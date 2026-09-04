import '../../../core/money/money.dart';

/// The fixed milestone thresholds Beta 1 supports, as whole percentages
/// of [target] saved. Deliberately not user-configurable and not
/// persisted -- see `docs/14_DECISION_LOG.md` ADR-022: attainment is
/// always derived fresh from current [saved]/[target], so editing or
/// soft-deleting a contribution can never leave a stale "reached" flag
/// behind.
const List<int> savingsGoalMilestoneThresholds = <int>[25, 50, 75, 100];

/// The minimum `saved.minorUnits` needed to reach [thresholdPercent] of
/// [targetMinorUnits], computed WITHOUT ever multiplying the full target
/// by up to 100 -- `Money` supports the full signed 64-bit range, and a
/// naive `targetMinorUnits * thresholdPercent ~/ 100` can silently
/// integer-overflow (wrap to a wrong, possibly negative, number --
/// Dart's native `int` does not throw on overflow) for a target near
/// that boundary, producing a wrong reached/not-reached answer instead
/// of a crash.
///
/// Each of the four fixed thresholds is handled with arithmetic that
/// provably cannot overflow for any `targetMinorUnits` up to
/// `9223372036854775807` (max signed 64-bit):
/// - 25%/50% only ever *divide* `targetMinorUnits` (by 4 or 2) -- a
///   division can never overflow.
/// - 75% is derived as `3 * (targetMinorUnits ~/ 4) + (targetMinorUnits
///   % 4)` rather than `targetMinorUnits * 3 ~/ 4`. This is exactly
///   `ceil(3 * targetMinorUnits / 4)` (proof: write `targetMinorUnits =
///   4q + r` with `r` in `0..3`; `3 * targetMinorUnits = 12q + 3r`, so
///   `ceil(3 * targetMinorUnits / 4) = 3q + ceil(3r / 4)`, and
///   `ceil(3r/4) == r` for every `r` in `0..3` by direct check -- so the
///   formula reduces to `3q + r`). The only multiplication left is
///   `3 * q`, where `q = targetMinorUnits ~/ 4 <= targetMinorUnits / 4`,
///   so `3 * q <= 0.75 * targetMinorUnits`, always comfortably inside
///   the signed 64-bit range.
/// - 100% is `targetMinorUnits` itself -- no arithmetic at all.
///
/// Ceiling (not floor) is used throughout -- "reached 50%" must mean
/// "saved at least half", never "saved at least half, rounded down".
int _minorUnitsRequiredForThreshold(int targetMinorUnits, int thresholdPercent) {
  switch (thresholdPercent) {
    case 25:
      final int q = targetMinorUnits ~/ 4;
      return q + (targetMinorUnits % 4 == 0 ? 0 : 1);
    case 50:
      final int q = targetMinorUnits ~/ 2;
      return q + (targetMinorUnits % 2 == 0 ? 0 : 1);
    case 75:
      final int q = targetMinorUnits ~/ 4;
      final int r = targetMinorUnits % 4;
      return 3 * q + r;
    case 100:
      return targetMinorUnits;
    default:
      throw ArgumentError.value(
        thresholdPercent,
        'thresholdPercent',
        'must be one of $savingsGoalMilestoneThresholds',
      );
  }
}

/// Every threshold in [savingsGoalMilestoneThresholds] that [saved] has
/// reached relative to [target], in ascending order. The 100% entry
/// being present is exactly equivalent to the goal being
/// [SavingsGoalStatus.completed] -- both conditions are `saved >=
/// target`; this list is not a second, independently-tracked source of
/// truth for completion.
List<int> reachedSavingsGoalMilestones({required Money saved, required Money target}) {
  return <int>[
    for (final int threshold in savingsGoalMilestoneThresholds)
      if (saved.minorUnits >= _minorUnitsRequiredForThreshold(target.minorUnits, threshold)) threshold,
  ];
}
