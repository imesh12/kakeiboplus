import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../finance/ledger_models.dart';
import '../../finance/transaction_type.dart';
import '../../money/currency_mismatch_exception.dart';
import '../../money/money.dart';
import '../app_database.dart';
import 'account_repository.dart';
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

  Future<String> recordExpense({
    required String profileId,
    required String accountId,
    required Money amount,
    String? categoryId,
    String? note,
    required DateTime occurredAtUtc,
  }) {
    return _insert(
      profileId: profileId,
      accountId: accountId,
      type: TransactionType.expense,
      amount: amount,
      categoryId: categoryId,
      note: note,
      occurredAtUtc: occurredAtUtc,
    );
  }

  Future<String> recordIncome({
    required String profileId,
    required String accountId,
    required Money amount,
    String? categoryId,
    String? note,
    required DateTime occurredAtUtc,
  }) {
    return _insert(
      profileId: profileId,
      accountId: accountId,
      type: TransactionType.income,
      amount: amount,
      categoryId: categoryId,
      note: note,
      occurredAtUtc: occurredAtUtc,
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
  Future<String> recordTransfer({
    required String profileId,
    required String sourceAccountId,
    required String destinationAccountId,
    required Money amount,
    String? note,
    required DateTime occurredAtUtc,
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
    );
  }

  Future<void> softDelete(String id) {
    return (_db.update(_db.transactions)..where((tbl) => tbl.id.equals(id))).write(
      TransactionsCompanion(
        deletedAt: Value<DateTime?>(DateTime.now().toUtc()),
        updatedAt: Value<DateTime>(DateTime.now().toUtc()),
      ),
    );
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
  }) async {
    final Transaction existing = await _requireEditableById(id);
    if (existing.type != type.name) {
      throw ArgumentError(
        'Transaction $id is currently a ${existing.type}, not ${type.name} -- '
        'transaction type cannot change on edit.',
      );
    }
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
  }) async {
    final Transaction existing = await _requireEditableById(id);
    if (existing.type != TransactionType.transfer.name) {
      throw ArgumentError(
        'Transaction $id is currently a ${existing.type}, not transfer -- '
        'transaction type cannot change on edit.',
      );
    }
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
  }

  Future<Transaction> _requireEditableById(String id) async {
    final Transaction? row =
        await (_db.select(_db.transactions)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
    if (row == null || row.deletedAt != null) {
      throw TransactionNotFoundException(id);
    }
    return row;
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
  }) async {
    if (!amount.isPositive) {
      throw ArgumentError.value(amount, 'amount', 'Transaction amount must be positive.');
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
            // syncVersion / syncStatus deliberately left at their column
            // defaults (0 / "localOnly" — ADR-020); Beta 0 never sets
            // them explicitly.
          ),
        );
    return id;
  }
}
