import '../../../core/money/money.dart';
import 'goal_target_date.dart';

/// A savings goal's deterministic status -- see
/// `docs/14_DECISION_LOG.md` ADR-022. Never depends on AI or a
/// subjective score; purely a comparison of [Money] amounts and, when a
/// target date exists, today's UTC calendar date.
enum SavingsGoalStatus {
  /// Not yet funded; either has no target date, or its target date is
  /// today or still in the future.
  inProgress,

  /// `saved >= target` -- checked BEFORE overdue, so a goal funded on or
  /// after a passed target date is `completed`, never `overdue`.
  completed,

  /// Not yet funded, and its target date has passed (today is strictly
  /// after it). A target date equal to today is not yet overdue -- see
  /// [hasTargetDatePassed].
  overdue,
}

/// Evaluates [SavingsGoalStatus] for a goal. [target]/[saved] must share
/// a currency (same invariant every other `Money` comparison in this
/// app enforces) -- in practice this always holds, since
/// `SavingsGoalContributionRepository` rejects a mismatched-currency
/// contribution before it can ever be summed into [saved].
SavingsGoalStatus evaluateSavingsGoalStatus({
  required Money target,
  required Money saved,
  DateTime? targetDateUtc,
  required DateTime todayUtc,
}) {
  if (!target.isPositive) {
    throw ArgumentError.value(target, 'target', 'must be strictly positive');
  }
  if (saved >= target) return SavingsGoalStatus.completed;
  if (targetDateUtc != null && hasTargetDatePassed(targetDateUtc: targetDateUtc, todayUtc: todayUtc)) {
    return SavingsGoalStatus.overdue;
  }
  return SavingsGoalStatus.inProgress;
}
