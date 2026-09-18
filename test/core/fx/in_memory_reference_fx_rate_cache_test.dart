import 'package:ai_financial_coach/core/fx/fx_rate.dart';
import 'package:ai_financial_coach/core/fx/in_memory_reference_fx_rate_cache.dart';
import 'package:ai_financial_coach/core/fx/reference_fx_rate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime fixedNow = DateTime.utc(2026, 6, 1, 12, 0, 0);

  ReferenceFxRate rateFor({
    required String base,
    required String quote,
    required String rateValue,
  }) =>
      ReferenceFxRate(
        rate: FxRate(baseCurrencyCode: base, quoteCurrencyCode: quote, rate: rateValue),
        source: 'fake-provider',
        observedAt: fixedNow,
        fetchedAt: fixedNow,
      );

  group('InMemoryReferenceFxRateCache — basic get/put', () {
    test('returns null for a pair nothing has been cached for', () {
      final InMemoryReferenceFxRateCache cache = InMemoryReferenceFxRateCache();
      expect(cache.get(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY'), isNull);
    });

    test('put then get returns the exact cached rate', () {
      final InMemoryReferenceFxRateCache cache = InMemoryReferenceFxRateCache();
      final ReferenceFxRate rate = rateFor(base: 'USD', quote: 'JPY', rateValue: '150.25');
      cache.put(rate);
      expect(cache.get(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY'), rate);
    });

    test('put overwrites a prior entry for the exact same pair', () {
      final InMemoryReferenceFxRateCache cache = InMemoryReferenceFxRateCache();
      cache.put(rateFor(base: 'USD', quote: 'JPY', rateValue: '150.25'));
      final ReferenceFxRate refreshed = rateFor(base: 'USD', quote: 'JPY', rateValue: '151.00');
      cache.put(refreshed);
      expect(cache.get(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY'), refreshed);
    });
  });

  group('InMemoryReferenceFxRateCache — pair safety (direction matters)', () {
    test('USD->JPY and JPY->USD are independent cache slots', () {
      final InMemoryReferenceFxRateCache cache = InMemoryReferenceFxRateCache();
      final ReferenceFxRate usdToJpy = rateFor(base: 'USD', quote: 'JPY', rateValue: '150.25');
      cache.put(usdToJpy);

      expect(cache.get(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY'), usdToJpy);
      // The inverse pair must never read the forward pair's entry -- no
      // implicit inversion, ever.
      expect(cache.get(baseCurrencyCode: 'JPY', quoteCurrencyCode: 'USD'), isNull);
    });

    test('caching multiple unrelated pairs does not cross-contaminate', () {
      final InMemoryReferenceFxRateCache cache = InMemoryReferenceFxRateCache();
      final ReferenceFxRate usdToJpy = rateFor(base: 'USD', quote: 'JPY', rateValue: '150.25');
      final ReferenceFxRate eurToUsd = rateFor(base: 'EUR', quote: 'USD', rateValue: '1.08');
      cache.put(usdToJpy);
      cache.put(eurToUsd);

      expect(cache.get(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY'), usdToJpy);
      expect(cache.get(baseCurrencyCode: 'EUR', quoteCurrencyCode: 'USD'), eurToUsd);
    });

    test('cache keys are case-insensitive, matching canonical upper-case currency codes', () {
      final InMemoryReferenceFxRateCache cache = InMemoryReferenceFxRateCache();
      final ReferenceFxRate usdToJpy = rateFor(base: 'USD', quote: 'JPY', rateValue: '150.25');
      cache.put(usdToJpy);
      expect(cache.get(baseCurrencyCode: 'usd', quoteCurrencyCode: 'jpy'), usdToJpy);
    });
  });

  group('InMemoryReferenceFxRateCache — removeIfPresent', () {
    test('removes an existing entry for the exact pair', () {
      final InMemoryReferenceFxRateCache cache = InMemoryReferenceFxRateCache();
      cache.put(rateFor(base: 'USD', quote: 'JPY', rateValue: '150.25'));
      cache.removeIfPresent(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY');
      expect(cache.get(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY'), isNull);
    });

    test('is a no-op (does not throw) when nothing is cached for that pair', () {
      final InMemoryReferenceFxRateCache cache = InMemoryReferenceFxRateCache();
      expect(
        () => cache.removeIfPresent(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY'),
        returnsNormally,
      );
    });

    test('does not affect a different pair', () {
      final InMemoryReferenceFxRateCache cache = InMemoryReferenceFxRateCache();
      final ReferenceFxRate eurToUsd = rateFor(base: 'EUR', quote: 'USD', rateValue: '1.08');
      cache.put(rateFor(base: 'USD', quote: 'JPY', rateValue: '150.25'));
      cache.put(eurToUsd);

      cache.removeIfPresent(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY');

      expect(cache.get(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY'), isNull);
      expect(cache.get(baseCurrencyCode: 'EUR', quoteCurrencyCode: 'USD'), eurToUsd);
    });
  });
}
