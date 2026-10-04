import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/providers.dart';
import 'package:ai_financial_coach/core/database/repositories/account_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/category_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/budget_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/transaction_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/recurring_rule_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/savings_goal_contribution_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/savings_goal_repository.dart';
import 'package:ai_financial_coach/core/finance/balance_class.dart';
import 'package:ai_financial_coach/core/finance/financial_account_subtype.dart';
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
import 'package:ai_financial_coach/shared/theme/app_theme.dart';
import 'package:ai_financial_coach/shared/widgets/app_card.dart';
import 'package:ai_financial_coach/shared/widgets/app_section_header.dart';
import 'package:ai_financial_coach/shared/widgets/app_icon_tile.dart';
import 'package:ai_financial_coach/shared/widgets/app_progress_bar.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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
    ThemeData? theme,
    Locale locale = const Locale('en'),
  }) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: theme,
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
    'Design Reversal Checkpoint: the hero card shows only "Total Balance" (no currency code, '
    'no "Living currency" badge) -- U3 Final Polish Pass: a second currency the user holds no '
    'longer renders a secondary summary card on Home at all',
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

      final Finder heroCard = find.byKey(const Key('heroCurrencyCard_JPY'));
      expect(heroCard, findsOneWidget);

      // Hero: exactly one "Total Balance" eyebrow, no currency-code label
      // and no "Living currency" badge anywhere on the card.
      expect(
        find.descendant(of: heroCard, matching: find.text('TOTAL BALANCE')),
        findsOneWidget,
      );
      expect(find.descendant(of: heroCard, matching: find.text('JPY')), findsNothing);
      expect(
        find.descendant(of: heroCard, matching: find.text('Living currency')),
        findsNothing,
      );

      // U3 Final Polish Pass (Home presentation cleanup): the LKR
      // secondary summary card -- and its "Home currency" badge -- no
      // longer render on Home at all, even though the user genuinely
      // holds an LKR account. That balance remains fully available on
      // the Accounts tab; this only asserts it isn't duplicated here.
      expect(find.byKey(const Key('secondaryCurrencyCard_LKR')), findsNothing);
      expect(find.text('Home currency'), findsNothing);
    },
  );

  testWidgets(
    'a negative balance keeps its minus sign and shows the negative-balance indicator on the '
    "hero card -- U3 Final Polish Pass: the EUR account's own balance no longer renders a "
    'second currency card on Home at all, so there is nothing left to confuse it with',
    (tester) async {
      useTallSurface(tester);
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

      // `_HeroCurrencyCard` carries a stable `heroCurrencyCard_<code>`
      // key specifically so tests can scope a finder to the hero card
      // instead of asserting over the whole page.
      final Finder heroCard = find.byKey(const Key('heroCurrencyCard_USD'));
      expect(heroCard, findsOneWidget);

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

      // U3 Final Polish Pass (Home presentation cleanup): the positive
      // EUR account no longer renders a secondary summary card on Home
      // at all -- confirming there's no separate place on this screen
      // for a negative indicator to leak into.
      expect(find.byKey(const Key('secondaryCurrencyCard_EUR')), findsNothing);
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
    'Checkpoint U3: the KakeiboPlus brand row and the greeting supporting line both render, '
    'and the greeting still greets the profile by name',
    (tester) async {
      useTallSurface(tester);
      final AppDatabase db = await seededDb(
        living: 'JPY',
        home: 'LKR',
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

      // Dashboard V1 Finalization checkpoint: the brand row is now
      // `_KakeiboBrandBar` -- a full-width teal/emerald bar with the
      // "KakeiboPlus" wordmark as plain white text (not the
      // `kakeiboplus-wordmark.png` asset, whose ink is a fixed color
      // meant for a light background -- see that class's own doc
      // comment) plus a profile action, rather than the former
      // Semantics-wrapped `Image`.
      expect(find.text('KakeiboPlus'), findsOneWidget);
      expect(find.byKey(const Key('brandBarProfileButton')), findsOneWidget);
      final Finder profileSemantics = find.byWidgetPredicate(
        (Widget widget) => widget is Semantics && widget.properties.label == 'Profile',
      );
      expect(profileSemantics, findsOneWidget);

      // Greeting: exactly one of the three time-of-day variants is
      // showing (whichever matches the real clock at test-run time),
      // always including the seeded profile's display name -- see
      // `greeting_period_test.dart` for the actual hour-boundary
      // coverage of which variant is picked.
      expect(find.textContaining('Test User'), findsWidgets);

      // Supporting line: present, and not itself mistaken for the
      // primary greeting (they're two separate `Text` widgets).
      expect(find.text('Small steps make a brighter future.'), findsOneWidget);
    },
  );

  testWidgets(
    'the Dashboard hero mascot renders inside the hero card, using the registered pets asset '
    'and never as a semantics-bearing (non-decorative) image',
    (tester) async {
      useTallSurface(tester);
      final AppDatabase db = await seededDb(
        living: 'JPY',
        home: 'LKR',
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

      // Mounted inside the JPY hero card specifically -- not merely
      // somewhere on screen -- matching docs/23 SS6.2 ("right side of
      // hero card").
      final Finder heroCardFinder = find.byKey(const Key('heroCurrencyCard_JPY'));
      final Finder mascotFinder = find.descendant(
        of: heroCardFinder,
        matching: find.byKey(const Key('dashboardMascot')),
      );
      expect(mascotFinder, findsOneWidget);

      // `dashboardMascot` keys the `DashboardMascot` wrapper itself, not
      // the `Image` it builds internally -- descend to the actual
      // `Image` for asset-path/semantics assertions.
      final Finder mascotImageFinder = find.descendant(
        of: mascotFinder,
        matching: find.byType(Image),
      );
      final Image mascotImage = tester.widget<Image>(mascotImageFinder);
      final AssetImage mascotAssetImage = mascotImage.image as AssetImage;
      expect(mascotAssetImage.assetName, 'assets/branding/pets/kakeiboplus_dog_default.png');

      // Purely decorative -- `excludeFromSemantics: true` and no
      // wrapping `Semantics` of its own means this image contributes
      // no semantics node at all, unlike the More screen's wordmark
      // (which deliberately IS announced). See `DashboardMascot`'s own
      // doc comment for why.
      expect(mascotImage.excludeFromSemantics, isTrue);
    },
  );

  testWidgets(
    'Design Reversal Checkpoint: the Dashboard hero mascot does not overflow or get clipped, '
    'and stays clear of the "TOTAL BALANCE" eyebrow and the balance amount beside it, on a '
    'narrow (320px-wide) screen',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1.0;

      final AppDatabase db = await seededDb(
        living: 'JPY',
        home: 'LKR',
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

      final Object? overflowException = tester.takeException();
      if (overflowException != null) {
        fail('Narrow-screen (320px) mascot layout threw an exception:\n\n$overflowException');
      }

      // The mascot and the "TOTAL BALANCE" eyebrow / balance amount are
      // all mounted and occupy disjoint horizontal space -- the hero
      // card's `Row`/`Expanded` layout makes this true by construction
      // (see `_HeroCurrencyCard`'s own doc comment), but this pins the
      // guarantee down as a test rather than only as a doc comment.
      final Finder heroCard = find.byKey(const Key('heroCurrencyCard_JPY'));
      final Finder mascotFinder = find.byKey(const Key('dashboardMascot'));
      expect(mascotFinder, findsOneWidget);
      final Rect heroRect = tester.getRect(heroCard);
      final Rect mascotRect = tester.getRect(mascotFinder);

      // U3 narrow-screen investigation (docs/14), Part A: the hero card
      // was silently shrink-wrapping to ~62% of the Dashboard's content
      // width (the text column's own `FractionallySizedBox` width
      // becoming the whole `Stack`'s width, and therefore the whole
      // `AppCard`'s width) instead of matching the other full-width
      // Dashboard sections (the 2x2 metrics grid, Upcoming/Spending/
      // Savings). `16` here is the Dashboard's own horizontal content
      // inset -- the same literal `SliverPadding` value every other
      // section is inset by, in `home_screen.dart` -- so this derives
      // the expected width from the actual test viewport rather than
      // hardcoding the hero's own pixel width.
      final double expectedContentWidth =
          tester.view.physicalSize.width / tester.view.devicePixelRatio - 2 * 16;
      expect(
        heroRect.width,
        closeTo(expectedContentWidth, 1.0),
        reason: 'heroRect=$heroRect should span the same full Dashboard content width '
            '($expectedContentWidth) as the other sections, not shrink-wrap to a '
            'fraction of it.',
      );

      // Scoped to the hero card itself -- `_MonthlyMetricsSection` right
      // below it also formats amounts with "¥", so an unscoped
      // `find.textContaining('¥')` would match more than one widget.
      final Rect eyebrowRect = tester.getRect(
        find.descendant(of: heroCard, matching: find.text('TOTAL BALANCE')),
      );
      final Rect amountRect = tester.getRect(
        find.descendant(of: heroCard, matching: find.textContaining('¥')),
      );

      // U3 narrow-screen investigation (docs/14), Part D: the temporary
      // `debugPrint` that unconditionally logged these Rects during the
      // investigation has been removed now that this test has passed
      // with a real, non-zero-Rect `mascotRect` -- the `reason:` strings
      // on the assertions below still surface the same values on a
      // future failure, without the unconditional noise on every run.
      //
      // U3 narrow-screen investigation (docs/14), Part B: this test
      // previously passed vacuously -- `Key('dashboardMascot')` sat
      // directly on `DashboardMascot`, whose `Image.asset` derives its
      // width from the decoded PNG's own aspect ratio, and before that
      // decode completed `tester.getRect` reported a real but
      // ZERO-WIDTH Rect (`left == right`), which can never overlap
      // anything via `Rect.overlaps()`. `Key('dashboardMascot')` now
      // sits on an explicit-size `SizedBox` in `_HeroCurrencyCard`
      // instead (see that call site), so `mascotRect` should be a
      // genuine, decode-independent box from here on. These two
      // assertions guard against the same false-green failure mode
      // recurring silently in the future.
      expect(
        mascotRect.width,
        greaterThan(0),
        reason: 'mascotRect=$mascotRect has zero width -- the measured Key is not attached to '
            'the actual visible mascot box (see this test\'s own doc comment above).',
      );
      expect(
        mascotRect.height,
        greaterThan(0),
        reason: 'mascotRect=$mascotRect has zero height -- the measured Key is not attached to '
            'the actual visible mascot box (see this test\'s own doc comment above).',
      );

      expect(
        mascotRect.overlaps(eyebrowRect),
        isFalse,
        reason: 'heroRect=$heroRect mascotRect=$mascotRect eyebrowRect=$eyebrowRect '
            'amountRect=$amountRect',
      );

      expect(
        mascotRect.overlaps(amountRect),
        isFalse,
        reason: 'heroRect=$heroRect mascotRect=$mascotRect eyebrowRect=$eyebrowRect '
            'amountRect=$amountRect',
      );
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

      expect(find.image(const AssetImage('assets/icons/dashboard/upcoming.png')), findsOneWidget);
      // Dashboard V1 Finalization checkpoint (ADR-048) gave this card
      // a Home-only ARB key, separate from `l10n.recurringTitle`
      // ("Recurring" -- unchanged, still the Recurring screen's own
      // AppBar title/the More screen's row) and a warm "You're all
      // caught up" empty-state treatment instead of the old generic
      // `AppEmptyState` message. ADR-049 then changed that same key's
      // VALUE from "Upcoming commitments" to just "Upcoming" (never
      // "Upcoming * Next 7 days") -- see ADR-049 for why.
      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('No upcoming payments'), findsOneWidget);
      expect(find.text("You're all caught up!"), findsOneWidget);
      expect(find.text('Recurring bills and reminders will appear here.'), findsOneWidget);

      final Finder ctaFinder = find.widgetWithText(OutlinedButton, 'Set up recurring');
      expect(ctaFinder, findsOneWidget);
      await tester.tap(ctaFinder);
      await tester.pumpAndSettle();
      expect(find.text('RECURRING_SCREEN_STUB'), findsOneWidget);
    },
  );

  testWidgets(
    'ADR-049: a single due-today recurring rule renders as the Upcoming card\'s one row -- '
    'never a summed total -- and "View all" routes to the recurring screen',
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
      expect(find.textContaining('Due today'), findsOneWidget);
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

      // Checkpoint 10 Visual Convergence follow-up: scoped to the
      // savings goals card itself (`Key('savingsGoalsCard')`) rather
      // than a bare `find.byIcon`, which now also matches the unrelated
      // Home quick-glance row's own goal icon above this card.
      expect(
        find.image(const AssetImage('assets/icons/dashboard/savings_goal.png')),
        findsOneWidget,
      );
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

      // Home's section order has grown since this test was first
      // written (brand header, greeting, hero, 2x2 metrics grid,
      // Upcoming commitments, Spending this month, THEN Savings
      // Goals), so the goals card's own content may now sit outside
      // what's already built even at this generous 2200px test
      // height. Scroll to the card itself first, using the same
      // established pattern as every other scrolled assertion in this
      // file, rather than asserting on a finder that never had a
      // chance to see it.
      await tester.scrollUntilVisible(find.byKey(const Key('savingsGoalsCard')), 300.0);
      await tester.pumpAndSettle();

      expect(find.text('₫500,000,000'), findsOneWidget);
      expect(find.text('of ₫999,999,999'), findsOneWidget);
      expect(find.byKey(const Key('goalAmountStacked')), findsOneWidget);
      expect(find.byKey(const Key('goalAmountSideBySide')), findsNothing);
    },
  );

  testWidgets(
    'ADR-049: the Upcoming row renders every digit of a KWD amount with 3 decimal places, '
    'unclipped, at 320px width and a 1.6x text scale',
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
      // ADR-049: the Upcoming row no longer pairs the amount with a
      // date on one `_AdaptiveAmountLine` (that widget stays in use by
      // the Savings Goals card, unchanged) -- the amount now sits in
      // its own fixed-position column in `_UpcomingRow`'s outer `Row`,
      // with the title/metadata column (`Expanded`) yielding space to
      // it instead. The guarantee this test exists for -- every digit
      // of a 3-decimal-place KWD amount renders, never clipped, at
      // 320px + 1.6x text scale -- still holds; it just has no
      // `recurringAmountStacked`/`recurringAmountSideBySide` key to
      // assert on any more.
      expect(find.text('د.ك12,345.678'), findsOneWidget);
    },
  );

  // ============================================================
  // ADR-049 (docs/14_DECISION_LOG.md): the Upcoming card becomes a
  // compact, capped multi-row list (overdue + due-today + next-7-days)
  // instead of a single nearest item. These tests cover the new
  // multi-row rendering itself; `selectHomeUpcomingItems`'s own
  // filtering/ordering/capping semantics have dedicated, isolated unit
  // coverage in `recurring_providers_test.dart` and are NOT re-verified
  // here through the widget tree.
  // ============================================================
  group('ADR-049: Upcoming card multi-row redesign', () {
    testWidgets(
      'an overdue, a due-today, and an upcoming item each render as their own row, with the '
      'correct label, and "View all" is still shown',
      (tester) async {
        useTallSurface(tester);
        final AppDatabase db = await seededDb(
          living: 'JPY',
          home: 'JPY',
          accounts: <_SeedAccount>[const _SeedAccount(name: 'JPY Wallet', currencyCode: 'JPY')],
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
        final DateTime todayUtc = DateTime.now().toUtc();
        final DateTime today = DateTime.utc(todayUtc.year, todayUtc.month, todayUtc.day);
        final RecurringRuleRepository ruleRepo = RecurringRuleRepository(db, AccountRepository(db));
        await ruleRepo.createRule(
          profileId: profile!.id,
          kind: RecurringRuleKind.expense,
          name: 'Overdue Rent',
          amount: Money.fromMinorUnits(80000, 'JPY'),
          accountId: account.id,
          frequency: RecurrenceFrequency.monthly,
          interval: 1,
          startDate: today.subtract(const Duration(days: 5)),
        );
        await ruleRepo.createRule(
          profileId: profile.id,
          kind: RecurringRuleKind.expense,
          name: 'Due Today Internet',
          amount: Money.fromMinorUnits(5000, 'JPY'),
          accountId: account.id,
          frequency: RecurrenceFrequency.monthly,
          interval: 1,
          startDate: today,
        );
        await ruleRepo.createRule(
          profileId: profile.id,
          kind: RecurringRuleKind.expense,
          name: 'Upcoming Gym',
          amount: Money.fromMinorUnits(3000, 'JPY'),
          accountId: account.id,
          frequency: RecurrenceFrequency.monthly,
          interval: 1,
          startDate: today.add(const Duration(days: 3)),
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

        // Exact row titles. `find.text` requires a full-string match, so
        // these can never collide with the metadata line below even
        // though both happen to contain the substring "Overdue" (this
        // test names the rule itself "Overdue Rent").
        expect(find.text('Overdue Rent'), findsOneWidget);
        expect(find.text('Due Today Internet'), findsOneWidget);
        expect(find.text('Upcoming Gym'), findsOneWidget);
        // Exact overdue/due-today metadata lines (Recurring UX
        // checkpoint, Part A5 -- home_screen.dart's `_UpcomingRow`
        // builds these as '${l10n.overdueLabel} · $exactDateLabel' and
        // '${l10n.recurringStatusDueToday} · $exactDateLabel'). A bare
        // `textContaining('Overdue')`/`textContaining('Due today')` is
        // no longer precise now that a row's own title can also
        // contain either substring -- asserting the exact status line
        // instead verifies the real UI piece (the metadata text), not
        // a generic substring count.
        expect(
          find.text(
            'Overdue · ${DateFormat.yMMMd().format(today.subtract(const Duration(days: 5)))}',
          ),
          findsOneWidget,
        );
        expect(
          find.text('Due today · ${DateFormat.yMMMd().format(today)}'),
          findsOneWidget,
        );
        // 'In N days' relative phrasing no longer renders for upcoming
        // items -- the redesigned metadata line shows a bare exact
        // date instead (Recurring UX checkpoint, Part A5). Compute the
        // real expected string from this test's own seeded date using
        // the exact same formatter production uses.
        expect(
          find.text(DateFormat.yMMMd().format(today.add(const Duration(days: 3)))),
          findsOneWidget,
        );
        expect(find.byKey(const Key('viewAllRecurringButton')), findsOneWidget);
      },
    );

    testWidgets(
      'more than kHomeUpcomingMaxRows pending items are capped to exactly 3 visible rows',
      (tester) async {
        useTallSurface(tester);
        final AppDatabase db = await seededDb(
          living: 'JPY',
          home: 'JPY',
          accounts: <_SeedAccount>[const _SeedAccount(name: 'JPY Wallet', currencyCode: 'JPY')],
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
        final DateTime todayUtc = DateTime.now().toUtc();
        final DateTime today = DateTime.utc(todayUtc.year, todayUtc.month, todayUtc.day);
        final RecurringRuleRepository ruleRepo = RecurringRuleRepository(db, AccountRepository(db));
        const List<String> names = <String>['Overdue A', 'Overdue B', 'Overdue C', 'Overdue D'];
        for (int i = 0; i < names.length; i++) {
          await ruleRepo.createRule(
            profileId: profile!.id,
            kind: RecurringRuleKind.expense,
            name: names[i],
            amount: Money.fromMinorUnits(1000, 'JPY'),
            accountId: account.id,
            frequency: RecurrenceFrequency.monthly,
            interval: 1,
            startDate: today.subtract(Duration(days: i + 1)),
          );
        }
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

        // All 4 rules are overdue, so every one of them would legitimately
        // qualify -- only `kHomeUpcomingMaxRows` (3) may actually render.
        // Each visible row's title now ALSO contains the substring
        // "Overdue" (every fixture rule here is literally named
        // "Overdue <letter>"), on top of its own status/date metadata
        // line also containing "Overdue" -- so a bare
        // `textContaining('Overdue')` count is no longer a valid proxy
        // for "how many rows are visible" (3 visible rows legitimately
        // produce 6 such matches, not 3). Row count is instead proven
        // structurally: `_UpcomingList` inserts exactly one inset
        // `Divider` between consecutive rows and none after the last
        // one, so N visible rows produce exactly N-1 dividers inside
        // the Upcoming card.
        final int visibleCount = names.where((n) => find.text(n).evaluate().isNotEmpty).length;
        expect(visibleCount, 3);
        expect(
          find.descendant(
            of: find.byKey(const Key('upcomingCommitmentsCard')),
            matching: find.byType(Divider),
          ),
          findsNWidgets(2), // 3 rows -> 2 inset dividers between them.
        );
        // The ordering itself is "oldest missed date first" (see
        // test/features/recurring/presentation/recurring_providers_test.dart,
        // 'overdue ordering -- oldest missed date first'), so among
        // Overdue A (1 day overdue) .. D (4 days overdue) the 3 that
        // win the cap are D, C, B -- the least-overdue, A, is the one
        // dropped.
        expect(find.text('Overdue D'), findsOneWidget);
        expect(find.text('Overdue C'), findsOneWidget);
        expect(find.text('Overdue B'), findsOneWidget);
        expect(find.text('Overdue A'), findsNothing);
      },
    );

    testWidgets(
      'identity icon precedence: a service identity wins over a chosen category icon',
      (tester) async {
        useTallSurface(tester);
        final AppDatabase db = await seededDb(
          living: 'JPY',
          home: 'JPY',
          accounts: <_SeedAccount>[const _SeedAccount(name: 'JPY Wallet', currencyCode: 'JPY')],
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
        final String categoryId = await CategoryRepository(db).createCategory(
          profileId: profile!.id,
          name: 'Dining',
          type: 'expense',
          icon: 'restaurant',
        );
        final DateTime todayUtc = DateTime.now().toUtc();
        final DateTime today = DateTime.utc(todayUtc.year, todayUtc.month, todayUtc.day);
        await RecurringRuleRepository(db, AccountRepository(db)).createRule(
          profileId: profile.id,
          kind: RecurringRuleKind.expense,
          name: 'Netflix',
          amount: Money.fromMinorUnits(1490, 'JPY'),
          accountId: account.id,
          categoryId: categoryId,
          serviceIdentityKey: 'netflix',
          frequency: RecurrenceFrequency.monthly,
          interval: 1,
          startDate: today,
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

        // Service identity (streaming family -> Icons.smart_display) wins
        // over the rule's own chosen category icon (Icons.restaurant) --
        // `TransactionIconBadge`'s existing precedence ladder, reused
        // verbatim, never re-implemented for this row.
        expect(find.byIcon(Icons.smart_display), findsOneWidget);
        expect(find.byIcon(Icons.restaurant), findsNothing);
        // The category badge is still shown from the rule's own resolved
        // category, independent of which icon won.
        expect(find.text('Dining'), findsOneWidget);
      },
    );

    testWidgets(
      'the category badge renders only for a rule with a real resolved category -- never '
      'invented for one with none',
      (tester) async {
        useTallSurface(tester);
        final AppDatabase db = await seededDb(
          living: 'JPY',
          home: 'JPY',
          accounts: <_SeedAccount>[const _SeedAccount(name: 'JPY Wallet', currencyCode: 'JPY')],
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
        final String categoryId = await CategoryRepository(db).createCategory(
          profileId: profile!.id,
          name: 'Dining',
          type: 'expense',
          icon: 'restaurant',
        );
        final DateTime todayUtc = DateTime.now().toUtc();
        final DateTime today = DateTime.utc(todayUtc.year, todayUtc.month, todayUtc.day);
        final RecurringRuleRepository ruleRepo = RecurringRuleRepository(db, AccountRepository(db));
        await ruleRepo.createRule(
          profileId: profile.id,
          kind: RecurringRuleKind.expense,
          name: 'Categorized Rule',
          amount: Money.fromMinorUnits(2000, 'JPY'),
          accountId: account.id,
          categoryId: categoryId,
          frequency: RecurrenceFrequency.monthly,
          interval: 1,
          startDate: today,
        );
        await ruleRepo.createRule(
          profileId: profile.id,
          kind: RecurringRuleKind.expense,
          name: 'Uncategorized Rule',
          amount: Money.fromMinorUnits(2500, 'JPY'),
          accountId: account.id,
          frequency: RecurrenceFrequency.monthly,
          interval: 1,
          startDate: today,
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

        expect(find.text('Categorized Rule'), findsOneWidget);
        expect(find.text('Uncategorized Rule'), findsOneWidget);
        // The category badge ("Dining") appears exactly once -- for the
        // categorized rule only, never fabricated for the other one.
        expect(find.text('Dining'), findsOneWidget);
      },
    );

    testWidgets(
      'an uncategorized income or transfer rule falls back to a kind-label badge '
      '("Income"/"Transfer"), while an uncategorized expense rule still omits the badge',
      (tester) async {
        useTallSurface(tester);
        final AppDatabase db = await seededDb(
          living: 'JPY',
          home: 'JPY',
          accounts: <_SeedAccount>[
            const _SeedAccount(name: 'JPY Wallet', currencyCode: 'JPY'),
            const _SeedAccount(name: 'JPY Savings', currencyCode: 'JPY'),
          ],
        );
        final ProfileRow? profile = await ProfileRepository(db).getProfile();
        final AccountRepository accountRepo = AccountRepository(db);
        final List<AccountRow> accounts = await (db.select(db.accounts)
              ..where((tbl) => tbl.profileId.equals(profile!.id) & tbl.deletedAt.isNull()))
            .get();
        final AccountRow walletAccount = accounts.firstWhere((a) => a.name == 'JPY Wallet');
        final AccountRow savingsAccount = accounts.firstWhere((a) => a.name == 'JPY Savings');
        final DateTime todayUtc = DateTime.now().toUtc();
        final DateTime today = DateTime.utc(todayUtc.year, todayUtc.month, todayUtc.day);
        final RecurringRuleRepository ruleRepo = RecurringRuleRepository(db, accountRepo);
        await ruleRepo.createRule(
          profileId: profile!.id,
          kind: RecurringRuleKind.income,
          name: 'Uncategorized Salary',
          amount: Money.fromMinorUnits(280000, 'JPY'),
          accountId: walletAccount.id,
          frequency: RecurrenceFrequency.monthly,
          interval: 1,
          startDate: today,
        );
        await ruleRepo.createRule(
          profileId: profile.id,
          kind: RecurringRuleKind.transfer,
          name: 'Uncategorized Savings Sweep',
          amount: Money.fromMinorUnits(20000, 'JPY'),
          accountId: walletAccount.id,
          destinationAccountId: savingsAccount.id,
          frequency: RecurrenceFrequency.monthly,
          interval: 1,
          startDate: today,
        );
        await ruleRepo.createRule(
          profileId: profile.id,
          kind: RecurringRuleKind.expense,
          name: 'Uncategorized Expense Again',
          amount: Money.fromMinorUnits(2500, 'JPY'),
          accountId: walletAccount.id,
          frequency: RecurrenceFrequency.monthly,
          interval: 1,
          startDate: today,
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

        expect(find.text('Uncategorized Salary'), findsOneWidget);
        expect(find.text('Uncategorized Savings Sweep'), findsOneWidget);
        expect(find.text('Uncategorized Expense Again'), findsOneWidget);
        // Income/transfer rules with no resolved category now show a
        // kind-label badge as a fallback (Part A4); the uncategorized
        // expense rule continues to show no badge at all, exactly as the
        // "never invented for one with none" test above already pins down
        // for the expense case specifically.
        expect(find.text('Income'), findsOneWidget);
        expect(find.text('Transfer'), findsOneWidget);
      },
    );

    testWidgets(
      'two due-today items in different currencies both render their own amount, '
      'independently -- never summed',
      (tester) async {
        useTallSurface(tester);
        final AppDatabase db = await seededDb(
          living: 'JPY',
          home: 'JPY',
          accounts: <_SeedAccount>[
            const _SeedAccount(name: 'JPY Wallet', currencyCode: 'JPY'),
            const _SeedAccount(name: 'USD Wallet', currencyCode: 'USD'),
          ],
        );
        final ProfileRow? profile = await ProfileRepository(db).getProfile();
        final AccountRepository accountRepo = AccountRepository(db);
        final List<AccountRow> accounts = await (db.select(db.accounts)
              ..where((tbl) => tbl.profileId.equals(profile!.id) & tbl.deletedAt.isNull()))
            .get();
        final AccountRow jpyAccount = accounts.firstWhere((a) => a.currencyCode == 'JPY');
        final AccountRow usdAccount = accounts.firstWhere((a) => a.currencyCode == 'USD');
        final DateTime todayUtc = DateTime.now().toUtc();
        final DateTime today = DateTime.utc(todayUtc.year, todayUtc.month, todayUtc.day);
        final RecurringRuleRepository ruleRepo = RecurringRuleRepository(db, accountRepo);
        await ruleRepo.createRule(
          profileId: profile!.id,
          kind: RecurringRuleKind.expense,
          name: 'JPY Rule',
          amount: Money.fromMinorUnits(80000, 'JPY'),
          accountId: jpyAccount.id,
          frequency: RecurrenceFrequency.monthly,
          interval: 1,
          startDate: today,
        );
        await ruleRepo.createRule(
          profileId: profile.id,
          kind: RecurringRuleKind.expense,
          name: 'USD Rule',
          amount: Money.fromMinorUnits(999, 'USD'),
          accountId: usdAccount.id,
          frequency: RecurrenceFrequency.monthly,
          interval: 1,
          startDate: today,
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

        expect(find.text('¥80,000'), findsOneWidget);
        expect(find.text('\$9.99'), findsOneWidget);
      },
    );

    testWidgets(
      'the Upcoming card with 3 rows lays out without overflow on a narrow (320px) screen',
      (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.view.physicalSize = const Size(320, 1400);
        tester.view.devicePixelRatio = 1.0;

        final AppDatabase db = await seededDb(
          living: 'JPY',
          home: 'JPY',
          accounts: <_SeedAccount>[const _SeedAccount(name: 'JPY Wallet', currencyCode: 'JPY')],
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
        final String categoryId = await CategoryRepository(db).createCategory(
          profileId: profile!.id,
          name: 'Subscriptions',
          type: 'expense',
          icon: 'restaurant',
        );
        final DateTime todayUtc = DateTime.now().toUtc();
        final DateTime today = DateTime.utc(todayUtc.year, todayUtc.month, todayUtc.day);
        final RecurringRuleRepository ruleRepo = RecurringRuleRepository(db, AccountRepository(db));
        await ruleRepo.createRule(
          profileId: profile.id,
          kind: RecurringRuleKind.expense,
          name: 'A rather long recurring rule name to stress narrow-width layout',
          amount: Money.fromMinorUnits(80000, 'JPY'),
          accountId: account.id,
          categoryId: categoryId,
          serviceIdentityKey: 'netflix',
          frequency: RecurrenceFrequency.monthly,
          interval: 1,
          startDate: today.subtract(const Duration(days: 2)),
        );
        await ruleRepo.createRule(
          profileId: profile.id,
          kind: RecurringRuleKind.expense,
          name: 'Due Today Item',
          amount: Money.fromMinorUnits(5000, 'JPY'),
          accountId: account.id,
          frequency: RecurrenceFrequency.monthly,
          interval: 1,
          startDate: today,
        );
        await ruleRepo.createRule(
          profileId: profile.id,
          kind: RecurringRuleKind.expense,
          name: 'Upcoming Item',
          amount: Money.fromMinorUnits(3000, 'JPY'),
          accountId: account.id,
          frequency: RecurrenceFrequency.monthly,
          interval: 1,
          startDate: today.add(const Duration(days: 4)),
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
          fail(
            'Narrow-screen (320px) Upcoming card layout (3 rows, one with a long name, a '
            'category badge, and a service icon) threw an exception:\n\n$overflowException',
          );
        }
      },
    );

    testWidgets(
      'the Upcoming card with 3 rows lays out without overflow at a 1.6x text scale',
      (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.view.physicalSize = const Size(320, 1800);
        tester.view.devicePixelRatio = 1.0;
        tester.platformDispatcher.textScaleFactorTestValue = 1.6;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        final AppDatabase db = await seededDb(
          living: 'JPY',
          home: 'JPY',
          accounts: <_SeedAccount>[const _SeedAccount(name: 'JPY Wallet', currencyCode: 'JPY')],
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
        final String categoryId = await CategoryRepository(db).createCategory(
          profileId: profile!.id,
          name: 'Subscriptions',
          type: 'expense',
          icon: 'restaurant',
        );
        final DateTime todayUtc = DateTime.now().toUtc();
        final DateTime today = DateTime.utc(todayUtc.year, todayUtc.month, todayUtc.day);
        final RecurringRuleRepository ruleRepo = RecurringRuleRepository(db, AccountRepository(db));
        await ruleRepo.createRule(
          profileId: profile.id,
          kind: RecurringRuleKind.expense,
          name: 'A rather long recurring rule name to stress narrow-width layout',
          amount: Money.fromMinorUnits(80000, 'JPY'),
          accountId: account.id,
          categoryId: categoryId,
          frequency: RecurrenceFrequency.monthly,
          interval: 1,
          startDate: today.subtract(const Duration(days: 2)),
        );
        await ruleRepo.createRule(
          profileId: profile.id,
          kind: RecurringRuleKind.expense,
          name: 'Due Today Item',
          amount: Money.fromMinorUnits(5000, 'JPY'),
          accountId: account.id,
          frequency: RecurrenceFrequency.monthly,
          interval: 1,
          startDate: today,
        );
        await ruleRepo.createRule(
          profileId: profile.id,
          kind: RecurringRuleKind.expense,
          name: 'Upcoming Item',
          amount: Money.fromMinorUnits(3000, 'JPY'),
          accountId: account.id,
          frequency: RecurrenceFrequency.monthly,
          interval: 1,
          startDate: today.add(const Duration(days: 4)),
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
          fail(
            'Upcoming card layout at 1.6x text scale (3 rows, one with a long name and a '
            'category badge) threw an exception:\n\n$overflowException',
          );
        }
      },
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
      'the savings goals and recurring cards also render bordered -- converged '
      'consistently with the rest of Home, not just the budget card',
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

        // Checkpoint 10 Visual Convergence follow-up: scoped to
        // `Key('savingsGoalsCard')` -- a bare
        // `find.byIcon(Icons.flag_outlined)` now also matches the
        // unrelated Home quick-glance row's goal icon above this card,
        // which made `tester.element(...)` throw "Too many elements".
        final BuildContext context = tester.element(find.byKey(const Key('savingsGoalsCard')));
        final ColorScheme colors = Theme.of(context).colorScheme;
        final AppTokens tokens = context.appTokens;
        for (final key in <String>['savingsGoalsCard', 'upcomingCommitmentsCard']) {
          final Card card = tester.widget<Card>(find.descendant(
            of: find.byKey(Key(key)), matching: find.byType(Card),
          ));
          expect(card.color, colors.surface, reason: '$key should be bordered');
          final RoundedRectangleBorder shape = card.shape! as RoundedRectangleBorder;
          expect(shape.side.color, tokens.colors.subtleBorder, reason: '$key should be bordered');
        }
        // U3 Final Polish Pass (Home presentation cleanup): this used to
        // also assert the per-account balance list's own `Card` was
        // bordered the same way -- that list no longer renders on Home
        // at all, so there's nothing left here to assert on it. The
        // account tile's own bordered-card styling is still covered on
        // its real, current screen (`test/widget/accounts_screen_test.dart`).
      },
    );

    testWidgets(
      'the savings/recurring section headers keep their exact original English title text '
      'even with the eyebrow styling applied',
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
        expect(find.text('Savings Goals'), findsOneWidget);
        expect(find.text('Upcoming'), findsOneWidget);
        // U3 Final Polish Pass: the "Accounts" section header (and the
        // per-account list it used to sit above) no longer renders on
        // Home at all -- see the dedicated removal test below.
        expect(find.text('Accounts'), findsNothing);
        // U3 Final Polish Pass (item 2): the full Budget detail card
        // (and its "Remaining monthly budget" section header) no
        // longer renders on Home at all -- Remaining Budget is already
        // represented in the 2x2 metrics grid above.
        expect(find.text('Remaining monthly budget'), findsNothing);
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
        // Final U3 Visual Polish Pass: the "Home" AppBar title is removed
        // outright -- the brand wordmark row is now the sole top
        // identity. `l10n.navHome` ("ホーム") still labels the bottom-nav
        // destination in `app_shell.dart` (untouched, a separate widget,
        // not exercised by this Home-only pump), so this assertion is
        // simply dropped rather than replaced with a `findsNothing` that
        // would just be re-asserting the removal forever.
        // Checkpoint U3 replaced the old fixed "{name}さん、こんにちは" greeting
        // with a time-of-day-aware one (`GreetingPeriod.forHour` ->
        // `homeGreetingMorning`/`Afternoon`/`Evening`) -- `HomeScreen` reads
        // the real wall-clock hour via `DateTime.now().hour`, which this
        // widget test has no seam to control deterministically, so this
        // asserts the actual real Japanese localization behavior without
        // depending on which one is currently showing: exactly one of the
        // three exact, fully-localized greetings (built from the SAME
        // `l10n.homeGreetingMorning/Afternoon/Evening` strings `app_ja.arb`
        // defines, with this test's own seeded 'Test User' display name)
        // must render -- never zero (a broken/missing greeting), never
        // more than one (a rendering bug), and never the removed fixed
        // string. See `greeting_period_test.dart` for the actual
        // hour-boundary coverage of which variant `GreetingPeriod.forHour`
        // picks -- that pure logic is unchanged and untouched here.
        final List<String> possibleJapaneseGreetings = <String>[
          'おはようございます、Test Userさん！',
          'こんにちは、Test Userさん！',
          'こんばんは、Test Userさん！',
        ];
        final int matchingGreetings = possibleJapaneseGreetings
            .where((String greeting) => find.text(greeting).evaluate().isNotEmpty)
            .length;
        expect(
          matchingGreetings,
          1,
          reason:
              'Expected exactly one of the three time-of-day Japanese greetings to render, '
              'got $matchingGreetings matches',
        );
        // The new supporting line (docs/23 SS4.2), also real Japanese
        // localization, not a placeholder -- independent of which
        // greeting variant above is currently showing.
        expect(find.text('小さな一歩が、明るい未来をつくります。'), findsOneWidget);
        // U3 Final Polish Pass: the Japanese "Accounts" heading (口座)
        // and "Manage" button (管理) no longer render on Home at all --
        // see the dedicated removal test below.
        expect(find.text('口座'), findsNothing);
        expect(find.text('管理'), findsNothing);
        expect(find.text('合計残高'), findsOneWidget); // hero eyebrow (dashboardTotalBalanceLabel)
        expect(find.text('今月の収入'), findsOneWidget);
        // Part C: "今月の支出" is also SpendingByCategorySection's own
        // (different-English-source) title in Japanese -- scoped to the
        // 2x2 grid's Monthly Spending tile, this check's actual subject.
        expect(
          find.descendant(
            of: find.byKey(const Key('monthlySpendingTile')),
            matching: find.text('今月の支出'),
          ),
          findsOneWidget,
        );
        expect(find.text('1日あたりの支出ペース'), findsOneWidget);
        // U3 Final Polish Pass (item 2): the full Budget detail card
        // (and its Japanese section header) no longer renders on Home
        // at all -- Remaining Budget is already represented in the 2x2
        // metrics grid above.
        expect(find.text('今月の残り予算'), findsNothing);
        expect(find.text('貯蓄目標'), findsOneWidget); // savings goals card title, empty state
        expect(find.text('今後の予定'), findsOneWidget); // upcoming card title, empty state (ADR-049)
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

        // Design Reversal Checkpoint (ADR-047): the hero card no longer
        // shows a "Living currency" badge (`生活通貨`) at all -- that
        // assertion was stale after the hero simplification and is
        // replaced with checks against the new approved hero structure:
        // its "TOTAL BALANCE" eyebrow (`合計残高`), the hero card itself,
        // and its single balance amount, still rendering correctly in
        // Japanese at 1.6x text scale without overflow.
        final Finder heroCard = find.byKey(const Key('heroCurrencyCard_JPY'));
        expect(heroCard, findsOneWidget);
        expect(
          find.descendant(of: heroCard, matching: find.text('合計残高')),
          findsOneWidget,
        ); // hero eyebrow (dashboardTotalBalanceLabel)
        expect(
          find.descendant(of: heroCard, matching: find.textContaining('¥')),
          findsOneWidget,
        ); // the hero's single balance amount, still rendered
        expect(find.text('小さな一歩が、明るい未来をつくります。'), findsOneWidget); // greeting supporting line

        // U3 Final Polish Pass: the LKR secondary card (and its "Home
        // currency" badge, 基準通貨) no longer renders on Home at all;
        // the hero's own former "Living currency" badge is still not
        // restored anywhere either.
        expect(find.byKey(const Key('secondaryCurrencyCard_LKR')), findsNothing);
        expect(find.text('生活通貨'), findsNothing);
        expect(find.text('基準通貨'), findsNothing);
        expect(find.text('今月の収入'), findsOneWidget); // hero's own 2x2 grid tile only now
        // "今月の支出" is a legitimate, intentional duplicate in Japanese:
        // the 2x2 grid's Monthly Spending tile and the "Spending this
        // month" section header (`homeSpendingThisMonthTitle`) happen to
        // share the exact same translated string, even though their
        // English source strings ("Monthly Spending" vs "Spending this
        // month") differ. Scope to the grid tile specifically via its
        // own `Key('monthlySpendingTile')` rather than asserting a
        // global count of 1, which would wrongly demand renaming either
        // (still-correct) Japanese string.
        expect(
          find.descendant(
            of: find.byKey(const Key('monthlySpendingTile')),
            matching: find.text('今月の支出'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'D: Japanese Home at 2.0x text scale -- the savings goal section remains '
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
        final SavingsGoalRepository goalRepo = SavingsGoalRepository(db);
        // A Japanese, user-entered goal name -- never translated by the
        // app (classification B: user/database content), included here to
        // also confirm it renders untouched alongside the localized UI
        // copy around it.
        final String goalId = await goalRepo.createGoal(
          // U3 Final Polish Pass (item 2): this test's former budget
          // setup (which used to promote `profile` non-null via an
          // earlier `profile!.id`) was removed along with the budget
          // assertions below -- see this same test's own updated
          // title/scope. `!` restored here since this is now the
          // first/only use of `profile`.
          profileId: profile!.id,
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
        // U3 Final Polish Pass (item 2): the full Budget detail card
        // (its Japanese title and status chip) no longer renders on
        // Home at all -- this test now scopes to the savings goal
        // section only, its actual remaining subject.
        expect(find.text('今月の残り予算'), findsNothing);
        expect(find.text('貯蓄目標'), findsOneWidget);
        expect(find.text('緊急資金'), findsOneWidget);
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

  });

  // ============================================================
  // Dashboard V1 Finalization checkpoint: the former Budgets/Goals
  // "quick glance" row (`_BudgetGoalsQuickGlanceRow`, tested above in
  // earlier rounds) is gone -- superseded by the 2x2 monthly-metrics
  // grid (`_MonthlyMetricsGrid`), whose four cards are Monthly Income,
  // Monthly Spending, Remaining Budget, and Daily Spending Pace. These
  // tests lock in: all four grid tiles render with their stable keys,
  // the Remaining Budget tile's honest empty state (no fabricated
  // figure) before a budget exists, its real figures once one does, and
  // that the grid doesn't overflow at a narrow width.
  // ============================================================

  group('Dashboard V1 Finalization -- 2x2 monthly metrics grid', () {
    testWidgets(
      'renders all four independent grid tiles, and the Remaining Budget tile shows an '
      'honest "Not set" empty state before any budget is configured',
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

        expect(find.byKey(const Key('monthlyIncomeTile')), findsOneWidget);
        expect(find.byKey(const Key('monthlySpendingTile')), findsOneWidget);
        expect(find.byKey(const Key('remainingBudgetTile')), findsOneWidget);
        expect(find.byKey(const Key('dailySpendingPaceTile')), findsOneWidget);

        expect(
          find.descendant(
            of: find.byKey(const Key('remainingBudgetTile')),
            matching: find.text('Remaining Budget'),
          ),
          findsOneWidget,
        );
        // Never a fabricated figure -- honestly reads "Not set" until
        // the user actually configures an overall budget, exactly like
        // the real Budget detail screen (`AppRoutes.budgets`) does.
        expect(
          find.descendant(
            of: find.byKey(const Key('remainingBudgetTile')),
            matching: find.text('Not set'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'the Remaining Budget tile shows the real remaining amount and days-left once an '
      'overall budget is configured -- the same figures the real Budget detail screen '
      'computes, never a second calculation -- but no longer shows a separate "Budget '
      'total" line (Dashboard presentation-only simplification: the full budget amount is '
      'still available on the Budget detail screen, never removed from the underlying model)',
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

        await tester.pumpWidget(appWithHome(container));
        await tester.pumpAndSettle();

        final Finder tile = find.byKey(const Key('remainingBudgetTile'));
        expect(find.descendant(of: tile, matching: find.text('Not set')), findsNothing);
        // ¥0 spent of ¥120,000 configured -- the tile's own remaining
        // figure happens to also read ¥120,000 (nothing spent yet), a
        // real, provider-derived value, never invented for this
        // display.
        expect(find.descendant(of: tile, matching: find.textContaining('¥120,000')), findsWidgets);
        // Icon-balance visual-polish pass (Remaining Budget
        // simplification): the former separate "Budget ¥120,000"
        // total-line label no longer renders on this compact Dashboard
        // card -- see the dedicated icon-container test below for the
        // explicit `findsNothing` regression guard on that exact text.
      },
    );

    testWidgets(
      'the 2x2 monthly metrics grid lays out without overflow on a narrow (320px-wide) screen',
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

        final Object? overflowException = tester.takeException();
        if (overflowException != null) {
          fail(
            'Narrow-screen (320px) monthly metrics grid threw an exception:\n\n'
            '$overflowException',
          );
        }
      },
    );

    testWidgets(
      'Final reference-match pass: all four 2x2 metric-card titles render their full English '
      'text on exactly ONE line at normal phone width (never ellipsized, never wrapped to a '
      'second line), and all four cards are the same height -- Remaining Budget does not end '
      'up taller than the others',
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

        await tester.pumpWidget(appWithHome(container));
        await tester.pumpAndSettle();

        // The exact full English title strings -- if any of these were
        // silently truncated at the character/data level (rather than
        // just visually wrapping), an exact `find.text(...)` match
        // would already fail outright.
        for (final String title in <String>[
          'Monthly Income',
          'Monthly Spending',
          'Remaining Budget',
          'Daily Spending Pace',
        ]) {
          final Finder titleFinder = find.text(title);
          expect(
            titleFinder,
            findsOneWidget,
            reason: 'title "$title" did not render in full on one line at normal phone width '
                '-- it may have been wrapped or ellipsized',
          );
          final Text titleWidget = tester.widget<Text>(titleFinder);
          // Final reference-match pass: pinned to exactly ONE line --
          // see `_metricTitleText`'s own updated doc comment. `find
          // .text(title)` above already proves the FULL string is
          // present as one piece of text (an ellipsized render would
          // not match the exact string), so this just pins the
          // `maxLines`/`overflow` CONFIGURATION itself, guarding
          // against a future regression back to 2-line wrapping.
          expect(
            titleWidget.maxLines,
            1,
            reason: '"$title" should render on exactly one line, never wrap to a second',
          );
          expect(titleWidget.overflow, TextOverflow.ellipsis);
        }

        // All four cards genuinely the same height -- not just the two
        // pairwise-equal rows each `IntrinsicHeight` row only matched
        // against ITSELF. `_computeMetricsGridTileHeight` (reference-
        // layout final pass) is what derives that one shared height and
        // applies it to every one of the four cards; this pins that
        // down as an actual assertion rather than only a doc comment.
        final Rect incomeRect = tester.getRect(find.byKey(const Key('monthlyIncomeTile')));
        final Rect spendingRect = tester.getRect(find.byKey(const Key('monthlySpendingTile')));
        final Rect remainingBudgetRect = tester.getRect(
          find.byKey(const Key('remainingBudgetTile')),
        );
        final Rect paceRect = tester.getRect(find.byKey(const Key('dailySpendingPaceTile')));
        final double incomeHeight = incomeRect.height;
        final double spendingHeight = spendingRect.height;
        final double remainingBudgetHeight = remainingBudgetRect.height;
        final double paceHeight = paceRect.height;

        for (final double height in <double>[spendingHeight, remainingBudgetHeight, paceHeight]) {
          expect(
            height,
            closeTo(incomeHeight, 4.0),
            reason: 'incomeHeight=$incomeHeight spendingHeight=$spendingHeight '
                'remainingBudgetHeight=$remainingBudgetHeight paceHeight=$paceHeight',
          );
        }

        // Final card-dimension pass: all four tiles' real width should
        // land close to the ~170px reference target (this test's own
        // simulated 400-logical-px-wide surface, minus the screen's
        // existing horizontal padding and the inter-card gap, divided
        // by two, yields a real tile width in this neighborhood --
        // never hard-coded, just bounded generously so a real
        // page-padding or gap change doesn't make this test flaky).
        for (final double width in <double>[
          incomeRect.width,
          spendingRect.width,
          remainingBudgetRect.width,
          paceRect.width,
        ]) {
          expect(
            width,
            inInclusiveRange(150.0, 195.0),
            reason: 'tile width=$width should stay close to the ~170px reference target',
          );
        }

        // Regression guard (final card-dimension pass): the approved
        // reference target is a compact ~170x100 card, replacing the
        // previous, much more generous `lessThan(190.0)`-only guard
        // (inherited from the reference-layout final pass, before the
        // padding/footer compaction this pass makes). The bound below
        // is intentionally a range, not a single pixel value -- it
        // only needs to catch a return to the old, much-taller
        // behavior on one side and a now-broken, overly-squashed
        // layout on the other; if this fails on a real device/font-
        // metrics combination with a legitimately compact-looking
        // result, retune the threshold against the printed height
        // above rather than deleting the guard.
        // Approved (final card-dimension pass): real measurement came
        // back at 178x106 for all four tiles -- this range is the
        // durable regression guard for that approved result, not a
        // provisional estimate any more.
        expect(
          incomeHeight,
          inInclusiveRange(95.0, 110.0),
          reason: 'shared 2x2 metric-tile height is $incomeHeight -- the approved compact '
              'target is ~106px; a value outside this range suggests the equal-height '
              'calculation is over- or under-allocating',
        );
      },
    );

    testWidgets(
      'SVG-reference polish pass: all four 2x2 icon containers render at the same '
      '[AppIconTileSize], no fabricated "vs last month"/"vs target" comparison label ever '
      'appears (no real month-over-month or daily-target data exists), and the Remaining '
      'Budget progress bar\'s real value matches the real spent/budgeted ratio',
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

        await tester.pumpWidget(appWithHome(container));
        await tester.pumpAndSettle();

        // Icon containers: all four 2x2 tiles must use the exact same
        // [AppIconTileSize] -- never one card with a visually bigger or
        // smaller icon box than its siblings.
        for (final Key tileKey in const <Key>[
          Key('monthlyIncomeTile'),
          Key('monthlySpendingTile'),
          Key('remainingBudgetTile'),
          Key('dailySpendingPaceTile'),
        ]) {
          final AppIconTile tile = tester.widget<AppIconTile>(
            find.descendant(of: find.byKey(tileKey), matching: find.byType(AppIconTile)),
          );
          expect(
            tile.size,
            // Final reference-match pass: bumped to `.large` (48/24,
            // was `.medium` 40/20) to match the reference's larger
            // icon -- still asserting all four 2x2 tiles share
            // whatever the one size is, which is the actual property
            // under test here.
            AppIconTileSize.large,
            reason: '$tileKey should use the same icon-container size as every other 2x2 tile',
          );
        }

        // No fabricated comparison labels: no real month-over-month
        // income/spending comparison and no real daily-spend target
        // exist anywhere in this app yet, so neither Income/Spending's
        // "vs last month" nor Daily Spending Pace's "vs target" footer
        // (both shown only as EXAMPLE placeholder values in the
        // `cards.svg` design reference) may ever actually render.
        expect(find.textContaining('vs last month'), findsNothing);
        expect(find.textContaining('vs target'), findsNothing);

        // Remaining Budget's progress bar renders the real clamped
        // spent/budgeted ratio -- ¥0 spent of ¥120,000 budgeted here,
        // so `value` must be exactly 0.0, never a placeholder/invented
        // figure.
        final AppProgressBar bar = tester.widget<AppProgressBar>(
          find.descendant(
            of: find.byKey(const Key('remainingBudgetTile')),
            matching: find.byType(AppProgressBar),
          ),
        );
        expect(bar.value, 0.0);

        // The Section 6 hairline `Divider` that used to precede the
        // (now-removed) "Budget <total>" line was intentionally
        // removed in the final card-dimension pass -- this test no
        // longer expects one; asserting `findsNothing` pins that
        // removal down as the approved design, not a silent
        // regression.
        expect(
          find.descendant(
            of: find.byKey(const Key('remainingBudgetTile')),
            matching: find.byType(Divider),
          ),
          findsNothing,
        );
        // Icon-balance visual-polish pass (Remaining Budget
        // simplification): the separate "Budget ¥120,000" total-line
        // label is REMOVED from this compact Dashboard card -- the
        // full budget amount is still available on the Budget detail
        // screen (untouched), this is presentation-only. `findsNothing`
        // pins that removal down as the approved design, replacing the
        // former `findsOneWidget` expectation.
        expect(
          find.descendant(
            of: find.byKey(const Key('remainingBudgetTile')),
            matching: find.text('Budget ¥120,000'),
          ),
          findsNothing,
        );

        // Icon-balance visual-polish pass: all four 2x2 icon
        // CONTAINERS must render at literally the same real pixel
        // size -- `tile.size` above only proves they share the same
        // named [AppIconTileSize] tier; now that [AppIconTile] also
        // supports a per-call `containerSize`/`glyphSize` override (so
        // this grid's icons can sit at 44px, between that tier's 40/48
        // without touching any OTHER screen's icons), this measures
        // the actual rendered box for every one of the four cards and
        // confirms they are pixel-identical to each other.
        final List<Size> iconContainerSizes = <Size>[
          for (final Key tileKey in const <Key>[
            Key('monthlyIncomeTile'),
            Key('monthlySpendingTile'),
            Key('remainingBudgetTile'),
            Key('dailySpendingPaceTile'),
          ])
            tester.getSize(
              find.descendant(of: find.byKey(tileKey), matching: find.byType(AppIconTile)),
            ),
        ];
        for (final Size size in iconContainerSizes) {
          expect(
            size,
            iconContainerSizes.first,
            reason: 'every 2x2 card icon container should render at the identical pixel size '
                'for the four icons to look optically balanced; got $iconContainerSizes',
          );
        }
      },
    );

    testWidgets(
      'Micro-polish pass: Daily Spending Pace\'s full supporting caption renders without '
      'ellipsis at normal phone width (allowed up to 2 real lines instead of being cut to '
      '"Average spen..."), the Remaining Budget progress TRACK widens to the tile\'s full '
      'usable width instead of the narrow icon-indented column, its fill stays the real '
      '30%-used spent/budgeted ratio, and all four 2x2 cards remain equal height',
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
          amount: Money.fromMinorUnits(120000, 'JPY'),
        );
        // Test-bug fix: a real, non-zero, non-100% spend so this test
        // actually exercises the distinction between the progress
        // TRACK (should span most of the card) and the gradient FILL
        // (should span only the real ratio) -- at 0% spent (the
        // previous fixture) both a correct and an incorrectly-narrow
        // measurement could look superficially similar in intent, so a
        // real ¥36,000-of-¥120,000 (30%) expense, via the exact same
        // `TransactionRepository.recordExpense` pattern the Spending-
        // by-category tests above already use, makes the assertion
        // meaningful and matches the real app via the SAME
        // `monthlyBudgetSummaryProvider` -- never a second calculation.
        final AccountRepository accountRepo = AccountRepository(db);
        final accountQuery = db.select(db.accounts)
          ..where(
            (tbl) =>
                tbl.profileId.equals(profile.id) &
                tbl.isActive.equals(true) &
                tbl.deletedAt.isNull(),
          );
        final AccountRow account = (await accountQuery.get()).first;
        await CategoryRepository(db).seedSystemCategoriesIfNeeded();
        final categoryQuery = db.select(db.categories)
          ..where((tbl) => tbl.profileId.isNull() & tbl.type.equals('expense'));
        final CategoryRow category = (await categoryQuery.get()).first;
        await TransactionRepository(db, accountRepo).recordExpense(
          profileId: profile.id,
          accountId: account.id,
          amount: Money.fromMinorUnits(36000, 'JPY'), // ¥36,000 of ¥120,000 = 30%
          categoryId: category.id,
          occurredAtUtc: DateTime.now().toUtc(),
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

        // The full English caption text must actually be present in
        // the tree (not substituted with an ellipsized fragment) --
        // `find.text` requires an exact match, so this alone already
        // fails if Flutter ellipsized it down to "Average spen...".
        final Finder paceCaption = find.descendant(
          of: find.byKey(const Key('dailySpendingPaceTile')),
          matching: find.text('Daily average so far'),
        );
        expect(paceCaption, findsOneWidget);
        final Text paceCaptionWidget = tester.widget<Text>(paceCaption);
        expect(
          paceCaptionWidget.maxLines,
          2,
          reason: 'Pace caption should allow up to 2 real lines instead of forcing one',
        );
        expect(tester.takeException(), isNull);

        // Test-bug fix (round 6): round 5's diagnostic measurement
        // (tileWidth=178, topRowWidth=146, footerRowWidth=146,
        // percentTextWidth=99.2, trackWidth=38.8) proved there never
        // was a real layout bug -- the footer row already spans the
        // full 146px card content width, EXACTLY matching the top row
        // above it (never narrowed back to the old icon-indented
        // column), and trackWidth + gap(8) + percentTextWidth adds up
        // to footerRowWidth exactly (38.8 + 8 + 99.2 = 146): `Expanded`
        // was always handing `AppProgressBar` its correct, full real
        // allocation.
        //
        // The only reason `trackWidth` itself measured small is that
        // `flutter test` has no real font loaded, so the 8-character
        // "N% used" label renders each character as a fixed box sized
        // to `bodySmall` (12) plus Material 3's `letterSpacing` (0.4)
        // -- 8 x (12 + 0.4) = 99.2px here, roughly double its real
        // ~50px Roboto width on an actual device (consistent with the
        // emulator screenshot already approved for this 178x106 card).
        // Asserting `trackWidth` against a fraction of the card's
        // width would therefore fail forever on this test-font
        // artifact alone, regardless of how correct the real
        // production layout is -- so the real regression guard below
        // measures the FOOTER ROW itself (immune to how wide its
        // sibling label happens to render in-test), which is the thing
        // that actually distinguishes "spans the full card" from "the
        // old icon-indented column".
        final double tileWidth =
            tester.getRect(find.byKey(const Key('remainingBudgetTile'))).width;
        final double footerRowWidth = tester
            .getRect(find.byKey(const Key('remainingBudgetProgressFooterRow')))
            .width;
        expect(
          footerRowWidth,
          greaterThan(tileWidth * 0.7),
          reason: 'progress footer row width=$footerRowWidth should span most of the '
              'approved card width=$tileWidth, not just the old icon-indented text column',
        );

        // Lighter internal-consistency check: the real track (kept
        // addressable via `AppProgressBar`'s own `trackKey`) should
        // still be the dominant part of that footer row, not a sliver
        // -- generous on purpose, since its exact pixel width in-test
        // is skewed by the sibling label's test-font rendering above.
        final double trackWidth = tester
            .getRect(
              find.descendant(
                of: find.byKey(const Key('remainingBudgetTile')),
                matching: find.byKey(const Key('remainingBudgetProgressTrack')),
              ),
            )
            .width;
        expect(trackWidth, greaterThan(0.0));

        // B. The real `BudgetCalculation` ratio reaches the component,
        // read directly from the constructor field: ¥36,000 spent of
        // ¥120,000 budgeted => exactly 0.30, proving the Dashboard
        // passes the correct financial ratio, never a placeholder.
        final AppProgressBar bar = tester.widget<AppProgressBar>(
          find.descendant(
            of: find.byKey(const Key('remainingBudgetTile')),
            matching: find.byType(AppProgressBar),
          ),
        );
        expect(bar.value, closeTo(0.3, 0.0001));

        // All four cards still render at the same height.
        final double incomeHeight =
            tester.getRect(find.byKey(const Key('monthlyIncomeTile'))).height;
        final double spendingHeight =
            tester.getRect(find.byKey(const Key('monthlySpendingTile'))).height;
        final double remainingBudgetHeight =
            tester.getRect(find.byKey(const Key('remainingBudgetTile'))).height;
        final double paceHeight =
            tester.getRect(find.byKey(const Key('dailySpendingPaceTile'))).height;
        for (final double height in <double>[spendingHeight, remainingBudgetHeight, paceHeight]) {
          expect(
            height,
            closeTo(incomeHeight, 4.0),
            reason: 'incomeHeight=$incomeHeight spendingHeight=$spendingHeight '
                'remainingBudgetHeight=$remainingBudgetHeight paceHeight=$paceHeight',
          );
        }
        // No height explosion: the two-line caption and the wider
        // progress bar should still land within the same approved
        // ~106px compact envelope as the dedicated dimension test
        // above.
        expect(incomeHeight, inInclusiveRange(95.0, 110.0));
      },
    );

    testWidgets(
      'Micro-polish pass: the 2x2 metrics grid (including the now-2-line Daily Spending '
      'Pace caption and the full-width Remaining Budget progress row) lays out without '
      'overflow at 320px width and at a large text scale',
      (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1.0;
        // Established idiom for text-scale stress tests in this repo
        // (see `budgets_screen_test.dart`) -- `platformDispatcher
        // .textScaleFactorTestValue`, not a hand-built `MediaQuery`
        // override, so this test goes through the exact same
        // `appWithHome` harness (theme/localization wiring included)
        // every other test in this file already relies on.
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

        await tester.pumpWidget(appWithHome(container));
        await tester.pumpAndSettle();

        expect(
          tester.takeException(),
          isNull,
          reason: 'narrow (320px) + 1.6x text scale should not overflow the 2x2 metrics grid',
        );
      },
    );
  });

  group('U3 Final Polish Pass -- Home presentation cleanup (account/currency summary removal)', () {
    testWidgets(
      'Home no longer renders the per-currency secondary summary cards, the "Accounts" '
      'section header, the "Manage" button, or the per-account balance list -- those remain '
      'available on the Accounts tab, this screen just stops duplicating them',
      (tester) async {
        useTallSurface(tester);
        final AppDatabase db = await seededDb(
          living: 'JPY',
          home: 'USD',
          accounts: <_SeedAccount>[
            const _SeedAccount(name: 'JPY Everyday Wallet', currencyCode: 'JPY'),
            const _SeedAccount(name: 'USD Travel Card', currencyCode: 'USD'),
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

        // The hero card for the living (JPY) currency still renders --
        // this pass never touched the hero.
        expect(find.byKey(const Key('heroCurrencyCard_JPY')), findsOneWidget);

        // The USD account genuinely exists and holds a real balance --
        // proving its absence below is a removed SECTION, not a
        // coincidental empty state.
        expect(find.byKey(const Key('secondaryCurrencyCard_USD')), findsNothing);
        expect(find.text('Home currency'), findsNothing);
        expect(find.text('Living currency'), findsNothing);

        // The "Accounts" section (header and every individual account
        // tile) is gone from Home entirely. `manageBudgetsButton` is
        // also asserted `findsNothing` here -- U3 Final Polish Pass
        // (item 2) removed the full Budget detail card (and its
        // "Manage" button) from Home entirely, so this key now never
        // renders on Home regardless of whether a budget is configured
        // (see `home_screen_test.dart`'s dedicated Budget-removal
        // assertions elsewhere in this file for that scenario
        // specifically); it remains reachable on the real Budget detail
        // screen, untouched.
        expect(find.text('Accounts'), findsNothing);
        expect(find.byKey(const Key('manageBudgetsButton')), findsNothing);
        expect(find.text('JPY Everyday Wallet'), findsNothing);
        expect(find.text('USD Travel Card'), findsNothing);

        // What's left, in order: brand header, greeting, hero, 2x2
        // metrics grid, Upcoming commitments, Spending this month, and
        // Savings Goals -- still all present, all untouched by this
        // cleanup. The full Budget detail card that used to render
        // after Savings Goals was removed by a separate, later pass
        // (U3 Final Polish Pass, item 2) as unnecessary duplication of
        // the 2x2 grid's own Remaining Budget tile.
        expect(find.byKey(const Key('upcomingCommitmentsCardSection')), findsOneWidget);
        expect(find.byKey(const Key('monthlyIncomeTile')), findsOneWidget);
      },
    );
  });

  // -- Dashboard V1 Finalization -- "Spending this month": a donut +
  // legend fed by `homeCategorySpendingProvider`
  // (`FinanceEngine.categoryExpenseTotals`, expense-only, current
  // calendar month, living currency) -- never a fabricated figure, and
  // colored via the same `categoryColorFor`/U1 category-identity
  // palette every other screen already uses.
  group('Dashboard V1 Finalization -- Spending this month (category breakdown)', () {
    testWidgets(
      'shows the calm "no spending yet" message when there are no expense transactions '
      'this month, rather than an empty chart',
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

        expect(find.text('Spending this month'), findsOneWidget);
        expect(find.byKey(const Key('spendingByCategoryCard')), findsOneWidget);
        expect(find.byKey(const Key('spendingEmptyMessage')), findsOneWidget);
        expect(find.text('No spending recorded this month yet.'), findsOneWidget);
      },
    );

    testWidgets(
      'renders real category expense totals and percentages once expenses are recorded, '
      'never a fabricated figure -- only expense transactions are counted, in the living '
      'currency, for the current calendar month',
      (tester) async {
        useTallSurface(tester);
        final AppDatabase db = await seededDb(
          living: 'JPY',
          home: 'JPY',
          accounts: <_SeedAccount>[const _SeedAccount(name: 'JPY Wallet', currencyCode: 'JPY')],
        );
        final ProfileRow? profile = await ProfileRepository(db).getProfile();
        final AccountRepository accountRepo = AccountRepository(db);
        // Raw one-shot Drift queries, never `.watch(...).first` -- this
        // file's own established workaround (see the account lookup
        // above) for the documented hang when a stream's first event is
        // awaited as `testWidgets` pre-pump setup under its FakeAsync
        // test zone.
        final accountQuery = db.select(db.accounts)
          ..where(
            (tbl) =>
                tbl.profileId.equals(profile!.id) &
                tbl.isActive.equals(true) &
                tbl.deletedAt.isNull(),
          );
        final AccountRow account = (await accountQuery.get()).first;

        await CategoryRepository(db).seedSystemCategoriesIfNeeded();
        final categoryQuery = db.select(db.categories)
          ..where((tbl) => tbl.profileId.isNull() & tbl.type.equals('expense'));
        final List<CategoryRow> categories = await categoryQuery.get();
        expect(
          categories.length,
          greaterThanOrEqualTo(2),
          reason: 'a freshly-seeded profile should have system expense categories available',
        );

        final DateTime now = DateTime.now().toUtc();
        final TransactionRepository txRepo = TransactionRepository(db, accountRepo);
        // Part D (U3 narrow-screen investigation, docs/14): JPY has 0
        // minor units (see `Money`'s own class doc: `Money.fromMinorUnits
        // (1200, 'JPY')` is Y1,200, not Y12.00) -- `minorUnits` IS the
        // whole-yen amount for a 0-decimal currency, never a x100
        // subdivision. This fixture previously passed 300000/100000,
        // which is actually Y300,000/Y100,000 -- the category names still
        // rendered (that's why those assertions passed), but the real
        // amount text was never Y3,000/Y1,000, so the amount/percentage
        // assertions below could never find them. Corrected to the
        // values the comments (and the 75%/25% split) actually intend.
        await txRepo.recordExpense(
          profileId: profile!.id,
          accountId: account.id,
          amount: Money.fromMinorUnits(3000, 'JPY'), // ¥3,000
          categoryId: categories[0].id,
          occurredAtUtc: now,
        );
        await txRepo.recordExpense(
          profileId: profile.id,
          accountId: account.id,
          amount: Money.fromMinorUnits(1000, 'JPY'), // ¥1,000
          categoryId: categories[1].id,
          occurredAtUtc: now,
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

        final Finder card = find.byKey(const Key('spendingByCategoryCard'));
        expect(card, findsOneWidget);
        expect(find.byKey(const Key('spendingEmptyMessage')), findsNothing);
        expect(find.descendant(of: card, matching: find.text(categories[0].name)), findsOneWidget);
        expect(find.descendant(of: card, matching: find.text(categories[1].name)), findsOneWidget);
        // ¥3,000 + ¥1,000 = ¥4,000 total -- ¥3,000 is 75% and ¥1,000 is 25%,
        // real arithmetic on the seeded amounts, never an invented figure.
        expect(find.descendant(of: card, matching: find.textContaining('¥3,000')), findsOneWidget);
        expect(find.descendant(of: card, matching: find.textContaining('¥1,000')), findsOneWidget);
        expect(find.descendant(of: card, matching: find.text('75%')), findsOneWidget);
        expect(find.descendant(of: card, matching: find.text('25%')), findsOneWidget);
      },
    );

    testWidgets(
      'the "View details" trailing action routes to Activity -- the real place to see the '
      'underlying transactions -- rather than a dead link or an invented detail screen',
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

        expect(find.byKey(const Key('spendingViewDetailsButton')), findsOneWidget);
      },
    );
  });

  // -- Checkpoint J (docs/20 §13.14): Home privacy -- net worth is no
  // longer shown on Home at all. `dashboardCurrencySummariesProvider`
  // still computes `CurrencyDashboardSummary.netWorth` exactly as
  // Checkpoint I left it (dedicated, exhaustive coverage remains in
  // `test/core/dashboard/dashboard_providers_test.dart` and
  // `test/core/networth/net_worth_providers_test.dart`) -- these tests
  // exist only to lock in that `HomeScreen` itself never renders that
  // figure, or the words "Net worth", anywhere, even in scenarios
  // (deposit accounts, liabilities) where net worth and available
  // balance genuinely differ. The full net-worth breakdown is only
  // ever reachable via a deliberate tap on More's "Net Worth" row --
  // see `more_screen_test.dart` and `net_worth_screen_test.dart`.
  group('Checkpoint J -- Home privacy (no net worth shown)', () {
    /// Directly classifies each account via [AccountRepository.createClassifiedAccount]
    /// (Checkpoint B/G's real classification API) rather than
    /// [seededDb]'s plain-cash-only helper above, since these tests need
    /// a real `deposit`/`creditCard` subtype -- see
    /// `financial_account_subtype.dart`.
    Future<AppDatabase> seedClassifiedDb({
      required String living,
      required String home,
    }) async {
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      final ProfileRepository profileRepo = ProfileRepository(db);
      await profileRepo.createProfile(
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
      return db;
    }

    testWidgets(
      'a deposit lowers available balance below net worth, but Home shows only the '
      'available balance -- no "Net worth" text anywhere, on either currency card',
      (tester) async {
        useTallSurface(tester);
        final AppDatabase db = await seedClassifiedDb(living: 'JPY', home: 'USD');
        final String profileId = (await ProfileRepository(db).getProfile())!.id;
        final AccountRepository accountRepo = AccountRepository(db);
        await accountRepo.createClassifiedAccount(
          profileId: profileId,
          name: 'Wallet',
          type: 'cash',
          balanceClass: BalanceClass.asset,
          subtype: FinancialAccountSubtype.cash,
          currencyCode: 'JPY',
          openingBalance: Money.fromMinorUnits(5000, 'JPY'),
        );
        await accountRepo.createClassifiedAccount(
          profileId: profileId,
          name: 'Fixed Deposit',
          type: 'deposit',
          balanceClass: BalanceClass.asset,
          subtype: FinancialAccountSubtype.deposit,
          currencyCode: 'JPY',
          openingBalance: Money.fromMinorUnits(100000, 'JPY'),
        );
        await accountRepo.createClassifiedAccount(
          profileId: profileId,
          name: 'USD Wallet',
          type: 'cash',
          balanceClass: BalanceClass.asset,
          subtype: FinancialAccountSubtype.cash,
          currencyCode: 'USD',
          openingBalance: Money.fromMinorUnits(2000, 'USD'),
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

        final Finder heroCard = find.byKey(const Key('heroCurrencyCard_JPY'));
        expect(heroCard, findsOneWidget);
        // U3 Final Polish Pass: the USD secondary card no longer renders
        // on Home at all.
        expect(find.byKey(const Key('secondaryCurrencyCard_USD')), findsNothing);

        // Hero (JPY): shows ONLY the available balance (5000, deposit
        // excluded) -- the deposit's 100000 net-worth-only contribution
        // is nowhere on this screen.
        expect(find.descendant(of: heroCard, matching: find.text('¥5,000')), findsOneWidget);
        expect(find.descendant(of: heroCard, matching: find.text('¥105,000')), findsNothing);

        // Neither the hero card, nor the screen as a whole, ever shows
        // the words "Net worth" -- this is a privacy boundary, not a
        // conditional display rule.
        expect(
          find.descendant(of: heroCard, matching: find.textContaining('Net worth')),
          findsNothing,
        );
        expect(find.textContaining('Net worth'), findsNothing);
      },
    );

    testWidgets(
      'a mixed deposit + credit-card portfolio, plus a configured budget, never shows net '
      'worth on Home -- the Remaining Budget metrics tile remains unaffected, and the '
      'accounts do not spill into a duplicate list on Home',
      (tester) async {
        useTallSurface(tester);
        final AppDatabase db = await seedClassifiedDb(living: 'JPY', home: 'JPY');
        final String profileId = (await ProfileRepository(db).getProfile())!.id;
        final AccountRepository accountRepo = AccountRepository(db);
        await accountRepo.createClassifiedAccount(
          profileId: profileId,
          name: 'Wallet',
          type: 'cash',
          balanceClass: BalanceClass.asset,
          subtype: FinancialAccountSubtype.cash,
          currencyCode: 'JPY',
          openingBalance: Money.fromMinorUnits(5000, 'JPY'),
        );
        await accountRepo.createClassifiedAccount(
          profileId: profileId,
          name: 'Fixed Deposit',
          type: 'deposit',
          balanceClass: BalanceClass.asset,
          subtype: FinancialAccountSubtype.deposit,
          currencyCode: 'JPY',
          openingBalance: Money.fromMinorUnits(100000, 'JPY'),
        );
        await accountRepo.createClassifiedAccount(
          profileId: profileId,
          name: 'Credit Card',
          type: 'creditCard',
          balanceClass: BalanceClass.liability,
          subtype: FinancialAccountSubtype.creditCard,
          currencyCode: 'JPY',
          openingBalance: Money.fromMinorUnits(30000, 'JPY'),
        );
        await BudgetRepository(db).setOverallBudget(
          profileId: profileId,
          month: BudgetMonth.fromUtc(DateTime.now().toUtc()),
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

        await tester.pumpWidget(appWithHome(container));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // The would-be net worth figure (5000 + 100000 - 30000 =
        // 75000) never appears, nor does the words "Net worth", even
        // though this profile genuinely has a deposit and a liability.
        expect(find.text('Net worth: ¥75,000'), findsNothing);
        expect(find.textContaining('Net worth'), findsNothing);

        // U3 Final Polish Pass (item 2) removed the full Budget detail
        // card from Home, so the ONLY budget-progress presentation left
        // on Home is the 2x2 grid's Remaining Budget tile -- confirm
        // THAT is still completely untouched by this checkpoint and
        // still renders the configured budget's own remaining figure
        // (5000 spent 0, 50000 budgeted, so remaining is also ¥50,000).
        expect(
          find.descendant(
            of: find.byKey(const Key('remainingBudgetTile')),
            matching: find.textContaining('¥50,000'),
          ),
          findsWidgets,
        );

        // U3 Final Polish Pass: the per-account balance list no
        // longer renders on Home at all (these accounts remain fully
        // listed on the Accounts tab -- this only asserts they aren't
        // ALSO duplicated here).
        expect(find.text('Wallet'), findsNothing);
        expect(find.text('Fixed Deposit'), findsNothing);
        expect(find.text('Credit Card'), findsNothing);
      },
    );

    testWidgets(
      'the hero card survives a narrow (320px-wide) screen at a 1.6x text scale without '
      'overflow, still showing only the available balance and never "Net worth"',
      (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.view.physicalSize = const Size(320, 2200);
        tester.view.devicePixelRatio = 1.0;
        tester.platformDispatcher.textScaleFactorTestValue = 1.6;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        final AppDatabase db = await seedClassifiedDb(living: 'JPY', home: 'JPY');
        final String profileId = (await ProfileRepository(db).getProfile())!.id;
        final AccountRepository accountRepo = AccountRepository(db);
        await accountRepo.createClassifiedAccount(
          profileId: profileId,
          name: 'Wallet',
          type: 'cash',
          balanceClass: BalanceClass.asset,
          subtype: FinancialAccountSubtype.cash,
          currencyCode: 'JPY',
          openingBalance: Money.fromMinorUnits(5000, 'JPY'),
        );
        await accountRepo.createClassifiedAccount(
          profileId: profileId,
          name: 'Fixed Deposit',
          type: 'deposit',
          balanceClass: BalanceClass.asset,
          subtype: FinancialAccountSubtype.deposit,
          currencyCode: 'JPY',
          openingBalance: Money.fromMinorUnits(100000, 'JPY'),
        );
        await accountRepo.createClassifiedAccount(
          profileId: profileId,
          name: 'Credit Card',
          type: 'creditCard',
          balanceClass: BalanceClass.liability,
          subtype: FinancialAccountSubtype.creditCard,
          currencyCode: 'JPY',
          openingBalance: Money.fromMinorUnits(30000, 'JPY'),
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

        final Object? overflowException = tester.takeException();
        if (overflowException != null) {
          fail(
            'Narrow-screen (320px) + 1.6x text scale hero card (available balance only) '
            'threw an exception:\n\n$overflowException',
          );
        }

        expect(find.text('¥5,000'), findsOneWidget);
        expect(find.textContaining('Net worth'), findsNothing);
      },
    );
  });

  group('metric card responsive presentation', () {
    for (final double width in <double>[320, 360, 390, 430]) {
      for (final double scale in <double>[1, 1.6, 2]) {
        testWidgets('preserves content at ${width}px and ${scale}x', (tester) async {
          tester.view.physicalSize = Size(width, 2600);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final AppDatabase db = await seededDb(
            living: 'JPY',
            home: 'JPY',
            accounts: <_SeedAccount>[
              const _SeedAccount(name: 'Wallet', currencyCode: 'JPY'),
            ],
          );
          final profile = (await ProfileRepository(db).getProfile())!;
          await BudgetRepository(db).setOverallBudget(
            profileId: profile.id,
            month: BudgetMonth.fromUtc(DateTime.now().toUtc()),
            amount: Money.fromMinorUnits(14000, 'JPY'),
          );
          final container = ProviderContainer(
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
          for (final title in <String>[
            'Monthly Income', 'Monthly Spending', 'Remaining Budget', 'Daily Spending Pace',
          ]) {
            expect(find.text(title), findsOneWidget);
          }
          final budget = find.byKey(const Key('remainingBudgetTile'));
          expect(find.descendant(of: budget, matching: find.text('¥14,000')), findsOneWidget);
          expect(
            tester.widget<AppProgressBar>(
              find.descendant(of: budget, matching: find.byType(AppProgressBar)),
            ).value,
            0,
          );
          final incomeRect = tester.getRect(find.byKey(const Key('monthlyIncomeTile')));
          final spendingRect = tester.getRect(find.byKey(const Key('monthlySpendingTile')));
          if (width >= 390) {
            expect(incomeRect.top, spendingRect.top);
            expect(incomeRect.right, lessThan(spendingRect.left));
          } else {
            expect(incomeRect.bottom, lessThan(spendingRect.top));
          }
        });
      }
    }
  });

  for (final spent in <int>[0, 50, 112]) {
    testWidgets('Dashboard assets, external headers and status gradients: $spent', (tester) async {
      useTallSurface(tester);
      final db = await seededDb(living: 'JPY', home: 'JPY', accounts: <_SeedAccount>[
        const _SeedAccount(name: 'Wallet', currencyCode: 'JPY'),
      ]);
      final profile = (await ProfileRepository(db).getProfile())!;
      await BudgetRepository(db).setOverallBudget(
        profileId: profile.id, month: BudgetMonth.fromUtc(DateTime.now().toUtc()),
        amount: Money.fromMinorUnits(100, 'JPY'),
      );
      if (spent > 0) {
        final account = (await db.select(db.accounts).get()).single;
        await CategoryRepository(db).seedSystemCategoriesIfNeeded();
        final query = db.select(db.categories)..where((t) => t.type.equals('expense'));
        final category = (await query.get()).first;
        await TransactionRepository(db, AccountRepository(db)).recordExpense(
          profileId: profile.id, accountId: account.id,
          amount: Money.fromMinorUnits(spent, 'JPY'), categoryId: category.id,
          occurredAtUtc: DateTime.now().toUtc(),
        );
      }
      final goals = SavingsGoalRepository(db);
      final goalId = await goals.createGoal(profileId: profile.id, name: 'Goal',
        targetAmount: Money.fromMinorUnits(100, 'JPY'));
      await SavingsGoalContributionRepository(db, goals).addContribution(
        goalId: goalId, amount: Money.fromMinorUnits(30, 'JPY'));
      final container = ProviderContainer(overrides: <Override>[
        appDatabaseProvider.overrideWithValue(db),
        fxRateProviderProvider.overrideWithValue(_AlwaysUnavailableFxRateProvider()),
        referenceFxRateCacheProvider.overrideWithValue(InMemoryReferenceFxRateCache()),
      ]);
      addTearDown(() => disposeInOrder(tester, container, db));
      await tester.pumpWidget(appWithHome(container, theme: AppTheme.light()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      const assets = <String, String>{
        'monthlyIncomeTile': 'monthly_income', 'monthlySpendingTile': 'monthly_spending',
        'remainingBudgetTile': 'remaining_budget', 'dailySpendingPaceTile': 'daily_spending_pace',
      };
      for (final entry in assets.entries) {
        final image = find.descendant(of: find.byKey(Key(entry.key)),
          matching: find.image(AssetImage('assets/icons/dashboard/${entry.value}.png')));
        expect(image, findsOneWidget);
        expect(tester.getSize(image), const Size(32, 32));
        expect(tester.widget<Image>(image).excludeFromSemantics, isTrue);
      }
      const headers = <String, String>{
        'Upcoming': 'upcoming', 'Spending this month': 'spending_chart', 'Savings Goals': 'savings_goal',
      };
      for (final entry in headers.entries) {
        final title = find.text(entry.key);
        expect(tester.widget<Text>(title).style!.fontSize, 14);
        expect(tester.widget<Text>(title).style!.fontWeight, FontWeight.w600);
        expect(title, findsOneWidget);
        expect(find.ancestor(of: title, matching: find.byType(AppCard)), findsNothing);
        final icon = find.image(AssetImage('assets/icons/dashboard/${entry.value}.png'));
        expect(icon, findsOneWidget);
        expect(tester.getSize(icon), const Size(28, 28));
        expect(tester.widget<Image>(icon).excludeFromSemantics, isTrue);
      }
      const sections = <String, String>{
        'Upcoming': 'upcomingCommitmentsCard',
        'Spending this month': 'spendingByCategoryCard',
        'Savings Goals': 'savingsGoalsCard',
      };
      Rect? previousCard;
      for (final entry in sections.entries) {
        final header = tester.getRect(find.ancestor(
          of: find.text(entry.key), matching: find.byType(AppSectionHeader)));
        final card = tester.getRect(find.byKey(Key(entry.value)));
        expect(card.top - header.bottom, closeTo(6, 0.01));
        if (previousCard != null) {
          expect(header.top - previousCard.bottom, closeTo(16, 0.01));
        }
        previousCard = card;
      }
      final budget = tester.widget<AppProgressBar>(find.descendant(
        of: find.byKey(const Key('remainingBudgetTile')), matching: find.byType(AppProgressBar)));
      final tokens = tester.element(find.byKey(const Key('remainingBudgetTile'))).appTokens;
      expect((budget.gradient! as LinearGradient).colors,
        spent > 100 ? tokens.colors.negativeGradient : tokens.colors.positiveGradient);
      expect(budget.minHeight, 6);
      expect(budget.value, (spent / 100).clamp(0.0, 1.0));
      expect(budget.semanticLabel, '$spent% used');
      final goal = tester.widget<AppProgressBar>(find.descendant(
        of: find.byKey(const Key('savingsGoalsCard')), matching: find.byType(AppProgressBar)));
      expect((goal.gradient! as LinearGradient).colors, tokens.colors.positiveGradient);
      expect(goal.minHeight, 6);
      expect(goal.value, 0.3);
      expect(goal.semanticLabel, 'Goal: 30%');
    });
  }
}
