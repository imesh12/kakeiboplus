import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/providers.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/routing/app_routes.dart';
import 'package:ai_financial_coach/features/settings/presentation/international_preferences_screen.dart';
import 'package:ai_financial_coach/features/settings/presentation/settings_screen.dart';
import 'package:ai_financial_coach/l10n/generated/app_localizations.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// International / Localization Foundation Checkpoint 4.3, extended by
// Checkpoint 6.8 (Localization Phase 1).
//
// CP4.3 covered exactly one localized string: the "International
// preferences" row's own `title`. CP6.8 finished the rest of the
// screen's static chrome (AppBar title, nav-row labels, profile summary
// line, error message, Beta 0 disclaimer) -- see the
// 'CP6.8 Japanese localization' group below for that coverage.
//
// Reuses the same seeding / router / disposal patterns already
// established (and separately verified) in
// `test/widget/international_preferences_screen_test.dart`, kept minimal
// here since this file only needs to reach `SettingsScreen` itself --
// none of that file's dropdown-interaction helpers are needed. CP6.8
// adds one extra marker route (`AppRoutes.accounts`) to this same shared
// router harness, used only by the new navigation-row test.
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
        GoRoute(
          path: AppRoutes.internationalPreferences,
          builder: (context, state) => const InternationalPreferencesScreen(),
        ),
        // A minimal marker screen -- CP6.8's navigation-row test only needs
        // to prove the tap reaches the real `AppRoutes.accounts` path, not
        // to exercise the real `AccountsScreen` and its own dependencies.
        GoRoute(
          path: AppRoutes.accounts,
          builder: (context, state) => const Scaffold(body: Text('ACCOUNTS_SCREEN_MARKER')),
        ),
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

  testWidgets('English locale renders the International preferences row label', (tester) async {
    final (AppDatabase db, String profileId) = await seededDb();
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithRouter(container));
    await tester.pumpAndSettle();

    expect(find.text('International preferences'), findsOneWidget);
  });

  testWidgets('Japanese locale renders the International preferences row label', (tester) async {
    final (AppDatabase db, String profileId) = await seededDb();
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithRouter(container, locale: const Locale('ja')));
    await tester.pumpAndSettle();

    expect(find.text('言語・地域設定'), findsOneWidget);
  });

  testWidgets('tapping the International preferences row navigates to that screen', (tester) async {
    final (AppDatabase db, String profileId) = await seededDb();
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithRouter(container));
    await tester.pumpAndSettle();

    await tester.tap(find.text('International preferences'));
    await tester.pumpAndSettle();

    expect(find.byType(InternationalPreferencesScreen), findsOneWidget);
  });

  group('CP6.8 Japanese localization', () {
    testWidgets(
        'CP6.8 (A): the Profile screen renders in Japanese -- AppBar title, every nav-row '
        'label, and the Beta 0 disclaimer', (tester) async {
      final (AppDatabase db, String profileId) = await seededDb();
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container, locale: const Locale('ja')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      expect(find.text('プロフィール'), findsOneWidget); // navProfile (AppBar title)
      expect(find.text('口座'), findsOneWidget); // accountsSectionTitle
      expect(find.text('カテゴリ'), findsOneWidget); // categoriesScreenTitle
      expect(find.text('予算'), findsOneWidget); // budgetsTitle
      expect(find.text('貯蓄目標'), findsOneWidget); // savingsGoalsTitle
      expect(find.text('定期'), findsOneWidget); // recurringTitle
      expect(find.text('言語・地域設定'), findsOneWidget); // internationalPreferences
      expect(
        find.text(
          'ベータ0 — ローカルの家計管理エンジンです。外貨換算（FX）、レシート、通知、'
          'クラウド同期、AIコーチングはまだ実装されていません。',
        ),
        findsOneWidget,
      ); // beta0DisclaimerMessage
      // profileLocationSummary -- Japanese sentence template, raw codes untranslated.
      expect(find.text('現在の国: JP（JPY）・母国: LK（LKR）'), findsOneWidget);
    });

    testWidgets('CP6.8 (B): tapping the localized Accounts row under the Japanese locale still '
        'navigates to AppRoutes.accounts', (tester) async {
      final (AppDatabase db, String profileId) = await seededDb();
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container, locale: const Locale('ja')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('口座')); // accountsSectionTitle
      await tester.pumpAndSettle();

      expect(find.text('ACCOUNTS_SCREEN_MARKER'), findsOneWidget);
    });

    testWidgets(
        'CP6.8 (C): a Japanese-language display name renders exactly as entered, alongside the '
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
        'CP6.8 (D): the Profile screen renders without overflow under the Japanese locale at a '
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
        'CP6.8 (E): the Profile screen renders without overflow under the Japanese locale at an '
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
        'CP6.8 (F): a long Japanese display name is still represented in full by its Text widget '
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
}
