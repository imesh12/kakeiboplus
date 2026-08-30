import 'package:ai_financial_coach/core/money/money.dart';
import 'package:ai_financial_coach/core/money/money_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const MoneyFormatter formatter = MoneyFormatter();

  group('MoneyFormatter — currency-metadata-driven precision', () {
    test('JPY has no decimal point', () {
      expect(formatter.format(Money.fromMinorUnits(1200, 'JPY')), '¥1,200');
    });

    test('KWD shows three decimal digits', () {
      expect(formatter.format(Money.fromMinorUnits(1234, 'KWD')), 'د.ك1.234');
    });

    test('USD shows two decimal digits', () {
      expect(formatter.format(Money.fromMinorUnits(1234, 'USD')), r'$12.34');
    });

    test('grouping separators appear every three digits', () {
      expect(formatter.format(Money.fromMinorUnits(123456789, 'JPY')), '¥123,456,789');
    });

    test('negative amounts render with a leading minus after the symbol', () {
      expect(formatter.format(Money.fromMinorUnits(-1234, 'USD')), r'-$12.34');
    });

    test('small amounts still show the full minor-unit precision zero-padded', () {
      expect(formatter.format(Money.fromMinorUnits(5, 'KWD')), 'د.ك0.005');
    });

    test('amounts under 1000 have no grouping separator', () {
      expect(formatter.format(Money.fromMinorUnits(999, 'JPY')), '¥999');
    });
  });
}
