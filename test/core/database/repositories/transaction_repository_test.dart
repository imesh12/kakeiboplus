import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/repositories/account_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/cheque_book_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/cheque_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/invalid_payment_instrument_attribution_exception.dart';
import 'package:ai_financial_coach/core/database/repositories/payment_instrument_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/transaction_linked_to_cheque_exception.dart';
import 'package:ai_financial_coach/core/database/repositories/transaction_repository.dart';
import 'package:ai_financial_coach/core/finance/cheque_status.dart';
import 'package:ai_financial_coach/core/finance/finance_engine.dart';
import 'package:ai_financial_coach/core/finance/ledger_models.dart';
import 'package:ai_financial_coach/core/finance/liability_overpayment_exception.dart';
import 'package:ai_financial_coach/core/finance/payment_instrument_type.dart';
import 'package:ai_financial_coach/core/database/repositories/transaction_not_found_exception.dart';
import 'package:ai_financial_coach/core/money/currency_mismatch_exception.dart';
import 'package:ai_financial_coach/core/money/money.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

// NOTE: exercises generated Drift code — see CLAUDE_FIRST_CODING_PROMPT.md.

void main() {
  late AppDatabase db;
  late ProfileRepository profileRepo;
  late AccountRepository accountRepo;
  late TransactionRepository transactionRepo;
  late String profileId;
  const Uuid uuid = Uuid();

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

  group('Checkpoint D -- payment instrument attribution', () {
    late PaymentInstrumentRepository instrumentRepo;
    late String accountId;
    late String instrumentId;

    setUp(() async {
      instrumentRepo = PaymentInstrumentRepository(db, accountRepo);
      accountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Checking',
        type: 'bank',
        currencyCode: 'JPY',
      );
      instrumentId = await instrumentRepo.createInstrument(
        profileId: profileId,
        accountId: accountId,
        instrumentType: PaymentInstrumentType.debitCard,
        nickname: 'Everyday debit card',
      );
    });

    test('21. a transaction with a null paymentInstrumentId behaves exactly as before', () async {
      final String id = await transactionRepo.recordExpense(
        profileId: profileId,
        accountId: accountId,
        amount: Money.fromMinorUnits(500, 'JPY'),
        occurredAtUtc: DateTime.utc(2026, 1, 1),
      );
      final Transaction row = (await transactionRepo.watchById(id).first)!;
      expect(row.paymentInstrumentId, isNull);
    });

    test('22. an expense with a matching instrument succeeds', () async {
      final String id = await transactionRepo.recordExpense(
        profileId: profileId,
        accountId: accountId,
        amount: Money.fromMinorUnits(500, 'JPY'),
        occurredAtUtc: DateTime.utc(2026, 1, 1),
        paymentInstrumentId: instrumentId,
      );
      final Transaction row = (await transactionRepo.watchById(id).first)!;
      expect(row.paymentInstrumentId, instrumentId);
    });

    test('23. income attribution follows the same account-match rule', () async {
      final String id = await transactionRepo.recordIncome(
        profileId: profileId,
        accountId: accountId,
        amount: Money.fromMinorUnits(500, 'JPY'),
        occurredAtUtc: DateTime.utc(2026, 1, 1),
        paymentInstrumentId: instrumentId,
      );
      final Transaction row = (await transactionRepo.watchById(id).first)!;
      expect(row.paymentInstrumentId, instrumentId);
    });

    test('24. transfer attribution matches the SOURCE account', () async {
      final String destinationAccountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Savings',
        type: 'bank',
        currencyCode: 'JPY',
      );
      final String id = await transactionRepo.recordTransfer(
        profileId: profileId,
        sourceAccountId: accountId,
        destinationAccountId: destinationAccountId,
        amount: Money.fromMinorUnits(500, 'JPY'),
        occurredAtUtc: DateTime.utc(2026, 1, 1),
        paymentInstrumentId: instrumentId,
      );
      final Transaction row = (await transactionRepo.watchById(id).first)!;
      expect(row.paymentInstrumentId, instrumentId);
      expect(row.accountId, accountId);
    });

    test('25. an instrument linked to an unrelated account is rejected', () async {
      final String unrelatedAccountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Savings',
        type: 'bank',
        currencyCode: 'JPY',
      );
      expect(
        () => transactionRepo.recordExpense(
          profileId: profileId,
          accountId: unrelatedAccountId,
          amount: Money.fromMinorUnits(500, 'JPY'),
          occurredAtUtc: DateTime.utc(2026, 1, 1),
          paymentInstrumentId: instrumentId,
        ),
        throwsA(isA<InvalidPaymentInstrumentAttributionException>()),
      );
    });

    test('26. a cross-profile instrument is rejected', () async {
      // Seeds a second, deliberately foreign `Profiles` row directly
      // through the DB fixture -- never via
      // `ProfileRepository.createProfile()`, which enforces the
      // single-local-profile invariant that a real second local profile
      // can never exist. This test needs a foreign `profileId` to exist
      // only so `TransactionRepository`'s cross-profile attribution
      // check has something to reject; it is not exercising
      // `ProfileRepository` at all, so bypassing it here does not
      // weaken that invariant.
      const String otherProfileId = 'other-profile-fixture-26';
      final DateTime otherProfileNow = DateTime.now().toUtc();
      await db.into(db.profiles).insert(
            ProfilesCompanion.insert(
              id: otherProfileId,
              displayName: 'Other User',
              homeCountry: 'US',
              currentCountry: 'US',
              homeCurrency: 'USD',
              livingCurrency: 'USD',
              preferredLanguage: 'en',
              timezone: 'America/New_York',
              dateFormat: 'yyyy-MM-dd',
              numberFormat: '#,##0.##',
              createdAt: otherProfileNow,
              updatedAt: otherProfileNow,
            ),
          );
      final String otherAccountId = await accountRepo.createAccount(
        profileId: otherProfileId,
        name: 'Their Checking',
        type: 'bank',
        currencyCode: 'JPY',
      );
      expect(
        () => transactionRepo.recordExpense(
          profileId: otherProfileId,
          accountId: otherAccountId,
          amount: Money.fromMinorUnits(500, 'JPY'),
          occurredAtUtc: DateTime.utc(2026, 1, 1),
          paymentInstrumentId: instrumentId, // belongs to profileId, not otherProfileId
        ),
        throwsA(isA<InvalidPaymentInstrumentAttributionException>()),
      );
    });

    test('27. a deleted instrument is rejected for a new transaction', () async {
      await instrumentRepo.softDelete(instrumentId);
      expect(
        () => transactionRepo.recordExpense(
          profileId: profileId,
          accountId: accountId,
          amount: Money.fromMinorUnits(500, 'JPY'),
          occurredAtUtc: DateTime.utc(2026, 1, 1),
          paymentInstrumentId: instrumentId,
        ),
        throwsA(isA<InvalidPaymentInstrumentAttributionException>()),
      );
    });

    test('28. an existing transaction remains valid after its instrument is archived', () async {
      final String id = await transactionRepo.recordExpense(
        profileId: profileId,
        accountId: accountId,
        amount: Money.fromMinorUnits(500, 'JPY'),
        occurredAtUtc: DateTime.utc(2026, 1, 1),
        paymentInstrumentId: instrumentId,
      );
      await instrumentRepo.softDelete(instrumentId);

      final Transaction row = (await transactionRepo.watchById(id).first)!;
      expect(row.paymentInstrumentId, instrumentId);
      final PaymentInstrumentRow? archived = await instrumentRepo.findByIdIncludingDeleted(
        instrumentId,
      );
      expect(archived, isNotNull);
      expect(archived!.deletedAt, isNotNull);
    });

    test('29. paymentInstrumentId has zero effect on FinanceEngine.accountBalance', () async {
      final String withInstrumentId = await transactionRepo.recordExpense(
        profileId: profileId,
        accountId: accountId,
        amount: Money.fromMinorUnits(500, 'JPY'),
        occurredAtUtc: DateTime.utc(2026, 1, 1),
        paymentInstrumentId: instrumentId,
      );
      await transactionRepo.recordExpense(
        profileId: profileId,
        accountId: accountId,
        amount: Money.fromMinorUnits(500, 'JPY'),
        occurredAtUtc: DateTime.utc(2026, 1, 1),
        // no paymentInstrumentId here
      );
      final AccountRow account = await accountRepo.requireById(accountId);
      final List<LedgerTransaction> ledger =
          await transactionRepo.watchLedgerForProfile(profileId).first;
      // Both expenses affect the balance identically regardless of
      // attribution -- LedgerTransaction/FinanceEngine never see
      // paymentInstrumentId at all (see `_toLedger`).
      expect(
        FinanceEngine.accountBalance(account.toLedgerAccount(), ledger),
        Money.fromMinorUnits(-1000, 'JPY'),
      );
      expect(withInstrumentId, isNotEmpty);
    });

    test('30. paymentInstrumentId has zero effect on income/expense totals', () async {
      await transactionRepo.recordExpense(
        profileId: profileId,
        accountId: accountId,
        amount: Money.fromMinorUnits(300, 'JPY'),
        occurredAtUtc: DateTime.utc(2026, 1, 1),
        paymentInstrumentId: instrumentId,
      );
      await transactionRepo.recordIncome(
        profileId: profileId,
        accountId: accountId,
        amount: Money.fromMinorUnits(700, 'JPY'),
        occurredAtUtc: DateTime.utc(2026, 1, 1),
        paymentInstrumentId: instrumentId,
      );
      final List<LedgerTransaction> ledger =
          await transactionRepo.watchLedgerForProfile(profileId).first;
      final MoneyTotals totals = FinanceEngine.incomeExpenseTotals(ledger, currencyCode: 'JPY');
      expect(totals.expense, Money.fromMinorUnits(300, 'JPY'));
      expect(totals.income, Money.fromMinorUnits(700, 'JPY'));
    });
  });

  group('Checkpoint E -- credit-card purchase/payment semantics', () {
    late PaymentInstrumentRepository instrumentRepo;
    late String creditCardAccountId;
    late String bankAccountId;
    late String creditCardInstrumentId;
    late String debitCardInstrumentId;

    /// Seeds a liability account with subtype `creditCard` directly
    /// through the DB, bypassing `AccountRepository.createAccount`
    /// (which today only ever produces asset-classified rows) -- the
    /// same pattern Checkpoint D's own tests already established for
    /// this exact gap.
    Future<String> seedCreditCardAccount({String currencyCode = 'JPY'}) async {
      final String id = uuid.v4();
      final DateTime now = DateTime.now().toUtc();
      await db.into(db.accounts).insert(
            AccountsCompanion.insert(
              id: id,
              profileId: profileId,
              name: 'Credit Card',
              type: 'card',
              currencyCode: currencyCode,
              balanceClass: const Value<String>('liability'),
              subtype: const Value<String>('creditCard'),
              createdAt: now,
              updatedAt: now,
            ),
          );
      return id;
    }

    setUp(() async {
      instrumentRepo = PaymentInstrumentRepository(db, accountRepo);
      creditCardAccountId = await seedCreditCardAccount();
      bankAccountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Checking',
        type: 'bank',
        currencyCode: 'JPY',
      );
      creditCardInstrumentId = await instrumentRepo.createInstrument(
        profileId: profileId,
        accountId: creditCardAccountId,
        instrumentType: PaymentInstrumentType.creditCard,
        nickname: 'Rakuten Visa',
      );
      debitCardInstrumentId = await instrumentRepo.createInstrument(
        profileId: profileId,
        accountId: bankAccountId,
        instrumentType: PaymentInstrumentType.debitCard,
        nickname: 'Everyday debit card',
      );
    });

    Future<Money> balanceOf(String accountId) async {
      final AccountRow account = await accountRepo.requireById(accountId);
      final List<LedgerTransaction> ledger =
          await transactionRepo.watchLedgerForProfile(profileId).first;
      return FinanceEngine.accountBalance(account.toLedgerAccount(), ledger);
    }

    test('7. a credit-card purchase increases the liability debt exactly', () async {
      await transactionRepo.recordExpense(
        profileId: profileId,
        accountId: creditCardAccountId,
        amount: Money.fromMinorUnits(5000, 'JPY'),
        occurredAtUtc: DateTime.utc(2026, 1, 1),
      );
      expect(await balanceOf(creditCardAccountId), Money.fromMinorUnits(5000, 'JPY'));
    });

    test('8. a credit-card purchase leaves an unrelated bank asset unchanged', () async {
      await transactionRepo.recordExpense(
        profileId: profileId,
        accountId: creditCardAccountId,
        amount: Money.fromMinorUnits(5000, 'JPY'),
        occurredAtUtc: DateTime.utc(2026, 1, 1),
      );
      expect(await balanceOf(bankAccountId), Money.zero('JPY'));
    });

    test('9. a purchase attributed to the matching credit-card instrument succeeds', () async {
      final String id = await transactionRepo.recordExpense(
        profileId: profileId,
        accountId: creditCardAccountId,
        amount: Money.fromMinorUnits(5000, 'JPY'),
        occurredAtUtc: DateTime.utc(2026, 1, 1),
        paymentInstrumentId: creditCardInstrumentId,
      );
      final Transaction row = (await transactionRepo.watchById(id).first)!;
      expect(row.paymentInstrumentId, creditCardInstrumentId);
    });

    test('10. a credit-card instrument linked to a DIFFERENT liability account is rejected', () async {
      final String otherCreditCardAccountId = await seedCreditCardAccount();
      final String otherInstrumentId = await instrumentRepo.createInstrument(
        profileId: profileId,
        accountId: otherCreditCardAccountId,
        instrumentType: PaymentInstrumentType.creditCard,
        nickname: 'Amex',
      );
      expect(
        () => transactionRepo.recordExpense(
          profileId: profileId,
          accountId: creditCardAccountId,
          amount: Money.fromMinorUnits(5000, 'JPY'),
          occurredAtUtc: DateTime.utc(2026, 1, 1),
          paymentInstrumentId: otherInstrumentId,
        ),
        throwsA(isA<InvalidPaymentInstrumentAttributionException>()),
      );
    });

    test('11. a debit-card instrument attributed to a liability purchase is rejected', () async {
      expect(
        () => transactionRepo.recordExpense(
          profileId: profileId,
          accountId: creditCardAccountId,
          amount: Money.fromMinorUnits(5000, 'JPY'),
          occurredAtUtc: DateTime.utc(2026, 1, 1),
          paymentInstrumentId: debitCardInstrumentId,
        ),
        throwsA(isA<InvalidPaymentInstrumentAttributionException>()),
      );
    });

    test(
        'bonus: a paymentService instrument linked to the SAME liability account is still '
        'rejected -- proves the instrumentType check, not just the accountId check, is what '
        'rejects a non-creditCard instrument here', () async {
      final String paymentServiceInstrumentId = await instrumentRepo.createInstrument(
        profileId: profileId,
        accountId: creditCardAccountId,
        instrumentType: PaymentInstrumentType.paymentService,
        nickname: 'Some Wallet',
      );
      expect(
        () => transactionRepo.recordExpense(
          profileId: profileId,
          accountId: creditCardAccountId,
          amount: Money.fromMinorUnits(5000, 'JPY'),
          occurredAtUtc: DateTime.utc(2026, 1, 1),
          paymentInstrumentId: paymentServiceInstrumentId,
        ),
        throwsA(isA<InvalidPaymentInstrumentAttributionException>()),
      );
    });

    test('12. an inactive (soft-deleted) instrument attribution fails', () async {
      await instrumentRepo.softDelete(creditCardInstrumentId);
      expect(
        () => transactionRepo.recordExpense(
          profileId: profileId,
          accountId: creditCardAccountId,
          amount: Money.fromMinorUnits(5000, 'JPY'),
          occurredAtUtc: DateTime.utc(2026, 1, 1),
          paymentInstrumentId: creditCardInstrumentId,
        ),
        throwsA(isA<InvalidPaymentInstrumentAttributionException>()),
      );
    });

    test('13. a credit-card payment reduces both the asset source and the liability debt', () async {
      await transactionRepo.recordExpense(
        profileId: profileId,
        accountId: creditCardAccountId,
        amount: Money.fromMinorUnits(5000, 'JPY'),
        occurredAtUtc: DateTime.utc(2026, 1, 1),
      );
      await transactionRepo.recordTransfer(
        profileId: profileId,
        sourceAccountId: bankAccountId,
        destinationAccountId: creditCardAccountId,
        amount: Money.fromMinorUnits(3000, 'JPY'),
        occurredAtUtc: DateTime.utc(2026, 1, 2),
      );
      expect(await balanceOf(bankAccountId), Money.fromMinorUnits(-3000, 'JPY'));
      expect(await balanceOf(creditCardAccountId), Money.fromMinorUnits(2000, 'JPY'));
    });

    test('14. a credit-card payment is a transfer -- never counted as income or expense', () async {
      await transactionRepo.recordExpense(
        profileId: profileId,
        accountId: creditCardAccountId,
        amount: Money.fromMinorUnits(5000, 'JPY'),
        occurredAtUtc: DateTime.utc(2026, 1, 1),
      );
      await transactionRepo.recordTransfer(
        profileId: profileId,
        sourceAccountId: bankAccountId,
        destinationAccountId: creditCardAccountId,
        amount: Money.fromMinorUnits(3000, 'JPY'),
        occurredAtUtc: DateTime.utc(2026, 1, 2),
      );
      final List<LedgerTransaction> ledger =
          await transactionRepo.watchLedgerForProfile(profileId).first;
      final MoneyTotals totals = FinanceEngine.incomeExpenseTotals(ledger, currencyCode: 'JPY');
      // Only the purchase (5000) is an expense; the 3000 payment never
      // appears in either total -- it is TransactionType.transfer.
      expect(totals.expense, Money.fromMinorUnits(5000, 'JPY'));
      expect(totals.income, Money.zero('JPY'));
    });

    test('15. an exact payoff to zero succeeds', () async {
      await transactionRepo.recordExpense(
        profileId: profileId,
        accountId: creditCardAccountId,
        amount: Money.fromMinorUnits(5000, 'JPY'),
        occurredAtUtc: DateTime.utc(2026, 1, 1),
      );
      await transactionRepo.recordTransfer(
        profileId: profileId,
        sourceAccountId: bankAccountId,
        destinationAccountId: creditCardAccountId,
        amount: Money.fromMinorUnits(5000, 'JPY'),
        occurredAtUtc: DateTime.utc(2026, 1, 2),
      );
      expect(await balanceOf(creditCardAccountId), Money.zero('JPY'));
    });

    test(
        '16. an overpayment below zero fails under existing FinanceEngine semantics '
        '(LiabilityOverpaymentException, not silently clamped)', () async {
      await transactionRepo.recordExpense(
        profileId: profileId,
        accountId: creditCardAccountId,
        amount: Money.fromMinorUnits(5000, 'JPY'),
        occurredAtUtc: DateTime.utc(2026, 1, 1),
      );
      await transactionRepo.recordTransfer(
        profileId: profileId,
        sourceAccountId: bankAccountId,
        destinationAccountId: creditCardAccountId,
        amount: Money.fromMinorUnits(6000, 'JPY'),
        occurredAtUtc: DateTime.utc(2026, 1, 2),
      );
      expect(
        () => balanceOf(creditCardAccountId),
        throwsA(isA<LiabilityOverpaymentException>()),
      );
    });

    test('17. a cross-currency credit-card payment is still rejected (same-currency-only V1 rule)',
        () async {
      final String usdCreditCardAccountId = await seedCreditCardAccount(currencyCode: 'USD');
      expect(
        () => transactionRepo.recordTransfer(
          profileId: profileId,
          sourceAccountId: bankAccountId, // JPY
          destinationAccountId: usdCreditCardAccountId, // USD
          amount: Money.fromMinorUnits(3000, 'JPY'),
          occurredAtUtc: DateTime.utc(2026, 1, 2),
        ),
        throwsA(isA<CurrencyMismatchException>()),
      );
    });
  });

  group('Checkpoint F -- deposit funding/maturity/interest semantics', () {
    late String depositAccountId;
    late String bankAccountId2;

    /// Seeds an asset account with subtype `deposit` directly through
    /// the DB, bypassing `AccountRepository.createAccount` (which today
    /// only ever produces a legacy-classified subtype, never `deposit`)
    /// -- the same gap Checkpoint E's own `seedCreditCardAccount` above
    /// already documents for a liability/creditCard account.
    Future<String> seedDepositAccount({
      String currencyCode = 'JPY',
      int openingBalanceMinorUnits = 0,
    }) async {
      final String id = uuid.v4();
      final DateTime now = DateTime.now().toUtc();
      await db.into(db.accounts).insert(
            AccountsCompanion.insert(
              id: id,
              profileId: profileId,
              name: 'Fixed Deposit',
              type: 'bank',
              currencyCode: currencyCode,
              openingBalanceMinorUnits: Value<int>(openingBalanceMinorUnits),
              balanceClass: const Value<String>('asset'),
              subtype: const Value<String>('deposit'),
              createdAt: now,
              updatedAt: now,
            ),
          );
      return id;
    }

    setUp(() async {
      depositAccountId = await seedDepositAccount();
      bankAccountId2 = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Checking (Checkpoint F)',
        type: 'bank',
        currencyCode: 'JPY',
        openingBalance: Money.fromMinorUnits(100000, 'JPY'),
      );
    });

    Future<Money> balanceOf(String accountId) async {
      final AccountRow account = await accountRepo.requireById(accountId);
      final List<LedgerTransaction> ledger =
          await transactionRepo.watchLedgerForProfile(profileId).first;
      return FinanceEngine.accountBalance(account.toLedgerAccount(), ledger);
    }

    test('26. funding a deposit is transfer semantics, not an expense', () async {
      await transactionRepo.recordTransfer(
        profileId: profileId,
        sourceAccountId: bankAccountId2,
        destinationAccountId: depositAccountId,
        amount: Money.fromMinorUnits(50000, 'JPY'),
        occurredAtUtc: DateTime.utc(2026, 1, 1),
      );
      expect(await balanceOf(depositAccountId), Money.fromMinorUnits(50000, 'JPY'));
      expect(await balanceOf(bankAccountId2), Money.fromMinorUnits(50000, 'JPY'));

      final List<LedgerTransaction> ledger =
          await transactionRepo.watchLedgerForProfile(profileId).first;
      final MoneyTotals totals = FinanceEngine.incomeExpenseTotals(ledger, currencyCode: 'JPY');
      expect(totals.expense, Money.zero('JPY'));
      expect(totals.income, Money.zero('JPY'));
    });

    test('27. a deposit maturity principal movement is transfer-like, not income', () async {
      await transactionRepo.recordTransfer(
        profileId: profileId,
        sourceAccountId: bankAccountId2,
        destinationAccountId: depositAccountId,
        amount: Money.fromMinorUnits(50000, 'JPY'),
        occurredAtUtc: DateTime.utc(2026, 1, 1),
      );
      // Maturity: the principal returns to the bank account -- an
      // ordinary transfer, exactly like funding, never income.
      await transactionRepo.recordTransfer(
        profileId: profileId,
        sourceAccountId: depositAccountId,
        destinationAccountId: bankAccountId2,
        amount: Money.fromMinorUnits(50000, 'JPY'),
        occurredAtUtc: DateTime.utc(2027, 1, 1),
      );
      expect(await balanceOf(depositAccountId), Money.zero('JPY'));
      expect(await balanceOf(bankAccountId2), Money.fromMinorUnits(100000, 'JPY'));

      final List<LedgerTransaction> ledger =
          await transactionRepo.watchLedgerForProfile(profileId).first;
      final MoneyTotals totals = FinanceEngine.incomeExpenseTotals(ledger, currencyCode: 'JPY');
      expect(totals.income, Money.zero('JPY'));
      expect(totals.expense, Money.zero('JPY'));
    });

    test('28. interest actually credited is recorded as income', () async {
      await transactionRepo.recordTransfer(
        profileId: profileId,
        sourceAccountId: bankAccountId2,
        destinationAccountId: depositAccountId,
        amount: Money.fromMinorUnits(50000, 'JPY'),
        occurredAtUtc: DateTime.utc(2026, 1, 1),
      );
      // Interest credited directly into the deposit account itself
      // (the default -- no separate interestDestinationAccountId).
      await transactionRepo.recordIncome(
        profileId: profileId,
        accountId: depositAccountId,
        amount: Money.fromMinorUnits(2750, 'JPY'),
        occurredAtUtc: DateTime.utc(2027, 1, 1),
      );
      expect(await balanceOf(depositAccountId), Money.fromMinorUnits(52750, 'JPY'));

      final List<LedgerTransaction> ledger =
          await transactionRepo.watchLedgerForProfile(profileId).first;
      final MoneyTotals totals = FinanceEngine.incomeExpenseTotals(ledger, currencyCode: 'JPY');
      expect(totals.income, Money.fromMinorUnits(2750, 'JPY'));
      expect(totals.expense, Money.zero('JPY'));
    });

    test('28b. interest credited to a separate interestDestinationAccountId is still income, '
        'and never touches the deposit\'s own balance', () async {
      await transactionRepo.recordTransfer(
        profileId: profileId,
        sourceAccountId: bankAccountId2,
        destinationAccountId: depositAccountId,
        amount: Money.fromMinorUnits(50000, 'JPY'),
        occurredAtUtc: DateTime.utc(2026, 1, 1),
      );
      await transactionRepo.recordIncome(
        profileId: profileId,
        accountId: bankAccountId2, // interest paid out to the linked bank account
        amount: Money.fromMinorUnits(2750, 'JPY'),
        occurredAtUtc: DateTime.utc(2027, 1, 1),
      );
      expect(await balanceOf(depositAccountId), Money.fromMinorUnits(50000, 'JPY')); // unchanged
      expect(await balanceOf(bankAccountId2), Money.fromMinorUnits(52750, 'JPY'));

      final List<LedgerTransaction> ledger =
          await transactionRepo.watchLedgerForProfile(profileId).first;
      final MoneyTotals totals = FinanceEngine.incomeExpenseTotals(ledger, currencyCode: 'JPY');
      expect(totals.income, Money.fromMinorUnits(2750, 'JPY'));
    });
  });

  /// Checkpoint N integrity repair -- see
  /// `TransactionRepository._requireNotChequeLinked`'s own doc.
  /// `ChequeRepository.markCleared` posts exactly one ordinary
  /// [Transaction] row and stores its id on the cleared [ChequeRow];
  /// every test below proves the reverse direction is blocked: none of
  /// `updateExpense`/`updateIncome`/`updateTransfer`/`softDelete` may
  /// silently change or remove that row while the cheque still claims
  /// [ChequeStatus.cleared]. An ordinary, never-cheque-linked
  /// transaction is proven to retain completely normal edit/delete
  /// behavior throughout.
  group('Checkpoint N: cheque-linked transaction protection', () {
    late ChequeBookRepository chequeBookRepo;
    late ChequeRepository chequeRepo;

    setUp(() {
      chequeBookRepo = ChequeBookRepository(db, accountRepo);
      chequeRepo = ChequeRepository(db, accountRepo, chequeBookRepo, transactionRepo);
    });

    /// A `bank`-subtype asset account -- eligible for a chequebook, the
    /// same `type: 'bank'` legacy-inference convention
    /// `cheque_repository_test.dart`'s own `seedBankAccount` uses.
    Future<String> seedBankAccount({Money? openingBalance}) {
      return accountRepo.createAccount(
        profileId: profileId,
        name: 'Everyday Chequing',
        type: 'bank',
        currencyCode: 'USD',
        openingBalance: openingBalance,
      );
    }

    /// The raw `Transactions` row, unfiltered by `deletedAt` -- unlike
    /// `watchById`, this must still resolve a soft-deleted row so tests
    /// can assert `deletedAt` stayed null after a rejected delete.
    Future<Transaction> rawTransaction(String id) =>
        (db.select(db.transactions)..where((tbl) => tbl.id.equals(id))).getSingle();

    Future<Money> balanceOf(String accountId) async {
      final AccountRow account = await accountRepo.requireById(accountId);
      final List<LedgerTransaction> ledger =
          await transactionRepo.watchLedgerForProfile(profileId).first;
      return FinanceEngine.accountBalance(account.toLedgerAccount(), ledger);
    }

    /// Records, then clears, one issued cheque -- the shared fixture
    /// for every "cleared issued cheque" test below.
    Future<({String chequeId, String transactionId, String accountId})> clearedIssuedCheque({
      int amountMinorUnits = 25000,
      int openingBalanceMinorUnits = 100000,
    }) async {
      final String accountId = await seedBankAccount(
        openingBalance: Money.fromMinorUnits(openingBalanceMinorUnits, 'USD'),
      );
      final String bookId = await chequeBookRepo.createChequeBook(
        profileId: profileId,
        accountId: accountId,
        label: 'Book',
      );
      final String chequeId = await chequeRepo.recordIssued(
        profileId: profileId,
        accountId: accountId,
        chequeBookId: bookId,
        chequeNumber: '000900',
        amount: Money.fromMinorUnits(amountMinorUnits, 'USD'),
        payeeName: 'Landlord',
        issueDateUtc: DateTime.utc(2026, 9, 1),
      );
      final String transactionId = await chequeRepo.markCleared(
        chequeId: chequeId,
        clearedDateUtc: DateTime.utc(2026, 9, 5),
      );
      return (chequeId: chequeId, transactionId: transactionId, accountId: accountId);
    }

    /// Records, then clears, one received cheque -- the shared fixture
    /// for every "cleared received cheque" test below.
    Future<({String chequeId, String transactionId, String accountId})> clearedReceivedCheque({
      int amountMinorUnits = 30000,
    }) async {
      final String accountId = await seedBankAccount();
      final String chequeId = await chequeRepo.recordReceived(
        profileId: profileId,
        accountId: accountId,
        chequeNumber: '2002',
        amount: Money.fromMinorUnits(amountMinorUnits, 'USD'),
        payerName: 'Payer',
        issueDateUtc: DateTime.utc(2026, 9, 1),
        receivedDateUtc: DateTime.utc(2026, 9, 1),
      );
      final String transactionId = await chequeRepo.markCleared(
        chequeId: chequeId,
        clearedDateUtc: DateTime.utc(2026, 9, 6),
      );
      return (chequeId: chequeId, transactionId: transactionId, accountId: accountId);
    }

    test(
      '1. editing a cleared ISSUED cheque\'s linked transaction throws '
      'TransactionLinkedToChequeException, and neither the transaction nor the cheque changes',
      () async {
        final result = await clearedIssuedCheque();
        final Transaction before = await rawTransaction(result.transactionId);

        await expectLater(
          transactionRepo.updateExpense(
            id: result.transactionId,
            accountId: result.accountId,
            amount: Money.fromMinorUnits(99999, 'USD'),
            occurredAtUtc: DateTime.utc(2026, 9, 10),
          ),
          throwsA(
            isA<TransactionLinkedToChequeException>()
                .having((e) => e.transactionId, 'transactionId', result.transactionId)
                .having((e) => e.chequeId, 'chequeId', result.chequeId),
          ),
        );

        final Transaction after = await rawTransaction(result.transactionId);
        expect(after.amountMinorUnits, before.amountMinorUnits);
        expect(after.occurredAt.isAtSameMomentAs(before.occurredAt), isTrue);
        expect(after.updatedAt.isAtSameMomentAs(before.updatedAt), isTrue);
        expect(after.deletedAt, isNull);

        final ChequeRow cheque = await chequeRepo.requireById(result.chequeId);
        expect(cheque.statusValue, ChequeStatus.cleared);
        expect(cheque.transactionId, result.transactionId);
      },
    );

    test(
      '2. soft-deleting a cleared ISSUED cheque\'s linked transaction throws '
      'TransactionLinkedToChequeException, and neither the transaction nor the cheque changes',
      () async {
        final result = await clearedIssuedCheque();

        await expectLater(
          transactionRepo.softDelete(result.transactionId),
          throwsA(isA<TransactionLinkedToChequeException>()),
        );

        final Transaction after = await rawTransaction(result.transactionId);
        expect(after.deletedAt, isNull);

        final ChequeRow cheque = await chequeRepo.requireById(result.chequeId);
        expect(cheque.statusValue, ChequeStatus.cleared);
        expect(cheque.transactionId, result.transactionId);
      },
    );

    test(
      '3. editing a cleared RECEIVED cheque\'s linked transaction throws '
      'TransactionLinkedToChequeException',
      () async {
        final result = await clearedReceivedCheque();

        await expectLater(
          transactionRepo.updateIncome(
            id: result.transactionId,
            accountId: result.accountId,
            amount: Money.fromMinorUnits(1, 'USD'),
            occurredAtUtc: DateTime.utc(2026, 9, 10),
          ),
          throwsA(isA<TransactionLinkedToChequeException>()),
        );

        final ChequeRow cheque = await chequeRepo.requireById(result.chequeId);
        expect(cheque.statusValue, ChequeStatus.cleared);
      },
    );

    test(
      '4. soft-deleting a cleared RECEIVED cheque\'s linked transaction throws '
      'TransactionLinkedToChequeException',
      () async {
        final result = await clearedReceivedCheque();

        await expectLater(
          transactionRepo.softDelete(result.transactionId),
          throwsA(isA<TransactionLinkedToChequeException>()),
        );

        final Transaction after = await rawTransaction(result.transactionId);
        expect(after.deletedAt, isNull);
      },
    );

    test('5. an ordinary, unlinked expense remains fully editable', () async {
      final String accountId = await seedBankAccount(
        openingBalance: Money.fromMinorUnits(100000, 'USD'),
      );
      final String txId = await transactionRepo.recordExpense(
        profileId: profileId,
        accountId: accountId,
        amount: Money.fromMinorUnits(5000, 'USD'),
        occurredAtUtc: DateTime.utc(2026, 9, 1),
      );

      await transactionRepo.updateExpense(
        id: txId,
        accountId: accountId,
        amount: Money.fromMinorUnits(6000, 'USD'),
        occurredAtUtc: DateTime.utc(2026, 9, 2),
      );

      final Transaction after = await rawTransaction(txId);
      expect(after.amountMinorUnits, 6000);
    });

    test('6. an ordinary, unlinked income remains fully editable', () async {
      final String accountId = await seedBankAccount();
      final String txId = await transactionRepo.recordIncome(
        profileId: profileId,
        accountId: accountId,
        amount: Money.fromMinorUnits(5000, 'USD'),
        occurredAtUtc: DateTime.utc(2026, 9, 1),
      );

      await transactionRepo.updateIncome(
        id: txId,
        accountId: accountId,
        amount: Money.fromMinorUnits(7000, 'USD'),
        occurredAtUtc: DateTime.utc(2026, 9, 2),
      );

      final Transaction after = await rawTransaction(txId);
      expect(after.amountMinorUnits, 7000);
    });

    test('7. an ordinary, unlinked transaction remains fully soft-deletable', () async {
      final String accountId = await seedBankAccount();
      final String txId = await transactionRepo.recordExpense(
        profileId: profileId,
        accountId: accountId,
        amount: Money.fromMinorUnits(5000, 'USD'),
        occurredAtUtc: DateTime.utc(2026, 9, 1),
      );

      await transactionRepo.softDelete(txId);

      final Transaction after = await rawTransaction(txId);
      expect(after.deletedAt, isNotNull);
    });

    test(
      '8. a rejected mutation attempt on a cheque-linked transaction leaves the account '
      'balance completely unchanged',
      () async {
        final result = await clearedIssuedCheque(
          amountMinorUnits: 25000,
          openingBalanceMinorUnits: 100000,
        );
        final Money before = await balanceOf(result.accountId);

        await expectLater(
          transactionRepo.updateExpense(
            id: result.transactionId,
            accountId: result.accountId,
            amount: Money.fromMinorUnits(1, 'USD'),
            occurredAtUtc: DateTime.utc(2026, 9, 10),
          ),
          throwsA(isA<TransactionLinkedToChequeException>()),
        );

        expect(await balanceOf(result.accountId), before);
      },
    );

    test(
      '9. a rejected mutation attempt never changes the cheque\'s own status or transactionId',
      () async {
        final result = await clearedIssuedCheque();
        final ChequeRow before = await chequeRepo.requireById(result.chequeId);

        await expectLater(
          transactionRepo.softDelete(result.transactionId),
          throwsA(isA<TransactionLinkedToChequeException>()),
        );

        final ChequeRow after = await chequeRepo.requireById(result.chequeId);
        expect(after.statusValue, before.statusValue);
        expect(after.transactionId, before.transactionId);
        expect(after.clearedDate, before.clearedDate);
      },
    );

    test(
      '10. updateTransfer cannot transform a cheque-linked transaction into a transfer either '
      '-- rejected by the pre-existing type-immutability check (a cheque never posts a '
      'transfer-type row in the first place, so this path never even reaches the new '
      'cheque-link guard, but the outcome is identically "rejected, nothing changes")',
      () async {
        final String otherAccountId = await seedBankAccount();
        final result = await clearedIssuedCheque();

        await expectLater(
          transactionRepo.updateTransfer(
            id: result.transactionId,
            sourceAccountId: result.accountId,
            destinationAccountId: otherAccountId,
            amount: Money.fromMinorUnits(25000, 'USD'),
            occurredAtUtc: DateTime.utc(2026, 9, 10),
          ),
          throwsA(isA<ArgumentError>()),
        );

        final Transaction after = await rawTransaction(result.transactionId);
        expect(after.type, 'expense');
      },
    );
  });
}
