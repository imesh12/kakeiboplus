import 'package:ai_financial_coach/core/fx/fx_rate.dart';
import 'package:ai_financial_coach/core/fx/reference_fx_rate.dart';
import 'package:ai_financial_coach/core/fx/reference_rate_result.dart';
import 'package:ai_financial_coach/core/fx/reference_rate_view.dart';
import 'package:flutter_test/flutter_test.dart';

// Checkpoint 9.5 Task C: `ReferenceRateView` adapts `ReferenceRateResult`
// for presentation without duplicating its fresh/stale/unavailable/
// identity policy. These tests lock in the mapping itself -- not the
// underlying policy, which `reference_fx_rate_service_test.dart` already
// covers exhaustively.

void main() {
  final DateTime fetchedAt = DateTime.utc(2026, 6, 1, 12, 0, 0);
  final DateTime observedAt = DateTime.utc(2026, 6, 1, 11, 55, 0);

  ReferenceFxRate referenceRate({String rateValue = '149.85'}) => ReferenceFxRate(
        rate: FxRate(baseCurrencyCode: 'USD', quoteCurrencyCode: 'JPY', rate: rateValue),
        source: 'exchangerate-api.com',
        observedAt: observedAt,
        fetchedAt: fetchedAt,
      );

  group('1. identity', () {
    test('maps to kind identity with no rate/formattedRate/source/fetchedAt', () {
      final ReferenceRateView view = ReferenceRateView.from(
        const ReferenceRateIdentity('EUR'),
        baseCurrencyCode: 'EUR',
        quoteCurrencyCode: 'EUR',
      );

      expect(view.kind, ReferenceRateViewKind.identity);
      expect(view.isIdentity, isTrue);
      expect(view.hasUsableRate, isFalse);
      expect(view.rate, isNull);
      expect(view.formattedRate, isNull);
      expect(view.source, isNull);
      expect(view.fetchedAt, isNull);
    });
  });

  group('2. fresh', () {
    test('maps to kind fresh with a formatted rate, source, and fetchedAt populated', () {
      final ReferenceRateView view = ReferenceRateView.from(
        ReferenceRateFresh(referenceRate()),
        baseCurrencyCode: 'USD',
        quoteCurrencyCode: 'JPY',
      );

      expect(view.kind, ReferenceRateViewKind.fresh);
      expect(view.isStale, isFalse);
      expect(view.hasUsableRate, isTrue);
      expect(view.baseCurrencyCode, 'USD');
      expect(view.quoteCurrencyCode, 'JPY');
      expect(view.formattedRate, '149.85');
      expect(view.source, 'exchangerate-api.com');
      expect(view.fetchedAt!.isAtSameMomentAs(fetchedAt), isTrue);
      expect(view.rate!.rateAsString, '149.85');
    });

    test('the exposed rate is the exact FxRate object, safe to feed to FxConverter unmodified', () {
      final ReferenceFxRate rr = referenceRate(rateValue: '0.0068');
      final ReferenceRateView view = ReferenceRateView.from(
        ReferenceRateFresh(rr),
        baseCurrencyCode: 'USD',
        quoteCurrencyCode: 'JPY',
      );

      expect(view.rate, rr.rate);
    });
  });

  group('3. stale', () {
    test('maps to kind stale, still carrying a usable formatted rate', () {
      final ReferenceRateView view = ReferenceRateView.from(
        ReferenceRateStale(referenceRate(rateValue: '148.00')),
        baseCurrencyCode: 'USD',
        quoteCurrencyCode: 'JPY',
      );

      expect(view.kind, ReferenceRateViewKind.stale);
      expect(view.isStale, isTrue);
      expect(view.hasUsableRate, isTrue);
      expect(view.formattedRate, '148');
    });
  });

  group('4. unavailable', () {
    test('maps to kind unavailable, exposing only the reason -- never the raw message', () {
      final ReferenceRateView view = ReferenceRateView.from(
        const ReferenceRateUnavailable(
          reason: ReferenceRateUnavailableReason.providerFailed,
          message: 'SocketException: Connection refused (raw, must never reach the UI)',
        ),
        baseCurrencyCode: 'USD',
        quoteCurrencyCode: 'JPY',
      );

      expect(view.kind, ReferenceRateViewKind.unavailable);
      expect(view.isUnavailable, isTrue);
      expect(view.hasUsableRate, isFalse);
      expect(view.unavailableReason, ReferenceRateUnavailableReason.providerFailed);
      expect(view.rate, isNull);
      expect(view.formattedRate, isNull);
      // The raw message is never carried onto the view at all -- there
      // is no field to expose it through, so a widget built on this
      // view structurally cannot render it, even by accident.
    });

    test('carries the requested pair even though ReferenceRateUnavailable itself has no currency codes', () {
      final ReferenceRateView view = ReferenceRateView.from(
        const ReferenceRateUnavailable(
          reason: ReferenceRateUnavailableReason.pairMismatch,
          message: 'irrelevant',
        ),
        baseCurrencyCode: 'GBP',
        quoteCurrencyCode: 'AUD',
      );

      expect(view.baseCurrencyCode, 'GBP');
      expect(view.quoteCurrencyCode, 'AUD');
    });
  });

  group('5. equality', () {
    test('two views built from equal inputs are equal', () {
      final ReferenceFxRate rr = referenceRate();
      final ReferenceRateView a = ReferenceRateView.from(
        ReferenceRateFresh(rr),
        baseCurrencyCode: 'USD',
        quoteCurrencyCode: 'JPY',
      );
      final ReferenceRateView b = ReferenceRateView.from(
        ReferenceRateFresh(rr),
        baseCurrencyCode: 'USD',
        quoteCurrencyCode: 'JPY',
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}
