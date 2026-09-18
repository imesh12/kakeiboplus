import 'dart:async';
import 'dart:io';

import 'package:ai_financial_coach/core/fx/exchangerate_api_fx_rate_provider.dart';
import 'package:ai_financial_coach/core/fx/fx_rate_provider.dart';
import 'package:ai_financial_coach/core/fx/reference_fx_rate.dart';
import 'package:ai_financial_coach/core/network/http_transport.dart';
import 'package:flutter_test/flutter_test.dart';

// Checkpoint 9.4 -- Real Reference FX Provider & Network Retrieval.
//
// Every test here is deterministic and fully offline (CP9.4 Task I: "no
// live internet tests") -- `_FakeHttpTransport` never opens a real
// socket; it hands back a pre-built response or throws a pre-configured
// synthetic error, exactly like `_FakeFxRateProvider` in
// `reference_fx_rate_service_test.dart` fakes the layer above this one
// (this project uses no mocking library -- see pubspec.yaml's own note).
//
// Response bodies are built as raw JSON *text* via `_body(...)` below,
// never via `jsonEncode` of a `Map<String, double>` -- doing the latter
// would round-trip every rate literal through a Dart `double` in the
// test's own setup, silently defeating the exact-decimal tests before
// the code under test ever ran. `_body` lets every test embed the exact
// literal characters a real vendor response would contain "on the wire".

/// Records every requested [Uri] and either returns a scripted
/// [HttpTransportResponse] or throws a scripted error -- never performs
/// real I/O.
class _FakeHttpTransport implements HttpTransport {
  _FakeHttpTransport({this.response, this.error});

  HttpTransportResponse? response;
  Object? error;
  int callCount = 0;
  Uri? lastRequestedUrl;
  Duration? lastRequestedTimeout;

  @override
  Future<HttpTransportResponse> get(Uri url, {required Duration timeout}) async {
    callCount++;
    lastRequestedUrl = url;
    lastRequestedTimeout = timeout;
    final Object? scriptedError = error;
    if (scriptedError != null) {
      // ignore: only_throw_errors
      throw scriptedError;
    }
    return response!;
  }
}

/// Builds a raw ExchangeRate-API-shaped JSON response body, embedding
/// each rate's EXACT literal text (never a Dart `double`). Pass
/// [omitRates] to produce a response missing the `"rates"` key
/// entirely (CP9.4 test 12, "wrong response shape").
String _body({
  String result = 'success',
  required String baseCode,
  Map<String, String> rateLiterals = const <String, String>{},
  int? timeLastUpdateUnix,
  bool omitRates = false,
}) {
  final String ratesField = omitRates
      ? ''
      : ', "rates": {${rateLiterals.entries.map((MapEntry<String, String> e) => '"${e.key}": ${e.value}').join(', ')}}';
  final String timeField =
      timeLastUpdateUnix != null ? ', "time_last_update_unix": $timeLastUpdateUnix' : '';
  return '{"result": "$result", "provider": "https://www.exchangerate-api.com", '
      '"base_code": "$baseCode"$timeField$ratesField}';
}

void main() {
  final DateTime fixedNow = DateTime.utc(2026, 6, 1, 12, 0, 0);
  ExchangeRateApiFxRateProvider providerWith(
    _FakeHttpTransport transport, {
    DateTime Function()? nowUtc,
  }) {
    return ExchangeRateApiFxRateProvider(
      transport: transport,
      nowUtc: nowUtc ?? (() => fixedNow),
    );
  }

  group('1. valid single rate', () {
    test('USD -> JPY returns exactly one ReferenceFxRate for the requested pair', () async {
      final _FakeHttpTransport transport = _FakeHttpTransport(
        response: HttpTransportResponse(
          statusCode: 200,
          body: _body(baseCode: 'USD', rateLiterals: <String, String>{'JPY': '149.85'}),
        ),
      );
      final FxRateProviderResult result = await providerWith(transport).fetchRates(
        baseCurrencyCode: 'USD',
        quoteCurrencyCodes: <String>{'JPY'},
      );

      expect(result, isA<FxRateProviderSuccess>());
      final List<ReferenceFxRate> rates = (result as FxRateProviderSuccess).rates;
      expect(rates.length, 1);
      expect(rates.single.baseCurrencyCode, 'USD');
      expect(rates.single.quoteCurrencyCode, 'JPY');
      expect(rates.single.rate.rateAsString, '149.85');
      expect(rates.single.source, ExchangeRateApiFxRateProvider.sourceId);
    });
  });

  group('2. valid multiple quotes', () {
    test('a multi-quote request returns exactly the requested pairs, nothing extra', () async {
      final _FakeHttpTransport transport = _FakeHttpTransport(
        response: HttpTransportResponse(
          statusCode: 200,
          body: _body(
            baseCode: 'USD',
            rateLiterals: <String, String>{
              'JPY': '149.85',
              'EUR': '0.92',
              'KWD': '0.307',
              // Deliberately present in the vendor payload but NOT
              // requested below -- must never leak into the result.
              'CAD': '1.36',
            },
          ),
        ),
      );
      final FxRateProviderResult result = await providerWith(transport).fetchRates(
        baseCurrencyCode: 'USD',
        quoteCurrencyCodes: <String>{'JPY', 'EUR', 'KWD'},
      );

      final List<ReferenceFxRate> rates = (result as FxRateProviderSuccess).rates;
      expect(rates.length, 3);
      expect(rates.map((ReferenceFxRate r) => r.quoteCurrencyCode).toSet(), <String>{'JPY', 'EUR', 'KWD'});
      expect(rates.every((ReferenceFxRate r) => r.baseCurrencyCode == 'USD'), isTrue);
    });
  });

  group('3. exact decimal preservation', () {
    for (final String rateValue in <String>[
      '150',
      '0.006666666667',
      '1.234567890123',
      '0.000000000001',
    ]) {
      test('"$rateValue" survives ingestion with no floating-point drift', () async {
        final _FakeHttpTransport transport = _FakeHttpTransport(
          response: HttpTransportResponse(
            statusCode: 200,
            body: _body(baseCode: 'USD', rateLiterals: <String, String>{'JPY': rateValue}),
          ),
        );
        final FxRateProviderResult result = await providerWith(transport).fetchRates(
          baseCurrencyCode: 'USD',
          quoteCurrencyCodes: <String>{'JPY'},
        );
        final List<ReferenceFxRate> rates = (result as FxRateProviderSuccess).rates;
        expect(rates.single.rate.rateAsString, rateValue);
      });
    }
  });

  group('4. 0-decimal currency pair', () {
    test('USD -> JPY (JPY has 0 minor units) round-trips the rate exactly', () async {
      final _FakeHttpTransport transport = _FakeHttpTransport(
        response: HttpTransportResponse(
          statusCode: 200,
          body: _body(baseCode: 'USD', rateLiterals: <String, String>{'JPY': '153.482071'}),
        ),
      );
      final FxRateProviderResult result = await providerWith(transport).fetchRates(
        baseCurrencyCode: 'USD',
        quoteCurrencyCodes: <String>{'JPY'},
      );
      expect((result as FxRateProviderSuccess).rates.single.rate.rateAsString, '153.482071');
    });
  });

  group('5. 3-decimal currency', () {
    test('USD -> KWD (KWD has 3 minor units) round-trips the rate exactly', () async {
      final _FakeHttpTransport transport = _FakeHttpTransport(
        response: HttpTransportResponse(
          statusCode: 200,
          body: _body(baseCode: 'USD', rateLiterals: <String, String>{'KWD': '0.307'}),
        ),
      );
      final FxRateProviderResult result = await providerWith(transport).fetchRates(
        baseCurrencyCode: 'USD',
        quoteCurrencyCodes: <String>{'KWD'},
      );
      expect((result as FxRateProviderSuccess).rates.single.rate.rateAsString, '0.307');
    });
  });

  group('6. MMK pair', () {
    test('USD -> MMK round-trips the rate exactly, without touching MMK\'s registry precision', () async {
      final _FakeHttpTransport transport = _FakeHttpTransport(
        response: HttpTransportResponse(
          statusCode: 200,
          body: _body(baseCode: 'USD', rateLiterals: <String, String>{'MMK': '2100.50'}),
        ),
      );
      final FxRateProviderResult result = await providerWith(transport).fetchRates(
        baseCurrencyCode: 'USD',
        quoteCurrencyCodes: <String>{'MMK'},
      );
      final ReferenceFxRate rate = (result as FxRateProviderSuccess).rates.single;
      expect(rate.rate.rateAsString, '2100.5');
      expect(rate.quoteCurrencyCode, 'MMK');
      // This adapter never reads/writes CurrencyRegistry.minorUnits at
      // all -- CP9.4 explicitly forbids changing MMK's 2-minor-unit
      // registry entry, and this test only proves the FX rate path is
      // entirely independent of it (Money/minor-unit rounding is a
      // completely separate concern -- see FxConverter).
    });
  });

  group('7. reverse direction is not synthesized', () {
    test('requesting USD -> JPY never produces a JPY -> USD entry', () async {
      final _FakeHttpTransport transport = _FakeHttpTransport(
        response: HttpTransportResponse(
          statusCode: 200,
          body: _body(baseCode: 'USD', rateLiterals: <String, String>{'JPY': '149.85'}),
        ),
      );
      final FxRateProviderResult result = await providerWith(transport).fetchRates(
        baseCurrencyCode: 'USD',
        quoteCurrencyCodes: <String>{'JPY'},
      );
      final List<ReferenceFxRate> rates = (result as FxRateProviderSuccess).rates;
      expect(rates.any((ReferenceFxRate r) => r.baseCurrencyCode == 'JPY'), isFalse);
    });
  });

  group('8. non-2xx response', () {
    test('HTTP 500 becomes a deterministic failure, not a crash', () async {
      final _FakeHttpTransport transport = _FakeHttpTransport(
        response: const HttpTransportResponse(statusCode: 500, body: 'Internal Server Error'),
      );
      final FxRateProviderResult result = await providerWith(transport).fetchRates(
        baseCurrencyCode: 'USD',
        quoteCurrencyCodes: <String>{'JPY'},
      );
      expect(result, isA<FxRateProviderFailure>());
    });
  });

  group('9. timeout', () {
    test('a TimeoutException from the transport becomes a deterministic failure', () async {
      final _FakeHttpTransport transport = _FakeHttpTransport(
        error: TimeoutException('timed out'),
      );
      final FxRateProviderResult result = await providerWith(transport).fetchRates(
        baseCurrencyCode: 'USD',
        quoteCurrencyCodes: <String>{'JPY'},
      );
      expect(result, isA<FxRateProviderFailure>());
    });
  });

  group('10. transport/network exception', () {
    test('a SocketException (no internet/DNS failure) becomes a deterministic failure', () async {
      final _FakeHttpTransport transport = _FakeHttpTransport(
        error: const SocketException('Failed host lookup'),
      );
      final FxRateProviderResult result = await providerWith(transport).fetchRates(
        baseCurrencyCode: 'USD',
        quoteCurrencyCodes: <String>{'JPY'},
      );
      expect(result, isA<FxRateProviderFailure>());
    });
  });

  group('11. malformed JSON', () {
    test('a non-JSON body becomes a deterministic failure', () async {
      final _FakeHttpTransport transport = _FakeHttpTransport(
        response: const HttpTransportResponse(statusCode: 200, body: 'not json at all {{{'),
      );
      final FxRateProviderResult result = await providerWith(transport).fetchRates(
        baseCurrencyCode: 'USD',
        quoteCurrencyCodes: <String>{'JPY'},
      );
      expect(result, isA<FxRateProviderFailure>());
    });
  });

  group('12. wrong response shape', () {
    test('valid JSON that is an array, not an object, becomes a deterministic failure', () async {
      final _FakeHttpTransport transport = _FakeHttpTransport(
        response: const HttpTransportResponse(statusCode: 200, body: '[1, 2, 3]'),
      );
      final FxRateProviderResult result = await providerWith(transport).fetchRates(
        baseCurrencyCode: 'USD',
        quoteCurrencyCodes: <String>{'JPY'},
      );
      expect(result, isA<FxRateProviderFailure>());
    });

    test('a JSON object missing "rates" entirely becomes a deterministic failure', () async {
      final _FakeHttpTransport transport = _FakeHttpTransport(
        response: HttpTransportResponse(
          statusCode: 200,
          body: _body(baseCode: 'USD', omitRates: true),
        ),
      );
      final FxRateProviderResult result = await providerWith(transport).fetchRates(
        baseCurrencyCode: 'USD',
        quoteCurrencyCodes: <String>{'JPY'},
      );
      expect(result, isA<FxRateProviderFailure>());
    });
  });

  group('13. wrong base currency', () {
    test('a response reporting a different base_code than requested becomes a failure', () async {
      final _FakeHttpTransport transport = _FakeHttpTransport(
        response: HttpTransportResponse(
          statusCode: 200,
          // Requested USD, vendor claims EUR -- must never be silently
          // accepted/relabeled.
          body: _body(baseCode: 'EUR', rateLiterals: <String, String>{'JPY': '162.80'}),
        ),
      );
      final FxRateProviderResult result = await providerWith(transport).fetchRates(
        baseCurrencyCode: 'USD',
        quoteCurrencyCodes: <String>{'JPY'},
      );
      expect(result, isA<FxRateProviderFailure>());
    });
  });

  group('14. missing requested quote', () {
    test('a response that never mentions the requested quote returns an empty success', () async {
      final _FakeHttpTransport transport = _FakeHttpTransport(
        response: HttpTransportResponse(
          statusCode: 200,
          body: _body(baseCode: 'USD', rateLiterals: <String, String>{'EUR': '0.92'}),
        ),
      );
      final FxRateProviderResult result = await providerWith(transport).fetchRates(
        baseCurrencyCode: 'USD',
        quoteCurrencyCodes: <String>{'JPY'},
      );
      expect(result, isA<FxRateProviderSuccess>());
      expect((result as FxRateProviderSuccess).rates, isEmpty);
    });
  });

  group('15. zero rate', () {
    test('a "0" rate for the requested quote is excluded, not accepted as zero', () async {
      final _FakeHttpTransport transport = _FakeHttpTransport(
        response: HttpTransportResponse(
          statusCode: 200,
          body: _body(baseCode: 'USD', rateLiterals: <String, String>{'JPY': '0'}),
        ),
      );
      final FxRateProviderResult result = await providerWith(transport).fetchRates(
        baseCurrencyCode: 'USD',
        quoteCurrencyCodes: <String>{'JPY'},
      );
      expect((result as FxRateProviderSuccess).rates, isEmpty);
    });
  });

  group('16. negative rate', () {
    test('a negative rate for the requested quote is excluded, never used', () async {
      final _FakeHttpTransport transport = _FakeHttpTransport(
        response: HttpTransportResponse(
          statusCode: 200,
          body: _body(baseCode: 'USD', rateLiterals: <String, String>{'JPY': '-149.85'}),
        ),
      );
      final FxRateProviderResult result = await providerWith(transport).fetchRates(
        baseCurrencyCode: 'USD',
        quoteCurrencyCodes: <String>{'JPY'},
      );
      expect((result as FxRateProviderSuccess).rates, isEmpty);
    });
  });

  group('17. exponent notation', () {
    test('an exponent-notation rate is excluded, never interpreted', () async {
      final _FakeHttpTransport transport = _FakeHttpTransport(
        response: HttpTransportResponse(
          statusCode: 200,
          body: _body(baseCode: 'USD', rateLiterals: <String, String>{'JPY': '1.4985e2'}),
        ),
      );
      final FxRateProviderResult result = await providerWith(transport).fetchRates(
        baseCurrencyCode: 'USD',
        quoteCurrencyCodes: <String>{'JPY'},
      );
      expect((result as FxRateProviderSuccess).rates, isEmpty);
    });
  });

  group('18. excessive precision', () {
    test('more than 12 fractional digits is excluded, not silently truncated', () async {
      final _FakeHttpTransport transport = _FakeHttpTransport(
        response: HttpTransportResponse(
          statusCode: 200,
          body: _body(
            baseCode: 'USD',
            rateLiterals: <String, String>{'JPY': '1.${'1' * 13}'},
          ),
        ),
      );
      final FxRateProviderResult result = await providerWith(transport).fetchRates(
        baseCurrencyCode: 'USD',
        quoteCurrencyCodes: <String>{'JPY'},
      );
      expect((result as FxRateProviderSuccess).rates, isEmpty);
    });
  });

  group('19. malformed rate token', () {
    test('a quoted-string rate value (not a bare number) is excluded', () async {
      final _FakeHttpTransport transport = _FakeHttpTransport(
        response: const HttpTransportResponse(
          statusCode: 200,
          body: '{"result": "success", "base_code": "USD", '
              '"rates": {"JPY": "not-a-number"}}',
        ),
      );
      final FxRateProviderResult result = await providerWith(transport).fetchRates(
        baseCurrencyCode: 'USD',
        quoteCurrencyCodes: <String>{'JPY'},
      );
      expect((result as FxRateProviderSuccess).rates, isEmpty);
    });

    test('a null rate value is excluded', () async {
      final _FakeHttpTransport transport = _FakeHttpTransport(
        response: const HttpTransportResponse(
          statusCode: 200,
          body: '{"result": "success", "base_code": "USD", "rates": {"JPY": null}}',
        ),
      );
      final FxRateProviderResult result = await providerWith(transport).fetchRates(
        baseCurrencyCode: 'USD',
        quoteCurrencyCodes: <String>{'JPY'},
      );
      expect((result as FxRateProviderSuccess).rates, isEmpty);
    });

    test('a bare (unquoted) NaN token makes the whole response malformed JSON, not a crash', () async {
      // Real JSON forbids bare `NaN`/`Infinity` literals -- a vendor that
      // ever emitted one would produce a document `jsonDecode` itself
      // rejects, which is the correct outcome here: the whole response
      // is untrustworthy, not just this one quote (see CP9.4 Task D:
      // "NaN/Infinity rejected").
      final _FakeHttpTransport transport = _FakeHttpTransport(
        response: const HttpTransportResponse(
          statusCode: 200,
          body: '{"result": "success", "base_code": "USD", "rates": {"JPY": NaN}}',
        ),
      );
      final FxRateProviderResult result = await providerWith(transport).fetchRates(
        baseCurrencyCode: 'USD',
        quoteCurrencyCodes: <String>{'JPY'},
      );
      expect(result, isA<FxRateProviderFailure>());
    });
  });

  group('20. provider timestamp behavior', () {
    test('a valid time_last_update_unix becomes observedAt exactly', () async {
      final DateTime providerTimestamp = DateTime.utc(2026, 5, 31, 0, 0, 0);
      final int epochSeconds = providerTimestamp.millisecondsSinceEpoch ~/ 1000;
      final _FakeHttpTransport transport = _FakeHttpTransport(
        response: HttpTransportResponse(
          statusCode: 200,
          body: _body(
            baseCode: 'USD',
            rateLiterals: <String, String>{'JPY': '149.85'},
            timeLastUpdateUnix: epochSeconds,
          ),
        ),
      );
      final FxRateProviderResult result = await providerWith(transport).fetchRates(
        baseCurrencyCode: 'USD',
        quoteCurrencyCodes: <String>{'JPY'},
      );
      final ReferenceFxRate rate = (result as FxRateProviderSuccess).rates.single;
      expect(rate.observedAt.isAtSameMomentAs(providerTimestamp), isTrue);
      expect(rate.observedAt.isUtc, isTrue);
    });

    test('a missing time_last_update_unix falls back to fetchedAt (documented policy)', () async {
      final _FakeHttpTransport transport = _FakeHttpTransport(
        response: HttpTransportResponse(
          statusCode: 200,
          body: _body(baseCode: 'USD', rateLiterals: <String, String>{'JPY': '149.85'}),
        ),
      );
      final FxRateProviderResult result = await providerWith(transport).fetchRates(
        baseCurrencyCode: 'USD',
        quoteCurrencyCodes: <String>{'JPY'},
      );
      final ReferenceFxRate rate = (result as FxRateProviderSuccess).rates.single;
      expect(rate.observedAt.isAtSameMomentAs(fixedNow), isTrue);
      expect(rate.observedAt.isAtSameMomentAs(rate.fetchedAt), isTrue);
    });
  });

  group('21. fetchedAt UTC behavior', () {
    test('fetchedAt is exactly the injected clock\'s instant, UTC', () async {
      final _FakeHttpTransport transport = _FakeHttpTransport(
        response: HttpTransportResponse(
          statusCode: 200,
          body: _body(baseCode: 'USD', rateLiterals: <String, String>{'JPY': '149.85'}),
        ),
      );
      final FxRateProviderResult result = await providerWith(transport).fetchRates(
        baseCurrencyCode: 'USD',
        quoteCurrencyCodes: <String>{'JPY'},
      );
      final ReferenceFxRate rate = (result as FxRateProviderSuccess).rates.single;
      expect(rate.fetchedAt.isAtSameMomentAs(fixedNow), isTrue);
      expect(rate.fetchedAt.isUtc, isTrue);
    });
  });

  group('22. no raw ordinary network exception escapes', () {
    for (final Object syntheticError in <Object>[
      const SocketException('Failed host lookup'),
      TimeoutException('timed out'),
      const HttpException('bad response'),
      const FormatException('bad'),
      StateError('unexpected'),
    ]) {
      test('${syntheticError.runtimeType} from the transport never propagates', () async {
        final _FakeHttpTransport transport = _FakeHttpTransport(error: syntheticError);
        final FxRateProviderResult result = await providerWith(transport).fetchRates(
          baseCurrencyCode: 'USD',
          quoteCurrencyCodes: <String>{'JPY'},
        );
        expect(result, isA<FxRateProviderFailure>());
      });
    }
  });

  group('request behavior', () {
    test('the requested URL is built from the canonical base currency, and the configured timeout is passed through', () async {
      final _FakeHttpTransport transport = _FakeHttpTransport(
        response: HttpTransportResponse(
          statusCode: 200,
          body: _body(baseCode: 'USD', rateLiterals: <String, String>{'JPY': '149.85'}),
        ),
      );
      final ExchangeRateApiFxRateProvider provider = ExchangeRateApiFxRateProvider(
        transport: transport,
        nowUtc: () => fixedNow,
        timeout: const Duration(seconds: 3),
      );
      await provider.fetchRates(
        // lower-case on purpose -- must be canonicalized before building the URL.
        baseCurrencyCode: 'usd',
        quoteCurrencyCodes: <String>{'jpy'},
      );
      expect(transport.callCount, 1);
      expect(transport.lastRequestedUrl, Uri.parse('https://open.er-api.com/v6/latest/USD'));
      expect(transport.lastRequestedTimeout, const Duration(seconds: 3));
    });
  });
}
