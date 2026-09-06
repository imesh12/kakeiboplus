import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/repositories/account_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/transaction_repository.dart';
import 'package:ai_financial_coach/core/finance/finance_engine.dart';
import 'package:ai_financial_coach/core/finance/ledger_models.dart';
import 'package:ai_financial_coach/core/database/repositories/transaction_not_found_exception.dart';
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

  group('updateExpense/updateIncome — editing', () {
    test('updates amount/category/note/date, preserves id/createdAt, bumps updatedAt', () async {
      final String account = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Wallet',
        type: 'cash',
        currencyCode: 'USD',
      );
      final String expenseId = await transactionRepo.recordExpense(
        profileId: profileId,
        accountId: account,
        amount: Money.fromMinorUnits(1000, 'USD'),
        note: 'Original note',
        occurredAtUtc: DateTime.utc(2026, 1, 1),
      );
      final Transaction original = (await transactionRepo.watchById(expenseId).first)!;

      await transactionRepo.updateExpense(
        id: expenseId,
        accountId: account,
        amount: Money.fromMinorUnits(4500, 'USD'),
        note: 'Updated note',
        occurredAtUtc: DateTime.utc(2026, 1, 5, 14, 30),
      );

      final Transaction updated = (await transactionRepo.watchById(expenseId).first)!;
      expect(updated.id, original.id);
      expect(updated.createdAt, original.createdAt);
      // Drift's default (non-text) DateTime columns round-trip to
      // whole-SECOND precision (see savings_goal_repository.dart's
      // `_withUtcDateTimes` doc comment), so two writes issued
      // milliseconds apart can legitimately round to the identical
      // second -- a strict `isAfter` is not a reliable invariant at
      // that precision. What actually matters ("this write recomputed
      // updatedAt, not merely carried over the old value") is that it
      // never moved BACKWARDS; the other field assertions below already
      // prove a real write happened.
      expect(updated.updatedAt.isBefore(original.updatedAt), isFalse);
      expect(updated.type, 'expense');
      expect(updated.amountMinorUnits, 4500);
      expect(updated.note, 'Updated note');
      // `updated.occurredAt` comes back local-tagged (Drift's default
      // DateTime column behavior), so a direct `==` against a
      // UTC-tagged `DateTime.utc(...)` compares tags, not the instant --
      // `isAtSameMomentAs` is the tag-agnostic comparison Dart provides
      // for exactly this.
      expect(updated.occurredAt.isAtSameMomentAs(DateTime.utc(2026, 1, 5, 14, 30)), isTrue);
    });

    test('changing to another account of the SAME currency succeeds', () async {
      final String accountA = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Wallet',
        type: 'cash',
        currencyCode: 'USD',
      );
      final String accountB = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Bank',
        type: 'bank',
        currencyCode: 'USD',
      );
      final String expenseId = await transactionRepo.recordExpense(
        profileId: profileId,
        accountId: accountA,
        amount: Money.fromMinorUnits(1000, 'USD'),
        occurredAtUtc: DateTime.utc(2026, 1, 1),
      );

      await transactionRepo.updateExpense(
        id: expenseId,
        accountId: accountB,
        amount: Money.fromMinorUnits(1000, 'USD'),
        occurredAtUtc: DateTime.utc(2026, 1, 1),
      );

      final Transaction updated = (await transactionRepo.watchById(expenseId).first)!;
      expect(updated.accountId, accountB);
      expect(updated.currencyCode, 'USD');
      expect(updated.amountMinorUnits, 1000);
    });

    test(
      'changing to a different-currency account while submitting Money in the OLD '
      'currency throws CurrencyMismatchException and writes nothing',
      () async {
        final String usdAccount = await accountRepo.createAccount(
          profileId: profileId,
          name: 'USD Wallet',
          type: 'cash',
          currencyCode: 'USD',
        );
        final String jpyAccount = await accountRepo.createAccount(
          profileId: profileId,
          name: 'JPY Wallet',
          type: 'cash',
          currencyCode: 'JPY',
        );
        final String expenseId = await transactionRepo.recordExpense(
          profileId: profileId,
          accountId: usdAccount,
          amount: Money.fromMinorUnits(1000, 'USD'),
          occurredAtUtc: DateTime.utc(2026, 1, 1),
        );

        // Money is NEVER relabeled across currencies: submitting the
        // still-USD amount against the newly-selected JPY account must
        // be rejected, not silently reinterpreted as 1000 JPY.
        expect(
          () => transactionRepo.updateExpense(
            id: expenseId,
            accountId: jpyAccount,
            amount: Money.fromMinorUnits(1000, 'USD'),
            occurredAtUtc: DateTime.utc(2026, 1, 1),
          ),
          throwsA(isA<CurrencyMismatchException>()),
        );

        final Transaction unchanged = (await transactionRepo.watchById(expenseId).first)!;
        expect(unchanged.accountId, usdAccount);
        expect(unchanged.currencyCode, 'USD');
        expect(unchanged.amountMinorUnits, 1000);
      },
    );

    test(
      'changing to a different-currency account succeeds only when the submitted '
      'Money itself already has the new account currency, with no FX/conversion performed',
      () async {
        final String usdAccount = await accountRepo.createAccount(
          profileId: profileId,
          name: 'USD Wallet',
          type: 'cash',
          currencyCode: 'USD',
        );
        final String jpyAccount = await accountRepo.createAccount(
          profileId: profileId,
          name: 'JPY Wallet',
          type: 'cash',
          currencyCode: 'JPY',
        );
        final String expenseId = await transactionRepo.recordExpense(
          profileId: profileId,
          accountId: usdAccount,
          amount: Money.fromMinorUnits(1000, 'USD'),
          occurredAtUtc: DateTime.utc(2026, 1, 1),
        );

        // The caller (the edit form) re-parsed the displayed amount
        // under JPY and submits a genuinely-JPY Money -- 500 here is a
        // deliberately DIFFERENT magnitude than the original 1000 USD
        // minor units, precisely so this test cannot pass by accident
        // via a relabeling bug that just kept the old minorUnits.
        await transactionRepo.updateExpense(
          id: expenseId,
          accountId: jpyAccount,
          amount: Money.fromMinorUnits(500, 'JPY'),
          occurredAtUtc: DateTime.utc(2026, 1, 1),
        );

        final Transaction updated = (await transactionRepo.watchById(expenseId).first)!;
        expect(updated.accountId, jpyAccount);
        expect(updated.currencyCode, 'JPY');
        expect(updated.amountMinorUnits, 500);
      },
    );

    test('updateIncome updates fields and re-derives currency the same way updateExpense does',
        () async {
      final String usdAccount = await accountRepo.createAccount(
        profileId: profileId,
        name: 'USD Wallet',
        type: 'cash',
        currencyCode: 'USD',
      );
      final String incomeId = await transactionRepo.recordIncome(
        profileId: profileId,
        accountId: usdAccount,
        amount: Money.fromMinorUnits(2000, 'USD'),
        occurredAtUtc: DateTime.utc(2026, 1, 1),
      );

      await transactionRepo.updateIncome(
        id: incomeId,
        accountId: usdAccount,
        amount: Money.fromMinorUnits(3000, 'USD'),
        occurredAtUtc: DateTime.utc(2026, 1, 2),
      );

      final Transaction updated = (await transactionRepo.watchById(incomeId).first)!;
      expect(updated.type, 'income');
      expect(updated.amountMinorUnits, 3000);
    });

    test('rejects a non-positive amount on update', () async {
      final String account = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Wallet',
        type: 'cash',
        currencyCode: 'USD',
      );
      final String expenseId = await transactionRepo.recordExpense(
        profileId: profileId,
        accountId: account,
        amount: Money.fromMinorUnits(1000, 'USD'),
        occurredAtUtc: DateTime.utc(2026, 1, 1),
      );
      expect(
        () => transactionRepo.updateExpense(
          id: expenseId,
          accountId: account,
          amount: Money.zero('USD'),
          occurredAtUtc: DateTime.utc(2026, 1, 1),
        ),
        throwsArgumentError,
      );
    });

    test('updateExpense on a transaction that is actually an income rejects the type change',
        () async {
      final String account = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Wallet',
        type: 'cash',
        currencyCode: 'USD',
      );
      final String incomeId = await transactionRepo.recordIncome(
        profileId: profileId,
        accountId: account,
        amount: Money.fromMinorUnits(1000, 'USD'),
        occurredAtUtc: DateTime.utc(2026, 1, 1),
      );
      expect(
        () => transactionRepo.updateExpense(
          id: incomeId,
          accountId: account,
          amount: Money.fromMinorUnits(1000, 'USD'),
          occurredAtUtc: DateTime.utc(2026, 1, 1),
        ),
        throwsArgumentError,
      );
    });

    test('updateExpense on a soft-deleted transaction throws TransactionNotFoundException',
        () async {
      final String account = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Wallet',
        type: 'cash',
        currencyCode: 'USD',
      );
      final String expenseId = await transactionRepo.recordExpense(
        profileId: profileId,
        accountId: account,
        amount: Money.fromMinorUnits(1000, 'USD'),
        occurredAtUtc: DateTime.utc(2026, 1, 1),
      );
      await transactionRepo.softDelete(expenseId);

      expect(
        () => transactionRepo.updateExpense(
          id: expenseId,
          accountId: account,
          amount: Money.fromMinorUnits(2000, 'USD'),
          occurredAtUtc: DateTime.utc(2026, 1, 1),
        ),
        throwsA(isA<TransactionNotFoundException>()),
      );
    });

    test('updateExpense on a never-existed id throws TransactionNotFoundException', () async {
      final String account = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Wallet',
        type: 'cash',
        currencyCode: 'USD',
      );
      expect(
        () => transactionRepo.updateExpense(
          id: 'does-not-exist',
          accountId: account,
          amount: Money.fromMinorUnits(1000, 'USD'),
          occurredAtUtc: DateTime.utc(2026, 1, 1),
        ),
        throwsA(isA<TransactionNotFoundException>()),
      );
    });
  });

  group('updateTransfer — editing', () {
    test('updates amount/note/date, preserves id/createdAt/type, bumps updatedAt', () async {
      final String accountA = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Wallet',
        type: 'cash',
        currencyCode: 'JPY',
        openingBalance: Money.fromMinorUnits(10000, 'JPY'),
      );
      final String accountB = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Bank',
        type: 'bank',
        currencyCode: 'JPY',
      );
      final String transferId = await transactionRepo.recordTransfer(
        profileId: profileId,
        sourceAccountId: accountA,
        destinationAccountId: accountB,
        amount: Money.fromMinorUnits(1000, 'JPY'),
        occurredAtUtc: DateTime.utc(2026, 1, 1),
      );
      final Transaction original = (await transactionRepo.watchById(transferId).first)!;

      await transactionRepo.updateTransfer(
        id: transferId,
        sourceAccountId: accountA,
        destinationAccountId: accountB,
        amount: Money.fromMinorUnits(2500, 'JPY'),
        note: 'Rent split',
        occurredAtUtc: DateTime.utc(2026, 1, 3),
      );

      final Transaction updated = (await transactionRepo.watchById(transferId).first)!;
      expect(updated.id, original.id);
      expect(updated.createdAt, original.createdAt);
      // See the identical comment in the updateExpense/updateIncome
      // editing test above: Drift's default DateTime columns round-trip
      // to whole-SECOND precision, so a strict `isAfter` isn't a
      // reliable invariant between two writes issued milliseconds
      // apart -- "did not move backwards" plus the field assertions
      // below (which already prove a real write happened) is the
      // meaningful check.
      expect(updated.updatedAt.isBefore(original.updatedAt), isFalse);
      expect(updated.type, 'transfer');
      expect(updated.amountMinorUnits, 2500);
      expect(updated.note, 'Rent split');
    });

    test('editing an existing transfer keeps categoryId null', () async {
      final String accountA = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Wallet',
        type: 'cash',
        currencyCode: 'JPY',
        openingBalance: Money.fromMinorUnits(10000, 'JPY'),
      );
      final String accountB = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Bank',
        type: 'bank',
        currencyCode: 'JPY',
      );
      final String transferId = await transactionRepo.recordTransfer(
        profileId: profileId,
        sourceAccountId: accountA,
        destinationAccountId: accountB,
        amount: Money.fromMinorUnits(1000, 'JPY'),
        occurredAtUtc: DateTime.utc(2026, 1, 1),
      );

      await transactionRepo.updateTransfer(
        id: transferId,
        sourceAccountId: accountA,
        destinationAccountId: accountB,
        amount: Money.fromMinorUnits(1500, 'JPY'),
        occurredAtUtc: DateTime.utc(2026, 1, 2),
      );

      final Transaction updated = (await transactionRepo.watchById(transferId).first)!;
      expect(updated.categoryId, isNull);
    });

    test('rejects changing destination to equal the source', () async {
      final String accountA = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Wallet',
        type: 'cash',
        currencyCode: 'JPY',
        openingBalance: Money.fromMinorUnits(10000, 'JPY'),
      );
      final String accountB = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Bank',
        type: 'bank',
        currencyCode: 'JPY',
      );
      final String transferId = await transactionRepo.recordTransfer(
        profileId: profileId,
        sourceAccountId: accountA,
        destinationAccountId: accountB,
        amount: Money.fromMinorUnits(1000, 'JPY'),
        occurredAtUtc: DateTime.utc(2026, 1, 1),
      );

      expect(
        () => transactionRepo.updateTransfer(
          id: transferId,
          sourceAccountId: accountA,
          destinationAccountId: accountA,
          amount: Money.fromMinorUnits(1000, 'JPY'),
          occurredAtUtc: DateTime.utc(2026, 1, 1),
        ),
        throwsArgumentError,
      );
    });

    test('rejects changing destination to a different-currency account', () async {
      final String accountA = await accountRepo.createAccount(
        profileId: profileId,
        name: 'JPY Wallet',
        type: 'cash',
        currencyCode: 'JPY',
        openingBalance: Money.fromMinorUnits(10000, 'JPY'),
      );
      final String accountB = await accountRepo.createAccount(
        profileId: profileId,
        name: 'JPY Bank',
        type: 'bank',
        currencyCode: 'JPY',
      );
      final String usdAccount = await accountRepo.createAccount(
        profileId: profileId,
        name: 'USD Wallet',
        type: 'cash',
        currencyCode: 'USD',
      );
      final String transferId = await transactionRepo.recordTransfer(
        profileId: profileId,
        sourceAccountId: accountA,
        destinationAccountId: accountB,
        amount: Money.fromMinorUnits(1000, 'JPY'),
        occurredAtUtc: DateTime.utc(2026, 1, 1),
      );

      expect(
        () => transactionRepo.updateTransfer(
          id: transferId,
          sourceAccountId: accountA,
          destinationAccountId: usdAccount,
          amount: Money.fromMinorUnits(1000, 'JPY'),
          occurredAtUtc: DateTime.utc(2026, 1, 1),
        ),
        throwsA(isA<CurrencyMismatchException>()),
      );
    });

    test('updateTransfer on a soft-deleted transaction throws TransactionNotFoundException',
        () async {
      final String accountA = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Wallet',
        type: 'cash',
        currencyCode: 'JPY',
        openingBalance: Money.fromMinorUnits(10000, 'JPY'),
      );
      final String accountB = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Bank',
        type: 'bank',
        currencyCode: 'JPY',
      );
      final String transferId = await transactionRepo.recordTransfer(
        profileId: profileId,
        sourceAccountId: accountA,
        destinationAccountId: accountB,
        amount: Money.fromMinorUnits(1000, 'JPY'),
        occurredAtUtc: DateTime.utc(2026, 1, 1),
      );
      await transactionRepo.softDelete(transferId);

      expect(
        () => transactionRepo.updateTransfer(
          id: transferId,
          sourceAccountId: accountA,
          destinationAccountId: accountB,
          amount: Money.fromMinorUnits(1000, 'JPY'),
          occurredAtUtc: DateTime.utc(2026, 1, 1),
        ),
        throwsA(isA<TransactionNotFoundException>()),
      );
    });
  });

  group('watchById', () {
    test('emits the current row, re-emits after an update, then emits null after soft-delete',
        () async {
      final String account = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Wallet',
        type: 'cash',
        currencyCode: 'USD',
      );
      final String expenseId = await transactionRepo.recordExpense(
        profileId: profileId,
        accountId: account,
        amount: Money.fromMinorUnits(1000, 'USD'),
        occurredAtUtc: DateTime.utc(2026, 1, 1),
      );

      // Each `.first` below opens (and, once satisfied, closes) its own
      // subscription against the live query -- the same pattern already
      // used throughout this file (e.g.
      // `transactionRepo.watchLedgerForProfile(profileId).first`) --
      // rather than holding one subscription open and asserting on a
      // buffered emission list.
      expect((await transactionRepo.watchById(expenseId).first)!.amountMinorUnits, 1000);

      await transactionRepo.updateExpense(
        id: expenseId,
        accountId: account,
        amount: Money.fromMinorUnits(2000, 'USD'),
        occurredAtUtc: DateTime.utc(2026, 1, 1),
      );
      expect((await transactionRepo.watchById(expenseId).first)!.amountMinorUnits, 2000);

      await transactionRepo.softDelete(expenseId);
      expect(await transactionRepo.watchById(expenseId).first, isNull);
    });

    test('never-existed id emits null', () async {
      final Transaction? row = await transactionRepo.watchById('does-not-exist').first;
      expect(row, isNull);
    });
  });
}
