import { corsHeaders, jsonResponse } from '../_shared/cors.ts';
import { serviceClient } from '../_shared/supabase.ts';

type FootballDataTeam = {
  id: number;
  name: string;
  shortName?: string;
  tla?: string;
  crest?: string;
};

type FootballDataMatch = {
  id: number;
  utcDate: string;
  status: string;
  stage?: string;
  group?: string;
  venue?: string;
  homeTeam: FootballDataTeam;
  awayTeam: FootballDataTeam;
  score?: {
    fullTime?: { home: number | null; away: number | null };
  };
};

type ApiFootballFixture = {
  fixture: {
    id: number;
    date: string;
    status: { short: string };
  };
  teams: {
    home: { name: string };
    away: { name: string };
  };
  goals: {
    home: number | null;
    away: number | null;
  };
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabase = serviceClient();
    const footballDataToken = Deno.env.get('FOOTBALL_DATA_TOKEN');
    if (!footballDataToken) {
      return jsonResponse({ ok: false, message: 'FOOTBALL_DATA_TOKEN is not configured.' }, 400);
    }

    const footballDataResult = await syncFootballData(supabase, footballDataToken);

    let apiFootballResult = { checked: false, updated: 0 };
    const apiFootballKey = Deno.env.get('API_FOOTBALL_KEY');
    const apiFootballLeagueId = Deno.env.get('API_FOOTBALL_WORLD_CUP_LEAGUE_ID');
    if (apiFootballKey && apiFootballLeagueId) {
      apiFootballResult = await applyApiFootballLiveOverrides(supabase, apiFootballKey, apiFootballLeagueId);
    }

    return jsonResponse({
      ok: true,
      footballData: footballDataResult,
      apiFootball: apiFootballResult,
    });
  } catch (error) {
    return jsonResponse({ ok: false, error: String(error) }, 500);
  }
});

async function syncFootballData(supabase: ReturnType<typeof serviceClient>, token: string) {
  const endpoint = 'https://api.football-data.org/v4/competitions/WC/matches?season=2026';
  const response = await fetch(endpoint, {
    headers: { 'X-Auth-Token': token },
  });
  await logProviderRequest(supabase, 'football-data', endpoint, response.status, response.ok);

  if (!response.ok) {
    throw new Error(`football-data.org returned ${response.status}`);
  }

  const payload = await response.json();
  const matches = (payload.matches ?? []) as FootballDataMatch[];
  let upserted = 0;
  let rescored = 0;

  for (const match of matches) {
    if (!match.homeTeam?.id || !match.awayTeam?.id) continue;
    const homeTeamId = await upsertTeam(supabase, 'football-data', String(match.homeTeam.id), match.homeTeam);
    const awayTeamId = await upsertTeam(supabase, 'football-data', String(match.awayTeam.id), match.awayTeam);
    const status = normalizeFootballDataStatus(match.status);
    const homeScore = match.score?.fullTime?.home ?? null;
    const awayScore = match.score?.fullTime?.away ?? null;

    const { data, error } = await supabase
      .from('matches')
      .upsert(
        {
          provider: 'football-data',
          provider_match_id: String(match.id),
          competition: 'FIFA World Cup',
          season: 2026,
          stage: normalizeStage(match.stage),
          group_name: match.group ?? null,
          venue: match.venue ?? null,
          home_team_id: homeTeamId,
          away_team_id: awayTeamId,
          kickoff_at: match.utcDate,
          status,
          home_score: homeScore,
          away_score: awayScore,
          raw_payload: match,
          last_synced_at: new Date().toISOString(),
        },
        { onConflict: 'provider,provider_match_id' },
      )
      .select('id,status')
      .single();

    if (error) throw error;
    upserted += 1;

    if (status === 'finished' && data?.id) {
      const { data: count, error: scoreError } = await supabase.rpc('recalculate_match_scores', {
        match_id: data.id,
      });
      if (scoreError) throw scoreError;
      rescored += Number(count ?? 0);
    }
  }

  return { checked: true, upserted, rescored };
}

async function applyApiFootballLiveOverrides(
  supabase: ReturnType<typeof serviceClient>,
  apiKey: string,
  leagueId: string,
) {
  const endpoint = `https://v3.football.api-sports.io/fixtures?league=${leagueId}&season=2026&live=all`;
  const response = await fetch(endpoint, {
    headers: { 'x-apisports-key': apiKey },
  });
  await logProviderRequest(supabase, 'api-football', endpoint, response.status, response.ok);

  if (!response.ok) {
    return { checked: true, updated: 0, error: `API-Football returned ${response.status}` };
  }

  const payload = await response.json();
  const fixtures = (payload.response ?? []) as ApiFootballFixture[];
  let updated = 0;

  for (const fixture of fixtures) {
    if (fixture.goals.home === null || fixture.goals.away === null) continue;
    const kickoff = new Date(fixture.fixture.date);
    const windowStart = new Date(kickoff.getTime() - 1000 * 60 * 90).toISOString();
    const windowEnd = new Date(kickoff.getTime() + 1000 * 60 * 90).toISOString();
    const homeName = fixture.teams.home.name.toLowerCase();
    const awayName = fixture.teams.away.name.toLowerCase();

    const { data: candidates, error } = await supabase
      .from('matches')
      .select('id, home_team:home_team_id(name), away_team:away_team_id(name)')
      .gte('kickoff_at', windowStart)
      .lte('kickoff_at', windowEnd);

    if (error) throw error;

    const match = (candidates ?? []).find((candidate: any) => {
      const candidateHome = String(candidate.home_team?.name ?? '').toLowerCase();
      const candidateAway = String(candidate.away_team?.name ?? '').toLowerCase();
      return candidateHome === homeName && candidateAway === awayName;
    });

    if (!match) continue;

    const status = normalizeApiFootballStatus(fixture.fixture.status.short);
    const { error: updateError } = await supabase
      .from('matches')
      .update({
        status,
        home_score: fixture.goals.home,
        away_score: fixture.goals.away,
        last_synced_at: new Date().toISOString(),
      })
      .eq('id', match.id);

    if (updateError) throw updateError;
    updated += 1;

    if (status === 'finished') {
      await supabase.rpc('recalculate_match_scores', { match_id: match.id });
    }
  }

  return { checked: true, updated };
}

async function upsertTeam(
  supabase: ReturnType<typeof serviceClient>,
  provider: string,
  providerTeamId: string,
  team: FootballDataTeam,
) {
  const { data, error } = await supabase
    .from('teams')
    .upsert(
      {
        provider,
        provider_team_id: providerTeamId,
        name: team.name,
        short_name: team.tla ?? team.shortName ?? team.name,
        country_code: team.tla ?? null,
        badge_url: team.crest ?? null,
      },
      { onConflict: 'provider,provider_team_id' },
    )
    .select('id')
    .single();

  if (error) throw error;
  return data.id as string;
}

async function logProviderRequest(
  supabase: ReturnType<typeof serviceClient>,
  provider: string,
  endpoint: string,
  statusCode: number,
  success: boolean,
) {
  await supabase.from('provider_request_log').insert({
    provider,
    endpoint,
    status_code: statusCode,
    success,
  });
}

function normalizeFootballDataStatus(status: string) {
  switch (status) {
    case 'LIVE':
    case 'IN_PLAY':
    case 'PAUSED':
      return 'live';
    case 'FINISHED':
      return 'finished';
    case 'POSTPONED':
    case 'SUSPENDED':
    case 'CANCELLED':
      return 'postponed';
    default:
      return 'scheduled';
  }
}

function normalizeApiFootballStatus(status: string) {
  switch (status) {
    case '1H':
    case 'HT':
    case '2H':
    case 'ET':
    case 'BT':
    case 'P':
      return 'live';
    case 'FT':
    case 'AET':
    case 'PEN':
      return 'finished';
    case 'PST':
    case 'CANC':
    case 'ABD':
      return 'postponed';
    default:
      return 'scheduled';
  }
}

function normalizeStage(stage?: string) {
  if (!stage) return 'Group stage';
  return stage
    .toLowerCase()
    .split('_')
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(' ');
}
