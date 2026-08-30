import 'package:ai_financial_coach/core/money/money_rounding.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MoneyRounding.roundHalfUpToMinorUnits — ADR-018', () {
    test('JPY example from ADR-018: 123.5 -> 124', () {
      expect(MoneyRounding.roundHalfUpToMinorUnits(Decimal.parse('123.5')), 124);
    });

    test(
        'USD example from ADR-018: \$12.345 -> \$12.35, i.e. the caller '
        'scales to minor units (1234.5 cents) before calling this function, '
        'and it rounds to 1235 cents', () {
      expect(MoneyRounding.roundHalfUpToMinorUnits(Decimal.parse('1234.5')), 1235);
    });

    test(
        'KWD example from ADR-018: KWD 1.2345 -> KWD 1.235, i.e. scaled to '
        '1234.5 (thousandths) before calling this function, rounds to 1235', () {
      expect(MoneyRounding.roundHalfUpToMinorUnits(Decimal.parse('1234.5')), 1235);
    });

    test('rounds exactly-half values up (away from zero), not to even', () {
      expect(MoneyRounding.roundHalfUpToMinorUnits(Decimal.parse('0.5')), 1);
      expect(MoneyRounding.roundHalfUpToMinorUnits(Decimal.parse('2.5')), 3);
      expect(MoneyRounding.roundHalfUpToMinorUnits(Decimal.parse('4.5')), 5);
    });

    test('rounds negative half values away from zero', () {
      expect(MoneyRounding.roundHalfUpToMinorUnits(Decimal.parse('-0.5')), -1);
      expect(MoneyRounding.roundHalfUpToMinorUnits(Decimal.parse('-2.5')), -3);
    });

    test('rounds values below the half-way point down', () {
      expect(MoneyRounding.roundHalfUpToMinorUnits(Decimal.parse('0.49')), 0);
      expect(MoneyRounding.roundHalfUpToMinorUnits(Decimal.parse('2.49')), 2);
    });

    test('rounds values above the half-way point up', () {
      expect(MoneyRounding.roundHalfUpToMinorUnits(Decimal.parse('0.51')), 1);
    });

    test('exact integers are unchanged', () {
      expect(MoneyRounding.roundHalfUpToMinorUnits(Decimal.parse('42')), 42);
    });
  });
}
