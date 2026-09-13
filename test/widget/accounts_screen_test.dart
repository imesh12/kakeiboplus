import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/providers.dart';
import 'package:ai_financial_coach/core/database/repositories/account_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/money/money.dart';
import 'package:ai_financial_coach/features/accounts/presentation/accounts_screen.dart';
import 'package:ai_financial_coach/l10n/generated/app_localizations.dart';
import 'package:ai_financial_coach/shared/theme/app_tokens.dart';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/rtl_harness.dart';

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
  const _SeedAccount({
    required this.name,
    required this.currencyCode,
    this.openingBalance,
    this.type = 'cash',
  });

  final String name;
  final String currencyCode;
  final Money? openingBalance;

  /// CP6.5: defaults to 'cash' so every pre-existing seed call (none of
  /// which passes `type`) keeps seeding exactly what it always seeded.
  final String type;
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
        type: account.type,
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

  // CP5.6: `{bool rtl = false}` threads an RTL `Directionality` through
  // `MaterialApp`'s own `builder:` -- see `test/support/rtl_harness.dart`.
  Widget appWithAccounts(
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
        home: const AccountsScreen(),
        builder: rtl ? rtlAppBuilder : null,
      ),
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

  testWidgets(
      'CP5.6: under RTL, a normal-width row still renders the horizontal layout with no '
      'exceptions -- the Row itself mirrors correctly', (tester) async {
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

    await tester.pumpWidget(appWithAccounts(container, rtl: true));
    await tester.pumpAndSettle();

    final Finder rowLayout = find.byKey(Key('accountsRowHorizontal_${account.id}'));
    expect(tester.takeException(), isNull);
    expect(rowLayout, findsOneWidget);
    expect(find.descendant(of: rowLayout, matching: find.text('K1,500.75')), findsOneWidget);
  });

  testWidgets(
      "CP5.6: under RTL, the stacked narrow-width row's balance is expected to hug the same "
      'reading-start edge as the account name above it -- demonstrates whether '
      '`Alignment.centerLeft` (physical, today) or `AlignmentDirectional.centerStart` '
      '(directional) is actually in use', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    const String longName = 'A rather long account name to stress narrow-width layout';
    final AppDatabase db = await seededDb(
      accounts: <_SeedAccount>[
        _SeedAccount(
          name: longName,
          currencyCode: 'MMK',
          openingBalance: Money.fromMinorUnits(999999999, 'MMK'),
        ),
      ],
    );
    final AccountRow account = await soleAccount(db);
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithAccounts(container, rtl: true));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final Finder rowLayout = find.byKey(Key('accountsRowStacked_${account.id}'));
    expect(rowLayout, findsOneWidget);
    final Finder money = find.descendant(of: rowLayout, matching: find.text('K9,999,999.99'));
    expect(money, findsOneWidget);

    // `accounts_screen.dart`'s stacked fallback positions the balance with a
    // physical `Alignment.centerLeft`, not a directional
    // `AlignmentDirectional.centerStart`. In LTR the two coincide (start ==
    // left), which is why this has gone unnoticed -- but under RTL, "start"
    // is the row's right edge, which is where the account name above it
    // renders (its `CrossAxisAlignment.start` already tracks Directionality
    // correctly). CP5.6's audit expects the balance to also hug that same
    // right/start edge under RTL; this assertion demonstrates whether
    // today's code still pins it to the physical left instead -- see CP5.6
    // report finding B.
    final double rowRight = tester.getTopRight(rowLayout).dx;
    final double moneyRight = tester.getTopRight(money).dx;
    expect(
      moneyRight,
      closeTo(rowRight, 1.0),
      reason: "expected the balance to hug the stacked block's reading-start edge "
          "(the row's right edge under RTL), matching the account name above it",
    );
  });

  // CP6.5: Accounts screen Japanese localization. Re-uses the CP5.2b/5.6
  // seeding and layout-key helpers above unchanged; only `appWithAccounts`
  // grew a `locale` parameter (default 'en', so every test above this
  // point is unaffected) and `_SeedAccount` grew a `type` field (default
  // 'cash', same reason).
  group('CP6.5 Japanese localization', () {
    testWidgets(
      'A: standard Japanese Accounts renders a localized AppBar title, a localized account-'
      'type label, an untouched currency code, and the full balance',
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

        await tester.pumpWidget(appWithAccounts(container, locale: const Locale('ja')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('口座'), findsOneWidget); // AppBar title (accountsSectionTitle)
        final Finder rowLayout = find.byKey(Key('accountsRowHorizontal_${account.id}'));
        expect(rowLayout, findsOneWidget);
        // Account name is user data -- untouched by localization even
        // though it happens to be in English under the Japanese locale.
        expect(
          find.descendant(of: rowLayout, matching: find.text('Main Wallet')),
          findsOneWidget,
        );
        expect(find.descendant(of: rowLayout, matching: find.text('現金 · JPY')), findsOneWidget);
        expect(find.descendant(of: rowLayout, matching: find.text('¥50,000')), findsOneWidget);
      },
    );

    testWidgets(
      'B: a user-entered account name renders exactly as stored under the Japanese locale, '
      'including when the name itself is Japanese text -- only the type label translates',
      (tester) async {
        const String japaneseName = '生活費用の口座';
        final AppDatabase db = await seededDb(
          accounts: <_SeedAccount>[
            _SeedAccount(
              name: japaneseName,
              currencyCode: 'USD',
              openingBalance: Money.fromMinorUnits(2500, 'USD'), // \$25.00
            ),
          ],
        );
        final AccountRow account = await soleAccount(db);
        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
        );
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithAccounts(container, locale: const Locale('ja')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final Finder rowLayout = find.byKey(Key('accountsRowHorizontal_${account.id}'));
        expect(rowLayout, findsOneWidget);
        // The stored name is reproduced verbatim -- no l10n lookup ever
        // runs against user data, so a Japanese-language name is neither
        // mistranslated nor duplicated.
        expect(
          find.descendant(of: rowLayout, matching: find.text(japaneseName)),
          findsOneWidget,
        );
        expect(find.descendant(of: rowLayout, matching: find.text('現金 · USD')), findsOneWidget);
      },
    );

    testWidgets(
      "C: bank/card/wallet account-type labels localize for display, while each account's "
      'persisted `type` column keeps its original English enum-style value',
      (tester) async {
        final AppDatabase db = await seededDb(
          accounts: <_SeedAccount>[
            const _SeedAccount(name: 'Bank Account', currencyCode: 'USD', type: 'bank'),
            const _SeedAccount(name: 'Card Account', currencyCode: 'USD', type: 'card'),
            const _SeedAccount(name: 'Wallet Account', currencyCode: 'USD', type: 'wallet'),
          ],
        );
        final List<AccountRow> accounts = await db.select(db.accounts).get();
        AccountRow byName(String name) => accounts.firstWhere((a) => a.name == name);
        final AccountRow bank = byName('Bank Account');
        final AccountRow card = byName('Card Account');
        final AccountRow wallet = byName('Wallet Account');
        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
        );
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithAccounts(container, locale: const Locale('ja')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          find.descendant(
            of: find.byKey(Key('accountsRowHorizontal_${bank.id}')),
            matching: find.text('銀行 · USD'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(Key('accountsRowHorizontal_${card.id}')),
            matching: find.text('カード · USD'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(Key('accountsRowHorizontal_${wallet.id}')),
            matching: find.text('ウォレット · USD'),
          ),
          findsOneWidget,
        );
        // The persisted column itself never changed -- only its display
        // label did.
        expect(bank.type, 'bank');
        expect(card.type, 'card');
        expect(wallet.type, 'wallet');
      },
    );

    testWidgets(
      'D: Japanese + MMK renders its registry-defined 2 decimal places (never 0) at normal '
      'width and text scale',
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

        await tester.pumpWidget(appWithAccounts(container, locale: const Locale('ja')));
        await tester.pumpAndSettle();

        final Finder rowLayout = find.byKey(Key('accountsRowHorizontal_${account.id}'));
        expect(tester.takeException(), isNull);
        expect(rowLayout, findsOneWidget);
        expect(find.descendant(of: rowLayout, matching: find.text('K1,500.75')), findsOneWidget);
        expect(find.byKey(Key('accountsRowStacked_${account.id}')), findsNothing);
      },
    );

    testWidgets(
      'E: Japanese + a large 0-decimal VND balance keeps every digit at 320px width and a '
      '1.6x text scale, with a long Japanese account name squeezed instead',
      (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1.0;
        tester.platformDispatcher.textScaleFactorTestValue = 1.6;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        const String longJapaneseName = '狭い画面でのレイアウトを確認するための、かなり長い口座名';
        final AppDatabase db = await seededDb(
          accounts: <_SeedAccount>[
            _SeedAccount(
              name: longJapaneseName,
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

        await tester.pumpWidget(appWithAccounts(container, locale: const Locale('ja')));
        await tester.pumpAndSettle();

        // Not asserting which layout branch this renders as, matching
        // the reasoning in the equivalent English CP5.2b test above --
        // scoped to whichever of this account's own two layout keys
        // actually rendered.
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
      'F: Japanese + a large 3-decimal KWD balance keeps every digit at 320px width and a '
      '1.6x text scale, with a long Japanese account name squeezed instead',
      (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1.0;
        tester.platformDispatcher.textScaleFactorTestValue = 1.6;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        const String longJapaneseName = '狭い画面でのレイアウトを確認するための、かなり長い口座名';
        final AppDatabase db = await seededDb(
          accounts: <_SeedAccount>[
            _SeedAccount(
              name: longJapaneseName,
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

        await tester.pumpWidget(appWithAccounts(container, locale: const Locale('ja')));
        await tester.pumpAndSettle();

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
      'G: Japanese + a large MMK balance switches to the stacked layout at 320px width and a '
      '2.0x text scale, never clipping a digit, with a long Japanese account name above it',
      (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.view.physicalSize = const Size(320, 2200);
        tester.view.devicePixelRatio = 1.0;
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        const String longJapaneseName = '狭い画面でのレイアウトを確認するための、かなり長い口座名';
        final AppDatabase db = await seededDb(
          accounts: <_SeedAccount>[
            _SeedAccount(
              name: longJapaneseName,
              currencyCode: 'MMK',
              openingBalance: Money.fromMinorUnits(999999999, 'MMK'), // K9,999,999.99
            ),
          ],
        );
        final AccountRow account = await soleAccount(db);
        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
        );
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithAccounts(container, locale: const Locale('ja')));
        await tester.pumpAndSettle();

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
      'H: navigation/action regression -- opening Add Account under the Japanese locale shows '
      'a fully localized dialog, and submitting it still creates a real account that appears '
      'in the (still Japanese) list',
      (tester) async {
        final AppDatabase db = await seededDb(accounts: const <_SeedAccount>[]);
        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
        );
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithAccounts(container, locale: const Locale('ja')));
        await tester.pumpAndSettle();

        // Empty state is itself localized -- confirms this dialog test
        // starts from a real "no accounts yet" condition, not a stale
        // fixture.
        expect(find.text('口座がまだありません。+ をタップして追加してください。'), findsOneWidget);

        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();

        expect(find.text('口座を追加'), findsOneWidget); // dialog title
        expect(find.text('名前'), findsOneWidget); // Name field label
        expect(find.text('種類'), findsOneWidget); // Type field label
        expect(find.text('通貨'), findsOneWidget); // Currency field label
        expect(find.text('キャンセル'), findsOneWidget); // Cancel button
        expect(find.text('追加'), findsOneWidget); // Add button

        await tester.enterText(find.byType(TextFormField), 'New JPY Wallet');
        await tester.tap(find.text('追加'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        // Dialog closed and the real, persisted account now renders in
        // the still-Japanese list with its (default) type localized.
        expect(find.text('口座を追加'), findsNothing);
        expect(find.text('New JPY Wallet'), findsOneWidget);
        expect(find.textContaining('現金 ·'), findsOneWidget);
        final List<AccountRow> accounts = await db.select(db.accounts).get();
        expect(accounts.where((a) => a.name == 'New JPY Wallet'), hasLength(1));
      },
    );
  });

  // ---------------------------------------------------------------------
  // Visual System Convergence Checkpoint 7.3: locks in the account row's
  // new bordered-card visual treatment (`AppCard(bordered: true)`) via the
  // same shape/side/color contract `app_card_test.dart` already asserts
  // for `AppCard` itself -- never a pixel value.
  // ---------------------------------------------------------------------
  testWidgets(
    'CP7.3: an account row renders inside a bordered, near-white card matching the converged '
    'visual system',
    (tester) async {
      final AppDatabase db = await seededDb(
        accounts: <_SeedAccount>[
          _SeedAccount(
            name: 'Main Wallet',
            currencyCode: 'JPY',
            openingBalance: Money.fromMinorUnits(50000, 'JPY'),
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

      final Finder rowLayout = find.byKey(Key('accountsRowHorizontal_${account.id}'));
      final Card cardWidget = tester.widget<Card>(
        find.ancestor(of: rowLayout, matching: find.byType(Card)).first,
      );
      final BuildContext context = tester.element(rowLayout);
      final ColorScheme colors = Theme.of(context).colorScheme;
      final AppTokens tokens = context.appTokens;

      expect(cardWidget.color, colors.surface);
      expect(cardWidget.elevation, 0);
      final RoundedRectangleBorder shape = cardWidget.shape! as RoundedRectangleBorder;
      expect(shape.side.color, tokens.colors.subtleBorder);
    },
  );
}
