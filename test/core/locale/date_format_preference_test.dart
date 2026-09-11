import 'package:ai_financial_coach/core/locale/date_format_preference.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DateFormatRegistry', () {
    test('byId resolves ymd', () {
      expect(DateFormatRegistry.byId('ymd'), DateFormatRegistry.yearMonthDay);
    });

    test('byId resolves dmy', () {
      expect(DateFormatRegistry.byId('dmy'), DateFormatRegistry.dayMonthYear);
    });

    test('byId resolves mdy', () {
      expect(DateFormatRegistry.byId('mdy'), DateFormatRegistry.monthDayYear);
    });

    test('explicit legacy "yyyy-MM-dd" resolves to ymd, not just generic fallback', () {
      expect(DateFormatRegistry.byId('yyyy-MM-dd'), same(DateFormatRegistry.yearMonthDay));
    });

    test('byId falls back to ymd for null', () {
      expect(DateFormatRegistry.byId(null), DateFormatRegistry.yearMonthDay);
    });

    test('byId falls back to ymd for an unknown/corrupt id', () {
      expect(DateFormatRegistry.byId('garbage'), DateFormatRegistry.yearMonthDay);
      expect(DateFormatRegistry.byId(''), DateFormatRegistry.yearMonthDay);
    });

    test('exactly 3 selectable preferences are supported', () {
      expect(DateFormatRegistry.supported, hasLength(3));
      expect(
        DateFormatRegistry.supported.map((DateFormatPreference p) => p.id).toSet(),
        <String>{'ymd', 'dmy', 'mdy'},
      );
    });

    test('the legacy raw value "yyyy-MM-dd" is not itself in the selectable list', () {
      expect(
        DateFormatRegistry.supported.map((DateFormatPreference p) => p.id),
        isNot(contains('yyyy-MM-dd')),
      );
    });

    test('fallback is ymd', () {
      expect(DateFormatRegistry.fallback, DateFormatRegistry.yearMonthDay);
    });
  });
}
