import 'package:ai_financial_coach/features/transactions/domain/activity_date_group.dart';
import 'package:flutter_test/flutter_test.dart';

// Beta 1 Transaction UX Phase B, Checkpoint 1 (`docs/14_DECISION_LOG.md`
// ADR-025/026). Every `now`/`occurredAtLocal` pair below is a plain
// (non-UTC) `DateTime` fixture -- this file never touches the real
// clock or `.toLocal()`/`.toUtc()` conversion, matching the pure,
// deterministic contract `activity_date_group.dart` documents.

void main() {
  group('activityDateGroupFor', () {
    final DateTime now = DateTime(2026, 3, 15, 9, 30);

    test('same calendar day as now is Today, regardless of time-of-day', () {
      final ActivityDateGroup group = activityDateGroupFor(
        occurredAtLocal: DateTime(2026, 3, 15, 23, 59),
        now: now,
      );
      expect(group.kind, ActivityDateGroupKind.today);
      expect(group.label, 'Today');
      expect(group.dateKey, DateTime(2026, 3, 15));
    });

    test('the calendar day immediately before now is Yesterday', () {
      final ActivityDateGroup group = activityDateGroupFor(
        occurredAtLocal: DateTime(2026, 3, 14, 0, 1),
        now: now,
      );
      expect(group.kind, ActivityDateGroupKind.yesterday);
      expect(group.label, 'Yesterday');
      expect(group.dateKey, DateTime(2026, 3, 14));
    });

    test(
        'a late-night time yesterday is still Yesterday, not Today, even '
        'though barely any real time has elapsed (calendar-day math, not '
        'elapsed duration)', () {
      final ActivityDateGroup group = activityDateGroupFor(
        occurredAtLocal: DateTime(2026, 3, 14, 23, 59),
        now: DateTime(2026, 3, 15, 0, 1),
      );
      expect(group.kind, ActivityDateGroupKind.yesterday);
    });

    test('2-6 calendar days ago renders as the weekday name', () {
      // 2026-03-15 is a Sunday; 2 days before is Friday 2026-03-13.
      final ActivityDateGroup group = activityDateGroupFor(
        occurredAtLocal: DateTime(2026, 3, 13),
        now: now,
      );
      expect(group.kind, ActivityDateGroupKind.thisWeek);
      expect(group.label, 'Friday');
      expect(group.dateKey, DateTime(2026, 3, 13));
    });

    test('exactly 6 calendar days ago is still the weekday name', () {
      final ActivityDateGroup group = activityDateGroupFor(
        occurredAtLocal: DateTime(2026, 3, 9), // 6 days before 2026-03-15
        now: now,
      );
      expect(group.kind, ActivityDateGroupKind.thisWeek);
      expect(group.label, 'Monday');
    });

    test('exactly 7 calendar days ago falls out of the weekday bucket', () {
      final ActivityDateGroup group = activityDateGroupFor(
        occurredAtLocal: DateTime(2026, 3, 8), // 7 days before 2026-03-15
        now: now,
      );
      expect(group.kind, ActivityDateGroupKind.thisYear);
      expect(group.label, 'Mar 8');
    });

    test('older-than-a-week but same calendar year renders month/day only', () {
      final ActivityDateGroup group = activityDateGroupFor(
        occurredAtLocal: DateTime(2026, 1, 5),
        now: now,
      );
      expect(group.kind, ActivityDateGroupKind.thisYear);
      expect(group.label, 'Jan 5');
    });

    test('a previous calendar year renders month/day/year', () {
      final ActivityDateGroup group = activityDateGroupFor(
        occurredAtLocal: DateTime(2025, 12, 20),
        now: now,
      );
      expect(group.kind, ActivityDateGroupKind.older);
      expect(group.label, 'Dec 20, 2025');
    });

    test(
        'a future-dated transaction (after now) is never mislabeled Today/'
        'Yesterday -- it falls back to a formatted date', () {
      final ActivityDateGroup group = activityDateGroupFor(
        occurredAtLocal: DateTime(2026, 4, 1),
        now: now,
      );
      expect(group.kind, ActivityDateGroupKind.thisYear);
      expect(group.label, 'Apr 1');
    });
  });

  group('groupByActivityDate', () {
    final DateTime now = DateTime(2026, 3, 15, 9, 30);

    test('merges consecutive same-day items into one section, in order', () {
      final List<ActivityDateSection<String>> sections = groupByActivityDate<String>(
        items: <String>['today-a', 'today-b', 'yesterday-a'],
        occurredAtLocalOf: (String item) => switch (item) {
          'today-a' => DateTime(2026, 3, 15, 8),
          'today-b' => DateTime(2026, 3, 15, 20),
          _ => DateTime(2026, 3, 14, 12),
        },
        now: now,
      );

      expect(sections, hasLength(2));
      expect(sections[0].group.label, 'Today');
      expect(sections[0].items, <String>['today-a', 'today-b']);
      expect(sections[1].group.label, 'Yesterday');
      expect(sections[1].items, <String>['yesterday-a']);
    });

    test('an empty input produces no sections', () {
      final List<ActivityDateSection<String>> sections = groupByActivityDate<String>(
        items: const <String>[],
        occurredAtLocalOf: (String item) => now,
        now: now,
      );
      expect(sections, isEmpty);
    });

    test(
        'two different weeks that both land on the same weekday name are '
        'kept as two distinct sections, keyed by calendar day rather than '
        "by the weekday label text (regression: 'Monday' is not a unique "
        'key)', () {
      final List<ActivityDateSection<String>> sections = groupByActivityDate<String>(
        items: <String>['recent-monday', 'older-monday'],
        occurredAtLocalOf: (String item) => switch (item) {
          'recent-monday' => DateTime(2026, 3, 9), // Monday, 6 days ago
          _ => DateTime(2026, 2, 2), // an earlier Monday, >6 days ago
        },
        now: now,
      );

      expect(sections, hasLength(2));
      expect(sections[0].group.label, 'Monday'); // this-week bucket
      expect(sections[0].group.dateKey, DateTime(2026, 3, 9));
      expect(sections[1].group.label, isNot('Monday')); // falls into the older/date-formatted bucket
      expect(sections[1].group.dateKey, DateTime(2026, 2, 2));
    });

    test('items returned in each section are unmodifiable', () {
      final List<ActivityDateSection<String>> sections = groupByActivityDate<String>(
        items: <String>['a'],
        occurredAtLocalOf: (String item) => now,
        now: now,
      );
      expect(() => sections.single.items.add('b'), throwsUnsupportedError);
    });
  });
}
