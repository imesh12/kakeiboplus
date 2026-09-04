/// A savings goal's target date is a user-picked **calendar date**
/// (year/month/day) -- not a precise instant. Normalizing it must never
/// let a timezone conversion move it to the previous or next calendar
/// day (`docs/14_DECISION_LOG.md` ADR-022).
///
/// # Why not `input.toUtc()`
///
/// A date picker typically returns a local `DateTime` at local midnight
/// for the day the user picked. Calling `.toUtc()` on that converts the
/// *instant*, which can shift the calendar date by one day depending on
/// the device's UTC offset (e.g. a device west of UTC at local midnight
/// is still "yesterday" in UTC). [normalizeCalendarDateToUtc] never
/// calls `.toUtc()`/`.toLocal()` -- it only ever reads [DateTime.year]/
/// [DateTime.month]/[DateTime.day] directly off whatever `DateTime` it's
/// given (which return exactly the calendar fields that `DateTime` was
/// constructed with, regardless of its own UTC/local tag or any
/// time-of-day component) and re-wraps those three numbers as a UTC
/// midnight. The selected calendar date survives unchanged; only its
/// representation becomes UTC.
///
/// This is the sole place a target date should ever be normalized --
/// `SavingsGoalRepository.createGoal`/`updateGoal` call this at the
/// write boundary so every `targetDate` reaching the database (and
/// every comparison in `savings_goal_status.dart`/
/// `savings_goal_calculation.dart`) is already a UTC-midnight calendar
/// date, never a precise instant with a stray time-of-day component.
DateTime normalizeCalendarDateToUtc(DateTime input) {
  return DateTime.utc(input.year, input.month, input.day);
}

/// True if [targetDateUtc] (assumed already [normalizeCalendarDateToUtc]
/// -normalized) is strictly before today's UTC calendar date -- i.e. the
/// deadline has come and gone. A target date equal to today is
/// deliberately NOT "passed" -- today counts as the final available day
/// to contribute (see `docs/14_DECISION_LOG.md` ADR-022); "overdue"
/// begins the day after.
bool hasTargetDatePassed({required DateTime targetDateUtc, required DateTime todayUtc}) {
  final DateTime todayDateOnly = normalizeCalendarDateToUtc(todayUtc);
  return targetDateUtc.isBefore(todayDateOnly);
}
