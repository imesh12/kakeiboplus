import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/repositories/account_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/recurring_occurrence_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/recurring_rule_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/transaction_repository.dart';
import 'package:ai_financial_coach/core/finance/finance_engine.dart';
import 'package:ai_financial_coach/core/finance/ledger_models.dart';
import 'package:ai_financial_coach/core/money/money.dart';
import 'package:ai_financial_coach/features/recurring/domain/recurrence_frequency.dart';
import 'package:ai_financial_coach/features/recurring/domain/recurring_rule_kind.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// NOTE: exercises generated Drift code -- see CLAUDE_FIRST_CODING_PROMPT.md.

void main() {
  late AppDatabase db;
  late ProfileRepository profileRepo;
  late AccountRepository accountRepo;
  late TransactionRepository transactionRepo;
  late RecurringRuleRepository ruleRepo;
  late RecurringOccurrenceRepository occurrenceRepo;
  late String profileId;
  late String jpyAccountId;
  late String jpyAccountId2;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    profileRepo = ProfileRepository(db);
    accountRepo = AccountRepository(db);
    transactionRepo = TransactionRepository(db, accountRepo);
    ruleRepo = RecurringRuleRepository(db, accountRepo);
    occurrenceRepo = RecurringOccurrenceRepository(db, ruleRepo, transactionRepo);

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
    jpyAccountId = await accountRepo.createAccount(
      profileId: profileId,
      name: 'Wallet',
      type: 'cash',
      currencyCode: 'JPY',
    );
    jpyAccountId2 = await accountRepo.createAccount(
      profileId: profileId,
      name: 'Savings',
      type: 'bank',
      currencyCode: 'JPY',
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<String> createExpenseRule({DateTime? startDate}) {
    return ruleRepo.createRule(
      profileId: profileId,
      kind: RecurringRuleKind.expense,
      name: 'Rent',
      amount: Money.fromMinorUnits(80000, 'JPY'),
      accountId: jpyAccountId,
      frequency: RecurrenceFrequency.monthly,
      interval: 1,
      startDate: startDate ?? DateTime.utc(2026, 1, 1),
    );
  }

  Future<String> createIncomeRule({DateTime? startDate}) {
    return ruleRepo.createRule(
      profileId: profileId,
      kind: RecurringRuleKind.income,
      name: 'Salary',
      amount: Money.fromMinorUnits(300000, 'JPY'),
      accountId: jpyAccountId,
      frequency: RecurrenceFrequency.monthly,
      interval: 1,
      startDate: startDate ?? DateTime.utc(2026, 1, 1),
    );
  }

  Future<String> createTransferRule({DateTime? startDate}) {
    return ruleRepo.createRule(
      profileId: profileId,
      kind: RecurringRuleKind.transfer,
      name: 'Move to savings',
      amount: Money.fromMinorUnits(20000, 'JPY'),
      accountId: jpyAccountId,
      destinationAccountId: jpyAccountId2,
      frequency: RecurrenceFrequency.monthly,
      interval: 1,
      startDate: startDate ?? DateTime.utc(2026, 1, 1),
    );
  }

  group('posting', () {
    test('a recurring expense creates exactly one expense transaction', () async {
      final String ruleId = await createExpenseRule();
      await occurrenceRepo.postOccurrence(ruleId: ruleId, scheduledDateUtc: DateTime.utc(2026, 1, 1));

      final List<Transaction> transactions = await db.select(db.transactions).get();
      expect(transactions, hasLength(1));
      expect(transactions.single.type, 'expense');
      expect(transactions.single.amountMinorUnits, 80000);
    });

    test('a recurring income creates exactly one income transaction', () async {
      final String ruleId = await createIncomeRule();
      await occurrenceRepo.postOccurrence(ruleId: ruleId, scheduledDateUtc: DateTime.utc(2026, 1, 1));

      final List<Transaction> transactions = await db.select(db.transactions).get();
      expect(transactions, hasLength(1));
      expect(transactions.single.type, 'income');
      expect(transactions.single.amountMinorUnits, 300000);
    });

    test('a recurring transfer creates exactly one transfer transaction', () async {
      final String ruleId = await createTransferRule();
      await occurrenceRepo.postOccurrence(ruleId: ruleId, scheduledDateUtc: DateTime.utc(2026, 1, 1));

      final List<Transaction> transactions = await db.select(db.transactions).get();
      expect(transactions, hasLength(1));
      expect(transactions.single.type, 'transfer');
      expect(transactions.single.accountId, jpyAccountId);
      expect(transactions.single.destinationAccountId, jpyAccountId2);
    });

    test('a posted transfer remains excluded from income/spending totals', () async {
      final String expenseRuleId = await createExpenseRule();
      final String transferRuleId = await createTransferRule();
      await occurrenceRepo.postOccurrence(
        ruleId: expenseRuleId,
        scheduledDateUtc: DateTime.utc(2026, 1, 1),
      );
      await occurrenceRepo.postOccurrence(
        ruleId: transferRuleId,
        scheduledDateUtc: DateTime.utc(2026, 1, 1),
      );

      final List<LedgerTransaction> ledger =
          await transactionRepo.watchLedgerForProfile(profileId).first;
      final MoneyTotals totals = FinanceEngine.incomeExpenseTotals(ledger, currencyCode: 'JPY');
      // Only the expense (80000) counts -- the transfer (20000) must not
      // appear in either total.
      expect(totals.expense, Money.fromMinorUnits(80000, 'JPY'));
      expect(totals.income, Money.zero('JPY'));
    });

    test('the posted transaction id is linked to the occurrence row', () async {
      final String ruleId = await createExpenseRule();
      final String occurrenceId =
          await occurrenceRepo.postOccurrence(ruleId: ruleId, scheduledDateUtc: DateTime.utc(2026, 1, 1));

      final RecurringOccurrenceRow occurrence =
          await (db.select(db.recurringOccurrences)..where((tbl) => tbl.id.equals(occurrenceId)))
              .getSingle();
      final Transaction transaction = await db.select(db.transactions).getSingle();

      expect(occurrence.status, 'posted');
      expect(occurrence.transactionId, transaction.id);
    });

    test('posting against a soft-deleted rule is rejected and creates nothing', () async {
      final String ruleId = await createExpenseRule();
      await ruleRepo.softDelete(ruleId);

      await expectLater(
        occurrenceRepo.postOccurrence(ruleId: ruleId, scheduledDateUtc: DateTime.utc(2026, 1, 1)),
        throwsA(isA<RecurringRuleNotFoundException>()),
      );
      expect(await db.select(db.transactions).get(), isEmpty);
      expect(await db.select(db.recurringOccurrences).get(), isEmpty);
    });
  });

  group('handled-occurrence uniqueness', () {
    test('posting the same occurrence twice is rejected', () async {
      final String ruleId = await createExpenseRule();
      await occurrenceRepo.postOccurrence(ruleId: ruleId, scheduledDateUtc: DateTime.utc(2026, 1, 1));

      await expectLater(
        occurrenceRepo.postOccurrence(ruleId: ruleId, scheduledDateUtc: DateTime.utc(2026, 1, 1)),
        throwsA(isA<RecurringOccurrenceAlreadyHandledException>()),
      );
    });

    test('skipping an already-posted occurrence is rejected', () async {
      final String ruleId = await createExpenseRule();
      await occurrenceRepo.postOccurrence(ruleId: ruleId, scheduledDateUtc: DateTime.utc(2026, 1, 1));

      await expectLater(
        occurrenceRepo.skipOccurrence(ruleId: ruleId, scheduledDateUtc: DateTime.utc(2026, 1, 1)),
        throwsA(isA<RecurringOccurrenceAlreadyHandledException>()),
      );
    });

    test('posting an already-skipped occurrence is rejected', () async {
      final String ruleId = await createExpenseRule();
      await occurrenceRepo.skipOccurrence(ruleId: ruleId, scheduledDateUtc: DateTime.utc(2026, 1, 1));

      await expectLater(
        occurrenceRepo.postOccurrence(ruleId: ruleId, scheduledDateUtc: DateTime.utc(2026, 1, 1)),
        throwsA(isA<RecurringOccurrenceAlreadyHandledException>()),
      );
    });

    test('skipping an already-skipped occurrence is rejected', () async {
      final String ruleId = await createExpenseRule();
      await occurrenceRepo.skipOccurrence(ruleId: ruleId, scheduledDateUtc: DateTime.utc(2026, 1, 1));

      await expectLater(
        occurrenceRepo.skipOccurrence(ruleId: ruleId, scheduledDateUtc: DateTime.utc(2026, 1, 1)),
        throwsA(isA<RecurringOccurrenceAlreadyHandledException>()),
      );
    });

    test('a rejected duplicate post leaves no new transaction or occurrence row behind', () async {
      final String ruleId = await createExpenseRule();
      await occurrenceRepo.postOccurrence(ruleId: ruleId, scheduledDateUtc: DateTime.utc(2026, 1, 1));
      final int transactionsBefore = (await db.select(db.transactions).get()).length;
      final int occurrencesBefore = (await db.select(db.recurringOccurrences).get()).length;

      await expectLater(
        occurrenceRepo.postOccurrence(ruleId: ruleId, scheduledDateUtc: DateTime.utc(2026, 1, 1)),
        throwsA(isA<RecurringOccurrenceAlreadyHandledException>()),
      );

      expect((await db.select(db.transactions).get()).length, transactionsBefore);
      expect((await db.select(db.recurringOccurrences).get()).length, occurrencesBefore);
    });

    test('different scheduled dates for the same rule are independent', () async {
      final String ruleId = await createExpenseRule();
      await occurrenceRepo.postOccurrence(ruleId: ruleId, scheduledDateUtc: DateTime.utc(2026, 1, 1));
      await occurrenceRepo.skipOccurrence(ruleId: ruleId, scheduledDateUtc: DateTime.utc(2026, 2, 1));

      final List<RecurringOccurrenceRow> occurrences =
          await occurrenceRepo.watchHandledForRule(ruleId).first;
      expect(occurrences, hasLength(2));
    });
  });

  group('deletion preserves history', () {
    test('deleting a rule leaves its historical occurrence records untouched', () async {
      final String ruleId = await createExpenseRule();
      final String occurrenceId =
          await occurrenceRepo.postOccurrence(ruleId: ruleId, scheduledDateUtc: DateTime.utc(2026, 1, 1));

      await ruleRepo.softDelete(ruleId);

      final RecurringOccurrenceRow occurrence =
          await (db.select(db.recurringOccurrences)..where((tbl) => tbl.id.equals(occurrenceId)))
              .getSingle();
      expect(occurrence.status, 'posted');
      final Transaction transaction = await db.select(db.transactions).getSingle();
      expect(transaction.deletedAt, isNull);
      expect(transaction.amountMinorUnits, 80000);
    });

    test('a deleted rule can never post a new occurrence again', () async {
      final String ruleId = await createExpenseRule();
      await ruleRepo.softDelete(ruleId);
      await expectLater(
        occurrenceRepo.postOccurrence(ruleId: ruleId, scheduledDateUtc: DateTime.utc(2026, 2, 1)),
        throwsA(isA<RecurringRuleNotFoundException>()),
      );
    });
  });
}
