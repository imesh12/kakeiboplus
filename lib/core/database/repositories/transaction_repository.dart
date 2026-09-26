import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../finance/cheque_status.dart';
import '../../finance/ledger_models.dart';
import '../../finance/transaction_type.dart';
import '../../money/currency_mismatch_exception.dart';
import '../../money/money.dart';
import '../app_database.dart';
import '../../finance/payment_instrument_type.dart';
import 'account_repository.dart';
import 'invalid_payment_instrument_attribution_exception.dart';
import 'transaction_linked_to_cheque_exception.dart';
import 'transaction_not_found_exception.dart';

/// The repository behind the entire Beta 0 transaction ledger: recording
/// expenses, income, and transfers, and reading them back both as raw
/// Drift rows (for the Activity screen) and as pure [LedgerTransaction]s
/// (for [FinanceEngine]).
///
/// Depends on [AccountRepository] (constructor-injected, not looked up
/// per call) so [recordTransfer] can validate that both accounts share a
/// currency — see ADR-019 (`docs/14_DECISION_LOG.md`): Beta 0 rejects a
/// cross-currency transfer here, at the domain/service layer, in
/// addition to whatever the UI form also checks. Never rely on the UI
/// layer alone for this rule.
class TransactionRepository {
  TransactionRepository(this._db, this._accountRepository);

  final AppDatabase _db;
  final AccountRepository _accountRepository;
  static const Uuid _uuid = Uuid();

  LedgerTransaction _toLedger(Transaction row) {
    return LedgerTransaction(
      id: row.id,
      accountId: row.accountId,
      destinationAccountId: row.destinationAccountId,
      type: TransactionType.values.byName(row.type),
      amount: Money.fromMinorUnits(row.amountMinorUnits, row.currencyCode),
      categoryId: row.categoryId,
      occurredAtUtc: row.occurredAt,
      isDeleted: row.deletedAt != null,
    );
  }

  /// All (including soft-deleted) transactions for [profileId], mapped to
  /// the pure-Dart shape [FinanceEngine] consumes. [FinanceEngine]
  /// itself is what excludes deleted rows from any computed
  /// total/balance — see `lib/core/finance/finance_engine.dart`.
  Stream<List<LedgerTransaction>> watchLedgerForProfile(String profileId) {
    final query = _db.select(_db.transactions)..where((tbl) => tbl.profileId.equals(profileId));
    return query.watch().map((rows) => rows.map(_toLedger).toList(growable: false));
  }

  /// Active (non-deleted) transactions as raw rows, newest first — for
  /// the Activity/history screen, which wants `note`/`categoryId`/etc.
  /// directly rather than the finance-engine-shaped view.
  Stream<List<Transaction>> watchActiveForProfile(String profileId) {
    final query = _db.select(_db.transactions)
      ..where((tbl) => tbl.profileId.equals(profileId) & tbl.deletedAt.isNull())
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.occurredAt)]);
    return query.watch();
  }

  Stream<List<Transaction>> watchActiveForAccount(String accountId) {
    final query = _db.select(_db.transactions)
      ..where(
        (tbl) =>
            (tbl.accountId.equals(accountId) | tbl.destinationAccountId.equals(accountId)) &
            tbl.deletedAt.isNull(),
      )
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.occurredAt)]);
    return query.watch();
  }

  /// [paymentInstrumentId], when supplied, must name an active payment
  /// instrument linked to [accountId] and owned by [profileId] -- see
  /// `PaymentInstrumentRepository`'s own doc and
  /// [InvalidPaymentInstrumentAttributionException]. Purely metadata:
  /// has ZERO effect on this expense's accounting (see
  /// `lib/core/finance/finance_engine.dart`).
  Future<String> recordExpense({
    required String profileId,
    required String accountId,
    required Money amount,
    String? categoryId,
    String? note,
    required DateTime occurredAtUtc,
    String? paymentInstrumentId,
  }) {
    return _insert(
      profileId: profileId,
      accountId: accountId,
      type: TransactionType.expense,
      amount: amount,
      categoryId: categoryId,
      note: note,
      occurredAtUtc: occurredAtUtc,
      paymentInstrumentId: paymentInstrumentId,
    );
  }

  /// See [recordExpense]'s own doc for [paymentInstrumentId]'s
  /// validation and zero-accounting-effect rules -- identical here.
  Future<String> recordIncome({
    required String profileId,
    required String accountId,
    required Money amount,
    String? categoryId,
    String? note,
    required DateTime occurredAtUtc,
    String? paymentInstrumentId,
  }) {
    return _insert(
      profileId: profileId,
      accountId: accountId,
      type: TransactionType.income,
      amount: amount,
      categoryId: categoryId,
      note: note,
      occurredAtUtc: occurredAtUtc,
      paymentInstrumentId: paymentInstrumentId,
    );
  }

  /// Records a transfer between two of the user's own accounts.
  ///
  /// **Release gate (ADR-019):** rejects the transfer with
  /// [CurrencyMismatchException] if the source and destination accounts
  /// don't share a currency, or if [amount]'s currency doesn't match
  /// them. This check happens here — independent of whatever the UI form
  /// already validated — so the rule holds even if a future screen or a
  /// bug skips the form-level check.
  ///
  /// [paymentInstrumentId], when supplied, represents the SOURCE payment
  /// instrument (V1 has no separate destination-instrument concept --
  /// see `Transactions.paymentInstrumentId`'s own doc) and must be
  /// linked to [sourceAccountId]. Purely metadata; see [recordExpense]'s
  /// own doc for the shared validation/zero-accounting-effect rules.
  Future<String> recordTransfer({
    required String profileId,
    required String sourceAccountId,
    required String destinationAccountId,
    required Money amount,
    String? note,
    required DateTime occurredAtUtc,
    String? paymentInstrumentId,
  }) async {
    if (sourceAccountId == destinationAccountId) {
      throw ArgumentError('Source and destination accounts must be different.');
    }
    final AccountRow source = await _accountRepository.requireById(sourceAccountId);
    final AccountRow destination = await _accountRepository.requireById(destinationAccountId);

    if (source.currencyCode != destination.currencyCode) {
      throw CurrencyMismatchException(source.currencyCode, destination.currencyCode);
    }
    if (amount.currencyCode != source.currencyCode) {
      throw CurrencyMismatchException(source.currencyCode, amount.currencyCode);
    }

    return _insert(
      profileId: profileId,
      accountId: sourceAccountId,
      destinationAccountId: destinationAccountId,
      type: TransactionType.transfer,
      amount: amount,
      categoryId: null, // transfers are never categorized — see FinanceEngine
      note: note,
      occurredAtUtc: occurredAtUtc,
      paymentInstrumentId: paymentInstrumentId,
    );
  }

  /// Checkpoint N: throws [TransactionLinkedToChequeException] rather
  /// than soft-deleting [id] if a cleared cheque's `transactionId`
  /// names it -- see [_requireNotChequeLinked]'s own doc. The guard
  /// check and the write happen inside the same
  /// `AppDatabase.transaction` block so a concurrent clear/soft-delete
  /// cannot race between them.
  Future<void> softDelete(String id) {
    return _db.transaction(() async {
      await _requireNotChequeLinked(id);
      await (_db.update(_db.transactions)..where((tbl) => tbl.id.equals(id))).write(
        TransactionsCompanion(
          deletedAt: Value<DateTime?>(DateTime.now().toUtc()),
          updatedAt: Value<DateTime>(DateTime.now().toUtc()),
        ),
      );
    });
  }

  /// One transaction by id, reactively -- `null` once it's soft-deleted
  /// or if it never existed, the same "unavailable below the UI layer"
  /// convention `SavingsGoalRepository`'s goal-detail lookup already
  /// uses. What the transaction detail/edit screens watch.
  Stream<Transaction?> watchById(String id) {
    final query = _db.select(_db.transactions)
      ..where((tbl) => tbl.id.equals(id) & tbl.deletedAt.isNull());
    return query.watchSingleOrNull();
  }

  /// Updates an existing expense's editable fields. **Never changes
  /// [id]/`type`** -- editing may not turn an expense into an income or
  /// transfer (see `docs/14_DECISION_LOG.md` ADR-025); switching type is
  /// deliberately unsupported here and always requires deleting and
  /// recreating instead.
  ///
  /// [accountId] may name a different account than the transaction
  /// currently has, but [amount] must already be denominated in that
  /// account's currency -- **this never relabels or converts money**.
  /// If [accountId]'s account is a different currency than [amount],
  /// this throws [CurrencyMismatchException] rather than silently
  /// reinterpreting the same minor units under a new currency code. The
  /// caller (the edit form) is responsible for re-parsing/revalidating
  /// the displayed amount under the newly selected account's currency
  /// before ever calling this -- see `MoneyTextField`.
  Future<void> updateExpense({
    required String id,
    required String accountId,
    required Money amount,
    String? categoryId,
    String? note,
    required DateTime occurredAtUtc,
  }) {
    return _updateExpenseOrIncome(
      id: id,
      type: TransactionType.expense,
      accountId: accountId,
      amount: amount,
      categoryId: categoryId,
      note: note,
      occurredAtUtc: occurredAtUtc,
    );
  }

  /// Updates an existing income's editable fields. See [updateExpense]
  /// for the shared type-immutability and currency rules -- the only
  /// difference is the transaction stays an income, never an expense.
  Future<void> updateIncome({
    required String id,
    required String accountId,
    required Money amount,
    String? categoryId,
    String? note,
    required DateTime occurredAtUtc,
  }) {
    return _updateExpenseOrIncome(
      id: id,
      type: TransactionType.income,
      accountId: accountId,
      amount: amount,
      categoryId: categoryId,
      note: note,
      occurredAtUtc: occurredAtUtc,
    );
  }

  Future<void> _updateExpenseOrIncome({
    required String id,
    required TransactionType type,
    required String accountId,
    required Money amount,
    String? categoryId,
    String? note,
    required DateTime occurredAtUtc,
  }) {
    // Checkpoint N: the existence/type check, the cheque-link guard,
    // and the write all happen inside one `AppDatabase.transaction`
    // block -- see [_requireNotChequeLinked]'s own doc -- so nothing
    // can clear a cheque against this same row in the gap between the
    // guard check and the write.
    return _db.transaction(() async {
      final Transaction existing = await _requireEditableById(id);
      if (existing.type != type.name) {
        throw ArgumentError(
          'Transaction $id is currently a ${existing.type}, not ${type.name} -- '
          'transaction type cannot change on edit.',
        );
      }
      await _requireNotChequeLinked(id);
      if (!amount.isPositive) {
        throw ArgumentError.value(amount, 'amount', 'Transaction amount must be positive.');
      }

      // Correction (ADR-025): the selected account's currency is
      // authoritative for what gets PERSISTED, but money is never
      // relabeled -- amount must already be in that currency, or this is
      // rejected. There is no FX conversion in this task.
      final AccountRow account = await _accountRepository.requireById(accountId);
      if (amount.currencyCode != account.currencyCode) {
        throw CurrencyMismatchException(account.currencyCode, amount.currencyCode);
      }

      // Race safety: the WHERE clause re-asserts the row is still active
      // and still the expected type at the moment of the write itself,
      // not just at the earlier read above -- see `_requireEditableById`
      // and ADR-025. A rowsAffected of anything other than 1 means the
      // row was deleted (or, unreachably in this app's single-writer
      // model, changed type) between the read and this write; either way
      // this must fail loudly rather than report success.
      final int rowsAffected = await (_db.update(_db.transactions)
            ..where(
              (tbl) => tbl.id.equals(id) & tbl.deletedAt.isNull() & tbl.type.equals(type.name),
            ))
          .write(
        TransactionsCompanion(
          accountId: Value<String>(accountId),
          amountMinorUnits: Value<int>(amount.minorUnits),
          currencyCode: Value<String>(account.currencyCode),
          categoryId: Value<String?>(categoryId),
          note: Value<String?>(note),
          occurredAt: Value<DateTime>(occurredAtUtc),
          updatedAt: Value<DateTime>(DateTime.now().toUtc()),
        ),
      );
      if (rowsAffected != 1) {
        throw TransactionNotFoundException(id);
      }
    });
  }

  /// Updates an existing transfer's editable fields. **Never changes
  /// [id]/`type`**, and deliberately has no `categoryId` parameter at
  /// all -- transfers are never categorized (see [recordTransfer]), and
  /// this API shape makes that impossible for a caller to violate rather
  /// than relying on a convention. `categoryId` is always persisted as
  /// `null`.
  ///
  /// Re-runs every check [recordTransfer] runs, against the (possibly
  /// new) account ids: source != destination, both accounts share a
  /// currency, and [amount] is already denominated in that currency --
  /// no relabeling, no conversion.
  Future<void> updateTransfer({
    required String id,
    required String sourceAccountId,
    required String destinationAccountId,
    required Money amount,
    String? note,
    required DateTime occurredAtUtc,
  }) {
    // Checkpoint N: see [_updateExpenseOrIncome]'s own doc for why the
    // existence/type check, the cheque-link guard, and the write all
    // run inside one `AppDatabase.transaction` block here too -- a
    // cheque-generated transaction should never normally be a
    // transfer (`ChequeRepository.markCleared` only ever calls
    // `recordExpense`/`recordIncome`), but this path is guarded
    // identically rather than relying on that never happening.
    return _db.transaction(() async {
      final Transaction existing = await _requireEditableById(id);
      if (existing.type != TransactionType.transfer.name) {
        throw ArgumentError(
          'Transaction $id is currently a ${existing.type}, not transfer -- '
          'transaction type cannot change on edit.',
        );
      }
      await _requireNotChequeLinked(id);
      if (!amount.isPositive) {
        throw ArgumentError.value(amount, 'amount', 'Transaction amount must be positive.');
      }
      if (sourceAccountId == destinationAccountId) {
        throw ArgumentError('Source and destination accounts must be different.');
      }
      final AccountRow source = await _accountRepository.requireById(sourceAccountId);
      final AccountRow destination = await _accountRepository.requireById(destinationAccountId);
      if (source.currencyCode != destination.currencyCode) {
        throw CurrencyMismatchException(source.currencyCode, destination.currencyCode);
      }
      if (amount.currencyCode != source.currencyCode) {
        throw CurrencyMismatchException(source.currencyCode, amount.currencyCode);
      }

      final int rowsAffected = await (_db.update(_db.transactions)
            ..where(
              (tbl) =>
                  tbl.id.equals(id) &
                  tbl.deletedAt.isNull() &
                  tbl.type.equals(TransactionType.transfer.name),
            ))
          .write(
        TransactionsCompanion(
          accountId: Value<String>(sourceAccountId),
          destinationAccountId: Value<String?>(destinationAccountId),
          amountMinorUnits: Value<int>(amount.minorUnits),
          currencyCode: Value<String>(source.currencyCode),
          categoryId: const Value<String?>(null), // transfers are never categorized
          note: Value<String?>(note),
          occurredAt: Value<DateTime>(occurredAtUtc),
          updatedAt: Value<DateTime>(DateTime.now().toUtc()),
        ),
      );
      if (rowsAffected != 1) {
        throw TransactionNotFoundException(id);
      }
    });
  }

  Future<Transaction> _requireEditableById(String id) async {
    final Transaction? row =
        await (_db.select(_db.transactions)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
    if (row == null || row.deletedAt != null) {
      throw TransactionNotFoundException(id);
    }
    return row;
  }

  /// Checkpoint N integrity repair: throws
  /// [TransactionLinkedToChequeException] if [id] is the
  /// `Transactions` row a CLEARED cheque's `transactionId` names --
  /// see `Cheques.transactionId`'s own doc. Called from every
  /// existing mutation path that can materially alter or remove an
  /// existing row (`softDelete`, `_updateExpenseOrIncome`,
  /// `updateTransfer`), always from INSIDE the same
  /// `AppDatabase.transaction` block that then performs the write, so
  /// nothing can clear a cheque against [id] in the gap between this
  /// check and that write.
  ///
  /// Queries `cheques` directly rather than depending on a
  /// `ChequeRepository` instance -- see this file's own
  /// `_validatePaymentInstrumentAttribution` precedent for
  /// `payment_instruments`, and
  /// [TransactionLinkedToChequeException]'s own doc for why a real
  /// constructor dependency here would additionally be circular
  /// (`ChequeRepository` depends on `TransactionRepository`, not the
  /// other way around).
  ///
  /// Deliberately does **not** filter on `Cheques.deletedAt`: V1's
  /// `ChequeRepository.deletePending` can only ever soft-delete a
  /// still-[ChequeStatus.pending] cheque (one with no linked
  /// `transactionId` to begin with -- see that method's own doc), so a
  /// cleared cheque is never itself soft-deleted in practice today.
  /// Even so, this check keys off [ChequeStatus.cleared] alone rather
  /// than additionally requiring `deletedAt IS NULL`, so that if a
  /// cleared-and-linked cheque row were ever soft-deleted by some
  /// future change, its linked transaction would still remain
  /// protected rather than silently losing that protection --
  /// preserving historical accounting integrity takes priority over
  /// a soft-deleted cheque row's own visibility.
  Future<void> _requireNotChequeLinked(String id) async {
    final ChequeRow? linkedCheque = await (_db.select(_db.cheques)
          ..where(
            (tbl) =>
                tbl.transactionId.equals(id) & tbl.status.equals(ChequeStatus.cleared.name),
          ))
        .getSingleOrNull();
    if (linkedCheque != null) {
      throw TransactionLinkedToChequeException(transactionId: id, chequeId: linkedCheque.id);
    }
  }

  Future<String> _insert({
    required String profileId,
    required String accountId,
    String? destinationAccountId,
    required TransactionType type,
    required Money amount,
    String? categoryId,
    String? note,
    required DateTime occurredAtUtc,
    String? paymentInstrumentId,
  }) async {
    if (!amount.isPositive) {
      throw ArgumentError.value(amount, 'amount', 'Transaction amount must be positive.');
    }
    if (paymentInstrumentId != null) {
      await _validatePaymentInstrumentAttribution(
        paymentInstrumentId: paymentInstrumentId,
        profileId: profileId,
        accountId: accountId,
      );
    }
    final String id = _uuid.v4();
    final DateTime now = DateTime.now().toUtc();
    await _db.into(_db.transactions).insert(
          TransactionsCompanion.insert(
            id: id,
            profileId: profileId,
            accountId: accountId,
            destinationAccountId: Value<String?>(destinationAccountId),
            type: type.name,
            amountMinorUnits: amount.minorUnits,
            currencyCode: amount.currencyCode,
            categoryId: Value<String?>(categoryId),
            note: Value<String?>(note),
            occurredAt: occurredAtUtc,
            createdAt: now,
            updatedAt: now,
            paymentInstrumentId: Value<String?>(paymentInstrumentId),
            // syncVersion / syncStatus deliberately left at their column
            // defaults (0 / "localOnly" — ADR-020); Beta 0 never sets
            // them explicitly.
          ),
        );
    return id;
  }

  /// Checkpoint D: validates [paymentInstrumentId] against the V1
  /// source-attribution rule -- see `Transactions.paymentInstrumentId`'s
  /// own doc and [InvalidPaymentInstrumentAttributionException]. Queries
  /// `payment_instruments` directly (rather than depending on a
  /// `PaymentInstrumentRepository` instance) so this repository's
  /// constructor -- and every one of its ~50 existing call sites across
  /// the app and test suite -- does not need to change for this
  /// checkpoint; see the Checkpoint D report for why a constructor
  /// change was deliberately avoided.
  Future<void> _validatePaymentInstrumentAttribution({
    required String paymentInstrumentId,
    required String profileId,
    required String accountId,
  }) async {
    final PaymentInstrumentRow? instrument = await (_db.select(_db.paymentInstruments)
          ..where((tbl) => tbl.id.equals(paymentInstrumentId)))
        .getSingleOrNull();
    if (instrument == null || instrument.deletedAt != null) {
      throw InvalidPaymentInstrumentAttributionException(
        paymentInstrumentId,
        'instrument does not exist or is archived — a new transaction cannot be '
        'attributed to a missing or archived instrument',
      );
    }
    if (instrument.profileId != profileId) {
      throw InvalidPaymentInstrumentAttributionException(
        paymentInstrumentId,
        'instrument belongs to profile ${instrument.profileId}, not $profileId',
      );
    }
    if (instrument.accountId != accountId) {
      throw InvalidPaymentInstrumentAttributionException(
        paymentInstrumentId,
        'instrument is linked to account ${instrument.accountId}, not this '
        "transaction's account $accountId -- V1 source-attribution rule requires "
        'them to match',
      );
    }

    // Checkpoint E: a liability-account purchase may only be attributed
    // to a `creditCard` instrument -- docs/20's "Payment instrument
    // relationship" rule. The accountId-match check above already
    // structurally rules out a `debitCard`/`cashCard` instrument here
    // (Checkpoint D's own creation-time validation never lets one of
    // those link to a liability account at all -- see
    // `PaymentInstrumentRepository`'s account-class validation table),
    // but a `paymentService`/`other` instrument CAN legitimately link
    // to the same liability account (that validation table permits
    // either balance class for those two types), so this explicit check
    // is what actually rejects that case rather than relying on
    // coincidental structural luck. Never runs for an asset-account
    // attribution (the overwhelming majority of existing callers) --
    // this is additive, scoped only to the new liability-purchase case.
    final AccountRow account = await _accountRepository.requireById(accountId);
    if (account.isLiability) {
      // Deliberately `PaymentInstrumentType.fromStorageValue(...)` here,
      // not the `PaymentInstrumentRowX.instrumentTypeValue` extension --
      // that extension lives in `payment_instrument_repository.dart`,
      // and this repository deliberately does not import that file
      // (see this method's own doc: no `PaymentInstrumentRepository`
      // dependency at all, by design).
      final PaymentInstrumentType instrumentType =
          PaymentInstrumentType.fromStorageValue(instrument.instrumentType);
      if (instrumentType != PaymentInstrumentType.creditCard) {
        throw InvalidPaymentInstrumentAttributionException(
          paymentInstrumentId,
          'account $accountId is a liability account, but this instrument is '
          '${instrumentType.name}, not creditCard -- only a creditCard '
          'instrument may attribute a liability-account transaction',
        );
      }
    }
  }
}
