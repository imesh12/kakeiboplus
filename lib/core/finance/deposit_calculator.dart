import 'package:meta/meta.dart';

import '../money/money.dart';
import 'ambiguous_compound_period_exception.dart';
import 'deposit_compounding_frequency.dart';
import 'deposit_term_unit.dart';

/// The result of a [DepositCalculator] estimate -- docs/20 §12.8's
/// required minimum output shape. **These are ESTIMATES, not
/// authoritative bank settlement values** (docs/20 §12.8's non-negotiable
/// labeling requirement) -- any UI that renders this must label them
/// "Estimated interest" / "Estimated maturity value", never a guaranteed
/// figure. Neither field is ever persisted by `DepositRepository` --
/// both are cheaply recomputable from `DepositDetails` plus the deposit
/// account's current balance, so storing them would be exactly the
/// "store a derived value that can be recalculated" this checkpoint's
/// own design principles forbid.
@immutable
class DepositEstimate {
  const DepositEstimate({required this.estimatedInterest, required this.estimatedMaturityValue});

  final Money estimatedInterest;
  final Money estimatedMaturityValue;
}

/// A minimal exact rational number (`numerator`/`denominator`, both
/// [BigInt], `denominator` always `> 0`) used internally by
/// [DepositCalculator] for arithmetic `package:decimal`'s `Decimal`
/// cannot represent exactly.
///
/// # Why not `Decimal` all the way through
///
/// Docs/20 §12.8 asks for every intermediate value to be an exact
/// `Decimal`, rounded once at the end via `MoneyRounding
/// .roundHalfUpToMinorUnits` (ADR-018). That works when every
/// intermediate division has a finite base-10 expansion. It does not
/// here: Actual/365 divides by 365 = 5 × 73, and compound interest
/// divides the annual rate by `periodsPerYear` (12, 4, 2, or 1) -- both
/// 73 and 12's prime factor 3 are not powers of 2 or 5, so `1/365` and
/// `1/12` are repeating decimals with NO exact finite `Decimal`
/// representation. Forcing either through `Decimal` before the "final"
/// rounding step would require truncating a repeating decimal first --
/// silently reintroducing, at an intermediate step, exactly the
/// imprecision the "round only once, at the end" rule exists to
/// prevent.
///
/// [_ExactFraction] instead keeps every intermediate value as an exact
/// `BigInt` numerator/denominator pair -- explicitly sanctioned by this
/// checkpoint's own instructions ("Use the project's existing exact
/// Decimal / BigInt / Money patterns") -- and performs the single
/// HALF-UP-away-from-zero rounding step, at the very end, via exact
/// `BigInt` comparison in [roundHalfUpToInt]. This is mathematically the
/// same ADR-018 policy `MoneyRounding.roundHalfUpToMinorUnits` encodes,
/// just implemented for a value that function's own `Decimal` parameter
/// type cannot hold in the first place. See this class's use in
/// [DepositCalculator.calculateSimpleInterest] /
/// [DepositCalculator.calculateCompoundInterest] for where the single
/// rounding point actually falls in each formula.
@immutable
class _ExactFraction {
  const _ExactFraction(this.numerator, this.denominator);

  factory _ExactFraction.fromInt(int value) => _ExactFraction(BigInt.from(value), BigInt.one);

  final BigInt numerator;

  /// Always strictly positive -- every constructor call site in this
  /// file passes a positive denominator (a currency's minor-unit scale,
  /// 10000 for basis points, 365, or a `periodsPerYear`), and arithmetic
  /// below preserves that invariant (`operator *`/`operator +` multiply
  /// two positive denominators together).
  final BigInt denominator;

  _ExactFraction operator +(_ExactFraction other) => _ExactFraction(
        numerator * other.denominator + other.numerator * denominator,
        denominator * other.denominator,
      );

  _ExactFraction operator *(_ExactFraction other) =>
      _ExactFraction(numerator * other.numerator, denominator * other.denominator);

  /// Exact integer exponentiation via repeated squaring -- [exponent]
  /// must be `>= 0` (every call site here is a whole number of
  /// compounding periods, never negative).
  _ExactFraction pow(int exponent) {
    assert(exponent >= 0, 'pow only supports a non-negative whole number of periods');
    _ExactFraction result = _ExactFraction.fromInt(1);
    _ExactFraction base = this;
    int remaining = exponent;
    while (remaining > 0) {
      if (remaining.isOdd) {
        result = result * base;
      }
      base = base * base;
      remaining >>= 1;
    }
    return result;
  }

  /// Rounds this fraction HALF UP (half away from zero) to the nearest
  /// integer -- the exact ADR-018 policy, applied exactly once. Every
  /// call site in this file only ever rounds a non-negative amount (a
  /// principal times a non-negative growth factor is never negative for
  /// any V1 deposit input), so this deliberately does not implement a
  /// negative-value branch -- unlike `MoneyRounding.roundHalfUpToMinorUnits`,
  /// which does, because it is also used for FX conversions that legitimately
  /// go negative.
  int roundHalfUpToInt() {
    assert(numerator.sign >= 0, 'roundHalfUpToInt only supports non-negative amounts');
    final BigInt floorValue = numerator ~/ denominator;
    final BigInt remainderNumerator = numerator - floorValue * denominator;
    final bool roundUp = (remainderNumerator * BigInt.from(2)) >= denominator;
    final BigInt result = roundUp ? floorValue + BigInt.one : floorValue;
    return result.toInt();
  }
}

/// Deterministic, exact V1 deposit interest calculations -- docs/20
/// §12.8's frozen calculation contract. Pure and stateless (no Drift/
/// Flutter dependency at all -- matching `FinanceEngine`'s own testing
/// philosophy, per this checkpoint's explicit instruction), so every
/// formula here is unit-testable with plain values.
///
/// **[principal] is always a parameter, never a stored field.** V1's
/// frozen `DepositDetails` contract (docs/20 §12.1) has no principal
/// column at all -- "DepositDetails itself does NOT carry a second
/// ledger balance" (this checkpoint's own architecture principle). The
/// deposit's principal is simply its `FinancialAccount`'s own balance
/// (`FinanceEngine.accountBalance`, exactly as for any other asset
/// account) -- callers (a future Deposit Detail screen, docs/20 §13.4
/// checkpoint H) compute that balance the normal way and pass it in
/// here. This keeps [DepositCalculator] fully decoupled from Drift/
/// `FinanceEngine`/`TransactionRepository`, the same "reuse, do not
/// create a parallel dependency" discipline `CreditFacilityRepository
/// .availableCredit` already established for credit-facility math.
class DepositCalculator {
  DepositCalculator._();

  static void _validatePrincipalAndRate(Money principal, int interestRateBasisPoints) {
    if (principal.isNegative) {
      throw ArgumentError.value(principal, 'principal', 'must not be negative.');
    }
    if (interestRateBasisPoints < 0) {
      throw ArgumentError.value(
        interestRateBasisPoints,
        'interestRateBasisPoints',
        'must not be negative.',
      );
    }
  }

  /// Docs/20 §12.8: `interest = principal × rate × (actualDays / 365)`
  /// -- **V1 reference day-count convention: Actual/365**, and leap
  /// years never change the 365 denominator (docs/20 §12.8's explicit
  /// instruction) -- only the numerator, [actualDays], is affected by a
  /// leap day, because it comes from real calendar-day subtraction.
  ///
  /// **Date convention: `[startDateUtc, maturityDateUtc)`.** [actualDays]
  /// is `maturityDateUtc.difference(startDateUtc).inDays` -- the start
  /// date itself does not count as an earned day, and every day up to
  /// but not including the maturity date does. A 30-day deposit (Jan 1
  /// -> Jan 31) accrues interest for exactly 30 days, not 29 or 31. Both
  /// dates must already be calendar-only UTC-midnight `DateTime`s (e.g.
  /// via `normalizeRecurringDate`) -- UTC has no DST, so this subtraction
  /// is exact regardless of which calendar dates are involved.
  ///
  /// Rounds once, HALF UP, to the nearest whole minor unit of
  /// [principal]'s currency, to produce [DepositEstimate.estimatedInterest]
  /// -- [DepositEstimate.estimatedMaturityValue] is then the EXACT integer
  /// sum `principal + estimatedInterest` (never independently rounded
  /// from the real-valued formula), per docs/20 §12.8's formula ordering.
  ///
  /// Throws [ArgumentError] if [principal] is negative,
  /// [interestRateBasisPoints] is negative, or [maturityDateUtc] is
  /// before [startDateUtc].
  static DepositEstimate calculateSimpleInterest({
    required Money principal,
    required int interestRateBasisPoints,
    required DateTime startDateUtc,
    required DateTime maturityDateUtc,
  }) {
    _validatePrincipalAndRate(principal, interestRateBasisPoints);
    if (maturityDateUtc.isBefore(startDateUtc)) {
      throw ArgumentError.value(
        maturityDateUtc,
        'maturityDateUtc',
        'must not be before startDateUtc.',
      );
    }
    final int actualDays = maturityDateUtc.difference(startDateUtc).inDays;

    final _ExactFraction rate = _ExactFraction(BigInt.from(interestRateBasisPoints), _basisPointsScale);
    final _ExactFraction dayFraction = _ExactFraction(BigInt.from(actualDays), _actualThreeSixtyFive);
    final _ExactFraction principalFraction = _ExactFraction.fromInt(principal.minorUnits);

    final int interestMinorUnits = (principalFraction * rate * dayFraction).roundHalfUpToInt();
    final Money interest = Money.fromMinorUnits(interestMinorUnits, principal.currencyCode);
    final Money maturityValue = principal + interest;
    return DepositEstimate(estimatedInterest: interest, estimatedMaturityValue: maturityValue);
  }

  /// Docs/20 §12.8: `maturityValue = principal × (1 + rate/n)^(n×t)`,
  /// where `n` = [compoundingFrequency.periodsPerYear] and `n×t` (the
  /// total whole number of compounding periods) is resolved by
  /// [_resolveCompoundingPlan] -- always a whole number, never a
  /// fractional exponent (docs/20 §12.8's explicit instruction).
  /// [DepositCompoundingFrequency.atMaturity] is the one exception to
  /// the plain "rate/n" per-period rate -- see [_resolveCompoundingPlan]'s
  /// own doc for why its single period's rate is scaled by the term's
  /// exact fraction of a year instead.
  ///
  /// Rounds once, HALF UP, to the nearest whole minor unit of
  /// [principal]'s currency, to produce
  /// [DepositEstimate.estimatedMaturityValue] --
  /// [DepositEstimate.estimatedInterest] is then the EXACT integer
  /// difference `estimatedMaturityValue - principal` (never independently
  /// rounded), per docs/20 §12.8's formula ordering ("interest =
  /// maturityValue − principal").
  ///
  /// Throws [ArgumentError] if [principal] is negative or
  /// [interestRateBasisPoints] is negative. Throws
  /// [AmbiguousCompoundPeriodException] if [termNumber]/[termUnit]/
  /// [compoundingFrequency] do not define an unambiguous whole number of
  /// compounding periods -- see that exception's own doc.
  static DepositEstimate calculateCompoundInterest({
    required Money principal,
    required int interestRateBasisPoints,
    required DepositCompoundingFrequency compoundingFrequency,
    required int termNumber,
    required DepositTermUnit termUnit,
  }) {
    _validatePrincipalAndRate(principal, interestRateBasisPoints);
    final _ExactFraction rate = _ExactFraction(BigInt.from(interestRateBasisPoints), _basisPointsScale);
    final ({int totalPeriods, _ExactFraction periodRate}) plan = _resolveCompoundingPlan(
      compoundingFrequency: compoundingFrequency,
      termNumber: termNumber,
      termUnit: termUnit,
      annualRate: rate,
    );

    final _ExactFraction growthFactor =
        (_ExactFraction.fromInt(1) + plan.periodRate).pow(plan.totalPeriods);
    final _ExactFraction principalFraction = _ExactFraction.fromInt(principal.minorUnits);

    final int maturityMinorUnits = (principalFraction * growthFactor).roundHalfUpToInt();
    final Money maturityValue = Money.fromMinorUnits(maturityMinorUnits, principal.currencyCode);
    final Money interest = maturityValue - principal;
    return DepositEstimate(estimatedInterest: interest, estimatedMaturityValue: maturityValue);
  }

  /// Basis-point scale -- `interestRateBasisPoints / 10000` is the exact
  /// annual rate fraction (docs/20 §12.8: "550 = 5.50%").
  static final BigInt _basisPointsScale = BigInt.from(10000);

  /// V1's frozen Actual/365 denominator (docs/20 §12.8) -- a constant
  /// 365 regardless of leap years; only [calculateSimpleInterest]'s
  /// [actualDays] numerator is ever affected by a leap day.
  static final BigInt _actualThreeSixtyFive = BigInt.from(365);

  /// Resolves `termNumber`/`termUnit`/[compoundingFrequency] to a whole
  /// number of compounding periods PLUS that single period's exact rate,
  /// or throws [AmbiguousCompoundPeriodException] if the period count is
  /// not exact.
  ///
  /// Every [compoundingFrequency] -- INCLUDING
  /// [DepositCompoundingFrequency.atMaturity] -- requires [termUnit] to
  /// be [DepositTermUnit.months] or [DepositTermUnit.years]: a day-based
  /// term has no unambiguous calendar-month period boundary, and
  /// [DepositCompoundingFrequency.atMaturity] is NOT exempt from this,
  /// because its single period's rate must still be scaled to the term's
  /// actual length -- see the next paragraph for why.
  ///
  /// [DepositCompoundingFrequency.atMaturity] is handled as a special
  /// case: it is always exactly 1 period, but that period's rate is the
  /// annual rate scaled by the term's exact fraction of a year
  /// (`totalMonths / 12`) -- NOT the flat, un-scaled annual rate divided
  /// by [DepositCompoundingFrequency.periodsPerYear] (`1`), which every
  /// OTHER frequency uses. Docs/20 §12.8 describes `atMaturity` as
  /// "equivalent to simple interest for that case" -- that equivalence
  /// only holds if a 6-month `atMaturity` term earns half the annual
  /// rate and a 2-year `atMaturity` term earns twice it, exactly as
  /// simple interest scales with `termDays/365`. Applying the flat,
  /// un-scaled annual rate regardless of the term's actual length (what a
  /// naive `rate / periodsPerYear` with `periodsPerYear: 1` would do)
  /// would silently overstate interest for any term shorter than a full
  /// year and understate it for any term longer than one -- exactly the
  /// kind of silently-wrong guess this checkpoint's "do not fake
  /// fractional compounding periods" / "do not guess bank behavior"
  /// instructions forbid. Scaling by the exact month-fraction of a year
  /// keeps this calculation faithful to that "equivalent to simple
  /// interest" framing while still using only exact `BigInt` fractions.
  static ({int totalPeriods, _ExactFraction periodRate}) _resolveCompoundingPlan({
    required DepositCompoundingFrequency compoundingFrequency,
    required int termNumber,
    required DepositTermUnit termUnit,
    required _ExactFraction annualRate,
  }) {
    final int? totalMonths = switch (termUnit) {
      DepositTermUnit.months => termNumber,
      DepositTermUnit.years => termNumber * 12,
      DepositTermUnit.days => null,
    };
    if (totalMonths == null) {
      throw AmbiguousCompoundPeriodException(
        'compoundingFrequency ${compoundingFrequency.storageValue} requires termUnit '
        'months or years -- a day-based term has no unambiguous calendar-month period '
        'boundary to compound against (got termUnit: days).',
      );
    }

    if (compoundingFrequency == DepositCompoundingFrequency.atMaturity) {
      final _ExactFraction periodRate =
          annualRate * _ExactFraction(BigInt.from(totalMonths), BigInt.from(12));
      return (totalPeriods: 1, periodRate: periodRate);
    }

    final int periodLengthMonths = switch (compoundingFrequency) {
      DepositCompoundingFrequency.monthly => 1,
      DepositCompoundingFrequency.quarterly => 3,
      DepositCompoundingFrequency.semiannual => 6,
      DepositCompoundingFrequency.annual => 12,
      DepositCompoundingFrequency.atMaturity =>
        throw StateError('unreachable -- handled above'),
    };
    if (totalMonths % periodLengthMonths != 0) {
      throw AmbiguousCompoundPeriodException(
        'a term of $termNumber ${termUnit.storageValue} ($totalMonths months) is not an '
        'exact whole number of ${compoundingFrequency.storageValue} '
        '($periodLengthMonths-month) compounding periods.',
      );
    }
    final int totalPeriods = totalMonths ~/ periodLengthMonths;
    final _ExactFraction periodRate =
        annualRate * _ExactFraction(BigInt.one, BigInt.from(compoundingFrequency.periodsPerYear));
    return (totalPeriods: totalPeriods, periodRate: periodRate);
  }
}
