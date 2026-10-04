import 'package:ai_financial_coach/core/money/money.dart';
import 'package:ai_financial_coach/features/dashboard/presentation/dashboard_providers.dart';
import 'package:flutter_test/flutter_test.dart';

// Checkpoint U3 (docs/23_DASHBOARD_HEADER_BRAND_SPEC.md §5.2):
// `remainingThisMonth` is a pure composition of two already-computed,
// already-tested [Money] fields (`income`/`expense` -- see
// `test/core/dashboard/dashboard_providers_test.dart` for their own
// underlying `FinanceEngine.incomeExpenseTotals` coverage, unchanged
// by this checkpoint). These tests exercise only the composition/sign
// behavior added here, directly on a hand-built [CurrencyDashboardSummary]
// -- no database, no provider, no widget tree needed.
void main() {
  CurrencyDashboardSummary summaryWith({required Money income, required Money expense}) {
    return CurrencyDashboardSummary(
      currencyCode: income.currencyCode,
      availableBalance: Money.zero(income.currencyCode),
      netWorth: Money.zero(income.currencyCode),
      income: income,
      expense: expense,
      dailyPace: Money.zero(income.currencyCode),
    );
  }

  group('CurrencyDashboardSummary.remainingThisMonth', () {
    test('income greater than expense is positive remaining, not negative', () {
      final CurrencyDashboardSummary summary = summaryWith(
        income: Money.fromMinorUnits(320000, 'JPY'),
        expense: Money.fromMinorUnits(182400, 'JPY'),
      );

      expect(summary.remainingThisMonth, Money.fromMinorUnits(137600, 'JPY'));
      expect(summary.remainingThisMonth.isNegative, isFalse);
    });

    test('income exactly equal to expense is zero, not negative', () {
      final CurrencyDashboardSummary summary = summaryWith(
        income: Money.fromMinorUnits(50000, 'JPY'),
        expense: Money.fromMinorUnits(50000, 'JPY'),
      );

      expect(summary.remainingThisMonth, Money.zero('JPY'));
      expect(summary.remainingThisMonth.isNegative, isFalse);
    });

    test('expense greater than income is negative -- the overspent state', () {
      final CurrencyDashboardSummary summary = summaryWith(
        income: Money.fromMinorUnits(100000, 'JPY'),
        expense: Money.fromMinorUnits(124300, 'JPY'),
      );

      expect(summary.remainingThisMonth, Money.fromMinorUnits(-24300, 'JPY'));
      expect(summary.remainingThisMonth.isNegative, isTrue);
    });

    test('no income and no expense (a brand-new month) is zero, not negative', () {
      final CurrencyDashboardSummary summary = summaryWith(
        income: Money.zero('JPY'),
        expense: Money.zero('JPY'),
      );

      expect(summary.remainingThisMonth, Money.zero('JPY'));
      expect(summary.remainingThisMonth.isNegative, isFalse);
    });

    test('is independent of availableBalance/netWorth -- never Net Worth in disguise', () {
      // docs/23 SS5.1: the hero must never expose Net Worth or a
      // disguised equivalent. A large, unrelated availableBalance/
      // netWorth must not leak into remainingThisMonth, which reads
      // only income/expense.
      final CurrencyDashboardSummary summary = CurrencyDashboardSummary(
        currencyCode: 'JPY',
        availableBalance: Money.fromMinorUnits(999999900, 'JPY'),
        netWorth: Money.fromMinorUnits(999999900, 'JPY'),
        income: Money.fromMinorUnits(320000, 'JPY'),
        expense: Money.fromMinorUnits(182400, 'JPY'),
        dailyPace: Money.zero('JPY'),
      );

      expect(summary.remainingThisMonth, Money.fromMinorUnits(137600, 'JPY'));
    });

    test('three-decimal currencies (KWD) are handled without precision loss', () {
      final CurrencyDashboardSummary summary = summaryWith(
        income: Money.fromMinorUnits(1245375, 'KWD'),
        expense: Money.fromMinorUnits(1000000, 'KWD'),
      );

      expect(summary.remainingThisMonth, Money.fromMinorUnits(245375, 'KWD'));
    });
  });
}
