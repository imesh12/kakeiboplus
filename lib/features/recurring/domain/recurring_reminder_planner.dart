import 'package:meta/meta.dart';

import 'recurring_rule_kind.dart';
import 'recurring_schedule.dart';

/// Beta 1 Task 4B's fixed local-reminder scheduling horizon, in days
/// forward from today (inclusive of today itself). Deliberately small
/// and bounded -- see `docs/14_DECISION_LOG.md` ADR-024 for why 14 days:
/// long enough that a reminder is always scheduled well before it's
/// due even for weekly/monthly rules, short enough that reconciling on
/// every cold start/foreground-resume/data-change (rather than a
/// background worker) never falls meaningfully behind, and small enough
/// that the number of OS-level pending notifications stays bounded by
/// `activeRules.length * 14`, never unbounded.
const int recurringReminderHorizonDays = 14;

/// One recurring rule's identity/content fields, as the pure planner
/// needs them -- deliberately NOT a `RecurringRuleRow` (this file must
/// stay free of any Drift import, same as `RecurringSchedule` itself).
/// The presentation layer builds this from a `RecurringRuleRow`,
/// mirroring `recurring_providers.dart`'s existing `recurringScheduleOf`
/// helper.
@immutable
class RecurringReminderRuleInput {
  const RecurringReminderRuleInput({
    required this.ruleId,
    required this.name,
    required this.kind,
    required this.amountMinorUnits,
    required this.currencyCode,
    required this.notificationsEnabled,
    required this.schedule,
  });

  final String ruleId;
  final String name;
  final RecurringRuleKind kind;
  final int amountMinorUnits;
  final String currencyCode;

  /// The rule's own "Remind me" opt-in -- a rule with this `false` never
  /// contributes a [DesiredReminder], regardless of its schedule.
  final bool notificationsEnabled;
  final RecurringSchedule schedule;
}

/// One already-handled (posted OR skipped) occurrence's identity --
/// deliberately not a `RecurringOccurrenceRow` for the same
/// Drift-independence reason as [RecurringReminderRuleInput]. Both
/// statuses remove a date from the desired reminder set equally --
/// posting AND skipping a due date both mean "the user has already
/// dealt with this", so neither should still ring a reminder
/// (`docs/14_DECISION_LOG.md` ADR-024, correction 6).
@immutable
class HandledOccurrenceKey {
  const HandledOccurrenceKey({required this.ruleId, required this.scheduledDateUtc});

  final String ruleId;
  final DateTime scheduledDateUtc;

  @override
  bool operator ==(Object other) =>
      other is HandledOccurrenceKey &&
      other.ruleId == ruleId &&
      other.scheduledDateUtc.isAtSameMomentAs(scheduledDateUtc);

  @override
  int get hashCode => Object.hash(ruleId, scheduledDateUtc.millisecondsSinceEpoch);
}

/// One reminder the notification-scheduling layer should have pending,
/// as of the moment [planDesiredReminders] was called. Deliberately
/// carries only calendar-date + plain content fields -- never a
/// platform notification id (see `NotificationIdAllocator`, a separate,
/// later step) and never a device-local wall-clock instant (see
/// `ScheduledReminder`'s doc comment: that conversion is the
/// notification-scheduling/platform boundary's job, not this pure
/// planner's -- `docs/14_DECISION_LOG.md` ADR-024, correction 5).
@immutable
class DesiredReminder {
  const DesiredReminder({
    required this.ruleId,
    required this.scheduledDateUtc,
    required this.ruleName,
    required this.kind,
    required this.amountMinorUnits,
    required this.currencyCode,
  });

  final String ruleId;
  final DateTime scheduledDateUtc;
  final String ruleName;
  final RecurringRuleKind kind;
  final int amountMinorUnits;
  final String currencyCode;

  @override
  bool operator ==(Object other) =>
      other is DesiredReminder &&
      other.ruleId == ruleId &&
      other.scheduledDateUtc.isAtSameMomentAs(scheduledDateUtc) &&
      other.ruleName == ruleName &&
      other.kind == kind &&
      other.amountMinorUnits == amountMinorUnits &&
      other.currencyCode == currencyCode;

  @override
  int get hashCode => Object.hash(
        ruleId,
        scheduledDateUtc.millisecondsSinceEpoch,
        ruleName,
        kind,
        amountMinorUnits,
        currencyCode,
      );
}

/// Computes every [DesiredReminder] across [rules] as of [nowUtc] --
/// pure, deterministic, no I/O, no platform/plugin dependency. The
/// notification-scheduling reconciliation layer
/// (`recurring_notification_providers.dart`) is the only caller.
///
/// For each rule with `notificationsEnabled == true`, includes every
/// occurrence from today (inclusive) through [horizonDays] forward --
/// always a bounded, finite scan via
/// `RecurringSchedule.occurrencesInRange`, never unbounded -- EXCLUDING
/// any date that already has a handled (posted or skipped) occurrence
/// in [handledOccurrences]. A rule with `notificationsEnabled == false`
/// contributes nothing, regardless of its schedule. Deliberately never
/// includes a date strictly before today ("overdue"): that backlog is
/// already surfaced in-app by `recurringPendingItemsProvider` -- a local
/// reminder is for something not yet due, not a second nag about
/// something the Overdue list already shows.
List<DesiredReminder> planDesiredReminders({
  required List<RecurringReminderRuleInput> rules,
  required Set<HandledOccurrenceKey> handledOccurrences,
  required DateTime nowUtc,
  int horizonDays = recurringReminderHorizonDays,
}) {
  final DateTime todayUtc = normalizeRecurringDate(nowUtc);
  final DateTime horizonEndUtc = todayUtc.add(Duration(days: horizonDays));

  final List<DesiredReminder> result = <DesiredReminder>[];
  for (final RecurringReminderRuleInput rule in rules) {
    if (!rule.notificationsEnabled) continue;

    final List<DateTime> occurrences = rule.schedule.occurrencesInRange(
      fromUtc: todayUtc,
      toUtc: horizonEndUtc,
    );
    for (final DateTime date in occurrences) {
      final bool alreadyHandled = handledOccurrences.contains(
        HandledOccurrenceKey(ruleId: rule.ruleId, scheduledDateUtc: date),
      );
      if (alreadyHandled) continue;
      result.add(
        DesiredReminder(
          ruleId: rule.ruleId,
          scheduledDateUtc: date,
          ruleName: rule.name,
          kind: rule.kind,
          amountMinorUnits: rule.amountMinorUnits,
          currencyCode: rule.currencyCode,
        ),
      );
    }
  }

  // Deterministic order -- callers (id allocation, tests) should never
  // depend on the incoming `rules` list's order.
  result.sort((DesiredReminder a, DesiredReminder b) {
    final int ruleCompare = a.ruleId.compareTo(b.ruleId);
    if (ruleCompare != 0) return ruleCompare;
    return a.scheduledDateUtc.compareTo(b.scheduledDateUtc);
  });
  return result;
}
