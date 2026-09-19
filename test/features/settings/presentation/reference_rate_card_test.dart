import 'package:ai_financial_coach/core/fx/fx_rate.dart';
import 'package:ai_financial_coach/core/fx/fx_rate_provider.dart';
import 'package:ai_financial_coach/core/fx/in_memory_reference_fx_rate_cache.dart';
import 'package:ai_financial_coach/core/fx/reference_fx_rate.dart';
import 'package:ai_financial_coach/core/fx/reference_fx_rate_cache.dart';
import 'package:ai_financial_coach/core/fx/reference_fx_rate_providers.dart';
import 'package:ai_financial_coach/features/settings/presentation/reference_rate_card.dart';
import 'package:ai_financial_coach/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hand-written fake -- same pattern used throughout `test/core/fx/`.
class _FakeFxRateProvider implements FxRateProvider {
  FxRateProviderResult? nextResult;
  int callCount = 0;

  @override
  Future<FxRateProviderResult> fetchRates({
    required String baseCurrencyCode,
    required Set<String> quoteCurrencyCodes,
  }) async {
    callCount++;
    final FxRateProviderResult? result = nextResult;
    if (result == null) {
      throw StateError('_FakeFxRateProvider.nextResult was not set before fetchRates was called.');
    }
    return result;
  }
}

ReferenceFxRate _referenceRate(String base, String quote, String value, {DateTime? fetchedAt}) =>
    ReferenceFxRate(
      rate: FxRate(baseCurrencyCode: base, quoteCurrencyCode: quote, rate: value),
      source: 'exchangerate-api.com',
      observedAt: fetchedAt ?? DateTime.utc(2026, 6, 1),
      fetchedAt: fetchedAt ?? DateTime.utc(2026, 6, 1),
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

  Widget appWithCard(
    ProviderContainer container, {
    required String homeCurrencyCode,
    required String livingCurrencyCode,
  }) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ReferenceRateCard(
            homeCurrencyCode: homeCurrencyCode,
            livingCurrencyCode: livingCurrencyCode,
          ),
        ),
      ),
    );
  }

  group('1. same-currency (Task E)', () {
    testWidgets('shows the same-currency message and makes zero provider calls', (tester) async {
      await tester.pumpWidget(appWithCard(container, homeCurrencyCode: 'USD', livingCurrencyCode: 'USD'));
      await tester.pumpAndSettle();

      expect(
        find.text("Your home and living currency are the same, so there's no reference rate to show."),
        findsOneWidget,
      );
      expect(fakeProvider.callCount, 0);
      // No refresh button either -- there's nothing to refresh.
      expect(find.byKey(const Key('refreshReferenceRateButton')), findsNothing);
    });
  });

  group('2. fresh rate', () {
    testWidgets('renders "1 <home> = <rate> <living>" once the provider resolves', (tester) async {
      fakeProvider.nextResult =
          FxRateProviderSuccess(<ReferenceFxRate>[_referenceRate('USD', 'JPY', '149.85')]);

      await tester.pumpWidget(appWithCard(container, homeCurrencyCode: 'USD', livingCurrencyCode: 'JPY'));
      await tester.pumpAndSettle();

      expect(find.text('1 USD = 149.85 JPY'), findsOneWidget);
      expect(find.byKey(const Key('referenceRateStaleChip')), findsNothing);
    });
  });

  group('3. stale rate', () {
    testWidgets('shows the stale indicator alongside the last-known rate', (tester) async {
      final DateTime staleFetchedAt = DateTime.now().toUtc().subtract(const Duration(hours: 5));
      await cache.put(_referenceRate('USD', 'JPY', '148.00', fetchedAt: staleFetchedAt));
      fakeProvider.nextResult = const FxRateProviderFailure('vendor unreachable');

      await tester.pumpWidget(appWithCard(container, homeCurrencyCode: 'USD', livingCurrencyCode: 'JPY'));
      await tester.pumpAndSettle();

      expect(find.text('1 USD = 148 JPY'), findsOneWidget);
      expect(find.byKey(const Key('referenceRateStaleChip')), findsOneWidget);
    });
  });

  group('4. unavailable', () {
    testWidgets('shows a generic unavailable message, never a raw exception string', (tester) async {
      fakeProvider.nextResult = const FxRateProviderFailure(
        'SocketException: Connection refused (must never reach the UI)',
      );

      await tester.pumpWidget(appWithCard(container, homeCurrencyCode: 'USD', livingCurrencyCode: 'JPY'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('referenceRateUnavailableMessage')), findsOneWidget);
      expect(find.textContaining('SocketException'), findsNothing);
    });
  });

  group('5. unrecognized currency code never crashes', () {
    testWidgets('an unknown living currency code shows unavailable with zero provider calls', (tester) async {
      await tester.pumpWidget(
        appWithCard(container, homeCurrencyCode: 'USD', livingCurrencyCode: 'ZZZ'),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('referenceRateUnavailableMessage')), findsOneWidget);
      expect(fakeProvider.callCount, 0);
      expect(find.byKey(const Key('refreshReferenceRateButton')), findsOneWidget);
    });
  });

  group('6. manual refresh (Task G)', () {
    testWidgets('tapping refresh invalidates and re-fetches when the cache is stale', (tester) async {
      final DateTime staleFetchedAt = DateTime.now().toUtc().subtract(const Duration(hours: 5));
      await cache.put(_referenceRate('USD', 'JPY', '148.00', fetchedAt: staleFetchedAt));
      fakeProvider.nextResult = const FxRateProviderFailure('still down');

      await tester.pumpWidget(appWithCard(container, homeCurrencyCode: 'USD', livingCurrencyCode: 'JPY'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('referenceRateStaleChip')), findsOneWidget);
      expect(fakeProvider.callCount, 1);

      fakeProvider.nextResult =
          FxRateProviderSuccess(<ReferenceFxRate>[_referenceRate('USD', 'JPY', '150.10')]);
      await tester.tap(find.byKey(const Key('refreshReferenceRateButton')));
      await tester.pumpAndSettle();

      expect(fakeProvider.callCount, 2);
      expect(find.text('1 USD = 150.1 JPY'), findsOneWidget);
      expect(find.byKey(const Key('referenceRateStaleChip')), findsNothing);
    });
  });
}
