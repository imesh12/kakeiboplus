/// What a [RecurringRules] row schedules. Deliberately a narrower set
/// than `TransactionType` (no `refund`/`adjustment`) -- Task 4A only
/// supports recurring income, expense, and same-currency transfer; see
/// `docs/14_DECISION_LOG.md` ADR-023.
enum RecurringRuleKind {
  expense,
  income,
  transfer,
}
