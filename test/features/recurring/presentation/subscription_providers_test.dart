import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/features/recurring/presentation/recurring_providers.dart';
import 'package:ai_financial_coach/features/recurring/presentation/subscription_providers.dart';
import 'package:flutter_test/flutter_test.dart';

// Checkpoint 11 -- Recurring + Subscriptions V1. Every function under
// test here is pure (no Riverpod `ProviderContainer`, no Drift
// database) -- same precedent `selectHomeRecurringItem`'s own dedicated
// coverage established. Directly builds [RecurringRuleRow] via its
// plain `const` constructor (Drift's generated data classes need no
// database to construct) so these tests stay fast and fully
// deterministic.
void main() {
  RecurringRuleRow rule({
    required String id,
    String kind = 'expense',
    String name = 'Netflix',
    int amountMinorUnits = 1500,
    String currencyCode = 'USD',
    String frequency = 'monthly',
    int interval = 1,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final DateTime start = startDate ?? DateTime.utc(2026, 1, 1);
    return RecurringRuleRow(
      id: id,
      profileId: 'profile-1',
      kind: kind,
      name: name,
      amountMinorUnits: amountMinorUnits,
      currencyCode: currencyCode,
      accountId: 'account-1',
      frequency: frequency,
      interval: interval,
      startDate: start,
      endDate: endDate,
      createdAt: start,
      updatedAt: start,
      notificationsEnabled: false,
      syncVersion: 0,
      syncStatus: 'localOnly',
    );
  }

  RecurringPendingItem pendingItem(RecurringRuleRow rule, DateTime date, RecurringItemUrgency urgency) =>
      RecurringPendingItem(rule: rule, scheduledDateUtc: date, urgency: urgency);

  group('isSubscriptionRule', () {
    test('true only for an expense-kind rule', () {
      expect(isSubscriptionRule(rule(id: 'r1', kind: 'expense')), isTrue);
      expect(isSubscriptionRule(rule(id: 'r2', kind: 'income')), isFalse);
      expect(isSubscriptionRule(rule(id: 'r3', kind: 'transfer')), isFalse);
    });
  });

  group('selectSubscriptionPendingItems', () {
    test('drops non-expense rules entirely', () {
      final RecurringRuleRow expenseRule = rule(id: 'e1');
      final RecurringRuleRow incomeRule = rule(id: 'i1', kind: 'income');
      final List<RecurringPendingItem> items = <RecurringPendingItem>[
        pendingItem(expenseRule, DateTime.utc(2026, 1, 1), RecurringItemUrgency.dueToday),
        pendingItem(incomeRule, DateTime.utc(2026, 1, 1), RecurringItemUrgency.dueToday),
      ];

      final List<RecurringPendingItem> result = selectSubscriptionPendingItems(items);

      expect(result, hasLength(1));
      expect(result.single.rule.id, 'e1');
    });

    test('keeps only the first (most urgent) item per rule id', () {
      // Same rule contributing two dates would never actually happen
      // from `recurringPendingItemsProvider` itself (a rule only ever
      // contributes one overdue/due-today backlog OR one upcoming
      // preview -- never both), but this selector's own dedup guarantee
      // is independently worth locking in regardless of what upstream
      // currently guarantees.
      final RecurringRuleRow subscriptionRule = rule(id: 's1');
      final List<RecurringPendingItem> items = <RecurringPendingItem>[
        pendingItem(subscriptionRule, DateTime.utc(2026, 1, 1), RecurringItemUrgency.overdue),
        pendingItem(subscriptionRule, DateTime.utc(2026, 2, 1), RecurringItemUrgency.upcoming),
      ];

      final List<RecurringPendingItem> result = selectSubscriptionPendingItems(items);

      expect(result, hasLength(1));
      expect(result.single.scheduledDateUtc, DateTime.utc(2026, 1, 1));
    });

    test('preserves the input priority order across multiple subscriptions', () {
      final RecurringRuleRow overdueRule = rule(id: 'overdue-rule');
      final RecurringRuleRow upcomingRule = rule(id: 'upcoming-rule');
      // Already sorted overdue-first, matching
      // `recurringPendingItemsProvider`'s own contract.
      final List<RecurringPendingItem> items = <RecurringPendingItem>[
        pendingItem(overdueRule, DateTime.utc(2025, 12, 1), RecurringItemUrgency.overdue),
        pendingItem(upcomingRule, DateTime.utc(2026, 2, 1), RecurringItemUrgency.upcoming),
      ];

      final List<RecurringPendingItem> result = selectSubscriptionPendingItems(items);

      expect(result.map((i) => i.rule.id).toList(), <String>['overdue-rule', 'upcoming-rule']);
    });

    test('an empty input produces an empty result', () {
      expect(selectSubscriptionPendingItems(const <RecurringPendingItem>[]), isEmpty);
    });
  });

  group('computeSubscriptionEstimatedTotals', () {
    final DateTime today = DateTime.utc(2026, 6, 15);

    test('a single active monthly expense rule produces one currency total', () {
      final List<SubscriptionCurrencyTotal> totals = computeSubscriptionEstimatedTotals(
        activeRules: <RecurringRuleRow>[
          rule(id: 'r1', amountMinorUnits: 150000, currencyCode: 'JPY'),
        ],
        todayUtc: today,
      );

      expect(totals, hasLength(1));
      expect(totals.single.currencyCode, 'JPY');
      expect(totals.single.monthlyEstimateMinorUnits, 150000);
      expect(totals.single.yearlyEstimateMinorUnits, 1800000);
      expect(totals.single.subscriptionCount, 1);
    });

    test('multiple rules in the same currency are summed together', () {
      final List<SubscriptionCurrencyTotal> totals = computeSubscriptionEstimatedTotals(
        activeRules: <RecurringRuleRow>[
          rule(id: 'r1', amountMinorUnits: 100000, currencyCode: 'JPY'),
          rule(id: 'r2', amountMinorUnits: 50000, currencyCode: 'JPY'),
        ],
        todayUtc: today,
      );

      expect(totals, hasLength(1));
      expect(totals.single.monthlyEstimateMinorUnits, 150000);
      expect(totals.single.subscriptionCount, 2);
    });

    test('multiple currencies are kept separate, never summed together', () {
      final List<SubscriptionCurrencyTotal> totals = computeSubscriptionEstimatedTotals(
        activeRules: <RecurringRuleRow>[
          rule(id: 'r1', amountMinorUnits: 150000, currencyCode: 'JPY'),
          rule(id: 'r2', amountMinorUnits: 999, currencyCode: 'KWD'),
        ],
        todayUtc: today,
      );

      expect(totals, hasLength(2));
      // Sorted by currency code for a deterministic order.
      expect(totals.map((t) => t.currencyCode).toList(), <String>['JPY', 'KWD']);
      final SubscriptionCurrencyTotal jpy = totals.firstWhere((t) => t.currencyCode == 'JPY');
      final SubscriptionCurrencyTotal kwd = totals.firstWhere((t) => t.currencyCode == 'KWD');
      expect(jpy.monthlyEstimateMinorUnits, 150000);
      expect(kwd.monthlyEstimateMinorUnits, 999);
      // Each currency's own figure is exactly what its single rule
      // contributes -- unaffected by the other currency's rule being
      // present at all. There is no combined/summed-across-currencies
      // field anywhere on this return type (ADR-031) -- the absence of
      // one is itself the "never fabricate a cross-currency total"
      // guarantee, and the two assertions above already confirm
      // neither entry leaked into the other.
    });

    test('income and transfer rules never contribute to the totals', () {
      final List<SubscriptionCurrencyTotal> totals = computeSubscriptionEstimatedTotals(
        activeRules: <RecurringRuleRow>[
          rule(id: 'r1', kind: 'income', amountMinorUnits: 300000, currencyCode: 'JPY'),
          rule(id: 'r2', kind: 'transfer', amountMinorUnits: 200000, currencyCode: 'JPY'),
        ],
        todayUtc: today,
      );

      expect(totals, isEmpty);
    });

    test('a rule whose schedule has already ended is excluded', () {
      final List<SubscriptionCurrencyTotal> totals = computeSubscriptionEstimatedTotals(
        activeRules: <RecurringRuleRow>[
          rule(
            id: 'r1',
            amountMinorUnits: 150000,
            currencyCode: 'JPY',
            startDate: DateTime.utc(2025, 1, 1),
            endDate: DateTime.utc(2025, 6, 1), // ended well before `today`
          ),
        ],
        todayUtc: today,
      );

      expect(totals, isEmpty);
    });

    test('a rule whose schedule has not started yet is still included', () {
      // `occurrenceOnOrAfter` returns `startDate` itself when `today` is
      // before it -- a not-yet-started rule still has a real future
      // occurrence, so it legitimately counts toward the steady-state
      // estimate.
      final List<SubscriptionCurrencyTotal> totals = computeSubscriptionEstimatedTotals(
        activeRules: <RecurringRuleRow>[
          rule(
            id: 'r1',
            amountMinorUnits: 150000,
            currencyCode: 'JPY',
            startDate: DateTime.utc(2027, 1, 1), // starts after `today`
          ),
        ],
        todayUtc: today,
      );

      expect(totals, hasLength(1));
      expect(totals.single.subscriptionCount, 1);
    });

    test('an empty rule list produces an empty totals list', () {
      expect(
        computeSubscriptionEstimatedTotals(activeRules: const <RecurringRuleRow>[], todayUtc: today),
        isEmpty,
      );
    });
  });
}
