import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/repositories/drift_reference_fx_rate_cache.dart';
import 'package:ai_financial_coach/core/fx/fx_rate.dart';
import 'package:ai_financial_coach/core/fx/fx_rate_provider.dart';
import 'package:ai_financial_coach/core/fx/reference_fx_rate.dart';
import 'package:ai_financial_coach/core/fx/reference_fx_rate_service.dart';
import 'package:ai_financial_coach/core/fx/reference_rate_result.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// NOTE: exercises generated Drift code (AppDatabase, the
// `reference_exchange_rates` table's generated
// `ReferenceExchangeRatesCompanion`/`ReferenceExchangeRate` row class) --
// run `dart run build_runner build --delete-conflicting-outputs` locally
// before running this test. See CLAUDE_FIRST_CODING_PROMPT.md.
//
// `ReferenceExchangeRates` has no foreign key to `profiles`/`accounts`/
// `currencies` (same convention as its sibling `TransactionExchangeRates`
// -- see that table's own doc), so unlike most repository tests in this
// directory, no profile/account fixture setup is needed at all.

/// Hand-written fake -- see `test/core/fx/reference_fx_rate_service_test
/// .dart` for the identical convention (this project uses no mocking
/// library).
class _FakeFxRateProvider implements FxRateProvider {
  FxRateProviderResult? nextResult;

  @override
  Future<FxRateProviderResult> fetchRates({
    required String baseCurrencyCode,
    required Set<String> quoteCurrencyCodes,
  }) async {
    final FxRateProviderResult? result = nextResult;
    if (result == null) {
      throw StateError('_FakeFxRateProvider.nextResult was not set before fetchRates was called.');
    }
    return result;
  }
}

void main() {
  late AppDatabase db;
  late DriftReferenceFxRateCache cache;

  ReferenceFxRate rateFor({
    required String base,
    required String quote,
    required String rateValue,
    String source = 'fake-provider',
    DateTime? observedAt,
    DateTime? fetchedAt,
  }) {
    final DateTime instant = DateTime.utc(2026, 6, 1, 12, 0, 0);
    return ReferenceFxRate(
      rate: FxRate(baseCurrencyCode: base, quoteCurrencyCode: quote, rate: rateValue),
      source: source,
      observedAt: observedAt ?? instant,
      fetchedAt: fetchedAt ?? instant,
    );
  }

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    cache = DriftReferenceFxRateCache(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('1. empty cache', () {
    test('USD -> JPY returns null when nothing has been cached', () async {
      expect(await cache.get(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY'), isNull);
    });
  });

  group('2. put + get', () {
    test('persisting USD -> JPY and reading it back preserves rate/source/timestamps', () async {
      final DateTime observed = DateTime.utc(2026, 6, 1, 11, 59, 0);
      final DateTime fetched = DateTime.utc(2026, 6, 1, 12, 0, 0);
      final ReferenceFxRate original = rateFor(
        base: 'USD',
        quote: 'JPY',
        rateValue: '150.25',
        source: 'fixer',
        observedAt: observed,
        fetchedAt: fetched,
      );

      await cache.put(original);
      final ReferenceFxRate? read =
          await cache.get(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY');

      expect(read, isNotNull);
      expect(read!.baseCurrencyCode, 'USD');
      expect(read.quoteCurrencyCode, 'JPY');
      expect(read.rate.rateAsString, '150.25');
      expect(read.source, 'fixer');
      expect(read.observedAt.isAtSameMomentAs(observed), isTrue);
      expect(read.fetchedAt.isAtSameMomentAs(fetched), isTrue);
    });
  });

  group('3. upsert same pair', () {
    test('putting B after A for the same pair leaves exactly one row, and get returns B', () async {
      final ReferenceFxRate a = rateFor(base: 'USD', quote: 'JPY', rateValue: '150.25');
      final ReferenceFxRate b = rateFor(base: 'USD', quote: 'JPY', rateValue: '151.00');

      await cache.put(a);
      await cache.put(b);

      final List<ReferenceExchangeRate> rows = await db.select(db.referenceExchangeRates).get();
      expect(rows.length, 1);
      // FxRate.rateAsString is `rate.toString()` on the underlying
      // `Decimal` -- per FxRate's own doc comment, this is a *numeric*
      // round-trip guarantee (`Decimal.parse(x.toString()) == x`), not a
      // lexical/cosmetic one. `Decimal.toString()` renders a whole-valued
      // decimal in its canonical minimal form, so the input literal
      // '151.00' is canonicalized to '151' the moment it passes through
      // `FxRate`'s constructor -- before `DriftReferenceFxRateCache` ever
      // sees it. This is proven by CP9.1's own `fx_rate_test.dart` (no
      // assertion anywhere requires trailing-zero preservation) and is
      // unrelated to Drift storage or this cache's behavior.
      expect(rows.single.rate, '151');

      final ReferenceFxRate? read =
          await cache.get(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY');
      expect(read!.rate.rateAsString, '151');
    });
  });

  group('4. direction independence', () {
    test('USD -> JPY and JPY -> USD persist and read back as separate rows', () async {
      final ReferenceFxRate usdToJpy = rateFor(base: 'USD', quote: 'JPY', rateValue: '150.25');
      final ReferenceFxRate jpyToUsd = rateFor(base: 'JPY', quote: 'USD', rateValue: '0.00665557');

      await cache.put(usdToJpy);
      await cache.put(jpyToUsd);

      final List<ReferenceExchangeRate> rows = await db.select(db.referenceExchangeRates).get();
      expect(rows.length, 2);

      final ReferenceFxRate? readForward =
          await cache.get(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY');
      final ReferenceFxRate? readReverse =
          await cache.get(baseCurrencyCode: 'JPY', quoteCurrencyCode: 'USD');
      expect(readForward!.rate.rateAsString, '150.25');
      expect(readReverse!.rate.rateAsString, '0.00665557');
    });
  });

  group('5. remove', () {
    test('removing USD -> JPY leaves JPY -> USD intact', () async {
      await cache.put(rateFor(base: 'USD', quote: 'JPY', rateValue: '150.25'));
      await cache.put(rateFor(base: 'JPY', quote: 'USD', rateValue: '0.00665557'));

      await cache.removeIfPresent(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY');

      expect(await cache.get(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY'), isNull);
      final ReferenceFxRate? reverse =
          await cache.get(baseCurrencyCode: 'JPY', quoteCurrencyCode: 'USD');
      expect(reverse, isNotNull);
      expect(reverse!.rate.rateAsString, '0.00665557');
    });
  });

  group('6. remove absent', () {
    test('removing a pair that was never cached is a deterministic no-op', () async {
      await expectLater(
        cache.removeIfPresent(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY'),
        completes,
      );
      expect(await cache.get(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY'), isNull);
    });
  });

  group('7. exact decimal round-trip', () {
    // Representative high-precision rates, chosen within FxRate's own
    // 12-fractional-digit input-sanity bound (see FxRate.maxFractionDigits).
    // No `double` is used anywhere in this path -- persistence goes
    // through the TEXT `rate` column exactly like
    // `TransactionExchangeRates.rate` (ADR-018).
    for (final String rateValue in <String>[
      '150',
      '0.006666666667',
      '1.234567890123',
      '0.000000000001',
    ]) {
      test('"$rateValue" round-trips exactly, with no floating-point drift', () async {
        final ReferenceFxRate original = rateFor(base: 'USD', quote: 'JPY', rateValue: rateValue);
        await cache.put(original);

        final ReferenceFxRate? read =
            await cache.get(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY');

        expect(read!.rate.rateAsString, rateValue);
        expect(read.rate, original.rate);
        expect(read.rate.baseCurrencyCode, 'USD');
        expect(read.rate.quoteCurrencyCode, 'JPY');
      });
    }
  });

  group('8. UTC timestamps', () {
    test('a whole-second UTC timestamp reads back as the same instant, isUtc == true', () async {
      final DateTime observed = DateTime.utc(2026, 6, 1, 11, 59, 0);
      final DateTime fetched = DateTime.utc(2026, 6, 1, 12, 0, 0);
      await cache.put(
        rateFor(
          base: 'USD',
          quote: 'JPY',
          rateValue: '150.25',
          observedAt: observed,
          fetchedAt: fetched,
        ),
      );

      final ReferenceFxRate? read =
          await cache.get(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY');

      expect(read!.observedAt.isUtc, isTrue);
      expect(read.fetchedAt.isUtc, isTrue);
      expect(read.observedAt.isAtSameMomentAs(observed), isTrue);
      expect(read.fetchedAt.isAtSameMomentAs(fetched), isTrue);
    });
  });

  group('9. local-tagged DateTime input', () {
    test(
      'a local-tagged DateTime representing an instant is normalized and read back as the '
      'same UTC instant, regardless of the machine timezone',
      () async {
        // Deliberately built from a UTC instant and re-tagged local via
        // `.toLocal()`, rather than a hardcoded offset -- this makes the
        // assertion below true on every machine's local timezone,
        // including a UTC+9 (Japan) one, without special-casing any of
        // them. See the CP9.1 "+9 hours" postmortem this mirrors.
        final DateTime utcInstant = DateTime.utc(2026, 6, 1, 12, 0, 0);
        final DateTime localTagged = utcInstant.toLocal();

        await cache.put(
          rateFor(
            base: 'USD',
            quote: 'JPY',
            rateValue: '150.25',
            observedAt: localTagged,
            fetchedAt: localTagged,
          ),
        );

        final ReferenceFxRate? read =
            await cache.get(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY');

        expect(read!.observedAt.isUtc, isTrue);
        expect(read.fetchedAt.isUtc, isTrue);
        expect(read.observedAt.isAtSameMomentAs(utcInstant), isTrue);
        expect(read.fetchedAt.isAtSameMomentAs(utcInstant), isTrue);
      },
    );
  });

  group('10. source', () {
    test('the source string survives persistence exactly, per ReferenceFxRate\'s trimmed contract', () async {
      await cache.put(rateFor(base: 'USD', quote: 'JPY', rateValue: '150.25', source: 'fixer'));
      final ReferenceFxRate? read =
          await cache.get(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY');
      expect(read!.source, 'fixer');
    });

    test('a source with surrounding whitespace is trimmed before it ever reaches the cache', () async {
      // ReferenceFxRate's own constructor trims -- proven at the domain
      // level in reference_fx_rate_test.dart. This proves the ALREADY-
      // trimmed value is what actually gets persisted and read back,
      // not re-trimmed or altered a second time by the cache.
      await cache.put(rateFor(base: 'USD', quote: 'JPY', rateValue: '150.25', source: '  fixer  '));
      final ReferenceFxRate? read =
          await cache.get(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY');
      expect(read!.source, 'fixer');
    });
  });

  group('11. case / canonical pair', () {
    test('a lower-case lookup still finds a rate cached under its canonical upper-case pair', () async {
      await cache.put(rateFor(base: 'USD', quote: 'JPY', rateValue: '150.25'));
      final ReferenceFxRate? read =
          await cache.get(baseCurrencyCode: 'usd', quoteCurrencyCode: 'jpy');
      expect(read, isNotNull);
      expect(read!.baseCurrencyCode, 'USD');
      expect(read.quoteCurrencyCode, 'JPY');
    });
  });

  group('15. CP9.2 service contract is unchanged with a Drift-backed cache', () {
    test('ReferenceFxRateService behaves identically when injected with DriftReferenceFxRateCache', () async {
      final DateTime now = DateTime.utc(2026, 6, 1, 12, 0, 0);
      final _FakeFxRateProvider provider = _FakeFxRateProvider();
      final ReferenceFxRateService service = ReferenceFxRateService(
        provider: provider,
        cache: cache,
        nowUtc: () => now,
      );

      // no-cache + success -> Fresh, and the Drift cache is actually
      // populated afterward.
      final ReferenceFxRate fetched = rateFor(
        base: 'USD',
        quote: 'JPY',
        rateValue: '150.25',
        fetchedAt: now,
        observedAt: now,
      );
      provider.nextResult = FxRateProviderSuccess(<ReferenceFxRate>[fetched]);
      final ReferenceRateResult first =
          await service.referenceRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY');
      expect(first, isA<ReferenceRateFresh>());
      expect(
        await cache.get(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY'),
        isNotNull,
      );

      // fresh cache -> Fresh again, without calling the provider a
      // second time (nextResult left set to the same success value would
      // still work, but clearing it proves the provider path isn't hit).
      provider.nextResult = null;
      final ReferenceRateResult second =
          await service.referenceRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY');
      expect(second, isA<ReferenceRateFresh>());

      // same-currency identity -- never touches the Drift cache at all.
      final ReferenceRateResult identity =
          await service.referenceRate(baseCurrencyCode: 'EUR', quoteCurrencyCode: 'EUR');
      expect(identity, isA<ReferenceRateIdentity>());
    });
  });
}
