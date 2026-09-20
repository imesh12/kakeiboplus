import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/providers.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/routing/app_routes.dart';
import 'package:ai_financial_coach/features/settings/presentation/settings_screen.dart';
import 'package:ai_financial_coach/l10n/generated/app_localizations.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// V1 Navigation Shell Implementation Checkpoint
// (`docs/22_UI_REFERENCE_PRODUCT_ARCHITECTURE.md` §26 / ADR-034): this
// screen is no longer a primary bottom-nav destination and no longer
// shows its former nav rows (Accounts/Categories/Budgets/Savings
// Goals/Recurring/International Preferences/Appearance/Cloud Account) or
// the Beta 0 disclaimer -- all of that moved to the new `MoreScreen`
// (see `more_screen_test.dart`). This file is trimmed to what
// `SettingsScreen` still actually renders: the read-only identity card
// (display name + location/currency summary) and its AppBar title. No
// coverage was deleted -- the nav-row/disclaimer assertions this file
// used to make (International / Localization Foundation Checkpoint 4.3,
// extended by Checkpoint 6.8, and Checkpoint 8.1's Appearance row) now
// live in `more_screen_test.dart` instead, exercising the same rows
// through their new home.
void main() {
  Future<(AppDatabase, String profileId)> seededDb() async {
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    final ProfileRepository profileRepo = ProfileRepository(db);
    final String profileId = await profileRepo.createProfile(
      displayName: 'Test User',
      homeCountry: 'LK',
      currentCountry: 'JP',
      homeCurrency: 'LKR',
      livingCurrency: 'JPY',
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

  Widget appWithRouter(ProviderContainer container, {Locale locale = const Locale('en')}) {
    final GoRouter router = GoRouter(
      initialLocation: AppRoutes.profile,
      routes: <RouteBase>[
        GoRoute(path: AppRoutes.profile, builder: (context, state) => const SettingsScreen()),
      ],
    );
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }

  group('identity card localization', () {
    testWidgets(
        'the Profile screen renders in Japanese -- AppBar title and the identity '
        'card location summary', (tester) async {
      final (AppDatabase db, String profileId) = await seededDb();
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container, locale: const Locale('ja')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      expect(find.text('プロフィール'), findsOneWidget); // navProfile (AppBar title)
      // profileLocationSummary -- Japanese sentence template, raw codes
      // untranslated.
      expect(find.text('現在の国: JP（JPY）・母国: LK（LKR）'), findsOneWidget);
    });

    testWidgets(
        'a Japanese-language display name renders exactly as entered, alongside the '
        'untranslated raw country/currency codes', (tester) async {
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      final ProfileRepository profileRepo = ProfileRepository(db);
      await profileRepo.createProfile(
        displayName: '田中 花子',
        homeCountry: 'MM',
        currentCountry: 'KW',
        homeCurrency: 'MMK',
        livingCurrency: 'KWD',
        preferredLanguage: 'ja',
        timezone: 'Asia/Kuwait',
        dateFormat: 'ymd',
        numberFormat: 'comma_period',
      );
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container, locale: const Locale('ja')));
      await tester.pumpAndSettle();

      expect(find.text('田中 花子'), findsOneWidget); // untouched user content, never translated
      // Raw ISO country/currency codes interpolated into the Japanese
      // template, never translated or reordered.
      expect(find.text('現在の国: KW（KWD）・母国: MM（MMK）'), findsOneWidget);
    });

    testWidgets(
        'the Profile screen renders without overflow under the Japanese locale at a '
        '1.6x text scale', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final (AppDatabase db, String profileId) = await seededDb();
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container, locale: const Locale('ja')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('プロフィール'), findsOneWidget);
    });

    testWidgets(
        'the Profile screen renders without overflow under the Japanese locale at an '
        'extreme 2.0x text scale', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final (AppDatabase db, String profileId) = await seededDb();
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container, locale: const Locale('ja')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('プロフィール'), findsOneWidget);
    });

    testWidgets(
        'a long Japanese display name is still represented in full by its Text widget '
        'at a narrow 320px width and a 1.6x text scale', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      const String longName = '田中 太郎（狭い画面のレイアウトを検証するための長い表示名）';
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      final ProfileRepository profileRepo = ProfileRepository(db);
      await profileRepo.createProfile(
        displayName: longName,
        homeCountry: 'LK',
        currentCountry: 'JP',
        homeCurrency: 'LKR',
        livingCurrency: 'JPY',
        preferredLanguage: 'ja',
        timezone: 'Asia/Tokyo',
        dateFormat: 'yyyy-MM-dd',
        numberFormat: '#,##0.##',
      );
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container, locale: const Locale('ja')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(longName), findsOneWidget);
    });
  });

  testWidgets('English locale renders the AppBar title and identity card', (tester) async {
    final (AppDatabase db, String profileId) = await seededDb();
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithRouter(container));
    await tester.pumpAndSettle();

    expect(find.text('Profile'), findsOneWidget); // navProfile (AppBar title)
    expect(find.text('Test User'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
