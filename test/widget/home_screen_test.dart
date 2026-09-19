import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/providers.dart';
import 'package:ai_financial_coach/core/database/repositories/account_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/budget_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/recurring_rule_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/savings_goal_contribution_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/savings_goal_repository.dart';
import 'package:ai_financial_coach/core/fx/fx_rate.dart';
import 'package:ai_financial_coach/core/fx/fx_rate_provider.dart';
import 'package:ai_financial_coach/core/fx/in_memory_reference_fx_rate_cache.dart';
import 'package:ai_financial_coach/core/fx/reference_fx_rate.dart';
import 'package:ai_financial_coach/core/fx/reference_fx_rate_cache.dart';
import 'package:ai_financial_coach/core/fx/reference_fx_rate_providers.dart';
import 'package:ai_financial_coach/core/money/money.dart';
import 'package:ai_financial_coach/core/routing/app_routes.dart';
import 'package:ai_financial_coach/features/budgets/domain/budget_month.dart';
import 'package:ai_financial_coach/features/dashboard/presentation/home_screen.dart';
import 'package:ai_financial_coach/features/recurring/domain/recurrence_frequency.dart';
import 'package:ai_financial_coach/features/recurring/domain/recurring_rule_kind.dart';
import 'package:ai_financial_coach/l10n/generated/app_localizations.dart';
import 'package:ai_financial_coach/shared/theme/app_tokens.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../support/rtl_harness.dart';

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
//
// Checkpoint 9.5 Task F adds `_LivingCurrencyEquivalentLine` to every
// hero/secondary currency card whose own currency differs from the
// profile's living currency -- which is most of the scenarios already
// seeded below (e.g. JPY living + LKR home). Every `ProviderContainer`
// in this file therefore now ALSO overrides `fxRateProviderProvider`/
// `referenceFxRateCacheProvider` with `_AlwaysUnavailableFxRateProvider`/
// a fresh `InMemoryReferenceFxRateCache` by default -- fully offline,
// deterministic, and (since the provider always fails with an empty
// cache) resolves to `ReferenceRateUnavailable`, which
// `_LivingCurrencyEquivalentLine` already renders as nothing at all.
// This keeps every pre-existing assertion in this file unaffected while
// guaranteeing none of them make a real network call merely because
// Home now has a reference-rate-aware widget. The dedicated "9. Task F"
// group at the end of this file overrides these two providers again,
// per test, with real success/stale/failure scripts to actually exercise
// the equivalent line's own rendering.

/// A stateless [FxRateProvider] fake that always fails immediately, with
/// no I/O of any kind. The safe, deterministic default for every test in
/// this file that isn't specifically about Task F's equivalent line --
/// see this file's own top-of-file comment.
class _AlwaysUnavailableFxRateProvider implements FxRateProvider {
  @override
  Future<FxRateProviderResult> fetchRates({
    required String baseCurrencyCode,
    required Set<String> quoteCurrencyCodes,
  }) async {
    return const FxRateProviderFailure('no reference rate configured for this test');
  }
}

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
  // CP5.6: `{bool rtl = false}` threads an RTL `Directionality` through
  // `MaterialApp`'s own `builder:` -- see `test/support/rtl_harness.dart`.
  // CP6.3: `HomeScreen` now reads `AppLocalizations.of(context)`, so this
  // harness needs the same localization wiring already established in
  // `add_transaction_screen_test.dart`'s `appWithPushedScreen()` and
  // `app_shell_test.dart`'s `buildApp()` -- `{Locale locale = const
  // Locale('en')}` keeps every pre-existing English test passing
  // unchanged, while the new Japanese-proof tests pass `locale: const
  // Locale('ja')`.
  Widget appWithHome(
    ProviderContainer container, {
    bool rtl = false,
    Locale locale = const Locale('en'),
  }) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const HomeScreen(),
        builder: rtl ? rtlAppBuilder : null,
      ),
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
  // CP6.3: same localization wiring as `appWithHome` above -- see its
  // comment for why.
  Widget appWithRouter(ProviderContainer container, {Locale locale = const Locale('en')}) {
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
      child: MaterialApp.router(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
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
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          fxRateProviderProvider.overrideWithValue(_AlwaysUnavailableFxRateProvider()),
          referenceFxRateCacheProvider.overrideWithValue(InMemoryReferenceFxRateCache()),
        ],
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
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          fxRateProviderProvider.overrideWithValue(_AlwaysUnavailableFxRateProvider()),
          referenceFxRateCacheProvider.overrideWithValue(InMemoryReferenceFxRateCache()),
        ],
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
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          fxRateProviderProvider.overrideWithValue(_AlwaysUnavailableFxRateProvider()),
          referenceFxRateCacheProvider.overrideWithValue(InMemoryReferenceFxRateCache()),
        ],
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
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          fxRateProviderProvider.overrideWithValue(_AlwaysUnavailableFxRateProvider()),
          referenceFxRateCacheProvider.overrideWithValue(InMemoryReferenceFxRateCache()),
        ],
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
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          fxRateProviderProvider.overrideWithValue(_AlwaysUnavailableFxRateProvider()),
          referenceFxRateCacheProvider.overrideWithValue(InMemoryReferenceFxRateCache()),
        ],
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
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          fxRateProviderProvider.overrideWithValue(_AlwaysUnavailableFxRateProvider()),
          referenceFxRateCacheProvider.overrideWithValue(InMemoryReferenceFxRateCache()),
        ],
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
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          fxRateProviderProvider.overrideWithValue(_AlwaysUnavailableFxRateProvider()),
          referenceFxRateCacheProvider.overrideWithValue(InMemoryReferenceFxRateCache()),
        ],
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
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          fxRateProviderProvider.overrideWithValue(_AlwaysUnavailableFxRateProvider()),
          referenceFxRateCacheProvider.overrideWithValue(InMemoryReferenceFxRateCache()),
        ],
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
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          fxRateProviderProvider.overrideWithValue(_AlwaysUnavailableFxRateProvider()),
          referenceFxRateCacheProvider.overrideWithValue(InMemoryReferenceFxRateCache()),
        ],
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
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          fxRateProviderProvider.overrideWithValue(_AlwaysUnavailableFxRateProvider()),
          referenceFxRateCacheProvider.overrideWithValue(InMemoryReferenceFxRateCache()),
        ],
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
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          fxRateProviderProvider.overrideWithValue(_AlwaysUnavailableFxRateProvider()),
          referenceFxRateCacheProvider.overrideWithValue(InMemoryReferenceFxRateCache()),
        ],
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
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          fxRateProviderProvider.overrideWithValue(_AlwaysUnavailableFxRateProvider()),
          referenceFxRateCacheProvider.overrideWithValue(InMemoryReferenceFxRateCache()),
        ],
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
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          fxRateProviderProvider.overrideWithValue(_AlwaysUnavailableFxRateProvider()),
          referenceFxRateCacheProvider.overrideWithValue(InMemoryReferenceFxRateCache()),
        ],
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

  // International / Localization Foundation Checkpoint 5.1 --
  // `_ConfiguredBudget`/`_PriorityGoalSummary`/`_RecurringItemSummary` now
  // share `_AdaptiveAmountLine` instead of a bare `Wrap`: the amount is
  // NEVER shrunk (no `FittedBox`), never ellipsized, and never loses a
  // digit -- when it and its secondary line ("of <total>" or a date)
  // don't both fit the row, the secondary line moves below the amount
  // instead. These tests assert the actual rendered strings (every
  // digit `MoneyFormatter` produced), not merely the absence of an
  // exception, and assert on the `<prefix>Stacked`/`<prefix>SideBySide`
  // keys to confirm which arrangement actually rendered -- see
  // `home_screen.dart`'s `_AdaptiveAmountLine` doc comment.

  testWidgets(
    'CP5.1: the budget card renders the amount side by side with "of <budgeted>" at normal '
    'width and default text scale -- unchanged from before this checkpoint',
    (tester) async {
      useTallSurface(tester);
      final AppDatabase db = await seededDb(
        living: 'JPY',
        home: 'JPY',
        accounts: <_SeedAccount>[const _SeedAccount(name: 'JPY Wallet', currencyCode: 'JPY')],
      );
      final ProfileRow? profile = await ProfileRepository(db).getProfile();
      // A short remaining/budgeted pair is deliberately used here (not
      // ¥120,000 -- see CP5.1's root-cause investigation): on real
      // measured Material 3 text metrics, "¥120,000" (headlineSmall,
      // bold) + "of ¥120,000" (bodyMedium) together need ~357px, which
      // does not fit this card's ~328px content width even at normal
      // (400px-logical) width and default text scale -- so it always
      // stacked, both before and after this checkpoint, and was never a
      // valid example of the side-by-side arrangement this test means to
      // verify. ¥5,000 is short enough to genuinely fit side by side.
      await BudgetRepository(db).setOverallBudget(
        profileId: profile!.id,
        month: BudgetMonth.fromUtc(DateTime.now().toUtc()),
        amount: Money.fromMinorUnits(5000, 'JPY'), // ¥5,000
      );
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          fxRateProviderProvider.overrideWithValue(_AlwaysUnavailableFxRateProvider()),
          referenceFxRateCacheProvider.overrideWithValue(InMemoryReferenceFxRateCache()),
        ],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('¥5,000'), findsOneWidget);
      expect(find.text('of ¥5,000'), findsOneWidget);
      expect(find.byKey(const Key('budgetAmountSideBySide')), findsOneWidget);
      expect(find.byKey(const Key('budgetAmountStacked')), findsNothing);
    },
  );

  testWidgets(
    'CP5.1: the budget card stacks the amount below "of <budgeted>" -- with every digit of a '
    'large 0-decimal VND remaining amount still fully rendered -- at 320px width and a 1.6x '
    'text scale together',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final AppDatabase db = await seededDb(
        living: 'VND',
        home: 'VND',
        accounts: <_SeedAccount>[const _SeedAccount(name: 'VND Wallet', currencyCode: 'VND')],
      );
      final ProfileRow? profile = await ProfileRepository(db).getProfile();
      await BudgetRepository(db).setOverallBudget(
        profileId: profile!.id,
        month: BudgetMonth.fromUtc(DateTime.now().toUtc()),
        amount: Money.fromMinorUnits(999999999, 'VND'), // ₫999,999,999
      );
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          fxRateProviderProvider.overrideWithValue(_AlwaysUnavailableFxRateProvider()),
          referenceFxRateCacheProvider.overrideWithValue(InMemoryReferenceFxRateCache()),
        ],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Every digit still present, in full, on both the primary amount
      // and the secondary "of <budgeted>" line -- not merely "no
      // exception was thrown".
      expect(find.text('₫999,999,999'), findsOneWidget);
      expect(find.text('of ₫999,999,999'), findsOneWidget);
      expect(find.byKey(const Key('budgetAmountStacked')), findsOneWidget);
      expect(find.byKey(const Key('budgetAmountSideBySide')), findsNothing);
    },
  );

  testWidgets(
    'CP5.1: the budget card stacks and keeps every digit of a KWD remaining amount with 3 '
    'decimal places at 320px width and a 1.6x text scale together',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final AppDatabase db = await seededDb(
        living: 'KWD',
        home: 'KWD',
        accounts: <_SeedAccount>[const _SeedAccount(name: 'KWD Wallet', currencyCode: 'KWD')],
      );
      final ProfileRow? profile = await ProfileRepository(db).getProfile();
      await BudgetRepository(db).setOverallBudget(
        profileId: profile!.id,
        month: BudgetMonth.fromUtc(DateTime.now().toUtc()),
        amount: Money.fromMinorUnits(12345678, 'KWD'), // د.ك12,345.678
      );
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          fxRateProviderProvider.overrideWithValue(_AlwaysUnavailableFxRateProvider()),
          referenceFxRateCacheProvider.overrideWithValue(InMemoryReferenceFxRateCache()),
        ],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('د.ك12,345.678'), findsOneWidget);
      expect(find.text('of د.ك12,345.678'), findsOneWidget);
      expect(find.byKey(const Key('budgetAmountStacked')), findsOneWidget);
      expect(find.byKey(const Key('budgetAmountSideBySide')), findsNothing);
    },
  );

  testWidgets(
    'CP5.1: the budget card stacks and keeps every digit of a large JPY remaining amount at '
    '320px width and a 1.6x text scale together',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final AppDatabase db = await seededDb(
        living: 'JPY',
        home: 'JPY',
        accounts: <_SeedAccount>[const _SeedAccount(name: 'JPY Wallet', currencyCode: 'JPY')],
      );
      final ProfileRow? profile = await ProfileRepository(db).getProfile();
      await BudgetRepository(db).setOverallBudget(
        profileId: profile!.id,
        month: BudgetMonth.fromUtc(DateTime.now().toUtc()),
        amount: Money.fromMinorUnits(99999999, 'JPY'), // ¥99,999,999
      );
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          fxRateProviderProvider.overrideWithValue(_AlwaysUnavailableFxRateProvider()),
          referenceFxRateCacheProvider.overrideWithValue(InMemoryReferenceFxRateCache()),
        ],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('¥99,999,999'), findsOneWidget);
      expect(find.text('of ¥99,999,999'), findsOneWidget);
      expect(find.byKey(const Key('budgetAmountStacked')), findsOneWidget);
      expect(find.byKey(const Key('budgetAmountSideBySide')), findsNothing);
    },
  );

  testWidgets(
    'CP5.1: the budget card stacks and keeps every digit of a large MMK remaining amount at '
    '320px width and a 2.0x text scale together',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(320, 2200);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final AppDatabase db = await seededDb(
        living: 'MMK',
        home: 'MMK',
        accounts: <_SeedAccount>[const _SeedAccount(name: 'MMK Wallet', currencyCode: 'MMK')],
      );
      final ProfileRow? profile = await ProfileRepository(db).getProfile();
      await BudgetRepository(db).setOverallBudget(
        profileId: profile!.id,
        month: BudgetMonth.fromUtc(DateTime.now().toUtc()),
        amount: Money.fromMinorUnits(999999999, 'MMK'), // K9,999,999.99 -- MMK has 2 minor units
        // (per `CurrencyRegistry`), not 0 -- see report note.
      );
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          fxRateProviderProvider.overrideWithValue(_AlwaysUnavailableFxRateProvider()),
          referenceFxRateCacheProvider.overrideWithValue(InMemoryReferenceFxRateCache()),
        ],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('K9,999,999.99'), findsOneWidget);
      expect(find.text('of K9,999,999.99'), findsOneWidget);
      expect(find.byKey(const Key('budgetAmountStacked')), findsOneWidget);
      expect(find.byKey(const Key('budgetAmountSideBySide')), findsNothing);
    },
  );

  testWidgets(
    'CP5.1: the savings goals card stacks and keeps every digit of large VND saved/target '
    'amounts at 320px width and a 1.6x text scale together',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(320, 2200);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final AppDatabase db = await seededDb(
        living: 'JPY',
        home: 'JPY',
        accounts: <_SeedAccount>[const _SeedAccount(name: 'JPY Wallet', currencyCode: 'JPY')],
      );
      final ProfileRow? profile = await ProfileRepository(db).getProfile();
      final SavingsGoalRepository goalRepo = SavingsGoalRepository(db);
      final String goalId = await goalRepo.createGoal(
        profileId: profile!.id,
        name: 'Large VND Goal',
        targetAmount: Money.fromMinorUnits(999999999, 'VND'), // ₫999,999,999
      );
      await SavingsGoalContributionRepository(db, goalRepo).addContribution(
        goalId: goalId,
        amount: Money.fromMinorUnits(500000000, 'VND'), // ₫500,000,000
      );
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          fxRateProviderProvider.overrideWithValue(_AlwaysUnavailableFxRateProvider()),
          referenceFxRateCacheProvider.overrideWithValue(InMemoryReferenceFxRateCache()),
        ],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('₫500,000,000'), findsOneWidget);
      expect(find.text('of ₫999,999,999'), findsOneWidget);
      expect(find.byKey(const Key('goalAmountStacked')), findsOneWidget);
      expect(find.byKey(const Key('goalAmountSideBySide')), findsNothing);
    },
  );

  testWidgets(
    'CP5.1: the recurring card stacks and keeps every digit of a KWD amount with 3 decimal '
    'places at 320px width and a 1.6x text scale together',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(320, 2200);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final AppDatabase db = await seededDb(
        living: 'JPY',
        home: 'JPY',
        accounts: <_SeedAccount>[
          const _SeedAccount(name: 'JPY Wallet', currencyCode: 'JPY'),
          const _SeedAccount(name: 'KWD Wallet', currencyCode: 'KWD'),
        ],
      );
      final ProfileRow? profile = await ProfileRepository(db).getProfile();
      // Deterministic one-shot lookup, scoped to the KWD account -- same
      // reasoning as the due-today/narrow-width recurring tests above
      // for why `watchActiveForProfile(...).first` is avoided here.
      final accountQuery = db.select(db.accounts)
        ..where(
          (tbl) =>
              tbl.profileId.equals(profile!.id) &
              tbl.currencyCode.equals('KWD') &
              tbl.isActive.equals(true) &
              tbl.deletedAt.isNull(),
        );
      final AccountRow kwdAccount = (await accountQuery.get()).first;
      final DateTime todayUtc = DateTime.now().toUtc();
      await RecurringRuleRepository(db, AccountRepository(db)).createRule(
        profileId: profile!.id,
        kind: RecurringRuleKind.expense,
        name: 'Large KWD Rule',
        amount: Money.fromMinorUnits(12345678, 'KWD'), // د.ك12,345.678
        accountId: kwdAccount.id,
        frequency: RecurrenceFrequency.monthly,
        interval: 1,
        startDate: DateTime.utc(todayUtc.year, todayUtc.month, todayUtc.day),
      );
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          fxRateProviderProvider.overrideWithValue(_AlwaysUnavailableFxRateProvider()),
          referenceFxRateCacheProvider.overrideWithValue(InMemoryReferenceFxRateCache()),
        ],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container));
      await tester.pumpAndSettle();

      // CP5.1: the recurring card sits below two currency cards plus the
      // (empty-state) budget and goals cards -- at 320px width the
      // `ListView`'s viewport + cache extent doesn't reach it on the
      // first pump regardless of a tall fixed `physicalSize`, so scroll
      // deterministically to the card's own stable key (added to
      // `_UpcomingCommitmentsCard` for exactly this) rather than relying
      // on height alone. Width and text scale are untouched.
      await tester.scrollUntilVisible(
        find.byKey(const Key('upcomingCommitmentsCardSection')),
        200.0,
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('د.ك12,345.678'), findsOneWidget);
      expect(find.byKey(const Key('recurringAmountStacked')), findsOneWidget);
      expect(find.byKey(const Key('recurringAmountSideBySide')), findsNothing);
    },
  );

  testWidgets(
    'CP5.2a: an account tile renders name, currency code, and full balance side by side under '
    'normal width and text scale',
    (tester) async {
      useTallSurface(tester);
      final AppDatabase db = await seededDb(
        living: 'JPY',
        home: 'JPY',
        accounts: <_SeedAccount>[
          _SeedAccount(
            name: 'Main Wallet',
            currencyCode: 'JPY',
            openingBalance: Money.fromMinorUnits(50000, 'JPY'), // ¥50,000
          ),
        ],
      );
      final ProfileRow? profile = await ProfileRepository(db).getProfile();
      final accountQuery = db.select(db.accounts)
        ..where(
          (tbl) =>
              tbl.profileId.equals(profile!.id) &
              tbl.isActive.equals(true) &
              tbl.deletedAt.isNull(),
        );
      final AccountRow account = (await accountQuery.get()).first;
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          fxRateProviderProvider.overrideWithValue(_AlwaysUnavailableFxRateProvider()),
          referenceFxRateCacheProvider.overrideWithValue(InMemoryReferenceFxRateCache()),
        ],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithHome(container));
      await tester.pumpAndSettle();

      // At normal width/text scale the horizontal branch is guaranteed, so
      // it's safe to scope both the name and the balance to specifically
      // this account's tile rather than just anywhere on screen.
      final Finder accountLayout = find.byKey(Key('accountTileHorizontal_${account.id}'));

      expect(tester.takeException(), isNull);
      expect(accountLayout, findsOneWidget);
      expect(find.descendant(of: accountLayout, matching: find.text('Main Wallet')), findsOneWidget);
      expect(find.descendant(of: accountLayout, matching: find.text('¥50,000')), findsOneWidget);
      expect(find.byKey(Key('accountTileStacked_${account.id}')), findsNothing);
    },
  );

  testWidgets(
    'CP5.2a: an account tile keeps every digit of a large 0-decimal VND balance at 320px '
    'width and a 1.6x text scale, with a long account name squeezed instead',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      // Widened from the usual 320x900 narrow-stress fixture: the
      // Accounts section is the deepest section on Home, and at 900px
      // tall `scrollUntilVisible` below could bring the account name
      // into view while the balance itself (below it if stacked, or
      // simply further down the tile) was still outside the viewport
      // and therefore not rendered -- confirmed by this test actually
      // failing to find the balance text at 900px on a real run.
      tester.view.physicalSize = const Size(320, 2200);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      const String longName = 'A rather long account name to stress narrow-width layout';
      final AppDatabase db = await seededDb(
        living: 'VND',
        home: 'VND',
        accounts: <_SeedAccount>[
          _SeedAccount(
            name: longName,
            currencyCode: 'VND',
            openingBalance: Money.fromMinorUnits(999999999, 'VND'), // ₫999,999,999
          ),
        ],
      );
      final ProfileRow? profile = await ProfileRepository(db).getProfile();
      final accountQuery = db.select(db.accounts)
        ..where(
          (tbl) =>
              tbl.profileId.equals(profile!.id) &
              tbl.isActive.equals(true) &
              tbl.deletedAt.isNull(),
        );
      final AccountRow account = (await accountQuery.get()).first;
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          fxRateProviderProvider.overrideWithValue(_AlwaysUnavailableFxRateProvider()),
          referenceFxRateCacheProvider.overrideWithValue(InMemoryReferenceFxRateCache()),
        ],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithHome(container));
      await tester.pumpAndSettle();
      // The Accounts section sits below the currency summary, budget,
      // savings goals, and upcoming-commitments cards -- deeper than
      // anything else on Home -- so a fixed narrow `physicalSize` alone
      // doesn't guarantee it's mounted; scroll to the account's own name
      // text deterministically, the same technique the recurring card's
      // narrow-width test above relies on.
      await tester.scrollUntilVisible(find.text(longName), 300.0);
      await tester.pumpAndSettle();

      // Not asserting which layout branch this renders as -- at 1.6x
      // this 0-decimal balance may legitimately land in either one, and
      // that isn't the point of this test. But a plain page-wide
      // `find.text(...)` isn't enough either: when living/home currency
      // match the account's currency (as here), the hero currency-
      // summary card at the top of Home shows this exact same total,
      // so the same string legitimately appears twice on screen. Scope
      // to whichever of this account's own two layout keys actually
      // rendered, so the assertion is about *this tile*, not the page.
      final Finder accountLayout = find.byWidgetPredicate(
        (Widget widget) =>
            widget.key == Key('accountTileHorizontal_${account.id}') ||
            widget.key == Key('accountTileStacked_${account.id}'),
      );

      expect(tester.takeException(), isNull);
      expect(accountLayout, findsOneWidget);
      expect(
        find.descendant(of: accountLayout, matching: find.text('₫999,999,999')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'CP5.2a: an account tile keeps every digit of a large 3-decimal KWD balance at 320px '
    'width and a 1.6x text scale, with a long account name squeezed instead',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      // Widened from the usual 320x900 narrow-stress fixture: the
      // Accounts section is the deepest section on Home, and at 900px
      // tall `scrollUntilVisible` below could bring the account name
      // into view while the balance itself (below it if stacked, or
      // simply further down the tile) was still outside the viewport
      // and therefore not rendered -- confirmed by this test actually
      // failing to find the balance text at 900px on a real run.
      tester.view.physicalSize = const Size(320, 2200);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      const String longName = 'A rather long account name to stress narrow-width layout';
      final AppDatabase db = await seededDb(
        living: 'KWD',
        home: 'KWD',
        accounts: <_SeedAccount>[
          _SeedAccount(
            name: longName,
            currencyCode: 'KWD',
            openingBalance: Money.fromMinorUnits(12345678, 'KWD'), // د.ك12,345.678
          ),
        ],
      );
      final ProfileRow? profile = await ProfileRepository(db).getProfile();
      final accountQuery = db.select(db.accounts)
        ..where(
          (tbl) =>
              tbl.profileId.equals(profile!.id) &
              tbl.isActive.equals(true) &
              tbl.deletedAt.isNull(),
        );
      final AccountRow account = (await accountQuery.get()).first;
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          fxRateProviderProvider.overrideWithValue(_AlwaysUnavailableFxRateProvider()),
          referenceFxRateCacheProvider.overrideWithValue(InMemoryReferenceFxRateCache()),
        ],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithHome(container));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text(longName), 300.0);
      await tester.pumpAndSettle();

      // Same reasoning as the VND test above: not asserting which
      // layout branch this renders as, but scoped to whichever of this
      // account's own two layout keys actually rendered, since the
      // hero currency-summary card shows this same total too (living
      // and home currency both match the account's currency here).
      final Finder accountLayout = find.byWidgetPredicate(
        (Widget widget) =>
            widget.key == Key('accountTileHorizontal_${account.id}') ||
            widget.key == Key('accountTileStacked_${account.id}'),
      );

      expect(tester.takeException(), isNull);
      expect(accountLayout, findsOneWidget);
      expect(
        find.descendant(of: accountLayout, matching: find.text('د.ك12,345.678')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'CP5.2a: an account tile switches to a stacked layout and keeps every digit of a large '
    'MMK balance at 320px width and a 2.0x text scale, never clipping it',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(320, 2200);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      const String longName = 'A rather long account name to stress narrow-width layout';
      final AppDatabase db = await seededDb(
        living: 'MMK',
        home: 'MMK',
        accounts: <_SeedAccount>[
          _SeedAccount(
            name: longName,
            currencyCode: 'MMK',
            // K9,999,999.99 -- MMK has 2 minor units per `CurrencyRegistry`,
            // not 0; this exact value was measured in a prior CP5.1
            // diagnostic run to exceed a narrow card's available width at
            // 2.0x text scale, so it's reused here to reliably force the
            // stacked layout rather than guessing a value.
            openingBalance: Money.fromMinorUnits(999999999, 'MMK'),
          ),
        ],
      );
      final ProfileRow? profile = await ProfileRepository(db).getProfile();
      final accountQuery = db.select(db.accounts)
        ..where(
          (tbl) =>
              tbl.profileId.equals(profile!.id) &
              tbl.isActive.equals(true) &
              tbl.deletedAt.isNull(),
        );
      final AccountRow account = (await accountQuery.get()).first;
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          fxRateProviderProvider.overrideWithValue(_AlwaysUnavailableFxRateProvider()),
          referenceFxRateCacheProvider.overrideWithValue(InMemoryReferenceFxRateCache()),
        ],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithHome(container));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text(longName), 300.0);
      await tester.pumpAndSettle();

      // This value is specifically chosen to force the stacked branch, so
      // it's safe to scope the balance assertion to that specific key.
      final Finder accountLayout = find.byKey(Key('accountTileStacked_${account.id}'));

      expect(tester.takeException(), isNull);
      expect(accountLayout, findsOneWidget);
      expect(
        find.descendant(of: accountLayout, matching: find.text('K9,999,999.99')),
        findsOneWidget,
      );
      expect(find.byKey(Key('accountTileHorizontal_${account.id}')), findsNothing);
    },
  );

  testWidgets(
    'CP5.2a: an account tile renders an MMK balance with its registry-defined 2 decimal '
    'places, not 0, under normal width and text scale',
    (tester) async {
      useTallSurface(tester);
      final AppDatabase db = await seededDb(
        living: 'MMK',
        home: 'MMK',
        accounts: <_SeedAccount>[
          _SeedAccount(
            name: 'Yangon Wallet',
            currencyCode: 'MMK',
            openingBalance: Money.fromMinorUnits(150075, 'MMK'), // K1,500.75
          ),
        ],
      );
      final ProfileRow? profile = await ProfileRepository(db).getProfile();
      final accountQuery = db.select(db.accounts)
        ..where(
          (tbl) =>
              tbl.profileId.equals(profile!.id) &
              tbl.isActive.equals(true) &
              tbl.deletedAt.isNull(),
        );
      final AccountRow account = (await accountQuery.get()).first;
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          fxRateProviderProvider.overrideWithValue(_AlwaysUnavailableFxRateProvider()),
          referenceFxRateCacheProvider.overrideWithValue(InMemoryReferenceFxRateCache()),
        ],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithHome(container));
      await tester.pumpAndSettle();

      // Normal width/text scale -- horizontal branch is guaranteed.
      final Finder accountLayout = find.byKey(Key('accountTileHorizontal_${account.id}'));

      expect(tester.takeException(), isNull);
      expect(accountLayout, findsOneWidget);
      expect(
        find.descendant(of: accountLayout, matching: find.text('K1,500.75')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
      "CP5.6: under RTL, the stacked account tile's balance is expected to hug the same "
      'reading-start edge as the account name above it -- demonstrates whether '
      '`Alignment.centerLeft` (physical, today) or `AlignmentDirectional.centerStart` '
      '(directional) is actually in use', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(320, 2200);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    const String longName = 'A rather long account name to stress narrow-width layout';
    final AppDatabase db = await seededDb(
      living: 'MMK',
      home: 'MMK',
      accounts: <_SeedAccount>[
        _SeedAccount(
          name: longName,
          currencyCode: 'MMK',
          openingBalance: Money.fromMinorUnits(999999999, 'MMK'),
        ),
      ],
    );
    final ProfileRow? profile = await ProfileRepository(db).getProfile();
    final accountQuery = db.select(db.accounts)
      ..where(
        (tbl) =>
            tbl.profileId.equals(profile!.id) &
            tbl.isActive.equals(true) &
            tbl.deletedAt.isNull(),
      );
    final AccountRow account = (await accountQuery.get()).first;
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          fxRateProviderProvider.overrideWithValue(_AlwaysUnavailableFxRateProvider()),
          referenceFxRateCacheProvider.overrideWithValue(InMemoryReferenceFxRateCache()),
        ],
    );
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithHome(container, rtl: true));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text(longName), 300.0);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final Finder accountLayout = find.byKey(Key('accountTileStacked_${account.id}'));
    expect(accountLayout, findsOneWidget);
    final Finder money =
        find.descendant(of: accountLayout, matching: find.text('K9,999,999.99'));
    expect(money, findsOneWidget);

    // Same defect class as `accounts_screen.dart`'s stacked row (CP5.6
    // report finding B): `_AccountTile`'s stacked fallback in
    // `home_screen.dart` also positions the balance with a physical
    // `Alignment.centerLeft` rather than `AlignmentDirectional.centerStart`,
    // so under RTL it's expected to stay pinned to the physical left
    // instead of moving to the row's right/start edge where the account
    // name above it (via `CrossAxisAlignment.start`) correctly moves to.
    final double rowRight = tester.getTopRight(accountLayout).dx;
    final double moneyRight = tester.getTopRight(money).dx;
    expect(
      moneyRight,
      closeTo(rowRight, 1.0),
      reason: "expected the balance to hug the stacked tile's reading-start edge "
          "(the tile's right edge under RTL), matching the account name above it",
    );
  });

  // ============================================================
  // Visual System Convergence Checkpoint 7.2: Home + AppShell Visual
  // Convergence toward the approved Claude Design light-theme dashboard
  // reference. These tests lock in the two shared-primitive enhancements
  // CP7.2 applied to Home (`AppCard.bordered`, `AppSectionHeader.eyebrow`)
  // without re-testing anything `app_card_test.dart`/
  // `app_section_header_test.dart` already cover generically -- these
  // only confirm Home actually wires the flags on, and that doing so
  // never changed any rendered string (every pre-existing `find.text(...)`
  // assertion above this point still passes unchanged, which is itself
  // part of that guarantee).
  // ============================================================

  group('CP7.2 Visual System Convergence', () {
    testWidgets(
      'the budget card renders as a bordered, colorScheme.surface card -- the shared '
      '"bordered" AppCard treatment -- instead of the old tonal fill with no border',
      (tester) async {
        useTallSurface(tester);
        final AppDatabase db = await seededDb(
          living: 'JPY',
          home: 'JPY',
          accounts: <_SeedAccount>[const _SeedAccount(name: 'JPY Wallet', currencyCode: 'JPY')],
        );
        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          fxRateProviderProvider.overrideWithValue(_AlwaysUnavailableFxRateProvider()),
          referenceFxRateCacheProvider.overrideWithValue(InMemoryReferenceFxRateCache()),
        ],
        );
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRouter(container));
        await tester.pumpAndSettle();

        final Finder budgetCard = find
            .ancestor(of: find.byIcon(Icons.savings_outlined), matching: find.byType(Card))
            .first;
        final Card card = tester.widget<Card>(budgetCard);
        final BuildContext context = tester.element(find.byIcon(Icons.savings_outlined));
        final ColorScheme colors = Theme.of(context).colorScheme;
        final AppTokens tokens = context.appTokens;

        expect(card.color, colors.surface);
        final RoundedRectangleBorder shape = card.shape! as RoundedRectangleBorder;
        expect(shape.side.color, tokens.colors.subtleBorder);
      },
    );

    testWidgets(
      'the savings goals and recurring cards also render bordered, and an account tile '
      'renders bordered too -- every card converged consistently, not just the budget card',
      (tester) async {
        useTallSurface(tester);
        final AppDatabase db = await seededDb(
          living: 'JPY',
          home: 'JPY',
          accounts: <_SeedAccount>[const _SeedAccount(name: 'JPY Wallet', currencyCode: 'JPY')],
        );
        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          fxRateProviderProvider.overrideWithValue(_AlwaysUnavailableFxRateProvider()),
          referenceFxRateCacheProvider.overrideWithValue(InMemoryReferenceFxRateCache()),
        ],
        );
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithHome(container));
        await tester.pumpAndSettle();

        final BuildContext context = tester.element(find.byIcon(Icons.flag_outlined));
        final ColorScheme colors = Theme.of(context).colorScheme;
        final AppTokens tokens = context.appTokens;

        for (final IconData icon in <IconData>[Icons.flag_outlined, Icons.event_note_outlined]) {
          final Card card = tester.widget<Card>(
            find.ancestor(of: find.byIcon(icon), matching: find.byType(Card)).first,
          );
          expect(card.color, colors.surface, reason: 'card for $icon should be bordered');
          final RoundedRectangleBorder shape = card.shape! as RoundedRectangleBorder;
          expect(shape.side.color, tokens.colors.subtleBorder, reason: 'card for $icon should be bordered');
        }

        final Card accountCard = tester.widget<Card>(
          find.ancestor(of: find.text('JPY Wallet'), matching: find.byType(Card)).first,
        );
        expect(accountCard.color, colors.surface);
        final RoundedRectangleBorder accountShape = accountCard.shape! as RoundedRectangleBorder;
        expect(accountShape.side.color, tokens.colors.subtleBorder);
      },
    );

    testWidgets(
      'the budget/savings/recurring/accounts section headers keep their exact original '
      'English title text even with the eyebrow styling applied',
      (tester) async {
        useTallSurface(tester);
        final AppDatabase db = await seededDb(
          living: 'JPY',
          home: 'JPY',
          accounts: <_SeedAccount>[const _SeedAccount(name: 'JPY Wallet', currencyCode: 'JPY')],
        );
        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          fxRateProviderProvider.overrideWithValue(_AlwaysUnavailableFxRateProvider()),
          referenceFxRateCacheProvider.overrideWithValue(InMemoryReferenceFxRateCache()),
        ],
        );
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithHome(container));
        await tester.pumpAndSettle();

        // Exact original casing -- never forced to upper case -- proving
        // the `eyebrow` flag changed styling only, not the rendered
        // string, exactly as `AppSectionHeader`'s own doc comment
        // guarantees.
        expect(find.text('Remaining monthly budget'), findsOneWidget);
        expect(find.text('Savings Goals'), findsOneWidget);
        expect(find.text('Recurring'), findsOneWidget);
        expect(find.text('Accounts'), findsOneWidget);
        expect(find.text('REMAINING MONTHLY BUDGET'), findsNothing);
        expect(find.text('SAVINGS GOALS'), findsNothing);
      },
    );
  });

  // ============================================================
  // CP6.3 (Localization Phase 1, Home Dashboard): exercises the REAL
  // `HomeScreen` under a real Japanese locale -- same pattern
  // established in CP6.1 (`app_shell_test.dart`) and CP6.2
  // (`add_transaction_screen_test.dart`). Every existing test above
  // this point keeps its default `locale: const Locale('en')`, so all
  // pre-existing English assertions are unaffected by this section.
  // ============================================================

  group('CP6.3 Japanese localization', () {
    testWidgets(
      'A: standard Japanese Home -- principal labels render in Japanese, no render exceptions',
      (tester) async {
        useTallSurface(tester);
        final AppDatabase db = await seededDb(
          living: 'JPY',
          home: 'JPY',
          accounts: <_SeedAccount>[const _SeedAccount(name: 'JPY Wallet', currencyCode: 'JPY')],
        );
        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          fxRateProviderProvider.overrideWithValue(_AlwaysUnavailableFxRateProvider()),
          referenceFxRateCacheProvider.overrideWithValue(InMemoryReferenceFxRateCache()),
        ],
        );
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithHome(container, locale: const Locale('ja')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('ホーム'), findsOneWidget); // AppBar title (reuses navHome)
        expect(find.text('Test Userさん、こんにちは'), findsOneWidget); // greeting placeholder
        expect(find.text('口座'), findsOneWidget); // Accounts section heading
        expect(find.text('管理'), findsOneWidget); // Accounts section "Manage" button
        expect(find.text('利用可能残高の合計'), findsOneWidget);
        expect(find.text('今月の収入'), findsOneWidget);
        expect(find.text('今月の支出'), findsOneWidget);
        expect(find.text('1日あたりの支出ペース'), findsOneWidget);
        expect(find.text('今月の残り予算'), findsOneWidget); // budget card title, empty state
        expect(find.text('貯蓄目標'), findsOneWidget); // savings goals card title, empty state
        expect(find.text('定期'), findsOneWidget); // recurring card title, empty state
      },
    );

    testWidgets(
      'B: Japanese Home renders the full KWD (3-decimal) remaining-budget figure alongside '
      'localized descriptive text, with no exceptions and no clipped digits',
      (tester) async {
        useTallSurface(tester);
        final AppDatabase db = await seededDb(
          living: 'KWD',
          home: 'KWD',
          accounts: <_SeedAccount>[const _SeedAccount(name: 'KWD Wallet', currencyCode: 'KWD')],
        );
        final ProfileRow? profile = await ProfileRepository(db).getProfile();
        await BudgetRepository(db).setOverallBudget(
          profileId: profile!.id,
          month: BudgetMonth.fromUtc(DateTime.now().toUtc()),
          amount: Money.fromMinorUnits(12345678, 'KWD'), // د.ك12,345.678
        );
        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          fxRateProviderProvider.overrideWithValue(_AlwaysUnavailableFxRateProvider()),
          referenceFxRateCacheProvider.overrideWithValue(InMemoryReferenceFxRateCache()),
        ],
        );
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRouter(container, locale: const Locale('ja')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        // Every digit of the KWD remaining amount still renders in full --
        // the localized descriptive text never forces the money to
        // shrink, clip, or ellipsize (same CP5.1 guarantee, now checked
        // together with Japanese labels for the first time).
        expect(find.text('د.ك12,345.678'), findsOneWidget);
        expect(find.text('د.ك12,345.678のうち'), findsOneWidget); // localized "of <budgeted>"
        expect(find.textContaining('%使用'), findsOneWidget); // localized "<percent>% used"
        expect(find.text('今月の残り予算'), findsOneWidget);
      },
    );

    testWidgets(
      'C: Japanese Home at 1.6x text scale -- principal dashboard content remains renderable, '
      'no overflow/render exceptions',
      (tester) async {
        useTallSurface(tester);
        tester.platformDispatcher.textScaleFactorTestValue = 1.6;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        final AppDatabase db = await seededDb(
          living: 'JPY',
          home: 'LKR',
          accounts: <_SeedAccount>[
            const _SeedAccount(name: 'JPY Wallet', currencyCode: 'JPY'),
            const _SeedAccount(name: 'LKR Wallet', currencyCode: 'LKR'),
          ],
        );
        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          fxRateProviderProvider.overrideWithValue(_AlwaysUnavailableFxRateProvider()),
          referenceFxRateCacheProvider.overrideWithValue(InMemoryReferenceFxRateCache()),
        ],
        );
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithHome(container, locale: const Locale('ja')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('生活通貨'), findsOneWidget); // livingCurrency badge (reused key)
        expect(find.text('基準通貨'), findsOneWidget); // homeCurrency badge (reused key)
        expect(find.text('今月の収入'), findsWidgets); // one per currency card
        expect(find.text('今月の支出'), findsWidgets);
      },
    );

    testWidgets(
      'D: Japanese Home at 2.0x text scale -- budget and savings goal sections remain '
      'usable/readable, no overflow/render exceptions',
      (tester) async {
        tester.view.physicalSize = const Size(400, 2600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

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
        final SavingsGoalRepository goalRepo = SavingsGoalRepository(db);
        // A Japanese, user-entered goal name -- never translated by the
        // app (classification B: user/database content), included here to
        // also confirm it renders untouched alongside the localized UI
        // copy around it.
        final String goalId = await goalRepo.createGoal(
          // `flutter analyze` flags a second `profile!.id` here as an
          // unnecessary_non_null_assertion: `profile` is promoted to
          // non-nullable after the `setOverallBudget` call above already
          // asserted it non-null, and it's never reassigned in between.
          profileId: profile.id,
          name: '緊急資金',
          targetAmount: Money.fromMinorUnits(100000, 'JPY'),
        );
        await SavingsGoalContributionRepository(db, goalRepo).addContribution(
          goalId: goalId,
          amount: Money.fromMinorUnits(30000, 'JPY'),
        );
        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          fxRateProviderProvider.overrideWithValue(_AlwaysUnavailableFxRateProvider()),
          referenceFxRateCacheProvider.overrideWithValue(InMemoryReferenceFxRateCache()),
        ],
        );
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRouter(container, locale: const Locale('ja')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('今月の残り予算'), findsOneWidget);
        expect(find.byKey(const Key('budgetStatusChip')), findsOneWidget);
        expect(find.text('貯蓄目標'), findsOneWidget);
        expect(find.text('緊急資金'), findsOneWidget);
      },
    );

    testWidgets(
      'E: Japanese Home at 320px width with enlarged text keeps every digit of a large MMK '
      'remaining amount, stacking it below its localized "of <budgeted>" line',
      (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.view.physicalSize = const Size(320, 2200);
        tester.view.devicePixelRatio = 1.0;
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        final AppDatabase db = await seededDb(
          living: 'MMK',
          home: 'MMK',
          accounts: <_SeedAccount>[const _SeedAccount(name: 'MMK Wallet', currencyCode: 'MMK')],
        );
        final ProfileRow? profile = await ProfileRepository(db).getProfile();
        await BudgetRepository(db).setOverallBudget(
          profileId: profile!.id,
          month: BudgetMonth.fromUtc(DateTime.now().toUtc()),
          amount: Money.fromMinorUnits(999999999, 'MMK'), // K9,999,999.99
        );
        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          fxRateProviderProvider.overrideWithValue(_AlwaysUnavailableFxRateProvider()),
          referenceFxRateCacheProvider.overrideWithValue(InMemoryReferenceFxRateCache()),
        ],
        );
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRouter(container, locale: const Locale('ja')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('K9,999,999.99'), findsOneWidget);
        expect(find.text('K9,999,999.99のうち'), findsOneWidget);
        expect(find.byKey(const Key('budgetAmountStacked')), findsOneWidget);
        expect(find.byKey(const Key('budgetAmountSideBySide')), findsNothing);
      },
    );

    testWidgets(
      'F: navigation regression -- tapping the localized budget call-to-action still routes '
      'to the budgets screen under the Japanese locale',
      (tester) async {
        useTallSurface(tester);
        final AppDatabase db = await seededDb(
          living: 'JPY',
          home: 'JPY',
          accounts: <_SeedAccount>[const _SeedAccount(name: 'JPY Wallet', currencyCode: 'JPY')],
        );
        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          fxRateProviderProvider.overrideWithValue(_AlwaysUnavailableFxRateProvider()),
          referenceFxRateCacheProvider.overrideWithValue(InMemoryReferenceFxRateCache()),
        ],
        );
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRouter(container, locale: const Locale('ja')));
        await tester.pumpAndSettle();

        final Finder ctaFinder = find.widgetWithText(OutlinedButton, '今月の予算を設定');
        expect(ctaFinder, findsOneWidget);

        await tester.tap(ctaFinder);
        await tester.pumpAndSettle();
        expect(find.text('BUDGETS_SCREEN_STUB'), findsOneWidget);
      },
    );
  });

  group('9. Checkpoint 9.5 Task F -- Home/Living currency equivalent', () {
    // NOTE (Repair #2): fetchedAt/observedAt default to the real wall
    // clock, not a hardcoded calendar date -- same root cause and same
    // fix as the analogous bug in reference_rate_provider_test.dart's own
    // `_referenceRate` helper (Repair #1, Task 4). Production wires
    // ReferenceFxRateService without an injected NowUtc override, so its
    // freshness check always runs against the real wall clock here too;
    // a fixed past default (DateTime.utc(2026, 6, 1)) eventually falls
    // outside the 1-hour freshness window purely because real time moved
    // on, silently flipping a test meant to exercise the FRESH path into
    // exercising the STALE fallback instead (extra "(cached)" text).
    // Callers that explicitly want a stale entry still pass their own
    // relative-to-now `fetchedAt` (see the "(cached)" test below), which
    // this default leaves untouched.
    ReferenceFxRate referenceRate(String base, String quote, String value, {DateTime? fetchedAt}) =>
        ReferenceFxRate(
          rate: FxRate(baseCurrencyCode: base, quoteCurrencyCode: quote, rate: value),
          source: 'exchangerate-api.com',
          observedAt: fetchedAt ?? DateTime.now().toUtc(),
          fetchedAt: fetchedAt ?? DateTime.now().toUtc(),
        );

    testWidgets(
      'a secondary card whose currency differs from the living currency shows a quiet '
      '"≈ <living currency amount>" line once a fresh reference rate resolves',
      (tester) async {
        useTallSurface(tester);
        final AppDatabase db = await seededDb(
          living: 'JPY',
          home: 'LKR',
          accounts: <_SeedAccount>[
            const _SeedAccount(name: 'JPY Wallet', currencyCode: 'JPY'),
            _SeedAccount(
              name: 'LKR Wallet',
              currencyCode: 'LKR',
              // 1000.00 LKR (2 minor units) = 100000 minor units.
              openingBalance: Money.fromMinorUnits(100000, 'LKR'),
            ),
          ],
        );
        final ReferenceFxRateCache cache = InMemoryReferenceFxRateCache();
        await cache.put(referenceRate('LKR', 'JPY', '0.50'));
        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[
            appDatabaseProvider.overrideWithValue(db),
            fxRateProviderProvider.overrideWithValue(_AlwaysUnavailableFxRateProvider()),
            referenceFxRateCacheProvider.overrideWithValue(cache),
          ],
        );
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithHome(container));
        await tester.pumpAndSettle();

        // 1000 LKR * 0.50 (LKR -> JPY) = 500 JPY, formatted with
        // MoneyFormatter -- never fabricated, never summed with the JPY
        // card's own balance.
        expect(find.byKey(const Key('livingCurrencyEquivalent_LKR')), findsOneWidget);
        expect(find.text('≈ ¥500'), findsOneWidget);
      },
    );

    testWidgets(
      'the hero card gets its own equivalent line too when the hero currency differs '
      'from the living currency',
      (tester) async {
        useTallSurface(tester);
        // Living currency VND, but the user holds no VND account -- the
        // hero card ends up being whichever currency sorts first
        // (JPY, alphabetically before USD here), which is NOT the
        // living currency, so the hero card itself needs an equivalent
        // line exactly like a secondary card would.
        final AppDatabase db = await seededDb(
          living: 'VND',
          home: 'JPY',
          accounts: <_SeedAccount>[
            _SeedAccount(
              name: 'JPY Wallet',
              currencyCode: 'JPY',
              // 100 JPY (0 minor units) = 100 minor units.
              openingBalance: Money.fromMinorUnits(100, 'JPY'),
            ),
          ],
        );
        final ReferenceFxRateCache cache = InMemoryReferenceFxRateCache();
        await cache.put(referenceRate('JPY', 'VND', '164.50'));
        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[
            appDatabaseProvider.overrideWithValue(db),
            fxRateProviderProvider.overrideWithValue(_AlwaysUnavailableFxRateProvider()),
            referenceFxRateCacheProvider.overrideWithValue(cache),
          ],
        );
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithHome(container));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('heroCurrencyCard_JPY')), findsOneWidget);
        expect(find.byKey(const Key('livingCurrencyEquivalent_JPY')), findsOneWidget);
      },
    );

    testWidgets(
      'a card whose currency already IS the living currency shows no equivalent line at all',
      (tester) async {
        useTallSurface(tester);
        final AppDatabase db = await seededDb(
          living: 'JPY',
          home: 'JPY',
          accounts: <_SeedAccount>[const _SeedAccount(name: 'JPY Wallet', currencyCode: 'JPY')],
        );
        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[
            appDatabaseProvider.overrideWithValue(db),
            fxRateProviderProvider.overrideWithValue(_AlwaysUnavailableFxRateProvider()),
            referenceFxRateCacheProvider.overrideWithValue(InMemoryReferenceFxRateCache()),
          ],
        );
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithHome(container));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('livingCurrencyEquivalent_JPY')), findsNothing);
      },
    );

    testWidgets(
      'a stale cached rate still shows the equivalent line, with a "(cached)" indicator',
      (tester) async {
        useTallSurface(tester);
        final AppDatabase db = await seededDb(
          living: 'JPY',
          home: 'LKR',
          accounts: <_SeedAccount>[
            const _SeedAccount(name: 'JPY Wallet', currencyCode: 'JPY'),
            _SeedAccount(
              name: 'LKR Wallet',
              currencyCode: 'LKR',
              // 1000.00 LKR (2 minor units) = 100000 minor units.
              openingBalance: Money.fromMinorUnits(100000, 'LKR'),
            ),
          ],
        );
        final ReferenceFxRateCache cache = InMemoryReferenceFxRateCache();
        await cache.put(
          referenceRate(
            'LKR',
            'JPY',
            '0.50',
            fetchedAt: DateTime.now().toUtc().subtract(const Duration(hours: 5)),
          ),
        );
        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[
            appDatabaseProvider.overrideWithValue(db),
            fxRateProviderProvider.overrideWithValue(_AlwaysUnavailableFxRateProvider()),
            referenceFxRateCacheProvider.overrideWithValue(cache),
          ],
        );
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithHome(container));
        await tester.pumpAndSettle();

        expect(find.text('≈ ¥500 (cached)'), findsOneWidget);
      },
    );

    testWidgets(
      'an unavailable reference rate (no cache, provider failing) shows no equivalent line, '
      'and never throws',
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
          overrides: <Override>[
            appDatabaseProvider.overrideWithValue(db),
            fxRateProviderProvider.overrideWithValue(_AlwaysUnavailableFxRateProvider()),
            referenceFxRateCacheProvider.overrideWithValue(InMemoryReferenceFxRateCache()),
          ],
        );
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithHome(container));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('livingCurrencyEquivalent_LKR')), findsOneWidget);
        expect(find.textContaining('≈'), findsNothing);
      },
    );
  });
}
