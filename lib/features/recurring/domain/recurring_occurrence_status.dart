/// The two -- and only two -- ways a scheduled occurrence date can be
/// handled. There is no "pending" status stored in the database: a
/// pending/due occurrence is never persisted, only derived on the fly
/// from a [RecurringRules] row's schedule (see `recurring_providers.dart`
/// and `docs/14_DECISION_LOG.md` ADR-023). A `RecurringOccurrences` row
/// only ever exists once a scheduled date has actually been acted on.
enum RecurringOccurrenceStatus {
  /// A real `Transactions` row was created for this scheduled date --
  /// see `RecurringOccurrenceRepository.postOccurrence`.
  posted,

  /// The user explicitly chose not to post this scheduled date. No
  /// `Transactions` row exists for it.
  skipped,
}
