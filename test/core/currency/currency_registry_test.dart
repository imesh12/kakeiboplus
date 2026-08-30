import 'package:ai_financial_coach/core/currency/currency_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CurrencyRegistry', () {
    test('seed set covers every currency named in the Blueprint V2 docs', () {
      const List<String> expectedCodes = <String>[
        'JPY', 'KRW', 'VND', 'KWD', // zero/triple decimal examples
        'LKR', 'NPR', 'INR', 'BDT', 'MMK', 'QAR', 'CAD', 'EUR', 'USD',
      ];
      for (final String code in expectedCodes) {
        expect(CurrencyRegistry.byCode(code), isNotNull, reason: '$code should be seeded');
      }
    });

    test('JPY, KRW, and VND are zero-minor-unit currencies', () {
      expect(CurrencyRegistry.require('JPY').minorUnits, 0);
      expect(CurrencyRegistry.require('KRW').minorUnits, 0);
      expect(CurrencyRegistry.require('VND').minorUnits, 0);
    });

    test('KWD is a three-minor-unit currency', () {
      expect(CurrencyRegistry.require('KWD').minorUnits, 3);
    });

    test('a representative set of currencies default to two minor units', () {
      for (final String code in <String>['USD', 'EUR', 'LKR', 'INR', 'CAD']) {
        expect(CurrencyRegistry.require(code).minorUnits, 2, reason: code);
      }
    });

    test('minorUnitScale is 10^minorUnits', () {
      expect(CurrencyRegistry.require('JPY').minorUnitScale, 1);
      expect(CurrencyRegistry.require('USD').minorUnitScale, 100);
      expect(CurrencyRegistry.require('KWD').minorUnitScale, 1000);
    });

    test('byCode is case-insensitive', () {
      expect(CurrencyRegistry.byCode('jpy'), CurrencyRegistry.byCode('JPY'));
    });

    test('byCode returns null for an unknown currency', () {
      expect(CurrencyRegistry.byCode('XXX'), isNull);
    });

    test('require throws ArgumentError for an unknown currency', () {
      expect(() => CurrencyRegistry.require('XXX'), throwsArgumentError);
    });
  });
}
