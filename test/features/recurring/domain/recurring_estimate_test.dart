import 'package:ai_financial_coach/features/recurring/domain/recurrence_frequency.dart';
import 'package:ai_financial_coach/features/recurring/domain/recurring_estimate.dart';
import 'package:flutter_test/flutter_test.dart';

// Checkpoint 11 -- Recurring + Subscriptions V1. Covers
// `roundHalfUpNonNegative` directly (the exact integer identity docs
// claim it implements) and `RecurringEstimate.of` across every
// frequency, several `interval` values, the documented 365-day-year/
// 12-month-year convention, the ROUND HALF UP tie-breaking rule, and
// the "monthly/yearly computed independently, never one derived from
// the other" guarantee. Nothing here touches Riverpod/Drift -- this is
// a pure domain layer, tested the same way
// `recurring_schedule_test.dart` tests `RecurringSchedule`.
void main() {
  group('roundHalfUpNonNegative', () {
    test('returns the exact quotient when the division is exact', () {
      expect(roundHalfUpNonNegative(10, 5), 2);
      expect(roundHalfUpNonNegative(0, 7), 0);
      expect(roundHalfUpNonNegative(100, 1), 100);
    });

    test('rounds down when the remainder is below half the denominator', () {
      // 10 / 4 = 2.5 exactly -- not below half, see the tie case below.
      // 9 / 4 = 2.25 -- remainder 1, half of denominator is 2 -- rounds down.
      expect(roundHalfUpNonNegative(9, 4), 2);
    });

    test('rounds up on an exact tie (half away from zero for non-negative inputs)', () {
      // 10 / 4 = 2.5 exactly -- the documented tie case rounds up, not
      // to even and not down.
      expect(roundHalfUpNonNegative(10, 4), 3);
      // 1 / 2 = 0.5 exactly.
      expect(roundHalfUpNonNegative(1, 2), 1);
    });

    test('rounds up when the remainder is above half the denominator', () {
      // 11 / 4 = 2.75 -- remainder 3, half of denominator is 2 -- rounds up.
      expect(roundHalfUpNonNegative(11, 4), 3);
    });
  });

  group('RecurringEstimate.of -- monthly frequency', () {
    test('interval 1: monthly equals the amount exactly, yearly is exactly 12x', () {
      final RecurringEstimate estimate = RecurringEstimate.of(
        frequency: RecurrenceFrequency.monthly,
        interval: 1,
        amountMinorUnits: 150000,
      );
      expect(estimate.monthlyMinorUnits, 150000);
      expect(estimate.yearlyMinorUnits, 1800000);
    });

    test('interval 5 ("every 5 months"): both figures are rounded estimates, not exact', () {
      // monthly = 100000 / 5 = 20000 exactly.
      // yearly = 100000 * 12 / 5 = 240000 exactly.
      final RecurringEstimate exact = RecurringEstimate.of(
        frequency: RecurrenceFrequency.monthly,
        interval: 5,
        amountMinorUnits: 100000,
      );
      expect(exact.monthlyMinorUnits, 20000);
      expect(exact.yearlyMinorUnits, 240000);

      // amount 100001 no longer divides evenly -- confirms rounding
      // actually engages rather than silently truncating.
      // monthly = 100001 / 5 = 20000.2 -> rounds to 20000.
      // yearly = 100001 * 12 / 5 = 240002.4 -> rounds to 240002.
      final RecurringEstimate rounded = RecurringEstimate.of(
        frequency: RecurrenceFrequency.monthly,
        interval: 5,
        amountMinorUnits: 100001,
      );
      expect(rounded.monthlyMinorUnits, 20000);
      expect(rounded.yearlyMinorUnits, 240002);
    });
  });

  group('RecurringEstimate.of -- yearly frequency', () {
    test('interval 1: yearly equals the amount exactly, monthly is a rounded 1/12', () {
      // 120000 / 12 = 10000 exactly.
      final RecurringEstimate exact = RecurringEstimate.of(
        frequency: RecurrenceFrequency.yearly,
        interval: 1,
        amountMinorUnits: 120000,
      );
      expect(exact.yearlyMinorUnits, 120000);
      expect(exact.monthlyMinorUnits, 10000);

      // 100000 / 12 = 8333.33... -> rounds to 8333.
      final RecurringEstimate rounded = RecurringEstimate.of(
        frequency: RecurrenceFrequency.yearly,
        interval: 1,
        amountMinorUnits: 100000,
      );
      expect(rounded.yearlyMinorUnits, 100000);
      expect(rounded.monthlyMinorUnits, 8333);
    });
  });

  group('RecurringEstimate.of -- daily frequency (365-day-year convention)', () {
    test('interval 1: yearly is exactly 365x the amount', () {
      final RecurringEstimate estimate = RecurringEstimate.of(
        frequency: RecurrenceFrequency.daily,
        interval: 1,
        amountMinorUnits: 1000,
      );
      expect(estimate.yearlyMinorUnits, 365000);
      // monthly = 1000 * 365 / 12 = 30416.66... -> rounds to 30417.
      expect(estimate.monthlyMinorUnits, 30417);
    });

    test('interval 7 behaves like "roughly weekly" but stays on the daily formula', () {
      // yearly = 1000 * 365 / 7 = 52142.857... -> rounds to 52143.
      final RecurringEstimate estimate = RecurringEstimate.of(
        frequency: RecurrenceFrequency.daily,
        interval: 7,
        amountMinorUnits: 1000,
      );
      expect(estimate.yearlyMinorUnits, 52143);
    });
  });

  group('RecurringEstimate.of -- weekly frequency', () {
    test('interval 1: yearly = amount * 365 / 7, rounded', () {
      // 1000 * 365 / 7 = 52142.857... -> rounds to 52143.
      final RecurringEstimate estimate = RecurringEstimate.of(
        frequency: RecurrenceFrequency.weekly,
        interval: 1,
        amountMinorUnits: 1000,
      );
      expect(estimate.yearlyMinorUnits, 52143);
      // monthly = 1000 * 365 / 84 = 4345.238... -> rounds to 4345.
      expect(estimate.monthlyMinorUnits, 4345);
    });

    test('interval 2 ("every 2 weeks"): both figures halve relative to weekly', () {
      // yearly = 1000 * 365 / 14 = 26071.428... -> rounds to 26071.
      final RecurringEstimate estimate = RecurringEstimate.of(
        frequency: RecurrenceFrequency.weekly,
        interval: 2,
        amountMinorUnits: 1000,
      );
      expect(estimate.yearlyMinorUnits, 26071);
    });
  });

  group('RecurringEstimate.of -- edge cases', () {
    test('a zero amount produces a zero estimate for every frequency', () {
      for (final RecurrenceFrequency frequency in RecurrenceFrequency.values) {
        final RecurringEstimate estimate = RecurringEstimate.of(
          frequency: frequency,
          interval: 1,
          amountMinorUnits: 0,
        );
        expect(estimate.monthlyMinorUnits, 0, reason: '$frequency monthly');
        expect(estimate.yearlyMinorUnits, 0, reason: '$frequency yearly');
      }
    });

    test('a large realistic amount (VND-scale) never overflows or goes negative', () {
      final RecurringEstimate estimate = RecurringEstimate.of(
        frequency: RecurrenceFrequency.daily,
        interval: 1,
        amountMinorUnits: 250000000, // ₫2,500,000
      );
      expect(estimate.monthlyMinorUnits, greaterThan(0));
      expect(estimate.yearlyMinorUnits, greaterThan(0));
      expect(estimate.yearlyMinorUnits, 250000000 * 365);
    });

    test('yearlyMinorUnits is never simply monthlyMinorUnits * 12 (independent rounding)', () {
      // Chosen so each figure's own rounding step lands differently:
      // monthly = 1000 * 365 / 12 = 30416.66... -> 30417
      // 30417 * 12 = 365004, but yearly is independently exactly 365000.
      final RecurringEstimate estimate = RecurringEstimate.of(
        frequency: RecurrenceFrequency.daily,
        interval: 1,
        amountMinorUnits: 1000,
      );
      expect(estimate.monthlyMinorUnits * 12, isNot(estimate.yearlyMinorUnits));
      expect(estimate.yearlyMinorUnits, 365000);
    });
  });
}
