import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/providers.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/savings_goal_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/savings_goal_contribution_repository.dart';
import 'package:ai_financial_coach/core/money/money.dart';
import 'package:ai_financial_coach/core/routing/app_routes.dart';
import 'package:ai_financial_coach/features/goals/presentation/goal_detail_screen.dart';
import 'package:ai_financial_coach/features/goals/presentation/savings_goals_screen.dart';
import 'package:ai_financial_coach/l10n/generated/app_localizations.dart';
import 'package:ai_financial_coach/shared/theme/app_tokens.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// NOTE: exercises generated Drift code — see CLAUDE_FIRST_CODING_PROMPT.md.

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

  Widget appWithGoals(ProviderContainer container, {Locale locale = const Locale('en')}) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SavingsGoalsScreen(),
      ),
    );
  }

  /// Like [appWithGoals], but with a real `GoRouter` ancestor wired
  /// exactly like `lib/core/routing/app_router.dart`'s own
  /// goals/goalDetail registration -- so tapping a goal tile's real
  /// `context.push(AppRoutes.goalDetail(...))` call lands on the real
  /// `GoalDetailScreen`, not a stub. CP6.6 test K uses this to confirm
  /// the list -> detail navigation path still works under the Japanese
  /// locale.
  Widget appWithGoalsRouter(ProviderContainer container, {Locale locale = const Locale('en')}) {
    final GoRouter router = GoRouter(
      initialLocation: AppRoutes.goals,
      routes: <RouteBase>[
        GoRoute(path: AppRoutes.goals, builder: (context, state) => const SavingsGoalsScreen()),
        GoRoute(
          path: AppRoutes.goalDetailPath,
          builder: (context, state) => GoalDetailScreen(goalId: state.pathParameters['id']!),
        ),
      ],
    );
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
  }

  /// Same deterministic shutdown sequence as
  /// `test/widget/budgets_screen_test.dart`'s `disposeInOrder`: unmount,
  /// then dispose, then one `pumpAndSettle()` so Drift's
  /// `StreamQueryStore.markAsClosed` `Timer.zero` fires before
  /// `db.close()`.
  Future<void> disposeInOrder(WidgetTester tester, ProviderContainer container, AppDatabase db) async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pumpAndSettle();
    await db.close();
  }

  testWidgets('the empty state is shown when there are no goals yet', (tester) async {
    final (AppDatabase db, _) = await seededDb();
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithGoals(container));
    await tester.pumpAndSettle();

    expect(find.textContaining('No savings goals yet'), findsOneWidget);
  });

  testWidgets('creating a goal with no target date shows it in the list', (tester) async {
    final (AppDatabase db, _) = await seededDb();
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithGoals(container));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('addGoalFab')));
    await tester.pumpAndSettle();
    expect(find.text('New savings goal'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('goalNameField')), 'Emergency Fund');
    await tester.enterText(find.byKey(const Key('goalTargetAmountField')), '120000');
    await tester.tap(find.byKey(const Key('saveGoal')));
    await tester.pumpAndSettle();

    expect(find.text('New savings goal'), findsNothing); // dialog closed
    expect(find.text('Emergency Fund'), findsOneWidget);
    expect(find.textContaining('¥120,000'), findsOneWidget);
    expect(find.textContaining('0%'), findsOneWidget); // nothing saved yet
  });

  testWidgets('the goal name field rejects an empty/whitespace-only name', (tester) async {
    final (AppDatabase db, _) = await seededDb();
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithGoals(container));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('addGoalFab')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('goalNameField')), '   ');
    await tester.enterText(find.byKey(const Key('goalTargetAmountField')), '120000');
    await tester.tap(find.byKey(const Key('saveGoal')));
    await tester.pumpAndSettle();

    // The dialog is still open -- form validation blocked the save.
    expect(find.text('New savings goal'), findsOneWidget);
  });

  testWidgets('a goal created with a target date shows it in the list', (tester) async {
    final (AppDatabase db, String profileId) = await seededDb();
    await SavingsGoalRepository(db).createGoal(
      profileId: profileId,
      name: 'Holiday Fund',
      targetAmount: Money.fromMinorUnits(80000, 'JPY'),
      targetDate: DateTime.utc(2026, 12, 25),
    );
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithGoals(container));
    await tester.pumpAndSettle();

    expect(find.text('Holiday Fund'), findsOneWidget);
    expect(find.textContaining('¥80,000'), findsOneWidget);
  });

  testWidgets('the goals screen lays out without overflow on a narrow (320px-wide) screen '
      'with several goals', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1.0;

    final (AppDatabase db, String profileId) = await seededDb();
    final SavingsGoalRepository goalRepo = SavingsGoalRepository(db);
    await goalRepo.createGoal(
      profileId: profileId,
      name: 'A very long savings goal name that could wrap awkwardly',
      targetAmount: Money.fromMinorUnits(1000000, 'JPY'),
      targetDate: DateTime.utc(2026, 12, 25),
    );
    await goalRepo.createGoal(
      profileId: profileId,
      name: 'Short Goal',
      targetAmount: Money.fromMinorUnits(50000, 'JPY'),
    );
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithGoals(container));
    await tester.pumpAndSettle();

    final Object? overflowException = tester.takeException();
    if (overflowException != null) {
      fail('Narrow-screen (320px) goals screen layout threw an exception:\n\n$overflowException');
    }
  });

  // CP5.4b: `_GoalListTile.subtitle`'s combined
  // "$saved of $target \u00b7 $percent% \u00b7 $status" string is one
  // plain `Text` with no `overflow`/`maxLines` set -- it wraps rather
  // than clips (per the CP5.4 audit), so this stress case confirms
  // every digit of a large, precision-sensitive currency amount still
  // survives intact (not abbreviated, not dropped) alongside a long
  // goal name at a narrow width and a large text scale, without
  // requiring the line to stay single-line.
  testWidgets(
      'CP5.4b: a long goal name and a large 3-decimal KWD saved/target amount survive intact '
      'at a narrow 320px width and a 1.6x text scale', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    const String longName = 'A rather long savings goal name to stress narrow-width layout';
    final (AppDatabase db, String profileId) = await seededDb();
    final SavingsGoalRepository goalRepo = SavingsGoalRepository(db);
    final String goalId = await goalRepo.createGoal(
      profileId: profileId,
      name: longName,
      // \u062F.\u064324,691.356 -- double the contribution below, so
      // wholePercentSaved lands on an exact 50 with no rounding
      // ambiguity to reproduce.
      targetAmount: Money.fromMinorUnits(24691356, 'KWD'),
    );
    final SavingsGoalContributionRepository contributionRepo =
        SavingsGoalContributionRepository(db, goalRepo);
    await contributionRepo.addContribution(
      goalId: goalId,
      // \u062F.\u064312,345.678 -- KWD has 3 minor units per
      // `CurrencyRegistry`, not 0; same magnitude already verified
      // correct by a real Windows run in CP5.2a/CP5.4a.
      amount: Money.fromMinorUnits(12345678, 'KWD'),
    );

    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithGoals(container));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    // Scoped to this specific goal's own tile -- not a page-wide
    // find.textContaining(...) -- since the subtitle is one combined
    // Text and a page-wide substring search could in principle collide
    // if this fixture ever grew to seed more than one goal.
    final Finder tile = find.byKey(Key('goalTile_$goalId'));
    expect(tile, findsOneWidget);
    expect(
      find.descendant(of: tile, matching: find.textContaining('\u062F.\u064312,345.678')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: tile, matching: find.textContaining('\u062F.\u064324,691.356')),
      findsOneWidget,
    );
    expect(find.descendant(of: tile, matching: find.textContaining('50%')), findsOneWidget);
    expect(find.descendant(of: tile, matching: find.textContaining('In progress')), findsOneWidget);
  });

  // CP6.6: Savings Goals list Japanese localization. Re-uses every
  // seeding/layout-key helper above unchanged; only `appWithGoals` grew
  // a `locale` parameter (default 'en', so every test above this point
  // is unaffected).
  group('CP6.6 Japanese localization', () {
    testWidgets(
      'A: standard Japanese Savings Goals list renders a localized AppBar, status label, and '
      'the "of {target}" phrase, with an untouched goal name',
      (tester) async {
        final (AppDatabase db, String profileId) = await seededDb();
        await SavingsGoalRepository(db).createGoal(
          profileId: profileId,
          name: 'Emergency Fund',
          targetAmount: Money.fromMinorUnits(100000, 'JPY'), // ¥100,000
        );
        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithGoals(container, locale: const Locale('ja')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('貯蓄目標'), findsOneWidget); // AppBar (savingsGoalsTitle)
        expect(find.text('Emergency Fund'), findsOneWidget); // goal name -- untouched
        expect(find.textContaining('¥100,000のうち'), findsOneWidget); // ofAmount(target)
        expect(find.textContaining('進行中'), findsOneWidget); // goalStatusInProgress
      },
    );

    testWidgets(
      'B: a Japanese-language user-entered goal name renders exactly as stored, alongside '
      'the localized status label',
      (tester) async {
        const String japaneseGoalName = '日本旅行2027';
        final (AppDatabase db, String profileId) = await seededDb();
        await SavingsGoalRepository(db).createGoal(
          profileId: profileId,
          name: japaneseGoalName,
          targetAmount: Money.fromMinorUnits(500000, 'JPY'),
        );
        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithGoals(container, locale: const Locale('ja')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        // The stored name is reproduced verbatim -- no l10n lookup ever
        // runs against user data, so a Japanese-language goal name is
        // neither mistranslated nor duplicated.
        expect(find.text(japaneseGoalName), findsOneWidget);
      },
    );

    testWidgets(
      'D: Japanese + MMK renders its registry-defined 2 decimal places (never 0) in a goal '
      "tile's saved/target amounts",
      (tester) async {
        final (AppDatabase db, String profileId) = await seededDb();
        final SavingsGoalRepository goalRepo = SavingsGoalRepository(db);
        final String goalId = await goalRepo.createGoal(
          profileId: profileId,
          name: 'MMK Goal',
          targetAmount: Money.fromMinorUnits(200000000, 'MMK'), // K2,000,000.00
        );
        final SavingsGoalContributionRepository contributionRepo =
            SavingsGoalContributionRepository(db, goalRepo);
        await contributionRepo.addContribution(
          goalId: goalId,
          amount: Money.fromMinorUnits(150075, 'MMK'), // K1,500.75
        );
        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithGoals(container, locale: const Locale('ja')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final Finder tile = find.byKey(Key('goalTile_$goalId'));
        expect(
          find.descendant(of: tile, matching: find.textContaining('K1,500.75')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: tile, matching: find.textContaining('K2,000,000.00')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'E: Japanese + a large 0-decimal VND goal keeps every digit of saved/target intact',
      (tester) async {
        final (AppDatabase db, String profileId) = await seededDb();
        final SavingsGoalRepository goalRepo = SavingsGoalRepository(db);
        final String goalId = await goalRepo.createGoal(
          profileId: profileId,
          name: 'VND Goal',
          targetAmount: Money.fromMinorUnits(1999999998, 'VND'),
        );
        final SavingsGoalContributionRepository contributionRepo =
            SavingsGoalContributionRepository(db, goalRepo);
        await contributionRepo.addContribution(
          goalId: goalId,
          amount: Money.fromMinorUnits(999999999, 'VND'), // ₫999,999,999
        );
        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithGoals(container, locale: const Locale('ja')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final Finder tile = find.byKey(Key('goalTile_$goalId'));
        expect(
          find.descendant(of: tile, matching: find.textContaining('₫999,999,999')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'F: Japanese + a large 3-decimal KWD goal keeps every digit of saved/target intact',
      (tester) async {
        final (AppDatabase db, String profileId) = await seededDb();
        final SavingsGoalRepository goalRepo = SavingsGoalRepository(db);
        final String goalId = await goalRepo.createGoal(
          profileId: profileId,
          name: 'KWD Goal',
          targetAmount: Money.fromMinorUnits(24691356, 'KWD'),
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

        await tester.pumpWidget(appWithGoals(container, locale: const Locale('ja')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final Finder tile = find.byKey(Key('goalTile_$goalId'));
        expect(
          find.descendant(of: tile, matching: find.textContaining('د.ك12,345.678')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'G: Japanese + 1.6x text scale renders the goals list without exceptions',
      (tester) async {
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        tester.platformDispatcher.textScaleFactorTestValue = 1.6;

        final (AppDatabase db, String profileId) = await seededDb();
        await SavingsGoalRepository(db).createGoal(
          profileId: profileId,
          name: 'Emergency Fund',
          targetAmount: Money.fromMinorUnits(100000, 'JPY'),
        );
        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithGoals(container, locale: const Locale('ja')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('貯蓄目標'), findsOneWidget);
      },
    );

    testWidgets(
      'H: Japanese + 2.0x text scale renders the goals list without exceptions',
      (tester) async {
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;

        final (AppDatabase db, String profileId) = await seededDb();
        await SavingsGoalRepository(db).createGoal(
          profileId: profileId,
          name: 'Emergency Fund',
          targetAmount: Money.fromMinorUnits(100000, 'JPY'),
        );
        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithGoals(container, locale: const Locale('ja')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('貯蓄目標'), findsOneWidget);
      },
    );

    testWidgets(
      'I: 320px narrow width + Japanese + 1.6x text scale + a long Japanese goal name + a '
      'large international (KWD) amount lays out without exceptions',
      (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1.0;
        tester.platformDispatcher.textScaleFactorTestValue = 1.6;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        const String longJapaneseName = '狭い画面でのレイアウトを確認するための、かなり長い貯蓄目標名';
        final (AppDatabase db, String profileId) = await seededDb();
        final SavingsGoalRepository goalRepo = SavingsGoalRepository(db);
        final String goalId = await goalRepo.createGoal(
          profileId: profileId,
          name: longJapaneseName,
          targetAmount: Money.fromMinorUnits(24691356, 'KWD'),
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

        await tester.pumpWidget(appWithGoals(container, locale: const Locale('ja')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final Finder tile = find.byKey(Key('goalTile_$goalId'));
        expect(tile, findsOneWidget);
        expect(find.descendant(of: tile, matching: find.text(longJapaneseName)), findsOneWidget);
        expect(
          find.descendant(of: tile, matching: find.textContaining('د.ك12,345.678')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'J: action regression -- creating a goal under the Japanese locale shows a fully '
      'localized dialog, and submitting it still creates a real, persisted goal that '
      'appears in the (still Japanese) list',
      (tester) async {
        final (AppDatabase db, _) = await seededDb();
        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithGoals(container, locale: const Locale('ja')));
        await tester.pumpAndSettle();

        expect(find.textContaining('貯蓄目標がまだありません'), findsOneWidget);

        await tester.tap(find.byKey(const Key('addGoalFab')));
        await tester.pumpAndSettle();
        expect(find.text('新しい貯蓄目標'), findsOneWidget); // newSavingsGoalDialogTitle
        expect(find.text('目標名'), findsOneWidget); // goalNameLabel
        expect(find.text('目標金額'), findsOneWidget); // targetAmountLabel
        expect(find.text('目標日なし'), findsOneWidget); // noTargetDateMessage

        await tester.enterText(find.byKey(const Key('goalNameField')), 'Emergency Fund');
        await tester.enterText(find.byKey(const Key('goalTargetAmountField')), '120000');
        await tester.tap(find.byKey(const Key('saveGoal')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('新しい貯蓄目標'), findsNothing); // dialog closed
        expect(find.text('Emergency Fund'), findsOneWidget);
        expect(find.textContaining('¥120,000のうち'), findsOneWidget);
      },
    );

    testWidgets(
      'K: navigation regression -- tapping a goal tile under the Japanese locale still '
      'navigates to the real Goal Detail screen, which renders with localized labels',
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

        await tester.pumpWidget(appWithGoalsRouter(container, locale: const Locale('ja')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(Key('goalTile_$goalId')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        // Landed on the real GoalDetailScreen -- its own localized
        // "Remaining" label (残り) and untouched goal name both render,
        // confirming this isn't a stub route.
        expect(find.text('残り'), findsOneWidget); // remainingLabel
        expect(find.text('Emergency Fund'), findsWidgets); // app bar + body
      },
    );
  });

  // ---------------------------------------------------------------------
  // Visual System Convergence Checkpoint 7.4: locks in the goal tile's new
  // bordered-card visual treatment (`AppCard(bordered: true)`) via the
  // same shape/side/color contract `app_card_test.dart`/
  // `accounts_screen_test.dart` already assert for `AppCard` -- never a
  // pixel value.
  // ---------------------------------------------------------------------
  testWidgets(
    'CP7.4: a goal tile renders inside a bordered, near-white card matching the converged '
    'visual system',
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

      await tester.pumpWidget(appWithGoals(container));
      await tester.pumpAndSettle();

      final Finder tileKey = find.byKey(Key('goalTile_$goalId'));
      final Card cardWidget = tester.widget<Card>(
        find.ancestor(of: tileKey, matching: find.byType(Card)).first,
      );
      final BuildContext context = tester.element(tileKey);
      final ColorScheme colors = Theme.of(context).colorScheme;
      final AppTokens tokens = context.appTokens;

      expect(cardWidget.color, colors.surface);
      expect(cardWidget.elevation, 0);
      final RoundedRectangleBorder shape = cardWidget.shape! as RoundedRectangleBorder;
      expect(shape.side.color, tokens.colors.subtleBorder);
    },
  );
}
