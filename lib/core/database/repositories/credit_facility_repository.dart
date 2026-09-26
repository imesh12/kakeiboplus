import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../finance/balance_class.dart';
import '../../finance/financial_account_subtype.dart';
import '../../money/currency_mismatch_exception.dart';
import '../../money/money.dart';
import '../app_database.dart';
import 'account_repository.dart';
import 'credit_facility_not_found_exception.dart';
import 'credit_facility_validation_exception.dart';

/// Domain helper for a Drift [CreditFacilityDetailsRow] -- the same
/// `AccountRowX`/`PaymentInstrumentRowX`-style convention this schema
/// already establishes.
extension CreditFacilityDetailsRowX on CreditFacilityDetailsRow {
  /// The stored credit limit as [Money], denominated in whatever
  /// currency the caller supplies -- this table has no `currencyCode`
  /// column of its own (docs/20 §12.3: "Currency is inherited from the
  /// FinancialAccount"), so the caller must already know the linked
  /// account's currency (e.g. from the same `AccountRow` used to
  /// validate this facility). Passing any other currency here would
  /// misrepresent the stored minor units -- this repository's own
  /// `createFacility` is what guarantees [creditLimitMinorUnits] was
  /// only ever stored in the linked account's currency in the first
  /// place.
  Money creditLimitAs(String accountCurrencyCode) =>
      Money.fromMinorUnits(creditLimitMinorUnits, accountCurrencyCode);
}

/// Checkpoint E: the repository foundation for `CreditFacilityDetails`
/// -- one-to-one metadata for a credit-facility liability
/// `FinancialAccount` (docs/20 §12.1). See `tables.dart`'s
/// `CreditFacilityDetails` doc for the full conceptual model; this class
/// enforces its creation invariants.
///
/// **Zero independent accounting weight**, matching `PaymentInstrument`'s
/// own guarantee from Checkpoint D: nothing in this class ever writes
/// `Accounts.balanceClass`/`openingBalanceMinorUnits`, and
/// `creditLimitMinorUnits` never participates in any
/// `FinanceEngine`/ledger-balance computation. "Available credit" is
/// always DERIVED (see [availableCredit]) and never persisted anywhere
/// -- there is no column for it on [CreditFacilityDetails].
///
/// **Account-eligibility validation (creation only):** the linked
/// account must already be `balanceClass: liability` and
/// `subtype: creditCard` -- this repository never creates or reclassifies
/// the underlying `FinancialAccount` itself (Checkpoint E ships no Add
/// Account UX; docs/20 §13.4 checkpoint G is what eventually does). Since
/// today's production `AccountRepository.createAccount` still only ever
/// produces asset-classified rows (Checkpoints B/C), a real
/// liability/creditCard account cannot yet be created end-to-end through
/// the app -- exactly the same gap Checkpoint D's own tests already
/// documented for a `creditCard` `PaymentInstrument`, worked around the
/// same way: tests seed a liability/creditCard account directly through
/// the DB fixture, rather than this repository weakening its own
/// validation to accommodate UI that doesn't exist yet.
class CreditFacilityRepository {
  CreditFacilityRepository(this._db, this._accountRepository);

  final AppDatabase _db;
  final AccountRepository _accountRepository;
  static const Uuid _uuid = Uuid();

  /// Creates a new credit facility for [accountId]. Validates, in
  /// order: that [accountId] exists (propagating whatever
  /// [AccountRepository.requireById] throws if it doesn't, matching
  /// every other repository that depends on it); that it belongs to
  /// [profileId]; that it is active (not soft-deleted); that its
  /// `balanceClass` is [BalanceClass.liability] and its `subtype` is
  /// [FinancialAccountSubtype.creditCard]; that [creditLimit] is
  /// already denominated in the account's own currency (else
  /// [CurrencyMismatchException], matching
  /// `AccountRepository.createAccount`'s own precedent for a mismatched
  /// `Money` argument) and is not negative (else [ArgumentError] --
  /// **zero is a valid limit**, deliberately: nothing in docs/20 §12.1
  /// requires a positive limit, V1 never enforces the limit against a
  /// purchase at all (12.3's "available credit ... always computed,
  /// never stored" -- there is no "reject purchase over limit" rule to
  /// need one for), and a facility legitimately can start at zero before
  /// its real limit is assigned; only a negative magnitude is
  /// nonsensical, consistent with 12.3's "every stored magnitude is
  /// non-negative" convention); that no facility already exists for this
  /// account (the one-facility-per-account invariant -- also enforced by
  /// [CreditFacilityDetails.accountId]'s database-level `unique()`
  /// constraint, but this pre-check is what turns a violation into a
  /// clear [CreditFacilityValidationException] rather than a raw SQLite
  /// error surfacing to a caller); and, if [linkedPaymentAccountId] is
  /// supplied, that it exists and belongs to [profileId] too (existence/
  /// ownership only -- never a `balanceClass`/`subtype` restriction; see
  /// `tables.dart`'s own doc on why this field is informational-only).
  /// [statementClosingDay]/[dueDay], if supplied, must each be between 1
  /// and 31 (else [ArgumentError]) -- independently of each other; unlike
  /// `PaymentInstruments.expiryMonth`/`expiryYear`, there is no
  /// "both or neither" rule between these two.
  Future<String> createFacility({
    required String profileId,
    required String accountId,
    required Money creditLimit,
    int? statementClosingDay,
    int? dueDay,
    String? linkedPaymentAccountId,
  }) async {
    final AccountRow account = await _accountRepository.requireById(accountId);
    if (account.profileId != profileId) {
      throw CreditFacilityValidationException(
        'account $accountId belongs to profile ${account.profileId}, not $profileId',
      );
    }
    if (account.deletedAt != null || !account.isActive) {
      throw CreditFacilityValidationException(
        'account $accountId is not active -- a credit facility cannot be attached '
        'to a deleted/inactive account',
      );
    }
    if (account.balanceClassValue != BalanceClass.liability) {
      throw CreditFacilityValidationException(
        'account $accountId has balanceClass ${account.balanceClassValue.name}, not '
        'liability -- a CreditFacilityDetails row may only attach to a liability account',
      );
    }
    if (account.subtypeValue != FinancialAccountSubtype.creditCard) {
      throw CreditFacilityValidationException(
        'account $accountId has subtype ${account.subtypeValue.name}, not creditCard -- '
        'a CreditFacilityDetails row may only attach to a creditCard-subtype account',
      );
    }
    if (creditLimit.currencyCode != account.currencyCode) {
      throw CurrencyMismatchException(account.currencyCode, creditLimit.currencyCode);
    }
    if (creditLimit.isNegative) {
      throw ArgumentError.value(
        creditLimit.minorUnits,
        'creditLimit',
        'must not be negative (zero is allowed).',
      );
    }
    _validateDayOfMonth(statementClosingDay, 'statementClosingDay');
    _validateDayOfMonth(dueDay, 'dueDay');

    final CreditFacilityDetailsRow? existing = await (_db.select(_db.creditFacilityDetails)
          ..where((tbl) => tbl.accountId.equals(accountId) & tbl.deletedAt.isNull()))
        .getSingleOrNull();
    if (existing != null) {
      throw CreditFacilityValidationException(
        'account $accountId already has a credit facility (id: ${existing.id})',
      );
    }

    if (linkedPaymentAccountId != null) {
      final AccountRow linked = await _accountRepository.requireById(linkedPaymentAccountId);
      if (linked.profileId != profileId) {
        throw CreditFacilityValidationException(
          'linkedPaymentAccountId $linkedPaymentAccountId belongs to profile '
          '${linked.profileId}, not $profileId',
        );
      }
    }

    final String id = _uuid.v4();
    final DateTime now = DateTime.now().toUtc();
    await _db.into(_db.creditFacilityDetails).insert(
          CreditFacilityDetailsCompanion.insert(
            id: id,
            profileId: profileId,
            accountId: accountId,
            creditLimitMinorUnits: creditLimit.minorUnits,
            statementClosingDay: Value<int?>(statementClosingDay),
            dueDay: Value<int?>(dueDay),
            linkedPaymentAccountId: Value<String?>(linkedPaymentAccountId),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  /// Checkpoint O: updates the credit limit on [accountId]'s existing
  /// facility -- the one edit path `createFacility` never provided
  /// (it is create-only; there was no way to change a limit after
  /// account creation before this checkpoint). Deliberately as narrow
  /// as [AccountRepository.updateAccount]'s own precedent: this writes
  /// ONLY [CreditFacilityDetailsRow.creditLimitMinorUnits] (and
  /// [CreditFacilityDetailsRow.updatedAt]) -- it never touches
  /// `Accounts.balanceClass`/`subtype`/`openingBalanceMinorUnits`
  /// (this method has no way to), never posts a `Transaction`, and
  /// therefore can never change a derived balance or Net Worth. Reuses
  /// [requireActiveForAccount] for existence, and the same currency-
  /// match/non-negative validation [createFacility] already
  /// establishes (zero remains a valid limit here too, for the exact
  /// same reason -- see that method's own doc).
  ///
  /// Throws [CreditFacilityNotFoundException] if [accountId] has no
  /// active facility, [CurrencyMismatchException] if [creditLimit] is
  /// denominated in a different currency than the linked account, and
  /// [ArgumentError] if it is negative.
  Future<void> updateCreditLimit({
    required String accountId,
    required Money creditLimit,
  }) async {
    final CreditFacilityDetailsRow facility = await requireActiveForAccount(accountId);
    final AccountRow account = await _accountRepository.requireById(accountId);
    if (creditLimit.currencyCode != account.currencyCode) {
      throw CurrencyMismatchException(account.currencyCode, creditLimit.currencyCode);
    }
    if (creditLimit.isNegative) {
      throw ArgumentError.value(
        creditLimit.minorUnits,
        'creditLimit',
        'must not be negative (zero is allowed).',
      );
    }
    await (_db.update(_db.creditFacilityDetails)..where((tbl) => tbl.id.equals(facility.id)))
        .write(
      CreditFacilityDetailsCompanion(
        creditLimitMinorUnits: Value<int>(creditLimit.minorUnits),
        updatedAt: Value<DateTime>(DateTime.now().toUtc()),
      ),
    );
  }

  static void _validateDayOfMonth(int? day, String argumentName) {
    if (day == null) return;
    if (day < 1 || day > 31) {
      throw ArgumentError.value(day, argumentName, 'must be between 1 and 31.');
    }
  }

  /// The active facility for [accountId], reactively -- `null` once
  /// none exists or it's soft-deleted. What a future Credit Facility
  /// Detail screen (docs/20 §13.4 checkpoint H) would watch.
  Stream<CreditFacilityDetailsRow?> watchForAccount(String accountId) {
    final query = _db.select(_db.creditFacilityDetails)
      ..where((tbl) => tbl.accountId.equals(accountId) & tbl.deletedAt.isNull());
    return query.watchSingleOrNull();
  }

  /// Resolves [accountId] to its active facility -- throws
  /// [CreditFacilityNotFoundException] if none exists or it's
  /// soft-deleted. For any caller (e.g. an available-credit
  /// computation) that requires the facility to exist right now, rather
  /// than reacting to it possibly not existing yet.
  Future<CreditFacilityDetailsRow> requireActiveForAccount(String accountId) async {
    final CreditFacilityDetailsRow? row = await (_db.select(_db.creditFacilityDetails)
          ..where((tbl) => tbl.accountId.equals(accountId) & tbl.deletedAt.isNull()))
        .getSingleOrNull();
    if (row == null) {
      throw CreditFacilityNotFoundException(accountId);
    }
    return row;
  }

  /// Docs/20 §12.3: `availableCredit = creditLimit - amountOwed`,
  /// **always computed, never stored** -- there is no column for this
  /// anywhere. [amountOwed] must already be computed by
  /// `FinanceEngine.accountBalance` for the same liability account (this
  /// repository has no `TransactionRepository`/ledger dependency at all,
  /// deliberately -- it neither recomputes nor duplicates that
  /// arithmetic; see the Checkpoint E brief's "reuse FinanceEngine, do
  /// not create parallel credit-card balance arithmetic" instruction).
  ///
  /// [Money]'s own `-` operator already throws [CurrencyMismatchException]
  /// if [creditLimit] and [amountOwed] are denominated differently
  /// (unreachable in practice: both should always come from the same
  /// liability account's own currency), so this is a thin, exact,
  /// deliberately trivial pass-through rather than reimplemented
  /// arithmetic.
  static Money availableCredit({required Money creditLimit, required Money amountOwed}) {
    return creditLimit - amountOwed;
  }
}
