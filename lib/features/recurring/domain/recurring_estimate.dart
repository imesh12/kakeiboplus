import 'package:meta/meta.dart';

import 'recurrence_frequency.dart';

/// ROUND HALF UP (half away from zero) of the non-negative rational
/// `numerator / denominator` -- reimplements the project's ADR-018
/// ROUND HALF UP policy (`lib/core/money/money_rounding.dart`) on plain
/// non-negative `int`s rather than `Decimal`/`BigInt`, since every
/// numerator/denominator [RecurringEstimate.of] builds is already an
/// exact small integer, never a value that needs `Decimal`'s arbitrary
/// precision.
///
/// `(2 * numerator + denominator) ~/ (2 * denominator)` is the standard
/// integer identity for this: writing `numerator = q * denominator + r`
/// (`0 <= r < denominator`), the expression reduces to `q + (2r +
/// denominator) ~/ (2 * denominator)`, and that second term is exactly 1
/// when `2r >= denominator` (the fractional part is `>= 0.5`) and 0
/// otherwise -- including the exact tie `2r == denominator`, which this
/// rounds up, matching "half away from zero" for these always-
/// non-negative inputs.
int roundHalfUpNonNegative(int numerator, int denominator) {
  assert(numerator >= 0, 'numerator must be >= 0');
  assert(denominator > 0, 'denominator must be > 0');
  return (2 * numerator + denominator) ~/ (2 * denominator);
}

/// Deterministic, integer-only *estimated* monthly/yearly cost of one
/// recurring rule -- Checkpoint 11 (Recurring + Subscriptions V1). See
/// `docs/14_DECISION_LOG.md` ADR-031 for why this is presented as an
/// estimate rather than an exact accounting figure, and why it lives in
/// the domain layer rather than a repository/provider: it is a pure
/// function of already-known values (a rule's frequency, interval, and
/// amount), exactly like [RecurringSchedule] is a pure function of a
/// rule's dates.
///
/// # Why "estimate", never "exact"
///
/// A monthly/yearly total only has an exact, unambiguous answer for a
/// schedule whose period divides evenly into a month/year (e.g. exactly
/// monthly, exactly yearly, with `interval == 1`). A weekly or daily
/// schedule's occurrence count *varies* month to month (a 4-week month
/// has one fewer weekly charge than a 5-week month) and year to year (a
/// leap year has one extra day) -- and even a monthly schedule with,
/// say, `interval: 5` ("every 5 months") does not divide evenly into a
/// 12-month year. This class normalizes every frequency to a single,
/// explicit convention -- **a 365-day year, a 12-month year** -- and
/// documents that convention here rather than claiming exactness.
/// Leap years are deliberately not special-cased: the resulting
/// +/- 1-in-1461 (~0.07%) drift is smaller than the ROUND HALF UP
/// rounding this class already performs on every result, and treating
/// it exactly would make the estimate depend on which specific years a
/// daily/weekly schedule happens to run through -- non-deterministic
/// from this class's point of view, for no practical benefit to an
/// already-labeled estimate. Every caller-facing surface that shows
/// this value must say "estimated" (see
/// `subscriptionsEstimatedMonthlyTotalLabel`/
/// `subscriptionsEstimatedYearlyTotalLabel` in the ARB files and
/// `subscription_providers.dart`) -- this class has no UI-string
/// obligation of its own, it only ever computes an estimate, never
/// asserts it is anything more.
///
/// # Integer-safe by construction
///
/// Every calculation here is exact integer/rational arithmetic -- never
/// `double` -- per the project's money-engine "no floating-point money
/// math" rule. [amountMinorUnits] is multiplied by a small constant
/// numerator (365, 12, or 1 -- never scaled by [interval], which only
/// ever appears in the denominator) and divided by a small denominator,
/// then rounded exactly once via [roundHalfUpNonNegative]. Even the
/// largest realistic recurring amount (JPY/VND-scale integers already
/// comfortably fit 64-bit `int`) multiplied by 365 stays many orders of
/// magnitude below `int`'s 64-bit range, so this never needs `BigInt`.
///
/// # Independence of the monthly and yearly results
///
/// [yearlyMinorUnits] is **not** `monthlyMinorUnits * 12` -- it is
/// computed independently from the same exact rational amount/interval
/// inputs, each rounded exactly once. Deriving one from the other would
/// compound a single rounding step's error twelvefold; computing both
/// independently keeps each one the single most accurate ROUND-HALF-UP
/// estimate for its own period.
@immutable
class RecurringEstimate {
  const RecurringEstimate({required this.monthlyMinorUnits, required this.yearlyMinorUnits});

  /// ROUND HALF UP estimate of this rule's average monthly cost, in the
  /// rule's own currency's minor units. Always `>= 0`.
  final int monthlyMinorUnits;

  /// ROUND HALF UP estimate of this rule's average yearly cost, in the
  /// rule's own currency's minor units. Always `>= 0`. See the class
  /// doc comment for why this is not simply `monthlyMinorUnits * 12`.
  final int yearlyMinorUnits;

  /// [interval] must be `>= 1` (the same invariant
  /// [RecurringSchedule]/`RecurringRuleRepository` already enforce).
  /// [amountMinorUnits] must be `>= 0` -- the repository layer already
  /// rejects a zero/negative recurring amount before a rule is ever
  /// persisted; this only re-asserts that invariant rather than
  /// silently producing a nonsensical negative estimate.
  factory RecurringEstimate.of({
    required RecurrenceFrequency frequency,
    required int interval,
    required int amountMinorUnits,
  }) {
    assert(interval >= 1, 'interval must be >= 1');
    assert(amountMinorUnits >= 0, 'amountMinorUnits must be >= 0');

    // (yearNumerator / yearDenominator) and (monthNumerator /
    // monthDenominator) are the exact "occurrences per year" / "occurrences
    // per month" rationals for this frequency+interval, under the
    // 365-day-year / 12-month-year convention documented above.
    final (int yearNumerator, int yearDenominator, int monthNumerator, int monthDenominator) =
        switch (frequency) {
      RecurrenceFrequency.daily => (365, interval, 365, interval * 12),
      RecurrenceFrequency.weekly => (365, interval * 7, 365, interval * 7 * 12),
      // Monthly/yearly use the exact 12-months-per-year convention --
      // unlike daily/weekly, these are exact whenever `interval` divides
      // evenly into 12 (monthly) or 1 (yearly), and only an estimate
      // (rounded) in between (e.g. "every 5 months").
      RecurrenceFrequency.monthly => (12, interval, 1, interval),
      RecurrenceFrequency.yearly => (1, interval, 1, interval * 12),
    };

    return RecurringEstimate(
      monthlyMinorUnits: roundHalfUpNonNegative(amountMinorUnits * monthNumerator, monthDenominator),
      yearlyMinorUnits: roundHalfUpNonNegative(amountMinorUnits * yearNumerator, yearDenominator),
    );
  }
}
