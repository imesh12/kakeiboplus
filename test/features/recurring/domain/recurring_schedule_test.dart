import 'package:ai_financial_coach/features/recurring/domain/recurrence_frequency.dart';
import 'package:ai_financial_coach/features/recurring/domain/recurring_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('daily', () {
    test('occurs every day from the anchor', () {
      final RecurringSchedule schedule = RecurringSchedule(
        frequency: RecurrenceFrequency.daily,
        interval: 1,
        startDateUtc: DateTime.utc(2026, 1, 1),
      );
      expect(
        schedule.occurrencesInRange(fromUtc: DateTime.utc(2026, 1, 1), toUtc: DateTime.utc(2026, 1, 5)),
        <DateTime>[
          DateTime.utc(2026, 1, 1),
          DateTime.utc(2026, 1, 2),
          DateTime.utc(2026, 1, 3),
          DateTime.utc(2026, 1, 4),
          DateTime.utc(2026, 1, 5),
        ],
      );
    });

    test('interval daily -- every 3 days', () {
      final RecurringSchedule schedule = RecurringSchedule(
        frequency: RecurrenceFrequency.daily,
        interval: 3,
        startDateUtc: DateTime.utc(2026, 1, 1),
      );
      expect(
        schedule.occurrencesInRange(fromUtc: DateTime.utc(2026, 1, 1), toUtc: DateTime.utc(2026, 1, 10)),
        <DateTime>[
          DateTime.utc(2026, 1, 1),
          DateTime.utc(2026, 1, 4),
          DateTime.utc(2026, 1, 7),
          DateTime.utc(2026, 1, 10),
        ],
      );
    });
  });

  group('weekly', () {
    test('occurs every 7 days from the anchor', () {
      final RecurringSchedule schedule = RecurringSchedule(
        frequency: RecurrenceFrequency.weekly,
        interval: 1,
        startDateUtc: DateTime.utc(2026, 1, 5), // a Monday
      );
      expect(
        schedule.occurrencesInRange(fromUtc: DateTime.utc(2026, 1, 5), toUtc: DateTime.utc(2026, 1, 26)),
        <DateTime>[
          DateTime.utc(2026, 1, 5),
          DateTime.utc(2026, 1, 12),
          DateTime.utc(2026, 1, 19),
          DateTime.utc(2026, 1, 26),
        ],
      );
    });

    test('interval weekly -- every 2 weeks', () {
      final RecurringSchedule schedule = RecurringSchedule(
        frequency: RecurrenceFrequency.weekly,
        interval: 2,
        startDateUtc: DateTime.utc(2026, 1, 5),
      );
      expect(
        schedule.occurrencesInRange(fromUtc: DateTime.utc(2026, 1, 5), toUtc: DateTime.utc(2026, 2, 16)),
        <DateTime>[
          DateTime.utc(2026, 1, 5),
          DateTime.utc(2026, 1, 19),
          DateTime.utc(2026, 2, 2),
          DateTime.utc(2026, 2, 16),
        ],
      );
    });
  });

  group('monthly', () {
    test('normal day-of-month with no clamping', () {
      final RecurringSchedule schedule = RecurringSchedule(
        frequency: RecurrenceFrequency.monthly,
        interval: 1,
        startDateUtc: DateTime.utc(2026, 3, 15),
      );
      expect(
        schedule.occurrencesInRange(fromUtc: DateTime.utc(2026, 3, 15), toUtc: DateTime.utc(2026, 6, 15)),
        <DateTime>[
          DateTime.utc(2026, 3, 15),
          DateTime.utc(2026, 4, 15),
          DateTime.utc(2026, 5, 15),
          DateTime.utc(2026, 6, 15),
        ],
      );
    });

    test(
      'Jan 31 anchor clamps against each month\'s own last day, always measured from the '
      'original anchor -- never drifts to the 28th',
      () {
        // 2026 is not a leap year -- Feb has 28 days.
        final RecurringSchedule schedule = RecurringSchedule(
          frequency: RecurrenceFrequency.monthly,
          interval: 1,
          startDateUtc: DateTime.utc(2026, 1, 31),
        );
        expect(
          schedule.occurrencesInRange(fromUtc: DateTime.utc(2026, 1, 31), toUtc: DateTime.utc(2026, 5, 31)),
          <DateTime>[
            DateTime.utc(2026, 1, 31),
            DateTime.utc(2026, 2, 28), // clamped, not 2/31
            DateTime.utc(2026, 3, 31), // back to 31 -- proves March isn't "Feb 28 + 1 month"
            DateTime.utc(2026, 4, 30), // clamped again
            DateTime.utc(2026, 5, 31),
          ],
        );
      },
    );

    test('Jan 31 anchor in a leap year clamps February to the 29th', () {
      final RecurringSchedule schedule = RecurringSchedule(
        frequency: RecurrenceFrequency.monthly,
        interval: 1,
        startDateUtc: DateTime.utc(2028, 1, 31), // 2028 is a leap year
      );
      final DateTime? february = schedule.occurrenceOnOrAfter(DateTime.utc(2028, 2, 1));
      expect(february, DateTime.utc(2028, 2, 29));
    });

    test('interval monthly -- every 2 months, still anchored from the original date', () {
      final RecurringSchedule schedule = RecurringSchedule(
        frequency: RecurrenceFrequency.monthly,
        interval: 2,
        startDateUtc: DateTime.utc(2026, 1, 31),
      );
      expect(
        schedule.occurrencesInRange(fromUtc: DateTime.utc(2026, 1, 31), toUtc: DateTime.utc(2026, 7, 31)),
        <DateTime>[
          DateTime.utc(2026, 1, 31),
          DateTime.utc(2026, 3, 31),
          DateTime.utc(2026, 5, 31),
          DateTime.utc(2026, 7, 31),
        ],
      );
    });
  });

  group('yearly', () {
    test('occurs on the same month/day every year', () {
      final RecurringSchedule schedule = RecurringSchedule(
        frequency: RecurrenceFrequency.yearly,
        interval: 1,
        startDateUtc: DateTime.utc(2026, 6, 15),
      );
      expect(
        schedule.occurrencesInRange(fromUtc: DateTime.utc(2026, 6, 15), toUtc: DateTime.utc(2029, 6, 15)),
        <DateTime>[
          DateTime.utc(2026, 6, 15),
          DateTime.utc(2027, 6, 15),
          DateTime.utc(2028, 6, 15),
          DateTime.utc(2029, 6, 15),
        ],
      );
    });

    test('Feb 29 anchor clamps to Feb 28 in a non-leap year, back to 29 in the next leap year', () {
      final RecurringSchedule schedule = RecurringSchedule(
        frequency: RecurrenceFrequency.yearly,
        interval: 1,
        startDateUtc: DateTime.utc(2028, 2, 29), // 2028 is a leap year
      );
      expect(schedule.occurrenceOnOrAfter(DateTime.utc(2029, 1, 1)), DateTime.utc(2029, 2, 28));
      expect(schedule.occurrenceOnOrAfter(DateTime.utc(2030, 1, 1)), DateTime.utc(2030, 2, 28));
      expect(schedule.occurrenceOnOrAfter(DateTime.utc(2031, 1, 1)), DateTime.utc(2031, 2, 28));
      // 2032 is the next leap year -- back to the original anchor day.
      expect(schedule.occurrenceOnOrAfter(DateTime.utc(2032, 1, 1)), DateTime.utc(2032, 2, 29));
    });
  });

  group('inclusivity', () {
    test('startDate is inclusive -- occurrenceOnOrAfter(startDate) is startDate itself', () {
      final RecurringSchedule schedule = RecurringSchedule(
        frequency: RecurrenceFrequency.weekly,
        interval: 1,
        startDateUtc: DateTime.utc(2026, 4, 1),
      );
      expect(schedule.occurrenceOnOrAfter(DateTime.utc(2026, 4, 1)), DateTime.utc(2026, 4, 1));
    });

    test('a date before startDate still resolves to startDate as the first occurrence', () {
      final RecurringSchedule schedule = RecurringSchedule(
        frequency: RecurrenceFrequency.monthly,
        interval: 1,
        startDateUtc: DateTime.utc(2026, 4, 10),
      );
      expect(schedule.occurrenceOnOrAfter(DateTime.utc(2020, 1, 1)), DateTime.utc(2026, 4, 10));
      expect(schedule.nextOccurrenceAfter(DateTime.utc(2020, 1, 1)), DateTime.utc(2026, 4, 10));
    });

    test('endDate is inclusive -- an occurrence exactly on endDate is still returned', () {
      final RecurringSchedule schedule = RecurringSchedule(
        frequency: RecurrenceFrequency.daily,
        interval: 1,
        startDateUtc: DateTime.utc(2026, 1, 1),
        endDateUtc: DateTime.utc(2026, 1, 3),
      );
      expect(schedule.occurrenceOnOrAfter(DateTime.utc(2026, 1, 3)), DateTime.utc(2026, 1, 3));
    });

    test('no occurrences after endDate -- occurrenceOnOrAfter/nextOccurrenceAfter both null', () {
      final RecurringSchedule schedule = RecurringSchedule(
        frequency: RecurrenceFrequency.daily,
        interval: 1,
        startDateUtc: DateTime.utc(2026, 1, 1),
        endDateUtc: DateTime.utc(2026, 1, 3),
      );
      expect(schedule.occurrenceOnOrAfter(DateTime.utc(2026, 1, 4)), isNull);
      expect(schedule.nextOccurrenceAfter(DateTime.utc(2026, 1, 3)), isNull);
    });

    test('a monthly schedule stops exactly at endDate even mid-clamp sequence', () {
      final RecurringSchedule schedule = RecurringSchedule(
        frequency: RecurrenceFrequency.monthly,
        interval: 1,
        startDateUtc: DateTime.utc(2026, 1, 31),
        endDateUtc: DateTime.utc(2026, 3, 31),
      );
      expect(
        schedule.occurrencesInRange(fromUtc: DateTime.utc(2026, 1, 1), toUtc: DateTime.utc(2026, 12, 31)),
        <DateTime>[
          DateTime.utc(2026, 1, 31),
          DateTime.utc(2026, 2, 28),
          DateTime.utc(2026, 3, 31),
        ],
      );
    });
  });

  group('occurrencesInRange', () {
    test('bounded range generation -- never returns anything outside [fromUtc, toUtc]', () {
      final RecurringSchedule schedule = RecurringSchedule(
        frequency: RecurrenceFrequency.daily,
        interval: 1,
        startDateUtc: DateTime.utc(2026, 1, 1),
      );
      final List<DateTime> occurrences = schedule.occurrencesInRange(
        fromUtc: DateTime.utc(2026, 1, 10),
        toUtc: DateTime.utc(2026, 1, 12),
      );
      expect(occurrences, <DateTime>[
        DateTime.utc(2026, 1, 10),
        DateTime.utc(2026, 1, 11),
        DateTime.utc(2026, 1, 12),
      ]);
    });

    test('an inverted range (toUtc before fromUtc) returns an empty list, not an error', () {
      final RecurringSchedule schedule = RecurringSchedule(
        frequency: RecurrenceFrequency.daily,
        interval: 1,
        startDateUtc: DateTime.utc(2026, 1, 1),
      );
      expect(
        schedule.occurrencesInRange(fromUtc: DateTime.utc(2026, 2, 1), toUtc: DateTime.utc(2026, 1, 1)),
        isEmpty,
      );
    });

    test('a range entirely before startDate returns an empty list', () {
      final RecurringSchedule schedule = RecurringSchedule(
        frequency: RecurrenceFrequency.daily,
        interval: 1,
        startDateUtc: DateTime.utc(2026, 6, 1),
      );
      expect(
        schedule.occurrencesInRange(fromUtc: DateTime.utc(2026, 1, 1), toUtc: DateTime.utc(2026, 5, 31)),
        isEmpty,
      );
    });
  });
}
