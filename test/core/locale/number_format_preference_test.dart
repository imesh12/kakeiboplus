import 'package:ai_financial_coach/core/locale/number_format_preference.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NumberFormatRegistry', () {
    test('comma_period has the expected separators', () {
      final NumberFormatPreference pref = NumberFormatRegistry.byId('comma_period');
      expect(pref, NumberFormatRegistry.commaGroupPeriodDecimal);
      expect(pref.groupSeparator, ',');
      expect(pref.decimalSeparator, '.');
    });

    test('period_comma has the expected separators', () {
      final NumberFormatPreference pref = NumberFormatRegistry.byId('period_comma');
      expect(pref, NumberFormatRegistry.periodGroupCommaDecimal);
      expect(pref.groupSeparator, '.');
      expect(pref.decimalSeparator, ',');
    });

    test('explicit legacy "#,##0.##" resolves to comma_period, not just generic fallback', () {
      expect(
        NumberFormatRegistry.byId('#,##0.##'),
        same(NumberFormatRegistry.commaGroupPeriodDecimal),
      );
    });

    test('byId falls back to comma_period for null', () {
      expect(NumberFormatRegistry.byId(null), NumberFormatRegistry.commaGroupPeriodDecimal);
    });

    test('byId falls back to comma_period for an unknown/corrupt id', () {
      expect(NumberFormatRegistry.byId('nonsense'), NumberFormatRegistry.commaGroupPeriodDecimal);
      expect(NumberFormatRegistry.byId(''), NumberFormatRegistry.commaGroupPeriodDecimal);
    });

    test('exactly 2 selectable preferences are supported', () {
      expect(NumberFormatRegistry.supported, hasLength(2));
      expect(
        NumberFormatRegistry.supported.map((NumberFormatPreference p) => p.id).toSet(),
        <String>{'comma_period', 'period_comma'},
      );
    });

    test('no Indian-grouping (or any other) preference is present', () {
      expect(
        NumberFormatRegistry.supported.map((NumberFormatPreference p) => p.id),
        isNot(contains('indian')),
      );
    });

    test('the legacy raw value is not itself in the selectable list', () {
      expect(
        NumberFormatRegistry.supported.map((NumberFormatPreference p) => p.id),
        isNot(contains('#,##0.##')),
      );
    });

    test('fallback is comma_period', () {
      expect(NumberFormatRegistry.fallback, NumberFormatRegistry.commaGroupPeriodDecimal);
    });
  });
}
