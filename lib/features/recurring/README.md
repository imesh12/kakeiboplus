# recurring — Beta 1 Task 4A foundation implemented; reminders are Task 4B

Beta 1 Task 4A implemented the deterministic recurring-money foundation:
`RecurringRules` (schedule/template only) and `RecurringOccurrences`
(handled scheduled dates only) — schema version 4, see
`docs/14_DECISION_LOG.md` ADR-023. A rule never affects a balance,
income/expense total, budget, or goal until one of its occurrences is
explicitly posted (creating a real transaction via the existing
transaction repository paths) or skipped.

Not implemented yet: OS/local notifications or reminders for due
occurrences (Task 4B, once this deterministic engine has been verified
in production use), automatic/background posting (occurrences are always
posted or skipped explicitly by the user), FX-aware recurring rules
(same-currency only), and cross-currency recurring transfers.
