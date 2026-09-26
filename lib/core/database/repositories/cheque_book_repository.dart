import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../finance/balance_class.dart';
import '../../finance/financial_account_subtype.dart';
import '../app_database.dart';
import 'account_repository.dart';
import 'cheque_book_not_found_exception.dart';
import 'cheque_validation_exception.dart';

/// The set of `FinancialAccountSubtype`s a `ChequeBooks` row may attach
/// to -- Checkpoint N's audited eligibility decision (see
/// `docs/20_ACCOUNTS_ASSETS_HOUSEHOLD_ARCHITECTURE.md` §13.16). `cash`/
/// `wallet` accounts do not carry chequebooks in practice; `deposit` is
/// a locked-term product, not a transactional one; `creditCard` is a
/// liability, out of this checkpoint's scope; a
/// `legacyCardNeedsReview`/`legacyUnknownNeedsReview` account is
/// deliberately excluded from any new financial capability until a user
/// reclassifies it -- the same discipline `CreditFacilityRepository`/
/// `DepositRepository` already established for their own eligible
/// subtypes. This set is shared by `ChequeRepository` for the account a
/// RECEIVED cheque deposits into, for the identical reason: both are
/// "an ordinary liquid transactional asset account," not a special
/// cheque-specific classification of their own.
const Set<FinancialAccountSubtype> chequeEligibleAccountSubtypes = <FinancialAccountSubtype>{
  FinancialAccountSubtype.bank,
  FinancialAccountSubtype.savings,
};

/// Checkpoint N: the repository foundation for `ChequeBooks` -- a
/// chequebook issued against one eligible asset account. See
/// `tables.dart`'s `ChequeBooks` doc for the full conceptual model; this
/// class enforces its creation invariants and lifecycle.
///
/// **Zero independent accounting weight** -- matching `PaymentInstrument`'s
/// own guarantee: nothing in this class ever writes
/// `Accounts.balanceClass`/`openingBalanceMinorUnits`, and a `ChequeBooks`
/// row never itself participates in any `FinanceEngine` computation.
///
/// **Account-eligibility validation (creation only):** the linked
/// account must already be `balanceClass: asset` and `subtype` in
/// [chequeEligibleAccountSubtypes] -- this repository never creates or
/// reclassifies the underlying `FinancialAccount` itself.
class ChequeBookRepository {
  ChequeBookRepository(this._db, this._accountRepository);

  final AppDatabase _db;
  final AccountRepository _accountRepository;
  static const Uuid _uuid = Uuid();

  /// Creates a new chequebook for [accountId]. Validates, in order: that
  /// [accountId] exists (propagating whatever [AccountRepository
  /// .requireById] throws if it doesn't); that it belongs to
  /// [profileId]; that it is active (not soft-deleted); that its
  /// `balanceClass`/`subtype` are eligible (see
  /// [chequeEligibleAccountSubtypes]); and that [label] is non-blank.
  ///
  /// [startingNumber], if supplied, is stored verbatim as TEXT (never
  /// parsed as an integer, so a leading-zero-padded number round-trips
  /// exactly) and is purely informational -- V1 does not compute or
  /// enforce a "valid range" of leaf numbers from it (leaf counts and
  /// numbering schemes vary by bank and are not declared anywhere on
  /// this row); [ChequeRepository.recordIssued]'s own uniqueness check
  /// is the only numbering safeguard this checkpoint implements.
  ///
  /// Returns the new `ChequeBooks` row's id.
  Future<String> createChequeBook({
    required String profileId,
    required String accountId,
    required String label,
    String? startingNumber,
  }) async {
    final AccountRow account = await _accountRepository.requireById(accountId);
    if (account.profileId != profileId) {
      throw ChequeValidationException(
        'account $accountId belongs to profile ${account.profileId}, not $profileId',
      );
    }
    if (account.deletedAt != null || !account.isActive) {
      throw ChequeValidationException(
        'account $accountId is not active -- a chequebook cannot be issued against '
        'a deleted/inactive account',
      );
    }
    if (account.balanceClassValue != BalanceClass.asset ||
        !chequeEligibleAccountSubtypes.contains(account.subtypeValue)) {
      throw ChequeValidationException(
        'account $accountId has balanceClass ${account.balanceClassValue.name} / subtype '
        '${account.subtypeValue.name} -- a chequebook may only attach to an asset account '
        'with subtype bank or savings',
      );
    }
    final String trimmedLabel = label.trim();
    if (trimmedLabel.isEmpty) {
      throw ArgumentError.value(label, 'label', 'must not be blank.');
    }
    final String? trimmedStartingNumber =
        startingNumber == null || startingNumber.trim().isEmpty ? null : startingNumber.trim();

    final String id = _uuid.v4();
    final DateTime now = DateTime.now().toUtc();
    await _db.into(_db.chequeBooks).insert(
          ChequeBooksCompanion.insert(
            id: id,
            profileId: profileId,
            accountId: accountId,
            label: trimmedLabel,
            startingNumber: Value<String?>(trimmedStartingNumber),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  /// The active (non-closed) `ChequeBooks` row named by [id]. Throws
  /// [ChequeBookNotFoundException] if it doesn't exist or is closed --
  /// used by [ChequeRepository.recordIssued] to reject a new issued
  /// cheque against a closed book.
  Future<ChequeBookRow> requireActive(String id) async {
    final ChequeBookRow? row = await (_db.select(_db.chequeBooks)
          ..where((tbl) => tbl.id.equals(id) & tbl.deletedAt.isNull()))
        .getSingleOrNull();
    if (row == null) {
      throw ChequeBookNotFoundException(id);
    }
    return row;
  }

  /// Closes [id] -- soft delete/"closed", see `ChequeBooks.deletedAt`'s
  /// own doc. No more issued cheques may be recorded against a closed
  /// book; its already-issued `Cheques` rows and the row itself remain
  /// fully resolvable for history. Throws [ChequeBookNotFoundException]
  /// if [id] is already closed or doesn't exist.
  Future<void> closeChequeBook(String id) async {
    await requireActive(id);
    final DateTime now = DateTime.now().toUtc();
    await (_db.update(_db.chequeBooks)..where((tbl) => tbl.id.equals(id))).write(
      ChequeBooksCompanion(deletedAt: Value<DateTime?>(now), updatedAt: Value<DateTime>(now)),
    );
  }

  /// Active (non-closed) chequebooks for [accountId], newest first --
  /// the chequebook picker for recording a new issued cheque.
  Stream<List<ChequeBookRow>> watchActiveForAccount(String accountId) {
    final query = _db.select(_db.chequeBooks)
      ..where((tbl) => tbl.accountId.equals(accountId) & tbl.deletedAt.isNull())
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]);
    return query.watch();
  }

  /// All (including closed) chequebooks for [profileId], newest first --
  /// the Cheques list screen's own filter/grouping needs to resolve a
  /// closed book's label for a historical issued cheque too.
  Stream<List<ChequeBookRow>> watchAllForProfile(String profileId) {
    final query = _db.select(_db.chequeBooks)
      ..where((tbl) => tbl.profileId.equals(profileId))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]);
    return query.watch();
  }
}
