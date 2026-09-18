import 'package:ai_financial_coach/core/fx/fx_rate.dart';
import 'package:ai_financial_coach/core/fx/fx_rate_provider.dart';
import 'package:ai_financial_coach/core/fx/in_memory_reference_fx_rate_cache.dart';
import 'package:ai_financial_coach/core/fx/reference_fx_rate.dart';
import 'package:ai_financial_coach/core/fx/reference_fx_rate_cache.dart';
import 'package:ai_financial_coach/core/fx/reference_fx_rate_service.dart';
import 'package:ai_financial_coach/core/fx/reference_rate_result.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hand-written fake -- this project uses no mocking library (see
/// `pubspec.yaml`'s dev_dependencies comment); every test that needs a
/// collaborator writes a real, explicit fake instead.
///
/// [nextResult] is consulted once per [fetchRates] call and NOT reset
/// automatically -- tests set it to whatever the provider should return
/// next. [callCount] lets tests assert whether the provider was called
/// at all (e.g. a fresh cache hit must never call it).
class _FakeFxRateProvider implements FxRateProvider {
  FxRateProviderResult? nextResult;
  int callCount = 0;
  Set<String>? lastRequestedQuoteCurrencyCodes;
  String? lastRequestedBaseCurrencyCode;

  @override
  Future<FxRateProviderResult> fetchRates({
    required String baseCurrencyCode,
    required Set<String> quoteCurrencyCodes,
  }) async {
    callCount++;
    lastRequestedBaseCurrencyCode = baseCurrencyCode;
    lastRequestedQuoteCurrencyCodes = quoteCurrencyCodes;
    final FxRateProviderResult? result = nextResult;
    if (result == null) {
      throw StateError('_FakeFxRateProvider.nextResult was not set before fetchRates was called.');
    }
    return result;
  }
}

void main() {
  late DateTime currentTime;
  late _FakeFxRateProvider provider;
  late ReferenceFxRateCache cache;
  late ReferenceFxRateService service;

  ReferenceFxRate rateFor({
    String base = 'USD',
    String quote = 'JPY',
    String rateValue = '150.25',
    String source = 'fake-provider',
    DateTime? observedAt,
    DateTime? fetchedAt,
  }) =>
      ReferenceFxRate(
        rate: FxRate(baseCurrencyCode: base, quoteCurrencyCode: quote, rate: rateValue),
        source: source,
        observedAt: observedAt ?? currentTime,
        fetchedAt: fetchedAt ?? currentTime,
      );

  setUp(() {
    currentTime = DateTime.utc(2026, 6, 1, 12, 0, 0);
    provider = _FakeFxRateProvider();
    cache = InMemoryReferenceFxRateCache();
    service = ReferenceFxRateService(
      provider: provider,
      cache: cache,
      nowUtc: () => currentTime,
    );
  });

  group('1. fresh cache', () {
    test('a cache hit within the freshness window is served without calling the provider', () async {
      final ReferenceFxRate cached = rateFor(fetchedAt: currentTime);
      await cache.put(cached);

      final ReferenceRateResult result =
          await service.referenceRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY');

      expect(result, isA<ReferenceRateFresh>());
      expect((result as ReferenceRateFresh).rate, cached);
      expect(provider.callCount, 0);
    });
  });

  group('2. exact freshness boundary', () {
    test('age exactly equal to the freshness window still counts as fresh', () async {
      final ReferenceFxRate cached = rateFor(
        fetchedAt: currentTime.subtract(const Duration(hours: 1)),
      );
      await cache.put(cached);

      final ReferenceRateResult result =
          await service.referenceRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY');

      expect(result, isA<ReferenceRateFresh>());
      expect(provider.callCount, 0);
    });

    test('age one second past the freshness window is stale and triggers a refresh attempt', () async {
      final ReferenceFxRate cached = rateFor(
        fetchedAt: currentTime.subtract(const Duration(hours: 1, seconds: 1)),
      );
      await cache.put(cached);
      provider.nextResult = const FxRateProviderFailure('provider unreachable');

      final ReferenceRateResult result =
          await service.referenceRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY');

      expect(result, isA<ReferenceRateStale>());
      expect((result as ReferenceRateStale).rate, cached);
      expect(provider.callCount, 1);
    });
  });

  group('3. stale + success', () {
    test('a successful refresh replaces the stale entry and returns fresh', () async {
      final ReferenceFxRate stale = rateFor(
        rateValue: '150.25',
        fetchedAt: currentTime.subtract(const Duration(hours: 2)),
      );
      await cache.put(stale);
      final ReferenceFxRate refreshed = rateFor(rateValue: '151.00', fetchedAt: currentTime);
      provider.nextResult = FxRateProviderSuccess(<ReferenceFxRate>[refreshed]);

      final ReferenceRateResult result =
          await service.referenceRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY');

      expect(result, isA<ReferenceRateFresh>());
      expect((result as ReferenceRateFresh).rate, refreshed);
      expect(await cache.get(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY'), refreshed);
    });
  });

  group('4. stale + failure', () {
    test('a failed refresh falls back to the stale cached rate', () async {
      final ReferenceFxRate stale = rateFor(
        fetchedAt: currentTime.subtract(const Duration(hours: 2)),
      );
      await cache.put(stale);
      provider.nextResult = const FxRateProviderFailure('provider unreachable');

      final ReferenceRateResult result =
          await service.referenceRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY');

      expect(result, isA<ReferenceRateStale>());
      expect((result as ReferenceRateStale).rate, stale);
      // The failed refresh must never poison/clear the still-usable stale entry.
      expect(await cache.get(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY'), stale);
    });
  });

  group('5. no-cache + success', () {
    test('an empty cache with a successful fetch returns fresh and populates the cache', () async {
      final ReferenceFxRate fetched = rateFor(fetchedAt: currentTime);
      provider.nextResult = FxRateProviderSuccess(<ReferenceFxRate>[fetched]);

      final ReferenceRateResult result =
          await service.referenceRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY');

      expect(result, isA<ReferenceRateFresh>());
      expect((result as ReferenceRateFresh).rate, fetched);
      expect(await cache.get(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY'), fetched);
    });
  });

  group('6. no-cache + failure', () {
    test('an empty cache with a failed fetch is unavailable, reason providerFailed', () async {
      provider.nextResult = const FxRateProviderFailure('provider unreachable');

      final ReferenceRateResult result =
          await service.referenceRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY');

      expect(result, isA<ReferenceRateUnavailable>());
      expect(
        (result as ReferenceRateUnavailable).reason,
        ReferenceRateUnavailableReason.providerFailed,
      );
    });
  });

  group('7. wrong provider pair', () {
    test('a success response for a different pair is never relabeled as the requested one', () async {
      // Asked for USD -> JPY; provider only quotes EUR -> USD.
      final ReferenceFxRate wrongPair = rateFor(base: 'EUR', quote: 'USD', rateValue: '1.08');
      provider.nextResult = FxRateProviderSuccess(<ReferenceFxRate>[wrongPair]);

      final ReferenceRateResult result =
          await service.referenceRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY');

      expect(result, isA<ReferenceRateUnavailable>());
      expect(
        (result as ReferenceRateUnavailable).reason,
        ReferenceRateUnavailableReason.pairMismatch,
      );
    });

    test('a wrong-pair response falls back to a stale cached rate when one exists', () async {
      final ReferenceFxRate stale = rateFor(
        fetchedAt: currentTime.subtract(const Duration(hours: 2)),
      );
      await cache.put(stale);
      final ReferenceFxRate wrongPair = rateFor(base: 'EUR', quote: 'USD', rateValue: '1.08');
      provider.nextResult = FxRateProviderSuccess(<ReferenceFxRate>[wrongPair]);

      final ReferenceRateResult result =
          await service.referenceRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY');

      expect(result, isA<ReferenceRateStale>());
      expect((result as ReferenceRateStale).rate, stale);
    });
  });

  group('8. cache direction (service-level)', () {
    test('caching USD->JPY never satisfies a JPY->USD request', () async {
      await cache.put(rateFor(base: 'USD', quote: 'JPY'));
      provider.nextResult = const FxRateProviderFailure('provider unreachable');

      final ReferenceRateResult result =
          await service.referenceRate(baseCurrencyCode: 'JPY', quoteCurrencyCode: 'USD');

      // No cache entry for JPY->USD and the provider fails -> unavailable,
      // never a silently-inverted USD->JPY rate presented as JPY->USD.
      expect(result, isA<ReferenceRateUnavailable>());
      expect(provider.lastRequestedBaseCurrencyCode, 'JPY');
      expect(provider.lastRequestedQuoteCurrencyCodes, <String>{'USD'});
    });
  });

  group('9. same currency', () {
    test('USD -> USD returns identity without touching the cache or provider', () async {
      final ReferenceRateResult result =
          await service.referenceRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'USD');

      expect(result, isA<ReferenceRateIdentity>());
      expect((result as ReferenceRateIdentity).currencyCode, 'USD');
      expect(provider.callCount, 0);
    });

    test('JPY -> JPY (0 minor units) returns identity', () async {
      final ReferenceRateResult result =
          await service.referenceRate(baseCurrencyCode: 'JPY', quoteCurrencyCode: 'JPY');
      expect(result, isA<ReferenceRateIdentity>());
      expect((result as ReferenceRateIdentity).currencyCode, 'JPY');
      expect(provider.callCount, 0);
    });

    test('KWD -> KWD (3 minor units) returns identity', () async {
      final ReferenceRateResult result =
          await service.referenceRate(baseCurrencyCode: 'KWD', quoteCurrencyCode: 'KWD');
      expect(result, isA<ReferenceRateIdentity>());
      expect((result as ReferenceRateIdentity).currencyCode, 'KWD');
      expect(provider.callCount, 0);
    });

    test('same currency compared case-insensitively still resolves to identity', () async {
      final ReferenceRateResult result =
          await service.referenceRate(baseCurrencyCode: 'usd', quoteCurrencyCode: 'USD');
      expect(result, isA<ReferenceRateIdentity>());
      expect(provider.callCount, 0);
    });
  });

  group('10. timestamp UTC independence', () {
    test(
      'freshness is computed correctly even when nowUtc is supplied with a local-tagged '
      'DateTime representing the same instant as fetchedAt (the CP9.1 "+9 hours" bug shape)',
      () async {
        final DateTime utcInstant = DateTime.utc(2026, 6, 1, 12, 0, 0);
        // Same instant as utcInstant, but tagged local -- if age were ever
        // computed by comparing wall-clock fields instead of true
        // instants, this would look many hours old/new depending on the
        // machine's offset from UTC.
        currentTime = utcInstant.toLocal();

        final ReferenceFxRate cached = rateFor(fetchedAt: utcInstant);
        await cache.put(cached);

        final ReferenceRateResult result =
            await service.referenceRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY');

        expect(result, isA<ReferenceRateFresh>());
        expect(provider.callCount, 0);
      },
    );

    test('a provider quote constructed from a local-tagged observedAt is still handled correctly', () async {
      final DateTime utcInstant = DateTime.utc(2026, 6, 1, 12, 0, 0);
      currentTime = utcInstant;
      final ReferenceFxRate fetched = rateFor(
        observedAt: utcInstant.toLocal(), // local tag, same instant as "now"
        fetchedAt: utcInstant.toLocal(),
      );
      provider.nextResult = FxRateProviderSuccess(<ReferenceFxRate>[fetched]);

      final ReferenceRateResult result =
          await service.referenceRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY');

      // Must be accepted as fresh (not rejected as "future") -- the
      // instant is exactly "now", regardless of the tag it arrived with.
      expect(result, isA<ReferenceRateFresh>());
    });
  });

  group('11. future timestamp', () {
    test('a provider quote observed in the future is rejected, reason invalidProviderData', () async {
      final ReferenceFxRate future = rateFor(
        observedAt: currentTime.add(const Duration(minutes: 5)),
        fetchedAt: currentTime,
      );
      provider.nextResult = FxRateProviderSuccess(<ReferenceFxRate>[future]);

      final ReferenceRateResult result =
          await service.referenceRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY');

      expect(result, isA<ReferenceRateUnavailable>());
      expect(
        (result as ReferenceRateUnavailable).reason,
        ReferenceRateUnavailableReason.invalidProviderData,
      );
    });

    test('a future-dated quote falls back to a stale cached rate when one exists', () async {
      final ReferenceFxRate stale = rateFor(
        fetchedAt: currentTime.subtract(const Duration(hours: 2)),
      );
      await cache.put(stale);
      final ReferenceFxRate future = rateFor(
        observedAt: currentTime.add(const Duration(minutes: 5)),
        fetchedAt: currentTime,
      );
      provider.nextResult = FxRateProviderSuccess(<ReferenceFxRate>[future]);

      final ReferenceRateResult result =
          await service.referenceRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY');

      expect(result, isA<ReferenceRateStale>());
      expect((result as ReferenceRateStale).rate, stale);
    });

    test('a quote observed at exactly "now" (not after) is accepted, not rejected as future', () async {
      final ReferenceFxRate exactlyNow = rateFor(observedAt: currentTime, fetchedAt: currentTime);
      provider.nextResult = FxRateProviderSuccess(<ReferenceFxRate>[exactlyNow]);

      final ReferenceRateResult result =
          await service.referenceRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY');

      expect(result, isA<ReferenceRateFresh>());
    });
  });

  group('12. invalid provider data', () {
    test('an empty-source quote can never reach the service in the first place', () {
      // ReferenceFxRate's own constructor rejects an empty source at
      // construction time (see reference_fx_rate_test.dart) -- there is
      // no service-level path to exercise here because a provider
      // literally cannot produce an invalid ReferenceFxRate to hand the
      // service. This test documents that boundary rather than
      // duplicating it.
      expect(
        () => rateFor(source: ''),
        throwsA(isA<Object>()),
      );
    });
  });

  group('provider batch request shape', () {
    test('referenceRate asks the provider for exactly the one requested quote currency', () async {
      provider.nextResult = FxRateProviderSuccess(<ReferenceFxRate>[rateFor()]);
      await service.referenceRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY');

      expect(provider.lastRequestedBaseCurrencyCode, 'USD');
      expect(provider.lastRequestedQuoteCurrencyCodes, <String>{'JPY'});
    });
  });
}
