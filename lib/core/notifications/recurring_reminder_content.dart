import '../../features/recurring/domain/recurring_reminder_planner.dart';
import '../../features/recurring/domain/recurring_rule_kind.dart';
import '../money/money.dart';
import '../money/money_formatter.dart';

/// A resolved notification title/body pair -- pure presentation text,
/// never itself scheduled/platform-specific (see `ScheduledReminder`,
/// which carries these two strings verbatim).
class RecurringReminderContent {
  const RecurringReminderContent({required this.title, required this.body});

  final String title;
  final String body;
}

/// `kind`'s short, user-facing label for a reminder body -- deliberately
/// distinguishes income/expense/transfer (Beta 1 Task 4B requirement 6)
/// rather than a generic "payment"/"transaction" word.
String _kindLabel(RecurringRuleKind kind) => switch (kind) {
      RecurringRuleKind.expense => 'Expense',
      RecurringRuleKind.income => 'Income',
      RecurringRuleKind.transfer => 'Transfer',
    };

/// Builds the concise title/body for [reminder] -- e.g. title `"Rent
/// due"`, body `"Expense · ¥1,200"`. Always exactly this rule's own
/// amount in its own currency (via [MoneyFormatter], never a `double`)
/// -- never a running total, never a cross-currency conversion (Beta 1
/// Task 4B requirement 6: "no fake totals, no cross-currency
/// calculations").
RecurringReminderContent buildRecurringReminderContent(
  DesiredReminder reminder, {
  MoneyFormatter formatter = const MoneyFormatter(),
}) {
  final Money amount = Money.fromMinorUnits(reminder.amountMinorUnits, reminder.currencyCode);
  final String formattedAmount = formatter.format(amount);
  return RecurringReminderContent(
    title: '${reminder.ruleName} due',
    body: '${_kindLabel(reminder.kind)} · $formattedAmount',
  );
}
