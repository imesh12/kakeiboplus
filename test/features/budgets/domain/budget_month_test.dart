import 'package:ai_financial_coach/features/budgets/domain/budget_month.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BudgetMonth construction', () {
    test('accepts a valid year/month', () {
      final BudgetMonth month = BudgetMonth(year: 2026, month: 9);
      expect(month.year, 2026);
      expect(month.month, 9);
    });

    test('rejects month 0 and month 13', () {
      expect(() => BudgetMonth(year: 2026, month: 0), throwsArgumentError);
      expect(() => BudgetMonth(year: 2026, month: 13), throwsArgumentError);
    });

    test('rejects a year outside the supported range', () {
      expect(() => BudgetMonth(year: 1999, month: 1), throwsArgumentError);
      expect(() => BudgetMonth(year: 2101, month: 1), throwsArgumentError);
    });

    test('accepts the boundary years', () {
      expect(() => BudgetMonth(year: BudgetMonth.minYear, month: 1), returnsNormally);
      expect(() => BudgetMonth(year: BudgetMonth.maxYear, month: 12), returnsNormally);
    });

    test('BudgetMonth.fromUtc extracts the year/month of a UTC instant', () {
      final BudgetMonth month = BudgetMonth.fromUtc(DateTime.utc(2026, 9, 15, 23, 59));
      expect(month, BudgetMonth(year: 2026, month: 9));
    });
  });

  group('BudgetMonth boundaries', () {
    test('startUtc / endUtcInclusive bracket exactly one calendar month', () {
      final BudgetMonth month = BudgetMonth(year: 2026, month: 2);
      expect(month.startUtc, DateTime.utc(2026, 2, 1));
      expect(month.endUtcInclusive, DateTime.utc(2026, 3).subtract(const Duration(microseconds: 1)));
    });

    test('December rolls over into next January correctly', () {
      final BudgetMonth month = BudgetMonth(year: 2026, month: 12);
      expect(month.startUtc, DateTime.utc(2026, 12, 1));
      expect(month.endUtcInclusive, DateTime.utc(2027, 1).subtract(const Duration(microseconds: 1)));
      expect(month.totalDays, 31);
    });

    test('totalDays is correct for a 30-day month, a 31-day month, and February', () {
      expect(BudgetMonth(year: 2026, month: 4).totalDays, 30); // April
      expect(BudgetMonth(year: 2026, month: 1).totalDays, 31); // January
      expect(BudgetMonth(year: 2026, month: 2).totalDays, 28); // Feb 2026: not a leap year
    });

    test('totalDays correctly identifies a leap February', () {
      expect(BudgetMonth(year: 2024, month: 2).totalDays, 29); // 2024 is a leap year
      expect(BudgetMonth(year: 2023, month: 2).totalDays, 28); // 2023 is not
    });
  });

  group('BudgetMonth ordering and equality', () {
    test('compareTo / < / > order months by year then month', () {
      final BudgetMonth jan = BudgetMonth(year: 2026, month: 1);
      final BudgetMonth sep = BudgetMonth(year: 2026, month: 9);
      final BudgetMonth nextJan = BudgetMonth(year: 2027, month: 1);
      expect(jan < sep, isTrue);
      expect(sep < nextJan, isTrue);
      expect(nextJan > jan, isTrue);
      expect(sep.compareTo(sep), 0);
    });

    test('two BudgetMonths with the same year/month are equal and hash equal', () {
      final BudgetMonth a = BudgetMonth(year: 2026, month: 9);
      final BudgetMonth b = BudgetMonth(year: 2026, month: 9);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('next / previous roll over year boundaries correctly', () {
      expect(BudgetMonth(year: 2026, month: 12).next, BudgetMonth(year: 2027, month: 1));
      expect(BudgetMonth(year: 2027, month: 1).previous, BudgetMonth(year: 2026, month: 12));
      expect(BudgetMonth(year: 2026, month: 9).next, BudgetMonth(year: 2026, month: 10));
    });

    test('toKey formats as zero-padded YYYY-MM', () {
      expect(BudgetMonth(year: 2026, month: 9).toKey(), '2026-09');
      expect(BudgetMonth(year: 2026, month: 12).toKey(), '2026-12');
    });
  });
}
