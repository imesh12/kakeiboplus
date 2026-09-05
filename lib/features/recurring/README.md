# recurring — Beta 1 Task 4A foundation + Task 4B local reminders implemented

Beta 1 Task 4A implemented the deterministic recurring-money foundation:
`RecurringRules` (schedule/template only) and `RecurringOccurrences`
(handled scheduled dates only) — schema version 4, see
`docs/14_DECISION_LOG.md` ADR-023. A rule never affects a balance,
income/expense total, budget, or goal until one of its occurrences is
explicitly posted (creating a real transaction via the existing
transaction repository paths) or skipped.

Beta 1 Task 4B added opt-in, per-rule LOCAL reminder notifications —
schema version 5, see `docs/14_DECISION_LOG.md` ADR-024:

- `RecurringRules.notificationsEnabled` (default `false`) is a per-rule
  "Remind me" preference, toggled in `_RuleDialog`
  (`presentation/recurring_screen.dart`). Enabling it is the ONLY thing
  that ever asks the OS for notification permission; if permission isn't
  granted the toggle reverts to `false` and every other recurring/
  financial function keeps working normally.
- `domain/recurring_reminder_planner.dart` is a pure function computing
  which (rule, date) pairs want a reminder — every date from today
  through a fixed 14-day horizon, minus anything already posted or
  skipped. It never decides notification ids or device-local wall-clock
  times; that split is the reconciliation/notification layer's job.
- `core/notifications/` holds the `NotificationScheduler` abstraction, a
  collision-resolving `NotificationIdAllocator`, the real
  `flutter_local_notifications`/`timezone`/`flutter_timezone`-backed
  implementation, and the reminder content builder. This feature's own
  providers/repositories/domain never import any of those three
  packages directly — only `local_notification_scheduler.dart` does.
- `presentation/recurring_notification_providers.dart` reconciles the
  full desired-reminder set on cold start, whenever active rules or
  handled occurrences change, and (via `AiFinancialCoachApp`'s
  `WidgetsBindingObserver`) whenever the app resumes to the foreground —
  never a background worker. Reconciliation always re-schedules the
  FULL desired set (idempotent, no duplicates) and cancels whatever's no
  longer desired, which is what makes editing a rule's schedule/name/
  amount, posting, skipping, and soft-deleting all fall out of one
  algorithm rather than special-cased handling for each.

Not implemented yet: automatic/background posting (occurrences are
always posted or skipped explicitly by the user), FX-aware recurring
rules (same-currency only), cross-currency recurring transfers, and any
Android manifest/Gradle or iOS `AppDelegate` configuration specific to
the notification packages above (deliberately deferred until the
packages are resolved and inspected on a real local Flutter toolchain —
see ADR-024 point 8).
