import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/repositories/account_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/transaction_repository.dart';
import 'package:ai_financial_coach/core/finance/finance_engine.dart';
import 'package:ai_financial_coach/core/finance/ledger_models.dart';
import 'package:ai_financial_coach/core/money/currency_mismatch_exception.dart';
import 'package:ai_financial_coach/core/money/money.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// NOTE: exercises generated Drift code — see CLAUDE_FIRST_CODING_PROMPT.md.

void main() {
  late AppDatabase db;
  late ProfileRepository profileRepo;
  late AccountRepository accountRepo;
  late TransactionRepository transactionRepo;
  late String profileId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    profileRepo = ProfileRepository(db);
    accountRepo = AccountRepository(db);
    transactionRepo = TransactionRepository(db, accountRepo);

    profileId = await profileRepo.createProfile(
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
  });

  tearDown(() async {
    await db.close();
  });

  group('Same-currency transfer (ADR-019) — happy path', () {
    test('records a transfer and both account balances update correctly', () async {
      final String jpyA = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Wallet',
        type: 'cash',
        currencyCode: 'JPY',
        openingBalance: Money.fromMinorUnits(10000, 'JPY'),
      );
      final String jpyB = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Bank',
        type: 'bank',
        currencyCode: 'JPY',
      );

      await transactionRepo.recordTransfer(
        profileId: profileId,
        sourceAccountId: jpyA,
        destinationAccountId: jpyB,
        amount: Money.fromMinorUnits(3000, 'JPY'),
        occurredAtUtc: DateTime.utc(2026, 1, 1),
      );

      final List<LedgerTransaction> ledger =
          await transactionRepo.watchLedgerForProfile(profileId).first;
      final AccountRow accountA = await accountRepo.requireById(jpyA);
      final AccountRow accountB = await accountRepo.requireById(jpyB);

      expect(
        FinanceEngine.accountBalance(accountA.toLedgerAccount(), ledger),
        Money.fromMinorUnits(7000, 'JPY'),
      );
      expect(
        FinanceEngine.accountBalance(accountB.toLedgerAccount(), ledger),
        Money.fromMinorUnits(3000, 'JPY'),
      );

      final MoneyTotals totals =
          FinanceEngine.incomeExpenseTotals(ledger, currencyCode: 'JPY');
      expect(totals.income, Money.zero('JPY'));
      expect(totals.expense, Money.zero('JPY'));
    });
  });

  group('Cross-currency transfer (release gate) — must be rejected', () {
    test('rejects a transfer between accounts of different currencies', () async {
      final String jpyAccount = await accountRepo.createAccount(
        profileId: profileId,
        name: 'JPY Wallet',
        type: 'cash',
        currencyCode: 'JPY',
      );
      final String lkrAccount = await accountRepo.createAccount(
        profileId: profileId,
        name: 'LKR Wallet',
        type: 'cash',
        currencyCode: 'LKR',
      );

      expect(
        () => transactionRepo.recordTransfer(
          profileId: profileId,
          sourceAccountId: jpyAccount,
          destinationAccountId: lkrAccount,
          amount: Money.fromMinorUnits(1000, 'JPY'),
          occurredAtUtc: DateTime.utc(2026, 1, 1),
        ),
        throwsA(isA<CurrencyMismatchException>()),
      );
    });

    test('a rejected transfer is not partially written', () async {
      final String jpyAccount = await accountRepo.createAccount(
        profileId: profileId,
        name: 'JPY Wallet',
        type: 'cash',
        currencyCode: 'JPY',
      );
      final String lkrAccount = await accountRepo.createAccount(
        profileId: profileId,
        name: 'LKR Wallet',
        type: 'cash',
        currencyCode: 'LKR',
      );

      try {
        await transactionRepo.recordTransfer(
          profileId: profileId,
          sourceAccountId: jpyAccount,
          destinationAccountId: lkrAccount,
          amount: Money.fromMinorUnits(1000, 'JPY'),
          occurredAtUtc: DateTime.utc(2026, 1, 1),
        );
      } on CurrencyMismatchException {
        // expected
      }

      final List<LedgerTransaction> ledger =
          await transactionRepo.watchLedgerForProfile(profileId).first;
      expect(ledger, isEmpty);
    });
  });

  group('Income/expense recording', () {
    test('release gate: recorded transactions survive being re-read, and a soft-deleted one is excluded', () async {
      final String account = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Wallet',
        type: 'cash',
        currencyCode: 'USD',
      );

      final String expenseId = await transactionRepo.recordExpense(
        profileId: profileId,
        accountId: account,
        amount: Money.fromMinorUnits(2500, 'USD'),
        occurredAtUtc: DateTime.utc(2026, 1, 1),
      );
      await transactionRepo.recordIncome(
        profileId: profileId,
        accountId: account,
        amount: Money.fromMinorUnits(5000, 'USD'),
        occurredAtUtc: DateTime.utc(2026, 1, 2),
      );

      await transactionRepo.softDelete(expenseId);

      final List<Transaction> active =
          await transactionRepo.watchActiveForProfile(profileId).first;
      expect(active.length, 1);
      expect(active.single.type, 'income');
    });

    test('rejects a non-positive amount', () async {
      final String account = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Wallet',
        type: 'cash',
        currencyCode: 'USD',
      );
      expect(
        () => transactionRepo.recordExpense(
          profileId: profileId,
          accountId: account,
          amount: Money.zero('USD'),
          occurredAtUtc: DateTime.utc(2026, 1, 1),
        ),
        throwsArgumentError,
      );
    });
  });
}
