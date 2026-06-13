import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worldcup_friends_predictor/src/app/app.dart';
import 'package:worldcup_friends_predictor/src/data/providers.dart';

void main() {
  testWidgets('starts on auth screen in demo mode', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appModeProvider.overrideWithValue(AppMode.demo)],
        child: const PredictorApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Create account'), findsOneWidget);
    expect(find.byKey(const ValueKey('authSubmitButton')), findsOneWidget);
  });
}
