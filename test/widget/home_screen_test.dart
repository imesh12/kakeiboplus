import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/providers.dart';
import 'package:ai_financial_coach/core/database/repositories/account_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/budget_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/recurring_rule_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/savings_goal_contribution_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/savings_goal_repository.dart';
import 'package:ai_financial_coach/core/money/money.dart';
import 'package:ai_financial_coach/core/routing/app_routes.dart';
import 'package:ai_financial_coach/features/budgets/domain/budget_month.dart';
import 'package:ai_financial_coach/features/dashboard/presentation/home_screen.dart';
import 'package:ai_financial_coach/features/recurring/domain/recurrence_frequency.dart';
import 'package:ai_financial_coach/features/recurring/domain/recurring_rule_kind.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// NOTE: exercises generated Drift code — see CLAUDE_FIRST_CODING_PROMPT.md.
//
// Beta 1 Task 1 UI polish pass. These tests cover presentation only --
// the underlying dashboard calculations already have dedicated coverage
// in `test/core/dashboard/dashboard_providers_test.dart` and
// `test/core/finance/finance_engine_test.dart`, so nothing here re-checks
// arithmetic. They exist to lock in: the hero/secondary currency split
// never combining currencies, the negative-balance treatment, that the
// narrow-screen layout doesn't throw, and the two forward-compatible
// empty states (budget, upcoming commitments).

class _SeedAccount {
  const _SeedAccount({required this.name, required this.currencyCode, this.openingBalance});

  final String name;
  final String currencyCode;
  final Money? openingBalance;
}

void main() {
  Future<AppDatabase> seededDb({
    required String living,
    required String home,
    required List<_SeedAccount> accounts,
  }) async {
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    final ProfileRepository profileRepo = ProfileRepository(db);
    final AccountRepository accountRepo = AccountRepository(db);
    final String profileId = await profileRepo.createProfile(
      displayName: 'Test User',
      homeCountry: 'LK',
      currentCountry: 'JP',
      homeCurrency: home,
      livingCurrency: living,
      preferredLanguage: 'en',
      timezone: 'Asia/Tokyo',
      dateFormat: 'yyyy-MM-dd',
      numberFormat: '#,##0.##',
    );
    for (final _SeedAccount account in accounts) {
      await accountRepo.createAccount(
        profileId: profileId,
        name: account.name,
        type: 'cash',
        currencyCode: account.currencyCode,
        openingBalance: account.openingBalance,
      );
    }
    return db;
  }

  /// No `GoRouter` and no navigation is exercised by any test below (the
  /// only navigating control on the screen is the "Manage" button, which
  /// none of these tests tap), so `HomeScreen` can be mounted directly as
  /// `MaterialApp.home` -- there is no need for the push-on-top-of-a-
  /// placeholder-route harness `add_transaction_screen_test.dart` uses.
  Widget appWithHome(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: HomeScreen()),
    );
  }

  /// Like [appWithHome], but with a real (minimal) `GoRouter` ancestor so
  /// a `context.push(AppRoutes.budgets)` call -- the budget card's CTA
  /// and "Manage" button both do this -- has somewhere to actually
  /// navigate to, instead of throwing for lack of a `GoRouter` ancestor.
  /// The budgets route is a recognizable stub, not the real
  /// `BudgetsScreen` -- these tests are about *HomeScreen* triggering
  /// navigation, not about what the budgets screen itself renders (that
  /// belongs to `test/widget/budgets_screen_test.dart`).
  Widget appWithRouter(ProviderContainer container) {
    final GoRouter router = GoRouter(
      initialLocation: '/home',
      routes: <RouteBase>[
        GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
        GoRoute(
          path: AppRoutes.budgets,
          builder: (context, state) => const Scaffold(body: Text('BUDGETS_SCREEN_STUB')),
        ),
        GoRoute(
          path: AppRoutes.goals,
          builder: (context, state) => const Scaffold(body: Text('GOALS_SCREEN_STUB')),
        ),
        GoRoute(
          path: AppRoutes.recurring,
          builder: (context, state) => const Scaffold(body: Text('RECURRING_SCREEN_STUB')),
        ),
      ],
    );
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    );
  }

  /// Same deterministic shutdown sequence as
  /// `add_transaction_screen_test.dart`'s `disposeInOrder`: unmount, then
  /// dispose the container, then one `pumpAndSettle()` so Drift's
  /// `StreamQueryStore.markAsClosed` `Timer.zero` fires before `db.close()`
  /// -- plain `tester.pump()` never elapses `FakeAsync`'s clock, so it
  /// can't fire that timer.
  Future<void> disposeInOrder(WidgetTester tester, ProviderContainer container, AppDatabase db) async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pumpAndSettle();
    await db.close();
  }

  /// The default flutter_test surface (800x600 logical px) is shorter than
  /// this screen's full scrollable content (hero card + budget card +
  /// commitments card + accounts section). A `ListView`'s underlying
  /// `Sliver` only mounts children within the current viewport plus its
  /// cache extent -- widgets further down are never built into the
  /// element tree at all, so `find.*` can't see them even though nothing
  /// is visually wrong. Using a generously tall surface for every test
  /// below that finds a specific widget (everything except the
  /// narrow-width test, which only asserts `tester.takeException()`)
  /// keeps each assertion independent of exactly how tall the content
  /// happens to be, without ever touching what's actually being asserted.
  void useTallSurface(WidgetTester tester) {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(400, 2000);
    tester.view.devicePixelRatio = 1.0;
  }

  testWidgets(
    'the living currency renders as the hero card with a "Living currency" badge, and a '
    'second currency the user holds renders as a distinct secondary card with its own '
    '"Home currency" badge -- never combined into one figure',
    (tester) async {
      useTallSurface(tester);
      final AppDatabase db = await seededDb(
        living: 'JPY',
        home: 'LKR',
        accounts: <_SeedAccount>[
          const _SeedAccount(name: 'JPY Wallet', currencyCode: 'JPY'),
          const _SeedAccount(name: 'LKR Wallet', currencyCode: 'LKR'),
        ],
      );
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithHome(container));
      await tester.pumpAndSettle();

      // Exactly one hero (JPY, living-first) and one secondary (LKR,
      // home) card -- each currency gets its own badge, never a single
      // combined figure.
      expect(find.text('Living currency'), findsOneWidget);
      expect(find.text('Home currency'), findsOneWidget);
      expect(find.text('JPY'), findsWidgets);
      expect(find.text('LKR'), findsWidgets);
    },
  );

  testWidgets(
    "a negative balance keeps its minus sign and shows the negative-balance indicator only "
    'on that currency\'s card -- not on a different, positive-balance currency card, and not '
    'confused with the same amount possibly also appearing in the per-account balance list',
    (tester) async {
      useTallSurface(tester);
      // Two currencies on purpose: USD (living -> hero card, negative)
      // and EUR (home -> secondary card, positive). This is what makes
      // the regression meaningful -- it proves the negative-balance
      // indicator is scoped to the negative currency's own card rather
      // than merely "found somewhere on the screen", which is exactly
      // what let a duplicate match (e.g. the per-account balance list
      // also rendering "-$50.00") slip past a page-wide assertion.
      final AppDatabase db = await seededDb(
        living: 'USD',
        home: 'EUR',
        accounts: <_SeedAccount>[
          _SeedAccount(
            name: 'USD Card',
            currencyCode: 'USD',
            openingBalance: Money.fromMinorUnits(-5000, 'USD'),
          ),
          _SeedAccount(
            name: 'EUR Wallet',
            currencyCode: 'EUR',
            openingBalance: Money.fromMinorUnits(20000, 'EUR'),
          ),
        ],
      );
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithHome(container));
      await tester.pumpAndSettle();

      // `_HeroCurrencyCard`/`_SecondaryCurrencyCard` carry stable
      // `heroCurrencyCard_<code>` / `secondaryCurrencyCard_<code>` keys
      // specifically so tests can scope a finder to one currency's card
      // instead of asserting over the whole page (where the same
      // formatted balance can legitimately also appear in the
      // per-account balance list below).
      final Finder heroCard = find.byKey(const Key('heroCurrencyCard_USD'));
      final Finder secondaryCard = find.byKey(const Key('secondaryCurrencyCard_EUR'));
      expect(heroCard, findsOneWidget);
      expect(secondaryCard, findsOneWidget);

      // The negative (USD, hero) card keeps the minus sign and shows the
      // negative indicator.
      expect(
        find.descendant(of: heroCard, matching: find.textContaining('-\$50.00')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: heroCard, matching: find.byIcon(Icons.south_rounded)),
        findsOneWidget,
      );

      // The positive (EUR, secondary) card must not carry the negative
      // indicator -- proving it's scoped to the negative currency, not
      // shown globally.
      expect(
        find.descendant(of: secondaryCard, matching: find.byIcon(Icons.south_rounded)),
        findsNothing,
      );
    },
  );

  testWidgets(
    'the dashboard lays out without overflow or layout exceptions on a narrow (320px-wide) '
    'screen, with multiple currencies present',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1.0;

      final AppDatabase db = await seededDb(
        living: 'JPY',
        home: 'LKR',
        accounts: <_SeedAccount>[
          const _SeedAccount(name: 'JPY Wallet', currencyCode: 'JPY'),
          const _SeedAccount(name: 'LKR Wallet', currencyCode: 'LKR'),
        ],
      );
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithHome(container));
      await tester.pumpAndSettle();

      // Fail with the *full* exception text (not just `expect(..., isNull)`'s
      // default one-line summary) so a real overflow prints Flutter's
      // complete diagnostic here, including its "The relevant
      // error-causing widget was: <Type> file:line:col" line -- that's
      // the authoritative source location of whichever RenderFlex is
      // actually overflowing, rather than another guess from this file.
      final Object? overflowException = tester.takeException();
      if (overflowException != null) {
        fail('Narrow-screen (320px) layout threw an exception:\n\n$overflowException');
      }
    },
  );

  testWidgets(
    'the budget card shows a polished empty state with a working call-to-action when no '
    'budget is configured yet, and tapping it routes to the budgets screen',
    (tester) async {
      useTallSurface(tester);
      final AppDatabase db = await seededDb(
        living: 'JPY',
        home: 'JPY',
        accounts: <_SeedAccount>[const _SeedAccount(name: 'JPY Wallet', currencyCode: 'JPY')],
      );
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.savings_outlined), findsOneWidget);
      expect(find.text('Remaining monthly budget'), findsOneWidget);
      expect(find.textContaining("You haven't set a monthly budget yet"), findsOneWidget);

      final Finder ctaFinder = find.widgetWithText(OutlinedButton, 'Set a monthly budget');
      expect(ctaFinder, findsOneWidget);
      // Now functional (Beta 1 Task 2 wired up the budgets route) --
      // never disabled once there's somewhere real to send the user.
      final OutlinedButton cta = tester.widget<OutlinedButton>(ctaFinder);
      expect(cta.onPressed, isNotNull);

      await tester.tap(ctaFinder);
      await tester.pumpAndSettle();
      expect(find.text('BUDGETS_SCREEN_STUB'), findsOneWidget);
    },
  );

  testWidgets(
    'a configured living-currency overall budget renders the real remaining amount, a status '
    'chip, and a percentage-used figure instead of the empty state',
    (tester) async {
      useTallSurface(tester);
      final AppDatabase db = await seededDb(
        living: 'JPY',
        home: 'JPY',
        accounts: <_SeedAccount>[const _SeedAccount(name: 'JPY Wallet', currencyCode: 'JPY')],
      );
      final ProfileRow? profile = await ProfileRepository(db).getProfile();
      await BudgetRepository(db).setOverallBudget(
        profileId: profile!.id,
        month: BudgetMonth.fromUtc(DateTime.now().toUtc()),
        amount: Money.fromMinorUnits(120000, 'JPY'), // ¥120,000
      );
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container));
      await tester.pumpAndSettle();

      expect(find.textContaining("You haven't set a monthly budget yet"), findsNothing);
      expect(find.text('of ¥120,000'), findsOneWidget);
      expect(find.byKey(const Key('budgetStatusChip')), findsOneWidget);
      expect(find.textContaining('% used'), findsOneWidget);
      expect(find.byKey(const Key('manageBudgetsButton')), findsOneWidget);

      await tester.tap(find.byKey(const Key('manageBudgetsButton')));
      await tester.pumpAndSettle();
      expect(find.text('BUDGETS_SCREEN_STUB'), findsOneWidget);
    },
  );

  testWidgets(
    'the richer card content for a configured budget (progress bar, status chip, percentage, '
    'daily recommendation) lays out without overflow on a narrow (320px-wide) screen',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1.0;

      final AppDatabase db = await seededDb(
        living: 'JPY',
        home: 'JPY',
        accounts: <_SeedAccount>[const _SeedAccount(name: 'JPY Wallet', currencyCode: 'JPY')],
      );
      final ProfileRow? profile = await ProfileRepository(db).getProfile();
      await BudgetRepository(db).setOverallBudget(
        profileId: profile!.id,
        month: BudgetMonth.fromUtc(DateTime.now().toUtc()),
        amount: Money.fromMinorUnits(120000, 'JPY'),
      );
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container));
      await tester.pumpAndSettle();

      final Object? overflowException = tester.takeException();
      if (overflowException != null) {
        fail('Narrow-screen (320px) configured-budget layout threw an exception:\n\n$overflowException');
      }
    },
  );

  testWidgets(
    'the recurring card shows a polished empty state with a working call-to-action when no '
    'rule exists yet, and tapping it routes to the recurring screen',
    (tester) async {
      useTallSurface(tester);
      final AppDatabase db = await seededDb(
        living: 'JPY',
        home: 'JPY',
        accounts: <_SeedAccount>[const _SeedAccount(name: 'JPY Wallet', currencyCode: 'JPY')],
      );
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.event_note_outlined), findsOneWidget);
      expect(find.text('Recurring'), findsOneWidget);
      expect(find.text('No recurring bills or income set up yet.'), findsOneWidget);

      final Finder ctaFinder = find.widgetWithText(OutlinedButton, 'Set up recurring');
      expect(ctaFinder, findsOneWidget);
      await tester.tap(ctaFinder);
      await tester.pumpAndSettle();
      expect(find.text('RECURRING_SCREEN_STUB'), findsOneWidget);
    },
  );

  testWidgets(
    'a due-today recurring rule renders as the single Home summary item -- never a summed '
    'total -- and "View all" routes to the recurring screen',
    (tester) async {
      useTallSurface(tester);
      final AppDatabase db = await seededDb(
        living: 'JPY',
        home: 'JPY',
        accounts: <_SeedAccount>[const _SeedAccount(name: 'JPY Wallet', currencyCode: 'JPY')],
      );
      final ProfileRow? profile = await ProfileRepository(db).getProfile();
      // Deterministic one-shot lookup instead of a reactive .watch()
      // stream -- AccountRepository.watchActiveForProfile(...).first
      // hangs when used as pre-widget test setup under testWidgets'
      // FakeAsync test zone. Same predicate shape as
      // watchActiveForProfile, built with .get() instead of .watch() so
      // no QueryStream is ever registered during test setup.
      final accountQuery = db.select(db.accounts)
        ..where(
          (tbl) =>
              tbl.profileId.equals(profile!.id) &
              tbl.isActive.equals(true) &
              tbl.deletedAt.isNull(),
        );
      final AccountRow account = (await accountQuery.get()).first;
      final DateTime todayUtc = DateTime.now().toUtc();
      await RecurringRuleRepository(db, AccountRepository(db)).createRule(
        // `!` still required here: the null-check on `profile` used to
        // build accountQuery's predicate lives inside a `where((tbl) =>
        // ...)` closure, and Dart's flow-analysis promotion does not
        // escape a closure back to the enclosing method body.
        profileId: profile!.id,
        kind: RecurringRuleKind.expense,
        name: 'Rent',
        amount: Money.fromMinorUnits(80000, 'JPY'), // ¥80,000
        accountId: account.id,
        frequency: RecurrenceFrequency.monthly,
        interval: 1,
        startDate: DateTime.utc(todayUtc.year, todayUtc.month, todayUtc.day),
      );
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container));
      await tester.pumpAndSettle();

      expect(find.text('No recurring bills or income set up yet.'), findsNothing);
      expect(find.text('Rent'), findsOneWidget);
      expect(find.text('¥80,000'), findsOneWidget);
      expect(find.text('Due today'), findsOneWidget);
      expect(find.byKey(const Key('viewAllRecurringButton')), findsOneWidget);

      await tester.tap(find.byKey(const Key('viewAllRecurringButton')));
      await tester.pumpAndSettle();
      expect(find.text('RECURRING_SCREEN_STUB'), findsOneWidget);
    },
  );

  testWidgets(
    'the recurring card lays out without overflow on a narrow (320px-wide) screen with a '
    'due-today item shown',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1.0;

      final AppDatabase db = await seededDb(
        living: 'JPY',
        home: 'JPY',
        accounts: <_SeedAccount>[const _SeedAccount(name: 'JPY Wallet', currencyCode: 'JPY')],
      );
      final ProfileRow? profile = await ProfileRepository(db).getProfile();
      // Deterministic one-shot lookup -- see the same fix in the
      // due-today test above for why watchActiveForProfile(...).first
      // was replaced here too.
      final accountQuery = db.select(db.accounts)
        ..where(
          (tbl) =>
              tbl.profileId.equals(profile!.id) &
              tbl.isActive.equals(true) &
              tbl.deletedAt.isNull(),
        );
      final AccountRow account = (await accountQuery.get()).first;
      final DateTime todayUtc = DateTime.now().toUtc();
      await RecurringRuleRepository(db, AccountRepository(db)).createRule(
        // Same reason as the due-today test above: the closure-scoped
        // null-check doesn't promote `profile` in this outer scope.
        profileId: profile!.id,
        kind: RecurringRuleKind.expense,
        name: 'A rather long recurring rule name to stress narrow-width layout',
        amount: Money.fromMinorUnits(80000, 'JPY'),
        accountId: account.id,
        frequency: RecurrenceFrequency.monthly,
        interval: 1,
        startDate: DateTime.utc(todayUtc.year, todayUtc.month, todayUtc.day),
      );
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container));
      await tester.pumpAndSettle();

      final Object? overflowException = tester.takeException();
      if (overflowException != null) {
        fail('Narrow-screen (320px) recurring card layout threw an exception:\n\n$overflowException');
      }
    },
  );

  testWidgets(
    'the savings goals card shows a polished empty state with a working call-to-action when '
    'no goal exists yet, and tapping it routes to the goals screen',
    (tester) async {
      useTallSurface(tester);
      final AppDatabase db = await seededDb(
        living: 'JPY',
        home: 'JPY',
        accounts: <_SeedAccount>[const _SeedAccount(name: 'JPY Wallet', currencyCode: 'JPY')],
      );
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.flag_outlined), findsOneWidget);
      expect(find.text('Savings Goals'), findsOneWidget);
      expect(find.textContaining("You haven't set a savings goal yet"), findsOneWidget);

      final Finder ctaFinder = find.widgetWithText(OutlinedButton, 'Set a savings goal');
      expect(ctaFinder, findsOneWidget);
      await tester.tap(ctaFinder);
      await tester.pumpAndSettle();
      expect(find.text('GOALS_SCREEN_STUB'), findsOneWidget);
    },
  );

  testWidgets(
    'an unfinished goal renders its real saved/target/percentage instead of the empty state',
    (tester) async {
      useTallSurface(tester);
      final AppDatabase db = await seededDb(
        living: 'JPY',
        home: 'JPY',
        accounts: <_SeedAccount>[const _SeedAccount(name: 'JPY Wallet', currencyCode: 'JPY')],
      );
      final ProfileRow? profile = await ProfileRepository(db).getProfile();
      final SavingsGoalRepository goalRepo = SavingsGoalRepository(db);
      final String goalId = await goalRepo.createGoal(
        profileId: profile!.id,
        name: 'Emergency Fund',
        targetAmount: Money.fromMinorUnits(100000, 'JPY'),
      );
      await SavingsGoalContributionRepository(db, goalRepo).addContribution(
        goalId: goalId,
        amount: Money.fromMinorUnits(30000, 'JPY'),
      );
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container));
      await tester.pumpAndSettle();

      expect(find.textContaining("You haven't set a savings goal yet"), findsNothing);
      expect(find.text('Emergency Fund'), findsOneWidget);
      expect(find.text('of ¥100,000'), findsOneWidget);
      expect(find.textContaining('30%'), findsOneWidget);
      expect(find.byKey(const Key('viewAllGoalsButton')), findsOneWidget);

      await tester.tap(find.byKey(const Key('viewAllGoalsButton')));
      await tester.pumpAndSettle();
      expect(find.text('GOALS_SCREEN_STUB'), findsOneWidget);
    },
  );

  testWidgets(
    "shows an 'all goals completed' state, never a fabricated most-recently-completed pick, "
    'when every goal is done',
    (tester) async {
      useTallSurface(tester);
      final AppDatabase db = await seededDb(
        living: 'JPY',
        home: 'JPY',
        accounts: <_SeedAccount>[const _SeedAccount(name: 'JPY Wallet', currencyCode: 'JPY')],
      );
      final ProfileRow? profile = await ProfileRepository(db).getProfile();
      final SavingsGoalRepository goalRepo = SavingsGoalRepository(db);
      final String goalId = await goalRepo.createGoal(
        profileId: profile!.id,
        name: 'Fully Funded',
        targetAmount: Money.fromMinorUnits(50000, 'JPY'),
      );
      await SavingsGoalContributionRepository(db, goalRepo).addContribution(
        goalId: goalId,
        amount: Money.fromMinorUnits(50000, 'JPY'),
      );
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container));
      await tester.pumpAndSettle();

      expect(find.text('All your savings goals are completed.'), findsOneWidget);
      expect(find.text('Fully Funded'), findsNothing); // no specific goal picked
    },
  );

  testWidgets(
    'the savings goals card lays out without overflow on a narrow (320px-wide) screen with a '
    'configured goal',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1.0;

      final AppDatabase db = await seededDb(
        living: 'JPY',
        home: 'JPY',
        accounts: <_SeedAccount>[const _SeedAccount(name: 'JPY Wallet', currencyCode: 'JPY')],
      );
      final ProfileRow? profile = await ProfileRepository(db).getProfile();
      final SavingsGoalRepository goalRepo = SavingsGoalRepository(db);
      final String goalId = await goalRepo.createGoal(
        profileId: profile!.id,
        name: 'A rather long savings goal name to stress narrow-width layout',
        targetAmount: Money.fromMinorUnits(100000, 'JPY'),
      );
      await SavingsGoalContributionRepository(db, goalRepo).addContribution(
        goalId: goalId,
        amount: Money.fromMinorUnits(30000, 'JPY'),
      );
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container));
      await tester.pumpAndSettle();

      final Object? overflowException = tester.takeException();
      if (overflowException != null) {
        fail('Narrow-screen (320px) savings goals card layout threw an exception:\n\n$overflowException');
      }
    },
  );
}
