import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../finance/balance_class.dart';
import '../../finance/calendar_month_math.dart';
import '../../finance/deposit_compounding_frequency.dart';
import '../../finance/deposit_installment_frequency.dart';
import '../../finance/deposit_interest_method.dart';
import '../../finance/deposit_term_unit.dart';
import '../../finance/deposit_type.dart';
import '../../finance/financial_account_subtype.dart';
import '../../money/currency_mismatch_exception.dart';
import '../app_database.dart';
import 'account_repository.dart';
import 'deposit_not_found_exception.dart';
import 'deposit_validation_exception.dart';

/// Domain helper for a Drift [DepositDetailsRow] -- the same
/// `AccountRowX`/`CreditFacilityDetailsRowX`-style convention this
/// schema already establishes.
extension DepositDetailsRowX on DepositDetailsRow {
  DepositType get depositTypeValue => DepositType.fromStorageValue(depositType);

  DepositTermUnit get termUnitValue => DepositTermUnit.fromStorageValue(termUnit);

  DepositInterestMethod get interestMethodValue =>
      DepositInterestMethod.fromStorageValue(interestMethod);

  /// `null` whenever [interestMethodValue] is [DepositInterestMethod.simple]
  /// -- see [DepositRepository.createDetails]'s creation-time guarantee.
  DepositCompoundingFrequency? get compoundingFrequencyValue {
    final String? raw = compoundingFrequency;
    return raw == null ? null : DepositCompoundingFrequency.fromStorageValue(raw);
  }

  /// `null` whenever [depositTypeValue] is not [DepositType.recurring].
  DepositInstallmentFrequency? get installmentFrequencyValue {
    final String? raw = installmentFrequency;
    return raw == null ? null : DepositInstallmentFrequency.fromStorageValue(raw);
  }
}

/// Checkpoint F: the repository foundation for `DepositDetails` --
/// one-to-one metadata for a deposit ASSET `FinancialAccount` (docs/20
/// §12.1/§12.7). See `tables.dart`'s `DepositDetails` doc for the full
/// conceptual model; this class enforces its creation invariants,
/// mirroring `CreditFacilityRepository`'s identical structure and
/// discipline for its own detail table.
///
/// **Zero independent accounting weight**: nothing in this class ever
/// writes `Accounts.balanceClass`/`openingBalanceMinorUnits`, and no
/// column here participates in any `FinanceEngine`/ledger-balance
/// computation -- the deposit's principal is simply its linked
/// account's own balance (see `DepositCalculator`'s doc). "Estimated
/// interest"/"estimated maturity value" are always DERIVED by
/// `DepositCalculator` and never persisted anywhere on this table.
///
/// **Account-eligibility validation (creation only):** the linked
/// account must already be `balanceClass: asset` and `subtype: deposit`
/// -- this repository never creates or reclassifies the underlying
/// `FinancialAccount` itself (Checkpoint F ships no Add Account UX;
/// docs/20 §13.4 checkpoint G is what eventually does). Exactly the
/// same production-UX gap `CreditFacilityRepository`'s own doc already
/// documents for a liability/creditCard account -- this repository's own
/// tests seed an asset/deposit account directly through the DB fixture,
/// rather than weakening validation to accommodate UI that doesn't exist
/// yet.
///
/// **Funding/maturity/interest transactions need NO new repository
/// method here at all.** `TransactionRepository.recordTransfer`
/// (funding a deposit, or its maturity principal returning to another
/// asset account) and `.recordIncome` (interest actually credited) were
/// already fully balance-class- and subtype-agnostic before this
/// checkpoint -- exactly the same discovery Checkpoint E made for a
/// liability `creditCard` account. Neither method needed a single line
/// changed for a `subtype: deposit` account; see
/// `test/core/database/repositories/transaction_repository_test.dart`'s
/// `Checkpoint F` group for the proof.
class DepositRepository {
  DepositRepository(this._db, this._accountRepository);

  final AppDatabase _db;
  final AccountRepository _accountRepository;
  static const Uuid _uuid = Uuid();

  /// Creates a new `DepositDetails` row for [accountId]. Validates, in
  /// order:
  ///
  /// 1. [accountId] exists (propagating whatever
  ///    [AccountRepository.requireById] throws if it doesn't); belongs to
  ///    [profileId]; is active (not soft-deleted); has `balanceClass:
  ///    asset` and `subtype: deposit` -- else [DepositValidationException].
  /// 2. [termNumber] is `>= 1` (else [ArgumentError] -- a zero/negative-
  ///    length term is not a meaningful deposit; unlike a credit limit,
  ///    there is no legitimate "zero-length deposit" analogous to a
  ///    facility pending its limit).
  /// 3. [interestRateBasisPoints] is not negative (else [ArgumentError]
  ///    -- **zero is a valid rate**, matching item 21's explicit
  ///    requirement).
  /// 4. The deterministic [maturityDate] is computed from [startDateUtc]/
  ///    [termNumber]/[termUnit] -- plain calendar-day addition for
  ///    [DepositTermUnit.days], `calendar_month_math.dart`'s anchor-based
  ///    arithmetic for [DepositTermUnit.months]/[DepositTermUnit.years]
  ///    (docs/20 §12.7). If [explicitMaturityDate] is also supplied, it
  ///    MUST equal the computed value exactly, or
  ///    [DepositValidationException] is thrown -- "if both explicit
  ///    maturityDate and term metadata are present, validate that they
  ///    are consistent rather than silently preferring one." There is
  ///    only ever one stored `maturityDate` column (the computed value);
  ///    [explicitMaturityDate] is a cross-check input only, never stored
  ///    separately.
  /// 5. [interestMethod] gates [compoundingFrequency]: required (non-null)
  ///    for [DepositInterestMethod.compound], must be `null` for
  ///    [DepositInterestMethod.simple] -- either violation throws
  ///    [DepositValidationException] rather than silently ignoring the
  ///    inconsistent field.
  /// 6. [depositType] gates [installmentAmountMinorUnits]/
  ///    [installmentFrequency]: both must be `null` unless [depositType]
  ///    is [DepositType.recurring] (docs/20 §12.9) -- else
  ///    [DepositValidationException]. Neither is REQUIRED even for
  ///    `recurring` -- V1 only needs to store them when known.
  ///    [installmentAmountMinorUnits], if supplied, must be strictly
  ///    positive (else [ArgumentError]).
  /// 7. No `DepositDetails` row already exists for [accountId] (the
  ///    one-deposit-per-account invariant -- also enforced by
  ///    [DepositDetails.accountId]'s database-level `unique()`
  ///    constraint, but this pre-check turns a violation into a clear
  ///    [DepositValidationException] rather than a raw SQLite error).
  /// 8. If [interestDestinationAccountId] is supplied: it exists, belongs
  ///    to [profileId], and shares [accountId]'s `currencyCode` --
  ///    **unlike** `CreditFacilityDetails.linkedPaymentAccountId`, this
  ///    IS currency-validated (see `tables.dart`'s doc on this column for
  ///    why: interest is actually postable there via an ordinary
  ///    `TransactionRepository.recordIncome` call with no FX step in V1).
  ///    A value equal to [accountId] itself is explicitly ALLOWED --
  ///    reinvesting interest back into the same deposit is a legitimate
  ///    pattern, not a circular relationship; this V1 schema has only
  ///    this one optional account-link column, so no genuinely circular
  ///    (two-FK) relationship can even be constructed here.
  Future<String> createDetails({
    required String profileId,
    required String accountId,
    required DepositType depositType,
    required int termNumber,
    required DepositTermUnit termUnit,
    required DateTime startDateUtc,
    required int interestRateBasisPoints,
    required DepositInterestMethod interestMethod,
    DepositCompoundingFrequency? compoundingFrequency,
    DateTime? explicitMaturityDate,
    bool autoRenew = false,
    String? renewalMode,
    String? interestDestinationAccountId,
    int? installmentAmountMinorUnits,
    DepositInstallmentFrequency? installmentFrequency,
  }) async {
    final AccountRow account = await _accountRepository.requireById(accountId);
    if (account.profileId != profileId) {
      throw DepositValidationException(
        'account $accountId belongs to profile ${account.profileId}, not $profileId',
      );
    }
    if (account.deletedAt != null || !account.isActive) {
      throw DepositValidationException(
        'account $accountId is not active -- deposit details cannot be attached '
        'to a deleted/inactive account',
      );
    }
    if (account.balanceClassValue != BalanceClass.asset) {
      throw DepositValidationException(
        'account $accountId has balanceClass ${account.balanceClassValue.name}, not '
        'asset -- a DepositDetails row may only attach to an asset account',
      );
    }
    if (account.subtypeValue != FinancialAccountSubtype.deposit) {
      throw DepositValidationException(
        'account $accountId has subtype ${account.subtypeValue.name}, not deposit -- '
        'a DepositDetails row may only attach to a deposit-subtype account',
      );
    }

    if (termNumber < 1) {
      throw ArgumentError.value(termNumber, 'termNumber', 'must be at least 1.');
    }
    if (interestRateBasisPoints < 0) {
      throw ArgumentError.value(
        interestRateBasisPoints,
        'interestRateBasisPoints',
        'must not be negative.',
      );
    }

    final DateTime normalizedStart = _normalizeCalendarDate(startDateUtc);
    final DateTime computedMaturityDate = _computeMaturityDate(
      startDateUtc: normalizedStart,
      termNumber: termNumber,
      termUnit: termUnit,
    );
    if (explicitMaturityDate != null &&
        _normalizeCalendarDate(explicitMaturityDate) != computedMaturityDate) {
      throw DepositValidationException(
        'explicitMaturityDate ${_normalizeCalendarDate(explicitMaturityDate)} does not '
        'match the maturity date computed from startDate/termNumber/termUnit '
        '($computedMaturityDate) -- these must agree, not silently prefer one',
      );
    }

    if (interestMethod == DepositInterestMethod.compound && compoundingFrequency == null) {
      throw const DepositValidationException(
        'interestMethod is compound but no compoundingFrequency was supplied -- '
        'compound interest cannot be calculated without it',
      );
    }
    if (interestMethod == DepositInterestMethod.simple && compoundingFrequency != null) {
      throw const DepositValidationException(
        'interestMethod is simple but compoundingFrequency was supplied -- '
        'compoundingFrequency is only meaningful for compound interest',
      );
    }

    if (depositType != DepositType.recurring) {
      if (installmentAmountMinorUnits != null || installmentFrequency != null) {
        throw DepositValidationException(
          'installmentAmountMinorUnits/installmentFrequency were supplied but '
          'depositType is ${depositType.storageValue}, not recurring -- these fields '
          'are only meaningful for a recurring deposit',
        );
      }
    }
    if (installmentAmountMinorUnits != null && installmentAmountMinorUnits <= 0) {
      throw ArgumentError.value(
        installmentAmountMinorUnits,
        'installmentAmountMinorUnits',
        'must be strictly positive.',
      );
    }

    final DepositDetailsRow? existing = await (_db.select(_db.depositDetails)
          ..where((tbl) => tbl.accountId.equals(accountId) & tbl.deletedAt.isNull()))
        .getSingleOrNull();
    if (existing != null) {
      throw DepositValidationException(
        'account $accountId already has deposit details (id: ${existing.id})',
      );
    }

    if (interestDestinationAccountId != null) {
      final AccountRow destination = await _accountRepository.requireById(
        interestDestinationAccountId,
      );
      if (destination.profileId != profileId) {
        throw DepositValidationException(
          'interestDestinationAccountId $interestDestinationAccountId belongs to '
          'profile ${destination.profileId}, not $profileId',
        );
      }
      if (destination.currencyCode != account.currencyCode) {
        throw CurrencyMismatchException(account.currencyCode, destination.currencyCode);
      }
    }

    final String id = _uuid.v4();
    final DateTime now = DateTime.now().toUtc();
    await _db.into(_db.depositDetails).insert(
          DepositDetailsCompanion.insert(
            id: id,
            profileId: profileId,
            accountId: accountId,
            depositType: depositType.storageValue,
            termNumber: termNumber,
            termUnit: termUnit.storageValue,
            startDate: normalizedStart,
            maturityDate: computedMaturityDate,
            interestRateBasisPoints: interestRateBasisPoints,
            interestMethod: interestMethod.storageValue,
            compoundingFrequency: Value<String?>(compoundingFrequency?.storageValue),
            autoRenew: Value<bool>(autoRenew),
            renewalMode: Value<String?>(renewalMode),
            interestDestinationAccountId: Value<String?>(interestDestinationAccountId),
            installmentAmountMinorUnits: Value<int?>(installmentAmountMinorUnits),
            installmentFrequency: Value<String?>(installmentFrequency?.storageValue),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  /// Calendar-only UTC-midnight normalization -- the same convention
  /// `normalizeRecurringDate` already established for
  /// `RecurringSchedule`'s `startDateUtc`/`endDateUtc`. Reads
  /// [DateTime.year]/[DateTime.month]/[DateTime.day] directly off
  /// whatever `DateTime` is given, never `.toUtc()`/`.toLocal()`, which
  /// convert an *instant* and can shift which calendar day it lands on.
  ///
  /// **This is the correct helper for a freshly-supplied, not-yet-stored
  /// value** (e.g. [createDetails]'s own `startDateUtc` parameter) --
  /// see [_canonicalizeStoredDate] below for the *different* helper a
  /// value already read back from `depositDetails` needs, and why
  /// `.toUtc()` is safe there but would be wrong here.
  static DateTime _normalizeCalendarDate(DateTime input) =>
      DateTime.utc(input.year, input.month, input.day);

  /// Undoes a read-side quirk in drift's default (non-text)
  /// `DateTimeColumn` storage mode: it always hands back a *local*-
  /// flagged `DateTime` on read -- even for a value this repository
  /// itself wrote as `DateTime.utc(...)` -- because the underlying
  /// instant survives the SQLite round trip exactly, but the `isUtc`
  /// flag does not (see
  /// https://github.com/simolus3/drift/issues/286 and
  /// https://github.com/simolus3/drift/issues/3135). On a UTC+9 machine
  /// this makes a value stored as `2027-01-01 00:00:00.000Z` come back
  /// as the local-flagged `2027-01-01 09:00:00.000` -- the exact same
  /// moment, just re-displayed in local wall-clock terms.
  ///
  /// This matters because `DateTime.==` requires BOTH the same instant
  /// AND the same `isUtc` flag -- unlike [DateTime.difference], which
  /// only ever compares instants and is unaffected by this quirk --
  /// per the operator's own documentation: "Returns true if `other` is
  /// a DateTime at the same moment **and in the same time zone**." So a
  /// value this repository wrote as `DateTime.utc(2027, 1, 1)` never
  /// compares equal to what drift hands back for it, even though it is
  /// the exact same moment -- and on a device far enough from UTC (west
  /// of it, or any offset large enough to cross a day boundary), the
  /// redisplayed *calendar fields themselves* -- `.year`/`.month`/`.day`
  /// -- would also be wrong relative to the calendar date this
  /// repository actually persisted.
  ///
  /// [startDate]/[maturityDate] are calendar-only, date-ONLY financial
  /// metadata (docs/20 §12.7) -- their logical calendar date must stay
  /// stable across persistence and readback, independent of the reading
  /// device's timezone. Calling `.toUtc()` here -- unlike
  /// [_normalizeCalendarDate]'s doc warning against it -- is safe and
  /// necessary specifically *because* [storedValue] is not a fresh,
  /// arbitrary local `DateTime` (where `.toUtc()` could shift which
  /// calendar day it lands on): it is drift's redisplay of an instant
  /// this repository itself already computed and stored as an exact
  /// UTC midnight, so `.toUtc()` recovers precisely that original UTC
  /// calendar date, on any reading device, regardless of offset --
  /// never a shift, only a correction. [_normalizeCalendarDate] then
  /// strips whatever spurious local time-of-day component the
  /// redisplay introduced (e.g. the `09:00` above), the same way it
  /// already does for a freshly-supplied value.
  static DateTime _canonicalizeStoredDate(DateTime storedValue) =>
      _normalizeCalendarDate(storedValue.toUtc());

  /// Applies [_canonicalizeStoredDate] to both of [row]'s date-only
  /// columns -- the single choke point [watchForAccount] and
  /// [requireActiveForAccount] both call so neither read path can drift
  /// out of sync with the other.
  static DepositDetailsRow? _canonicalizeRow(DepositDetailsRow? row) {
    if (row == null) {
      return null;
    }
    return row.copyWith(
      startDate: _canonicalizeStoredDate(row.startDate),
      maturityDate: _canonicalizeStoredDate(row.maturityDate),
    );
  }

  /// Docs/20 §12.7: `maturityDate = startDate + term`. Plain calendar-day
  /// addition for [DepositTermUnit.days] (unambiguous -- no month/year
  /// clamping is involved); `calendar_month_math.dart`'s
  /// [addWholeCalendarMonths] for [DepositTermUnit.months]/
  /// [DepositTermUnit.years] -- e.g. a deposit starting Jan 31 with a
  /// 1-month term matures Feb 28 (or 29 in a leap year), exactly as that
  /// shared routine already proves for a monthly recurring rule anchored
  /// on the 31st.
  static DateTime _computeMaturityDate({
    required DateTime startDateUtc,
    required int termNumber,
    required DepositTermUnit termUnit,
  }) {
    switch (termUnit) {
      case DepositTermUnit.days:
        return startDateUtc.add(Duration(days: termNumber));
      case DepositTermUnit.months:
        return addWholeCalendarMonths(startDateUtc, termNumber);
      case DepositTermUnit.years:
        return addWholeCalendarMonths(startDateUtc, termNumber * 12);
    }
  }

  /// The active deposit details for [accountId], reactively -- `null`
  /// once none exists or it's soft-deleted. What a future Deposit Detail
  /// screen (docs/20 §13.4 checkpoint H) would watch.
  Stream<DepositDetailsRow?> watchForAccount(String accountId) {
    final query = _db.select(_db.depositDetails)
      ..where((tbl) => tbl.accountId.equals(accountId) & tbl.deletedAt.isNull());
    return query.watchSingleOrNull().map(_canonicalizeRow);
  }

  /// Resolves [accountId] to its active deposit details -- throws
  /// [DepositNotFoundException] if none exists or it's soft-deleted.
  Future<DepositDetailsRow> requireActiveForAccount(String accountId) async {
    final DepositDetailsRow? row = await (_db.select(_db.depositDetails)
          ..where((tbl) => tbl.accountId.equals(accountId) & tbl.deletedAt.isNull()))
        .getSingleOrNull();
    if (row == null) {
      throw DepositNotFoundException(accountId);
    }
    return _canonicalizeRow(row)!;
  }
}
