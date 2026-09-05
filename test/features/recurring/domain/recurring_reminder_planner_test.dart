import 'package:ai_financial_coach/features/recurring/domain/recurrence_frequency.dart';
import 'package:ai_financial_coach/features/recurring/domain/recurring_reminder_planner.dart';
import 'package:ai_financial_coach/features/recurring/domain/recurring_rule_kind.dart';
import 'package:ai_financial_coach/features/recurring/domain/recurring_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

RecurringReminderRuleInput _dailyRule({
  required String ruleId,
  required String name,
  bool notificationsEnabled = true,
  DateTime? startDateUtc,
  RecurringRuleKind kind = RecurringRuleKind.expense,
}) =>
    RecurringReminderRuleInput(
      ruleId: ruleId,
      name: name,
      kind: kind,
      amountMinorUnits: 1000,
      currencyCode: 'JPY',
      notificationsEnabled: notificationsEnabled,
      schedule: RecurringSchedule(
        frequency: RecurrenceFrequency.daily,
        interval: 1,
        startDateUtc: startDateUtc ?? DateTime.utc(2026, 1, 1),
      ),
    );

void main() {
  final DateTime today = DateTime.utc(2026, 9, 5);

  group('planDesiredReminders', () {
    test('a rule with notificationsEnabled=false contributes nothing', () {
      final List<DesiredReminder> result = planDesiredReminders(
        rules: <RecurringReminderRuleInput>[
          _dailyRule(ruleId: 'r1', name: 'Coffee', notificationsEnabled: false),
        ],
        handledOccurrences: const <HandledOccurrenceKey>{},
        nowUtc: today,
      );
      expect(result, isEmpty);
    });

    test('includes today through the horizon (inclusive), excludes strictly-before-today', () {
      final List<DesiredReminder> result = planDesiredReminders(
        rules: <RecurringReminderRuleInput>[_dailyRule(ruleId: 'r1', name: 'Coffee')],
        handledOccurrences: const <HandledOccurrenceKey>{},
        nowUtc: today,
        horizonDays: 14,
      );

      expect(result.length, 15); // today + 14 more days, inclusive both ends
      expect(result.first.scheduledDateUtc, today);
      expect(result.last.scheduledDateUtc, today.add(const Duration(days: 14)));
      // Never anything before today ("overdue") -- that's the in-app
      // Overdue list's job, not a new local reminder.
      expect(result.any((DesiredReminder r) => r.scheduledDateUtc.isBefore(today)), isFalse);
    });

    test('a date with a handled (posted) occurrence is excluded', () {
      final DateTime handledDate = today;
      final List<DesiredReminder> result = planDesiredReminders(
        rules: <RecurringReminderRuleInput>[_dailyRule(ruleId: 'r1', name: 'Coffee')],
        handledOccurrences: <HandledOccurrenceKey>{
          HandledOccurrenceKey(ruleId: 'r1', scheduledDateUtc: handledDate),
        },
        nowUtc: today,
        horizonDays: 2,
      );
      expect(result.any((DesiredReminder r) => r.scheduledDateUtc == handledDate), isFalse);
      expect(result.length, 2); // today+1, today+2 remain
    });

    test('a date with a handled (skipped) occurrence is excluded exactly like posted', () {
      // planDesiredReminders takes only ruleId+date -- status is
      // deliberately not part of HandledOccurrenceKey, since posted and
      // skipped both mean "already dealt with" equally (correction 6).
      final DateTime handledDate = today.add(const Duration(days: 1));
      final List<DesiredReminder> result = planDesiredReminders(
        rules: <RecurringReminderRuleInput>[_dailyRule(ruleId: 'r1', name: 'Coffee')],
        handledOccurrences: <HandledOccurrenceKey>{
          HandledOccurrenceKey(ruleId: 'r1', scheduledDateUtc: handledDate),
        },
        nowUtc: today,
        horizonDays: 2,
      );
      expect(result.any((DesiredReminder r) => r.scheduledDateUtc == handledDate), isFalse);
      expect(result.length, 2);
    });

    test('two different rules due on the same date both appear, distinctly', () {
      final List<DesiredReminder> result = planDesiredReminders(
        rules: <RecurringReminderRuleInput>[
          _dailyRule(ruleId: 'r1', name: 'Rent'),
          _dailyRule(ruleId: 'r2', name: 'Salary', kind: RecurringRuleKind.income),
        ],
        handledOccurrences: const <HandledOccurrenceKey>{},
        nowUtc: today,
        horizonDays: 0,
      );
      expect(result.length, 2);
      expect(result.map((DesiredReminder r) => r.ruleId).toSet(), <String>{'r1', 'r2'});
      expect(result.every((DesiredReminder r) => r.scheduledDateUtc == today), isTrue);
    });

    test('a rule whose schedule starts after the horizon end contributes nothing', () {
      final List<DesiredReminder> result = planDesiredReminders(
        rules: <RecurringReminderRuleInput>[
          _dailyRule(ruleId: 'r1', name: 'Future', startDateUtc: today.add(const Duration(days: 30))),
        ],
        handledOccurrences: const <HandledOccurrenceKey>{},
        nowUtc: today,
        horizonDays: 14,
      );
      expect(result, isEmpty);
    });

    test('result is sorted deterministically by (ruleId, date) regardless of input order', () {
      final List<DesiredReminder> a = planDesiredReminders(
        rules: <RecurringReminderRuleInput>[
          _dailyRule(ruleId: 'z-rule', name: 'Z'),
          _dailyRule(ruleId: 'a-rule', name: 'A'),
        ],
        handledOccurrences: const <HandledOccurrenceKey>{},
        nowUtc: today,
        horizonDays: 0,
      );
      expect(a.first.ruleId, 'a-rule');
      expect(a.last.ruleId, 'z-rule');
    });
  });
}
