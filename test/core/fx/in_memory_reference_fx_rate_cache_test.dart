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
    test('returns null for a pair nothing has been cached for', () async {
      final InMemoryReferenceFxRateCache cache = InMemoryReferenceFxRateCache();
      expect(await cache.get(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY'), isNull);
    });

    test('put then get returns the exact cached rate', () async {
      final InMemoryReferenceFxRateCache cache = InMemoryReferenceFxRateCache();
      final ReferenceFxRate rate = rateFor(base: 'USD', quote: 'JPY', rateValue: '150.25');
      await cache.put(rate);
      expect(await cache.get(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY'), rate);
    });

    test('put overwrites a prior entry for the exact same pair', () async {
      final InMemoryReferenceFxRateCache cache = InMemoryReferenceFxRateCache();
      await cache.put(rateFor(base: 'USD', quote: 'JPY', rateValue: '150.25'));
      final ReferenceFxRate refreshed = rateFor(base: 'USD', quote: 'JPY', rateValue: '151.00');
      await cache.put(refreshed);
      expect(await cache.get(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY'), refreshed);
    });
  });

  group('InMemoryReferenceFxRateCache — pair safety (direction matters)', () {
    test('USD->JPY and JPY->USD are independent cache slots', () async {
      final InMemoryReferenceFxRateCache cache = InMemoryReferenceFxRateCache();
      final ReferenceFxRate usdToJpy = rateFor(base: 'USD', quote: 'JPY', rateValue: '150.25');
      await cache.put(usdToJpy);

      expect(await cache.get(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY'), usdToJpy);
      // The inverse pair must never read the forward pair's entry -- no
      // implicit inversion, ever.
      expect(await cache.get(baseCurrencyCode: 'JPY', quoteCurrencyCode: 'USD'), isNull);
    });

    test('caching multiple unrelated pairs does not cross-contaminate', () async {
      final InMemoryReferenceFxRateCache cache = InMemoryReferenceFxRateCache();
      final ReferenceFxRate usdToJpy = rateFor(base: 'USD', quote: 'JPY', rateValue: '150.25');
      final ReferenceFxRate eurToUsd = rateFor(base: 'EUR', quote: 'USD', rateValue: '1.08');
      await cache.put(usdToJpy);
      await cache.put(eurToUsd);

      expect(await cache.get(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY'), usdToJpy);
      expect(await cache.get(baseCurrencyCode: 'EUR', quoteCurrencyCode: 'USD'), eurToUsd);
    });

    test('cache keys are case-insensitive, matching canonical upper-case currency codes', () async {
      final InMemoryReferenceFxRateCache cache = InMemoryReferenceFxRateCache();
      final ReferenceFxRate usdToJpy = rateFor(base: 'USD', quote: 'JPY', rateValue: '150.25');
      await cache.put(usdToJpy);
      expect(await cache.get(baseCurrencyCode: 'usd', quoteCurrencyCode: 'jpy'), usdToJpy);
    });
  });

  group('InMemoryReferenceFxRateCache — removeIfPresent', () {
    test('removes an existing entry for the exact pair', () async {
      final InMemoryReferenceFxRateCache cache = InMemoryReferenceFxRateCache();
      await cache.put(rateFor(base: 'USD', quote: 'JPY', rateValue: '150.25'));
      await cache.removeIfPresent(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY');
      expect(await cache.get(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY'), isNull);
    });

    test('is a no-op (does not throw) when nothing is cached for that pair', () async {
      final InMemoryReferenceFxRateCache cache = InMemoryReferenceFxRateCache();
      await expectLater(
        cache.removeIfPresent(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY'),
        completes,
      );
    });

    test('does not affect a different pair', () async {
      final InMemoryReferenceFxRateCache cache = InMemoryReferenceFxRateCache();
      final ReferenceFxRate eurToUsd = rateFor(base: 'EUR', quote: 'USD', rateValue: '1.08');
      await cache.put(rateFor(base: 'USD', quote: 'JPY', rateValue: '150.25'));
      await cache.put(eurToUsd);

      await cache.removeIfPresent(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY');

      expect(await cache.get(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY'), isNull);
      expect(await cache.get(baseCurrencyCode: 'EUR', quoteCurrencyCode: 'USD'), eurToUsd);
    });
  });
}
