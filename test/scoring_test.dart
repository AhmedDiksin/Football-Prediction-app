import 'package:flutter_test/flutter_test.dart';
import 'package:worldcup_friends_predictor/src/domain/models.dart';
import 'package:worldcup_friends_predictor/src/domain/scoring.dart';

void main() {
  group('scorePrediction', () {
    test('awards 3 points for exact score', () {
      expect(
        scorePrediction(
          predictedHome: 2,
          predictedAway: 0,
          actualHome: 2,
          actualAway: 0,
        ),
        3,
      );
    });

    test('awards 1 point for correct winner', () {
      expect(
        scorePrediction(
          predictedHome: 1,
          predictedAway: 0,
          actualHome: 3,
          actualAway: 1,
        ),
        1,
      );
    });

    test('awards 1 point for correctly predicted draw', () {
      expect(
        scorePrediction(
          predictedHome: 0,
          predictedAway: 0,
          actualHome: 2,
          actualAway: 2,
        ),
        1,
      );
    });

    test('awards 0 points for wrong outcome', () {
      expect(
        scorePrediction(
          predictedHome: 1,
          predictedAway: 0,
          actualHome: 0,
          actualAway: 2,
        ),
        0,
      );
    });
  });

  test(
    'rankLeaderboard uses competition ranking with exact-score tiebreak',
    () {
      final ranked = rankLeaderboard(const [
        LeaderboardEntry(
          userId: 'a',
          displayName: 'A',
          rank: 0,
          points: 7,
          exactScores: 1,
        ),
        LeaderboardEntry(
          userId: 'b',
          displayName: 'B',
          rank: 0,
          points: 8,
          exactScores: 1,
        ),
        LeaderboardEntry(
          userId: 'c',
          displayName: 'C',
          rank: 0,
          points: 7,
          exactScores: 1,
        ),
        LeaderboardEntry(
          userId: 'd',
          displayName: 'D',
          rank: 0,
          points: 7,
          exactScores: 0,
        ),
      ]);

      expect(ranked.map((entry) => entry.rank), [1, 2, 2, 4]);
    },
  );
}
