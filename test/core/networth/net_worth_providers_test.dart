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
import 'package:ai_financial_coach/features/accounts/presentation/account_providers.dart';
import 'package:ai_financial_coach/features/networth/presentation/net_worth_providers.dart';
import 'package:ai_financial_coach/features/onboarding/presentation/profile_providers.dart';
import 'package:ai_financial_coach/features/transactions/presentation/transaction_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// NOTE: exercises generated Drift code -- see CLAUDE_FIRST_CODING_PROMPT.md.
//
// Checkpoint J: `netWorthSummariesProvider` -- the dedicated Net Worth
// screen's data source. Mirrors `dashboard_providers_test.dart`'s own
// harness exactly (plain `test()`, real in-memory Drift DB, explicit
// `await container.read(allAccountsProvider.future)` before a
// synchronous provider read) for the same reason that file documents:
// plain `test()` runs on the real event loop, avoiding the FakeAsync
// "Timer is still pending" class of flake that `testWidgets()` risks
// here.
void main() {
  late AppDatabase db;
  late ProfileRepository profileRepo;
  late AccountRepository accountRepo;
  late DepositRepository depositRepo;
  late ProviderContainer container;

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<String> seedProfile({required String living, required String home}) async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    profileRepo = ProfileRepository(db);
    accountRepo = AccountRepository(db);
    depositRepo = DepositRepository(db, accountRepo);
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

  Future<List<NetWorthCurrencySummary>> readSummaries() async {
    await container.read(activeProfileProvider.future);
    await container.read(allAccountsProvider.future);
    await container.read(ledgerProvider.future);
    return container.read(netWorthSummariesProvider).requireValue;
  }

  group('netWorthSummariesProvider', () {
    test('a profile with genuinely no accounts yields an empty summary list', () async {
      await seedProfile(living: 'JPY', home: 'LKR');
      await container.read(activeProfileProvider.future);
      await container.read(allAccountsProvider.future);
      await container.read(ledgerProvider.future);
      final AsyncValue<List<NetWorthCurrencySummary>> summaries =
          container.read(netWorthSummariesProvider);
      expect(summaries.hasValue, isTrue);
      expect(summaries.requireValue, isEmpty);
    });

    test('a cash asset contributes to totalAssets and is not flagged as a deposit', () async {
      final String profileId = await seedProfile(living: 'JPY', home: 'USD');
      final String accountId = await accountRepo.createClassifiedAccount(
        profileId: profileId,
        name: 'Cash',
        type: 'cash',
        balanceClass: BalanceClass.asset,
        subtype: FinancialAccountSubtype.cash,
        currencyCode: 'JPY',
        openingBalance: Money.fromMinorUnits(5000, 'JPY'),
      );

      final NetWorthCurrencySummary jpy = (await readSummaries()).single;
      expect(jpy.totalAssets, Money.fromMinorUnits(5000, 'JPY'));
      expect(jpy.totalLiabilities, Money.zero('JPY'));
      expect(jpy.netWorth, Money.fromMinorUnits(5000, 'JPY'));
      expect(jpy.liabilityLines, isEmpty);
      final NetWorthAccountLine line = jpy.assetLines.single;
      expect(line.accountId, accountId);
      expect(line.isDeposit, isFalse);
      expect(line.isLiability, isFalse);
      expect(line.isClosed, isFalse);
    });

    test('a deposit contributes to totalAssets (not excluded) and is flagged isDeposit',
        () async {
      final String profileId = await seedProfile(living: 'JPY', home: 'USD');
      final String accountId = await accountRepo.createClassifiedAccount(
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
        accountId: accountId,
        depositType: DepositType.fixed,
        termNumber: 12,
        termUnit: DepositTermUnit.months,
        startDateUtc: DateTime.utc(2026, 1, 1),
        interestRateBasisPoints: 250,
        interestMethod: DepositInterestMethod.simple,
      );

      final NetWorthCurrencySummary jpy = (await readSummaries()).single;
      // Checkpoint J item 4/6: deposits count as ASSETS in net worth,
      // unlike Home's available/liquid money, which excludes them.
      expect(jpy.totalAssets, Money.fromMinorUnits(100000, 'JPY'));
      expect(jpy.netWorth, Money.fromMinorUnits(100000, 'JPY'));
      final NetWorthAccountLine line = jpy.assetLines.single;
      expect(line.isDeposit, isTrue);
      expect(line.isLiability, isFalse);
    });

    test('a credit-card liability is flagged isLiability and subtracted from net worth',
        () async {
      final String profileId = await seedProfile(living: 'JPY', home: 'USD');
      final String accountId = await accountRepo.createClassifiedAccount(
        profileId: profileId,
        name: 'Credit Card',
        type: 'creditCard',
        balanceClass: BalanceClass.liability,
        subtype: FinancialAccountSubtype.creditCard,
        currencyCode: 'JPY',
        openingBalance: Money.fromMinorUnits(30000, 'JPY'),
      );

      final NetWorthCurrencySummary jpy = (await readSummaries()).single;
      expect(jpy.totalAssets, Money.zero('JPY'));
      expect(jpy.totalLiabilities, Money.fromMinorUnits(30000, 'JPY'));
      // Net worth goes negative -- more owed than owned.
      expect(jpy.netWorth, Money.fromMinorUnits(-30000, 'JPY'));
      expect(jpy.assetLines, isEmpty);
      final NetWorthAccountLine line = jpy.liabilityLines.single;
      expect(line.accountId, accountId);
      expect(line.isLiability, isTrue);
      // A liability's own line balance is the non-negative "amount
      // owed" magnitude, per `FinanceEngine.accountBalance`'s
      // convention -- never itself negative.
      expect(line.balance, Money.fromMinorUnits(30000, 'JPY'));
    });

    test(
        'a closed account keeps its balance in net worth totals and is flagged isClosed '
        '(never excluded, per docs/20\'s conservative closing policy)', () async {
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

      final NetWorthCurrencySummary jpy = (await readSummaries()).single;
      expect(jpy.totalAssets, Money.fromMinorUnits(7000, 'JPY'));
      expect(jpy.netWorth, Money.fromMinorUnits(7000, 'JPY'));
      final NetWorthAccountLine line = jpy.assetLines.single;
      expect(line.isClosed, isTrue);
    });

    test(
        'multiple currencies never get combined -- each currency has its own independent '
        'summary, no FX conversion', () async {
      final String profileId = await seedProfile(living: 'JPY', home: 'USD');
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

      final List<NetWorthCurrencySummary> summaries = await readSummaries();
      expect(summaries.map((s) => s.currencyCode).toSet(), <String>{'JPY', 'USD'});
      // Living currency (JPY) ordered first.
      expect(summaries.first.currencyCode, 'JPY');

      final NetWorthCurrencySummary jpy = summaries.firstWhere((s) => s.currencyCode == 'JPY');
      final NetWorthCurrencySummary usd = summaries.firstWhere((s) => s.currencyCode == 'USD');
      expect(jpy.netWorth, Money.fromMinorUnits(10000, 'JPY'));
      expect(usd.netWorth, Money.fromMinorUnits(2000, 'USD'));
    });

    test(
        'a mixed portfolio (cash + deposit + credit card) produces the exact expected '
        'assets/liabilities/net-worth breakdown', () async {
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
      await accountRepo.createClassifiedAccount(
        profileId: profileId,
        name: 'Credit Card',
        type: 'creditCard',
        balanceClass: BalanceClass.liability,
        subtype: FinancialAccountSubtype.creditCard,
        currencyCode: 'JPY',
        openingBalance: Money.fromMinorUnits(30000, 'JPY'),
      );

      final NetWorthCurrencySummary jpy = (await readSummaries()).single;
      // totalAssets = 10000 (cash) + 100000 (deposit, INCLUDED here
      // unlike Home's available balance) = 110000
      expect(jpy.totalAssets, Money.fromMinorUnits(110000, 'JPY'));
      expect(jpy.totalLiabilities, Money.fromMinorUnits(30000, 'JPY'));
      // netWorth = 110000 - 30000 = 80000
      expect(jpy.netWorth, Money.fromMinorUnits(80000, 'JPY'));
      expect(jpy.assetLines.length, 2);
      expect(jpy.liabilityLines.length, 1);
      expect(jpy.assetLines.where((l) => l.isDeposit).length, 1);
    });
  });
}
