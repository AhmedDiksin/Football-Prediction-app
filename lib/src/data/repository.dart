import '../domain/models.dart';

abstract class PredictorRepository {
  Stream<AppUser?> watchUser();
  AppUser? get currentUser;
  Future<AppUser> signIn({required String email, required String password});
  Future<AppUser> signUp({required String email, required String password});
  Future<void> signOut();
  Future<void> saveProfile({required String displayName, required int avatarColor});

  Stream<List<MatchWithPrediction>> watchMatches();
  Future<void> upsertPrediction({
    required String matchId,
    required int homeScore,
    required int awayScore,
  });

  Stream<List<LeagueSummary>> watchLeagues();
  Stream<List<LeaderboardEntry>> watchLeaderboard(String leagueId);
  Future<LeagueSummary> createLeague(String name);
  Future<void> joinLeague(String inviteCode);

  Future<void> simulateFinalScore({
    required String matchId,
    required int homeScore,
    required int awayScore,
  });
}
