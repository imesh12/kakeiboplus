import 'package:ai_financial_coach/core/money/money.dart';
import 'package:ai_financial_coach/features/budgets/domain/budget_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('evaluateBudgetStatus', () {
    test('healthy when spending is at or under the expected pace', () {
      // Budget 3000, 10 days elapsed of 30 -> expected pace = 1000.
      final BudgetStatus status = evaluateBudgetStatus(
        budgeted: Money.fromMinorUnits(3000, 'USD'),
        spent: Money.fromMinorUnits(1000, 'USD'),
        daysElapsedInclusive: 10,
        totalDaysInMonth: 30,
      );
      expect(status, BudgetStatus.healthy);
    });

    test('caution when ahead of pace but still under the total budget', () {
      // Expected pace = 1000, spent 2500, still <= budgeted (3000).
      final BudgetStatus status = evaluateBudgetStatus(
        budgeted: Money.fromMinorUnits(3000, 'USD'),
        spent: Money.fromMinorUnits(2500, 'USD'),
        daysElapsedInclusive: 10,
        totalDaysInMonth: 30,
      );
      expect(status, BudgetStatus.caution);
    });

    test('overBudget once spending exceeds the total budget, regardless of pace', () {
      final BudgetStatus status = evaluateBudgetStatus(
        budgeted: Money.fromMinorUnits(3000, 'USD'),
        spent: Money.fromMinorUnits(3001, 'USD'),
        daysElapsedInclusive: 1,
        totalDaysInMonth: 30,
      );
      expect(status, BudgetStatus.overBudget);
    });

    test('spending exactly at the expected pace is healthy, not caution', () {
      final BudgetStatus status = evaluateBudgetStatus(
        budgeted: Money.fromMinorUnits(3000, 'USD'),
        spent: Money.fromMinorUnits(1000, 'USD'),
        daysElapsedInclusive: 10,
        totalDaysInMonth: 30,
      );
      expect(status, BudgetStatus.healthy);
    });

    test('spending exactly at the total budget is overBudget only once it exceeds, not at equality', () {
      final BudgetStatus status = evaluateBudgetStatus(
        budgeted: Money.fromMinorUnits(3000, 'USD'),
        spent: Money.fromMinorUnits(3000, 'USD'),
        daysElapsedInclusive: 30,
        totalDaysInMonth: 30,
      );
      expect(status, isNot(BudgetStatus.overBudget));
    });

    test('rejects zero elapsed days rather than dividing by zero', () {
      expect(
        () => evaluateBudgetStatus(
          budgeted: Money.fromMinorUnits(3000, 'USD'),
          spent: Money.zero('USD'),
          daysElapsedInclusive: 0,
          totalDaysInMonth: 30,
        ),
        throwsArgumentError,
      );
    });

    test('rejects a non-positive budgeted amount', () {
      expect(
        () => evaluateBudgetStatus(
          budgeted: Money.zero('USD'),
          spent: Money.zero('USD'),
          daysElapsedInclusive: 1,
          totalDaysInMonth: 30,
        ),
        throwsArgumentError,
      );
    });
  });
}
