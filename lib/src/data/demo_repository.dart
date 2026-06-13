import 'dart:async';
import 'dart:math';

import 'package:uuid/uuid.dart';

import '../domain/models.dart';
import '../domain/scoring.dart';
import 'repository.dart';

class DemoPredictorRepository implements PredictorRepository {
  DemoPredictorRepository() {
    _seed();
  }

  final _uuid = const Uuid();
  final _userController = StreamController<AppUser?>.broadcast();
  final _matchController = StreamController<List<MatchWithPrediction>>.broadcast();
  final _leagueController = StreamController<List<LeagueSummary>>.broadcast();
  final Map<String, StreamController<List<LeaderboardEntry>>> _leaderboardControllers = {};

  AppUser? _user;
  final List<Team> _teams = [];
  final List<FixtureMatch> _matches = [];
  final Map<String, Prediction> _predictions = {};
  final List<LeagueSummary> _leagues = [];
  final List<LeaderboardEntry> _friends = [];

  @override
  AppUser? get currentUser => _user;

  @override
  Stream<AppUser?> watchUser() {
    Future.microtask(() => _userController.add(_user));
    return _userController.stream;
  }

  @override
  Future<AppUser> signIn({required String email, required String password}) async {
    _user = AppUser(id: 'demo-user', email: email, displayName: 'Ahmed Diksin');
    _emitAll();
    return _user!;
  }

  @override
  Future<AppUser> signUp({required String email, required String password}) async {
    _user = AppUser(id: 'demo-user', email: email);
    _emitAll();
    return _user!;
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _predictions.clear();
    _emitAll();
  }

  @override
  Future<void> saveProfile({required String displayName, required int avatarColor}) async {
    final existing = _user ?? const AppUser(id: 'demo-user', email: 'friend@example.com');
    _user = existing.copyWith(displayName: displayName, avatarColor: avatarColor);
    _emitAll();
  }

  @override
  Stream<List<MatchWithPrediction>> watchMatches() {
    Future.microtask(_emitMatches);
    return _matchController.stream;
  }

  @override
  Future<void> upsertPrediction({
    required String matchId,
    required int homeScore,
    required int awayScore,
  }) async {
    final user = _requireUser();
    final match = _matches.firstWhere((item) => item.id == matchId);
    if (match.isLocked) {
      throw StateError('Predictions lock at kickoff.');
    }
    _predictions[matchId] = Prediction(
      matchId: matchId,
      userId: user.id,
      homeScore: homeScore,
      awayScore: awayScore,
    );
    _emitAll();
  }

  @override
  Stream<List<LeagueSummary>> watchLeagues() {
    Future.microtask(_emitLeagues);
    return _leagueController.stream;
  }

  @override
  Stream<List<LeaderboardEntry>> watchLeaderboard(String leagueId) {
    final controller = _leaderboardControllers.putIfAbsent(
      leagueId,
      () => StreamController<List<LeaderboardEntry>>.broadcast(),
    );
    Future.microtask(() => _emitLeaderboard(leagueId));
    return controller.stream;
  }

  @override
  Future<LeagueSummary> createLeague(String name) async {
    _requireUser();
    final league = LeagueSummary(
      id: _uuid.v4(),
      name: name.trim(),
      memberCount: 1,
      rank: 1,
      totalPlayers: 1,
      points: _currentUserPoints(),
      isGlobal: false,
      inviteCode: _inviteCode(),
    );
    _leagues.add(league);
    _emitAll();
    return league;
  }

  @override
  Future<void> joinLeague(String inviteCode) async {
    _requireUser();
    final index = _leagues.indexWhere((league) => league.inviteCode == inviteCode.trim().toUpperCase());
    if (index == -1) {
      throw StateError('No league found for that invite code.');
    }
    final league = _leagues[index];
    _leagues[index] = LeagueSummary(
      id: league.id,
      name: league.name,
      memberCount: league.memberCount + 1,
      rank: min(league.rank, 2),
      totalPlayers: league.totalPlayers + 1,
      points: _currentUserPoints(),
      isGlobal: league.isGlobal,
      inviteCode: league.inviteCode,
    );
    _emitAll();
  }

  @override
  Future<void> simulateFinalScore({
    required String matchId,
    required int homeScore,
    required int awayScore,
  }) async {
    final index = _matches.indexWhere((item) => item.id == matchId);
    if (index == -1) return;
    _matches[index] = _matches[index].copyWith(
      status: MatchStatus.finished,
      homeScore: homeScore,
      awayScore: awayScore,
    );
    _scorePredictionsFor(matchId, homeScore, awayScore);
    _emitAll();
  }

  void _seed() {
    final mexico = Team(id: 'team-mexico', name: 'Mexico', shortName: 'MEX', countryCode: 'MX');
    final southAfrica = Team(id: 'team-south-africa', name: 'South Africa', shortName: 'RSA', countryCode: 'ZA');
    final southKorea = Team(id: 'team-south-korea', name: 'South Korea', shortName: 'KOR', countryCode: 'KR');
    final czechia = Team(id: 'team-czechia', name: 'Czechia', shortName: 'CZE', countryCode: 'CZ');
    final canada = Team(id: 'team-canada', name: 'Canada', shortName: 'CAN', countryCode: 'CA');
    final bosnia = Team(id: 'team-bosnia', name: 'Bosnia', shortName: 'BIH', countryCode: 'BA');
    final usa = Team(id: 'team-usa', name: 'United States', shortName: 'USA', countryCode: 'US');
    final paraguay = Team(id: 'team-paraguay', name: 'Paraguay', shortName: 'PAR', countryCode: 'PY');
    _teams.addAll([mexico, southAfrica, southKorea, czechia, canada, bosnia, usa, paraguay]);

    final now = DateTime.now().toUtc();
    _matches.addAll([
      FixtureMatch(
        id: 'match-1',
        homeTeam: mexico,
        awayTeam: southAfrica,
        kickoffAt: now.add(const Duration(minutes: 45)),
        status: MatchStatus.scheduled,
        venue: 'Mexico City',
      ),
      FixtureMatch(
        id: 'match-2',
        homeTeam: southKorea,
        awayTeam: czechia,
        kickoffAt: now.add(const Duration(hours: 3)),
        status: MatchStatus.scheduled,
        venue: 'Los Angeles',
      ),
      FixtureMatch(
        id: 'match-3',
        homeTeam: canada,
        awayTeam: bosnia,
        kickoffAt: now.subtract(const Duration(hours: 2)),
        status: MatchStatus.finished,
        homeScore: 1,
        awayScore: 1,
        venue: 'Toronto',
      ),
      FixtureMatch(
        id: 'match-4',
        homeTeam: usa,
        awayTeam: paraguay,
        kickoffAt: now.add(const Duration(days: 1, hours: 2)),
        status: MatchStatus.scheduled,
        venue: 'Dallas',
      ),
    ]);

    _friends.addAll(const [
      LeaderboardEntry(userId: 'friend-1', displayName: 'Ammar Tube', rank: 1, points: 8, exactScores: 2),
      LeaderboardEntry(userId: 'friend-2', displayName: 'Muhammad', rank: 2, points: 7, exactScores: 1),
      LeaderboardEntry(userId: 'friend-3', displayName: 'Heba Alasady', rank: 4, points: 6, exactScores: 0),
      LeaderboardEntry(userId: 'friend-4', displayName: 'ORAS', rank: 4, points: 6, exactScores: 0),
      LeaderboardEntry(userId: 'friend-5', displayName: 'Haider', rank: 7, points: 5, exactScores: 1),
      LeaderboardEntry(userId: 'friend-6', displayName: 'Aboody', rank: 8, points: 4, exactScores: 0),
      LeaderboardEntry(userId: 'friend-7', displayName: 'Summer Oras', rank: 9, points: 2, exactScores: 0),
    ]);

    _leagues.add(const LeagueSummary(
      id: 'global',
      name: 'Global',
      memberCount: 689057,
      rank: 64006,
      totalPlayers: 689057,
      points: 0,
      isGlobal: true,
    ));
    _leagues.add(const LeagueSummary(
      id: 'daxan',
      name: 'Daxan',
      memberCount: 10,
      rank: 2,
      totalPlayers: 10,
      points: 0,
      isGlobal: false,
      inviteCode: 'DAXAN',
    ));
  }

  void _scorePredictionsFor(String matchId, int homeScore, int awayScore) {
    final prediction = _predictions[matchId];
    if (prediction == null) return;
    _predictions[matchId] = Prediction(
      matchId: prediction.matchId,
      userId: prediction.userId,
      homeScore: prediction.homeScore,
      awayScore: prediction.awayScore,
      points: scorePrediction(
        predictedHome: prediction.homeScore,
        predictedAway: prediction.awayScore,
        actualHome: homeScore,
        actualAway: awayScore,
      ),
      exact: isExactPrediction(
        predictedHome: prediction.homeScore,
        predictedAway: prediction.awayScore,
        actualHome: homeScore,
        actualAway: awayScore,
      ),
    );
  }

  AppUser _requireUser() {
    final user = _user;
    if (user == null) throw StateError('Please sign in first.');
    return user;
  }

  int _currentUserPoints() => _predictions.values.fold(0, (total, prediction) => total + (prediction.points ?? 0));
  int _currentUserExact() => _predictions.values.where((prediction) => prediction.exact).length;

  void _emitAll() {
    _userController.add(_user);
    _emitMatches();
    _emitLeagues();
    for (final league in _leagues) {
      _emitLeaderboard(league.id);
    }
  }

  void _emitMatches() {
    _matchController.add([
      for (final match in _matches)
        MatchWithPrediction(
          match: match,
          prediction: _predictions[match.id],
          homePickPercent: match.id.hashCode.abs() % 40 + 25,
          awayPickPercent: match.awayTeam.id.hashCode.abs() % 30 + 18,
          drawPickPercent: 100 -
              ((match.id.hashCode.abs() % 40 + 25) + (match.awayTeam.id.hashCode.abs() % 30 + 18)).clamp(0, 95),
        ),
    ]..sort((a, b) => a.match.kickoffAt.compareTo(b.match.kickoffAt)));
  }

  void _emitLeagues() {
    final points = _currentUserPoints();
    _leagueController.add([
      for (final league in _leagues)
        LeagueSummary(
          id: league.id,
          name: league.name,
          memberCount: league.memberCount,
          rank: league.id == 'global' ? max(1, 64006 - points * 811) : max(1, league.rank - points ~/ 3),
          totalPlayers: league.totalPlayers,
          points: points,
          isGlobal: league.isGlobal,
          inviteCode: league.inviteCode,
        ),
    ]);
  }

  void _emitLeaderboard(String leagueId) {
    final controller = _leaderboardControllers[leagueId];
    if (controller == null) return;
    final user = _user;
    final current = LeaderboardEntry(
      userId: user?.id ?? 'demo-user',
      displayName: user?.displayName ?? 'You',
      rank: 1,
      points: _currentUserPoints(),
      exactScores: _currentUserExact(),
      isCurrentUser: true,
    );
    final entries = rankLeaderboard([current, ..._friends]);
    controller.add(entries);
  }

  String _inviteCode() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    return List.generate(6, (_) => alphabet[random.nextInt(alphabet.length)]).join();
  }
}
