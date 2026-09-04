import 'package:meta/meta.dart';

import '../../../core/finance/finance_engine.dart';
import '../../../core/money/money.dart';
import 'goal_target_date.dart';
import 'savings_goal_milestones.dart';
import 'savings_goal_status.dart';

/// The full deterministic evaluation of one savings goal at a point in
/// time: [target]/[saved] as authoritative [Money], [remaining] clamped
/// at zero, [status], the milestones reached so far, and (when
/// applicable) a recommended daily contribution pace. See
/// `docs/14_DECISION_LOG.md` ADR-022.
///
/// Deliberately takes [saved] as an already-summed [Money] input rather
/// than a list of contributions -- summing (and excluding soft-deleted
/// rows) is a repository/provider-layer concern, not this pure
/// calculation's. See `SavingsGoalContributionRepository` and
/// `goalCalculationProvider`.
@immutable
class SavingsGoalCalculation {
  const SavingsGoalCalculation({
    required this.target,
    required this.saved,
    required this.remaining,
    required this.status,
    required this.recommendedDailyContribution,
    required this.reachedMilestones,
  });

  final Money target;
  final Money saved;

  /// `max(target - saved, 0)` -- never negative, even when overfunded.
  final Money remaining;

  final SavingsGoalStatus status;

  /// `null` means "not applicable" -- [status] is
  /// [SavingsGoalStatus.completed] uses `Money.zero` instead (a real,
  /// meaningful answer: nothing left to save), but a goal with no
  /// target date, or one whose target date has already passed without
  /// being funded, has no daily pace to recommend at all. See
  /// `FinanceEngine.recommendedDailyContribution` for the ceiling-
  /// division formula used when this IS applicable.
  final Money? recommendedDailyContribution;

  /// Every threshold in [savingsGoalMilestoneThresholds] reached so far,
  /// ascending. Always recomputed fresh -- never persisted.
  final List<int> reachedMilestones;

  /// Presentation-only whole-percent-saved, **floor**-rounded so it can
  /// never read "100%" while [status] is still
  /// [SavingsGoalStatus.inProgress] (99.6% must show "99%", not "100%",
  /// which would falsely imply completion) -- see
  /// `docs/14_DECISION_LOG.md` ADR-022. Uncapped above 100 for an
  /// overfunded goal; only a progress bar's *fill fraction* should ever
  /// clamp, never this text.
  ///
  /// Uses `BigInt` for this one transient calculation, exactly so it
  /// stays exact (never an approximation that could misclassify the
  /// 99%-vs-100% boundary) even at minor-unit values near the signed
  /// 64-bit boundary that authoritative `Money` supports. The `BigInt`
  /// never escapes this getter -- `Money` itself is never changed to
  /// `BigInt`, and this result is never fed back into a stored value or
  /// another calculation.
  int get wholePercentSaved {
    final BigInt s = BigInt.from(saved.minorUnits);
    final BigInt t = BigInt.from(target.minorUnits);
    // `target` is always strictly positive by the time it reaches here
    // -- `SavingsGoalRepository` rejects a zero/negative target before
    // any row is ever written -- so this never divides by zero.
    return (s * BigInt.from(100) ~/ t).toInt();
  }
}

/// Orchestrates [SavingsGoalCalculation] from a goal's target/saved
/// amounts, its (already UTC-midnight-normalized -- see
/// [normalizeCalendarDateToUtc]) target date if any, and the current UTC
/// instant. Mirrors `BudgetCalculator.evaluate`'s role: the low-level
/// arithmetic primitives live in `FinanceEngine`; this decides WHEN each
/// one applies from the goal's period/completion semantics.
class SavingsGoalCalculator {
  SavingsGoalCalculator._();

  static SavingsGoalCalculation evaluate({
    required Money target,
    required Money saved,
    DateTime? targetDateUtc,
    required DateTime todayUtc,
  }) {
    final SavingsGoalStatus status = evaluateSavingsGoalStatus(
      target: target,
      saved: saved,
      targetDateUtc: targetDateUtc,
      todayUtc: todayUtc,
    );

    final Money remaining =
        (target - saved).isNegative ? Money.zero(target.currencyCode) : target - saved;

    final Money? recommendedDailyContribution = _recommendedDailyContribution(
      status: status,
      remaining: remaining,
      targetDateUtc: targetDateUtc,
      todayUtc: todayUtc,
      currencyCode: target.currencyCode,
    );

    return SavingsGoalCalculation(
      target: target,
      saved: saved,
      remaining: remaining,
      status: status,
      recommendedDailyContribution: recommendedDailyContribution,
      reachedMilestones: reachedSavingsGoalMilestones(saved: saved, target: target),
    );
  }

  static Money? _recommendedDailyContribution({
    required SavingsGoalStatus status,
    required Money remaining,
    required DateTime? targetDateUtc,
    required DateTime todayUtc,
    required String currencyCode,
  }) {
    // Completed -> zero, a real answer ("nothing left to save"), never
    // fabricated and never `null`.
    if (status == SavingsGoalStatus.completed) {
      return Money.zero(currencyCode);
    }
    // No target date -> nothing to pace against.
    if (targetDateUtc == null) {
      return null;
    }
    // Passed, unfunded -> "not applicable", never a fake zero (that
    // would misleadingly read as "on track needing nothing further").
    if (hasTargetDatePassed(targetDateUtc: targetDateUtc, todayUtc: todayUtc)) {
      return null;
    }
    // Today or a future date -> today counts as one of the remaining
    // days (a deadline of today itself is exactly 1 remaining day).
    final DateTime todayDateOnly = normalizeCalendarDateToUtc(todayUtc);
    final int remainingDaysInclusive = targetDateUtc.difference(todayDateOnly).inDays + 1;
    return FinanceEngine.recommendedDailyContribution(
      remaining: remaining,
      remainingDaysInclusive: remainingDaysInclusive,
    );
  }
}
