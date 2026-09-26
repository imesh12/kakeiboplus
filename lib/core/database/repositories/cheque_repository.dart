import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../finance/balance_class.dart';
import '../../finance/cheque_direction.dart';
import '../../finance/cheque_status.dart';
import '../../money/currency_mismatch_exception.dart';
import '../../money/money.dart';
import '../app_database.dart';
import 'account_repository.dart';
import 'cheque_book_repository.dart';
import 'cheque_lifecycle_exception.dart';
import 'cheque_not_found_exception.dart';
import 'cheque_validation_exception.dart';
import 'transaction_repository.dart';

/// Domain helper for a Drift [ChequeRow] -- the same `AccountRowX`/
/// `CreditFacilityDetailsRowX`-style convention this schema already
/// establishes.
extension ChequeRowX on ChequeRow {
  ChequeDirection get directionValue => ChequeDirection.values.byName(direction);
  ChequeStatus get statusValue => ChequeStatus.values.byName(status);
  Money get amount => Money.fromMinorUnits(amountMinorUnits, currencyCode);
}

/// Checkpoint N: the repository foundation for `Cheques` -- creation of
/// issued/received cheques and every lifecycle transition between
/// them. See `tables.dart`'s `Cheques`/`ChequeStatus`/`ChequeDirection`
/// docs for the full conceptual/accounting model this class enforces.
///
/// **Posting is atomic and idempotent**, the identical discipline
/// `RecurringOccurrenceRepository.postOccurrence` already established
/// for its own "pending schedule -> real ledger transaction" step: the
/// transition check (is this cheque still [ChequeStatus.pending]?) is
/// re-run INSIDE the same `AppDatabase.transaction` block that performs
/// the transition, so calling [markCleared] (or any other transition
/// method) twice on the same cheque always throws
/// [ChequeLifecycleException] on the second call -- it can never post a
/// second [Transactions] row, and a failed post never leaves a `Cheques`
/// row pointing at a [Transactions] row that doesn't exist (both writes
/// roll back together on any failure).
class ChequeRepository {
  ChequeRepository(
    this._db,
    this._accountRepository,
    this._chequeBookRepository,
    this._transactionRepository,
  );

  final AppDatabase _db;
  final AccountRepository _accountRepository;
  final ChequeBookRepository _chequeBookRepository;
  final TransactionRepository _transactionRepository;
  static const Uuid _uuid = Uuid();

  Future<AccountRow> _requireEligibleAccount({
    required String accountId,
    required String profileId,
  }) async {
    final AccountRow account = await _accountRepository.requireById(accountId);
    if (account.profileId != profileId) {
      throw ChequeValidationException(
        'account $accountId belongs to profile ${account.profileId}, not $profileId',
      );
    }
    if (account.deletedAt != null || !account.isActive) {
      throw ChequeValidationException(
        'account $accountId is not active -- a cheque cannot be recorded against '
        'a deleted/inactive account',
      );
    }
    if (account.balanceClassValue != BalanceClass.asset ||
        !chequeEligibleAccountSubtypes.contains(account.subtypeValue)) {
      throw ChequeValidationException(
        'account $accountId has balanceClass ${account.balanceClassValue.name} / subtype '
        '${account.subtypeValue.name} -- a cheque may only be recorded against an asset '
        'account with subtype bank or savings',
      );
    }
    return account;
  }

  String _requireNonBlank(String value, String argumentName) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(value, argumentName, 'must not be blank.');
    }
    return trimmed;
  }

  /// Records a new [ChequeDirection.issued] cheque, [status]
  /// [ChequeStatus.pending] -- creates NO [Transactions] row (see
  /// [ChequeStatus.pending]'s own doc). Validates, in order: that
  /// [accountId] is an active, eligible (asset, bank/savings) account
  /// owned by [profileId]; that [chequeBookId] names an active
  /// (non-closed) chequebook (propagating [ChequeBookNotFoundException]
  /// if not) belonging to THIS SAME [accountId] (a chequebook can never
  /// be used to issue against a different account than the one it was
  /// created for); that [amount]'s currency matches [accountId]'s own
  /// currency; that [chequeNumber] and [payeeName] are non-blank; and
  /// that no other non-deleted issued cheque already uses [chequeNumber]
  /// within this SAME [chequeBookId] (see `Cheques`' own doc for why
  /// this uniqueness is scoped to the chequebook, not global).
  ///
  /// Returns the new `Cheques` row's id.
  Future<String> recordIssued({
    required String profileId,
    required String accountId,
    required String chequeBookId,
    required String chequeNumber,
    required Money amount,
    required String payeeName,
    required DateTime issueDateUtc,
    String? memo,
  }) async {
    final AccountRow account = await _requireEligibleAccount(
      accountId: accountId,
      profileId: profileId,
    );
    final ChequeBookRow chequeBook = await _chequeBookRepository.requireActive(chequeBookId);
    if (chequeBook.accountId != accountId) {
      throw ChequeValidationException(
        'chequeBook $chequeBookId belongs to account ${chequeBook.accountId}, not $accountId',
      );
    }
    if (chequeBook.profileId != profileId) {
      throw ChequeValidationException(
        'chequeBook $chequeBookId belongs to profile ${chequeBook.profileId}, not $profileId',
      );
    }
    if (amount.currencyCode != account.currencyCode) {
      throw CurrencyMismatchException(account.currencyCode, amount.currencyCode);
    }
    if (!amount.isPositive) {
      throw ArgumentError.value(amount.minorUnits, 'amount', 'must be strictly positive.');
    }
    final String trimmedNumber = _requireNonBlank(chequeNumber, 'chequeNumber');
    final String trimmedPayee = _requireNonBlank(payeeName, 'payeeName');

    final ChequeRow? duplicate = await (_db.select(_db.cheques)
          ..where(
            (tbl) =>
                tbl.chequeBookId.equals(chequeBookId) &
                tbl.chequeNumber.equals(trimmedNumber) &
                tbl.deletedAt.isNull(),
          ))
        .getSingleOrNull();
    if (duplicate != null) {
      throw ChequeValidationException(
        'cheque number $trimmedNumber already exists in chequebook $chequeBookId '
        '(id: ${duplicate.id})',
      );
    }

    final String id = _uuid.v4();
    final DateTime now = DateTime.now().toUtc();
    await _db.into(_db.cheques).insert(
          ChequesCompanion.insert(
            id: id,
            profileId: profileId,
            accountId: accountId,
            direction: ChequeDirection.issued.name,
            chequeBookId: Value<String?>(chequeBookId),
            chequeNumber: trimmedNumber,
            amountMinorUnits: amount.minorUnits,
            currencyCode: amount.currencyCode,
            counterpartyName: trimmedPayee,
            issueDate: issueDateUtc,
            status: ChequeStatus.pending.name,
            createdAt: now,
            updatedAt: now,
            memo: Value<String?>(memo),
          ),
        );
    return id;
  }

  /// Records a new [ChequeDirection.received] cheque, [status]
  /// [ChequeStatus.pending] -- creates NO [Transactions] row. Validates,
  /// in order: that [accountId] (the account the cheque will be
  /// deposited into once cleared) is an active, eligible (asset,
  /// bank/savings) account owned by [profileId]; that [amount]'s
  /// currency matches [accountId]'s own currency; and that
  /// [chequeNumber]/[payerName] are non-blank. Deliberately performs NO
  /// uniqueness check on [chequeNumber] -- see `Cheques`' own doc for
  /// why a received cheque's number is never constrained (it was not
  /// issued by the user, so two different external payers' cheques may
  /// coincidentally share a number).
  ///
  /// Returns the new `Cheques` row's id.
  Future<String> recordReceived({
    required String profileId,
    required String accountId,
    required String chequeNumber,
    required Money amount,
    required String payerName,
    required DateTime issueDateUtc,
    required DateTime receivedDateUtc,
    String? memo,
  }) async {
    final AccountRow account = await _requireEligibleAccount(
      accountId: accountId,
      profileId: profileId,
    );
    if (amount.currencyCode != account.currencyCode) {
      throw CurrencyMismatchException(account.currencyCode, amount.currencyCode);
    }
    if (!amount.isPositive) {
      throw ArgumentError.value(amount.minorUnits, 'amount', 'must be strictly positive.');
    }
    final String trimmedNumber = _requireNonBlank(chequeNumber, 'chequeNumber');
    final String trimmedPayer = _requireNonBlank(payerName, 'payerName');

    final String id = _uuid.v4();
    final DateTime now = DateTime.now().toUtc();
    await _db.into(_db.cheques).insert(
          ChequesCompanion.insert(
            id: id,
            profileId: profileId,
            accountId: accountId,
            direction: ChequeDirection.received.name,
            chequeNumber: trimmedNumber,
            amountMinorUnits: amount.minorUnits,
            currencyCode: amount.currencyCode,
            counterpartyName: trimmedPayer,
            issueDate: issueDateUtc,
            receivedDate: Value<DateTime?>(receivedDateUtc),
            status: ChequeStatus.pending.name,
            createdAt: now,
            updatedAt: now,
            memo: Value<String?>(memo),
          ),
        );
    return id;
  }

  /// The active (non-deleted) `Cheques` row named by [id]. Throws
  /// [ChequeNotFoundException] if it doesn't exist or is soft-deleted.
  Future<ChequeRow> requireById(String id) async {
    final ChequeRow? row = await (_db.select(_db.cheques)
          ..where((tbl) => tbl.id.equals(id) & tbl.deletedAt.isNull()))
        .getSingleOrNull();
    if (row == null) {
      throw ChequeNotFoundException(id);
    }
    return row;
  }

  /// Re-reads [id] and throws [ChequeLifecycleException] unless it is
  /// still [ChequeStatus.pending] -- shared by every transition method
  /// below, always called from INSIDE the same `AppDatabase.transaction`
  /// block that then performs the transition (see this class's own
  /// doc for the idempotency guarantee this gives).
  Future<ChequeRow> _requirePendingForTransition(String id, String action) async {
    final ChequeRow row = await requireById(id);
    if (row.statusValue != ChequeStatus.pending) {
      throw ChequeLifecycleException(
        'cannot $action cheque $id: its status is already ${row.statusValue.name}, not pending',
      );
    }
    return row;
  }

  /// Transitions [chequeId] from [ChequeStatus.pending] to
  /// [ChequeStatus.cleared], posting exactly one [Transactions] row --
  /// an expense (via [TransactionRepository.recordExpense]) for
  /// [ChequeDirection.issued], an income (via [TransactionRepository
  /// .recordIncome]) for [ChequeDirection.received] -- dated
  /// [clearedDateUtc]. Both the new [Transactions] row and the updated
  /// `Cheques` row are written inside a single `AppDatabase.transaction`
  /// block: if either write fails, both roll back together.
  ///
  /// Throws [ChequeNotFoundException] if [chequeId] doesn't exist.
  /// Throws [ChequeLifecycleException] if [chequeId]'s status is not
  /// [ChequeStatus.pending] -- in particular, calling this a second time
  /// on an already-cleared cheque always throws here rather than posting
  /// a second [Transactions] row (see this class's own doc).
  ///
  /// Returns the new [Transactions] row's id.
  Future<String> markCleared({required String chequeId, required DateTime clearedDateUtc}) {
    return _db.transaction(() async {
      final ChequeRow cheque = await _requirePendingForTransition(chequeId, 'clear');

      final String transactionId = switch (cheque.directionValue) {
        ChequeDirection.issued => await _transactionRepository.recordExpense(
            profileId: cheque.profileId,
            accountId: cheque.accountId,
            amount: cheque.amount,
            note: 'Cheque ${cheque.chequeNumber} to ${cheque.counterpartyName}',
            occurredAtUtc: clearedDateUtc,
          ),
        ChequeDirection.received => await _transactionRepository.recordIncome(
            profileId: cheque.profileId,
            accountId: cheque.accountId,
            amount: cheque.amount,
            note: 'Cheque ${cheque.chequeNumber} from ${cheque.counterpartyName}',
            occurredAtUtc: clearedDateUtc,
          ),
      };

      final DateTime now = DateTime.now().toUtc();
      await (_db.update(_db.cheques)..where((tbl) => tbl.id.equals(chequeId))).write(
        ChequesCompanion(
          status: Value<String>(ChequeStatus.cleared.name),
          clearedDate: Value<DateTime?>(clearedDateUtc),
          transactionId: Value<String?>(transactionId),
          updatedAt: Value<DateTime>(now),
        ),
      );
      return transactionId;
    });
  }

  /// Transitions [chequeId] from [ChequeStatus.pending] to
  /// [ChequeStatus.bounced] -- posts NO [Transactions] row (see
  /// [ChequeStatus.bounced]'s own doc). There is deliberately no
  /// bounce-after-clear reversal flow in V1 -- see [ChequeStatus]'s own
  /// doc for why this is a considered deferral, not an oversight; this
  /// method can therefore only ever transition a still-pending cheque,
  /// exactly like [markCleared]/[markStopped]/[markCancelled].
  ///
  /// Throws [ChequeNotFoundException]/[ChequeLifecycleException] with
  /// the same meaning as [markCleared].
  Future<void> markBounced({required String chequeId, required DateTime bouncedDateUtc}) {
    return _db.transaction(() async {
      await _requirePendingForTransition(chequeId, 'mark bounced');
      final DateTime now = DateTime.now().toUtc();
      await (_db.update(_db.cheques)..where((tbl) => tbl.id.equals(chequeId))).write(
        ChequesCompanion(
          status: Value<String>(ChequeStatus.bounced.name),
          bouncedDate: Value<DateTime?>(bouncedDateUtc),
          updatedAt: Value<DateTime>(now),
        ),
      );
    });
  }

  /// Transitions [chequeId] from [ChequeStatus.pending] to
  /// [ChequeStatus.stopped] -- [ChequeDirection.issued] only (see
  /// [ChequeStatus.stopped]'s own doc for why a stop-payment
  /// instruction has no meaning for a received cheque). Posts NO
  /// [Transactions] row.
  ///
  /// Throws [ChequeNotFoundException]/[ChequeLifecycleException] with
  /// the same meaning as [markCleared]; also throws
  /// [ChequeLifecycleException] if [chequeId]'s direction is
  /// [ChequeDirection.received].
  Future<void> markStopped({required String chequeId, required DateTime stoppedDateUtc}) {
    return _db.transaction(() async {
      final ChequeRow cheque = await _requirePendingForTransition(chequeId, 'stop');
      if (cheque.directionValue != ChequeDirection.issued) {
        throw ChequeLifecycleException(
          'cannot stop cheque $chequeId: only an issued cheque can be stopped, this one is '
          '${cheque.directionValue.name}',
        );
      }
      final DateTime now = DateTime.now().toUtc();
      await (_db.update(_db.cheques)..where((tbl) => tbl.id.equals(chequeId))).write(
        ChequesCompanion(
          status: Value<String>(ChequeStatus.stopped.name),
          stoppedOrCancelledDate: Value<DateTime?>(stoppedDateUtc),
          updatedAt: Value<DateTime>(now),
        ),
      );
    });
  }

  /// Transitions [chequeId] from [ChequeStatus.pending] to
  /// [ChequeStatus.cancelled] -- either direction (see
  /// [ChequeStatus.cancelled]'s own doc). Posts NO [Transactions] row.
  ///
  /// Throws [ChequeNotFoundException]/[ChequeLifecycleException] with
  /// the same meaning as [markCleared].
  Future<void> markCancelled({required String chequeId, required DateTime cancelledDateUtc}) {
    return _db.transaction(() async {
      await _requirePendingForTransition(chequeId, 'cancel');
      final DateTime now = DateTime.now().toUtc();
      await (_db.update(_db.cheques)..where((tbl) => tbl.id.equals(chequeId))).write(
        ChequesCompanion(
          status: Value<String>(ChequeStatus.cancelled.name),
          stoppedOrCancelledDate: Value<DateTime?>(cancelledDateUtc),
          updatedAt: Value<DateTime>(now),
        ),
      );
    });
  }

  /// Soft-deletes [chequeId] -- the ONLY deletion path this checkpoint
  /// implements, and only for a still-[ChequeStatus.pending] cheque
  /// (one with no linked [Transactions] row to begin with, so deleting
  /// it can never silently change any posted accounting history). A
  /// cleared/bounced/stopped/cancelled cheque can never be deleted in
  /// V1 -- a deliberate deferral (see the Checkpoint N report), not an
  /// oversight; historical preservation is always preferred.
  ///
  /// Throws [ChequeNotFoundException] if [chequeId] doesn't exist.
  /// Throws [ChequeLifecycleException] if [chequeId]'s status is not
  /// [ChequeStatus.pending].
  Future<void> deletePending(String chequeId) {
    return _db.transaction(() async {
      await _requirePendingForTransition(chequeId, 'delete');
      final DateTime now = DateTime.now().toUtc();
      await (_db.update(_db.cheques)..where((tbl) => tbl.id.equals(chequeId))).write(
        ChequesCompanion(deletedAt: Value<DateTime?>(now), updatedAt: Value<DateTime>(now)),
      );
    });
  }

  /// Active (non-deleted) cheques for [accountId], newest issue date
  /// first.
  Stream<List<ChequeRow>> watchActiveForAccount(String accountId) {
    final query = _db.select(_db.cheques)
      ..where((tbl) => tbl.accountId.equals(accountId) & tbl.deletedAt.isNull())
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.issueDate)]);
    return query.watch();
  }

  /// Active (non-deleted) cheques for [profileId], newest issue date
  /// first -- the Cheques list screen's own data source.
  Stream<List<ChequeRow>> watchActiveForProfile(String profileId) {
    final query = _db.select(_db.cheques)
      ..where((tbl) => tbl.profileId.equals(profileId) & tbl.deletedAt.isNull())
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.issueDate)]);
    return query.watch();
  }

  /// Active (non-deleted) issued cheques recorded against
  /// [chequeBookId], newest issue date first.
  Stream<List<ChequeRow>> watchActiveForChequeBook(String chequeBookId) {
    final query = _db.select(_db.cheques)
      ..where((tbl) => tbl.chequeBookId.equals(chequeBookId) & tbl.deletedAt.isNull())
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.issueDate)]);
    return query.watch();
  }

  /// A single cheque's live state, for the detail screen.
  Stream<ChequeRow?> watchById(String id) {
    final query = _db.select(_db.cheques)..where((tbl) => tbl.id.equals(id));
    return query.watchSingleOrNull();
  }
}
