import 'package:ai_financial_coach/core/money/money.dart';
import 'package:ai_financial_coach/features/goals/domain/savings_goal_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('evaluateSavingsGoalStatus', () {
    final DateTime today = DateTime.utc(2026, 9, 3);

    test('inProgress: no target date, unfunded', () {
      final status = evaluateSavingsGoalStatus(
        target: Money.fromMinorUnits(100000, 'JPY'),
        saved: Money.fromMinorUnits(30000, 'JPY'),
        todayUtc: today,
      );
      expect(status, SavingsGoalStatus.inProgress);
    });

    test('inProgress: future target date, unfunded', () {
      final status = evaluateSavingsGoalStatus(
        target: Money.fromMinorUnits(100000, 'JPY'),
        saved: Money.fromMinorUnits(30000, 'JPY'),
        targetDateUtc: DateTime.utc(2026, 12, 25),
        todayUtc: today,
      );
      expect(status, SavingsGoalStatus.inProgress);
    });

    test('inProgress: target date is today, unfunded -- not yet overdue', () {
      final status = evaluateSavingsGoalStatus(
        target: Money.fromMinorUnits(100000, 'JPY'),
        saved: Money.fromMinorUnits(30000, 'JPY'),
        targetDateUtc: today,
        todayUtc: today,
      );
      expect(status, SavingsGoalStatus.inProgress);
    });

    test('completed: saved exactly equals target', () {
      final status = evaluateSavingsGoalStatus(
        target: Money.fromMinorUnits(100000, 'JPY'),
        saved: Money.fromMinorUnits(100000, 'JPY'),
        todayUtc: today,
      );
      expect(status, SavingsGoalStatus.completed);
    });

    test('completed: overfunded (saved exceeds target)', () {
      final status = evaluateSavingsGoalStatus(
        target: Money.fromMinorUnits(100000, 'JPY'),
        saved: Money.fromMinorUnits(150000, 'JPY'),
        todayUtc: today,
      );
      expect(status, SavingsGoalStatus.completed);
    });

    test('overdue: target date passed, unfunded', () {
      final status = evaluateSavingsGoalStatus(
        target: Money.fromMinorUnits(100000, 'JPY'),
        saved: Money.fromMinorUnits(30000, 'JPY'),
        targetDateUtc: DateTime.utc(2026, 9, 1),
        todayUtc: today,
      );
      expect(status, SavingsGoalStatus.overdue);
    });

    test('completed takes precedence over overdue: funded on/after a passed target date', () {
      final status = evaluateSavingsGoalStatus(
        target: Money.fromMinorUnits(100000, 'JPY'),
        saved: Money.fromMinorUnits(100000, 'JPY'),
        targetDateUtc: DateTime.utc(2026, 9, 1),
        todayUtc: today,
      );
      expect(status, SavingsGoalStatus.completed);
    });

    test('rejects a non-positive target', () {
      expect(
        () => evaluateSavingsGoalStatus(
          target: Money.zero('JPY'),
          saved: Money.zero('JPY'),
          todayUtc: today,
        ),
        throwsArgumentError,
      );
    });
  });
}
