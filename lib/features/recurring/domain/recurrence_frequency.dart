/// How often a [RecurringSchedule] repeats. See
/// `docs/14_DECISION_LOG.md` ADR-023 (Beta 1 Task 4A) and
/// `recurring_schedule.dart` for the deterministic anchor-based
/// occurrence math each frequency drives.
enum RecurrenceFrequency {
  daily,
  weekly,
  monthly,
  yearly,
}
