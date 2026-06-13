import { corsHeaders, jsonResponse } from '../_shared/cors.ts';
import { serviceClient } from '../_shared/supabase.ts';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabase = serviceClient();
    const teams = [
      { provider_team_id: 'demo-mexico', name: 'Mexico', short_name: 'MEX', country_code: 'MX' },
      { provider_team_id: 'demo-south-africa', name: 'South Africa', short_name: 'RSA', country_code: 'ZA' },
      { provider_team_id: 'demo-south-korea', name: 'South Korea', short_name: 'KOR', country_code: 'KR' },
      { provider_team_id: 'demo-czechia', name: 'Czechia', short_name: 'CZE', country_code: 'CZ' },
      { provider_team_id: 'demo-canada', name: 'Canada', short_name: 'CAN', country_code: 'CA' },
      { provider_team_id: 'demo-bosnia', name: 'Bosnia', short_name: 'BIH', country_code: 'BA' },
    ];

    const teamIds = new Map<string, string>();
    for (const team of teams) {
      const { data, error } = await supabase
        .from('teams')
        .upsert({ provider: 'demo', ...team }, { onConflict: 'provider,provider_team_id' })
        .select('id, provider_team_id')
        .single();
      if (error) throw error;
      teamIds.set(data.provider_team_id, data.id);
    }

    const now = Date.now();
    const matches = [
      {
        provider_match_id: 'demo-match-1',
        home_team_id: teamIds.get('demo-mexico'),
        away_team_id: teamIds.get('demo-south-africa'),
        kickoff_at: new Date(now + 1000 * 60 * 45).toISOString(),
        status: 'scheduled',
        venue: 'Mexico City',
      },
      {
        provider_match_id: 'demo-match-2',
        home_team_id: teamIds.get('demo-south-korea'),
        away_team_id: teamIds.get('demo-czechia'),
        kickoff_at: new Date(now + 1000 * 60 * 60 * 3).toISOString(),
        status: 'scheduled',
        venue: 'Los Angeles',
      },
      {
        provider_match_id: 'demo-match-3',
        home_team_id: teamIds.get('demo-canada'),
        away_team_id: teamIds.get('demo-bosnia'),
        kickoff_at: new Date(now - 1000 * 60 * 60 * 2).toISOString(),
        status: 'finished',
        home_score: 1,
        away_score: 1,
        venue: 'Toronto',
      },
    ];

    const { error } = await supabase.from('matches').upsert(
      matches.map((match) => ({
        provider: 'demo',
        competition: 'FIFA World Cup',
        season: 2026,
        stage: 'Group stage',
        raw_payload: match,
        last_synced_at: new Date().toISOString(),
        ...match,
      })),
      { onConflict: 'provider,provider_match_id' },
    );

    if (error) throw error;
    return jsonResponse({ ok: true, teams: teams.length, matches: matches.length });
  } catch (error) {
    return jsonResponse({ ok: false, error: String(error) }, 500);
  }
});
