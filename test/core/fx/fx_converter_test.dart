import 'package:ai_financial_coach/core/fx/fx_converter.dart';
import 'package:ai_financial_coach/core/fx/fx_rate.dart';
import 'package:ai_financial_coach/core/fx/fx_rate_pair_mismatch_exception.dart';
import 'package:ai_financial_coach/core/money/money.dart';
import 'package:ai_financial_coach/core/money/money_overflow_exception.dart';
import 'package:flutter_test/flutter_test.dart';

// Checkpoint 9.1 (FX Money Engine & Historical Exchange-Rate Foundation),
// Phase 6: C (exact conversion), D (ROUND HALF UP boundaries), E (high
// precision), F (large values / overflow), G (rate direction), H (same
// currency). Every expected value below is hand-computed with exact
// integer arithmetic in the doc comment right above the test that uses
// it -- never "whatever the code currently returns" -- so a regression
// that changes the *math* (not just refactors it) is caught.
//
// The true signed-64-bit minimum, written this way (rather than the
// literal `-9223372036854775808`) because Dart parses a negative literal
// as unary minus applied to the positive literal, and positive
// 9223372036854775808 itself does not fit in 64 bits.
const int _minInt64 = -9223372036854775807 - 1;
const int _maxInt64 = 9223372036854775807;

void main() {
  group('FxConverter — C: exact conversion (evenly divides, no rounding)', () {
    test('USD -> JPY: \$100.00 @ 150.25 = ¥15025', () {
      // 10000 minor units (USD, 2dp) * 15025 (significand of "150.25",
      // scale 2) * 10^0 (JPY, 0dp) / 10^(2+2) = 150250000 / 10000 = 15025
      // exactly.
      final Money result = FxConverter.convert(
        source: Money.fromMinorUnits(10000, 'USD'),
        targetCurrencyCode: 'JPY',
        rate: FxRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY', rate: '150.25'),
      );
      expect(result, Money.fromMinorUnits(15025, 'JPY'));
    });

    test('JPY -> USD: ¥1000 @ 0.0068 = \$6.80', () {
      // 1000 (JPY, 0dp) * 68 (significand of "0.0068", scale 4) * 10^2
      // (USD, 2dp) / 10^(4+0) = 6800000 / 10000 = 680 exactly.
      final Money result = FxConverter.convert(
        source: Money.fromMinorUnits(1000, 'JPY'),
        targetCurrencyCode: 'USD',
        rate: FxRate(baseCurrencyCode: 'JPY', quoteCurrencyCode: 'USD', rate: '0.0068'),
      );
      expect(result, Money.fromMinorUnits(680, 'USD'));
    });

    test('USD -> KWD: \$100.00 @ 0.307 = KWD 30.700', () {
      // 10000 (USD, 2dp) * 307 (significand of "0.307", scale 3) * 10^3
      // (KWD, 3dp) / 10^(3+2) = 3070000000 / 100000 = 30700 exactly.
      final Money result = FxConverter.convert(
        source: Money.fromMinorUnits(10000, 'USD'),
        targetCurrencyCode: 'KWD',
        rate: FxRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'KWD', rate: '0.307'),
      );
      expect(result, Money.fromMinorUnits(30700, 'KWD'));
    });

    test('KWD -> USD: KWD 1.500 @ 3.26 = \$4.89', () {
      // 1500 (KWD, 3dp) * 326 (significand of "3.26", scale 2) * 10^2
      // (USD, 2dp) / 10^(2+3) = 48900000 / 100000 = 489 exactly.
      final Money result = FxConverter.convert(
        source: Money.fromMinorUnits(1500, 'KWD'),
        targetCurrencyCode: 'USD',
        rate: FxRate(baseCurrencyCode: 'KWD', quoteCurrencyCode: 'USD', rate: '3.26'),
      );
      expect(result, Money.fromMinorUnits(489, 'USD'));
    });

    test('USD -> VND: \$10.00 @ 24500 = ₫245000', () {
      // 1000 (USD, 2dp) * 24500 (significand of "24500", scale 0) * 10^0
      // (VND, 0dp) / 10^(0+2) = 24500000 / 100 = 245000 exactly.
      final Money result = FxConverter.convert(
        source: Money.fromMinorUnits(1000, 'USD'),
        targetCurrencyCode: 'VND',
        rate: FxRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'VND', rate: '24500'),
      );
      expect(result, Money.fromMinorUnits(245000, 'VND'));
    });

    test('VND -> USD: ₫245000 @ 0.00004 = \$9.80', () {
      // 245000 (VND, 0dp) * 4 (significand of "0.00004", scale 5) * 10^2
      // (USD, 2dp) / 10^(5+0) = 98000000 / 100000 = 980 exactly.
      final Money result = FxConverter.convert(
        source: Money.fromMinorUnits(245000, 'VND'),
        targetCurrencyCode: 'USD',
        rate: FxRate(baseCurrencyCode: 'VND', quoteCurrencyCode: 'USD', rate: '0.00004'),
      );
      expect(result, Money.fromMinorUnits(980, 'USD'));
    });

    test('USD -> MMK: \$50.00 @ 2100.50 = MMK 105025.00', () {
      // 5000 (USD, 2dp) * 210050 (significand of "2100.50", scale 2) *
      // 10^2 (MMK, 2dp) / 10^(2+2) = 105025000000 / 10000 = 10502500
      // exactly.
      final Money result = FxConverter.convert(
        source: Money.fromMinorUnits(5000, 'USD'),
        targetCurrencyCode: 'MMK',
        rate: FxRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'MMK', rate: '2100.50'),
      );
      expect(result, Money.fromMinorUnits(10502500, 'MMK'));
    });

    test('MMK -> USD: MMK 105025.00 @ 0.0004 = \$42.01', () {
      // 10502500 (MMK, 2dp) * 4 (significand of "0.0004", scale 4) *
      // 10^2 (USD, 2dp) / 10^(4+2) = 4201000000 / 1000000 = 4201
      // exactly.
      final Money result = FxConverter.convert(
        source: Money.fromMinorUnits(10502500, 'MMK'),
        targetCurrencyCode: 'USD',
        rate: FxRate(baseCurrencyCode: 'MMK', quoteCurrencyCode: 'USD', rate: '0.0004'),
      );
      expect(result, Money.fromMinorUnits(4201, 'USD'));
    });

    test('EUR -> CAD: €200.00 @ 1.475 = CAD 295.00', () {
      // 20000 (EUR, 2dp) * 1475 (significand of "1.475", scale 3) *
      // 10^2 (CAD, 2dp) / 10^(3+2) = 2950000000 / 100000 = 29500
      // exactly.
      final Money result = FxConverter.convert(
        source: Money.fromMinorUnits(20000, 'EUR'),
        targetCurrencyCode: 'CAD',
        rate: FxRate(baseCurrencyCode: 'EUR', quoteCurrencyCode: 'CAD', rate: '1.475'),
      );
      expect(result, Money.fromMinorUnits(29500, 'CAD'));
    });
  });

  group('FxConverter — D: ROUND HALF UP boundaries (half away from zero)', () {
    // All six cases target JPY (0 minor units) so the target's own
    // decimal places can never absorb the fraction being rounded --
    // exactly the "especially test zero-decimal target currencies" case
    // the checkpoint calls out.

    test('below half, positive: \$0.02 @ 150.5 = ¥3 (3.01 rounds down)', () {
      // 2 * 1505 (significand of "150.5", scale 1) * 10^0 / 10^(1+2)
      // = 3010 / 1000 = 3.01 -> rounds down to 3 (fraction .01 < .5).
      final Money result = FxConverter.convert(
        source: Money.fromMinorUnits(2, 'USD'),
        targetCurrencyCode: 'JPY',
        rate: FxRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY', rate: '150.5'),
      );
      expect(result, Money.fromMinorUnits(3, 'JPY'));
    });

    test('exact half, positive: \$0.01 @ 150 = ¥2 (1.5 rounds up, away from zero)', () {
      // 1 * 150 (significand of "150", scale 0) * 10^0 / 10^(0+2)
      // = 150 / 100 = 1.5 exactly -> ties round away from zero -> 2.
      final Money result = FxConverter.convert(
        source: Money.fromMinorUnits(1, 'USD'),
        targetCurrencyCode: 'JPY',
        rate: FxRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY', rate: '150'),
      );
      expect(result, Money.fromMinorUnits(2, 'JPY'));
    });

    test('above half, positive: \$0.01 @ 150.5 = ¥2 (1.505 rounds up)', () {
      // 1 * 1505 * 10^0 / 10^(1+2) = 1505 / 1000 = 1.505 -> rounds up
      // to 2 (fraction .505 > .5).
      final Money result = FxConverter.convert(
        source: Money.fromMinorUnits(1, 'USD'),
        targetCurrencyCode: 'JPY',
        rate: FxRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY', rate: '150.5'),
      );
      expect(result, Money.fromMinorUnits(2, 'JPY'));
    });

    test('below half, negative: -\$0.02 @ 150.5 = -¥3 (-3.01 rounds toward zero)', () {
      // -2 * 1505 * 10^0 / 10^(1+2) = -3010 / 1000 = -3.01 -> the
      // fractional magnitude (.01) is below half, so it rounds to the
      // nearer integer, -3 (not -4).
      final Money result = FxConverter.convert(
        source: Money.fromMinorUnits(-2, 'USD'),
        targetCurrencyCode: 'JPY',
        rate: FxRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY', rate: '150.5'),
      );
      expect(result, Money.fromMinorUnits(-3, 'JPY'));
    });

    test('exact half, negative: -\$0.01 @ 150 = -¥2 (-1.5 rounds away from zero)', () {
      // -1 * 150 * 10^0 / 10^(0+2) = -150 / 100 = -1.5 exactly -> ties
      // round away from zero -> -2 (matches the checkpoint's own
      // "-1.5 -> -2" example).
      final Money result = FxConverter.convert(
        source: Money.fromMinorUnits(-1, 'USD'),
        targetCurrencyCode: 'JPY',
        rate: FxRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY', rate: '150'),
      );
      expect(result, Money.fromMinorUnits(-2, 'JPY'));
    });

    test('above half, negative: -\$0.01 @ 150.5 = -¥2 (-1.505 rounds away from zero)', () {
      // -1 * 1505 * 10^0 / 10^(1+2) = -1505 / 1000 = -1.505 -> magnitude
      // above half -> rounds away from zero -> -2.
      final Money result = FxConverter.convert(
        source: Money.fromMinorUnits(-1, 'USD'),
        targetCurrencyCode: 'JPY',
        rate: FxRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY', rate: '150.5'),
      );
      expect(result, Money.fromMinorUnits(-2, 'JPY'));
    });

    test('exact half against a non-zero-decimal target: ¥1 @ 0.015 = \$0.02', () {
      // 1 (JPY, 0dp) * 15 (significand of "0.015", scale 3) * 10^2
      // (USD, 2dp) / 10^(3+0) = 1500 / 1000 = 1.5 exactly -> rounds up
      // to 2 -- confirms the half-away-from-zero rule isn't special-
      // cased to zero-decimal targets only.
      final Money result = FxConverter.convert(
        source: Money.fromMinorUnits(1, 'JPY'),
        targetCurrencyCode: 'USD',
        rate: FxRate(baseCurrencyCode: 'JPY', quoteCurrencyCode: 'USD', rate: '0.015'),
      );
      expect(result, Money.fromMinorUnits(2, 'USD'));
    });
  });

  group('FxConverter — E: high precision (double would be suspect here)', () {
    test('\$100.00 @ 153.482071 = ¥15348 (15348.2071 rounds down)', () {
      // 10000 (USD, 2dp) * 153482071 (significand of "153.482071",
      // scale 6) * 10^0 (JPY, 0dp) / 10^(6+2)
      // = 1534820710000 / 100000000 = 15348.2071 exactly (computed with
      // BigInt, not double) -> fraction .2071 < .5 -> rounds down to
      // 15348. A double computing 100 * 153.482071 is not guaranteed to
      // land on exactly 15348.2071 -- this BigInt path is.
      final Money result = FxConverter.convert(
        source: Money.fromMinorUnits(10000, 'USD'),
        targetCurrencyCode: 'JPY',
        rate: FxRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY', rate: '153.482071'),
      );
      expect(result, Money.fromMinorUnits(15348, 'JPY'));
    });
  });

  group('FxConverter — F: large values near the signed 64-bit boundary', () {
    test('valid large positive result succeeds', () {
      // maxInt64 (USD, 2dp) * 1 (significand of "1", scale 0) * 10^0
      // (JPY, 0dp) / 10^(0+2) = 9223372036854775807 / 100
      // = 92233720368547758.07 -> rounds down (fraction .07 < .5) to
      // 92233720368547758, comfortably inside int64 range.
      final Money result = FxConverter.convert(
        source: Money.fromMinorUnits(_maxInt64, 'USD'),
        targetCurrencyCode: 'JPY',
        rate: FxRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY', rate: '1'),
      );
      expect(result, Money.fromMinorUnits(92233720368547758, 'JPY'));
    });

    test('valid large negative result succeeds', () {
      // minInt64 / 100 = -92233720368547758.08 -> truncating quotient is
      // -92233720368547758, remainder -8, |remainder|*2 = 16 < 100 ->
      // no rounding adjustment -> stays -92233720368547758.
      final Money result = FxConverter.convert(
        source: Money.fromMinorUnits(_minInt64, 'USD'),
        targetCurrencyCode: 'JPY',
        rate: FxRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY', rate: '1'),
      );
      expect(result, Money.fromMinorUnits(-92233720368547758, 'JPY'));
    });

    test('positive overflow is rejected deterministically, not wrapped/clamped', () {
      // Using a JPY (0dp) source and a whole-number rate makes the
      // denominator 10^(0+0) = 1, so nothing shrinks the product back
      // down -- maxInt64 * 2 * 10^2 (USD, 2dp) vastly exceeds maxInt64.
      expect(
        () => FxConverter.convert(
          source: Money.fromMinorUnits(_maxInt64, 'JPY'),
          targetCurrencyCode: 'USD',
          rate: FxRate(baseCurrencyCode: 'JPY', quoteCurrencyCode: 'USD', rate: '2'),
        ),
        throwsA(
          isA<MoneyOverflowException>()
              .having((e) => e.currencyCode, 'currencyCode', 'USD')
              .having(
                (e) => e.exactMinorUnits,
                'exactMinorUnits',
                BigInt.parse('9223372036854775807') * BigInt.two * BigInt.from(100),
              ),
        ),
      );
    });

    test('negative overflow is rejected deterministically, not wrapped/clamped', () {
      final Money source = Money.fromMinorUnits(_minInt64, 'JPY');
      expect(
        () => FxConverter.convert(
          source: source,
          targetCurrencyCode: 'USD',
          rate: FxRate(baseCurrencyCode: 'JPY', quoteCurrencyCode: 'USD', rate: '2'),
        ),
        throwsA(
          isA<MoneyOverflowException>()
              .having((e) => e.currencyCode, 'currencyCode', 'USD')
              .having(
                (e) => e.exactMinorUnits,
                'exactMinorUnits',
                BigInt.from(_minInt64) * BigInt.two * BigInt.from(100),
              ),
        ),
      );
    });

    // CP9.7 (V1 FX final hardening): Task 5 explicitly calls for "a
    // conversion whose BigInt intermediate exceeds int64 but final result
    // is valid, if mathematically possible under the current
    // implementation". The four cases below were absent -- the existing
    // overflow tests above only ever exercise a JPY (0dp) source with a
    // whole-number rate, which makes the denominator 1 and so never
    // demonstrates a *shrinking* division back down into range. All four
    // expected values were hand-computed with exact integer arithmetic
    // (also cross-checked with a standalone Python script mirroring
    // FxConverter's own numerator/denominator/round-half-up-away-from-zero
    // algorithm) before being written here.
    test(
      'BigInt intermediate vastly exceeds int64 magnitude but final rounded result is valid',
      () {
        // maxInt64 (USD, 2dp) * 999999999999 (significand of
        // "0.999999999999", scale 12) * 10^2 (EUR, 2dp)
        // / 10^(12+2) = 9223372036854775807 * 999999999999 * 100 / 10^14.
        // The numerator itself is a ~110-bit BigInt
        // (922337203684555243496314522419300), far outside signed 64-bit
        // range -- but dividing by the 10^14 denominator brings the
        // truncated quotient down to 9223372036845552434 with remainder
        // 96314522419300; doubling the remainder (192629044838600) is
        // >= the denominator, so ROUND HALF UP away from zero bumps the
        // result up by 1 to 9223372036845552435, which fits comfortably
        // inside int64.
        final Money result = FxConverter.convert(
          source: Money.fromMinorUnits(_maxInt64, 'USD'),
          targetCurrencyCode: 'EUR',
          rate: FxRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'EUR', rate: '0.999999999999'),
        );
        expect(result, Money.fromMinorUnits(9223372036845552435, 'EUR'));
      },
    );

    test('exact positive int64 boundary is a valid result, not rejected as overflow', () {
      // maxInt64 (USD, 2dp) * 1 (significand of "1", scale 0) * 10^2
      // (CAD, 2dp) / 10^(0+2) = maxInt64 * 100 / 100 = maxInt64 exactly,
      // landing precisely on the signed-64-bit ceiling with zero rounding.
      final Money result = FxConverter.convert(
        source: Money.fromMinorUnits(_maxInt64, 'USD'),
        targetCurrencyCode: 'CAD',
        rate: FxRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'CAD', rate: '1'),
      );
      expect(result, Money.fromMinorUnits(_maxInt64, 'CAD'));
    });

    test('exact negative int64 boundary is a valid result, not rejected as overflow', () {
      // minInt64 (USD, 2dp) * 1 * 10^2 (CAD, 2dp) / 10^2 = minInt64
      // exactly, landing precisely on the signed-64-bit floor with zero
      // rounding.
      final Money result = FxConverter.convert(
        source: Money.fromMinorUnits(_minInt64, 'USD'),
        targetCurrencyCode: 'CAD',
        rate: FxRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'CAD', rate: '1'),
      );
      expect(result, Money.fromMinorUnits(_minInt64, 'CAD'));
    });

    test('overflow by the smallest margin the 12-fraction-digit rate cap can produce', () {
      // maxInt64 (USD, 2dp) * 1000000000001 (significand of
      // "1.000000000001", scale 12) * 10^2 (CAD, 2dp) / 10^14. The exact
      // BigInt-rounded result is 9223372036863999179 -- only 9223372 over
      // maxInt64 -- the tightest overflow margin obtainable given
      // FxRate's 12-fraction-digit precision cap, proving the boundary
      // check itself (not just "obviously huge" overflows) is exact.
      expect(
        () => FxConverter.convert(
          source: Money.fromMinorUnits(_maxInt64, 'USD'),
          targetCurrencyCode: 'CAD',
          rate: FxRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'CAD', rate: '1.000000000001'),
        ),
        throwsA(
          isA<MoneyOverflowException>()
              .having((e) => e.currencyCode, 'currencyCode', 'CAD')
              .having(
                (e) => e.exactMinorUnits,
                'exactMinorUnits',
                BigInt.parse('9223372036863999179'),
              ),
        ),
      );
    });
  });

  group('FxConverter — G: rate direction is explicit, never silently inverted', () {
    test('a USD -> JPY rate cannot be used to convert JPY -> USD', () {
      final FxRate usdToJpy = FxRate(
        baseCurrencyCode: 'USD',
        quoteCurrencyCode: 'JPY',
        rate: '150.25',
      );
      expect(
        () => FxConverter.convert(
          source: Money.fromMinorUnits(1000, 'JPY'),
          targetCurrencyCode: 'USD',
          rate: usdToJpy,
        ),
        throwsA(
          isA<FxRatePairMismatchException>()
              .having((e) => e.requiredBaseCurrencyCode, 'requiredBaseCurrencyCode', 'JPY')
              .having((e) => e.requiredQuoteCurrencyCode, 'requiredQuoteCurrencyCode', 'USD')
              .having((e) => e.rate, 'rate', usdToJpy),
        ),
      );
    });

    test('a rate whose quote currency does not match the target is rejected', () {
      final FxRate usdToJpy = FxRate(
        baseCurrencyCode: 'USD',
        quoteCurrencyCode: 'JPY',
        rate: '150.25',
      );
      expect(
        () => FxConverter.convert(
          source: Money.fromMinorUnits(1000, 'USD'),
          targetCurrencyCode: 'KWD', // rate is quoted in JPY, not KWD
          rate: usdToJpy,
        ),
        throwsA(isA<FxRatePairMismatchException>()),
      );
    });

    test('omitting the required rate for a cross-currency conversion throws ArgumentError', () {
      expect(
        () => FxConverter.convert(source: Money.fromMinorUnits(1000, 'USD'), targetCurrencyCode: 'JPY'),
        throwsArgumentError,
      );
    });
  });

  group('FxConverter — H: same-currency identity conversion', () {
    test('USD -> USD returns identical minor units, no rate required', () {
      final Money source = Money.fromMinorUnits(123456, 'USD');
      final Money result = FxConverter.convert(source: source, targetCurrencyCode: 'USD');
      expect(result, source);
    });

    test('JPY -> JPY returns identical minor units, no rate required', () {
      final Money source = Money.fromMinorUnits(987654, 'JPY');
      final Money result = FxConverter.convert(source: source, targetCurrencyCode: 'JPY');
      expect(result, source);
    });

    test('KWD -> KWD returns identical minor units, no rate required', () {
      final Money source = Money.fromMinorUnits(1500, 'KWD');
      final Money result = FxConverter.convert(source: source, targetCurrencyCode: 'KWD');
      expect(result, source);
    });

    test('a same-currency conversion ignores an irrelevant rate passed in anyway', () {
      final Money source = Money.fromMinorUnits(500, 'USD');
      // This rate's pair doesn't even mention USD -> USD; if it were
      // consulted at all this would throw FxRatePairMismatchException.
      final Money result = FxConverter.convert(
        source: source,
        targetCurrencyCode: 'USD',
        rate: FxRate(baseCurrencyCode: 'EUR', quoteCurrencyCode: 'JPY', rate: '150'),
      );
      expect(result, source);
    });
  });
}
