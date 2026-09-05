import 'package:ai_financial_coach/core/notifications/recurring_reminder_content.dart';
import 'package:ai_financial_coach/features/recurring/domain/recurring_reminder_planner.dart';
import 'package:ai_financial_coach/features/recurring/domain/recurring_rule_kind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildRecurringReminderContent', () {
    test('title carries the rule name, body carries kind and this rule\'s own amount', () {
      final DesiredReminder reminder = DesiredReminder(
        ruleId: 'rule-1',
        scheduledDateUtc: DateTime.utc(2026, 9, 5),
        ruleName: 'Rent',
        kind: RecurringRuleKind.expense,
        amountMinorUnits: 120000,
        currencyCode: 'JPY',
      );

      final RecurringReminderContent content = buildRecurringReminderContent(reminder);

      expect(content.title, contains('Rent'));
      expect(content.body, contains('Expense'));
      expect(content.body, contains('120,000')); // JPY has 0 minor units -- ¥120,000, never ¥1,200.00
    });

    test('distinguishes income/expense/transfer in the body', () {
      RecurringReminderContent contentFor(RecurringRuleKind kind) => buildRecurringReminderContent(
            DesiredReminder(
              ruleId: 'rule-1',
              scheduledDateUtc: DateTime.utc(2026, 9, 5),
              ruleName: 'Something',
              kind: kind,
              amountMinorUnits: 100,
              currencyCode: 'USD',
            ),
          );

      expect(contentFor(RecurringRuleKind.expense).body, contains('Expense'));
      expect(contentFor(RecurringRuleKind.income).body, contains('Income'));
      expect(contentFor(RecurringRuleKind.transfer).body, contains('Transfer'));
    });

    test('never fabricates a total across rules -- only this reminder\'s own amount appears', () {
      final RecurringReminderContent content = buildRecurringReminderContent(
        DesiredReminder(
          ruleId: 'rule-1',
          scheduledDateUtc: DateTime.utc(2026, 9, 5),
          ruleName: 'Coffee',
          kind: RecurringRuleKind.expense,
          amountMinorUnits: 500,
          currencyCode: 'USD',
        ),
      );
      expect(content.body, contains(r'$5.00'));
    });
  });
}
