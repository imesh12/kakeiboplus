import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/repositories/drift_reference_fx_rate_cache.dart';
import 'package:ai_financial_coach/core/fx/exchangerate_api_fx_rate_provider.dart';
import 'package:ai_financial_coach/core/fx/fx_rate.dart';
import 'package:ai_financial_coach/core/fx/reference_fx_rate.dart';
import 'package:ai_financial_coach/core/fx/reference_fx_rate_service.dart';
import 'package:ai_financial_coach/core/fx/reference_rate_result.dart';
import 'package:ai_financial_coach/core/network/http_transport.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// Checkpoint 9.4 -- end-to-end integration of the full, now-complete
// stack this checkpoint's own architecture diagram describes:
//
//   FakeHttpTransport (stands in for a real vendor over the network)
//     -> ExchangeRateApiFxRateProvider (FxRateProvider)
//       -> ReferenceFxRateService
//         -> DriftReferenceFxRateCache (persistent, CP9.3)
//
// Every prior CP9.1-CP9.3 test file already exercises the cache and
// service in isolation (with hand-written fakes at each seam); this file
// specifically proves the seams fit together correctly now that a real
// (if network-faked) provider exists, and that ReferenceFxRateService's
// fresh/stale/unavailable/identity policy -- entirely unchanged since
// CP9.2 -- still governs correctly with this provider in place (CP9.4
// Task E: "do not duplicate this policy inside the vendor adapter").
//
// Fully offline: `_FakeHttpTransport` never opens a socket.

class _FakeHttpTransport implements HttpTransport {
  // No explicit constructor: every call site constructs this with no
  // arguments (`_FakeHttpTransport()`) and sets `response`/`error`
  // afterward via plain field assignment -- a constructor accepting them
  // as optional named parameters would be dead code no caller ever uses
  // (this is exactly what `flutter analyze`'s `unused_element_parameter`
  // flagged). Dart's implicit default no-arg constructor is sufficient.

  HttpTransportResponse? response;
  Object? error;
  int callCount = 0;

  @override
  Future<HttpTransportResponse> get(Uri url, {required Duration timeout}) async {
    callCount++;
    final Object? scriptedError = error;
    if (scriptedError != null) {
      // ignore: only_throw_errors
      throw scriptedError;
    }
    return response!;
  }
}

String _body({required String baseCode, required Map<String, String> rateLiterals}) {
  final String ratesField =
      rateLiterals.entries.map((MapEntry<String, String> e) => '"${e.key}": ${e.value}').join(', ');
  return '{"result": "success", "base_code": "$baseCode", "rates": {$ratesField}}';
}

void main() {
  late AppDatabase db;
  late DriftReferenceFxRateCache cache;
  late _FakeHttpTransport transport;
  late DateTime now;
  late ReferenceFxRateService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    cache = DriftReferenceFxRateCache(db);
    transport = _FakeHttpTransport();
    now = DateTime.utc(2026, 6, 1, 12, 0, 0);
    service = ReferenceFxRateService(
      provider: ExchangeRateApiFxRateProvider(transport: transport, nowUtc: () => now),
      cache: cache,
      nowUtc: () => now,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('23. end-to-end success path', () {
    test('a first-ever request with an empty cache fetches from the provider and persists it', () async {
      transport.response = HttpTransportResponse(
        statusCode: 200,
        body: _body(baseCode: 'USD', rateLiterals: <String, String>{'JPY': '149.85'}),
      );

      final ReferenceRateResult result =
          await service.referenceRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY');

      expect(result, isA<ReferenceRateFresh>());
      expect((result as ReferenceRateFresh).rate.rate.rateAsString, '149.85');
      expect(transport.callCount, 1);

      final ReferenceFxRate? persisted =
          await cache.get(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY');
      expect(persisted, isNotNull);
      expect(persisted!.rate.rateAsString, '149.85');
    });
  });

  group('24. fresh cache causes no provider request', () {
    test('a cache entry within the freshness window never touches the provider', () async {
      await cache.put(
        ReferenceFxRate(
          rate: FxRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY', rate: '148.00'),
          source: 'seed',
          observedAt: now,
          fetchedAt: now,
        ),
      );

      final ReferenceRateResult result =
          await service.referenceRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY');

      expect(result, isA<ReferenceRateFresh>());
      expect((result as ReferenceRateFresh).rate.rate.rateAsString, '148');
      expect(transport.callCount, 0);
    });
  });

  group('25. stale cache + provider success updates the persistent cache', () {
    test('a stale entry is refreshed from the provider and the new value is persisted', () async {
      final DateTime staleFetchedAt = now.subtract(const Duration(hours: 2));
      await cache.put(
        ReferenceFxRate(
          rate: FxRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY', rate: '148.00'),
          source: 'seed',
          observedAt: staleFetchedAt,
          fetchedAt: staleFetchedAt,
        ),
      );
      transport.response = HttpTransportResponse(
        statusCode: 200,
        body: _body(baseCode: 'USD', rateLiterals: <String, String>{'JPY': '150.10'}),
      );

      final ReferenceRateResult result =
          await service.referenceRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY');

      expect(result, isA<ReferenceRateFresh>());
      expect((result as ReferenceRateFresh).rate.rate.rateAsString, '150.1');
      expect(transport.callCount, 1);

      final ReferenceFxRate? persisted =
          await cache.get(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY');
      expect(persisted!.rate.rateAsString, '150.1');
    });
  });

  group('26. stale cache + provider failure returns stale', () {
    test('a provider failure falls back to the stale cached rate, and never overwrites it', () async {
      final DateTime staleFetchedAt = now.subtract(const Duration(hours: 2));
      await cache.put(
        ReferenceFxRate(
          rate: FxRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY', rate: '148.00'),
          source: 'seed',
          observedAt: staleFetchedAt,
          fetchedAt: staleFetchedAt,
        ),
      );
      transport.error = const FormatException('vendor is down');

      final ReferenceRateResult result =
          await service.referenceRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY');

      expect(result, isA<ReferenceRateStale>());
      expect((result as ReferenceRateStale).rate.rate.rateAsString, '148');

      final ReferenceFxRate? persisted =
          await cache.get(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY');
      expect(persisted!.rate.rateAsString, '148');
      expect(persisted.fetchedAt.isAtSameMomentAs(staleFetchedAt), isTrue);
    });
  });

  group('27. no cache + provider failure returns unavailable', () {
    test('an empty cache and a failing provider is reported unavailable, never a fabricated rate', () async {
      transport.error = const FormatException('vendor is down');

      final ReferenceRateResult result =
          await service.referenceRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY');

      expect(result, isA<ReferenceRateUnavailable>());
      expect(
        (result as ReferenceRateUnavailable).reason,
        ReferenceRateUnavailableReason.providerFailed,
      );
    });
  });

  group('28. same-currency identity causes no network request', () {
    test('EUR -> EUR never touches the cache or the provider', () async {
      final ReferenceRateResult result =
          await service.referenceRate(baseCurrencyCode: 'EUR', quoteCurrencyCode: 'EUR');

      expect(result, isA<ReferenceRateIdentity>());
      expect((result as ReferenceRateIdentity).currencyCode, 'EUR');
      expect(transport.callCount, 0);
    });
  });
}
