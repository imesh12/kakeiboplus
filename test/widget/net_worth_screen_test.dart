import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/providers.dart';
import 'package:ai_financial_coach/core/database/repositories/account_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/deposit_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/finance/balance_class.dart';
import 'package:ai_financial_coach/core/finance/deposit_interest_method.dart';
import 'package:ai_financial_coach/core/finance/deposit_term_unit.dart';
import 'package:ai_financial_coach/core/finance/deposit_type.dart';
import 'package:ai_financial_coach/core/finance/financial_account_subtype.dart';
import 'package:ai_financial_coach/core/money/money.dart';
import 'package:ai_financial_coach/features/networth/presentation/net_worth_screen.dart';
import 'package:ai_financial_coach/l10n/generated/app_localizations.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// NOTE: exercises generated Drift code -- see CLAUDE_FIRST_CODING_PROMPT.md.
//
// Checkpoint J (docs/20 §13.14): the dedicated Net Worth screen. This is
// the ONLY screen this app ever shows a full net-worth figure on -- see
// `home_screen_test.dart`'s own "Checkpoint J -- Home privacy" group for
// the matching guarantee that Home never does. A plain
// `MaterialApp(home: ...)` harness is enough here: `NetWorthScreen` never
// calls `context.push`/`context.pop`, unlike `AccountDetailScreen`'s Edit
// action (see that screen's own GoRouter harness for why one is needed
// there).
void main() {
  Future<(AppDatabase, String)> seededDb({String living = 'JPY', String home = 'USD'}) async {
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    final ProfileRepository profileRepo = ProfileRepository(db);
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
    return (db, profileId);
  }

  Widget appWithNetWorth(
    ProviderContainer container, {
    Locale locale = const Locale('en'),
  }) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const NetWorthScreen(),
      ),
    );
  }

  Future<void> disposeInOrder(WidgetTester tester, ProviderContainer container, AppDatabase db) async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pumpAndSettle();
    await db.close();
  }

  testWidgets('a profile with no accounts shows the empty state, not a spinner or error', (
    tester,
  ) async {
    final (AppDatabase db, String _) = await seededDb();
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithNetWorth(container));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Net Worth'), findsOneWidget); // AppBar title
    expect(
      find.text('No accounts yet. Add one to see your net worth here.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('netWorthList')), findsNothing);
  });

  testWidgets(
    'shows assets and liabilities in separate sections, with correct totals and a deposit '
    'badge, for a single currency',
    (tester) async {
      final (AppDatabase db, String profileId) = await seededDb(living: 'JPY', home: 'USD');
      final AccountRepository accountRepo = AccountRepository(db);
      final DepositRepository depositRepo = DepositRepository(db, accountRepo);
      await accountRepo.createClassifiedAccount(
        profileId: profileId,
        name: 'Cash',
        type: 'cash',
        balanceClass: BalanceClass.asset,
        subtype: FinancialAccountSubtype.cash,
        currencyCode: 'JPY',
        openingBalance: Money.fromMinorUnits(10000, 'JPY'),
      );
      final String depositId = await accountRepo.createClassifiedAccount(
        profileId: profileId,
        name: 'Fixed Deposit',
        type: 'deposit',
        balanceClass: BalanceClass.asset,
        subtype: FinancialAccountSubtype.deposit,
        currencyCode: 'JPY',
        openingBalance: Money.fromMinorUnits(100000, 'JPY'),
      );
      await depositRepo.createDetails(
        profileId: profileId,
        accountId: depositId,
        depositType: DepositType.fixed,
        termNumber: 1,
        termUnit: DepositTermUnit.years,
        startDateUtc: DateTime.utc(2026, 1, 1),
        interestRateBasisPoints: 300,
        interestMethod: DepositInterestMethod.simple,
      );
      final String creditCardId = await accountRepo.createClassifiedAccount(
        profileId: profileId,
        name: 'Credit Card',
        type: 'creditCard',
        balanceClass: BalanceClass.liability,
        subtype: FinancialAccountSubtype.creditCard,
        currencyCode: 'JPY',
        openingBalance: Money.fromMinorUnits(30000, 'JPY'),
      );
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithNetWorth(container));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final Finder card = find.byKey(const Key('netWorthCurrencyCard_JPY'));
      expect(card, findsOneWidget);

      // netWorth = 10000 + 100000 - 30000 = 80000
      final Finder total = find.descendant(of: card, matching: find.byKey(const Key('netWorthTotal')));
      expect(total, findsOneWidget);
      expect(find.descendant(of: total, matching: find.text('¥80,000')), findsOneWidget);
      expect(find.text('Assets'), findsOneWidget);
      expect(find.text('Liabilities'), findsOneWidget);
      expect(find.text('Cash'), findsOneWidget);
      expect(find.text('Fixed Deposit'), findsOneWidget);
      expect(find.text('Credit Card'), findsOneWidget);
      expect(find.text('Deposit'), findsOneWidget); // assetsDepositBadge, next to Fixed Deposit
      // "¥30,000" also occurs as this card's own Total Liabilities
      // figure -- anchored to the Credit Card account row specifically
      // (via its stable per-account key) so this proves the ACCOUNT
      // LINE shows its own non-negative magnitude, not just that the
      // amount appears somewhere on the card.
      final Finder creditCardRow = find.byKey(Key('netWorthAccountRow_$creditCardId'));
      expect(creditCardRow, findsOneWidget);
      expect(find.descendant(of: creditCardRow, matching: find.text('¥30,000')), findsOneWidget);
    },
  );

  testWidgets(
    'multiple currencies render as independent sections -- no combined/converted total',
    (tester) async {
      final (AppDatabase db, String profileId) = await seededDb(living: 'JPY', home: 'USD');
      final AccountRepository accountRepo = AccountRepository(db);
      await accountRepo.createClassifiedAccount(
        profileId: profileId,
        name: 'JPY Wallet',
        type: 'cash',
        balanceClass: BalanceClass.asset,
        subtype: FinancialAccountSubtype.cash,
        currencyCode: 'JPY',
        openingBalance: Money.fromMinorUnits(10000, 'JPY'),
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
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithNetWorth(container));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final Finder jpyCard = find.byKey(const Key('netWorthCurrencyCard_JPY'));
      final Finder usdCard = find.byKey(const Key('netWorthCurrencyCard_USD'));
      expect(jpyCard, findsOneWidget);
      expect(usdCard, findsOneWidget);
      // Each currency's own figure is single-account-and-no-liabilities
      // here, so its Total Assets row and its one account row also
      // legitimately show the same amount as the headline -- scoping to
      // the card alone still leaves 3 matching Text widgets inside it.
      // Anchor to the headline (`netWorthTotal`) specifically, which is
      // what this test is actually about ("no combined/converted
      // total" -- i.e. each currency's OWN total is correct and
      // independent), not merely that the figure appears on the card.
      final Finder jpyTotal = find.descendant(of: jpyCard, matching: find.byKey(const Key('netWorthTotal')));
      final Finder usdTotal = find.descendant(of: usdCard, matching: find.byKey(const Key('netWorthTotal')));
      expect(jpyTotal, findsOneWidget);
      expect(usdTotal, findsOneWidget);
      expect(find.descendant(of: jpyTotal, matching: find.text('¥10,000')), findsOneWidget);
      expect(find.descendant(of: usdTotal, matching: find.text('\$20.00')), findsOneWidget);
    },
  );

  testWidgets(
    'a closed account still contributes to the total and shows a Closed badge on its own line',
    (tester) async {
      final (AppDatabase db, String profileId) = await seededDb(living: 'JPY', home: 'USD');
      final AccountRepository accountRepo = AccountRepository(db);
      final String accountId = await accountRepo.createClassifiedAccount(
        profileId: profileId,
        name: 'Old Wallet',
        type: 'cash',
        balanceClass: BalanceClass.asset,
        subtype: FinancialAccountSubtype.cash,
        currencyCode: 'JPY',
        openingBalance: Money.fromMinorUnits(7000, 'JPY'),
      );
      await accountRepo.softDelete(accountId);
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithNetWorth(container));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // "¥7,000" also occurs on this card's own Total Assets row and
      // on the closed account's own row -- this test's name is about
      // the TOTAL still including a closed account's balance, so anchor
      // the figure to the headline (`netWorthTotal`) specifically.
      final Finder card = find.byKey(const Key('netWorthCurrencyCard_JPY'));
      final Finder total = find.descendant(of: card, matching: find.byKey(const Key('netWorthTotal')));
      expect(total, findsOneWidget);
      expect(find.descendant(of: total, matching: find.text('¥7,000')), findsOneWidget);
      // "Closed" is anchored to the specific account's own row (via its
      // stable per-account key) -- proving the badge sits on THIS
      // account's line, not merely that the word appears on the card.
      final Finder accountRow = find.byKey(Key('netWorthAccountRow_$accountId'));
      expect(accountRow, findsOneWidget);
      expect(find.descendant(of: accountRow, matching: find.text('Closed')), findsOneWidget);
    },
  );

  testWidgets(
    'a liability-only profile shows a negative net worth, visibly marked',
    (tester) async {
      final (AppDatabase db, String profileId) = await seededDb(living: 'JPY', home: 'USD');
      final AccountRepository accountRepo = AccountRepository(db);
      await accountRepo.createClassifiedAccount(
        profileId: profileId,
        name: 'Credit Card',
        type: 'creditCard',
        balanceClass: BalanceClass.liability,
        subtype: FinancialAccountSubtype.creditCard,
        currencyCode: 'JPY',
        openingBalance: Money.fromMinorUnits(30000, 'JPY'),
      );
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithNetWorth(container));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Net worth is negative (-30000) -- rendered with a visible
      // "south" indicator alongside the figure, per
      // `_CurrencyNetWorthSection`'s own doc comment; the point of this
      // assertion is only that the screen doesn't crash or silently
      // clamp to zero, not the exact icon/color used.
      expect(find.text('-¥30,000'), findsOneWidget);
    },
  );

  testWidgets('renders without overflow at a narrow 320px width and 1.6x text scale', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final (AppDatabase db, String profileId) = await seededDb(living: 'JPY', home: 'USD');
    final AccountRepository accountRepo = AccountRepository(db);
    await accountRepo.createClassifiedAccount(
      profileId: profileId,
      name: 'Cash',
      type: 'cash',
      balanceClass: BalanceClass.asset,
      subtype: FinancialAccountSubtype.cash,
      currencyCode: 'JPY',
      openingBalance: Money.fromMinorUnits(10000, 'JPY'),
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
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithNetWorth(container));
    await tester.pumpAndSettle();

    final Object? overflowException = tester.takeException();
    if (overflowException != null) {
      fail(
        'Narrow-screen (320px) + 1.6x text scale Net Worth screen threw an exception:\n\n'
        '$overflowException',
      );
    }
    expect(find.text('Net Worth'), findsOneWidget);
  });

  testWidgets('renders in Japanese without exceptions', (tester) async {
    final (AppDatabase db, String profileId) = await seededDb(living: 'JPY', home: 'USD');
    final AccountRepository accountRepo = AccountRepository(db);
    await accountRepo.createClassifiedAccount(
      profileId: profileId,
      name: 'Cash',
      type: 'cash',
      balanceClass: BalanceClass.asset,
      subtype: FinancialAccountSubtype.cash,
      currencyCode: 'JPY',
      openingBalance: Money.fromMinorUnits(10000, 'JPY'),
    );
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithNetWorth(container, locale: const Locale('ja')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Two distinct, independently-verified occurrences of the same
    // Japanese string -- the AppBar title and the currency card's own
    // "totalLabel" eyebrow caption -- each anchored to its own
    // structural location rather than collapsed into a single
    // `findsWidgets`, which would not notice if either one went missing
    // as long as at least one remained.
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('純資産')),
      findsOneWidget,
    ); // AppBar title
    final Finder card = find.byKey(const Key('netWorthCurrencyCard_JPY'));
    expect(
      find.descendant(of: card, matching: find.text('純資産')),
      findsOneWidget,
    ); // totalLabel eyebrow
    expect(find.text('資産'), findsOneWidget); // assetsSectionTitle
  });
}
