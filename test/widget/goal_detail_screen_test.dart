import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/providers.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/savings_goal_contribution_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/savings_goal_repository.dart';
import 'package:ai_financial_coach/core/money/money.dart';
import 'package:ai_financial_coach/features/goals/presentation/goal_detail_screen.dart';
import 'package:ai_financial_coach/l10n/generated/app_localizations.dart';
import 'package:ai_financial_coach/shared/theme/app_tokens.dart';
import 'package:ai_financial_coach/shared/widgets/app_progress_bar.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
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
  Widget appWithGoalDetail(
    ProviderContainer container,
    String goalId, {
    bool rtl = false,
    Locale locale = const Locale('en'),
  }) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
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

  // CP6.6: Goal Detail Japanese localization. Re-uses every seeding/
  // layout-key helper above unchanged; only `appWithGoalDetail` grew a
  // `locale` parameter (default 'en', so every test above this point is
  // unaffected). Letters below reference the CP6.6 checkpoint's overall
  // Savings Goal coverage list (A/B/K live in
  // `test/widget/savings_goals_screen_test.dart`).
  group('CP6.6 Japanese localization', () {
    testWidgets(
      'C: standard Japanese Goal Detail renders localized principal labels with target/saved/'
      'remaining values intact',
      (tester) async {
        final (AppDatabase db, String profileId) = await seededDb();
        final String goalId = await SavingsGoalRepository(db).createGoal(
          profileId: profileId,
          name: 'Emergency Fund',
          targetAmount: Money.fromMinorUnits(100000, 'JPY'), // ¥100,000
        );
        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithGoalDetail(container, goalId, locale: const Locale('ja')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Emergency Fund'), findsWidgets); // untouched goal name
        expect(find.textContaining('¥100,000のうち'), findsOneWidget); // ofAmount(target)
        expect(find.textContaining('進行中'), findsOneWidget); // goalStatusInProgress
        expect(find.text('残り'), findsOneWidget); // remainingLabel
        expect(
          tester.widget<Text>(find.byKey(const Key('goalSavedAmount'))).data,
          '¥0', // nothing saved yet -- value itself is untouched
        );
        expect(find.text('積立履歴'), findsOneWidget); // contributionHistoryTitle
        expect(find.text('積立はまだありません。'), findsOneWidget); // noContributionsYetMessage
      },
    );

    testWidgets(
      'D: Japanese + the hero row switches to a stacked layout and keeps every digit of a '
      'large MMK saved amount at a narrow 320px width and an extreme 2.0x text scale',
      (tester) async {
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

        await tester.pumpWidget(appWithGoalDetail(container, goalId, locale: const Locale('ja')));
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
            matching: find.text('進行中'), // goalStatusInProgress
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'E: Japanese + a large 0-decimal VND saved amount keeps every digit at a narrow 320px '
      'width and a 1.6x text scale',
      (tester) async {
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

        await tester.pumpWidget(appWithGoalDetail(container, goalId, locale: const Locale('ja')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          tester.widget<Text>(find.byKey(const Key('goalSavedAmount'))).data,
          '₫999,999,999',
        );
      },
    );

    testWidgets(
      'F: Japanese + a 3-decimal KWD saved amount renders with its registry-defined precision, '
      'not 0, in the hero row under normal width and text scale',
      (tester) async {
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

        await tester.pumpWidget(appWithGoalDetail(container, goalId, locale: const Locale('ja')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          tester.widget<Text>(find.byKey(const Key('goalSavedAmount'))).data,
          'د.ك12,345.678',
        );
      },
    );

    testWidgets(
      'G: Japanese + 1.6x text scale renders the goal detail screen without exceptions',
      (tester) async {
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        tester.platformDispatcher.textScaleFactorTestValue = 1.6;

        final (AppDatabase db, String profileId) = await seededDb();
        final String goalId = await SavingsGoalRepository(db).createGoal(
          profileId: profileId,
          name: 'Emergency Fund',
          targetAmount: Money.fromMinorUnits(100000, 'JPY'),
        );
        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithGoalDetail(container, goalId, locale: const Locale('ja')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('残り'), findsOneWidget);
      },
    );

    testWidgets(
      'H: Japanese + 2.0x text scale renders the goal detail screen without exceptions',
      (tester) async {
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;

        final (AppDatabase db, String profileId) = await seededDb();
        final String goalId = await SavingsGoalRepository(db).createGoal(
          profileId: profileId,
          name: 'Emergency Fund',
          targetAmount: Money.fromMinorUnits(100000, 'JPY'),
        );
        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithGoalDetail(container, goalId, locale: const Locale('ja')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('残り'), findsOneWidget);
      },
    );

    testWidgets(
      'J: contribution/action regression -- adding a contribution under the Japanese locale '
      'shows a fully localized dialog, and submitting it still persists and updates the '
      'saved amount and contribution history',
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

        await tester.pumpWidget(appWithGoalDetail(container, goalId, locale: const Locale('ja')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('addContributionFab')));
        await tester.pumpAndSettle();
        expect(find.text('積立を追加'), findsOneWidget); // addContributionDialogTitle
        expect(find.text('金額'), findsOneWidget); // amountLabel

        await tester.enterText(find.byKey(const Key('contributionAmountField')), '30000');
        await tester.tap(find.byKey(const Key('saveContribution')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('積立を追加'), findsNothing); // dialog closed
        expect(
          tester.widget<Text>(find.byKey(const Key('goalSavedAmount'))).data,
          '¥30,000',
        );
        expect(find.text('積立はまだありません。'), findsNothing);
      },
    );
  });

  // ---------------------------------------------------------------------
  // Checkpoint S: Savings Goals completion -- genuine gaps the audit
  // found (see `docs/14_DECISION_LOG.md` ADR-042): no widget coverage
  // existed anywhere for the Overdue/Completed/>100% status displays,
  // for the milestone chips actually reflecting reached-vs-not-reached
  // state, for the target-date/recommended-daily-contribution detail
  // rows rendering together, or for the double-submit re-entrancy guard
  // this checkpoint added to `_AddContributionDialogState._submit`.
  // ---------------------------------------------------------------------
  group('Checkpoint S -- completion, overdue, milestones, duplicate submission', () {
    testWidgets(
      'a goal funded to exactly 60% shows the 25%/50% milestones as reached and 75%/100% as '
      'not yet reached',
      (tester) async {
        final (AppDatabase db, String profileId) = await seededDb();
        final SavingsGoalRepository goalRepo = SavingsGoalRepository(db);
        final String goalId = await goalRepo.createGoal(
          profileId: profileId,
          name: 'Emergency Fund',
          targetAmount: Money.fromMinorUnits(100000, 'JPY'),
        );
        final SavingsGoalContributionRepository contributionRepo =
            SavingsGoalContributionRepository(db, goalRepo);
        await contributionRepo.addContribution(goalId: goalId, amount: Money.fromMinorUnits(60000, 'JPY'));

        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithGoalDetail(container, goalId));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final BuildContext context = tester.element(find.byKey(const Key('goalSavedAmount')));
        final ColorScheme colors = Theme.of(context).colorScheme;

        Chip chipLabeled(String label) => tester.widget<Chip>(find.widgetWithText(Chip, label));

        expect(chipLabeled('25%').backgroundColor, colors.primaryContainer); // reached
        expect(chipLabeled('50%').backgroundColor, colors.primaryContainer); // reached
        expect(chipLabeled('75%').backgroundColor, colors.surfaceContainerHighest); // not reached
        expect(chipLabeled('100%').backgroundColor, colors.surfaceContainerHighest); // not reached
        expect(find.byIcon(Icons.check), findsNWidgets(2)); // only the two reached chips
      },
    );

    testWidgets(
      'an exactly-100%-funded goal shows Completed, ¥0 remaining, all four milestones '
      'reached, and a fully-filled progress bar',
      (tester) async {
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
          amount: Money.fromMinorUnits(100000, 'JPY'),
        );

        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithGoalDetail(container, goalId));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Completed'), findsOneWidget);
        // A completed goal's "recommended daily contribution" is ALSO a
        // real Money.zero (ADR-022 point 2 -- completed always answers
        // zero, never null, regardless of target date), so a bare
        // `find.text('¥0')` would match both that row and the Remaining
        // row; scope to the Remaining row's own Row specifically.
        final Finder remainingRow =
            find.ancestor(of: find.text('Remaining'), matching: find.byType(Row)).first;
        expect(find.descendant(of: remainingRow, matching: find.text('¥0')), findsOneWidget);
        // Scoped to the "· 100%" summary-line form -- distinct from
        // the milestone chip that also reads the bare text '100%'.
        expect(find.textContaining('· 100%'), findsOneWidget);
        expect(find.byIcon(Icons.check), findsNWidgets(4)); // every milestone reached
        expect(tester.widget<AppProgressBar>(find.byType(AppProgressBar)).value, 1.0);
      },
    );

    testWidgets(
      'an overfunded goal (target ¥20,000, saved ¥25,000) shows the uncapped 125%, '
      '¥0 remaining, Completed, and a fully-filled but never-overflowed progress bar',
      (tester) async {
        final (AppDatabase db, String profileId) = await seededDb();
        final SavingsGoalRepository goalRepo = SavingsGoalRepository(db);
        final String goalId = await goalRepo.createGoal(
          profileId: profileId,
          name: 'Emergency Fund',
          targetAmount: Money.fromMinorUnits(20000, 'JPY'),
        );
        final SavingsGoalContributionRepository contributionRepo =
            SavingsGoalContributionRepository(db, goalRepo);
        await contributionRepo.addContribution(goalId: goalId, amount: Money.fromMinorUnits(25000, 'JPY'));

        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithGoalDetail(container, goalId));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Completed'), findsOneWidget);
        // Same "recommended daily contribution is also ¥0" collision as
        // the exact-100% test above -- scope to the Remaining row.
        final Finder remainingRow =
            find.ancestor(of: find.text('Remaining'), matching: find.byType(Row)).first;
        expect(
          find.descendant(of: remainingRow, matching: find.text('¥0')),
          findsOneWidget,
        ); // remaining row, never negative
        expect(find.textContaining('· 125%'), findsOneWidget); // uncapped, never "100%"
        expect(find.byIcon(Icons.check), findsNWidgets(4));
        // The bar's fill fraction clamps to 1.0 -- it cannot visually
        // render past full -- while the text above stays truthfully 125%.
        expect(tester.widget<AppProgressBar>(find.byType(AppProgressBar)).value, 1.0);
      },
    );

    testWidgets(
      'an overdue, unfunded goal with a past target date shows Overdue and no recommended '
      'daily contribution row',
      (tester) async {
        final (AppDatabase db, String profileId) = await seededDb();
        final SavingsGoalRepository goalRepo = SavingsGoalRepository(db);
        final String goalId = await goalRepo.createGoal(
          profileId: profileId,
          name: 'Emergency Fund',
          targetAmount: Money.fromMinorUnits(100000, 'JPY'),
          targetDate: DateTime.now().toUtc().subtract(const Duration(days: 2)),
        );

        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithGoalDetail(container, goalId));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Overdue'), findsOneWidget);
        expect(find.text('Recommended daily contribution'), findsNothing); // not applicable
        expect(find.byType(Chip), findsNothing); // 0% saved -- no milestone reached yet
      },
    );

    testWidgets(
      'a future target date and a recommended daily contribution both render as detail rows',
      (tester) async {
        final (AppDatabase db, String profileId) = await seededDb();
        final SavingsGoalRepository goalRepo = SavingsGoalRepository(db);
        final String goalId = await goalRepo.createGoal(
          profileId: profileId,
          name: 'Emergency Fund',
          targetAmount: Money.fromMinorUnits(50000, 'JPY'),
          targetDate: DateTime.now().toUtc().add(const Duration(days: 10)),
        );
        final SavingsGoalContributionRepository contributionRepo =
            SavingsGoalContributionRepository(db, goalRepo);
        await contributionRepo.addContribution(goalId: goalId, amount: Money.fromMinorUnits(10000, 'JPY'));

        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithGoalDetail(container, goalId));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Target date'), findsOneWidget);
        expect(find.text('Recommended daily contribution'), findsOneWidget);
        // 40000 remaining over 11 remaining days (today + 10 counts as day
        // one) -- ceiling division, never floor (ADR-022 point 2).
        expect(find.text('¥3,637'), findsOneWidget); // ceil(40000 / 11) = 3637
      },
    );

    testWidgets(
      "rapid double-tap on Add Contribution's save button records only one contribution, not "
      'two',
      (tester) async {
        final (AppDatabase db, String profileId) = await seededDb();
        final SavingsGoalRepository goalRepo = SavingsGoalRepository(db);
        final String goalId = await goalRepo.createGoal(
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
        await tester.enterText(find.byKey(const Key('contributionAmountField')), '30000');

        // NOT two physical `tester.tap()` calls: a first investigation
        // round used that pattern and a real Windows `flutter test` run
        // caught it as a potential false positive -- `tester.tap()`'s own
        // internal gesture-dispatch code contains genuine `await` points
        // (TestAsyncUtils.guard/startGesture/gesture.up()), and Dart
        // yields to the microtask queue at every `await`, even one that
        // resolves immediately. That is enough for the FIRST tap's
        // `_submit()` to run its pending `await addContribution(...)` to
        // completion and pop the dialog (a genuine async Future
        // continuation, unlike the Timer-based Drift stream hangs
        // documented elsewhere in this repo -- no `pump()` is needed for
        // a plain Future to progress) before the SECOND tap's hit-test
        // ever runs. Once the dialog is gone/mid-transition, the second
        // tap's precomputed offset no longer lands on the (now stale)
        // `FilledButton`, so Flutter warns that the tap missed -- and,
        // worse, "only one contribution recorded" would then be true for
        // an uninteresting reason (the second tap hit nothing) rather
        // than because the `_isSaving` guard actually intercepted a
        // second concurrent submit.
        //
        // Instead: fetch the CURRENT `FilledButton` widget once, then
        // invoke its `onPressed` callback -- the real `_submit` closure
        // `_AddContributionDialogState.build` actually wired up -- twice
        // in a row with NO `await` between the two calls. Two
        // back-to-back synchronous statements never yield to the
        // microtask queue, so this deterministically fires `_submit()`
        // twice before either call's `await addContribution(...)` can
        // resolve, which is exactly the re-entrancy hazard the
        // `_isSaving` guard (ADR-042) defends against -- without any
        // gesture/hit-testing involved, and without touching production
        // code or adding a test-only seam.
        final FilledButton saveButton =
            tester.widget<FilledButton>(find.byKey(const Key('saveContribution')));
        saveButton.onPressed!();
        saveButton.onPressed!();
        await tester.pumpAndSettle();

        expect(find.text('Add a contribution'), findsNothing); // dialog closed
        // A one-shot query against the table directly, NOT
        // `contributionRepo.watchActiveForGoal(goalId).first` -- a Drift
        // query `Stream`'s `.first` is a documented hang risk in this
        // suite (see e.g. `savings_goal_contribution_repository_test.dart`'s
        // use of `db.select(db.transactions).get()` for the same reason):
        // it waits for the stream's *next* qualifying emission, and
        // nothing here guarantees one arrives on a schedule this test can
        // rely on. A one-shot `.get()` reads the current row set directly
        // and returns as soon as that single query resolves.
        final List<SavingsGoalContributionRow> rows = await (db.select(db.savingsGoalContributions)
              ..where((tbl) => tbl.goalId.equals(goalId) & tbl.deletedAt.isNull()))
            .get();
        expect(rows, hasLength(1)); // not 2
        expect(rows.single.amountMinorUnits, 30000);
        expect(
          tester.widget<Text>(find.byKey(const Key('goalSavedAmount'))).data,
          '¥30,000', // not ¥60,000
        );
      },
    );

    testWidgets(
      "the same re-entrancy guard on Edit Goal's save button records only one update, not two",
      (tester) async {
        final (AppDatabase db, String profileId) = await seededDb();
        final SavingsGoalRepository goalRepo = SavingsGoalRepository(db);
        final String goalId = await goalRepo.createGoal(
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
        await tester.enterText(find.byKey(const Key('editGoalNameField')), 'New Name');
        await tester.enterText(find.byKey(const Key('editGoalTargetAmountField')), '200000');

        // Same technique as the Add Contribution test above -- see that
        // test's comment for why two physical `tester.tap()` calls would
        // be a potential false positive here too. `_EditGoalDialogState
        // ._submit` carries the identical `if (_isSaving) return;` guard
        // (ADR-042).
        final FilledButton saveButton =
            tester.widget<FilledButton>(find.byKey(const Key('saveEditGoal')));
        saveButton.onPressed!();
        saveButton.onPressed!();
        await tester.pumpAndSettle();

        expect(find.text('Edit goal'), findsNothing); // dialog closed
        final SavingsGoalRow row = await goalRepo.requireActiveGoal(goalId);
        expect(row.name, 'New Name'); // not corrupted by a second concurrent write
        expect(row.targetAmountMinorUnits, 200000);
      },
    );
  });

  // ---------------------------------------------------------------------
  // Visual System Convergence Checkpoint 7.4: locks in the hero section's
  // and each contribution row's new bordered-card visual treatment
  // (`AppCard(bordered: true)`) via the same shape/side/color contract
  // `app_card_test.dart`/`accounts_screen_test.dart` already assert for
  // `AppCard` -- never a pixel value. Also confirms the saved amount and
  // a contribution amount still render in full, unformatted-by-us.
  // ---------------------------------------------------------------------
  testWidgets(
    'CP7.4: the hero section and a contribution row each render inside a bordered, '
    'near-white card matching the converged visual system',
    (tester) async {
      final (AppDatabase db, String profileId) = await seededDb();
      final SavingsGoalRepository goalRepo = SavingsGoalRepository(db);
      final String goalId = await goalRepo.createGoal(
        profileId: profileId,
        name: 'Emergency Fund',
        targetAmount: Money.fromMinorUnits(100000, 'JPY'),
      );
      final SavingsGoalContributionRepository contributionRepo =
          SavingsGoalContributionRepository(db, goalRepo);
      final String contributionId = await contributionRepo.addContribution(
        goalId: goalId,
        amount: Money.fromMinorUnits(30000, 'JPY'),
      );
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithGoalDetail(container, goalId));
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(find.byKey(const Key('goalSavedAmount')));
      final ColorScheme colors = Theme.of(context).colorScheme;
      final AppTokens tokens = context.appTokens;

      void expectBorderedCard(Finder anchor) {
        final Card cardWidget = tester.widget<Card>(
          find.ancestor(of: anchor, matching: find.byType(Card)).first,
        );
        expect(cardWidget.color, colors.surface);
        expect(cardWidget.elevation, 0);
        final RoundedRectangleBorder shape = cardWidget.shape! as RoundedRectangleBorder;
        expect(shape.side.color, tokens.colors.subtleBorder);
      }

      expectBorderedCard(find.byKey(const Key('goalSavedAmount')));
      expectBorderedCard(find.byKey(Key('contributionTile_$contributionId')));

      expect(tester.widget<Text>(find.byKey(const Key('goalSavedAmount'))).data, '¥30,000');
      expect(find.text('¥30,000'), findsWidgets); // hero amount + contribution row amount
    },
  );
}
