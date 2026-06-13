import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models.dart';
import 'repository.dart';

class SupabasePredictorRepository implements PredictorRepository {
  SupabasePredictorRepository(this._client);

  final SupabaseClient _client;
  AppUser? _cachedUser;

  @override
  AppUser? get currentUser => _cachedUser;

  @override
  Stream<AppUser?> watchUser() async* {
    yield await _loadCurrentUser();
    await for (final _ in _client.auth.onAuthStateChange) {
      yield await _loadCurrentUser();
    }
  }

  @override
  Future<AppUser> signIn({required String email, required String password}) async {
    final response = await _client.auth.signInWithPassword(email: email, password: password);
    return _hydrateAuthUser(response.user);
  }

  @override
  Future<AppUser> signUp({required String email, required String password}) async {
    final response = await _client.auth.signUp(email: email, password: password);
    return _hydrateAuthUser(response.user);
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  Future<void> saveProfile({required String displayName, required int avatarColor}) async {
    await _client.rpc('create_profile', params: {
      'display_name': displayName,
      'avatar_color': avatarColor.toRadixString(16).padLeft(8, '0'),
    });
    _cachedUser = await _loadCurrentUser();
  }

  @override
  Stream<List<MatchWithPrediction>> watchMatches() {
    return _client
        .from('matches')
        .stream(primaryKey: ['id'])
        .order('kickoff_at')
        .asyncMap((rows) => _hydrateMatches(rows.cast<Map<String, dynamic>>()));
  }

  @override
  Future<void> upsertPrediction({
    required String matchId,
    required int homeScore,
    required int awayScore,
  }) async {
    await _client.rpc('upsert_prediction', params: {
      'match_id': matchId,
      'home_score': homeScore,
      'away_score': awayScore,
    });
  }

  @override
  Stream<List<LeagueSummary>> watchLeagues() {
    return Stream<int>.periodic(const Duration(seconds: 15), (tick) => tick)
        .startWith(0)
        .asyncMap((_) => _fetchLeagues());
  }

  @override
  Stream<List<LeaderboardEntry>> watchLeaderboard(String leagueId) {
    return Stream<int>.periodic(const Duration(seconds: 10), (tick) => tick)
        .startWith(0)
        .asyncMap((_) => _fetchLeaderboard(leagueId));
  }

  @override
  Future<LeagueSummary> createLeague(String name) async {
    final result = await _client.rpc('create_league', params: {'league_name': name}).single();
    return _leagueFromMap(result);
  }

  @override
  Future<void> joinLeague(String inviteCode) async {
    await _client.rpc('join_league', params: {'invite_code': inviteCode.trim().toUpperCase()});
  }

  @override
  Future<void> simulateFinalScore({
    required String matchId,
    required int homeScore,
    required int awayScore,
  }) async {
    throw UnsupportedError('Score simulation is only available in demo mode.');
  }

  Future<AppUser?> _loadCurrentUser() async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      _cachedUser = null;
      return null;
    }
    _cachedUser = await _hydrateAuthUser(authUser);
    return _cachedUser;
  }

  Future<AppUser> _hydrateAuthUser(User? authUser) async {
    if (authUser == null) {
      throw StateError('No Supabase user returned.');
    }

    final profile = await _client
        .from('profiles')
        .select('display_name, avatar_color')
        .eq('id', authUser.id)
        .maybeSingle();

    final colorText = profile?['avatar_color'] as String?;
    final avatarColor = colorText == null ? 0xff5af28a : int.tryParse(colorText, radix: 16) ?? 0xff5af28a;

    final user = AppUser(
      id: authUser.id,
      email: authUser.email ?? '',
      displayName: profile?['display_name'] as String?,
      avatarColor: avatarColor,
    );
    _cachedUser = user;
    return user;
  }

  Future<List<MatchWithPrediction>> _hydrateMatches(List<Map<String, dynamic>> matchRows) async {
    if (matchRows.isEmpty) return [];
    final teamIds = <String>{
      for (final row in matchRows) row['home_team_id'] as String,
      for (final row in matchRows) row['away_team_id'] as String,
    };
    final teamRows = await _client.from('teams').select().inFilter('id', teamIds.toList());
    final typedTeamRows = teamRows.cast<Map<String, dynamic>>();
    final teams = {
      for (final row in typedTeamRows) row['id'] as String: _teamFromMap(row),
    };

    final userId = _client.auth.currentUser?.id;
    final List<Map<String, dynamic>> predictionRows;
    if (userId == null) {
      predictionRows = [];
    } else {
      final rows = await _client
          .from('predictions')
          .select('match_id, user_id, home_score, away_score, prediction_scores(points, exact)')
          .eq('user_id', userId)
          .inFilter('match_id', matchRows.map((row) => row['id']).toList());
      predictionRows = rows.cast<Map<String, dynamic>>();
    }
    final predictions = {
      for (final row in predictionRows) row['match_id'] as String: _predictionFromMap(row),
    };

    return [
      for (final row in matchRows)
        MatchWithPrediction(
          match: _matchFromMap(row, teams),
          prediction: predictions[row['id']],
        ),
    ];
  }

  Future<List<LeagueSummary>> _fetchLeagues() async {
    final rows = await _client.rpc('get_my_leagues');
    return [for (final row in rows as List<dynamic>) _leagueFromMap(row as Map<String, dynamic>)];
  }

  Future<List<LeaderboardEntry>> _fetchLeaderboard(String leagueId) async {
    final rows = await _client.rpc('get_leaderboard', params: {'league_id': leagueId});
    return [for (final row in rows as List<dynamic>) _leaderboardFromMap(row as Map<String, dynamic>)];
  }

  Team _teamFromMap(Map<String, dynamic> row) {
    return Team(
      id: row['id'] as String,
      name: row['name'] as String,
      shortName: row['short_name'] as String? ?? row['name'] as String,
      countryCode: row['country_code'] as String? ?? '',
      badgeUrl: row['badge_url'] as String?,
    );
  }

  FixtureMatch _matchFromMap(Map<String, dynamic> row, Map<String, Team> teams) {
    return FixtureMatch(
      id: row['id'] as String,
      homeTeam: teams[row['home_team_id']]!,
      awayTeam: teams[row['away_team_id']]!,
      kickoffAt: DateTime.parse(row['kickoff_at'] as String),
      status: _statusFromText(row['status'] as String),
      homeScore: row['home_score'] as int?,
      awayScore: row['away_score'] as int?,
      stage: row['stage'] as String? ?? 'Group stage',
      venue: row['venue'] as String?,
    );
  }

  Prediction _predictionFromMap(Map<String, dynamic> row) {
    final scoreRows = row['prediction_scores'];
    final score = scoreRows is List && scoreRows.isNotEmpty ? scoreRows.first as Map<String, dynamic> : null;
    return Prediction(
      matchId: row['match_id'] as String,
      userId: row['user_id'] as String,
      homeScore: row['home_score'] as int,
      awayScore: row['away_score'] as int,
      points: score?['points'] as int?,
      exact: score?['exact'] as bool? ?? false,
    );
  }

  LeagueSummary _leagueFromMap(Map<String, dynamic> row) {
    return LeagueSummary(
      id: row['id'] as String,
      name: row['name'] as String,
      memberCount: row['member_count'] as int? ?? 0,
      rank: row['rank'] as int? ?? 0,
      totalPlayers: row['total_players'] as int? ?? 0,
      points: row['points'] as int? ?? 0,
      isGlobal: row['is_global'] as bool? ?? false,
      inviteCode: row['invite_code'] as String?,
    );
  }

  LeaderboardEntry _leaderboardFromMap(Map<String, dynamic> row) {
    return LeaderboardEntry(
      userId: row['user_id'] as String,
      displayName: row['display_name'] as String,
      rank: row['rank'] as int,
      points: row['points'] as int,
      exactScores: row['exact_scores'] as int,
      isCurrentUser: row['is_current_user'] as bool? ?? false,
    );
  }

  MatchStatus _statusFromText(String value) {
    return switch (value) {
      'live' => MatchStatus.live,
      'finished' => MatchStatus.finished,
      'postponed' => MatchStatus.postponed,
      _ => MatchStatus.scheduled,
    };
  }
}

extension _StartWith<T> on Stream<T> {
  Stream<T> startWith(T value) async* {
    yield value;
    yield* this;
  }
}
