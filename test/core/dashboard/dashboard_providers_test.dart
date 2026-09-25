import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/providers.dart';
import 'package:ai_financial_coach/core/database/repositories/account_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/transaction_repository.dart';
import 'package:ai_financial_coach/core/finance/balance_class.dart';
import 'package:ai_financial_coach/core/finance/financial_account_subtype.dart';
import 'package:ai_financial_coach/core/money/money.dart';
import 'package:ai_financial_coach/features/accounts/presentation/account_providers.dart';
import 'package:ai_financial_coach/features/dashboard/presentation/dashboard_providers.dart';
import 'package:ai_financial_coach/features/onboarding/presentation/profile_providers.dart';
import 'package:ai_financial_coach/features/transactions/presentation/transaction_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// NOTE: exercises generated Drift code — see CLAUDE_FIRST_CODING_PROMPT.md.
//
// These are plain `test()`s, not `testWidgets()`s -- there is no widget
// tree here, only Riverpod providers reading Drift streams. That
// deliberately keeps them off Flutter's FakeAsync-driven test clock (the
// thing `testWidgets` wraps every test body in): plain `test()` runs on
// the real event loop, so `container.read(someStreamProvider.future)`
// and `ProviderContainer.dispose()` behave exactly like they would in
// the running app, with no risk of the "Timer is still pending" widget
// -test-lifecycle class of failure this project hit earlier in
// `add_transaction_screen_test.dart` (see that file's doc comments).

void main() {
  late AppDatabase db;
  late ProfileRepository profileRepo;
  late AccountRepository accountRepo;
  late TransactionRepository transactionRepo;
  late ProviderContainer container;

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  /// Creates a profile with the given living/home currencies and returns
  /// its id, wiring up [container] against the same in-memory [db].
  Future<String> seedProfile({required String living, required String home}) async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    profileRepo = ProfileRepository(db);
    accountRepo = AccountRepository(db);
    transactionRepo = TransactionRepository(db, accountRepo);
    container = ProviderContainer(
      overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
    );
    return profileRepo.createProfile(
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
  }

  group('dashboardCurrencySummariesProvider', () {
    test('zero-data dashboard: a profile with no accounts yields an empty summary list', () async {
      await seedProfile(living: 'JPY', home: 'LKR');

      // dashboardCurrencySummariesProvider gates on all three of these
      // being resolved (not just the profile) before it computes
      // anything -- await all three or the read below can race a still-
      // loading accounts/ledger stream and flake. Checkpoint I moved the
      // provider's own dependency from `accountsProvider` (active-only)
      // to `allAccountsProvider` (active+closed) -- awaiting
      // `accountsProvider.future` here does NOT wait for
      // `allAccountsProvider` to resolve (they are two independent
      // Drift stream subscriptions), so the synchronous read below could
      // still observe `AsyncValue.loading()` and flake `hasValue`.
      await container.read(activeProfileProvider.future);
      await container.read(allAccountsProvider.future);
      await container.read(ledgerProvider.future);

      final AsyncValue<List<CurrencyDashboardSummary>> summaries =
          container.read(dashboardCurrencySummariesProvider);
      expect(summaries.hasValue, isTrue);
      expect(summaries.requireValue, isEmpty);
    });

    test(
        'monthly income/expense per currency, transfers excluded, multiple currencies '
        'never silently summed together, JPY renders with zero decimals', () async {
      final String profileId = await seedProfile(living: 'JPY', home: 'USD');

      final String jpyWallet = await accountRepo.createAccount(
        profileId: profileId,
        name: 'JPY Wallet',
        type: 'cash',
        currencyCode: 'JPY',
        openingBalance: Money.fromMinorUnits(10000, 'JPY'), // ¥10,000
      );
      final String jpyBank = await accountRepo.createAccount(
        profileId: profileId,
        name: 'JPY Bank',
        type: 'bank',
        currencyCode: 'JPY',
      );
      final String usdWallet = await accountRepo.createAccount(
        profileId: profileId,
        name: 'USD Wallet',
        type: 'cash',
        currencyCode: 'USD',
        openingBalance: Money.fromMinorUnits(2000, 'USD'), // $20.00
      );

      final DateTime now = DateTime.now().toUtc();

      // JPY: income ¥3,000, expense ¥1,200 -- expect balance/income/expense
      // to reflect exactly these, in JPY only.
      await transactionRepo.recordIncome(
        profileId: profileId,
        accountId: jpyWallet,
        amount: Money.fromMinorUnits(3000, 'JPY'),
        occurredAtUtc: now,
      );
      await transactionRepo.recordExpense(
        profileId: profileId,
        accountId: jpyWallet,
        amount: Money.fromMinorUnits(1200, 'JPY'),
        occurredAtUtc: now,
      );
      // Same-currency transfer between the two JPY accounts: must move
      // the balance but must NOT appear in JPY income or expense.
      await transactionRepo.recordTransfer(
        profileId: profileId,
        sourceAccountId: jpyWallet,
        destinationAccountId: jpyBank,
        amount: Money.fromMinorUnits(4000, 'JPY'),
        occurredAtUtc: now,
      );

      // USD (a decimal currency): income $50.00, expense $12.34 -- must
      // stay entirely separate from the JPY figures above.
      await transactionRepo.recordIncome(
        profileId: profileId,
        accountId: usdWallet,
        amount: Money.fromMinorUnits(5000, 'USD'),
        occurredAtUtc: now,
      );
      await transactionRepo.recordExpense(
        profileId: profileId,
        accountId: usdWallet,
        amount: Money.fromMinorUnits(1234, 'USD'),
        occurredAtUtc: now,
      );

      // Checkpoint I: await `allAccountsProvider` (what
      // dashboardCurrencySummariesProvider actually watches now), not
      // `accountsProvider` -- see the zero-data test above for why the
      // two are not interchangeable here.
      await container.read(activeProfileProvider.future);
      await container.read(allAccountsProvider.future);
      await container.read(ledgerProvider.future);

      final AsyncValue<List<CurrencyDashboardSummary>> summariesAsync =
          container.read(dashboardCurrencySummariesProvider);
      expect(summariesAsync.hasValue, isTrue);
      final List<CurrencyDashboardSummary> summaries = summariesAsync.requireValue;

      // Multiple currencies are never silently summed: exactly one entry
      // per currency, never one combined entry.
      expect(summaries.map((s) => s.currencyCode).toSet(), <String>{'JPY', 'USD'});

      // Living currency (JPY) ordered first.
      expect(summaries.first.currencyCode, 'JPY');

      final CurrencyDashboardSummary jpy = summaries.firstWhere((s) => s.currencyCode == 'JPY');
      // Balance: (10000 + 3000 - 1200 - 4000) + (0 + 4000) = 7800 + 4000 = 11800
      expect(jpy.availableBalance, Money.fromMinorUnits(11800, 'JPY'));
      // Checkpoint I: no deposit/liability account exists in this
      // scenario, so net worth and available balance are necessarily
      // identical -- a strictly stronger assertion than before this
      // checkpoint's rename, not a weaker one.
      expect(jpy.netWorth, Money.fromMinorUnits(11800, 'JPY'));
      expect(jpy.income, Money.fromMinorUnits(3000, 'JPY')); // transfer excluded
      expect(jpy.expense, Money.fromMinorUnits(1200, 'JPY')); // transfer excluded
      // JPY has zero minor units -- renders with no decimal point.
      expect(jpy.availableBalance.toMajorUnitsString(), '11800');
      expect(jpy.availableBalance.toMajorUnitsString().contains('.'), isFalse);

      final CurrencyDashboardSummary usd = summaries.firstWhere((s) => s.currencyCode == 'USD');
      expect(usd.availableBalance, Money.fromMinorUnits(5766, 'USD')); // 2000 + 5000 - 1234
      expect(usd.netWorth, Money.fromMinorUnits(5766, 'USD'));
      expect(usd.income, Money.fromMinorUnits(5000, 'USD'));
      expect(usd.expense, Money.fromMinorUnits(1234, 'USD'));
      expect(usd.availableBalance.toMajorUnitsString(), '57.66'); // decimal currency renders correctly

      // Daily spending pace is today's month-to-date expense truncated
      // by however many days of the current month have elapsed -- both
      // currencies' expense are non-zero, so both paces are non-zero and
      // each stays in its own currency.
      expect(jpy.dailyPace.currencyCode, 'JPY');
      expect(jpy.dailyPace.isNegative, isFalse);
      expect(usd.dailyPace.currencyCode, 'USD');
      expect(usd.dailyPace.isNegative, isFalse);
    });
  });

  group('Forward-compatible Beta 1 placeholders (no budgets schema yet)', () {
    test('monthlyBudgetSummaryProvider reports "not configured" (empty budget state)', () async {
      await seedProfile(living: 'JPY', home: 'LKR');
      final MonthlyBudgetSummary budget = container.read(monthlyBudgetSummaryProvider);
      expect(budget.remaining, isNull);
    });
  });

  // -- Checkpoint I (docs/20 §13.4 checkpoint I / §13.13): Home dashboard
  // net worth / available-money / liquidity presentation. Every test
  // below awaits `allAccountsProvider.future` (not `accountsProvider`),
  // matching `dashboardCurrencySummariesProvider`'s own dependency after
  // this checkpoint -- see `dashboard_providers.dart`'s doc comment on
  // why.
  group('Checkpoint I -- net worth / available-money dashboard semantics', () {
    Future<List<CurrencyDashboardSummary>> readSummaries() async {
      await container.read(activeProfileProvider.future);
      await container.read(allAccountsProvider.future);
      await container.read(ledgerProvider.future);
      return container.read(dashboardCurrencySummariesProvider).requireValue;
    }

    test('A. a cash account contributes to available/liquid money', () async {
      final String profileId = await seedProfile(living: 'JPY', home: 'USD');
      await accountRepo.createClassifiedAccount(
        profileId: profileId,
        name: 'Cash',
        type: 'cash',
        balanceClass: BalanceClass.asset,
        subtype: FinancialAccountSubtype.cash,
        currencyCode: 'JPY',
        openingBalance: Money.fromMinorUnits(5000, 'JPY'),
      );
      final CurrencyDashboardSummary jpy = (await readSummaries()).single;
      expect(jpy.availableBalance, Money.fromMinorUnits(5000, 'JPY'));
      expect(jpy.netWorth, Money.fromMinorUnits(5000, 'JPY'));
    });

    test('B. a bank account contributes to available/liquid money', () async {
      final String profileId = await seedProfile(living: 'JPY', home: 'USD');
      await accountRepo.createClassifiedAccount(
        profileId: profileId,
        name: 'Bank',
        type: 'bank',
        balanceClass: BalanceClass.asset,
        subtype: FinancialAccountSubtype.bank,
        currencyCode: 'JPY',
        openingBalance: Money.fromMinorUnits(20000, 'JPY'),
      );
      final CurrencyDashboardSummary jpy = (await readSummaries()).single;
      expect(jpy.availableBalance, Money.fromMinorUnits(20000, 'JPY'));
      expect(jpy.netWorth, Money.fromMinorUnits(20000, 'JPY'));
    });

    test(
        'C. a savings account (AccountCreationKind.savings -- FinancialAccountSubtype.bank) '
        'contributes to available/liquid money', () async {
      final String profileId = await seedProfile(living: 'JPY', home: 'USD');
      await accountRepo.createClassifiedAccount(
        profileId: profileId,
        name: 'Savings',
        type: 'savings',
        balanceClass: BalanceClass.asset,
        subtype: FinancialAccountSubtype.bank,
        currencyCode: 'JPY',
        openingBalance: Money.fromMinorUnits(5000, 'JPY'),
      );
      final CurrencyDashboardSummary jpy = (await readSummaries()).single;
      expect(jpy.availableBalance, Money.fromMinorUnits(5000, 'JPY'));
      expect(jpy.netWorth, Money.fromMinorUnits(5000, 'JPY'));
    });

    test('D. a wallet account contributes to available/liquid money', () async {
      final String profileId = await seedProfile(living: 'JPY', home: 'USD');
      await accountRepo.createClassifiedAccount(
        profileId: profileId,
        name: 'Wallet',
        type: 'wallet',
        balanceClass: BalanceClass.asset,
        subtype: FinancialAccountSubtype.wallet,
        currencyCode: 'JPY',
        openingBalance: Money.fromMinorUnits(3000, 'JPY'),
      );
      final CurrencyDashboardSummary jpy = (await readSummaries()).single;
      expect(jpy.availableBalance, Money.fromMinorUnits(3000, 'JPY'));
      expect(jpy.netWorth, Money.fromMinorUnits(3000, 'JPY'));
    });

    test(
        'E. a deposit contributes its principal to net worth but NOT to available/liquid '
        'money', () async {
      final String profileId = await seedProfile(living: 'JPY', home: 'USD');
      await accountRepo.createClassifiedAccount(
        profileId: profileId,
        name: 'Fixed Deposit',
        type: 'deposit',
        balanceClass: BalanceClass.asset,
        subtype: FinancialAccountSubtype.deposit,
        currencyCode: 'JPY',
        openingBalance: Money.fromMinorUnits(100000, 'JPY'),
      );
      final CurrencyDashboardSummary jpy = (await readSummaries()).single;
      expect(jpy.availableBalance, Money.zero('JPY'));
      expect(jpy.netWorth, Money.fromMinorUnits(100000, 'JPY'));
    });

    test(
        'F1. a zero-balance credit-card liability contributes zero to both available money '
        'and the net-worth deduction', () async {
      final String profileId = await seedProfile(living: 'JPY', home: 'USD');
      await accountRepo.createClassifiedAccount(
        profileId: profileId,
        name: 'Credit Card',
        type: 'creditCard',
        balanceClass: BalanceClass.liability,
        subtype: FinancialAccountSubtype.creditCard,
        currencyCode: 'JPY',
        openingBalance: Money.zero('JPY'),
      );
      final CurrencyDashboardSummary jpy = (await readSummaries()).single;
      expect(jpy.availableBalance, Money.zero('JPY'));
      expect(jpy.netWorth, Money.zero('JPY'));
    });

    test(
        'F2. a non-zero credit-card liability is excluded from available money and is '
        'subtracted from net worth per the established sign convention', () async {
      final String profileId = await seedProfile(living: 'JPY', home: 'USD');
      await accountRepo.createClassifiedAccount(
        profileId: profileId,
        name: 'Credit Card',
        type: 'creditCard',
        balanceClass: BalanceClass.liability,
        subtype: FinancialAccountSubtype.creditCard,
        currencyCode: 'JPY',
        openingBalance: Money.fromMinorUnits(30000, 'JPY'), // amount owed
      );
      final CurrencyDashboardSummary jpy = (await readSummaries()).single;
      expect(jpy.availableBalance, Money.zero('JPY'));
      // Net worth goes negative -- more owed than owned in this currency.
      expect(jpy.netWorth, Money.fromMinorUnits(-30000, 'JPY'));
    });

    test(
        'G. a mixed portfolio (cash + bank + savings + wallet + deposit + credit card) '
        'produces the exact expected available/net-worth totals', () async {
      final String profileId = await seedProfile(living: 'JPY', home: 'USD');
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
        name: 'Bank',
        type: 'bank',
        balanceClass: BalanceClass.asset,
        subtype: FinancialAccountSubtype.bank,
        currencyCode: 'JPY',
        openingBalance: Money.fromMinorUnits(20000, 'JPY'),
      );
      await accountRepo.createClassifiedAccount(
        profileId: profileId,
        name: 'Savings',
        type: 'savings',
        balanceClass: BalanceClass.asset,
        subtype: FinancialAccountSubtype.bank,
        currencyCode: 'JPY',
        openingBalance: Money.fromMinorUnits(5000, 'JPY'),
      );
      await accountRepo.createClassifiedAccount(
        profileId: profileId,
        name: 'Wallet',
        type: 'wallet',
        balanceClass: BalanceClass.asset,
        subtype: FinancialAccountSubtype.wallet,
        currencyCode: 'JPY',
        openingBalance: Money.fromMinorUnits(3000, 'JPY'),
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

      final CurrencyDashboardSummary jpy = (await readSummaries()).single;
      // available = 10000 + 20000 + 5000 + 3000 (deposit and credit
      // card both excluded) = 38000
      expect(jpy.availableBalance, Money.fromMinorUnits(38000, 'JPY'));
      // net worth = 10000 + 20000 + 5000 + 3000 + 100000 (deposit
      // INCLUDED) - 30000 (credit card SUBTRACTED) = 108000
      expect(jpy.netWorth, Money.fromMinorUnits(108000, 'JPY'));
    });

    test(
        'H. a closed account keeps its balance in net worth but loses it from available '
        'money -- Account Lifecycle\'s conservative "closing must not destroy financial '
        'value" policy applied to the dashboard', () async {
      final String profileId = await seedProfile(living: 'JPY', home: 'USD');
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

      final List<CurrencyDashboardSummary> summaries = await readSummaries();
      // The currency must still appear at all -- before this checkpoint,
      // a currency whose only account was closed disappeared from the
      // dashboard entirely.
      expect(summaries.map((s) => s.currencyCode), contains('JPY'));
      final CurrencyDashboardSummary jpy = summaries.firstWhere((s) => s.currencyCode == 'JPY');
      expect(jpy.availableBalance, Money.zero('JPY'));
      expect(jpy.netWorth, Money.fromMinorUnits(7000, 'JPY'));
    });

    test(
        'I. reactivating a closed account restores it to available money without '
        'duplicating its value in net worth', () async {
      final String profileId = await seedProfile(living: 'JPY', home: 'USD');
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
      await accountRepo.reactivate(accountId);

      final CurrencyDashboardSummary jpy = (await readSummaries()).single;
      expect(jpy.availableBalance, Money.fromMinorUnits(7000, 'JPY'));
      // Not doubled to 14000 -- the same single balance, now counted by
      // both totals again.
      expect(jpy.netWorth, Money.fromMinorUnits(7000, 'JPY'));
    });
  });
}
