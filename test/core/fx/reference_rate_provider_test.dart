import 'package:ai_financial_coach/core/fx/fx_rate.dart';
import 'package:ai_financial_coach/core/fx/fx_rate_provider.dart';
import 'package:ai_financial_coach/core/fx/in_memory_reference_fx_rate_cache.dart';
import 'package:ai_financial_coach/core/fx/reference_fx_rate.dart';
import 'package:ai_financial_coach/core/fx/reference_fx_rate_cache.dart';
import 'package:ai_financial_coach/core/fx/reference_fx_rate_providers.dart';
import 'package:ai_financial_coach/core/fx/reference_fx_rate_service.dart';
import 'package:ai_financial_coach/core/fx/reference_rate_result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hand-written fake -- same pattern `reference_fx_rate_service_test.dart`
/// already uses (this project uses no mocking library).
class _FakeFxRateProvider implements FxRateProvider {
  FxRateProviderResult? nextResult;
  int callCount = 0;
  String? lastRequestedBaseCurrencyCode;
  Set<String>? lastRequestedQuoteCurrencyCodes;

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

// NOTE: fetchedAt/observedAt are computed relative to the real wall clock
// (DateTime.now().toUtc()), not a hardcoded calendar date. The production
// referenceFxRateServiceProvider wires ReferenceFxRateService without an
// injected NowUtc override (see reference_fx_rate_providers.dart), so the
// service's own freshness check always runs against the real wall clock in
// these tests too. A fixed past date (e.g. DateTime.utc(2026, 6, 1)) would
// eventually -- and did -- fall outside the 1-hour freshness window purely
// because real time moved on, causing a cached entry to be judged stale and
// the fake provider to be called a second time even though nothing about
// caching/freshness behavior was actually broken. Computing "now" at call
// time keeps every seeded rate fresh relative to whatever moment the test
// actually runs, matching the pattern the adjacent stale-entry test below
// already uses correctly (DateTime.now().toUtc().subtract(...)).
ReferenceFxRate _referenceRate(String base, String quote, String value) => ReferenceFxRate(
      rate: FxRate(baseCurrencyCode: base, quoteCurrencyCode: quote, rate: value),
      source: 'fake',
      observedAt: DateTime.now().toUtc(),
      fetchedAt: DateTime.now().toUtc(),
    );

void main() {
  late _FakeFxRateProvider fakeProvider;
  late ReferenceFxRateCache cache;
  late ProviderContainer container;

  setUp(() {
    fakeProvider = _FakeFxRateProvider();
    cache = InMemoryReferenceFxRateCache();
    container = ProviderContainer(
      overrides: <Override>[
        fxRateProviderProvider.overrideWithValue(fakeProvider),
        referenceFxRateCacheProvider.overrideWithValue(cache),
      ],
    );
    addTearDown(container.dispose);
  });

  group('1. referenceFxRateServiceProvider', () {
    test('resolves to a real ReferenceFxRateService without touching the provider (lazy, no I/O)', () {
      final ReferenceFxRateService service = container.read(referenceFxRateServiceProvider);

      expect(service, isA<ReferenceFxRateService>());
      expect(fakeProvider.callCount, 0);
    });
  });

  group('2. referenceRateProvider resolves the requested pair', () {
    test('a fresh fetch calls the provider with exactly the requested base and quote', () async {
      fakeProvider.nextResult =
          FxRateProviderSuccess(<ReferenceFxRate>[_referenceRate('USD', 'JPY', '149.85')]);

      final ReferenceRateResult result =
          await container.read(referenceRateProvider(('USD', 'JPY')).future);

      expect(result, isA<ReferenceRateFresh>());
      expect(fakeProvider.lastRequestedBaseCurrencyCode, 'USD');
      expect(fakeProvider.lastRequestedQuoteCurrencyCodes, <String>{'JPY'});
    });
  });

  group('3. direction is never inverted', () {
    test('a cached USD->JPY entry does not satisfy a request for JPY->USD', () async {
      await cache.put(_referenceRate('USD', 'JPY', '149.85'));
      fakeProvider.nextResult = const FxRateProviderFailure('no JPY->USD quote seeded');

      final ReferenceRateResult result =
          await container.read(referenceRateProvider(('JPY', 'USD')).future);

      // No cache hit for the inverse pair -- the service must fall
      // through to the provider (which this test deliberately fails),
      // never silently invert the cached USD->JPY entry into a JPY->USD
      // answer.
      expect(result, isA<ReferenceRateUnavailable>());
      expect(fakeProvider.lastRequestedBaseCurrencyCode, 'JPY');
      expect(fakeProvider.lastRequestedQuoteCurrencyCodes, <String>{'USD'});
    });

    test('(base, quote) and (quote, base) are distinct family keys with independent results', () async {
      // CAD and USD are both CurrencyRegistry-supported (GBP is not a
      // member of the registry's approved 13-currency set and must not be
      // added just to satisfy a test); this pair is otherwise unrelated to
      // this file's own USD/JPY pair used elsewhere, so it stays clearly
      // distinct while still proving the same (A,B) vs (B,A) behavior.
      fakeProvider.nextResult =
          FxRateProviderSuccess(<ReferenceFxRate>[_referenceRate('CAD', 'USD', '0.73')]);
      final ReferenceRateResult forward =
          await container.read(referenceRateProvider(('CAD', 'USD')).future);

      fakeProvider.nextResult = const FxRateProviderFailure('no USD->CAD quote seeded');
      final ReferenceRateResult backward =
          await container.read(referenceRateProvider(('USD', 'CAD')).future);

      expect(forward, isA<ReferenceRateFresh>());
      expect(backward, isA<ReferenceRateUnavailable>());
    });
  });

  group('4. same pair shares one in-flight result while both requests are live', () {
    test('reading the same pair twice in quick succession only calls the provider once', () async {
      fakeProvider.nextResult =
          FxRateProviderSuccess(<ReferenceFxRate>[_referenceRate('USD', 'JPY', '149.85')]);

      final List<ReferenceRateResult> results = await Future.wait(<Future<ReferenceRateResult>>[
        container.read(referenceRateProvider(('USD', 'JPY')).future),
        container.read(referenceRateProvider(('USD', 'JPY')).future),
      ]);

      expect(results[0], isA<ReferenceRateFresh>());
      expect(results[1], isA<ReferenceRateFresh>());
      expect(fakeProvider.callCount, 1);
    });
  });

  group('5. same-currency identity never calls the provider at all', () {
    test('requesting (EUR, EUR) resolves to identity with zero provider calls', () async {
      final ReferenceRateResult result =
          await container.read(referenceRateProvider(('EUR', 'EUR')).future);

      expect(result, isA<ReferenceRateIdentity>());
      expect(fakeProvider.callCount, 0);
    });
  });

  group('6. manual refresh via ref.invalidate re-runs the provider fn, not the freshness cache', () {
    test('invalidating right after a fresh fetch re-runs but still serves the still-fresh cache entry', () async {
      fakeProvider.nextResult =
          FxRateProviderSuccess(<ReferenceFxRate>[_referenceRate('USD', 'JPY', '149.85')]);
      await container.read(referenceRateProvider(('USD', 'JPY')).future);
      expect(fakeProvider.callCount, 1);

      // Task G's "simple V1 refresh" is a Riverpod-level invalidation of
      // this provider, not a bypass of ReferenceFxRateService's own
      // freshness contract -- the entry just cached is still within the
      // freshness window, so re-running the provider function must
      // resolve straight from cache without touching the network-facing
      // provider again.
      container.invalidate(referenceRateProvider(('USD', 'JPY')));
      final ReferenceRateResult second =
          await container.read(referenceRateProvider(('USD', 'JPY')).future);

      expect(fakeProvider.callCount, 1);
      expect(second, isA<ReferenceRateFresh>());
      expect((second as ReferenceRateFresh).rate.rate.rateAsString, '149.85');
    });

    test('invalidating a stale entry does call through to the provider again', () async {
      final DateTime staleFetchedAt = DateTime.now().toUtc().subtract(const Duration(hours: 2));
      await cache.put(
        ReferenceFxRate(
          rate: FxRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY', rate: '148.00'),
          source: 'seed',
          observedAt: staleFetchedAt,
          fetchedAt: staleFetchedAt,
        ),
      );
      fakeProvider.nextResult =
          FxRateProviderSuccess(<ReferenceFxRate>[_referenceRate('USD', 'JPY', '150.10')]);

      final ReferenceRateResult result =
          await container.read(referenceRateProvider(('USD', 'JPY')).future);

      expect(fakeProvider.callCount, 1);
      expect(result, isA<ReferenceRateFresh>());
      expect((result as ReferenceRateFresh).rate.rate.rateAsString, '150.1');
    });
  });
}
