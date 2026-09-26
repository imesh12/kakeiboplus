import 'package:ai_financial_coach/core/finance/finance_engine.dart';
import 'package:ai_financial_coach/core/finance/ledger_models.dart';
import 'package:ai_financial_coach/core/finance/transaction_type.dart';
import 'package:ai_financial_coach/core/money/money.dart';
import 'package:ai_financial_coach/features/budgets/domain/budget_calculation.dart';
import 'package:ai_financial_coach/features/budgets/domain/budget_month.dart';
import 'package:ai_financial_coach/features/budgets/domain/budget_month_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  BudgetCalculation calc({required int budgeted, required int spent, BudgetMonth? month}) {
    return BudgetCalculator.evaluate(
      month: month ?? BudgetMonth(year: 2026, month: 9),
      todayUtc: DateTime.utc(2026, 9, 30), // fully-elapsed historical-style pace
      budgeted: Money.fromMinorUnits(budgeted, 'JPY'),
      spent: Money.fromMinorUnits(spent, 'JPY'),
    );
  }

  group('CategoryBudgetProgress', () {
    test('usedRatio is spent/budgeted, uncapped above 1.0', () {
      final CategoryBudgetProgress progress = CategoryBudgetProgress(
        budgetId: 'b1',
        categoryId: 'cat1',
        calculation: calc(budgeted: 10000, spent: 12500),
      );
      expect(progress.usedRatio, 1.25);
      expect(progress.isOverBudget, isTrue);
    });

    test('usedRatio under 1.0 when spending is within budget', () {
      final CategoryBudgetProgress progress = CategoryBudgetProgress(
        budgetId: 'b1',
        categoryId: 'cat1',
        calculation: calc(budgeted: 10000, spent: 6500),
      );
      expect(progress.usedRatio, closeTo(0.65, 1e-9));
      expect(progress.isOverBudget, isFalse);
    });

    test('usedRatio is exactly 1.0 at exact budget usage -- not over budget', () {
      final CategoryBudgetProgress progress = CategoryBudgetProgress(
        budgetId: 'b1',
        categoryId: 'cat1',
        calculation: calc(budgeted: 10000, spent: 10000),
      );
      expect(progress.usedRatio, 1.0);
      expect(progress.isOverBudget, isFalse);
    });

    test('usedRatio is 0.0 with no spending', () {
      final CategoryBudgetProgress progress = CategoryBudgetProgress(
        budgetId: 'b1',
        categoryId: 'cat1',
        calculation: calc(budgeted: 10000, spent: 0),
      );
      expect(progress.usedRatio, 0.0);
      expect(progress.isOverBudget, isFalse);
    });

    test('categoryId identity is preserved independent of any display name', () {
      final CategoryBudgetProgress progress = CategoryBudgetProgress(
        budgetId: 'budget-42',
        categoryId: 'category-7',
        calculation: calc(budgeted: 1000, spent: 500),
      );
      expect(progress.budgetId, 'budget-42');
      expect(progress.categoryId, 'category-7');
    });
  });

  group('BudgetMonthSummary', () {
    test('totalBudget/spent/remaining reconcile with the sum of category progress', () {
      final BudgetMonth month = BudgetMonth(year: 2026, month: 8);
      final List<CategoryBudgetProgress> progress = <CategoryBudgetProgress>[
        CategoryBudgetProgress(
          budgetId: 'b1',
          categoryId: 'groceries',
          calculation: calc(budgeted: 20000, spent: 13000, month: month),
        ),
        CategoryBudgetProgress(
          budgetId: 'b2',
          categoryId: 'dining',
          calculation: calc(budgeted: 10000, spent: 12000, month: month),
        ),
      ];
      final BudgetMonthSummary summary = BudgetMonthSummary(
        month: month,
        currencyCode: 'JPY',
        totalBudget: Money.fromMinorUnits(30000, 'JPY'),
        spent: Money.fromMinorUnits(25000, 'JPY'),
        remaining: Money.fromMinorUnits(5000, 'JPY'),
        categoryProgress: progress,
      );

      // Section M: month.totalBudget == sum(category budget amounts).
      final Money summedBudgets = progress.fold(
        Money.zero('JPY'),
        (Money acc, CategoryBudgetProgress p) => acc + p.calculation.budgeted,
      );
      expect(summary.totalBudget, summedBudgets);

      // month.spent == sum(spending attributed to those category budgets).
      final Money summedSpent = progress.fold(
        Money.zero('JPY'),
        (Money acc, CategoryBudgetProgress p) => acc + p.calculation.spent,
      );
      expect(summary.spent, summedSpent);

      // month.remaining == month.totalBudget - month.spent.
      expect(summary.remaining, summary.totalBudget - summary.spent);
    });

    test('usedRatio uncapped above 1.0 when the whole month is over budget', () {
      final BudgetMonthSummary summary = BudgetMonthSummary(
        month: BudgetMonth(year: 2026, month: 8),
        currencyCode: 'JPY',
        totalBudget: Money.fromMinorUnits(30000, 'JPY'),
        spent: Money.fromMinorUnits(37500, 'JPY'),
        remaining: Money.fromMinorUnits(-7500, 'JPY'),
        categoryProgress: const <CategoryBudgetProgress>[],
      );
      expect(summary.usedRatio, 1.25);
      expect(summary.isOverBudget, isTrue);
      expect(summary.remaining.isNegative, isTrue);
    });
  });

  group('FinanceEngine.categoryExpenseTotal -- half-open month boundary (Section H)', () {
    LedgerTransaction expense({required DateTime occurredAtUtc, required int amount, String category = 'cat1'}) {
      return LedgerTransaction(
        id: 'tx-${occurredAtUtc.toIso8601String()}-$amount',
        accountId: 'acc1',
        destinationAccountId: null,
        type: TransactionType.expense,
        amount: Money.fromMinorUnits(amount, 'JPY'),
        occurredAtUtc: occurredAtUtc,
        categoryId: category,
        isDeleted: false,
      );
    }

    test('the first instant of the month is included', () {
      final BudgetMonth month = BudgetMonth(year: 2026, month: 8);
      final Money total = FinanceEngine.categoryExpenseTotal(
        <LedgerTransaction>[expense(occurredAtUtc: month.startUtc, amount: 500)],
        currencyCode: 'JPY',
        categoryId: 'cat1',
        fromUtc: month.startUtc,
        toUtc: month.endUtcInclusive,
      );
      expect(total, Money.fromMinorUnits(500, 'JPY'));
    });

    test('the last microsecond before next month is included', () {
      final BudgetMonth month = BudgetMonth(year: 2026, month: 8);
      final Money total = FinanceEngine.categoryExpenseTotal(
        <LedgerTransaction>[expense(occurredAtUtc: month.endUtcInclusive, amount: 700)],
        currencyCode: 'JPY',
        categoryId: 'cat1',
        fromUtc: month.startUtc,
        toUtc: month.endUtcInclusive,
      );
      expect(total, Money.fromMinorUnits(700, 'JPY'));
    });

    test("next month's first instant is excluded -- no leakage across the boundary", () {
      final BudgetMonth august = BudgetMonth(year: 2026, month: 8);
      final Money total = FinanceEngine.categoryExpenseTotal(
        <LedgerTransaction>[expense(occurredAtUtc: august.next.startUtc, amount: 900)],
        currencyCode: 'JPY',
        categoryId: 'cat1',
        fromUtc: august.startUtc,
        toUtc: august.endUtcInclusive,
      );
      expect(total, Money.zero('JPY'));
    });

    test('a transaction in the previous month is excluded', () {
      final BudgetMonth august = BudgetMonth(year: 2026, month: 8);
      final Money total = FinanceEngine.categoryExpenseTotal(
        <LedgerTransaction>[expense(occurredAtUtc: august.previous.endUtcInclusive, amount: 900)],
        currencyCode: 'JPY',
        categoryId: 'cat1',
        fromUtc: august.startUtc,
        toUtc: august.endUtcInclusive,
      );
      expect(total, Money.zero('JPY'));
    });

    test('leap-year February: last day (29th) is included, March 1st is excluded', () {
      final BudgetMonth feb2028 = BudgetMonth(year: 2028, month: 2); // 2028 is a leap year
      expect(feb2028.totalDays, 29);
      final Money total = FinanceEngine.categoryExpenseTotal(
        <LedgerTransaction>[
          expense(occurredAtUtc: DateTime.utc(2028, 2, 29, 23, 59, 59), amount: 100),
          expense(occurredAtUtc: DateTime.utc(2028, 3, 1), amount: 200),
        ],
        currencyCode: 'JPY',
        categoryId: 'cat1',
        fromUtc: feb2028.startUtc,
        toUtc: feb2028.endUtcInclusive,
      );
      expect(total, Money.fromMinorUnits(100, 'JPY'));
    });

    test('December -> January boundary: a January 1st transaction never counts toward December',
        () {
      final BudgetMonth december = BudgetMonth(year: 2026, month: 12);
      expect(december.next, BudgetMonth(year: 2027, month: 1));
      final Money total = FinanceEngine.categoryExpenseTotal(
        <LedgerTransaction>[expense(occurredAtUtc: DateTime.utc(2027, 1, 1), amount: 300)],
        currencyCode: 'JPY',
        categoryId: 'cat1',
        fromUtc: december.startUtc,
        toUtc: december.endUtcInclusive,
      );
      expect(total, Money.zero('JPY'));
    });
  });
}
