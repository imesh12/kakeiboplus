import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../finance/balance_class.dart';
import '../../finance/card_network.dart';
import '../../finance/payment_instrument_type.dart';
import '../app_database.dart';
import 'account_repository.dart';
import 'payment_instrument_not_found_exception.dart';
import 'payment_instrument_validation_exception.dart';

/// Domain helpers for a Drift [PaymentInstrumentRow] -- the same
/// `AccountRowX`-style convention `account_repository.dart` already
/// establishes for translating a plain-text enum column back into its
/// strongly-typed Dart value.
extension PaymentInstrumentRowX on PaymentInstrumentRow {
  PaymentInstrumentType get instrumentTypeValue =>
      PaymentInstrumentType.fromStorageValue(instrumentType);

  CardNetwork? get networkValue =>
      network == null ? null : CardNetwork.fromStorageValue(network!);
}

/// Checkpoint D: the repository foundation for `PaymentInstrument` --
/// metadata describing HOW a `FinancialAccount` (physically `accounts`)
/// was used to pay or receive money. See `tables.dart`'s
/// `PaymentInstruments` doc for the full conceptual model; this class is
/// what enforces its creation/lifecycle invariants.
///
/// **Account-class validation (creation only):** each
/// [PaymentInstrumentType] permits only certain [BalanceClass] values on
/// the account it links to -- [debitCard]/[cashCard] require
/// [BalanceClass.asset]; [creditCard] requires [BalanceClass.liability];
/// [paymentService]/[other] permit either, since their real-world
/// funding model varies and V1 does not assume one. A [creditCard]
/// instrument does NOT itself make its linked account a liability --
/// this validation only ever rejects an inconsistent pairing, it never
/// changes `Accounts.balanceClass` (which remains immutable by
/// `AccountRepository`'s own signature-shape discipline, unaffected by
/// this repository). Today's production Add Account UX cannot create a
/// liability account yet (Checkpoint B/C), so a real `creditCard`
/// instrument cannot yet be created end-to-end in the app -- tests seed
/// a liability account directly through the DB fixture, exactly as the
/// Checkpoint D brief permits, rather than this repository weakening its
/// own validation to accommodate UI that doesn't exist yet.
///
/// **Sensitive-data boundary:** this repository never accepts or stores
/// a full card number/PAN, CVV/CVC, PIN, magnetic stripe data, or any
/// authentication credential -- only [last4] (validated as exactly 4
/// decimal digits, or null) and [expiryMonth]/[expiryYear] (validated as
/// both-null-or-both-present, month 1-12).
///
/// **Immutability:** [profileId], [PaymentInstrumentRow.accountId], and
/// [PaymentInstrumentRow.instrumentType] can never change after
/// creation -- [updateMetadata]'s signature has no parameter for any of
/// the three, the same immutability-by-signature-shape discipline
/// `AccountRepository.updateAccount` already established for
/// `balanceClass`/`subtype`/`currencyCode`. If relinking an instrument
/// to a different account is ever needed, the Checkpoint D brief is
/// explicit that it should be a separate, explicit operation with its
/// own history semantics -- not silently exposed through a generic
/// update. That operation is not built here.
///
/// **Lifecycle:** soft delete only, matching every other table in this
/// schema (`Accounts`/`Transactions`/`FinancialInstitutions`). An
/// instrument referenced by a historical transaction must remain
/// resolvable after being archived -- see [findByIdIncludingDeleted] --
/// while [watchActiveForAccount]/[watchActiveForProfile] (selection for
/// a *new* transaction) exclude it.
class PaymentInstrumentRepository {
  PaymentInstrumentRepository(this._db, this._accountRepository);

  final AppDatabase _db;
  final AccountRepository _accountRepository;
  static const Uuid _uuid = Uuid();

  /// The [BalanceClass] values each [PaymentInstrumentType] permits on
  /// its linked account -- see this class's own doc for the full
  /// rationale for each row.
  static const Map<PaymentInstrumentType, Set<BalanceClass>> _allowedBalanceClasses =
      <PaymentInstrumentType, Set<BalanceClass>>{
    PaymentInstrumentType.debitCard: <BalanceClass>{BalanceClass.asset},
    PaymentInstrumentType.cashCard: <BalanceClass>{BalanceClass.asset},
    PaymentInstrumentType.creditCard: <BalanceClass>{BalanceClass.liability},
    PaymentInstrumentType.paymentService: <BalanceClass>{
      BalanceClass.asset,
      BalanceClass.liability,
    },
    PaymentInstrumentType.other: <BalanceClass>{BalanceClass.asset, BalanceClass.liability},
  };

  /// Creates a new payment instrument. Validates, in order: [last4]/
  /// expiry shape (plain [ArgumentError] -- see those helpers' own doc),
  /// that [accountId] exists and belongs to [profileId], that its
  /// [BalanceClass] is one [instrumentType] permits, and -- if
  /// [institutionId] is supplied -- that it exists and belongs to
  /// [profileId] too. Throws [PaymentInstrumentValidationException] for
  /// the three relational failures; propagates whatever
  /// [AccountRepository.requireById] throws if [accountId] doesn't
  /// exist at all (matching every other repository that depends on it,
  /// e.g. `TransactionRepository.recordTransfer`).
  Future<String> createInstrument({
    required String profileId,
    required String accountId,
    required PaymentInstrumentType instrumentType,
    required String nickname,
    CardNetwork? network,
    String? last4,
    int? expiryMonth,
    int? expiryYear,
    String? institutionId,
  }) async {
    _validateLast4(last4);
    _validateExpiry(expiryMonth, expiryYear);

    final AccountRow account = await _accountRepository.requireById(accountId);
    if (account.profileId != profileId) {
      throw PaymentInstrumentValidationException(
        'account $accountId belongs to profile ${account.profileId}, not $profileId',
      );
    }
    final Set<BalanceClass> allowed = _allowedBalanceClasses[instrumentType]!;
    if (!allowed.contains(account.balanceClassValue)) {
      throw PaymentInstrumentValidationException(
        '${instrumentType.name} cannot link to a ${account.balanceClassValue.name} account '
        '(account $accountId) -- ${instrumentType.name} permits: '
        '${allowed.map((BalanceClass c) => c.name).join('/')}',
      );
    }

    if (institutionId != null) {
      await _requireInstitutionForProfile(institutionId, profileId);
    }

    final String id = _uuid.v4();
    final DateTime now = DateTime.now().toUtc();
    await _db.into(_db.paymentInstruments).insert(
          PaymentInstrumentsCompanion.insert(
            id: id,
            profileId: profileId,
            accountId: accountId,
            institutionId: Value<String?>(institutionId),
            instrumentType: instrumentType.storageValue,
            network: Value<String?>(network?.storageValue),
            nickname: nickname,
            last4: Value<String?>(last4),
            expiryMonth: Value<int?>(expiryMonth),
            expiryYear: Value<int?>(expiryYear),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Future<void> _requireInstitutionForProfile(String institutionId, String profileId) async {
    final FinancialInstitutionRow? institution = await (_db.select(_db.financialInstitutions)
          ..where((tbl) => tbl.id.equals(institutionId)))
        .getSingleOrNull();
    if (institution == null) {
      throw PaymentInstrumentValidationException('institution $institutionId does not exist');
    }
    if (institution.profileId != profileId) {
      throw PaymentInstrumentValidationException(
        'institution $institutionId belongs to profile ${institution.profileId}, not $profileId',
      );
    }
  }

  static void _validateLast4(String? last4) {
    if (last4 == null) return;
    if (!RegExp(r'^\d{4}$').hasMatch(last4)) {
      throw ArgumentError.value(last4, 'last4', 'must be exactly 4 decimal digits, or null.');
    }
  }

  /// Both-null-or-both-present (see this class's own doc for why this
  /// rule was chosen over allowing either half alone: a lone month or a
  /// lone year is not a usable expiry date, and silently accepting one
  /// would just defer the same "which half is missing" ambiguity to
  /// whatever reads it back).
  static void _validateExpiry(int? month, int? year) {
    if (month == null && year == null) return;
    if (month == null || year == null) {
      throw ArgumentError('expiryMonth and expiryYear must both be null or both be present.');
    }
    if (month < 1 || month > 12) {
      throw ArgumentError.value(month, 'expiryMonth', 'must be between 1 and 12.');
    }
  }

  /// Active (non-archived) instruments linked to [accountId], oldest
  /// first -- what a future "choose a card for this transaction" picker
  /// would watch.
  Stream<List<PaymentInstrumentRow>> watchActiveForAccount(String accountId) {
    final query = _db.select(_db.paymentInstruments)
      ..where((tbl) => tbl.accountId.equals(accountId) & tbl.deletedAt.isNull())
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.createdAt)]);
    return query.watch();
  }

  /// Active (non-archived) instruments for [profileId] across every
  /// account, oldest first.
  Stream<List<PaymentInstrumentRow>> watchActiveForProfile(String profileId) {
    final query = _db.select(_db.paymentInstruments)
      ..where((tbl) => tbl.profileId.equals(profileId) & tbl.deletedAt.isNull())
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.createdAt)]);
    return query.watch();
  }

  /// Resolves [id] to its live row -- throws [PaymentInstrumentNotFoundException]
  /// if it doesn't exist or is archived. For *new*-transaction attribution
  /// and any operation that requires an active instrument; see
  /// [findByIdIncludingDeleted] for historical resolution instead.
  Future<PaymentInstrumentRow> requireActiveById(String id) async {
    final PaymentInstrumentRow? row = await (_db.select(_db.paymentInstruments)
          ..where((tbl) => tbl.id.equals(id) & tbl.deletedAt.isNull()))
        .getSingleOrNull();
    if (row == null) {
      throw PaymentInstrumentNotFoundException(id);
    }
    return row;
  }

  /// Resolves [id] regardless of soft-delete state -- `null` only if it
  /// never existed at all. This is what lets a historical transaction's
  /// attribution remain understandable after the instrument it names has
  /// been archived (see this class's own "Lifecycle" doc); nothing that
  /// creates or selects for a *new* transaction should use this.
  Future<PaymentInstrumentRow?> findByIdIncludingDeleted(String id) {
    return (_db.select(_db.paymentInstruments)..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
  }

  /// Updates an instrument's safe metadata fields only. **Never**
  /// [PaymentInstrumentRow.accountId], [PaymentInstrumentRow.profileId],
  /// or [PaymentInstrumentRow.instrumentType] -- see this class's own
  /// "Immutability" doc; this method's signature has no parameter for
  /// any of the three, so there is no way for a caller to move an
  /// instrument to a different account/profile or change its type
  /// through this API at all.
  Future<void> updateMetadata({
    required String id,
    required String nickname,
    CardNetwork? network,
    String? last4,
    int? expiryMonth,
    int? expiryYear,
    String? institutionId,
  }) async {
    _validateLast4(last4);
    _validateExpiry(expiryMonth, expiryYear);

    final PaymentInstrumentRow existing = await requireActiveById(id);
    if (institutionId != null) {
      await _requireInstitutionForProfile(institutionId, existing.profileId);
    }

    final int rowsAffected = await (_db.update(_db.paymentInstruments)
          ..where((tbl) => tbl.id.equals(id) & tbl.deletedAt.isNull()))
        .write(
      PaymentInstrumentsCompanion(
        nickname: Value<String>(nickname),
        network: Value<String?>(network?.storageValue),
        last4: Value<String?>(last4),
        expiryMonth: Value<int?>(expiryMonth),
        expiryYear: Value<int?>(expiryYear),
        institutionId: Value<String?>(institutionId),
        updatedAt: Value<DateTime>(DateTime.now().toUtc()),
      ),
    );
    if (rowsAffected != 1) {
      throw PaymentInstrumentNotFoundException(id);
    }
  }

  /// Archives (soft-deletes) an instrument. Never hard-deletes -- a
  /// historical transaction may still reference it (see
  /// [findByIdIncludingDeleted]).
  Future<void> softDelete(String id) async {
    final int rowsAffected = await (_db.update(_db.paymentInstruments)
          ..where((tbl) => tbl.id.equals(id) & tbl.deletedAt.isNull()))
        .write(
      PaymentInstrumentsCompanion(
        deletedAt: Value<DateTime?>(DateTime.now().toUtc()),
        updatedAt: Value<DateTime>(DateTime.now().toUtc()),
      ),
    );
    if (rowsAffected != 1) {
      throw PaymentInstrumentNotFoundException(id);
    }
  }
}
