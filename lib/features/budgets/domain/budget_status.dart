import '../../../core/money/money.dart';

/// A deterministic, non-AI classification of how a budget is tracking
/// against its expected pace through the month. See
/// `docs/14_DECISION_LOG.md` ADR-021 for the full rationale; summarized
/// here:
///
/// - [healthy]: spending so far is at or under the expected pace.
/// - [caution]: spending is ahead of pace but has not yet exceeded the
///   total budget.
/// - [overBudget]: spending has exceeded the total budget.
///
/// Deliberately has no fourth "no data" value -- a month with zero
/// elapsed days (a future month) has no defined status at all, which is
/// represented by `BudgetCalculation.status` being `null`, not by adding
/// a value here that would need to render as if it meant something.
enum BudgetStatus { healthy, caution, overBudget }

/// Classifies [spent] against [budgeted] for a month that has at least
/// one elapsed day. Never called for a future month (zero elapsed days)
/// -- see `BudgetCalculator.evaluate`, the only caller, which skips this
/// entirely rather than letting it divide by a zero-day period.
///
/// [budgeted] and [spent] must share a currency (an ordinary
/// [CurrencyMismatchException] from `Money`'s own comparison operators
/// results otherwise) and [budgeted] must be strictly positive --
/// `BudgetRepository` never persists a zero or negative budget, so this
/// is a caller-contract precondition here, not a re-validation of user
/// input.
///
/// Threshold rule -- a single deterministic pace comparison, not an
/// arbitrary percentage cutoff:
///
/// ```
/// expectedSpendSoFar = budgeted * daysElapsedInclusive ~/ totalDaysInMonth
/// ```
///
/// - `spent > budgeted`                                -> [BudgetStatus.overBudget]
/// - `spent > expectedSpendSoFar` (but `<= budgeted`)   -> [BudgetStatus.caution]
/// - otherwise (`spent <= expectedSpendSoFar`)          -> [BudgetStatus.healthy]
BudgetStatus evaluateBudgetStatus({
  required Money budgeted,
  required Money spent,
  required int daysElapsedInclusive,
  required int totalDaysInMonth,
}) {
  if (daysElapsedInclusive < 1) {
    throw ArgumentError.value(
      daysElapsedInclusive,
      'daysElapsedInclusive',
      'must be at least 1 -- this function is not defined for a month '
          'with zero elapsed days; callers must not invoke it for a '
          'future month.',
    );
  }
  if (!budgeted.isPositive) {
    throw ArgumentError.value(budgeted, 'budgeted', 'must be a strictly positive amount.');
  }

  if (spent > budgeted) {
    return BudgetStatus.overBudget;
  }

  final Money expectedSpendSoFar = Money.fromMinorUnits(
    budgeted.minorUnits * daysElapsedInclusive ~/ totalDaysInMonth,
    budgeted.currencyCode,
  );

  return spent > expectedSpendSoFar ? BudgetStatus.caution : BudgetStatus.healthy;
}
