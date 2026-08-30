import 'package:ai_financial_coach/core/money/currency_mismatch_exception.dart';
import 'package:ai_financial_coach/core/money/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Money arithmetic (same currency)', () {
    test('addition', () {
      final Money a = Money.fromMinorUnits(1000, 'USD');
      final Money b = Money.fromMinorUnits(234, 'USD');
      expect(a + b, Money.fromMinorUnits(1234, 'USD'));
    });

    test('subtraction, including going negative', () {
      final Money a = Money.fromMinorUnits(100, 'USD');
      final Money b = Money.fromMinorUnits(300, 'USD');
      expect(a - b, Money.fromMinorUnits(-200, 'USD'));
      expect((a - b).isNegative, isTrue);
    });

    test('unary negation', () {
      final Money a = Money.fromMinorUnits(500, 'USD');
      expect(-a, Money.fromMinorUnits(-500, 'USD'));
    });

    test('comparisons', () {
      final Money a = Money.fromMinorUnits(100, 'USD');
      final Money b = Money.fromMinorUnits(200, 'USD');
      expect(a < b, isTrue);
      expect(b > a, isTrue);
      expect(a <= a, isTrue);
      expect(a.compareTo(a), 0);
    });

    test('zero/isZero/isPositive/isNegative', () {
      expect(Money.zero('USD').isZero, isTrue);
      expect(Money.fromMinorUnits(1, 'USD').isPositive, isTrue);
      expect(Money.fromMinorUnits(-1, 'USD').isNegative, isTrue);
    });

    test('equality and hashCode are value-based', () {
      final Money a = Money.fromMinorUnits(1234, 'USD');
      final Money b = Money.fromMinorUnits(1234, 'USD');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('currency code is case-normalized to upper case', () {
      final Money a = Money.fromMinorUnits(100, 'usd');
      expect(a.currencyCode, 'USD');
    });
  });

  group('Money arithmetic (release gate: mismatched currency is rejected)', () {
    test('addition across currencies throws CurrencyMismatchException', () {
      final Money jpy = Money.fromMinorUnits(1000, 'JPY');
      final Money usd = Money.fromMinorUnits(1000, 'USD');
      expect(() => jpy + usd, throwsA(isA<CurrencyMismatchException>()));
    });

    test('subtraction across currencies throws CurrencyMismatchException', () {
      final Money jpy = Money.fromMinorUnits(1000, 'JPY');
      final Money usd = Money.fromMinorUnits(1000, 'USD');
      expect(() => jpy - usd, throwsA(isA<CurrencyMismatchException>()));
    });

    test('comparison across currencies throws CurrencyMismatchException', () {
      final Money jpy = Money.fromMinorUnits(1000, 'JPY');
      final Money usd = Money.fromMinorUnits(1000, 'USD');
      expect(() => jpy < usd, throwsA(isA<CurrencyMismatchException>()));
      expect(() => jpy.compareTo(usd), throwsA(isA<CurrencyMismatchException>()));
    });

    test('equality does NOT throw across currencies (they are simply unequal)', () {
      final Money jpy = Money.fromMinorUnits(1000, 'JPY');
      final Money usd = Money.fromMinorUnits(1000, 'USD');
      expect(jpy == usd, isFalse);
    });
  });

  group('Money.toMajorUnitsString — currency precision (release gate)', () {
    test('JPY (0 minor units): 1200 minor units -> "1200"', () {
      expect(Money.fromMinorUnits(1200, 'JPY').toMajorUnitsString(), '1200');
    });

    test('KRW (0 minor units): 50000 minor units -> "50000"', () {
      expect(Money.fromMinorUnits(50000, 'KRW').toMajorUnitsString(), '50000');
    });

    test('VND (0 minor units): 100000 minor units -> "100000"', () {
      expect(Money.fromMinorUnits(100000, 'VND').toMajorUnitsString(), '100000');
    });

    test('KWD (3 minor units): 1234 minor units -> "1.234"', () {
      expect(Money.fromMinorUnits(1234, 'KWD').toMajorUnitsString(), '1.234');
    });

    test('KWD zero-pads short fractions: 5 minor units -> "0.005"', () {
      expect(Money.fromMinorUnits(5, 'KWD').toMajorUnitsString(), '0.005');
    });

    test('USD (2 minor units): 1234 minor units -> "12.34"', () {
      expect(Money.fromMinorUnits(1234, 'USD').toMajorUnitsString(), '12.34');
    });

    test('a 2-decimal currency zero-pads: 5 minor units -> "0.05"', () {
      expect(Money.fromMinorUnits(5, 'USD').toMajorUnitsString(), '0.05');
    });

    test('negative amounts carry the sign correctly', () {
      expect(Money.fromMinorUnits(-1234, 'USD').toMajorUnitsString(), '-12.34');
      expect(Money.fromMinorUnits(-500, 'JPY').toMajorUnitsString(), '-500');
    });
  });
}
