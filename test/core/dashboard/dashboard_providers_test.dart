import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/providers.dart';
import 'package:ai_financial_coach/core/database/repositories/account_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/transaction_repository.dart';
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
      // loading accounts/ledger stream and flake.
      await container.read(activeProfileProvider.future);
      await container.read(accountsProvider.future);
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

      await container.read(activeProfileProvider.future);
      await container.read(accountsProvider.future);
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
      expect(jpy.balance, Money.fromMinorUnits(11800, 'JPY'));
      expect(jpy.income, Money.fromMinorUnits(3000, 'JPY')); // transfer excluded
      expect(jpy.expense, Money.fromMinorUnits(1200, 'JPY')); // transfer excluded
      // JPY has zero minor units -- renders with no decimal point.
      expect(jpy.balance.toMajorUnitsString(), '11800');
      expect(jpy.balance.toMajorUnitsString().contains('.'), isFalse);

      final CurrencyDashboardSummary usd = summaries.firstWhere((s) => s.currencyCode == 'USD');
      expect(usd.balance, Money.fromMinorUnits(5766, 'USD')); // 2000 + 5000 - 1234
      expect(usd.income, Money.fromMinorUnits(5000, 'USD'));
      expect(usd.expense, Money.fromMinorUnits(1234, 'USD'));
      expect(usd.balance.toMajorUnitsString(), '57.66'); // decimal currency renders correctly

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

  group('Forward-compatible Beta 1 placeholders (no budgets/recurring schema yet)', () {
    test('monthlyBudgetSummaryProvider reports "not configured" (empty budget state)', () async {
      await seedProfile(living: 'JPY', home: 'LKR');
      final MonthlyBudgetSummary budget = container.read(monthlyBudgetSummaryProvider);
      expect(budget.remaining, isNull);
    });

    test('upcomingCommitmentsProvider reports no items (empty upcoming-commitments state)',
        () async {
      await seedProfile(living: 'JPY', home: 'LKR');
      final List<UpcomingCommitmentSummary> commitments =
          container.read(upcomingCommitmentsProvider);
      expect(commitments, isEmpty);
    });
  });
}
