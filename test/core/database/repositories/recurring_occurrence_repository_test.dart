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

  group('concurrent post/skip race -- Section F items 26/29/34', () {
    test(
      'two concurrent post attempts for the same occurrence create exactly one transaction, not '
      'two',
      () async {
        final String ruleId = await createExpenseRule();

        // Fired together, NOT sequentially awaited -- unlike the
        // sequential-await tests above (which already prove calling
        // this twice in a row is rejected), this is the genuine race
        // Section F asks for: two truly simultaneous in-flight calls,
        // exercising `RecurringOccurrenceRepository`'s own claim that
        // the re-check INSIDE `_db.transaction()` closes this race
        // because Drift/SQLite serializes transaction bodies on a
        // single connection, rather than merely trusting that claim.
        final List<Object> results = await Future.wait<Object>(<Future<Object>>[
          occurrenceRepo
              .postOccurrence(ruleId: ruleId, scheduledDateUtc: DateTime.utc(2026, 1, 1))
              .then<Object>((String id) => id, onError: (Object e) => e),
          occurrenceRepo
              .postOccurrence(ruleId: ruleId, scheduledDateUtc: DateTime.utc(2026, 1, 1))
              .then<Object>((String id) => id, onError: (Object e) => e),
        ]);

        final List<String> succeededIds = results.whereType<String>().toList();
        final List<RecurringOccurrenceAlreadyHandledException> rejections =
            results.whereType<RecurringOccurrenceAlreadyHandledException>().toList();
        expect(succeededIds, hasLength(1)); // exactly one call actually posted
        expect(rejections, hasLength(1)); // the other was rejected, never silently dropped

        final List<Transaction> transactions = await db.select(db.transactions).get();
        expect(transactions, hasLength(1));
        final List<RecurringOccurrenceRow> occurrences =
            await db.select(db.recurringOccurrences).get();
        expect(occurrences, hasLength(1));
        expect(occurrences.single.id, succeededIds.single);
      },
    );

    test(
      'a concurrent post and skip for the same occurrence produce exactly one handled outcome, '
      'never both',
      () async {
        final String ruleId = await createExpenseRule();

        final List<Object> results = await Future.wait<Object>(<Future<Object>>[
          occurrenceRepo
              .postOccurrence(ruleId: ruleId, scheduledDateUtc: DateTime.utc(2026, 1, 1))
              .then<Object>((String id) => id, onError: (Object e) => e),
          occurrenceRepo
              .skipOccurrence(ruleId: ruleId, scheduledDateUtc: DateTime.utc(2026, 1, 1))
              .then<Object>((String id) => id, onError: (Object e) => e),
        ]);

        final List<String> succeededIds = results.whereType<String>().toList();
        final List<RecurringOccurrenceAlreadyHandledException> rejections =
            results.whereType<RecurringOccurrenceAlreadyHandledException>().toList();
        expect(succeededIds, hasLength(1));
        expect(rejections, hasLength(1));

        // Never both posted AND skipped for the same (ruleId, scheduledDate).
        final List<RecurringOccurrenceRow> occurrences =
            await db.select(db.recurringOccurrences).get();
        expect(occurrences, hasLength(1));

        // A Transactions row exists iff the winner was the post, never
        // otherwise -- whichever action actually won the race, item 34's
        // "never both posted and skipped" invariant.
        final List<Transaction> transactions = await db.select(db.transactions).get();
        expect(transactions.length, occurrences.single.status == 'posted' ? 1 : 0);
      },
    );
  });

  group('ledger impact (FinanceEngine) -- Section F/K', () {
    test('a posted recurring expense reduces the account balance by exactly its amount', () async {
      final String accountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Wallet with balance',
        type: 'cash',
        currencyCode: 'JPY',
        openingBalance: Money.fromMinorUnits(500000, 'JPY'),
      );
      final String ruleId = await ruleRepo.createRule(
        profileId: profileId,
        kind: RecurringRuleKind.expense,
        name: 'Rent',
        amount: Money.fromMinorUnits(80000, 'JPY'),
        accountId: accountId,
        frequency: RecurrenceFrequency.monthly,
        interval: 1,
        startDate: DateTime.utc(2026, 1, 1),
      );

      await occurrenceRepo.postOccurrence(ruleId: ruleId, scheduledDateUtc: DateTime.utc(2026, 1, 1));

      final AccountRow account = await accountRepo.requireById(accountId);
      final List<LedgerTransaction> ledger =
          await transactionRepo.watchLedgerForProfile(profileId).first;
      final Money balance = FinanceEngine.accountBalance(account.toLedgerAccount(), ledger);
      // Exactly the same effect a manually-entered 80,000 expense against
      // this account would have -- `postOccurrence` calls the identical
      // `TransactionRepository.recordExpense` the Add Transaction screen
      // uses, never a parallel calculation (items 21/44).
      expect(balance, Money.fromMinorUnits(420000, 'JPY'));
    });

    test('a posted recurring income increases the account balance by exactly its amount', () async {
      final String accountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Wallet with balance',
        type: 'cash',
        currencyCode: 'JPY',
        openingBalance: Money.fromMinorUnits(500000, 'JPY'),
      );
      final String ruleId = await ruleRepo.createRule(
        profileId: profileId,
        kind: RecurringRuleKind.income,
        name: 'Salary',
        amount: Money.fromMinorUnits(300000, 'JPY'),
        accountId: accountId,
        frequency: RecurrenceFrequency.monthly,
        interval: 1,
        startDate: DateTime.utc(2026, 1, 1),
      );

      await occurrenceRepo.postOccurrence(ruleId: ruleId, scheduledDateUtc: DateTime.utc(2026, 1, 1));

      final AccountRow account = await accountRepo.requireById(accountId);
      final List<LedgerTransaction> ledger =
          await transactionRepo.watchLedgerForProfile(profileId).first;
      final Money balance = FinanceEngine.accountBalance(account.toLedgerAccount(), ledger);
      expect(balance, Money.fromMinorUnits(800000, 'JPY')); // items 22/44
    });

    test(
      'skipping an occurrence has zero ledger effect -- account balance and transaction history '
      'are both unchanged (item 32, CRITICAL)',
      () async {
        final String accountId = await accountRepo.createAccount(
          profileId: profileId,
          name: 'Wallet with balance',
          type: 'cash',
          currencyCode: 'JPY',
          openingBalance: Money.fromMinorUnits(500000, 'JPY'),
        );
        final String ruleId = await ruleRepo.createRule(
          profileId: profileId,
          kind: RecurringRuleKind.expense,
          name: 'Rent',
          amount: Money.fromMinorUnits(80000, 'JPY'),
          accountId: accountId,
          frequency: RecurrenceFrequency.monthly,
          interval: 1,
          startDate: DateTime.utc(2026, 1, 1),
        );

        final AccountRow accountBefore = await accountRepo.requireById(accountId);
        final Money balanceBefore = FinanceEngine.accountBalance(
          accountBefore.toLedgerAccount(),
          await transactionRepo.watchLedgerForProfile(profileId).first,
        );

        await occurrenceRepo.skipOccurrence(
          ruleId: ruleId,
          scheduledDateUtc: DateTime.utc(2026, 1, 1),
        );

        final AccountRow accountAfter = await accountRepo.requireById(accountId);
        final Money balanceAfter = FinanceEngine.accountBalance(
          accountAfter.toLedgerAccount(),
          await transactionRepo.watchLedgerForProfile(profileId).first,
        );
        expect(balanceAfter, balanceBefore);
        expect(balanceAfter, Money.fromMinorUnits(500000, 'JPY')); // opening balance, untouched

        final List<Transaction> transactions = await db.select(db.transactions).get();
        expect(transactions, isEmpty); // no Transactions row is ever created for a skip

        final List<RecurringOccurrenceRow> occurrences =
            await db.select(db.recurringOccurrences).get();
        expect(occurrences, hasLength(1));
        expect(occurrences.single.status, 'skipped');
        expect(occurrences.single.transactionId, isNull); // per the table's documented invariant
      },
    );
  });

  group('generated-transaction edit/delete interaction -- items 38-40', () {
    test(
      'deleting the transaction a posted occurrence generated leaves the occurrence permanently '
      "'posted' -- it can never be re-posted or re-skipped through stale state",
      () async {
        final String ruleId = await createExpenseRule();
        final String occurrenceId = await occurrenceRepo.postOccurrence(
          ruleId: ruleId,
          scheduledDateUtc: DateTime.utc(2026, 1, 1),
        );
        final RecurringOccurrenceRow occurrenceBefore =
            await (db.select(db.recurringOccurrences)..where((tbl) => tbl.id.equals(occurrenceId)))
                .getSingle();
        final String transactionId = occurrenceBefore.transactionId!;

        // The user deletes the generated transaction from the Activity
        // screen, through the same `TransactionRepository.softDelete`
        // every other transaction deletion uses -- nothing recurring-
        // specific.
        await transactionRepo.softDelete(transactionId);

        // The occurrence row itself is untouched -- still 'posted',
        // still linked to the now-deleted transaction id. There is no
        // reconciliation code path that frees it up.
        final RecurringOccurrenceRow occurrenceAfter =
            await (db.select(db.recurringOccurrences)..where((tbl) => tbl.id.equals(occurrenceId)))
                .getSingle();
        expect(occurrenceAfter.status, 'posted');
        expect(occurrenceAfter.transactionId, transactionId);

        // Neither posting nor skipping that same scheduled date is
        // possible afterward -- the occurrence stays historically
        // 'posted' rather than silently becoming postable again.
        await expectLater(
          occurrenceRepo.postOccurrence(ruleId: ruleId, scheduledDateUtc: DateTime.utc(2026, 1, 1)),
          throwsA(isA<RecurringOccurrenceAlreadyHandledException>()),
        );
        await expectLater(
          occurrenceRepo.skipOccurrence(ruleId: ruleId, scheduledDateUtc: DateTime.utc(2026, 1, 1)),
          throwsA(isA<RecurringOccurrenceAlreadyHandledException>()),
        );
      },
    );

    test(
      'editing the generated transaction directly is never overwritten by editing or deleting '
      'the recurring rule afterward',
      () async {
        final String ruleId = await createExpenseRule();
        final String occurrenceId = await occurrenceRepo.postOccurrence(
          ruleId: ruleId,
          scheduledDateUtc: DateTime.utc(2026, 1, 1),
        );
        final RecurringOccurrenceRow occurrence =
            await (db.select(db.recurringOccurrences)..where((tbl) => tbl.id.equals(occurrenceId)))
                .getSingle();
        final String transactionId = occurrence.transactionId!;

        // The user edits the posted transaction's note directly, same as
        // any ordinary transaction -- nothing about this being
        // recurring-generated makes it special.
        await transactionRepo.updateExpense(
          id: transactionId,
          accountId: jpyAccountId,
          amount: Money.fromMinorUnits(80000, 'JPY'),
          note: 'Edited by hand',
          occurredAtUtc: DateTime.utc(2026, 1, 1),
        );

        // Editing the RULE afterward (amount) never touches this
        // already-posted transaction -- there is no sync/re-derivation
        // code path from rule to historical transaction.
        await ruleRepo.updateRule(id: ruleId, amount: Money.fromMinorUnits(99999, 'JPY'));
        // Soft-deleting the rule likewise never touches it.
        await ruleRepo.softDelete(ruleId);

        final Transaction transactionAfter =
            await (db.select(db.transactions)..where((tbl) => tbl.id.equals(transactionId)))
                .getSingle();
        expect(transactionAfter.note, 'Edited by hand');
        expect(transactionAfter.amountMinorUnits, 80000); // unchanged by the rule edit
        expect(transactionAfter.deletedAt, isNull); // unchanged by the rule's soft-delete
      },
    );
  });
}
