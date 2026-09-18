import 'package:ai_financial_coach/core/fx/fx_rate.dart';
import 'package:ai_financial_coach/core/fx/fx_rate_parse_exception.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

// Checkpoint 9.1 (FX Money Engine & Historical Exchange-Rate Foundation),
// Phase 6.A: rate parsing/validation.
void main() {
  group('FxRate — valid rates', () {
    for (final String value in <String>[
      '1',
      '1.0',
      '0.01',
      '150.25',
      '153.482071', // high-precision, 6 fractional digits
      '0.0000001', // very small positive rate, 7 fractional digits
    ]) {
      test('"$value" parses', () {
        final FxRate rate = FxRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY', rate: value);
        expect(rate.rate, Decimal.parse(value));
        expect(rate.rate > Decimal.zero, isTrue);
      });
    }

    test('at exactly the maxFractionDigits bound (12) parses', () {
      final String value = '1.${'1' * FxRate.maxFractionDigits}';
      final FxRate rate = FxRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY', rate: value);
      expect(rate.rate, Decimal.parse(value));
    });

    test('leading/trailing whitespace is trimmed', () {
      final FxRate rate =
          FxRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY', rate: '  150.25  ');
      expect(rate.rate, Decimal.parse('150.25'));
    });

    test('currency codes are normalized to canonical upper case', () {
      final FxRate rate = FxRate(baseCurrencyCode: 'usd', quoteCurrencyCode: 'jpy', rate: '150.25');
      expect(rate.baseCurrencyCode, 'USD');
      expect(rate.quoteCurrencyCode, 'JPY');
    });
  });

  group('FxRate — invalid rates rejected with FxRateParseException', () {
    void expectRejected(String value, {String? reason}) {
      test('"$value" is rejected', () {
        expect(
          () => FxRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY', rate: value),
          throwsA(isA<FxRateParseException>()),
          reason: reason,
        );
      });
    }

    expectRejected('0', reason: 'zero is not a valid rate');
    expectRejected('0.0', reason: 'zero is not a valid rate');
    expectRejected('-1', reason: 'negative rates are rejected');
    expectRejected('-150.25', reason: 'negative rates are rejected');
    expectRejected('', reason: 'empty input');
    expectRejected('   ', reason: 'whitespace-only input');
    expectRejected('abc', reason: 'malformed decimal');
    expectRejected('1.2.3', reason: 'malformed decimal');
    expectRejected('1,5', reason: 'comma is not a decimal separator here');
    expectRejected('NaN', reason: 'NaN must never parse as a rate');
    expectRejected('Infinity', reason: 'Infinity must never parse as a rate');
    expectRejected('-Infinity', reason: 'Infinity must never parse as a rate');
    expectRejected('1e10', reason: 'exponent notation is not part of the parse contract');
    expectRejected('1E10', reason: 'exponent notation is not part of the parse contract');

    test('more than maxFractionDigits fractional digits is rejected', () {
      final String tooPrecise = '1.${'1' * (FxRate.maxFractionDigits + 1)}';
      expect(
        () => FxRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY', rate: tooPrecise),
        throwsA(isA<FxRateParseException>()),
      );
    });
  });

  group('FxRate — unknown currency codes', () {
    test('an unknown base currency throws ArgumentError', () {
      expect(
        () => FxRate(baseCurrencyCode: 'XXX', quoteCurrencyCode: 'JPY', rate: '1'),
        throwsArgumentError,
      );
    });

    test('an unknown quote currency throws ArgumentError', () {
      expect(
        () => FxRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'XXX', rate: '1'),
        throwsArgumentError,
      );
    });
  });

  group('FxRate — serialization round-trip', () {
    test('rateAsString parses back to an identical Decimal', () {
      for (final String value in <String>['1', '150.25', '0.0000001', '153.482071']) {
        final FxRate rate = FxRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY', rate: value);
        expect(Decimal.parse(rate.rateAsString), rate.rate);
      }
    });
  });

  group('FxRate — equality', () {
    test('two rates with the same base/quote/value are equal', () {
      final FxRate a = FxRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY', rate: '150.25');
      final FxRate b = FxRate(baseCurrencyCode: 'usd', quoteCurrencyCode: 'jpy', rate: '150.25');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('a different rate value is not equal', () {
      final FxRate a = FxRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY', rate: '150.25');
      final FxRate b = FxRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY', rate: '150.26');
      expect(a, isNot(b));
    });
  });
}
