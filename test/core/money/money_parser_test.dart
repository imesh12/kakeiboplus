import 'package:ai_financial_coach/core/money/money.dart';
import 'package:ai_financial_coach/core/money/money_parse_exception.dart';
import 'package:ai_financial_coach/core/money/money_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MoneyParser — currency precision at the input boundary (release gate)', () {
    test('parses a whole-yen amount for JPY (0 minor units)', () {
      expect(MoneyParser.parse('1200', 'JPY'), Money.fromMinorUnits(1200, 'JPY'));
    });

    test('rejects a fractional amount for JPY (0 minor units)', () {
      expect(
        () => MoneyParser.parse('12.50', 'JPY'),
        throwsA(isA<MoneyParseException>()),
      );
    });

    test('rejects a fractional amount for KRW (0 minor units)', () {
      expect(
        () => MoneyParser.parse('100.1', 'KRW'),
        throwsA(isA<MoneyParseException>()),
      );
    });

    test('rejects a fractional amount for VND (0 minor units)', () {
      expect(
        () => MoneyParser.parse('1000.5', 'VND'),
        throwsA(isA<MoneyParseException>()),
      );
    });

    test('parses a 3-decimal amount for KWD', () {
      expect(MoneyParser.parse('1.234', 'KWD'), Money.fromMinorUnits(1234, 'KWD'));
    });

    test('rejects a 4-decimal amount for KWD (more precision than it supports)', () {
      expect(
        () => MoneyParser.parse('1.2345', 'KWD'),
        throwsA(isA<MoneyParseException>()),
      );
    });

    test('accepts fewer decimals than KWD allows', () {
      expect(MoneyParser.parse('1.2', 'KWD'), Money.fromMinorUnits(1200, 'KWD'));
      expect(MoneyParser.parse('1', 'KWD'), Money.fromMinorUnits(1000, 'KWD'));
    });

    test('parses a standard 2-decimal amount for USD', () {
      expect(MoneyParser.parse('12.34', 'USD'), Money.fromMinorUnits(1234, 'USD'));
    });

    test('rejects a 3-decimal amount for a 2-decimal currency (never silently truncates)', () {
      expect(
        () => MoneyParser.parse('12.345', 'USD'),
        throwsA(isA<MoneyParseException>()),
      );
    });
  });

  group('MoneyParser — general validation', () {
    test('rejects empty input', () {
      expect(() => MoneyParser.parse('', 'USD'), throwsA(isA<MoneyParseException>()));
      expect(() => MoneyParser.parse('   ', 'USD'), throwsA(isA<MoneyParseException>()));
    });

    test('rejects non-numeric input', () {
      expect(() => MoneyParser.parse('abc', 'USD'), throwsA(isA<MoneyParseException>()));
    });

    test('rejects negative input', () {
      expect(() => MoneyParser.parse('-5', 'USD'), throwsA(isA<MoneyParseException>()));
    });

    test('accepts zero', () {
      expect(MoneyParser.parse('0', 'USD'), Money.zero('USD'));
    });

    test('trims surrounding whitespace', () {
      expect(MoneyParser.parse('  12.34  ', 'USD'), Money.fromMinorUnits(1234, 'USD'));
    });

    test('never routes through double: an amount double cannot represent exactly still parses correctly', () {
      // 0.1 + 0.2 famously != 0.3 in binary floating point. MoneyParser
      // must get this exactly right because it never uses double.
      expect(MoneyParser.parse('0.10', 'USD'), Money.fromMinorUnits(10, 'USD'));
      expect(MoneyParser.parse('0.30', 'USD'), Money.fromMinorUnits(30, 'USD'));
    });
  });
}
