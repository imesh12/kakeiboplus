import 'package:ai_financial_coach/core/money/money.dart';
import 'package:ai_financial_coach/features/goals/domain/savings_goal_calculation.dart';
import 'package:ai_financial_coach/features/goals/domain/savings_goal_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SavingsGoalCalculator.evaluate', () {
    final DateTime today = DateTime.utc(2026, 9, 3);

    test('remaining = target - saved when under target', () {
      final calc = SavingsGoalCalculator.evaluate(
        target: Money.fromMinorUnits(100000, 'JPY'),
        saved: Money.fromMinorUnits(30000, 'JPY'),
        todayUtc: today,
      );
      expect(calc.remaining, Money.fromMinorUnits(70000, 'JPY'));
      expect(calc.status, SavingsGoalStatus.inProgress);
    });

    test('remaining clamps at zero when overfunded, never negative', () {
      final calc = SavingsGoalCalculator.evaluate(
        target: Money.fromMinorUnits(100000, 'JPY'),
        saved: Money.fromMinorUnits(150000, 'JPY'),
        todayUtc: today,
      );
      expect(calc.remaining, Money.zero('JPY'));
      expect(calc.status, SavingsGoalStatus.completed);
    });

    test('exact completion: saved == target', () {
      final calc = SavingsGoalCalculator.evaluate(
        target: Money.fromMinorUnits(100000, 'JPY'),
        saved: Money.fromMinorUnits(100000, 'JPY'),
        todayUtc: today,
      );
      expect(calc.status, SavingsGoalStatus.completed);
      expect(calc.remaining, Money.zero('JPY'));
      expect(calc.reachedMilestones, <int>[25, 50, 75, 100]);
    });

    group('recommendedDailyContribution -- ceiling, never floor', () {
      test('regression case: remaining=100, 3 remaining days -> 34, not 33', () {
        // today=Sep3, target date=Sep5 -> remainingDaysInclusive = 3.
        final calc = SavingsGoalCalculator.evaluate(
          target: Money.fromMinorUnits(100, 'JPY'),
          saved: Money.zero('JPY'),
          targetDateUtc: DateTime.utc(2026, 9, 5),
          todayUtc: today,
        );
        expect(calc.remaining, Money.fromMinorUnits(100, 'JPY'));
        expect(calc.recommendedDailyContribution, Money.fromMinorUnits(34, 'JPY'));
        // Verifies the ceiling actually suffices: 34 * 3 >= 100 (floor's
        // 33 * 3 == 99 would NOT reach the goal).
        expect(34 * 3, greaterThanOrEqualTo(100));
      });

      test('evenly divisible remaining needs no rounding up', () {
        final calc = SavingsGoalCalculator.evaluate(
          target: Money.fromMinorUnits(300000, 'JPY'),
          saved: Money.zero('JPY'),
          targetDateUtc: DateTime.utc(2026, 9, 6),
          todayUtc: today, // remainingDaysInclusive = 4
        );
        expect(calc.recommendedDailyContribution, Money.fromMinorUnits(75000, 'JPY'));
      });

      test('target date is today -> remainingDaysInclusive = 1, entire remaining amount', () {
        final calc = SavingsGoalCalculator.evaluate(
          target: Money.fromMinorUnits(50000, 'JPY'),
          saved: Money.fromMinorUnits(10000, 'JPY'),
          targetDateUtc: today,
          todayUtc: today,
        );
        expect(calc.recommendedDailyContribution, Money.fromMinorUnits(40000, 'JPY'));
      });

      test('no target date -> not applicable (null), never a fabricated number', () {
        final calc = SavingsGoalCalculator.evaluate(
          target: Money.fromMinorUnits(50000, 'JPY'),
          saved: Money.fromMinorUnits(10000, 'JPY'),
          todayUtc: today,
        );
        expect(calc.recommendedDailyContribution, isNull);
      });

      test('target date already passed, unfunded -> not applicable (null), never a fake zero', () {
        final calc = SavingsGoalCalculator.evaluate(
          target: Money.fromMinorUnits(50000, 'JPY'),
          saved: Money.fromMinorUnits(10000, 'JPY'),
          targetDateUtc: DateTime.utc(2026, 9, 1),
          todayUtc: today,
        );
        expect(calc.status, SavingsGoalStatus.overdue);
        expect(calc.recommendedDailyContribution, isNull);
      });

      test('completed -> zero, regardless of target date, even a passed one', () {
        final calc = SavingsGoalCalculator.evaluate(
          target: Money.fromMinorUnits(50000, 'JPY'),
          saved: Money.fromMinorUnits(50000, 'JPY'),
          targetDateUtc: DateTime.utc(2026, 9, 1),
          todayUtc: today,
        );
        expect(calc.status, SavingsGoalStatus.completed);
        expect(calc.recommendedDailyContribution, Money.zero('JPY'));
      });

      test('completed with no target date at all -> zero, not null', () {
        final calc = SavingsGoalCalculator.evaluate(
          target: Money.fromMinorUnits(50000, 'JPY'),
          saved: Money.fromMinorUnits(50000, 'JPY'),
          todayUtc: today,
        );
        expect(calc.recommendedDailyContribution, Money.zero('JPY'));
      });

      test('leap-year boundary (Feb 29 exists in 2028) is counted correctly', () {
        // today = 2028-02-28, target date = 2028-03-01 -> Feb28, Feb29,
        // Mar1 => remainingDaysInclusive = 3. Using a remainder-forcing
        // remaining (300001) distinguishes correct leap handling from a
        // bug that skips Feb 29 (which would compute
        // remainingDaysInclusive = 2 and a very different answer).
        final calc = SavingsGoalCalculator.evaluate(
          target: Money.fromMinorUnits(300001, 'JPY'),
          saved: Money.zero('JPY'),
          targetDateUtc: DateTime.utc(2028, 3, 1),
          todayUtc: DateTime.utc(2028, 2, 28),
        );
        expect(calc.recommendedDailyContribution, Money.fromMinorUnits(100001, 'JPY'));
      });

      test('ordinary month-length boundary (31-day January into February)', () {
        // today = 2026-01-30, target date = 2026-02-02 ->
        // Jan30, Jan31, Feb1, Feb2 => remainingDaysInclusive = 4.
        final calc = SavingsGoalCalculator.evaluate(
          target: Money.fromMinorUnits(400000, 'JPY'),
          saved: Money.zero('JPY'),
          targetDateUtc: DateTime.utc(2026, 2, 2),
          todayUtc: DateTime.utc(2026, 1, 30),
        );
        expect(calc.recommendedDailyContribution, Money.fromMinorUnits(100000, 'JPY'));
      });
    });

    group('wholePercentSaved -- floor, never rounds up to a false 100%', () {
      test('99.6% floors to 99%, not 100%', () {
        final calc = SavingsGoalCalculator.evaluate(
          target: Money.fromMinorUnits(100000, 'JPY'),
          saved: Money.fromMinorUnits(99600, 'JPY'),
          todayUtc: today,
        );
        expect(calc.status, SavingsGoalStatus.inProgress);
        expect(calc.wholePercentSaved, 99);
      });

      test('exactly 100% reads 100%', () {
        final calc = SavingsGoalCalculator.evaluate(
          target: Money.fromMinorUnits(100000, 'JPY'),
          saved: Money.fromMinorUnits(100000, 'JPY'),
          todayUtc: today,
        );
        expect(calc.wholePercentSaved, 100);
      });

      test('overfunded reads uncapped, e.g. 142%', () {
        final calc = SavingsGoalCalculator.evaluate(
          target: Money.fromMinorUnits(100000, 'JPY'),
          saved: Money.fromMinorUnits(142800, 'JPY'),
          todayUtc: today,
        );
        expect(calc.wholePercentSaved, 142);
      });

      test('zero saved reads 0%', () {
        final calc = SavingsGoalCalculator.evaluate(
          target: Money.fromMinorUnits(100000, 'JPY'),
          saved: Money.zero('JPY'),
          todayUtc: today,
        );
        expect(calc.wholePercentSaved, 0);
      });
    });
  });
}
