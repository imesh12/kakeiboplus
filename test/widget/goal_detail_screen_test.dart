import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/providers.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/savings_goal_contribution_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/savings_goal_repository.dart';
import 'package:ai_financial_coach/core/money/money.dart';
import 'package:ai_financial_coach/features/goals/presentation/goal_detail_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/rtl_harness.dart';

// NOTE: exercises generated Drift code — see CLAUDE_FIRST_CODING_PROMPT.md.
//
// Deliberately does NOT exercise `GoalDetailScreen`'s delete-goal flow
// (`_confirmDelete`) -- that calls `context.pop()`, which requires a
// `GoRouter` ancestor this file's plain `MaterialApp(home: ...)` harness
// doesn't provide (matching `test/widget/budgets_screen_test.dart`,
// which likewise never taps into cross-screen navigation). The
// underlying repository behavior soft-delete exercises is already
// covered by `test/core/database/repositories/savings_goal_repository_test.dart`.

void main() {
  Future<(AppDatabase, String)> seededDb() async {
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    final ProfileRepository profileRepo = ProfileRepository(db);
    final String profileId = await profileRepo.createProfile(
      displayName: 'Test User',
      homeCountry: 'LK',
      currentCountry: 'JP',
      homeCurrency: 'LKR',
      livingCurrency: 'JPY',
      preferredLanguage: 'en',
      timezone: 'Asia/Tokyo',
      dateFormat: 'yyyy-MM-dd',
      numberFormat: '#,##0.##',
    );
    return (db, profileId);
  }

  // CP5.6: `{bool rtl = false}` threads an RTL `Directionality` through
  // `MaterialApp`'s own `builder:` -- see `test/support/rtl_harness.dart`.
  Widget appWithGoalDetail(ProviderContainer container, String goalId, {bool rtl = false}) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: GoalDetailScreen(goalId: goalId),
        builder: rtl ? rtlAppBuilder : null,
      ),
    );
  }

  Future<void> disposeInOrder(WidgetTester tester, ProviderContainer container, AppDatabase db) async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pumpAndSettle();
    await db.close();
  }

  testWidgets('shows a freshly-created goal with no contributions as 0% in progress',
      (tester) async {
    final (AppDatabase db, String profileId) = await seededDb();
    final String goalId = await SavingsGoalRepository(db).createGoal(
      profileId: profileId,
      name: 'Emergency Fund',
      targetAmount: Money.fromMinorUnits(100000, 'JPY'),
    );
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithGoalDetail(container, goalId));
    await tester.pumpAndSettle();

    expect(find.text('Emergency Fund'), findsWidgets); // app bar title + body
    expect(find.textContaining('of ¥100,000'), findsOneWidget);
    expect(find.textContaining('In progress'), findsOneWidget);
    expect(find.text('No contributions yet.'), findsOneWidget);
  });

  testWidgets('adding a contribution updates saved and the contribution history', (tester) async {
    final (AppDatabase db, String profileId) = await seededDb();
    final String goalId = await SavingsGoalRepository(db).createGoal(
      profileId: profileId,
      name: 'Emergency Fund',
      targetAmount: Money.fromMinorUnits(100000, 'JPY'),
    );
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithGoalDetail(container, goalId));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('addContributionFab')));
    await tester.pumpAndSettle();
    expect(find.text('Add a contribution'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('contributionAmountField')), '30000');
    await tester.tap(find.byKey(const Key('saveContribution')));
    await tester.pumpAndSettle();

    expect(find.text('Add a contribution'), findsNothing); // dialog closed
    expect(find.text('¥30,000'), findsWidgets); // headline saved amount + history row
    expect(find.text('No contributions yet.'), findsNothing);
  });

  testWidgets('deleting a contribution removes it from history and reduces saved', (tester) async {
    final (AppDatabase db, String profileId) = await seededDb();
    final SavingsGoalRepository goalRepo = SavingsGoalRepository(db);
    final String goalId = await goalRepo.createGoal(
      profileId: profileId,
      name: 'Emergency Fund',
      targetAmount: Money.fromMinorUnits(100000, 'JPY'),
    );
    final SavingsGoalContributionRepository contributionRepo =
        SavingsGoalContributionRepository(db, goalRepo);
    await contributionRepo.addContribution(
      goalId: goalId,
      amount: Money.fromMinorUnits(30000, 'JPY'),
      contributedAt: DateTime.utc(2026, 1, 1),
    );
    final String secondId = await contributionRepo.addContribution(
      goalId: goalId,
      amount: Money.fromMinorUnits(20000, 'JPY'),
      contributedAt: DateTime.utc(2026, 2, 1),
    );

    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithGoalDetail(container, goalId));
    await tester.pumpAndSettle();

    expect(find.byKey(Key('contributionTile_$secondId')), findsOneWidget);
    // Scoped to the headline saved-amount widget specifically --
    // "Remaining" (target 100000 - saved 50000) also reads ¥50,000 at
    // this point, so a plain `find.text('¥50,000')` matches two
    // widgets. See `goal_detail_screen.dart`'s `goalSavedAmount` key.
    expect(
      tester.widget<Text>(find.byKey(const Key('goalSavedAmount'))).data,
      '¥50,000', // 30000 + 20000, headline saved
    );

    await tester.tap(find.byKey(Key('deleteContribution_$secondId')));
    await tester.pumpAndSettle();

    expect(find.byKey(Key('contributionTile_$secondId')), findsNothing);
    expect(find.text('¥30,000'), findsWidgets); // saved dropped back to just the first
  });

  testWidgets('editing a goal updates the displayed name and target amount', (tester) async {
    final (AppDatabase db, String profileId) = await seededDb();
    final String goalId = await SavingsGoalRepository(db).createGoal(
      profileId: profileId,
      name: 'Old Name',
      targetAmount: Money.fromMinorUnits(100000, 'JPY'),
    );
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithGoalDetail(container, goalId));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('editGoal')));
    await tester.pumpAndSettle();
    expect(find.text('Edit goal'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('editGoalNameField')), 'New Name');
    await tester.enterText(find.byKey(const Key('editGoalTargetAmountField')), '200000');
    await tester.tap(find.byKey(const Key('saveEditGoal')));
    await tester.pumpAndSettle();

    expect(find.text('Edit goal'), findsNothing); // dialog closed
    expect(find.text('New Name'), findsWidgets);
    expect(find.textContaining('of ¥200,000'), findsOneWidget);
  });

  testWidgets('a goal that no longer exists (e.g. soft-deleted) shows an unavailable state',
      (tester) async {
    final (AppDatabase db, String profileId) = await seededDb();
    final SavingsGoalRepository goalRepo = SavingsGoalRepository(db);
    final String goalId = await goalRepo.createGoal(
      profileId: profileId,
      name: 'Temporary',
      targetAmount: Money.fromMinorUnits(100000, 'JPY'),
    );
    await goalRepo.softDeleteGoal(goalId);

    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithGoalDetail(container, goalId));
    await tester.pumpAndSettle();

    expect(find.text('This goal is no longer available.'), findsOneWidget);
    expect(find.byKey(const Key('addContributionFab')), findsNothing);
    expect(find.byKey(const Key('editGoal')), findsNothing);
  });

  testWidgets('the goal detail screen lays out without overflow on a narrow (320px-wide) screen '
      'with a target date, milestones, and contribution history', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1.0;

    final (AppDatabase db, String profileId) = await seededDb();
    final SavingsGoalRepository goalRepo = SavingsGoalRepository(db);
    final String goalId = await goalRepo.createGoal(
      profileId: profileId,
      name: 'A very long savings goal name that could wrap awkwardly on a narrow screen',
      targetAmount: Money.fromMinorUnits(100000, 'JPY'),
      targetDate: DateTime.utc(2026, 12, 25),
    );
    final SavingsGoalContributionRepository contributionRepo =
        SavingsGoalContributionRepository(db, goalRepo);
    await contributionRepo.addContribution(goalId: goalId, amount: Money.fromMinorUnits(60000, 'JPY'));

    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithGoalDetail(container, goalId));
    await tester.pumpAndSettle();

    final Object? overflowException = tester.takeException();
    if (overflowException != null) {
      fail('Narrow-screen (320px) goal detail layout threw an exception:\n\n$overflowException');
    }
  });

  // CP5.4a: hero saved-amount/status-chip adaptive layout hardening.
  // These are additive to the coverage above -- they don't re-check
  // normal-regression persistence behavior (already covered by the
  // tests above) or the unavailable-goal state; what's new here is
  // narrow-width/large-text-scale robustness for `_GoalHeroAmountRow`,
  // the `goalHeroHorizontal`/`goalHeroStacked` layout switch it
  // introduces, and confirmation that the authoritative saved amount
  // always renders in full regardless of which arrangement is chosen.

  testWidgets(
      'CP5.4a: an ordinary saved amount and status chip render side by side at normal width '
      'and text scale', (tester) async {
    final (AppDatabase db, String profileId) = await seededDb();
    final SavingsGoalRepository goalRepo = SavingsGoalRepository(db);
    final String goalId = await goalRepo.createGoal(
      profileId: profileId,
      name: 'Emergency Fund',
      targetAmount: Money.fromMinorUnits(200000, 'JPY'),
    );
    final SavingsGoalContributionRepository contributionRepo =
        SavingsGoalContributionRepository(db, goalRepo);
    await contributionRepo.addContribution(goalId: goalId, amount: Money.fromMinorUnits(80000, 'JPY'));

    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithGoalDetail(container, goalId));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // At the test harness's default (non-narrow) surface size, the hero
    // amount and status chip are guaranteed to fit side by side.
    expect(find.byKey(const Key('goalHeroHorizontal')), findsOneWidget);
    expect(find.byKey(const Key('goalHeroStacked')), findsNothing);
    expect(
      tester.widget<Text>(find.byKey(const Key('goalSavedAmount'))).data,
      '\u00A580,000', // ¥80,000
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('goalHeroHorizontal')),
        matching: find.text('In progress'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
      'CP5.4a: a large 0-decimal VND saved amount keeps every digit at a narrow 320px width '
      'and a 1.6x text scale', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final (AppDatabase db, String profileId) = await seededDb();
    final SavingsGoalRepository goalRepo = SavingsGoalRepository(db);
    final String goalId = await goalRepo.createGoal(
      profileId: profileId,
      name: 'Large VND Goal',
      targetAmount: Money.fromMinorUnits(1999999998, 'VND'),
    );
    final SavingsGoalContributionRepository contributionRepo =
        SavingsGoalContributionRepository(db, goalRepo);
    await contributionRepo.addContribution(
      goalId: goalId,
      amount: Money.fromMinorUnits(999999999, 'VND'),
    );

    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithGoalDetail(container, goalId));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Deliberately not scoped to a specific goalHeroHorizontal/
    // goalHeroStacked key here -- at this width/scale the layout may
    // legitimately land in either branch; only that every digit of the
    // saved amount survives intact is being asserted (the next test
    // pins a specific branch, using a magnitude pre-measured to force
    // it).
    expect(
      tester.widget<Text>(find.byKey(const Key('goalSavedAmount'))).data,
      '\u20AB999,999,999', // ₫999,999,999
    );
  });

  testWidgets(
      'CP5.4a: the hero row switches to a stacked layout and keeps every digit of a large MMK '
      'saved amount at a narrow 320px width and an extreme 2.0x text scale', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final (AppDatabase db, String profileId) = await seededDb();
    final SavingsGoalRepository goalRepo = SavingsGoalRepository(db);
    final String goalId = await goalRepo.createGoal(
      profileId: profileId,
      name: 'Large MMK Goal',
      targetAmount: Money.fromMinorUnits(2000000000, 'MMK'),
    );
    final SavingsGoalContributionRepository contributionRepo =
        SavingsGoalContributionRepository(db, goalRepo);
    await contributionRepo.addContribution(
      goalId: goalId,
      // K9,999,999.99 -- MMK has 2 minor units per `CurrencyRegistry`,
      // not 0; this exact value was measured in a prior CP5.1/CP5.2a
      // diagnostic run to exceed a narrow card's available width at
      // 2.0x text scale against competing fixed-width content, so it's
      // reused here -- alongside "In progress" (the default status for
      // an under-target goal with no target date, and the longest of
      // the three status labels) -- to reliably force the stacked
      // branch rather than guessing a value.
      amount: Money.fromMinorUnits(999999999, 'MMK'),
    );

    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithGoalDetail(container, goalId));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('goalHeroStacked')), findsOneWidget);
    expect(find.byKey(const Key('goalHeroHorizontal')), findsNothing);
    expect(
      tester.widget<Text>(find.byKey(const Key('goalSavedAmount'))).data,
      'K9,999,999.99',
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('goalHeroStacked')),
        matching: find.text('In progress'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
      'CP5.4a: a 3-decimal KWD saved amount renders with its registry-defined precision, not 0, '
      'in the hero row under normal width and text scale', (tester) async {
    final (AppDatabase db, String profileId) = await seededDb();
    final SavingsGoalRepository goalRepo = SavingsGoalRepository(db);
    final String goalId = await goalRepo.createGoal(
      profileId: profileId,
      name: 'KWD Precision Goal',
      targetAmount: Money.fromMinorUnits(99999999, 'KWD'),
    );
    final SavingsGoalContributionRepository contributionRepo =
        SavingsGoalContributionRepository(db, goalRepo);
    await contributionRepo.addContribution(
      goalId: goalId,
      amount: Money.fromMinorUnits(12345678, 'KWD'), // د.ك12,345.678
    );

    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithGoalDetail(container, goalId));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      tester.widget<Text>(find.byKey(const Key('goalSavedAmount'))).data,
      '\u062F.\u064312,345.678', // د.ك12,345.678
    );
  });

  testWidgets(
      'CP5.6: RTL smoke -- the hero row (already `Directionality.of(context)`-aware since '
      'CP5.4a) switches to a stacked layout and keeps every digit of a large MMK saved '
      'amount at a narrow 320px width and an extreme 2.0x text scale, under RTL, with no '
      'exceptions', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final (AppDatabase db, String profileId) = await seededDb();
    final SavingsGoalRepository goalRepo = SavingsGoalRepository(db);
    final String goalId = await goalRepo.createGoal(
      profileId: profileId,
      name: 'Large MMK Goal',
      targetAmount: Money.fromMinorUnits(2000000000, 'MMK'),
    );
    final SavingsGoalContributionRepository contributionRepo =
        SavingsGoalContributionRepository(db, goalRepo);
    await contributionRepo.addContribution(
      goalId: goalId,
      amount: Money.fromMinorUnits(999999999, 'MMK'), // K9,999,999.99
    );

    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithGoalDetail(container, goalId, rtl: true));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('goalHeroStacked')), findsOneWidget);
    expect(find.byKey(const Key('goalHeroHorizontal')), findsNothing);
    expect(
      tester.widget<Text>(find.byKey(const Key('goalSavedAmount'))).data,
      'K9,999,999.99',
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('goalHeroStacked')),
        matching: find.text('In progress'),
      ),
      findsOneWidget,
    );
  });
}
