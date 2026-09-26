import '../../../core/database/repositories/credit_facility_repository.dart';
import '../../../core/money/money.dart';

/// Checkpoint O: pure, presentation-only derivations for a credit
/// card's "Credit details" section on Account Detail -- available
/// credit and utilization. Deliberately NOT part of `FinanceEngine`
/// (docs/20 §12.3's own boundary, restated by this checkpoint's brief:
/// "presentation calculations... do not belong in FinanceEngine merely
/// because they involve money") and deliberately not persisted anywhere
/// (there is no column for either value on `CreditFacilityDetails` --
/// see that table's own doc). Every instance is built fresh from
/// already-derived inputs ([creditLimit] from `CreditFacilityDetails
/// .creditLimitMinorUnits`, [amountOwed] from `FinanceEngine
/// .accountBalance`); this class never queries anything itself.
///
/// **Available credit is display-clamped, not domain-clamped:**
/// [CreditFacilityRepository.availableCredit] itself stays exactly as
/// Checkpoint E defined it -- `creditLimit - amountOwed`, unclamped,
/// because that is the correct domain arithmetic and other callers may
/// legitimately want the signed figure. [availableCredit] on THIS class
/// additionally floors that result at zero purely for display, per this
/// checkpoint's explicit "do not show negative available credit as if
/// it were meaningful spending capacity" rule. An over-limit balance is
/// never hidden -- see [utilizationPercent], which is free to exceed
/// 100.
class CreditFacilityPresentation {
  const CreditFacilityPresentation({required this.creditLimit, required this.amountOwed});

  /// The facility's persisted, currently-configured limit. May be zero
  /// -- see [hasConfiguredLimit].
  final Money creditLimit;

  /// The linked account's current derived balance -- already a
  /// non-negative "amount owed" magnitude (`FinanceEngine
  /// .accountBalance`'s liability convention), never itself negative.
  final Money amountOwed;

  /// Whether [creditLimit] is a meaningful, configured limit (`> 0`)
  /// rather than the "not yet assigned" placeholder value
  /// `CreditFacilityRepository.createFacility` also accepts (see that
  /// method's own doc: "zero is a valid limit... a facility
  /// legitimately can start at zero before its real limit is
  /// assigned"). Every limit-dependent figure below -- [availableCredit]/
  /// [utilizationPercent] -- is only meaningful when this is `true`;
  /// presentation must not fabricate a 0% utilization or a "full"
  /// available-credit figure for an unset limit (this checkpoint's
  /// explicit "Missing limit" rule), so callers gate on this flag
  /// first and show a localized "Not set" instead when it is `false`.
  bool get hasConfiguredLimit => creditLimit.minorUnits > 0;

  /// `max(0, creditLimit - amountOwed)` -- never negative. Only
  /// meaningful when [hasConfiguredLimit] is `true`; callers must check
  /// that first rather than reading this for an unset limit.
  Money get availableCredit {
    final Money raw = CreditFacilityRepository.availableCredit(
      creditLimit: creditLimit,
      amountOwed: amountOwed,
    );
    return raw.isNegative ? Money.zero(creditLimit.currencyCode) : raw;
  }

  /// `amountOwed / creditLimit * 100`, as a plain double for display
  /// formatting -- deliberately not money (this is a ratio, not a
  /// currency amount), and deliberately not persisted anywhere (this
  /// checkpoint's explicit "utilization is presentation-derived data,
  /// do NOT persist it" rule). May exceed 100 for an over-limit
  /// balance -- never clamped, so an over-limit condition is never
  /// hidden. Only meaningful when [hasConfiguredLimit] is `true`;
  /// callers must check that first rather than reading this for an
  /// unset limit (this getter does not itself guard against a zero
  /// limit -- do not call it when [hasConfiguredLimit] is `false`).
  double get utilizationPercent => amountOwed.minorUnits / creditLimit.minorUnits * 100;
}
