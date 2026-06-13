import 'models.dart';

MatchOutcome outcomeFor(int? homeScore, int? awayScore) {
  if (homeScore == null || awayScore == null) return MatchOutcome.unknown;
  if (homeScore > awayScore) return MatchOutcome.home;
  if (awayScore > homeScore) return MatchOutcome.away;
  return MatchOutcome.draw;
}

int scorePrediction({
  required int predictedHome,
  required int predictedAway,
  required int actualHome,
  required int actualAway,
}) {
  if (predictedHome == actualHome && predictedAway == actualAway) return 3;
  final predicted = outcomeFor(predictedHome, predictedAway);
  final actual = outcomeFor(actualHome, actualAway);
  return predicted == actual ? 1 : 0;
}

bool isExactPrediction({
  required int predictedHome,
  required int predictedAway,
  required int actualHome,
  required int actualAway,
}) {
  return predictedHome == actualHome && predictedAway == actualAway;
}

List<LeaderboardEntry> rankLeaderboard(List<LeaderboardEntry> entries) {
  final sorted = [...entries]..sort((a, b) {
    final points = b.points.compareTo(a.points);
    if (points != 0) return points;
    final exact = b.exactScores.compareTo(a.exactScores);
    if (exact != 0) return exact;
    return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
  });

  var previousPoints = -1;
  var previousExact = -1;
  var currentRank = 0;

  return [
    for (var index = 0; index < sorted.length; index++)
      sorted[index].copyRank(() {
        final entry = sorted[index];
        if (entry.points != previousPoints ||
            entry.exactScores != previousExact) {
          currentRank = index + 1;
          previousPoints = entry.points;
          previousExact = entry.exactScores;
        }
        return currentRank;
      }()),
  ];
}

extension on LeaderboardEntry {
  LeaderboardEntry copyRank(int rank) {
    return LeaderboardEntry(
      userId: userId,
      displayName: displayName,
      rank: rank,
      points: points,
      exactScores: exactScores,
      isCurrentUser: isCurrentUser,
    );
  }
}
