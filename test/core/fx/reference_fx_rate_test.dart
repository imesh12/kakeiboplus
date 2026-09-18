import 'package:ai_financial_coach/core/fx/fx_rate.dart';
import 'package:ai_financial_coach/core/fx/invalid_reference_fx_rate_exception.dart';
import 'package:ai_financial_coach/core/fx/reference_fx_rate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  FxRate usdToJpy() => FxRate(
        baseCurrencyCode: 'USD',
        quoteCurrencyCode: 'JPY',
        rate: '150.25',
      );

  group('ReferenceFxRate — UTC contract (CP9.2 Task B)', () {
    test('a UTC observedAt round-trips as the exact same instant, re-tagged UTC', () {
      final DateTime observed = DateTime.utc(2026, 6, 1, 9, 30, 0);
      final ReferenceFxRate rate = ReferenceFxRate(
        rate: usdToJpy(),
        source: 'fake-provider',
        observedAt: observed,
        fetchedAt: observed,
      );

      expect(rate.observedAt.isUtc, isTrue);
      expect(rate.observedAt.isAtSameMomentAs(observed), isTrue);
    });

    test('a UTC fetchedAt round-trips as the exact same instant, re-tagged UTC', () {
      final DateTime observed = DateTime.utc(2026, 6, 1, 9, 30, 0);
      final DateTime fetched = DateTime.utc(2026, 6, 1, 9, 30, 5);
      final ReferenceFxRate rate = ReferenceFxRate(
        rate: usdToJpy(),
        source: 'fake-provider',
        observedAt: observed,
        fetchedAt: fetched,
      );

      expect(rate.fetchedAt.isUtc, isTrue);
      expect(rate.fetchedAt.isAtSameMomentAs(fetched), isTrue);
    });

    test('a local-tagged input is normalized to UTC, preserving the exact instant', () {
      // DateTime.toUtc() never changes what instant a DateTime
      // represents -- it only changes its tag. Constructing with a
      // local-tagged DateTime must therefore still compare equal (same
      // instant) to the UTC-tagged version of that same instant, while
      // itself reporting isUtc == true afterward.
      final DateTime localObserved = DateTime(2026, 6, 1, 18, 30, 0); // local tag
      final ReferenceFxRate rate = ReferenceFxRate(
        rate: usdToJpy(),
        source: 'fake-provider',
        observedAt: localObserved,
        fetchedAt: localObserved,
      );

      expect(rate.observedAt.isUtc, isTrue);
      expect(rate.fetchedAt.isUtc, isTrue);
      expect(rate.observedAt.isAtSameMomentAs(localObserved), isTrue);
      expect(rate.fetchedAt.isAtSameMomentAs(localObserved), isTrue);
    });
  });

  group('ReferenceFxRate — source validation', () {
    test('rejects an empty source', () {
      final DateTime now = DateTime.utc(2026, 6, 1);
      expect(
        () => ReferenceFxRate(rate: usdToJpy(), source: '', observedAt: now, fetchedAt: now),
        throwsA(isA<InvalidReferenceFxRateException>()),
      );
    });

    test('rejects a whitespace-only source', () {
      final DateTime now = DateTime.utc(2026, 6, 1);
      expect(
        () => ReferenceFxRate(rate: usdToJpy(), source: '   ', observedAt: now, fetchedAt: now),
        throwsA(isA<InvalidReferenceFxRateException>()),
      );
    });

    test('trims a valid source', () {
      final DateTime now = DateTime.utc(2026, 6, 1);
      final ReferenceFxRate rate = ReferenceFxRate(
        rate: usdToJpy(),
        source: '  fake-provider  ',
        observedAt: now,
        fetchedAt: now,
      );
      expect(rate.source, 'fake-provider');
    });
  });

  group('ReferenceFxRate — no double, exact rate, convenience accessors', () {
    test('baseCurrencyCode/quoteCurrencyCode delegate to the wrapped FxRate', () {
      final DateTime now = DateTime.utc(2026, 6, 1);
      final ReferenceFxRate rate = ReferenceFxRate(
        rate: usdToJpy(),
        source: 'fake-provider',
        observedAt: now,
        fetchedAt: now,
      );
      expect(rate.baseCurrencyCode, 'USD');
      expect(rate.quoteCurrencyCode, 'JPY');
      expect(rate.rate.rateAsString, '150.25');
    });

    test('two ReferenceFxRates with identical fields are equal', () {
      final DateTime now = DateTime.utc(2026, 6, 1);
      final ReferenceFxRate a = ReferenceFxRate(
        rate: usdToJpy(),
        source: 'fake-provider',
        observedAt: now,
        fetchedAt: now,
      );
      final ReferenceFxRate b = ReferenceFxRate(
        rate: usdToJpy(),
        source: 'fake-provider',
        observedAt: now,
        fetchedAt: now,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}
