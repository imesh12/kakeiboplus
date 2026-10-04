import 'package:meta/meta.dart';

import '../../../core/finance/finance_engine.dart';
import '../../../core/money/money.dart';
import 'budget_month.dart';
import 'budget_status.dart';

/// The full deterministic result of evaluating one budget (overall or
/// category) for one [BudgetMonth]. Every amount is [Money] -- never a
/// `double` -- except [status], which is itself a deterministic
/// classification, not a floating heuristic. Nothing here is persisted;
/// it is always recomputed fresh from the live ledger and the budget's
/// stored `amountMinorUnits`.
///
/// [dailyRecommendedSpend], [projectedMonthEndSpend], and [status] are
/// all `null` together for a **future** month (see
/// [BudgetCalculator.evaluate]) -- a month that has not started yet has
/// no "today" to measure pace or a daily recommendation from, so this
/// represents that as "not applicable" rather than fabricating a healthy
/// answer for a month with zero elapsed days. [budgeted]/[spent]/
/// [remaining] are always present regardless of period, since they need
/// no notion of "today" to compute.
@immutable
class BudgetCalculation {
  const BudgetCalculation({
    required this.month,
    required this.budgeted,
    required this.spent,
    required this.remaining,
    required this.dailyRecommendedSpend,
    required this.projectedMonthEndSpend,
    required this.status,
    required this.remainingDaysInclusive,
  });

  final BudgetMonth month;
  final Money budgeted;
  final Money spent;

  /// `budgeted - spent`. Can be negative -- an overspent budget is
  /// represented as a negative [Money], never clamped to zero, so the
  /// true overspend amount is always visible.
  final Money remaining;

  final Money? dailyRecommendedSpend;
  final Money? projectedMonthEndSpend;
  final BudgetStatus? status;

  /// The same `remainingDaysInclusive` value [BudgetCalculator.evaluate]
  /// already computes internally to derive [dailyRecommendedSpend] --
  /// exposed as its own field (Dashboard V1 Finalization checkpoint) so
  /// a compact "Remaining Budget" presentation (e.g. a Home summary
  /// tile) can show "N days left" without recomputing it independently
  /// or reimplementing the current/historical/future-month period rule
  /// documented on [BudgetCalculator.evaluate]. `null` under the exact
  /// same condition [dailyRecommendedSpend]/[status] are `null` -- a
  /// future month that hasn't started yet, see [isFutureMonth].
  final int? remainingDaysInclusive;

  /// Whether [month] has not started yet relative to the `todayUtc`
  /// passed to [BudgetCalculator.evaluate] -- equivalent to
  /// `status == null`, exposed under its own name so callers can explain
  /// *why* those fields are absent without re-deriving it.
  bool get isFutureMonth => status == null;
}

/// Builds a [BudgetCalculation] from a budget's configured amount and the
/// ledger's actual spend for that month, applying the three period rules
/// a budget month can be in relative to "today". See
/// `docs/14_DECISION_LOG.md` ADR-021.
///
/// - **Current month** (`month` is the same as `todayUtc`'s month):
///   `daysElapsedInclusive` is `todayUtc`'s day-of-month -- today counts
///   as a full elapsed day.
/// - **Historical month** (`month` is strictly before `todayUtc`'s
///   month): `daysElapsedInclusive` is the whole month
///   (`month.totalDays`) -- the month is over, so pace/projection are
///   evaluated against the complete period, and
///   [BudgetCalculation.projectedMonthEndSpend] equals
///   [BudgetCalculation.spent] exactly (see
///   `FinanceEngine.projectedMonthEndSpend`'s doc comment).
/// - **Future month** (`month` is strictly after `todayUtc`'s month):
///   there are zero elapsed days. Nothing here divides by that zero --
///   [BudgetCalculation.dailyRecommendedSpend],
///   [BudgetCalculation.projectedMonthEndSpend], and
///   [BudgetCalculation.status] are all left `null` ("not applicable")
///   rather than calling into math that isn't defined yet for a month
///   that hasn't started.
///
/// This function does not read any clock itself -- [todayUtc] is
/// supplied by the caller (see `budget_providers.dart`), the same
/// no-hidden-clock convention every other deterministic calculation in
/// this app follows.
class BudgetCalculator {
  BudgetCalculator._();

  static BudgetCalculation evaluate({
    required BudgetMonth month,
    required DateTime todayUtc,
    required Money budgeted,
    required Money spent,
  }) {
    assert(todayUtc.isUtc, 'BudgetCalculator.evaluate requires a UTC todayUtc');
    final Money remaining = budgeted - spent;
    final int totalDays = month.totalDays;
    final BudgetMonth todayMonth = BudgetMonth.fromUtc(todayUtc);

    final int daysElapsedInclusive;
    if (month == todayMonth) {
      daysElapsedInclusive = todayUtc.day; // current month
    } else if (month < todayMonth) {
      daysElapsedInclusive = totalDays; // historical month: fully elapsed
    } else {
      daysElapsedInclusive = 0; // future month: hasn't started yet
    }

    if (daysElapsedInclusive < 1) {
      return BudgetCalculation(
        month: month,
        budgeted: budgeted,
        spent: spent,
        remaining: remaining,
        dailyRecommendedSpend: null,
        projectedMonthEndSpend: null,
        status: null,
        remainingDaysInclusive: null,
      );
    }

    final int remainingDaysInclusive = totalDays - daysElapsedInclusive + 1;
    return BudgetCalculation(
      month: month,
      budgeted: budgeted,
      spent: spent,
      remaining: remaining,
      dailyRecommendedSpend: FinanceEngine.recommendedDailySpend(
        remaining: remaining,
        remainingDaysInclusive: remainingDaysInclusive,
      ),
      projectedMonthEndSpend: FinanceEngine.projectedMonthEndSpend(
        spent: spent,
        daysElapsedInclusive: daysElapsedInclusive,
        totalDaysInMonth: totalDays,
      ),
      status: evaluateBudgetStatus(
        budgeted: budgeted,
        spent: spent,
        daysElapsedInclusive: daysElapsedInclusive,
        totalDaysInMonth: totalDays,
      ),
      remainingDaysInclusive: remainingDaysInclusive,
    );
  }
}
