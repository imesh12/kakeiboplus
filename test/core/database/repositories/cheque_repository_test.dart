import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/repositories/account_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/cheque_book_not_found_exception.dart';
import 'package:ai_financial_coach/core/database/repositories/cheque_book_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/cheque_lifecycle_exception.dart';
import 'package:ai_financial_coach/core/database/repositories/cheque_not_found_exception.dart';
import 'package:ai_financial_coach/core/database/repositories/cheque_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/cheque_validation_exception.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/transaction_repository.dart';
import 'package:ai_financial_coach/core/finance/balance_class.dart';
import 'package:ai_financial_coach/core/finance/cheque_direction.dart';
import 'package:ai_financial_coach/core/finance/cheque_status.dart';
import 'package:ai_financial_coach/core/finance/finance_engine.dart';
import 'package:ai_financial_coach/core/finance/financial_account_subtype.dart';
import 'package:ai_financial_coach/core/finance/ledger_models.dart';
import 'package:ai_financial_coach/core/money/currency_mismatch_exception.dart';
import 'package:ai_financial_coach/core/money/money.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// NOTE: exercises generated Drift code -- see CLAUDE_FIRST_CODING_PROMPT.md.
//
// Checkpoint N: ChequeBookRepository/ChequeRepository -- the
// ChequeBooks/Cheques foundation. See `tables.dart`'s `Cheques` doc and
// `docs/20_ACCOUNTS_ASSETS_HOUSEHOLD_ARCHITECTURE.md` §13.16 for the
// full accounting-semantics rationale every test below verifies.
void main() {
  late AppDatabase db;
  late ProfileRepository profileRepo;
  late AccountRepository accountRepo;
  late TransactionRepository transactionRepo;
  late ChequeBookRepository chequeBookRepo;
  late ChequeRepository chequeRepo;
  late String profileId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    profileRepo = ProfileRepository(db);
    accountRepo = AccountRepository(db);
    transactionRepo = TransactionRepository(db, accountRepo);
    chequeBookRepo = ChequeBookRepository(db, accountRepo);
    chequeRepo = ChequeRepository(db, accountRepo, chequeBookRepo, transactionRepo);

    profileId = await profileRepo.createProfile(
      displayName: 'Test User',
      homeCountry: 'US',
      currentCountry: 'US',
      homeCurrency: 'USD',
      livingCurrency: 'USD',
      preferredLanguage: 'en',
      timezone: 'America/New_York',
      dateFormat: 'yyyy-MM-dd',
      numberFormat: '#,##0.##',
    );
  });

  tearDown(() async {
    await db.close();
  });

  /// A `bank`-subtype asset account -- created through the real,
  /// unmodified `AccountRepository.createAccount` (its legacy `type`
  /// inference already maps `'bank'` to `subtype: bank` -- see
  /// `classifyLegacyAccountType`), so this is an ordinary, already
  /// end-to-end-creatable account, not a DB-seeded fixture.
  Future<String> seedBankAccount({
    String currencyCode = 'USD',
    Money? openingBalance,
  }) {
    return accountRepo.createAccount(
      profileId: profileId,
      name: 'Everyday Chequing',
      type: 'bank',
      currencyCode: currencyCode,
      openingBalance: openingBalance,
    );
  }

  /// A `savings`-subtype asset account -- Checkpoint K's first-class
  /// subtype, created via `createClassifiedAccount` (today's legacy
  /// `createAccount` type-inference never produces `savings`).
  Future<String> seedSavingsAccount({String currencyCode = 'USD'}) {
    return accountRepo.createClassifiedAccount(
      profileId: profileId,
      name: 'Savings',
      type: 'bank',
      balanceClass: BalanceClass.asset,
      subtype: FinancialAccountSubtype.savings,
      currencyCode: currencyCode,
    );
  }

  /// A `cash`-subtype asset account -- eligible for neither a chequebook
  /// nor a received-cheque deposit target, for the ineligibility tests.
  Future<String> seedCashAccount({String currencyCode = 'USD'}) {
    return accountRepo.createAccount(
      profileId: profileId,
      name: 'Wallet Cash',
      type: 'cash',
      currencyCode: currencyCode,
    );
  }

  /// A liability, `creditCard`-subtype account -- Checkpoint O:
  /// eligible for neither a chequebook nor a received-cheque deposit
  /// target. Credit card is already double-excluded by
  /// `chequeEligibleAccountSubtypes` (not in the set) AND by the
  /// `account.isAsset` check both call sites apply -- this fixture lets
  /// the tests below prove that in practice, not just by reading the
  /// set literal.
  Future<String> seedCreditCardAccount({String currencyCode = 'USD'}) {
    return accountRepo.createClassifiedAccount(
      profileId: profileId,
      name: 'Credit Card',
      type: 'creditCard',
      balanceClass: BalanceClass.liability,
      subtype: FinancialAccountSubtype.creditCard,
      currencyCode: currencyCode,
    );
  }

  Future<List<LedgerTransaction>> ledgerFor(String forProfileId) =>
      transactionRepo.watchLedgerForProfile(forProfileId).first;

  group('ChequeBookRepository.createChequeBook', () {
    test('1. creates a chequebook for an eligible bank account', () async {
      final String accountId = await seedBankAccount();
      final String id = await chequeBookRepo.createChequeBook(
        profileId: profileId,
        accountId: accountId,
        label: 'Primary chequebook',
        startingNumber: '000101',
      );
      final ChequeBookRow row = await chequeBookRepo.requireActive(id);
      expect(row.accountId, accountId);
      expect(row.label, 'Primary chequebook');
      expect(row.startingNumber, '000101');
      expect(row.deletedAt, isNull);
    });

    test('2. creates a chequebook for an eligible savings account', () async {
      final String accountId = await seedSavingsAccount();
      final String id = await chequeBookRepo.createChequeBook(
        profileId: profileId,
        accountId: accountId,
        label: 'Savings chequebook',
      );
      expect((await chequeBookRepo.requireActive(id)).accountId, accountId);
    });

    test('3. rejects an ineligible (cash) account subtype', () async {
      final String accountId = await seedCashAccount();
      expect(
        () => chequeBookRepo.createChequeBook(
          profileId: profileId,
          accountId: accountId,
          label: 'Should not be allowed',
        ),
        throwsA(isA<ChequeValidationException>()),
      );
    });

    test(
        'Checkpoint O item Y -- rejects a credit-card (liability) account; credit card must '
        'never become cheque-eligible', () async {
      final String accountId = await seedCreditCardAccount();
      expect(
        () => chequeBookRepo.createChequeBook(
          profileId: profileId,
          accountId: accountId,
          label: 'Should not be allowed',
        ),
        throwsA(isA<ChequeValidationException>()),
      );
    });

    test('4. rejects a blank label', () async {
      final String accountId = await seedBankAccount();
      expect(
        () => chequeBookRepo.createChequeBook(
          profileId: profileId,
          accountId: accountId,
          label: '   ',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('5. rejects a deleted/inactive account', () async {
      final String accountId = await seedBankAccount();
      await accountRepo.softDelete(accountId);
      expect(
        () => chequeBookRepo.createChequeBook(
          profileId: profileId,
          accountId: accountId,
          label: 'Too late',
        ),
        throwsA(isA<ChequeValidationException>()),
      );
    });

    test('6. closeChequeBook marks it closed; requireActive then throws', () async {
      final String accountId = await seedBankAccount();
      final String id = await chequeBookRepo.createChequeBook(
        profileId: profileId,
        accountId: accountId,
        label: 'Retiring book',
      );
      await chequeBookRepo.closeChequeBook(id);
      expect(
        () => chequeBookRepo.requireActive(id),
        throwsA(isA<ChequeBookNotFoundException>()),
      );
    });
  });

  group('ChequeRepository.recordIssued', () {
    test('7. creates a pending issued cheque with NO Transactions row', () async {
      final String accountId = await seedBankAccount();
      final String bookId = await chequeBookRepo.createChequeBook(
        profileId: profileId,
        accountId: accountId,
        label: 'Book',
      );
      final String chequeId = await chequeRepo.recordIssued(
        profileId: profileId,
        accountId: accountId,
        chequeBookId: bookId,
        chequeNumber: '000202',
        amount: Money.fromMinorUnits(15000, 'USD'),
        payeeName: 'Landlord',
        issueDateUtc: DateTime.utc(2026, 9, 1),
      );

      final ChequeRow row = await chequeRepo.requireById(chequeId);
      expect(row.statusValue, ChequeStatus.pending);
      expect(row.directionValue, ChequeDirection.issued);
      expect(row.transactionId, isNull);
      expect((await ledgerFor(profileId)), isEmpty);
    });

    test('8. preserves a leading-zero cheque number exactly (TEXT, not numeric)', () async {
      final String accountId = await seedBankAccount();
      final String bookId = await chequeBookRepo.createChequeBook(
        profileId: profileId,
        accountId: accountId,
        label: 'Book',
      );
      final String chequeId = await chequeRepo.recordIssued(
        profileId: profileId,
        accountId: accountId,
        chequeBookId: bookId,
        chequeNumber: '000045',
        amount: Money.fromMinorUnits(500, 'USD'),
        payeeName: 'Someone',
        issueDateUtc: DateTime.utc(2026, 9, 1),
      );
      expect((await chequeRepo.requireById(chequeId)).chequeNumber, '000045');
    });

    test('9. rejects a duplicate cheque number within the SAME chequebook', () async {
      final String accountId = await seedBankAccount();
      final String bookId = await chequeBookRepo.createChequeBook(
        profileId: profileId,
        accountId: accountId,
        label: 'Book',
      );
      await chequeRepo.recordIssued(
        profileId: profileId,
        accountId: accountId,
        chequeBookId: bookId,
        chequeNumber: '000300',
        amount: Money.fromMinorUnits(100, 'USD'),
        payeeName: 'A',
        issueDateUtc: DateTime.utc(2026, 9, 1),
      );
      expect(
        () => chequeRepo.recordIssued(
          profileId: profileId,
          accountId: accountId,
          chequeBookId: bookId,
          chequeNumber: '000300',
          amount: Money.fromMinorUnits(200, 'USD'),
          payeeName: 'B',
          issueDateUtc: DateTime.utc(2026, 9, 2),
        ),
        throwsA(isA<ChequeValidationException>()),
      );
    });

    test('10. allows the SAME cheque number across two DIFFERENT chequebooks', () async {
      final String accountId = await seedBankAccount();
      final String bookA = await chequeBookRepo.createChequeBook(
        profileId: profileId,
        accountId: accountId,
        label: 'Book A',
      );
      final String bookB = await chequeBookRepo.createChequeBook(
        profileId: profileId,
        accountId: accountId,
        label: 'Book B',
      );
      await chequeRepo.recordIssued(
        profileId: profileId,
        accountId: accountId,
        chequeBookId: bookA,
        chequeNumber: '000001',
        amount: Money.fromMinorUnits(100, 'USD'),
        payeeName: 'A',
        issueDateUtc: DateTime.utc(2026, 9, 1),
      );
      // Does not throw -- different book, same number is allowed.
      await chequeRepo.recordIssued(
        profileId: profileId,
        accountId: accountId,
        chequeBookId: bookB,
        chequeNumber: '000001',
        amount: Money.fromMinorUnits(100, 'USD'),
        payeeName: 'A',
        issueDateUtc: DateTime.utc(2026, 9, 1),
      );
    });

    test('11. rejects a currency mismatch against the account', () async {
      final String accountId = await seedBankAccount();
      final String bookId = await chequeBookRepo.createChequeBook(
        profileId: profileId,
        accountId: accountId,
        label: 'Book',
      );
      expect(
        () => chequeRepo.recordIssued(
          profileId: profileId,
          accountId: accountId,
          chequeBookId: bookId,
          chequeNumber: '000400',
          amount: Money.fromMinorUnits(100, 'JPY'),
          payeeName: 'A',
          issueDateUtc: DateTime.utc(2026, 9, 1),
        ),
        throwsA(isA<CurrencyMismatchException>()),
      );
    });

    test('12. rejects an ineligible (cash) account', () async {
      final String bankAccountId = await seedBankAccount();
      final String bookId = await chequeBookRepo.createChequeBook(
        profileId: profileId,
        accountId: bankAccountId,
        label: 'Book',
      );
      final String cashAccountId = await seedCashAccount();
      expect(
        () => chequeRepo.recordIssued(
          profileId: profileId,
          accountId: cashAccountId,
          chequeBookId: bookId,
          chequeNumber: '000500',
          amount: Money.fromMinorUnits(100, 'USD'),
          payeeName: 'A',
          issueDateUtc: DateTime.utc(2026, 9, 1),
        ),
        throwsA(isA<ChequeValidationException>()),
      );
    });

    test(
        'Checkpoint O item Y -- rejects issuing a cheque against a credit-card (liability) '
        'account', () async {
      final String bankAccountId = await seedBankAccount();
      final String bookId = await chequeBookRepo.createChequeBook(
        profileId: profileId,
        accountId: bankAccountId,
        label: 'Book',
      );
      final String creditCardAccountId = await seedCreditCardAccount();
      expect(
        () => chequeRepo.recordIssued(
          profileId: profileId,
          accountId: creditCardAccountId,
          chequeBookId: bookId,
          chequeNumber: '000501',
          amount: Money.fromMinorUnits(100, 'USD'),
          payeeName: 'A',
          issueDateUtc: DateTime.utc(2026, 9, 1),
        ),
        throwsA(isA<ChequeValidationException>()),
      );
    });

    test('13. rejects a chequebook that belongs to a DIFFERENT account', () async {
      final String accountA = await seedBankAccount();
      final String accountB = await seedBankAccount();
      final String bookForA = await chequeBookRepo.createChequeBook(
        profileId: profileId,
        accountId: accountA,
        label: 'Book for A',
      );
      expect(
        () => chequeRepo.recordIssued(
          profileId: profileId,
          accountId: accountB,
          chequeBookId: bookForA,
          chequeNumber: '000600',
          amount: Money.fromMinorUnits(100, 'USD'),
          payeeName: 'A',
          issueDateUtc: DateTime.utc(2026, 9, 1),
        ),
        throwsA(isA<ChequeValidationException>()),
      );
    });

    test('14. rejects a closed chequebook', () async {
      final String accountId = await seedBankAccount();
      final String bookId = await chequeBookRepo.createChequeBook(
        profileId: profileId,
        accountId: accountId,
        label: 'Book',
      );
      await chequeBookRepo.closeChequeBook(bookId);
      expect(
        () => chequeRepo.recordIssued(
          profileId: profileId,
          accountId: accountId,
          chequeBookId: bookId,
          chequeNumber: '000700',
          amount: Money.fromMinorUnits(100, 'USD'),
          payeeName: 'A',
          issueDateUtc: DateTime.utc(2026, 9, 1),
        ),
        throwsA(isA<ChequeBookNotFoundException>()),
      );
    });
  });

  group('ChequeRepository.recordReceived', () {
    test('15. creates a pending received cheque with NO Transactions row', () async {
      final String accountId = await seedBankAccount();
      final String chequeId = await chequeRepo.recordReceived(
        profileId: profileId,
        accountId: accountId,
        chequeNumber: '5551',
        amount: Money.fromMinorUnits(9900, 'USD'),
        payerName: 'Client Co',
        issueDateUtc: DateTime.utc(2026, 9, 1),
        receivedDateUtc: DateTime.utc(2026, 9, 2),
      );
      final ChequeRow row = await chequeRepo.requireById(chequeId);
      expect(row.statusValue, ChequeStatus.pending);
      expect(row.directionValue, ChequeDirection.received);
      expect(row.chequeBookId, isNull);
      // `row.receivedDate` comes back local-tagged (Drift's default
      // non-text DateTime column behavior -- see
      // `transaction_repository_test.dart`'s identical, already-
      // established convention), so a direct `==` against a UTC-tagged
      // `DateTime.utc(...)` compares tags, not the instant;
      // `isAtSameMomentAs` is the tag-agnostic comparison Dart provides
      // for exactly this.
      expect(row.receivedDate!.isAtSameMomentAs(DateTime.utc(2026, 9, 2)), isTrue);
      expect((await ledgerFor(profileId)), isEmpty);
    });

    test('16. allows a DUPLICATE cheque number across two received cheques', () async {
      final String accountId = await seedBankAccount();
      await chequeRepo.recordReceived(
        profileId: profileId,
        accountId: accountId,
        chequeNumber: '1001',
        amount: Money.fromMinorUnits(100, 'USD'),
        payerName: 'Payer A',
        issueDateUtc: DateTime.utc(2026, 9, 1),
        receivedDateUtc: DateTime.utc(2026, 9, 1),
      );
      // Does not throw -- received cheques have no uniqueness scope.
      await chequeRepo.recordReceived(
        profileId: profileId,
        accountId: accountId,
        chequeNumber: '1001',
        amount: Money.fromMinorUnits(500, 'USD'),
        payerName: 'Payer B',
        issueDateUtc: DateTime.utc(2026, 9, 3),
        receivedDateUtc: DateTime.utc(2026, 9, 3),
      );
    });

    test('17. rejects a currency mismatch against the deposit account', () async {
      final String accountId = await seedBankAccount();
      expect(
        () => chequeRepo.recordReceived(
          profileId: profileId,
          accountId: accountId,
          chequeNumber: '1002',
          amount: Money.fromMinorUnits(100, 'JPY'),
          payerName: 'Payer',
          issueDateUtc: DateTime.utc(2026, 9, 1),
          receivedDateUtc: DateTime.utc(2026, 9, 1),
        ),
        throwsA(isA<CurrencyMismatchException>()),
      );
    });
  });

  group('ChequeRepository lifecycle transitions', () {
    Future<String> issueOneCheque({
      required String accountId,
      String chequeNumber = '000900',
      int amountMinorUnits = 10000,
    }) async {
      final String bookId = await chequeBookRepo.createChequeBook(
        profileId: profileId,
        accountId: accountId,
        label: 'Book',
      );
      return chequeRepo.recordIssued(
        profileId: profileId,
        accountId: accountId,
        chequeBookId: bookId,
        chequeNumber: chequeNumber,
        amount: Money.fromMinorUnits(amountMinorUnits, 'USD'),
        payeeName: 'Payee',
        issueDateUtc: DateTime.utc(2026, 9, 1),
      );
    }

    test('18. markCleared posts exactly one expense transaction for an issued cheque', () async {
      final String accountId = await seedBankAccount(
        openingBalance: Money.fromMinorUnits(100000, 'USD'),
      );
      final String chequeId = await issueOneCheque(accountId: accountId, amountMinorUnits: 25000);

      final String transactionId = await chequeRepo.markCleared(
        chequeId: chequeId,
        clearedDateUtc: DateTime.utc(2026, 9, 5),
      );

      final ChequeRow row = await chequeRepo.requireById(chequeId);
      expect(row.statusValue, ChequeStatus.cleared);
      expect(row.transactionId, transactionId);
      // See test 15's own comment above for why this is
      // `isAtSameMomentAs`, not a direct `==`, against a UTC-tagged
      // literal.
      expect(row.clearedDate!.isAtSameMomentAs(DateTime.utc(2026, 9, 5)), isTrue);

      final List<LedgerTransaction> ledger = await ledgerFor(profileId);
      expect(ledger, hasLength(1));
      expect(ledger.single.id, transactionId);
      expect(ledger.single.type.name, 'expense');
      expect(ledger.single.amount, Money.fromMinorUnits(25000, 'USD'));
    });

    test('19. markCleared posts exactly one income transaction for a received cheque', () async {
      final String accountId = await seedBankAccount();
      final String chequeId = await chequeRepo.recordReceived(
        profileId: profileId,
        accountId: accountId,
        chequeNumber: '2002',
        amount: Money.fromMinorUnits(30000, 'USD'),
        payerName: 'Payer',
        issueDateUtc: DateTime.utc(2026, 9, 1),
        receivedDateUtc: DateTime.utc(2026, 9, 1),
      );

      final String transactionId = await chequeRepo.markCleared(
        chequeId: chequeId,
        clearedDateUtc: DateTime.utc(2026, 9, 6),
      );

      final List<LedgerTransaction> ledger = await ledgerFor(profileId);
      expect(ledger, hasLength(1));
      expect(ledger.single.id, transactionId);
      expect(ledger.single.type.name, 'income');
      expect(ledger.single.amount, Money.fromMinorUnits(30000, 'USD'));
    });

    test(
      '20. calling markCleared TWICE on the same cheque throws on the second call and never '
      'posts a second transaction (idempotency)',
      () async {
        final String accountId = await seedBankAccount();
        final String chequeId = await issueOneCheque(accountId: accountId);

        await chequeRepo.markCleared(chequeId: chequeId, clearedDateUtc: DateTime.utc(2026, 9, 5));
        expect(
          () => chequeRepo.markCleared(chequeId: chequeId, clearedDateUtc: DateTime.utc(2026, 9, 6)),
          throwsA(isA<ChequeLifecycleException>()),
        );

        final List<LedgerTransaction> ledger = await ledgerFor(profileId);
        expect(ledger, hasLength(1));
      },
    );

    test('21. markBounced transitions to bounced and posts NO transaction', () async {
      final String accountId = await seedBankAccount();
      final String chequeId = await issueOneCheque(accountId: accountId);

      await chequeRepo.markBounced(chequeId: chequeId, bouncedDateUtc: DateTime.utc(2026, 9, 4));

      final ChequeRow row = await chequeRepo.requireById(chequeId);
      expect(row.statusValue, ChequeStatus.bounced);
      expect(row.transactionId, isNull);
      expect((await ledgerFor(profileId)), isEmpty);
    });

    test('22. cannot bounce an already-cleared cheque', () async {
      final String accountId = await seedBankAccount();
      final String chequeId = await issueOneCheque(accountId: accountId);
      await chequeRepo.markCleared(chequeId: chequeId, clearedDateUtc: DateTime.utc(2026, 9, 5));

      expect(
        () => chequeRepo.markBounced(chequeId: chequeId, bouncedDateUtc: DateTime.utc(2026, 9, 6)),
        throwsA(isA<ChequeLifecycleException>()),
      );
    });

    test('23. cannot clear an already-bounced cheque', () async {
      final String accountId = await seedBankAccount();
      final String chequeId = await issueOneCheque(accountId: accountId);
      await chequeRepo.markBounced(chequeId: chequeId, bouncedDateUtc: DateTime.utc(2026, 9, 4));

      expect(
        () => chequeRepo.markCleared(chequeId: chequeId, clearedDateUtc: DateTime.utc(2026, 9, 6)),
        throwsA(isA<ChequeLifecycleException>()),
      );
    });

    test('24. markStopped transitions an issued cheque and posts NO transaction', () async {
      final String accountId = await seedBankAccount();
      final String chequeId = await issueOneCheque(accountId: accountId);

      await chequeRepo.markStopped(chequeId: chequeId, stoppedDateUtc: DateTime.utc(2026, 9, 3));

      final ChequeRow row = await chequeRepo.requireById(chequeId);
      expect(row.statusValue, ChequeStatus.stopped);
      expect(row.transactionId, isNull);
      expect((await ledgerFor(profileId)), isEmpty);
    });

    test('25. cannot stop a RECEIVED cheque', () async {
      final String accountId = await seedBankAccount();
      final String chequeId = await chequeRepo.recordReceived(
        profileId: profileId,
        accountId: accountId,
        chequeNumber: '3003',
        amount: Money.fromMinorUnits(100, 'USD'),
        payerName: 'Payer',
        issueDateUtc: DateTime.utc(2026, 9, 1),
        receivedDateUtc: DateTime.utc(2026, 9, 1),
      );

      expect(
        () => chequeRepo.markStopped(chequeId: chequeId, stoppedDateUtc: DateTime.utc(2026, 9, 2)),
        throwsA(isA<ChequeLifecycleException>()),
      );
    });

    test('26. cannot stop an already-cleared cheque', () async {
      final String accountId = await seedBankAccount();
      final String chequeId = await issueOneCheque(accountId: accountId);
      await chequeRepo.markCleared(chequeId: chequeId, clearedDateUtc: DateTime.utc(2026, 9, 5));

      expect(
        () => chequeRepo.markStopped(chequeId: chequeId, stoppedDateUtc: DateTime.utc(2026, 9, 6)),
        throwsA(isA<ChequeLifecycleException>()),
      );
    });

    test('27. markCancelled works for an issued cheque', () async {
      final String accountId = await seedBankAccount();
      final String chequeId = await issueOneCheque(accountId: accountId);
      await chequeRepo.markCancelled(chequeId: chequeId, cancelledDateUtc: DateTime.utc(2026, 9, 2));
      expect((await chequeRepo.requireById(chequeId)).statusValue, ChequeStatus.cancelled);
    });

    test('28. markCancelled works for a received cheque', () async {
      final String accountId = await seedBankAccount();
      final String chequeId = await chequeRepo.recordReceived(
        profileId: profileId,
        accountId: accountId,
        chequeNumber: '4004',
        amount: Money.fromMinorUnits(100, 'USD'),
        payerName: 'Payer',
        issueDateUtc: DateTime.utc(2026, 9, 1),
        receivedDateUtc: DateTime.utc(2026, 9, 1),
      );
      await chequeRepo.markCancelled(chequeId: chequeId, cancelledDateUtc: DateTime.utc(2026, 9, 2));
      expect((await chequeRepo.requireById(chequeId)).statusValue, ChequeStatus.cancelled);
    });

    test('29. cannot cancel an already-cleared cheque', () async {
      final String accountId = await seedBankAccount();
      final String chequeId = await issueOneCheque(accountId: accountId);
      await chequeRepo.markCleared(chequeId: chequeId, clearedDateUtc: DateTime.utc(2026, 9, 5));

      expect(
        () =>
            chequeRepo.markCancelled(chequeId: chequeId, cancelledDateUtc: DateTime.utc(2026, 9, 6)),
        throwsA(isA<ChequeLifecycleException>()),
      );
    });

    test('30. deletePending soft-deletes a still-pending cheque', () async {
      final String accountId = await seedBankAccount();
      final String chequeId = await issueOneCheque(accountId: accountId);
      await chequeRepo.deletePending(chequeId);
      expect(() => chequeRepo.requireById(chequeId), throwsA(isA<ChequeNotFoundException>()));
    });

    test('31. cannot delete an already-cleared cheque', () async {
      final String accountId = await seedBankAccount();
      final String chequeId = await issueOneCheque(accountId: accountId);
      await chequeRepo.markCleared(chequeId: chequeId, clearedDateUtc: DateTime.utc(2026, 9, 5));

      expect(
        () => chequeRepo.deletePending(chequeId),
        throwsA(isA<ChequeLifecycleException>()),
      );
    });
  });

  group('Accounting invariants (FinanceEngine)', () {
    test(
      '32. a PENDING issued cheque does not reduce the drawing account\'s cleared balance',
      () async {
        final String accountId = await seedBankAccount(
          openingBalance: Money.fromMinorUnits(100000, 'USD'),
        );
        await issueOneChequeHelper(
          chequeBookRepo: chequeBookRepo,
          chequeRepo: chequeRepo,
          profileId: profileId,
          accountId: accountId,
          amountMinorUnits: 25000,
        );

        final AccountRow account = await accountRepo.requireById(accountId);
        final Money balance =
            FinanceEngine.accountBalance(account.toLedgerAccount(), await ledgerFor(profileId));
        expect(balance, Money.fromMinorUnits(100000, 'USD'));
      },
    );

    test('33. clearing an issued cheque reduces the balance by exactly its amount', () async {
      final String accountId = await seedBankAccount(
        openingBalance: Money.fromMinorUnits(100000, 'USD'),
      );
      final String chequeId = await issueOneChequeHelper(
        chequeBookRepo: chequeBookRepo,
        chequeRepo: chequeRepo,
        profileId: profileId,
        accountId: accountId,
        amountMinorUnits: 25000,
      );
      await chequeRepo.markCleared(chequeId: chequeId, clearedDateUtc: DateTime.utc(2026, 9, 5));

      final AccountRow account = await accountRepo.requireById(accountId);
      final Money balance =
          FinanceEngine.accountBalance(account.toLedgerAccount(), await ledgerFor(profileId));
      expect(balance, Money.fromMinorUnits(75000, 'USD'));
    });

    test(
      '34. a PENDING received cheque does not increase the deposit account\'s cleared balance',
      () async {
        final String accountId = await seedBankAccount(
          openingBalance: Money.fromMinorUnits(50000, 'USD'),
        );
        await chequeRepo.recordReceived(
          profileId: profileId,
          accountId: accountId,
          chequeNumber: '6006',
          amount: Money.fromMinorUnits(20000, 'USD'),
          payerName: 'Payer',
          issueDateUtc: DateTime.utc(2026, 9, 1),
          receivedDateUtc: DateTime.utc(2026, 9, 1),
        );

        final AccountRow account = await accountRepo.requireById(accountId);
        final Money balance =
            FinanceEngine.accountBalance(account.toLedgerAccount(), await ledgerFor(profileId));
        expect(balance, Money.fromMinorUnits(50000, 'USD'));
      },
    );

    test('35. clearing a received cheque increases the balance by exactly its amount', () async {
      final String accountId = await seedBankAccount(
        openingBalance: Money.fromMinorUnits(50000, 'USD'),
      );
      final String chequeId = await chequeRepo.recordReceived(
        profileId: profileId,
        accountId: accountId,
        chequeNumber: '7007',
        amount: Money.fromMinorUnits(20000, 'USD'),
        payerName: 'Payer',
        issueDateUtc: DateTime.utc(2026, 9, 1),
        receivedDateUtc: DateTime.utc(2026, 9, 1),
      );
      await chequeRepo.markCleared(chequeId: chequeId, clearedDateUtc: DateTime.utc(2026, 9, 6));

      final AccountRow account = await accountRepo.requireById(accountId);
      final Money balance =
          FinanceEngine.accountBalance(account.toLedgerAccount(), await ledgerFor(profileId));
      expect(balance, Money.fromMinorUnits(70000, 'USD'));
    });

    test('36. a bounced issued cheque never affects the account balance', () async {
      final String accountId = await seedBankAccount(
        openingBalance: Money.fromMinorUnits(100000, 'USD'),
      );
      final String chequeId = await issueOneChequeHelper(
        chequeBookRepo: chequeBookRepo,
        chequeRepo: chequeRepo,
        profileId: profileId,
        accountId: accountId,
        amountMinorUnits: 25000,
      );
      await chequeRepo.markBounced(chequeId: chequeId, bouncedDateUtc: DateTime.utc(2026, 9, 4));

      final AccountRow account = await accountRepo.requireById(accountId);
      final Money balance =
          FinanceEngine.accountBalance(account.toLedgerAccount(), await ledgerFor(profileId));
      expect(balance, Money.fromMinorUnits(100000, 'USD'));
    });

    test('37. a stopped issued cheque never affects the account balance', () async {
      final String accountId = await seedBankAccount(
        openingBalance: Money.fromMinorUnits(100000, 'USD'),
      );
      final String chequeId = await issueOneChequeHelper(
        chequeBookRepo: chequeBookRepo,
        chequeRepo: chequeRepo,
        profileId: profileId,
        accountId: accountId,
        amountMinorUnits: 25000,
      );
      await chequeRepo.markStopped(chequeId: chequeId, stoppedDateUtc: DateTime.utc(2026, 9, 3));

      final AccountRow account = await accountRepo.requireById(accountId);
      final Money balance =
          FinanceEngine.accountBalance(account.toLedgerAccount(), await ledgerFor(profileId));
      expect(balance, Money.fromMinorUnits(100000, 'USD'));
    });
  });
}

/// Shared by the accounting-invariant tests above -- issues one cheque
/// against a fresh chequebook on [accountId] and returns its id.
Future<String> issueOneChequeHelper({
  required ChequeBookRepository chequeBookRepo,
  required ChequeRepository chequeRepo,
  required String profileId,
  required String accountId,
  required int amountMinorUnits,
}) async {
  final String bookId = await chequeBookRepo.createChequeBook(
    profileId: profileId,
    accountId: accountId,
    label: 'Book',
  );
  return chequeRepo.recordIssued(
    profileId: profileId,
    accountId: accountId,
    chequeBookId: bookId,
    chequeNumber: '00${amountMinorUnits % 1000}',
    amount: Money.fromMinorUnits(amountMinorUnits, 'USD'),
    payeeName: 'Payee',
    issueDateUtc: DateTime.utc(2026, 9, 1),
  );
}
