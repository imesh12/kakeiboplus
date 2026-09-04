import 'package:ai_financial_coach/core/money/money.dart';
import 'package:ai_financial_coach/features/goals/domain/savings_goal_milestones.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('reachedSavingsGoalMilestones', () {
    test('nothing reached with zero saved', () {
      final reached = reachedSavingsGoalMilestones(
        saved: Money.zero('JPY'),
        target: Money.fromMinorUnits(100000, 'JPY'),
      );
      expect(reached, isEmpty);
    });

    test('exactly 25% reached, not 50%', () {
      final reached = reachedSavingsGoalMilestones(
        saved: Money.fromMinorUnits(25000, 'JPY'),
        target: Money.fromMinorUnits(100000, 'JPY'),
      );
      expect(reached, <int>[25]);
    });

    test('49% reaches only 25%, not 50% -- ceiling, not floor, of the threshold', () {
      final reached = reachedSavingsGoalMilestones(
        saved: Money.fromMinorUnits(49000, 'JPY'),
        target: Money.fromMinorUnits(100000, 'JPY'),
      );
      expect(reached, <int>[25]);
    });

    test('exactly 50% reached', () {
      final reached = reachedSavingsGoalMilestones(
        saved: Money.fromMinorUnits(50000, 'JPY'),
        target: Money.fromMinorUnits(100000, 'JPY'),
      );
      expect(reached, <int>[25, 50]);
    });

    test('exactly 75% reached', () {
      final reached = reachedSavingsGoalMilestones(
        saved: Money.fromMinorUnits(75000, 'JPY'),
        target: Money.fromMinorUnits(100000, 'JPY'),
      );
      expect(reached, <int>[25, 50, 75]);
    });

    test('one minor unit short of 75% does not reach it', () {
      final reached = reachedSavingsGoalMilestones(
        saved: Money.fromMinorUnits(74999, 'JPY'),
        target: Money.fromMinorUnits(100000, 'JPY'),
      );
      expect(reached, <int>[25, 50]);
    });

    test('exactly 100% reached (all four thresholds) -- same condition as completed', () {
      final reached = reachedSavingsGoalMilestones(
        saved: Money.fromMinorUnits(100000, 'JPY'),
        target: Money.fromMinorUnits(100000, 'JPY'),
      );
      expect(reached, <int>[25, 50, 75, 100]);
    });

    test('overfunded still reports all four thresholds, nothing above 100', () {
      final reached = reachedSavingsGoalMilestones(
        saved: Money.fromMinorUnits(250000, 'JPY'),
        target: Money.fromMinorUnits(100000, 'JPY'),
      );
      expect(reached, <int>[25, 50, 75, 100]);
    });

    test('a target not evenly divisible by 4 still ceils each threshold correctly', () {
      // target = 10 (minor units); 25% -> ceil(2.5) = 3, 50% -> ceil(5) = 5,
      // 75% -> ceil(7.5) = 8, 100% -> 10.
      const target = 10;
      expect(
        reachedSavingsGoalMilestones(
          saved: Money.fromMinorUnits(2, 'JPY'),
          target: Money.fromMinorUnits(target, 'JPY'),
        ),
        isEmpty,
      );
      expect(
        reachedSavingsGoalMilestones(
          saved: Money.fromMinorUnits(3, 'JPY'),
          target: Money.fromMinorUnits(target, 'JPY'),
        ),
        <int>[25],
      );
      expect(
        reachedSavingsGoalMilestones(
          saved: Money.fromMinorUnits(7, 'JPY'),
          target: Money.fromMinorUnits(target, 'JPY'),
        ),
        <int>[25, 50],
      );
      expect(
        reachedSavingsGoalMilestones(
          saved: Money.fromMinorUnits(8, 'JPY'),
          target: Money.fromMinorUnits(target, 'JPY'),
        ),
        <int>[25, 50, 75],
      );
    });

    group('near the signed 64-bit boundary -- must not overflow/wrap', () {
      // 8e18: comfortably below max int64 (~9.223e18) but large enough
      // that a naive `target * 3` (for the 75% threshold) would already
      // have overflowed (3 * 8e18 > 2.4e19, far past int64 max).
      const int nearMaxTarget = 8000000000000000000;

      test('exact round-number thresholds at 8e18 target', () {
        expect(
          reachedSavingsGoalMilestones(
            saved: Money.fromMinorUnits(2000000000000000000, 'JPY'),
            target: Money.fromMinorUnits(nearMaxTarget, 'JPY'),
          ),
          <int>[25],
        );
        expect(
          reachedSavingsGoalMilestones(
            saved: Money.fromMinorUnits(6000000000000000000, 'JPY'),
            target: Money.fromMinorUnits(nearMaxTarget, 'JPY'),
          ),
          <int>[25, 50, 75],
        );
        expect(
          reachedSavingsGoalMilestones(
            saved: Money.fromMinorUnits(5999999999999999999, 'JPY'),
            target: Money.fromMinorUnits(nearMaxTarget, 'JPY'),
          ),
          <int>[25, 50], // one minor unit short of 75% -- must not wrap to a false positive
        );
      });

      test('the literal signed-64-bit maximum as target does not crash and 100% works exactly', () {
        const int int64Max = 9223372036854775807;
        expect(
          reachedSavingsGoalMilestones(
            saved: Money.fromMinorUnits(int64Max, 'JPY'),
            target: Money.fromMinorUnits(int64Max, 'JPY'),
          ),
          <int>[25, 50, 75, 100],
        );
        expect(
          reachedSavingsGoalMilestones(
            saved: Money.zero('JPY'),
            target: Money.fromMinorUnits(int64Max, 'JPY'),
          ),
          isEmpty,
        );
      });
    });
  });
}
