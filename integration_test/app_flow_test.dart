import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:worldcup_friends_predictor/src/app/app.dart';
import 'package:worldcup_friends_predictor/src/data/providers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('complete friends prediction flow in demo mode', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appModeProvider.overrideWithValue(AppMode.demo)],
        child: const PredictorApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('authSubmitButton')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('displayNameField')), 'Flow Tester');
    await tester.tap(find.byKey(const ValueKey('saveProfileButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('matchesList')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('homeScoreUp')).first);
    await tester.tap(find.byKey(const ValueKey('homeScoreUp')).first);
    await tester.tap(find.byKey(const ValueKey('savePrediction_match-1')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('simulateFinal_match-1')));
    await tester.pumpAndSettle();

    expect(find.textContaining('3 pts'), findsWidgets);

    await tester.tap(find.text('Leagues'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('leaguesList')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('league_daxan')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('leaderboardList')), findsOneWidget);
    expect(find.text('Flow Tester'), findsOneWidget);
  });
}
