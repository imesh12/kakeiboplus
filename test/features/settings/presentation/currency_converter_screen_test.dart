import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/providers.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/fx/fx_rate.dart';
import 'package:ai_financial_coach/core/fx/fx_rate_provider.dart';
import 'package:ai_financial_coach/core/fx/in_memory_reference_fx_rate_cache.dart';
import 'package:ai_financial_coach/core/fx/reference_fx_rate.dart';
import 'package:ai_financial_coach/core/fx/reference_fx_rate_cache.dart';
import 'package:ai_financial_coach/core/fx/reference_fx_rate_providers.dart';
import 'package:ai_financial_coach/features/settings/presentation/currency_converter_screen.dart';
import 'package:ai_financial_coach/features/settings/presentation/favorite_currency_pairs_provider.dart';
import 'package:ai_financial_coach/l10n/generated/app_localizations.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Checkpoint 9.6 -- Currency Converter widget tests.
///
/// Same hand-written-fake / real-in-memory-database conventions as every
/// other CP9.x FX widget test in this project (no mocking library --
/// `_FakeFxRateProvider` mirrors `reference_rate_card_test.dart`'s own
/// fake, extended with `lastRequestedBaseCurrencyCode`/
/// `lastRequestedQuoteCurrencyCodes` the same way
/// `test/core/fx/reference_rate_provider_test.dart`'s fake already does,
/// so ordered-pair-direction assertions don't need a second fake type).
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

ReferenceFxRate _referenceRate(String base, String quote, String value, {DateTime? fetchedAt}) =>
    ReferenceFxRate(
      rate: FxRate(baseCurrencyCode: base, quoteCurrencyCode: quote, rate: value),
      source: 'exchangerate-api.com',
      // Real-wall-clock-relative by default -- see Repair #1/#2's own
      // fix for why a hardcoded past calendar date here would eventually
      // (and silently) become "stale" purely because real time moved on.
      observedAt: fetchedAt ?? DateTime.now().toUtc(),
      fetchedAt: fetchedAt ?? DateTime.now().toUtc(),
    );

void main() {
  Future<(AppDatabase, String profileId)> seededDb({
    String homeCurrency = 'USD',
    String livingCurrency = 'JPY',
  }) async {
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    final ProfileRepository profileRepo = ProfileRepository(db);
    final String profileId = await profileRepo.createProfile(
      displayName: 'Test User',
      homeCountry: 'US',
      currentCountry: 'JP',
      homeCurrency: homeCurrency,
      livingCurrency: livingCurrency,
      preferredLanguage: 'en',
      timezone: 'Asia/Tokyo',
      dateFormat: 'yyyy-MM-dd',
      numberFormat: '#,##0.##',
    );
    return (db, profileId);
  }

  Future<void> disposeInOrder(WidgetTester tester, ProviderContainer container, AppDatabase db) async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pumpAndSettle();
    await db.close();
  }

  /// Deterministically brings [target] into view within this screen's
  /// scrollable body.
  ///
  /// Repair Pass #1 (Failures 3-6): the Favorite Pairs section sits near
  /// the bottom of this screen's `ListView`, below the From/To fields,
  /// the swap/favorite controls, and the full conversion-result +
  /// Reference Rate card -- in the widget-test surface's default
  /// viewport, that section's elements are outside the
  /// viewport-plus-cache-extent window Flutter's Sliver machinery
  /// actually mounts, so `find.text`/`find.byKey` (and `tester.tap`) on
  /// it evaluate to zero *elements*, not zero pixels -- there is no
  /// production bug here, only a test that needed to scroll first. Same
  /// root cause, same fix, and (deliberately) nearly the same
  /// implementation as `international_preferences_screen_test.dart`'s
  /// own `scrollPageUntilVisible`: reset to the top first when [target]
  /// isn't yet present (a target already scrolled past can't be found by
  /// only ever searching downward), then search downward in small
  /// bounded increments until it appears.
  Future<void> scrollUntilVisible(WidgetTester tester, Finder target, {required String description}) async {
    if (target.evaluate().isEmpty) {
      final Finder scrollable = find.byType(Scrollable).first;
      final ScrollableState scrollableState = tester.state<ScrollableState>(scrollable);
      if (scrollableState.position.pixels != 0) {
        scrollableState.position.jumpTo(0);
        await tester.pump();
      }

      const int maxScrollAttempts = 20;
      int attempts = 0;
      while (target.evaluate().isEmpty && attempts < maxScrollAttempts) {
        await tester.drag(scrollable, const Offset(0, -200));
        await tester.pump();
        attempts++;
      }
      if (target.evaluate().isEmpty) {
        fail(
          '$description was not found after resetting the page to the top and '
          '$maxScrollAttempts bounded scroll attempts.',
        );
      }
    }

    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
  }

  Widget appWithConverter(
    ProviderContainer container, {
    Locale locale = const Locale('en'),
  }) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const CurrencyConverterScreen(),
      ),
    );
  }

  group('1. default pair (Task 14)', () {
    testWidgets('seeds From/To from the profile home -> living currency', (tester) async {
      final (AppDatabase db, String profileId) = await seededDb(homeCurrency: 'USD', livingCurrency: 'JPY');
      final _FakeFxRateProvider fakeProvider = _FakeFxRateProvider()
        ..nextResult = FxRateProviderSuccess(<ReferenceFxRate>[_referenceRate('USD', 'JPY', '149.85')]);
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          fxRateProviderProvider.overrideWithValue(fakeProvider),
          referenceFxRateCacheProvider.overrideWithValue(InMemoryReferenceFxRateCache()),
        ],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithConverter(container));
      await tester.pumpAndSettle();

      // Ordered pair requested (Task 18 #2): USD -> JPY, exactly the
      // profile's home -> living direction, never inverted.
      expect(fakeProvider.lastRequestedBaseCurrencyCode, 'USD');
      expect(fakeProvider.lastRequestedQuoteCurrencyCodes, <String>{'JPY'});
      expect(profileId, isNotEmpty);
    });
  });

  group('2. exact conversion + currency precision (Tasks 4/5/18)', () {
    testWidgets('JPY target rounds to 0 decimals', (tester) async {
      final (AppDatabase db, String _) = await seededDb(homeCurrency: 'USD', livingCurrency: 'JPY');
      final _FakeFxRateProvider fakeProvider = _FakeFxRateProvider()
        ..nextResult = FxRateProviderSuccess(<ReferenceFxRate>[_referenceRate('USD', 'JPY', '149.85')]);
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          fxRateProviderProvider.overrideWithValue(fakeProvider),
          referenceFxRateCacheProvider.overrideWithValue(InMemoryReferenceFxRateCache()),
        ],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithConverter(container));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('converterAmountField')), '10');
      await tester.pumpAndSettle();

      // 10 USD * 149.85 = 1498.5 -> ROUND HALF UP -> 1499 (0 decimals).
      expect(find.text('≈ ¥1,499'), findsOneWidget);
    });

    testWidgets('KWD target rounds to 3 decimals', (tester) async {
      final (AppDatabase db, String _) = await seededDb(homeCurrency: 'USD', livingCurrency: 'KWD');
      final _FakeFxRateProvider fakeProvider = _FakeFxRateProvider()
        ..nextResult = FxRateProviderSuccess(<ReferenceFxRate>[_referenceRate('USD', 'KWD', '0.307')]);
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          fxRateProviderProvider.overrideWithValue(fakeProvider),
          referenceFxRateCacheProvider.overrideWithValue(InMemoryReferenceFxRateCache()),
        ],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithConverter(container));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('converterAmountField')), '10');
      await tester.pumpAndSettle();

      // 10 USD * 0.307 = 3.07 -> exactly 3 decimals for KWD -> 3.070.
      //
      // Repair Pass #1 (Failure 1): the expected string here was wrong,
      // not production. `CurrencyRegistry.seed`'s KWD entry has
      // `symbol: 'د.ك'` (not the plain code "KWD"), and `MoneyFormatter`
      // always prefixes with `currency.symbol` and never a space -- the
      // same policy every other currency in this file already relies on
      // (JPY's "¥", MMK's "K", USD's "$" below). Every existing
      // KWD-formatting test elsewhere in this project (e.g.
      // `test/widget/home_screen_test.dart`, `goal_detail_screen_test.dart`)
      // already expects this same "د.ك12,345.678"-style rendering, so
      // "≈ KWD 3.070" was never a real production output to match.
      expect(find.text('≈ د.ك3.070'), findsOneWidget);
    });

    testWidgets('MMK target respects 2 decimals', (tester) async {
      final (AppDatabase db, String _) = await seededDb(homeCurrency: 'USD', livingCurrency: 'MMK');
      final _FakeFxRateProvider fakeProvider = _FakeFxRateProvider()
        ..nextResult = FxRateProviderSuccess(<ReferenceFxRate>[_referenceRate('USD', 'MMK', '2100.5')]);
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          fxRateProviderProvider.overrideWithValue(fakeProvider),
          referenceFxRateCacheProvider.overrideWithValue(InMemoryReferenceFxRateCache()),
        ],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithConverter(container));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('converterAmountField')), '2');
      await tester.pumpAndSettle();

      // 2 USD * 2100.5 = 4201.0 -> MMK 2 decimals -> 4,201.00.
      expect(find.text('≈ K4,201.00'), findsOneWidget);
    });

    testWidgets('exact rate formatting is independent of the target money decimals', (tester) async {
      final (AppDatabase db, String _) = await seededDb(homeCurrency: 'USD', livingCurrency: 'JPY');
      final _FakeFxRateProvider fakeProvider = _FakeFxRateProvider()
        ..nextResult = FxRateProviderSuccess(<ReferenceFxRate>[_referenceRate('USD', 'JPY', '149.85')]);
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          fxRateProviderProvider.overrideWithValue(fakeProvider),
          referenceFxRateCacheProvider.overrideWithValue(InMemoryReferenceFxRateCache()),
        ],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithConverter(container));
      await tester.pumpAndSettle();

      // The rate equation keeps its own full precision ("149.85") even
      // though JPY (the converted MONEY) has 0 decimals -- two
      // deliberately separate formatting policies (Task 5).
      expect(find.text('1 USD = 149.85 JPY'), findsOneWidget);
    });
  });

  group('3. same currency (Task 6)', () {
    testWidgets('identity conversion, same-currency message, zero provider calls', (tester) async {
      final (AppDatabase db, String _) = await seededDb(homeCurrency: 'USD', livingCurrency: 'USD');
      final _FakeFxRateProvider fakeProvider = _FakeFxRateProvider();
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          fxRateProviderProvider.overrideWithValue(fakeProvider),
          referenceFxRateCacheProvider.overrideWithValue(InMemoryReferenceFxRateCache()),
        ],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithConverter(container));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('converterAmountField')), '25');
      await tester.pumpAndSettle();

      // Repair Pass #1 (Failure 2): the expected string here was wrong,
      // not production. `Money.toMajorUnitsString` always zero-pads the
      // fraction out to the currency's full `minorUnits` digit count
      // (see its own doc comment / `money_test.dart`'s KWD zero-padding
      // case), so 2500 minor USD units always renders as "25.00", never
      // "25" -- exactly the same "$25.00"-style rendering every existing
      // round-dollar test elsewhere already expects (e.g.
      // `test/widget/accounts_screen_test.dart`'s `Money.fromMinorUnits(2500,
      // 'USD') // $25.00`).
      expect(find.text('≈ \$25.00'), findsOneWidget);
      expect(
        find.text('From and To are the same currency, so the converted amount is exactly what you entered.'),
        findsOneWidget,
      );
      expect(fakeProvider.callCount, 0);
    });
  });

  group('4. reference-rate status (Tasks 8/18)', () {
    testWidgets('unavailable rate shows no invented conversion result', (tester) async {
      final (AppDatabase db, String _) = await seededDb(homeCurrency: 'USD', livingCurrency: 'JPY');
      final _FakeFxRateProvider fakeProvider = _FakeFxRateProvider()
        ..nextResult = const FxRateProviderFailure(
          'SocketException: Connection refused (must never reach the UI)',
        );
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          fxRateProviderProvider.overrideWithValue(fakeProvider),
          referenceFxRateCacheProvider.overrideWithValue(InMemoryReferenceFxRateCache()),
        ],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithConverter(container));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('converterAmountField')), '10');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('conversionUnavailableMessage')), findsWidgets);
      expect(find.textContaining('SocketException'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('stale rate still converts and shows the cached indicator', (tester) async {
      final (AppDatabase db, String _) = await seededDb(homeCurrency: 'USD', livingCurrency: 'JPY');
      final ReferenceFxRateCache cache = InMemoryReferenceFxRateCache();
      await cache.put(
        _referenceRate(
          'USD',
          'JPY',
          '148.00',
          fetchedAt: DateTime.now().toUtc().subtract(const Duration(hours: 5)),
        ),
      );
      final _FakeFxRateProvider fakeProvider = _FakeFxRateProvider()
        ..nextResult = const FxRateProviderFailure('vendor unreachable');
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          fxRateProviderProvider.overrideWithValue(fakeProvider),
          referenceFxRateCacheProvider.overrideWithValue(cache),
        ],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithConverter(container));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('converterAmountField')), '10');
      await tester.pumpAndSettle();

      // 10 USD * 148.00 = 1480 JPY, but STALE -> "(cached)" suffix.
      expect(find.text('≈ ¥1,480 (cached)'), findsOneWidget);
      expect(find.byKey(const Key('converterStaleChip')), findsOneWidget);
    });

    testWidgets('fresh rate displays normally with source and updated labels', (tester) async {
      final (AppDatabase db, String _) = await seededDb(homeCurrency: 'USD', livingCurrency: 'JPY');
      final _FakeFxRateProvider fakeProvider = _FakeFxRateProvider()
        ..nextResult = FxRateProviderSuccess(<ReferenceFxRate>[_referenceRate('USD', 'JPY', '149.85')]);
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          fxRateProviderProvider.overrideWithValue(fakeProvider),
          referenceFxRateCacheProvider.overrideWithValue(InMemoryReferenceFxRateCache()),
        ],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithConverter(container));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('converterStaleChip')), findsNothing);
      expect(find.textContaining('Source: exchangerate-api.com'), findsOneWidget);
      expect(find.byKey(const Key('converterRateEquationText')), findsOneWidget);
    });
  });

  group('5. invalid amount / empty input (Task 4)', () {
    testWidgets('invalid text shows the enter-amount prompt, never a crash', (tester) async {
      final (AppDatabase db, String _) = await seededDb(homeCurrency: 'USD', livingCurrency: 'JPY');
      final _FakeFxRateProvider fakeProvider = _FakeFxRateProvider()
        ..nextResult = FxRateProviderSuccess(<ReferenceFxRate>[_referenceRate('USD', 'JPY', '149.85')]);
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          fxRateProviderProvider.overrideWithValue(fakeProvider),
          referenceFxRateCacheProvider.overrideWithValue(InMemoryReferenceFxRateCache()),
        ],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithConverter(container));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('converterAmountField')), 'not a number');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Enter an amount to convert.'), findsOneWidget);
    });
  });

  group('6. amount typing never repeatedly fetches (Task 9)', () {
    testWidgets('typing 1, 10, 100, 1000 calls the provider exactly once', (tester) async {
      final (AppDatabase db, String _) = await seededDb(homeCurrency: 'USD', livingCurrency: 'JPY');
      final _FakeFxRateProvider fakeProvider = _FakeFxRateProvider()
        ..nextResult = FxRateProviderSuccess(<ReferenceFxRate>[_referenceRate('USD', 'JPY', '149.85')]);
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          fxRateProviderProvider.overrideWithValue(fakeProvider),
          referenceFxRateCacheProvider.overrideWithValue(InMemoryReferenceFxRateCache()),
        ],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithConverter(container));
      await tester.pumpAndSettle();
      expect(fakeProvider.callCount, 1);

      for (final String typed in <String>['1', '10', '100', '1000']) {
        await tester.enterText(find.byKey(const Key('converterAmountField')), typed);
        await tester.pumpAndSettle();
      }

      expect(fakeProvider.callCount, 1);
      expect(find.text('≈ ¥149,850'), findsOneWidget);
    });
  });

  group('7. explicit swap (Task 7/18)', () {
    testWidgets('swap reverses From/To and requests the reverse ordered pair, never a reciprocal', (
      tester,
    ) async {
      final (AppDatabase db, String _) = await seededDb(homeCurrency: 'USD', livingCurrency: 'JPY');
      final _FakeFxRateProvider fakeProvider = _FakeFxRateProvider()
        ..nextResult = FxRateProviderSuccess(<ReferenceFxRate>[_referenceRate('USD', 'JPY', '149.85')]);
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          fxRateProviderProvider.overrideWithValue(fakeProvider),
          referenceFxRateCacheProvider.overrideWithValue(InMemoryReferenceFxRateCache()),
        ],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithConverter(container));
      await tester.pumpAndSettle();
      expect(fakeProvider.lastRequestedBaseCurrencyCode, 'USD');
      expect(fakeProvider.callCount, 1);

      // The reverse pair (JPY -> USD) is a deliberately DIFFERENT quote
      // than USD -> JPY -- never `1 / 149.85`.
      fakeProvider.nextResult = FxRateProviderSuccess(<ReferenceFxRate>[_referenceRate('JPY', 'USD', '0.0067')]);
      await tester.tap(find.byKey(const Key('swapCurrenciesButton')));
      await tester.pumpAndSettle();

      expect(fakeProvider.callCount, 2);
      expect(fakeProvider.lastRequestedBaseCurrencyCode, 'JPY');
      expect(fakeProvider.lastRequestedQuoteCurrencyCodes, <String>{'USD'});
      expect(find.text('1 JPY = 0.0067 USD'), findsOneWidget);
    });
  });

  group('8. favorite pairs (Tasks 11/12/18)', () {
    testWidgets('favoriting, unfavoriting, and the reverse pair being distinct', (tester) async {
      final (AppDatabase db, String _) = await seededDb(homeCurrency: 'USD', livingCurrency: 'JPY');
      final _FakeFxRateProvider fakeProvider = _FakeFxRateProvider()
        ..nextResult = FxRateProviderSuccess(<ReferenceFxRate>[_referenceRate('USD', 'JPY', '149.85')]);
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          fxRateProviderProvider.overrideWithValue(fakeProvider),
          referenceFxRateCacheProvider.overrideWithValue(InMemoryReferenceFxRateCache()),
        ],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithConverter(container));
      await tester.pumpAndSettle();

      await scrollUntilVisible(
        tester,
        find.byKey(const Key('toggleFavoritePairButton')),
        description: 'favorite toggle button',
      );
      await tester.tap(find.byKey(const Key('toggleFavoritePairButton')));
      await tester.pumpAndSettle();
      expect(container.read(favoriteCurrencyPairsProvider), <(String, String)>[('USD', 'JPY')]);

      await scrollUntilVisible(
        tester,
        find.byKey(const Key('favoritePair_USD_JPY')),
        description: "favorite chip 'USD → JPY'",
      );
      expect(find.byKey(const Key('favoritePair_USD_JPY')), findsOneWidget);

      // The reverse pair is a distinct favorite, never merged/deduped.
      container.read(favoriteCurrencyPairsProvider.notifier).state = <(String, String)>[
        ('USD', 'JPY'),
        ('JPY', 'USD'),
      ];
      await tester.pumpAndSettle();
      await scrollUntilVisible(
        tester,
        find.byKey(const Key('favoritePair_JPY_USD')),
        description: "favorite chip 'JPY → USD'",
      );
      expect(find.byKey(const Key('favoritePair_JPY_USD')), findsOneWidget);
      expect(find.byKey(const Key('favoritePair_USD_JPY')), findsOneWidget);

      await scrollUntilVisible(
        tester,
        find.byKey(const Key('toggleFavoritePairButton')),
        description: 'favorite toggle button',
      );
      await tester.tap(find.byKey(const Key('toggleFavoritePairButton')));
      await tester.pumpAndSettle();
      expect(container.read(favoriteCurrencyPairsProvider), <(String, String)>[('JPY', 'USD')]);
    });

    testWidgets('selecting a favorite changes the active pair', (tester) async {
      final (AppDatabase db, String _) = await seededDb(homeCurrency: 'USD', livingCurrency: 'JPY');
      final _FakeFxRateProvider fakeProvider = _FakeFxRateProvider()
        ..nextResult = FxRateProviderSuccess(<ReferenceFxRate>[_referenceRate('USD', 'JPY', '149.85')]);
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          fxRateProviderProvider.overrideWithValue(fakeProvider),
          referenceFxRateCacheProvider.overrideWithValue(InMemoryReferenceFxRateCache()),
          favoriteCurrencyPairsProvider.overrideWith((ref) => <(String, String)>[('EUR', 'CAD')]),
        ],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      // Opening the screen with a favorite already saved must fetch only
      // the ACTIVE pair (USD -> JPY, from the profile default), never
      // every favorite -- Task 11's "no automatic request for every
      // favorite merely because the screen opened."
      await tester.pumpWidget(appWithConverter(container));
      await tester.pumpAndSettle();
      expect(fakeProvider.callCount, 1);
      expect(fakeProvider.lastRequestedBaseCurrencyCode, 'USD');

      fakeProvider.nextResult = FxRateProviderSuccess(<ReferenceFxRate>[_referenceRate('EUR', 'CAD', '1.47')]);
      await scrollUntilVisible(
        tester,
        find.byKey(const Key('favoritePair_EUR_CAD')),
        description: "favorite chip 'EUR → CAD'",
      );
      await tester.tap(find.byKey(const Key('favoritePair_EUR_CAD')));
      await tester.pumpAndSettle();

      expect(fakeProvider.lastRequestedBaseCurrencyCode, 'EUR');
      expect(fakeProvider.lastRequestedQuoteCurrencyCodes, <String>{'CAD'});
    });

    testWidgets('reaching the 6-pair limit refuses a new favorite with no silent eviction', (tester) async {
      final (AppDatabase db, String _) = await seededDb(homeCurrency: 'USD', livingCurrency: 'JPY');
      final _FakeFxRateProvider fakeProvider = _FakeFxRateProvider()
        ..nextResult = FxRateProviderSuccess(<ReferenceFxRate>[_referenceRate('USD', 'JPY', '149.85')]);
      final List<(String, String)> sixFavorites = <(String, String)>[
        ('EUR', 'CAD'),
        ('CAD', 'EUR'),
        ('LKR', 'JPY'),
        ('JPY', 'LKR'),
        ('INR', 'USD'),
        ('USD', 'INR'),
      ];
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          fxRateProviderProvider.overrideWithValue(fakeProvider),
          referenceFxRateCacheProvider.overrideWithValue(InMemoryReferenceFxRateCache()),
          favoriteCurrencyPairsProvider.overrideWith((ref) => sixFavorites),
        ],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithConverter(container));
      await tester.pumpAndSettle();

      // The active pair (USD -> JPY) is NOT among the 6 saved favorites,
      // so tapping the star tries to add a 7th -- must be refused with
      // the limit message, and the existing 6 must remain untouched
      // (no silent eviction of e.g. the oldest one).
      await tester.tap(find.byKey(const Key('toggleFavoritePairButton')));
      await tester.pumpAndSettle();

      expect(container.read(favoriteCurrencyPairsProvider), sixFavorites);
      expect(find.text('You can save up to 6 favorite pairs.'), findsOneWidget);
    });

    testWidgets('favorites are session-only: a fresh container starts empty', (tester) async {
      // Persistence decision (ADR-028): favorites live only in this
      // ProviderContainer's in-memory state. A brand new container (the
      // same simulation `test/widget/home_screen_test.dart` etc. use for
      // "does this survive disposal" checks) never inherits another
      // container's favorites.
      final ProviderContainer firstContainer = ProviderContainer();
      firstContainer.read(favoriteCurrencyPairsProvider.notifier).state = <(String, String)>[
        ('USD', 'JPY'),
      ];
      expect(firstContainer.read(favoriteCurrencyPairsProvider), isNotEmpty);
      firstContainer.dispose();

      final ProviderContainer secondContainer = ProviderContainer();
      addTearDown(secondContainer.dispose);
      expect(secondContainer.read(favoriteCurrencyPairsProvider), isEmpty);
    });
  });

  group('9. localization (Task 15/18)', () {
    testWidgets('English', (tester) async {
      final (AppDatabase db, String _) = await seededDb(homeCurrency: 'USD', livingCurrency: 'JPY');
      final _FakeFxRateProvider fakeProvider = _FakeFxRateProvider()
        ..nextResult = FxRateProviderSuccess(<ReferenceFxRate>[_referenceRate('USD', 'JPY', '149.85')]);
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          fxRateProviderProvider.overrideWithValue(fakeProvider),
          referenceFxRateCacheProvider.overrideWithValue(InMemoryReferenceFxRateCache()),
        ],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithConverter(container));
      await tester.pumpAndSettle();

      expect(find.text('Currency Converter'), findsOneWidget);
      await scrollUntilVisible(
        tester,
        find.text('Favorite pairs'),
        description: "'Favorite pairs' section title",
      );
      expect(find.text('Favorite pairs'), findsOneWidget);
      expect(find.text('No favorite pairs yet.'), findsOneWidget);
    });

    testWidgets('Japanese', (tester) async {
      final (AppDatabase db, String _) = await seededDb(homeCurrency: 'USD', livingCurrency: 'JPY');
      final _FakeFxRateProvider fakeProvider = _FakeFxRateProvider()
        ..nextResult = FxRateProviderSuccess(<ReferenceFxRate>[_referenceRate('USD', 'JPY', '149.85')]);
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          fxRateProviderProvider.overrideWithValue(fakeProvider),
          referenceFxRateCacheProvider.overrideWithValue(InMemoryReferenceFxRateCache()),
        ],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithConverter(container, locale: const Locale('ja')));
      await tester.pumpAndSettle();

      expect(find.text('通貨換算'), findsOneWidget);
      await scrollUntilVisible(
        tester,
        find.text('お気に入りの通貨ペア'),
        description: "Japanese 'Favorite pairs' section title",
      );
      expect(find.text('お気に入りの通貨ペア'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
