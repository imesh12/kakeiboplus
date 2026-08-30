import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/providers.dart';
import 'package:ai_financial_coach/features/onboarding/presentation/onboarding_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// NOTE: exercises generated Drift code — see CLAUDE_FIRST_CODING_PROMPT.md.

void main() {
  testWidgets('submitting with no name shows a validation error and saves nothing', (
    tester,
  ) async {
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: OnboardingScreen()),
      ),
    );

    await tester.tap(find.text('Get started'));
    await tester.pump();

    expect(find.text('Enter a name.'), findsOneWidget);
    expect(await db.select(db.profiles).get(), isEmpty);
  });

  testWidgets('completing the form creates a local profile', (tester) async {
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: OnboardingScreen()),
      ),
    );

    await tester.enterText(find.byType(TextFormField).first, 'Test User');
    await tester.tap(find.text('Get started'));
    // Profile creation is async (a database insert); pump until settled.
    await tester.pumpAndSettle();

    final List<ProfileRow> profiles = await db.select(db.profiles).get();
    expect(profiles, hasLength(1));
    expect(profiles.single.displayName, 'Test User');
    // Defaults for the current/home country pickers (Japan / Sri Lanka)
    // per OnboardingScreen's initial state.
    expect(profiles.single.currentCountry, 'JP');
    expect(profiles.single.livingCurrency, 'JPY');
    expect(profiles.single.homeCountry, 'LK');
    expect(profiles.single.homeCurrency, 'LKR');
  });
}
