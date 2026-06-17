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
  final _matchController =
      StreamController<List<MatchWithPrediction>>.broadcast();
  final _leagueController = StreamController<List<LeagueSummary>>.broadcast();
  final Map<String, StreamController<List<LeaderboardEntry>>>
  _leaderboardControllers = {};

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
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    _user = AppUser(id: 'demo-user', email: email, displayName: 'Ahmed Diksin');
    _emitAll();
    return _user!;
  }

  @override
  Future<AppUser> signUp({
    required String email,
    required String password,
  }) async {
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
  Future<void> saveProfile({
    required String displayName,
    required int avatarColor,
  }) async {
    final existing =
        _user ?? const AppUser(id: 'demo-user', email: 'friend@example.com');
    _user = existing.copyWith(
      displayName: displayName,
      avatarColor: avatarColor,
    );
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
    final index = _leagues.indexWhere(
      (league) => league.inviteCode == inviteCode.trim().toUpperCase(),
    );
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
    Team team(String id, String name, String shortName, String countryCode) =>
        Team(
          id: 'team-$id',
          name: name,
          shortName: shortName,
          countryCode: countryCode,
        );

    final mexico = team('mexico', 'Mexico', 'MEX', 'MX');
    final southAfrica = team('south-africa', 'South Africa', 'RSA', 'ZA');
    final southKorea = team('south-korea', 'South Korea', 'KOR', 'KR');
    final czechia = team('czechia', 'Czechia', 'CZE', 'CZ');
    final canada = team('canada', 'Canada', 'CAN', 'CA');
    final bosnia = team('bosnia', 'Bosnia', 'BIH', 'BA');
    final usa = team('usa', 'United States', 'USA', 'US');
    final paraguay = team('paraguay', 'Paraguay', 'PAR', 'PY');
    final england = team('england', 'England', 'ENG', 'GB');
    final brazil = team('brazil', 'Brazil', 'BRA', 'BR');
    final argentina = team('argentina', 'Argentina', 'ARG', 'AR');
    final germany = team('germany', 'Germany', 'GER', 'DE');
    final france = team('france', 'France', 'FRA', 'FR');
    final spain = team('spain', 'Spain', 'ESP', 'ES');
    final japan = team('japan', 'Japan', 'JPN', 'JP');
    final morocco = team('morocco', 'Morocco', 'MAR', 'MA');
    final portugal = team('portugal', 'Portugal', 'POR', 'PT');
    final netherlands = team('netherlands', 'Netherlands', 'NED', 'NL');
    final uruguay = team('uruguay', 'Uruguay', 'URU', 'UY');
    final senegal = team('senegal', 'Senegal', 'SEN', 'SN');
    _teams.addAll([
      mexico,
      southAfrica,
      southKorea,
      czechia,
      canada,
      bosnia,
      usa,
      paraguay,
      england,
      brazil,
      argentina,
      germany,
      france,
      spain,
      japan,
      morocco,
      portugal,
      netherlands,
      uruguay,
      senegal,
    ]);

    final now = DateTime.now().toUtc();
    FixtureMatch match({
      required String id,
      required Team home,
      required Team away,
      required DateTime kickoffAt,
      required MatchStatus status,
      required String venue,
      int? homeScore,
      int? awayScore,
    }) => FixtureMatch(
      id: id,
      homeTeam: home,
      awayTeam: away,
      kickoffAt: kickoffAt,
      status: status,
      homeScore: homeScore,
      awayScore: awayScore,
      venue: venue,
    );

    _matches.addAll([
      match(
        id: 'match-1',
        home: mexico,
        away: southAfrica,
        kickoffAt: now.add(const Duration(minutes: 45)),
        status: MatchStatus.scheduled,
        venue: 'Mexico City',
      ),
      match(
        id: 'match-2',
        home: southKorea,
        away: czechia,
        kickoffAt: now.add(const Duration(hours: 3)),
        status: MatchStatus.scheduled,
        venue: 'Los Angeles',
      ),
      match(
        id: 'match-3',
        home: canada,
        away: bosnia,
        kickoffAt: now.subtract(const Duration(hours: 2)),
        status: MatchStatus.finished,
        homeScore: 1,
        awayScore: 1,
        venue: 'Toronto',
      ),
      match(
        id: 'match-4',
        home: usa,
        away: paraguay,
        kickoffAt: now.subtract(const Duration(minutes: 20)),
        status: MatchStatus.live,
        homeScore: 0,
        awayScore: 0,
        venue: 'Dallas',
      ),
      match(
        id: 'match-5',
        home: england,
        away: brazil,
        kickoffAt: now.add(const Duration(days: 1, hours: 2)),
        status: MatchStatus.scheduled,
        venue: 'New York/New Jersey',
      ),
      match(
        id: 'match-6',
        home: argentina,
        away: germany,
        kickoffAt: now.add(const Duration(days: 1, hours: 5)),
        status: MatchStatus.scheduled,
        venue: 'Miami',
      ),
      match(
        id: 'match-7',
        home: france,
        away: spain,
        kickoffAt: now.add(const Duration(days: 1, hours: 8)),
        status: MatchStatus.scheduled,
        venue: 'Seattle',
      ),
      match(
        id: 'match-8',
        home: japan,
        away: morocco,
        kickoffAt: now.add(const Duration(days: 2, hours: 2)),
        status: MatchStatus.scheduled,
        venue: 'Atlanta',
      ),
      match(
        id: 'match-9',
        home: portugal,
        away: netherlands,
        kickoffAt: now.add(const Duration(days: 2, hours: 5)),
        status: MatchStatus.scheduled,
        venue: 'Boston',
      ),
      match(
        id: 'match-10',
        home: uruguay,
        away: senegal,
        kickoffAt: now.subtract(const Duration(days: 1, hours: 4)),
        status: MatchStatus.finished,
        homeScore: 2,
        awayScore: 1,
        venue: 'Kansas City',
      ),
      match(
        id: 'match-11',
        home: mexico,
        away: southKorea,
        kickoffAt: now.add(const Duration(days: 3, hours: 1)),
        status: MatchStatus.scheduled,
        venue: 'Guadalajara',
      ),
      match(
        id: 'match-12',
        home: canada,
        away: usa,
        kickoffAt: now.add(const Duration(days: 3, hours: 4)),
        status: MatchStatus.scheduled,
        venue: 'Vancouver',
      ),
    ]);

    _friends.addAll(const [
      LeaderboardEntry(
        userId: 'friend-1',
        displayName: 'Ammar Tube',
        rank: 1,
        points: 8,
        exactScores: 2,
      ),
      LeaderboardEntry(
        userId: 'friend-2',
        displayName: 'Muhammad',
        rank: 2,
        points: 7,
        exactScores: 1,
      ),
      LeaderboardEntry(
        userId: 'friend-3',
        displayName: 'Heba Alasady',
        rank: 4,
        points: 6,
        exactScores: 0,
      ),
      LeaderboardEntry(
        userId: 'friend-4',
        displayName: 'ORAS',
        rank: 4,
        points: 6,
        exactScores: 0,
      ),
      LeaderboardEntry(
        userId: 'friend-5',
        displayName: 'ayad daxan',
        rank: 4,
        points: 6,
        exactScores: 0,
      ),
      LeaderboardEntry(
        userId: 'friend-6',
        displayName: 'Haider',
        rank: 7,
        points: 5,
        exactScores: 1,
      ),
      LeaderboardEntry(
        userId: 'friend-7',
        displayName: 'Aboody',
        rank: 8,
        points: 4,
        exactScores: 0,
      ),
      LeaderboardEntry(
        userId: 'friend-8',
        displayName: 'Summer Oras',
        rank: 9,
        points: 2,
        exactScores: 0,
      ),
      LeaderboardEntry(
        userId: 'friend-9',
        displayName: 'Abdullah Ayad',
        rank: 10,
        points: 0,
        exactScores: 0,
      ),
      LeaderboardEntry(
        userId: 'friend-10',
        displayName: 'Nada Ali',
        rank: 10,
        points: 0,
        exactScores: 0,
      ),
    ]);

    _leagues.addAll(const [
      LeagueSummary(
        id: 'global',
        name: 'Global',
        memberCount: 689057,
        rank: 64006,
        totalPlayers: 689057,
        points: 0,
        isGlobal: true,
      ),
      LeagueSummary(
        id: 'united-kingdom',
        name: 'United Kingdom',
        memberCount: 90691,
        rank: 9922,
        totalPlayers: 90691,
        points: 0,
        isGlobal: true,
      ),
      LeagueSummary(
        id: 'daxan',
        name: 'Daxan',
        memberCount: 10,
        rank: 2,
        totalPlayers: 10,
        points: 0,
        isGlobal: false,
        inviteCode: 'DAXAN',
      ),
      LeagueSummary(
        id: 'family-cup',
        name: 'Family Cup',
        memberCount: 8,
        rank: 3,
        totalPlayers: 8,
        points: 0,
        isGlobal: false,
        inviteCode: 'FAMILY',
      ),
      LeagueSummary(
        id: 'work-friends',
        name: 'Work Friends',
        memberCount: 14,
        rank: 5,
        totalPlayers: 14,
        points: 0,
        isGlobal: false,
        inviteCode: 'WORK26',
      ),
    ]);
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

  int _currentUserPoints() => _predictions.values.fold(
    0,
    (total, prediction) => total + (prediction.points ?? 0),
  );
  int _currentUserExact() =>
      _predictions.values.where((prediction) => prediction.exact).length;

  void _emitAll() {
    _userController.add(_user);
    _emitMatches();
    _emitLeagues();
    for (final league in _leagues) {
      _emitLeaderboard(league.id);
    }
  }

  void _emitMatches() {
    _matchController.add(
      [
        for (final match in _matches)
          MatchWithPrediction(
            match: match,
            prediction: _predictions[match.id],
            homePickPercent: match.id.hashCode.abs() % 40 + 25,
            awayPickPercent: match.awayTeam.id.hashCode.abs() % 30 + 18,
            drawPickPercent:
                100 -
                ((match.id.hashCode.abs() % 40 + 25) +
                        (match.awayTeam.id.hashCode.abs() % 30 + 18))
                    .clamp(0, 95),
          ),
      ]..sort(_compareMatchCards),
    );
  }

  int _compareMatchCards(MatchWithPrediction a, MatchWithPrediction b) {
    final status = _statusSort(
      a.match.status,
    ).compareTo(_statusSort(b.match.status));
    if (status != 0) return status;
    return a.match.kickoffAt.compareTo(b.match.kickoffAt);
  }

  int _statusSort(MatchStatus status) {
    return switch (status) {
      MatchStatus.scheduled => 0,
      MatchStatus.live => 1,
      MatchStatus.finished => 2,
      MatchStatus.postponed => 3,
    };
  }

  void _emitLeagues() {
    final points = _currentUserPoints();
    _leagueController.add([
      for (final league in _leagues)
        LeagueSummary(
          id: league.id,
          name: league.name,
          memberCount: league.memberCount,
          rank:
              league.id == 'global'
                  ? max(1, 64006 - points * 811)
                  : max(1, league.rank - points ~/ 3),
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
    return List.generate(
      6,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }
}
