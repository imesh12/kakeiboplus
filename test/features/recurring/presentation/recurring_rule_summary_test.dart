import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/features/recurring/presentation/recurring_providers.dart';
import 'package:flutter_test/flutter_test.dart';

// Recurring UX checkpoint (full Recurring screen redesign,
// docs/14_DECISION_LOG.md ADR-TBD) -- unit coverage for the new
// per-rule summary selectors that back the redesigned screen's
// All/Active/Upcoming/Expired filter bar and search box. Every
// function under test here is pure (no Riverpod `ProviderContainer`,
// no Drift database) -- same precedent `subscription_providers_test.dart`
// already established for this file's sibling selectors. Directly
// builds [RecurringRuleRow] via its plain `const` constructor (Drift's
// generated data classes need no database to construct) so these
// tests stay fast and fully deterministic.
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
    String? categoryId,
    String? serviceIdentityKey,
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
      categoryId: categoryId,
      serviceIdentityKey: serviceIdentityKey,
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

  final DateTime today = DateTime.utc(2026, 6, 15);

  group('selectRecurringRuleSummaries', () {
    test('an active rule (schedule not yet ended) gets a non-null nextOccurrenceUtc', () {
      final RecurringRuleRow activeRule = rule(id: 'r1', startDate: DateTime.utc(2026, 1, 1));

      final List<RecurringRuleSummary> summaries = selectRecurringRuleSummaries(
        rules: <RecurringRuleRow>[activeRule],
        pendingItems: const <RecurringPendingItem>[],
        todayUtc: today,
      );

      expect(summaries, hasLength(1));
      expect(summaries.single.isActive, isTrue);
      expect(summaries.single.isExpired, isFalse);
      expect(summaries.single.nextOccurrenceUtc, isNotNull);
    });

    test('a rule whose schedule already ended before today gets a null nextOccurrenceUtc', () {
      final RecurringRuleRow endedRule = rule(
        id: 'r1',
        startDate: DateTime.utc(2025, 1, 1),
        endDate: DateTime.utc(2025, 6, 1),
      );

      final List<RecurringRuleSummary> summaries = selectRecurringRuleSummaries(
        rules: <RecurringRuleRow>[endedRule],
        pendingItems: const <RecurringPendingItem>[],
        todayUtc: today,
      );

      expect(summaries, hasLength(1));
      expect(summaries.single.isExpired, isTrue);
      expect(summaries.single.isActive, isFalse);
      expect(summaries.single.nextOccurrenceUtc, isNull);
    });

    test("each rule's single most urgent pending item is attached, by rule id", () {
      final RecurringRuleRow ruleA = rule(id: 'a');
      final RecurringRuleRow ruleB = rule(id: 'b');
      final List<RecurringPendingItem> items = <RecurringPendingItem>[
        pendingItem(ruleA, DateTime.utc(2026, 6, 10), RecurringItemUrgency.overdue),
        pendingItem(ruleB, DateTime.utc(2026, 6, 20), RecurringItemUrgency.upcoming),
      ];

      final List<RecurringRuleSummary> summaries = selectRecurringRuleSummaries(
        rules: <RecurringRuleRow>[ruleA, ruleB],
        pendingItems: items,
        todayUtc: today,
      );

      final RecurringRuleSummary summaryA = summaries.firstWhere((s) => s.rule.id == 'a');
      final RecurringRuleSummary summaryB = summaries.firstWhere((s) => s.rule.id == 'b');
      expect(summaryA.pendingItem?.urgency, RecurringItemUrgency.overdue);
      expect(summaryB.pendingItem?.urgency, RecurringItemUrgency.upcoming);
    });

    test('keeps only the FIRST pending item for a rule id when more than one is given', () {
      // Mirrors `selectSubscriptionPendingItems`'s own dedup guarantee
      // (ADR-031 precedent) -- never actually produced by
      // `recurringPendingItemsProvider` itself, but worth locking in
      // independently of what upstream currently guarantees.
      final RecurringRuleRow ruleA = rule(id: 'a');
      final List<RecurringPendingItem> items = <RecurringPendingItem>[
        pendingItem(ruleA, DateTime.utc(2026, 6, 10), RecurringItemUrgency.overdue),
        pendingItem(ruleA, DateTime.utc(2026, 7, 1), RecurringItemUrgency.upcoming),
      ];

      final List<RecurringRuleSummary> summaries = selectRecurringRuleSummaries(
        rules: <RecurringRuleRow>[ruleA],
        pendingItems: items,
        todayUtc: today,
      );

      expect(summaries.single.pendingItem?.scheduledDateUtc, DateTime.utc(2026, 6, 10));
    });

    test('a rule with no matching pending item gets a null pendingItem, not an error', () {
      final RecurringRuleRow ruleA = rule(id: 'a');

      final List<RecurringRuleSummary> summaries = selectRecurringRuleSummaries(
        rules: <RecurringRuleRow>[ruleA],
        pendingItems: const <RecurringPendingItem>[],
        todayUtc: today,
      );

      expect(summaries.single.pendingItem, isNull);
    });

    test('preserves the input rule order', () {
      final RecurringRuleRow ruleA = rule(id: 'a');
      final RecurringRuleRow ruleB = rule(id: 'b');
      final RecurringRuleRow ruleC = rule(id: 'c');

      final List<RecurringRuleSummary> summaries = selectRecurringRuleSummaries(
        rules: <RecurringRuleRow>[ruleC, ruleA, ruleB],
        pendingItems: const <RecurringPendingItem>[],
        todayUtc: today,
      );

      expect(summaries.map((s) => s.rule.id).toList(), <String>['c', 'a', 'b']);
    });

    test('an empty rule list produces an empty result', () {
      expect(
        selectRecurringRuleSummaries(
          rules: const <RecurringRuleRow>[],
          pendingItems: const <RecurringPendingItem>[],
          todayUtc: today,
        ),
        isEmpty,
      );
    });
  });

  group('isUpcomingEligible', () {
    RecurringRuleSummary summaryWith(RecurringPendingItem? item) => RecurringRuleSummary(
      rule: rule(id: 'r1'),
      nextOccurrenceUtc: today,
      pendingItem: item,
    );

    test('false when the rule has no pending item at all', () {
      expect(isUpcomingEligible(summaryWith(null), today), isFalse);
    });

    test('true for an overdue pending item regardless of date', () {
      final RecurringPendingItem item = pendingItem(
        rule(id: 'r1'),
        today.subtract(const Duration(days: 30)),
        RecurringItemUrgency.overdue,
      );
      expect(isUpcomingEligible(summaryWith(item), today), isTrue);
    });

    test('true for a due-today pending item', () {
      final RecurringPendingItem item = pendingItem(rule(id: 'r1'), today, RecurringItemUrgency.dueToday);
      expect(isUpcomingEligible(summaryWith(item), today), isTrue);
    });

    test('true for an upcoming item within kHomeUpcomingWindowDays', () {
      final RecurringPendingItem item = pendingItem(
        rule(id: 'r1'),
        today.add(const Duration(days: kHomeUpcomingWindowDays)),
        RecurringItemUrgency.upcoming,
      );
      expect(isUpcomingEligible(summaryWith(item), today), isTrue);
    });

    test('false for an upcoming item beyond kHomeUpcomingWindowDays', () {
      final RecurringPendingItem item = pendingItem(
        rule(id: 'r1'),
        today.add(const Duration(days: kHomeUpcomingWindowDays + 1)),
        RecurringItemUrgency.upcoming,
      );
      expect(isUpcomingEligible(summaryWith(item), today), isFalse);
    });
  });

  group('selectRecurringRuleSummariesForFilter', () {
    RecurringRuleSummary activeSummary(String id, {RecurringPendingItem? pending}) => RecurringRuleSummary(
      rule: rule(id: id),
      nextOccurrenceUtc: today,
      pendingItem: pending,
    );
    RecurringRuleSummary expiredSummary(String id) =>
        RecurringRuleSummary(rule: rule(id: id), nextOccurrenceUtc: null, pendingItem: null);

    test('RecurringListFilter.all returns every summary unfiltered', () {
      final List<RecurringRuleSummary> summaries = <RecurringRuleSummary>[
        activeSummary('a'),
        expiredSummary('b'),
      ];
      expect(
        selectRecurringRuleSummariesForFilter(summaries, RecurringListFilter.all, today),
        summaries,
      );
    });

    test('RecurringListFilter.active keeps only non-expired summaries', () {
      final List<RecurringRuleSummary> summaries = <RecurringRuleSummary>[
        activeSummary('a'),
        expiredSummary('b'),
      ];
      final List<RecurringRuleSummary> result = selectRecurringRuleSummariesForFilter(
        summaries,
        RecurringListFilter.active,
        today,
      );
      expect(result.map((s) => s.rule.id).toList(), <String>['a']);
    });

    test('RecurringListFilter.expired keeps only expired summaries', () {
      final List<RecurringRuleSummary> summaries = <RecurringRuleSummary>[
        activeSummary('a'),
        expiredSummary('b'),
      ];
      final List<RecurringRuleSummary> result = selectRecurringRuleSummariesForFilter(
        summaries,
        RecurringListFilter.expired,
        today,
      );
      expect(result.map((s) => s.rule.id).toList(), <String>['b']);
    });

    test('RecurringListFilter.upcoming applies isUpcomingEligible per summary', () {
      final RecurringRuleRow ruleA = rule(id: 'a');
      final RecurringRuleRow ruleB = rule(id: 'b');
      final List<RecurringRuleSummary> summaries = <RecurringRuleSummary>[
        RecurringRuleSummary(
          rule: ruleA,
          nextOccurrenceUtc: today,
          pendingItem: pendingItem(ruleA, today, RecurringItemUrgency.dueToday),
        ),
        RecurringRuleSummary(
          rule: ruleB,
          nextOccurrenceUtc: today,
          pendingItem: pendingItem(
            ruleB,
            today.add(const Duration(days: kHomeUpcomingWindowDays + 5)),
            RecurringItemUrgency.upcoming,
          ),
        ),
      ];
      final List<RecurringRuleSummary> result = selectRecurringRuleSummariesForFilter(
        summaries,
        RecurringListFilter.upcoming,
        today,
      );
      expect(result.map((s) => s.rule.id).toList(), <String>['a']);
    });

    test('an empty summary list produces an empty result for every filter', () {
      for (final RecurringListFilter filter in RecurringListFilter.values) {
        expect(
          selectRecurringRuleSummariesForFilter(const <RecurringRuleSummary>[], filter, today),
          isEmpty,
        );
      }
    });
  });

  group('searchRecurringRuleSummaries', () {
    RecurringRuleSummary summaryFor(RecurringRuleRow rule) =>
        RecurringRuleSummary(rule: rule, nextOccurrenceUtc: today, pendingItem: null);

    test('an empty/blank query returns every summary unfiltered', () {
      final List<RecurringRuleSummary> summaries = <RecurringRuleSummary>[
        summaryFor(rule(id: 'a', name: 'Netflix')),
        summaryFor(rule(id: 'b', name: 'Rent')),
      ];
      expect(searchRecurringRuleSummaries(summaries, '', const <String, CategoryRow>{}), summaries);
      expect(searchRecurringRuleSummaries(summaries, '   ', const <String, CategoryRow>{}), summaries);
    });

    test('matches case-insensitively on the rule name', () {
      final List<RecurringRuleSummary> summaries = <RecurringRuleSummary>[
        summaryFor(rule(id: 'a', name: 'Netflix')),
        summaryFor(rule(id: 'b', name: 'Rent')),
      ];
      final List<RecurringRuleSummary> result = searchRecurringRuleSummaries(
        summaries,
        'NET',
        const <String, CategoryRow>{},
      );
      expect(result.map((s) => s.rule.id).toList(), <String>['a']);
    });

    test('matches on the resolved service identity proper name even when it differs from the rule name', () {
      final List<RecurringRuleSummary> summaries = <RecurringRuleSummary>[
        summaryFor(rule(id: 'a', name: 'Streaming bill', serviceIdentityKey: 'netflix')),
        summaryFor(rule(id: 'b', name: 'Rent')),
      ];
      final List<RecurringRuleSummary> result = searchRecurringRuleSummaries(
        summaries,
        'netflix',
        const <String, CategoryRow>{},
      );
      expect(result.map((s) => s.rule.id).toList(), <String>['a']);
    });

    test('matches on the resolved category name via the supplied lookup map', () {
      const CategoryRow dining = CategoryRow(
        id: 'cat-1',
        type: 'expense',
        name: 'Dining',
        sortOrder: 0,
        isSystem: false,
        isActive: true,
      );
      final List<RecurringRuleSummary> summaries = <RecurringRuleSummary>[
        summaryFor(rule(id: 'a', name: 'Lunch club', categoryId: 'cat-1')),
        summaryFor(rule(id: 'b', name: 'Rent')),
      ];
      final List<RecurringRuleSummary> result = searchRecurringRuleSummaries(summaries, 'dining', <String, CategoryRow>{
        'cat-1': dining,
      });
      expect(result.map((s) => s.rule.id).toList(), <String>['a']);
    });

    test('a query matching nothing produces an empty result', () {
      final List<RecurringRuleSummary> summaries = <RecurringRuleSummary>[
        summaryFor(rule(id: 'a', name: 'Netflix')),
      ];
      expect(
        searchRecurringRuleSummaries(summaries, 'zzz-no-match', const <String, CategoryRow>{}),
        isEmpty,
      );
    });
  });
}
