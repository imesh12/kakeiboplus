import 'package:ai_financial_coach/features/dashboard/domain/greeting_period.dart';
import 'package:flutter_test/flutter_test.dart';

// Checkpoint U3 (docs/23_DASHBOARD_HEADER_BRAND_SPEC.md §4.2): pure
// boundary coverage for the Dashboard greeting's time-of-day
// discriminator -- deliberately plain `test()`s (no widget, no clock
// mocking) since `GreetingPeriod.forHour` takes its hour as a plain
// `int` rather than reading `DateTime.now()` itself.
void main() {
  group('GreetingPeriod.forHour', () {
    test('midnight (0) is morning', () {
      expect(GreetingPeriod.forHour(0), GreetingPeriod.morning);
    });

    test('11 is still morning', () {
      expect(GreetingPeriod.forHour(11), GreetingPeriod.morning);
    });

    test('the noon boundary (12) is afternoon, not morning', () {
      expect(GreetingPeriod.forHour(12), GreetingPeriod.afternoon);
    });

    test('17 is still afternoon', () {
      expect(GreetingPeriod.forHour(17), GreetingPeriod.afternoon);
    });

    test('the evening boundary (18) is evening, not afternoon', () {
      expect(GreetingPeriod.forHour(18), GreetingPeriod.evening);
    });

    test('23 (the last hour of the day) is still evening', () {
      expect(GreetingPeriod.forHour(23), GreetingPeriod.evening);
    });
  });
}
