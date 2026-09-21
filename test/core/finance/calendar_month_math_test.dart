import 'package:ai_financial_coach/core/finance/calendar_month_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('lastDayOfMonth', () {
    test('ordinary months', () {
      expect(lastDayOfMonth(2026, 1), 31);
      expect(lastDayOfMonth(2026, 4), 30);
    });

    test('February in a non-leap year is 28', () {
      expect(lastDayOfMonth(2026, 2), 28);
    });

    test('February in a leap year is 29', () {
      expect(lastDayOfMonth(2028, 2), 29);
    });

    test('December rolls into the following January correctly', () {
      expect(lastDayOfMonth(2026, 12), 31);
    });
  });

  group('addWholeCalendarMonths -- item 13: Jan 31 + 1 month', () {
    test('Jan 31 (non-leap year) + 1 month clamps to Feb 28', () {
      final DateTime result = addWholeCalendarMonths(DateTime.utc(2026, 1, 31), 1);
      expect(result, DateTime.utc(2026, 2, 28));
    });

    test('Jan 31 (leap year) + 1 month clamps to Feb 29', () {
      final DateTime result = addWholeCalendarMonths(DateTime.utc(2028, 1, 31), 1);
      expect(result, DateTime.utc(2028, 2, 29));
    });

    test('Jan 31 + 2 months returns to 31 -- proves it is not "Feb 28 + 1 month"', () {
      final DateTime result = addWholeCalendarMonths(DateTime.utc(2026, 1, 31), 2);
      expect(result, DateTime.utc(2026, 3, 31));
    });
  });

  group('addWholeCalendarMonths -- item 14: leap-day behavior', () {
    test('Feb 29 (leap year) + 12 months clamps to Feb 28 the following (non-leap) year', () {
      final DateTime result = addWholeCalendarMonths(DateTime.utc(2028, 2, 29), 12);
      expect(result, DateTime.utc(2029, 2, 28));
    });

    test('Feb 29 (leap year) + 48 months lands back on Feb 29 the next leap year', () {
      final DateTime result = addWholeCalendarMonths(DateTime.utc(2028, 2, 29), 48);
      expect(result, DateTime.utc(2032, 2, 29));
    });
  });

  group('addWholeCalendarMonths -- item 15: month-end/year transition behavior', () {
    test('Dec 31 + 1 month rolls into January of the next year, still on the 31st', () {
      final DateTime result = addWholeCalendarMonths(DateTime.utc(2026, 12, 31), 1);
      expect(result, DateTime.utc(2027, 1, 31));
    });

    test('Oct 31 + 4 months clamps at Feb 28 (non-leap year), still measured from Oct 31', () {
      final DateTime result = addWholeCalendarMonths(DateTime.utc(2026, 10, 31), 4);
      expect(result, DateTime.utc(2027, 2, 28));
    });

    test('Aug 31 + 1 month clamps to Sep 30', () {
      final DateTime result = addWholeCalendarMonths(DateTime.utc(2026, 8, 31), 1);
      expect(result, DateTime.utc(2026, 9, 30));
    });

    test('a non-clamped day-of-month is never altered', () {
      final DateTime result = addWholeCalendarMonths(DateTime.utc(2026, 3, 15), 3);
      expect(result, DateTime.utc(2026, 6, 15));
    });

    test('adding zero months returns the anchor unchanged', () {
      final DateTime result = addWholeCalendarMonths(DateTime.utc(2026, 1, 31), 0);
      expect(result, DateTime.utc(2026, 1, 31));
    });
  });
}
