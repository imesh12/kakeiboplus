import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/providers.dart';
import 'package:ai_financial_coach/core/database/repositories/account_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/money/money.dart';
import 'package:ai_financial_coach/features/dashboard/presentation/home_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
    'the budget card shows a polished empty state with a disabled call-to-action when no '
    'budget is configured yet',
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

      await tester.pumpWidget(appWithHome(container));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.savings_outlined), findsOneWidget);
      expect(find.text('Remaining monthly budget'), findsOneWidget);
      expect(find.textContaining("You haven't set a monthly budget yet"), findsOneWidget);

      final Finder ctaFinder = find.widgetWithText(OutlinedButton, 'Set a monthly budget');
      expect(ctaFinder, findsOneWidget);
      // Intentionally disabled -- there is no budgets flow to open yet;
      // wiring it up is Beta 1's budgets task, not this UI-polish pass.
      final OutlinedButton cta = tester.widget<OutlinedButton>(ctaFinder);
      expect(cta.onPressed, isNull);
    },
  );

  testWidgets(
    'the upcoming commitments card shows a polished empty state',
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

      await tester.pumpWidget(appWithHome(container));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.event_note_outlined), findsOneWidget);
      expect(find.text('No upcoming commitments yet.'), findsOneWidget);
      expect(find.text('Recurring bills and scheduled payments will appear here.'), findsOneWidget);
    },
  );
}
