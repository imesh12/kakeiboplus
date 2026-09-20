import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

import '../../../core/database/app_database.dart';
import '../../../core/notifications/notification_id_allocator.dart';
import '../../../core/notifications/notification_providers.dart';
import '../../../core/notifications/notification_scheduler.dart';
import '../../../core/notifications/recurring_reminder_content.dart';
import '../domain/recurrence_frequency.dart';
import '../domain/recurring_reminder_planner.dart';
import '../domain/recurring_rule_kind.dart';
import '../domain/recurring_schedule.dart';
import 'recurring_providers.dart';

/// Maps a persisted [RecurringRuleRow] to the pure planner's input shape
/// -- mirrors `recurring_providers.dart`'s own `recurringScheduleOf` helper (same
/// idea, extended with the extra fields
/// [planDesiredReminders]/[DesiredReminder] need that a bare
/// [RecurringSchedule] doesn't carry).
RecurringReminderRuleInput _toReminderRuleInput(RecurringRuleRow rule) => RecurringReminderRuleInput(
      ruleId: rule.id,
      name: rule.name,
      kind: RecurringRuleKind.values.byName(rule.kind),
      amountMinorUnits: rule.amountMinorUnits,
      currencyCode: rule.currencyCode,
      notificationsEnabled: rule.notificationsEnabled,
      schedule: RecurringSchedule(
        frequency: RecurrenceFrequency.values.byName(rule.frequency),
        interval: rule.interval,
        startDateUtc: rule.startDate,
        endDateUtc: rule.endDate,
      ),
    );

HandledOccurrenceKey _toHandledKey(RecurringOccurrenceRow occurrence) => HandledOccurrenceKey(
      ruleId: occurrence.ruleId,
      scheduledDateUtc: occurrence.scheduledDate,
    );

/// Reconciles every active rule's local reminders against [scheduler] --
/// the single algorithm behind every one of Beta 1 Task 4B's lifecycle
/// requirements (`docs/14_DECISION_LOG.md` ADR-024):
///
///  - **Create/edit a rule's schedule while enabled**: its newly-desired
///    dates get scheduled; any date no longer desired (schedule
///    changed, rule disabled, or the date is now handled) gets
///    cancelled.
///  - **Post/skip an occurrence**: that date leaves the desired set (via
///    [handledOccurrences]) on the very next reconciliation, so its
///    pending reminder is cancelled.
///  - **Edit name/amount only**: [reconcileRecurringReminders]
///    re-schedules the FULL desired set every pass, and
///    [NotificationScheduler.schedule] is specified to replace (never
///    duplicate) an already-pending id -- so the notification's content
///    simply gets refreshed in place.
///  - **Soft-delete a rule**: it drops out of [rules] entirely (see
///    `RecurringRuleRepository.softDelete` / `watchActiveRules`), so
///    none of its dates are ever desired again and every one of its
///    still-pending reminders gets cancelled below.
///  - **Repeated reconciliation**: fully idempotent -- the same desired
///    set always allocates the same ids
///    ([NotificationIdAllocator.allocate]'s own guarantee) and
///    re-scheduling an unchanged reminder under its existing id is a
///    no-op at the OS level.
///
/// Exposed (not private) so both [recurringNotificationReconcilerProvider]
/// and its tests can call it directly with fakes -- see
/// `test/features/recurring/presentation/
/// recurring_notification_providers_test.dart`.
@visibleForTesting
Future<void> reconcileRecurringReminders({
  required List<RecurringRuleRow> rules,
  required List<RecurringOccurrenceRow> handledOccurrences,
  required NotificationScheduler scheduler,
  required DateTime nowUtc,
}) async {
  final List<RecurringReminderRuleInput> ruleInputs =
      rules.map(_toReminderRuleInput).toList(growable: false);
  final Set<HandledOccurrenceKey> handledKeys = handledOccurrences.map(_toHandledKey).toSet();

  final List<DesiredReminder> desired = planDesiredReminders(
    rules: ruleInputs,
    handledOccurrences: handledKeys,
    nowUtc: nowUtc,
  );

  const NotificationIdAllocator allocator = NotificationIdAllocator();
  final Map<DesiredReminder, int> ids = allocator.allocate(
    desired,
    ruleIdOf: (DesiredReminder reminder) => reminder.ruleId,
    scheduledDateUtcOf: (DesiredReminder reminder) => reminder.scheduledDateUtc,
  );
  final Set<int> desiredIds = ids.values.toSet();

  for (final DesiredReminder reminder in desired) {
    final RecurringReminderContent content = buildRecurringReminderContent(reminder);
    await scheduler.schedule(
      ScheduledReminder(
        id: ids[reminder]!,
        ruleId: reminder.ruleId,
        scheduledDateUtc: reminder.scheduledDateUtc,
        title: content.title,
        body: content.body,
      ),
    );
  }

  final Set<int> pendingIds = await scheduler.pendingIds();
  for (final int id in pendingIds) {
    if (!desiredIds.contains(id)) {
      await scheduler.cancel(id);
    }
  }
}

/// Reactively reconciles recurring reminders whenever
/// [activeRecurringRulesProvider] or [handledOccurrencesProvider]
/// change -- a plain `Provider` (not `.autoDispose`), same convention
/// `appDatabaseProvider` established, so it stays alive and keeps
/// reacting for the app's whole lifetime once
/// [lib/app/app.dart]'s `build()` creates it with a single `ref.watch`
/// (mirroring that file's existing
/// `categoryRepositoryProvider.seedSystemCategoriesIfNeeded()`
/// fire-and-forget precedent).
///
/// Covers 3 of Beta 1 Task 4B correction 2's 4 reconciliation triggers
/// (cold start; active rules change; handled occurrences change) purely
/// through Riverpod's own dependency graph. The 4th --
/// foreground/resume -- cannot come from a data change (the 14-day
/// horizon advances with wall-clock time even when no rule/occurrence
/// changed) and is instead triggered explicitly by
/// `AiFinancialCoachApp`'s `WidgetsBindingObserver` calling
/// `ref.invalidate(recurringNotificationReconcilerProvider)` on
/// `AppLifecycleState.resumed` -- see `lib/app/app.dart`. Invalidating
/// forces this provider's body to re-run with a fresh `DateTime.now()`,
/// which is exactly what a resume needs: the same rules/occurrences,
/// reconciled against today's (possibly new) calendar date.
///
/// Deliberately NOT a background worker/isolate -- Beta 1 explicitly
/// scopes that out (correction 2); the horizon and these four triggers
/// are judged sufficient to never meaningfully fall behind.
final Provider<void> recurringNotificationReconcilerProvider = Provider<void>((ref) {
  final AsyncValue<List<RecurringRuleRow>> rulesAsync = ref.watch(activeRecurringRulesProvider);
  final AsyncValue<List<RecurringOccurrenceRow>> handledAsync =
      ref.watch(handledOccurrencesProvider);

  final List<RecurringRuleRow>? rules = rulesAsync.valueOrNull;
  final List<RecurringOccurrenceRow>? handled = handledAsync.valueOrNull;
  if (rules == null || handled == null) {
    // Still loading (or errored) -- nothing to reconcile yet; the next
    // rebuild once both resolve will reconcile.
    return;
  }

  final NotificationScheduler scheduler = ref.read(notificationSchedulerProvider);
  unawaited(
    reconcileRecurringReminders(
      rules: rules,
      handledOccurrences: handled,
      scheduler: scheduler,
      nowUtc: DateTime.now().toUtc(),
    ),
  );
});
