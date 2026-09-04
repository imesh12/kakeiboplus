import 'package:ai_financial_coach/features/goals/domain/goal_target_date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeCalendarDateToUtc', () {
    test('preserves the selected calendar date for a local DateTime with a late time-of-day', () {
      // A non-UTC (local) DateTime, deliberately not midnight -- if the
      // implementation ever regressed to calling `.toUtc()` first, a
      // late-enough local time combined with a west-of-UTC device
      // offset could push this into the next UTC calendar day. Reading
      // .year/.month/.day directly (never `.toUtc()`) must always yield
      // exactly the selected date, regardless of the machine's own
      // timezone.
      final DateTime picked = DateTime(2026, 3, 15, 23, 45);
      final DateTime normalized = normalizeCalendarDateToUtc(picked);
      expect(normalized, DateTime.utc(2026, 3, 15));
      expect(normalized.isUtc, isTrue);
    });

    test('preserves the selected calendar date for an already-UTC DateTime with a late time-of-day', () {
      final DateTime picked = DateTime.utc(2026, 12, 31, 23, 59, 59);
      final DateTime normalized = normalizeCalendarDateToUtc(picked);
      expect(normalized, DateTime.utc(2026, 12, 31));
    });

    test('is idempotent -- normalizing an already-normalized date is a no-op', () {
      final DateTime once = normalizeCalendarDateToUtc(DateTime.utc(2026, 6, 1));
      final DateTime twice = normalizeCalendarDateToUtc(once);
      expect(twice, once);
    });
  });

  group('hasTargetDatePassed', () {
    test('a target date equal to today has NOT passed', () {
      final DateTime today = DateTime.utc(2026, 9, 3);
      expect(hasTargetDatePassed(targetDateUtc: today, todayUtc: today), isFalse);
    });

    test('a target date one day before today HAS passed', () {
      expect(
        hasTargetDatePassed(
          targetDateUtc: DateTime.utc(2026, 9, 2),
          todayUtc: DateTime.utc(2026, 9, 3),
        ),
        isTrue,
      );
    });

    test('a target date in the future has NOT passed', () {
      expect(
        hasTargetDatePassed(
          targetDateUtc: DateTime.utc(2026, 9, 4),
          todayUtc: DateTime.utc(2026, 9, 3),
        ),
        isFalse,
      );
    });

    test('compares by calendar date only, ignoring a non-midnight todayUtc time-of-day', () {
      expect(
        hasTargetDatePassed(
          targetDateUtc: DateTime.utc(2026, 9, 3),
          todayUtc: DateTime.utc(2026, 9, 3, 23, 59, 59),
        ),
        isFalse, // still "today", not passed, despite the late time-of-day
      );
    });
  });
}
