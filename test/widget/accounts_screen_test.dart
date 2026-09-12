import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/providers.dart';
import 'package:ai_financial_coach/core/database/repositories/account_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/money/money.dart';
import 'package:ai_financial_coach/features/accounts/presentation/accounts_screen.dart';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// NOTE: exercises generated Drift code -- see CLAUDE_FIRST_CODING_PROMPT.md.
//
// CP5.2b: dedicated coverage for the Accounts screen's per-row layout
// only -- the underlying balance/currency arithmetic already has coverage
// elsewhere (see `test/core/finance/finance_engine_test.dart` and
// `test/core/dashboard/dashboard_providers_test.dart`), so nothing here
// re-checks the math. These tests exist to lock in: the descriptive
// column (name + "type · currency") yields before the authoritative
// balance, the balance is never clipped/truncated at narrow widths or
// large text scales, and the correct number of decimal places for each
// currency comes straight from `CurrencyRegistry` -- not a hand-picked
// assumption.

class _SeedAccount {
  const _SeedAccount({required this.name, required this.currencyCode, this.openingBalance});

  final String name;
  final String currencyCode;
  final Money? openingBalance;
}

void main() {
  /// Seeds a single profile plus whichever accounts are given. Every test
  /// below seeds exactly one account, so `soleAccount` (below) can look
  /// it up unambiguously without the profile-scoped predicate query
  /// `home_screen_test.dart` needs when several accounts coexist.
  Future<AppDatabase> seededDb({required List<_SeedAccount> accounts}) async {
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    final ProfileRepository profileRepo = ProfileRepository(db);
    final AccountRepository accountRepo = AccountRepository(db);
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

  /// Re-queries the single seeded account's real id directly from Drift,
  /// mirroring the pattern `home_screen_test.dart` uses for the same
  /// reason: nothing in `seededDb` above hands the id back, and the
  /// account-specific layout keys need it.
  Future<AccountRow> soleAccount(AppDatabase db) async {
    return (await db.select(db.accounts).get()).first;
  }

  Widget appWithAccounts(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: AccountsScreen()),
    );
  }

  /// Same deterministic shutdown sequence as `home_screen_test.dart`'s
  /// `disposeInOrder`: unmount, then dispose, then one `pumpAndSettle()`
  /// so Drift's `StreamQueryStore.markAsClosed` `Timer.zero` fires before
  /// `db.close()`.
  Future<void> disposeInOrder(
    WidgetTester tester,
    ProviderContainer container,
    AppDatabase db,
  ) async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pumpAndSettle();
    await db.close();
  }

  testWidgets(
    'CP5.2b: an account row renders name, type/currency metadata, and full balance side by '
    'side under normal width and text scale',
    (tester) async {
      final AppDatabase db = await seededDb(
        accounts: <_SeedAccount>[
          _SeedAccount(
            name: 'Main Wallet',
            currencyCode: 'JPY',
            openingBalance: Money.fromMinorUnits(50000, 'JPY'), // ¥50,000
          ),
        ],
      );
      final AccountRow account = await soleAccount(db);
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithAccounts(container));
      await tester.pumpAndSettle();

      // At normal width/text scale the horizontal branch is guaranteed,
      // so it's safe to scope name, metadata, and balance to specifically
      // this account's row rather than just anywhere on screen.
      final Finder rowLayout = find.byKey(Key('accountsRowHorizontal_${account.id}'));

      expect(tester.takeException(), isNull);
      expect(rowLayout, findsOneWidget);
      expect(find.descendant(of: rowLayout, matching: find.text('Main Wallet')), findsOneWidget);
      expect(
        find.descendant(of: rowLayout, matching: find.text('cash · JPY')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: rowLayout, matching: find.text('¥50,000')),
        findsOneWidget,
      );
      expect(find.byKey(Key('accountsRowStacked_${account.id}')), findsNothing);
    },
  );

  testWidgets(
    'CP5.2b: an account row keeps every digit of a large 0-decimal VND balance at 320px width '
    'and a 1.6x text scale, with a long account name squeezed instead',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      const String longName = 'A rather long account name to stress narrow-width layout';
      final AppDatabase db = await seededDb(
        accounts: <_SeedAccount>[
          _SeedAccount(
            name: longName,
            currencyCode: 'VND',
            openingBalance: Money.fromMinorUnits(999999999, 'VND'), // ₫999,999,999
          ),
        ],
      );
      final AccountRow account = await soleAccount(db);
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithAccounts(container));
      await tester.pumpAndSettle();

      // Not asserting which layout branch this renders as -- at 1.6x this
      // 0-decimal balance may legitimately land in either one, and that
      // isn't the point of this test. Scope to whichever of this
      // account's own two layout keys actually rendered (rather than a
      // page-wide `find.text(...)`) so the assertion is about *this row*,
      // per the lesson from CP5.2a: a shared literal amount can otherwise
      // coincidentally match something else on screen.
      final Finder rowLayout = find.byWidgetPredicate(
        (Widget widget) =>
            widget.key == Key('accountsRowHorizontal_${account.id}') ||
            widget.key == Key('accountsRowStacked_${account.id}'),
      );

      expect(tester.takeException(), isNull);
      expect(rowLayout, findsOneWidget);
      expect(
        find.descendant(of: rowLayout, matching: find.text('₫999,999,999')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'CP5.2b: an account row keeps every digit of a large 3-decimal KWD balance at 320px width '
    'and a 1.6x text scale, with a long account name squeezed instead',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      const String longName = 'A rather long account name to stress narrow-width layout';
      final AppDatabase db = await seededDb(
        accounts: <_SeedAccount>[
          _SeedAccount(
            name: longName,
            currencyCode: 'KWD',
            openingBalance: Money.fromMinorUnits(12345678, 'KWD'), // د.ك12,345.678
          ),
        ],
      );
      final AccountRow account = await soleAccount(db);
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithAccounts(container));
      await tester.pumpAndSettle();

      // Same reasoning as the VND test above -- not asserting which
      // layout branch this renders as, but scoped to whichever of this
      // account's own two layout keys actually rendered.
      final Finder rowLayout = find.byWidgetPredicate(
        (Widget widget) =>
            widget.key == Key('accountsRowHorizontal_${account.id}') ||
            widget.key == Key('accountsRowStacked_${account.id}'),
      );

      expect(tester.takeException(), isNull);
      expect(rowLayout, findsOneWidget);
      expect(
        find.descendant(of: rowLayout, matching: find.text('د.ك12,345.678')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'CP5.2b: an account row switches to a stacked layout and keeps every digit of a large MMK '
    'balance at 320px width and a 2.0x text scale, never clipping it',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(320, 2200);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      const String longName = 'A rather long account name to stress narrow-width layout';
      final AppDatabase db = await seededDb(
        accounts: <_SeedAccount>[
          _SeedAccount(
            name: longName,
            currencyCode: 'MMK',
            // K9,999,999.99 -- MMK has 2 minor units per `CurrencyRegistry`,
            // not 0; this exact value was measured in prior CP5.1/CP5.2a
            // diagnostics to exceed a narrow row's available width at
            // 2.0x text scale, so it's reused here to reliably force the
            // stacked layout rather than guessing a value.
            openingBalance: Money.fromMinorUnits(999999999, 'MMK'),
          ),
        ],
      );
      final AccountRow account = await soleAccount(db);
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithAccounts(container));
      await tester.pumpAndSettle();

      // This value is specifically chosen to force the stacked branch, so
      // it's safe to scope the balance assertion to that specific key.
      final Finder rowLayout = find.byKey(Key('accountsRowStacked_${account.id}'));

      expect(tester.takeException(), isNull);
      expect(rowLayout, findsOneWidget);
      expect(
        find.descendant(of: rowLayout, matching: find.text('K9,999,999.99')),
        findsOneWidget,
      );
      expect(find.byKey(Key('accountsRowHorizontal_${account.id}')), findsNothing);
    },
  );

  testWidgets(
    'CP5.2b: an account row renders an MMK balance with its registry-defined 2 decimal '
    'places, not 0, under normal width and text scale',
    (tester) async {
      final AppDatabase db = await seededDb(
        accounts: <_SeedAccount>[
          _SeedAccount(
            name: 'Yangon Wallet',
            currencyCode: 'MMK',
            openingBalance: Money.fromMinorUnits(150075, 'MMK'), // K1,500.75
          ),
        ],
      );
      final AccountRow account = await soleAccount(db);
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithAccounts(container));
      await tester.pumpAndSettle();

      // Normal width/text scale -- horizontal branch is guaranteed.
      final Finder rowLayout = find.byKey(Key('accountsRowHorizontal_${account.id}'));

      expect(tester.takeException(), isNull);
      expect(rowLayout, findsOneWidget);
      expect(
        find.descendant(of: rowLayout, matching: find.text('K1,500.75')),
        findsOneWidget,
      );
    },
  );
}
