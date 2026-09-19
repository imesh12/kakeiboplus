import 'package:ai_financial_coach/core/fx/fx_rate.dart';
import 'package:ai_financial_coach/core/fx/reference_fx_rate_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

// Checkpoint 9.5's "CRITICAL RATE FORMATTING" rule: an FX rate's own
// precision is never the target currency's minor-unit precision, never
// rendered via `double`, never in scientific notation, and never padded
// with invented trailing zeros. These tests lock that contract in
// directly against `ReferenceFxRateFormatter`, independent of any UI.

void main() {
  const ReferenceFxRateFormatter formatter = ReferenceFxRateFormatter();

  FxRate rate(String value) =>
      FxRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY', rate: value);

  group('1. plain decimal rendering', () {
    test('a typical multi-digit rate with a fractional part renders unchanged', () {
      expect(formatter.format(rate('149.85')), '149.85');
    });

    test('a whole-number rate (no fractional part) renders with no trailing decimal point', () {
      expect(formatter.format(rate('151')), '151');
    });
  });

  group('2. canonicalization -- no invented or dropped digits', () {
    test('a rate string with a trailing-zero fraction canonicalizes to Decimal.toString() exactly', () {
      // FxRate stores `Decimal.parse('151.00')`, whose own `toString()`
      // canonicalizes to "151" -- the formatter must reflect that
      // canonical form, never re-padding it back to "151.00".
      expect(formatter.format(rate('151.00')), '151');
    });

    test('a rate with a non-zero trailing digit after a would-be-dropped zero keeps it (grouping still applies to the integer part)', () {
      // 2100.50 -> the trailing zero is dropped (matching Decimal.toString()
      // canonicalization) but the non-zero '.5' is preserved; the integer
      // part '2100' is still thousands-grouped per this formatter's
      // deliberate V1 policy (see ADR-027 / group 3 below), so the correct
      // expectation is '2,100.5', not the ungrouped '2100.5'.
      expect(formatter.format(rate('2100.50')), '2,100.5');
    });
  });

  group('3. thousands grouping on the integer part only', () {
    test('a four-digit integer part gets one group separator', () {
      expect(formatter.format(rate('1234.5')), '1,234.5');
    });

    test('a seven-digit integer part gets two group separators', () {
      expect(formatter.format(rate('1234567')), '1,234,567');
    });

    test('the fractional part is never grouped, however many digits it has', () {
      expect(formatter.format(rate('1234.123456789012')), '1,234.123456789012');
    });
  });

  group('4. very small rates', () {
    test('a rate far below 1 renders every fractional digit, ungrouped, with no scientific notation', () {
      expect(formatter.format(rate('0.0000001')), '0.0000001');
    });
  });

  group('5. no double anywhere', () {
    test('a rate at the 12-fractional-digit precision ceiling renders exactly, without float rounding', () {
      // 0.123456789012 is not exactly representable in binary
      // floating-point; a correct implementation never round-trips
      // through `double`, so this must render back exactly as typed.
      expect(formatter.format(rate('0.123456789012')), '0.123456789012');
    });
  });

  group('6. custom group separator', () {
    test('a formatter constructed with a different group separator uses it consistently', () {
      const ReferenceFxRateFormatter periodGrouped = ReferenceFxRateFormatter(groupSeparator: '.');
      expect(periodGrouped.format(rate('1234567.89')), '1.234.567.89');
    });
  });
}
