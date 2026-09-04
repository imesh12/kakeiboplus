import 'package:ai_financial_coach/core/money/money.dart';
import 'package:ai_financial_coach/features/budgets/domain/budget_calculation.dart';
import 'package:ai_financial_coach/features/budgets/domain/budget_month.dart';
import 'package:ai_financial_coach/features/budgets/domain/budget_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BudgetCalculator.evaluate -- current month', () {
    test('mid-month: computes remaining, daily recommendation, projection, and status', () {
      final BudgetCalculation calc = BudgetCalculator.evaluate(
        month: BudgetMonth(year: 2026, month: 9),
        todayUtc: DateTime.utc(2026, 9, 10), // day 10 of a 30-day month
        budgeted: Money.fromMinorUnits(3000, 'USD'),
        spent: Money.fromMinorUnits(1000, 'USD'),
      );
      expect(calc.remaining, Money.fromMinorUnits(2000, 'USD'));
      // remainingDaysInclusive = 30 - 10 + 1 = 21
      expect(calc.dailyRecommendedSpend, Money.fromMinorUnits(2000 ~/ 21, 'USD'));
      // projected = 1000 * 30 ~/ 10 = 3000
      expect(calc.projectedMonthEndSpend, Money.fromMinorUnits(3000, 'USD'));
      expect(calc.status, BudgetStatus.healthy);
      expect(calc.isFutureMonth, isFalse);
    });

    test('day 1 of the month: daysElapsedInclusive is 1, never 0', () {
      final BudgetCalculation calc = BudgetCalculator.evaluate(
        month: BudgetMonth(year: 2026, month: 9),
        todayUtc: DateTime.utc(2026, 9, 1),
        budgeted: Money.fromMinorUnits(3000, 'USD'),
        spent: Money.fromMinorUnits(100, 'USD'),
      );
      expect(calc.status, isNotNull);
      // projected = 100 * 30 ~/ 1 = 3000
      expect(calc.projectedMonthEndSpend, Money.fromMinorUnits(3000, 'USD'));
    });

    test('last day of the month: remainingDaysInclusive is exactly 1', () {
      final BudgetCalculation calc = BudgetCalculator.evaluate(
        month: BudgetMonth(year: 2026, month: 9), // 30-day month
        todayUtc: DateTime.utc(2026, 9, 30),
        budgeted: Money.fromMinorUnits(3000, 'USD'),
        spent: Money.fromMinorUnits(2500, 'USD'),
      );
      expect(calc.remaining, Money.fromMinorUnits(500, 'USD'));
      expect(calc.dailyRecommendedSpend, Money.fromMinorUnits(500, 'USD'));
    });

    test('zero spending so far: healthy, full remaining amount, no overspend', () {
      final BudgetCalculation calc = BudgetCalculator.evaluate(
        month: BudgetMonth(year: 2026, month: 9),
        todayUtc: DateTime.utc(2026, 9, 5),
        budgeted: Money.fromMinorUnits(3000, 'USD'),
        spent: Money.zero('USD'),
      );
      expect(calc.status, BudgetStatus.healthy);
      expect(calc.remaining, Money.fromMinorUnits(3000, 'USD'));
      expect(calc.projectedMonthEndSpend, Money.zero('USD'));
    });

    test('exact budget usage is not overBudget', () {
      final BudgetCalculation calc = BudgetCalculator.evaluate(
        month: BudgetMonth(year: 2026, month: 9),
        todayUtc: DateTime.utc(2026, 9, 15),
        budgeted: Money.fromMinorUnits(3000, 'USD'),
        spent: Money.fromMinorUnits(3000, 'USD'),
      );
      expect(calc.remaining, Money.zero('USD'));
      expect(calc.status, isNot(BudgetStatus.overBudget));
      expect(calc.dailyRecommendedSpend, Money.zero('USD'));
    });

    test('overspent budget: remaining is negative and daily recommendation is zero, never negative', () {
      final BudgetCalculation calc = BudgetCalculator.evaluate(
        month: BudgetMonth(year: 2026, month: 9),
        todayUtc: DateTime.utc(2026, 9, 15),
        budgeted: Money.fromMinorUnits(3000, 'USD'),
        spent: Money.fromMinorUnits(3500, 'USD'),
      );
      expect(calc.remaining, Money.fromMinorUnits(-500, 'USD'));
      expect(calc.status, BudgetStatus.overBudget);
      expect(calc.dailyRecommendedSpend, Money.zero('USD'));
    });
  });

  group('BudgetCalculator.evaluate -- historical month', () {
    test('daysElapsedInclusive is the full month, and projection equals actual spend exactly', () {
      final BudgetCalculation calc = BudgetCalculator.evaluate(
        month: BudgetMonth(year: 2026, month: 6), // June, entirely in the past
        todayUtc: DateTime.utc(2026, 9, 10),
        budgeted: Money.fromMinorUnits(5000, 'USD'),
        spent: Money.fromMinorUnits(4200, 'USD'),
      );
      expect(calc.isFutureMonth, isFalse);
      expect(calc.projectedMonthEndSpend, calc.spent);
      // For a fully-elapsed month, expectedSpendSoFar always equals the
      // full budget exactly (daysElapsedInclusive == totalDaysInMonth),
      // so a historical month's status can only ever be healthy or
      // overBudget -- caution (which means "ahead of a *partial* pace")
      // cannot occur once the whole period has already happened.
      expect(calc.status, BudgetStatus.healthy);
    });

    test('a historical month can still be overBudget if spending exceeded the total', () {
      final BudgetCalculation calc = BudgetCalculator.evaluate(
        month: BudgetMonth(year: 2026, month: 6),
        todayUtc: DateTime.utc(2026, 9, 10),
        budgeted: Money.fromMinorUnits(5000, 'USD'),
        spent: Money.fromMinorUnits(5001, 'USD'),
      );
      expect(calc.status, BudgetStatus.overBudget);
    });

    test('a historical month status is judged against the complete budget, not a partial pace', () {
      // Spent 4999 of a 5000 budget in a fully-elapsed month: since the
      // whole month already happened, expectedSpendSoFar == budgeted, so
      // this is healthy (under the full budget), not caution.
      final BudgetCalculation calc = BudgetCalculator.evaluate(
        month: BudgetMonth(year: 2026, month: 6),
        todayUtc: DateTime.utc(2026, 9, 10),
        budgeted: Money.fromMinorUnits(5000, 'USD'),
        spent: Money.fromMinorUnits(4999, 'USD'),
      );
      expect(calc.status, BudgetStatus.healthy);
    });
  });

  group('BudgetCalculator.evaluate -- future month', () {
    test('dailyRecommendedSpend, projectedMonthEndSpend, and status are all null -- not fabricated', () {
      final BudgetCalculation calc = BudgetCalculator.evaluate(
        month: BudgetMonth(year: 2026, month: 12), // future relative to "today" below
        todayUtc: DateTime.utc(2026, 9, 10),
        budgeted: Money.fromMinorUnits(3000, 'USD'),
        spent: Money.zero('USD'),
      );
      expect(calc.dailyRecommendedSpend, isNull);
      expect(calc.projectedMonthEndSpend, isNull);
      expect(calc.status, isNull);
      expect(calc.isFutureMonth, isTrue);
      // budgeted/spent/remaining remain real numbers regardless of period.
      expect(calc.budgeted, Money.fromMinorUnits(3000, 'USD'));
      expect(calc.remaining, Money.fromMinorUnits(3000, 'USD'));
    });
  });
}
