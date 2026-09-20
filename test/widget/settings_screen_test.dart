import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/providers.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/routing/app_routes.dart';
import 'package:ai_financial_coach/features/settings/presentation/international_preferences_screen.dart';
import 'package:ai_financial_coach/features/settings/presentation/settings_screen.dart';
import 'package:ai_financial_coach/features/settings/presentation/theme_customization_screen.dart';
import 'package:ai_financial_coach/l10n/generated/app_localizations.dart';
import 'package:ai_financial_coach/shared/theme/app_tokens.dart';
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
        GoRoute(
          path: AppRoutes.themeCustomization,
          builder: (context, state) => const ThemeCustomizationScreen(),
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

  // ---------------------------------------------------------------------
  // Visual System Convergence Checkpoint 7.6: locks in each Profile/
  // Settings row's new bordered-card visual treatment (`AppCard(bordered:
  // true)`) via the same shape/side/color contract `app_card_test.dart`/
  // `accounts_screen_test.dart` already assert for `AppCard` -- never a
  // pixel value. This file has no `find.byType(ListTile)`/`find.byType
  // (Card)`/`find.byType(Divider)` assertions elsewhere, so wrapping each
  // row is unconstrained by any prior structural test here; this is the
  // first such assertion for this screen.
  // ---------------------------------------------------------------------
  testWidgets(
    'CP7.6: the International preferences row renders inside a bordered, near-white card '
    'matching the converged visual system, and still navigates on tap',
    (tester) async {
      final (AppDatabase db, String profileId) = await seededDb();
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container));
      await tester.pumpAndSettle();

      final Finder rowLabel = find.text('International preferences');
      final Card cardWidget = tester.widget<Card>(
        find.ancestor(of: rowLabel, matching: find.byType(Card)).first,
      );
      final BuildContext context = tester.element(rowLabel);
      final ColorScheme colors = Theme.of(context).colorScheme;
      final AppTokens tokens = context.appTokens;

      expect(cardWidget.color, colors.surface);
      expect(cardWidget.elevation, 0);
      final RoundedRectangleBorder shape = cardWidget.shape! as RoundedRectangleBorder;
      expect(shape.side.color, tokens.colors.subtleBorder);

      await tester.tap(rowLabel);
      await tester.pumpAndSettle();

      expect(find.byType(InternationalPreferencesScreen), findsOneWidget);
    },
  );

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
      // profileLocationSummary -- Japanese sentence template, raw codes
      // untranslated. Asserted here, before the scroll below, since it
      // lives on the top-of-list profile card.
      expect(find.text('現在の国: JP（JPY）・母国: LK（LKR）'), findsOneWidget);
      expect(find.text('口座'), findsOneWidget); // accountsSectionTitle
      expect(find.text('カテゴリ'), findsOneWidget); // categoriesScreenTitle
      expect(find.text('予算'), findsOneWidget); // budgetsTitle
      expect(find.text('貯蓄目標'), findsOneWidget); // savingsGoalsTitle
      expect(find.text('定期'), findsOneWidget); // recurringTitle
      expect(find.text('言語・地域設定'), findsOneWidget); // internationalPreferences

      // CP8.1 verification fix: the new "Appearance" row (CP8.1) pushed
      // the Beta 0 disclaimer -- the ListView's last child -- far enough
      // down that it is no longer built into the Element tree at the
      // default test-surface size; this is a lazy-sliver realization gap,
      // not a changed/missing widget (`settings_screen.dart`'s disclaimer
      // code and `app_ja.arb`'s localized string are both unchanged).
      // Scroll it into view using this repo's own established pattern
      // (see `add_transaction_screen_test.dart` / `home_screen_test.dart`)
      // rather than weakening or deleting this assertion.
      // Checkpoint 10 Visual Convergence Pass: the disclaimer copy was
      // corrected -- FX and recurring reminders are implemented today, so
      // the old "not implemented yet" claim about them was stale (see
      // `app_ja.arb`'s updated `beta0DisclaimerMessage`). This asserts
      // the new, accurate string with the same rigor the old one had --
      // an exact match, not a weakened `textContaining`.
      final Finder disclaimer = find.text(
        '複数通貨の管理、参考為替レート、繰り返しのリマインダーは今すぐご利用いただけます。'
        'レシート読み取り、クラウド同期、AIコーチングは今後のアップデートで追加予定です。',
      );
      await tester.scrollUntilVisible(disclaimer, 300.0);
      await tester.pumpAndSettle();
      expect(disclaimer, findsOneWidget); // beta0DisclaimerMessage
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

  group('CP8.1 Appearance row (Premium Theme Personalization Foundation)', () {
    testWidgets(
      'the Appearance row renders inside a bordered card matching the converged visual system, '
      'and navigates to Theme Customization on tap',
      (tester) async {
        final (AppDatabase db, String profileId) = await seededDb();
        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRouter(container));
        await tester.pumpAndSettle();

        final Finder rowLabel = find.text('Appearance');
        expect(rowLabel, findsOneWidget);

        final Card cardWidget = tester.widget<Card>(
          find.ancestor(of: rowLabel, matching: find.byType(Card)).first,
        );
        final BuildContext context = tester.element(rowLabel);
        final ColorScheme colors = Theme.of(context).colorScheme;
        final AppTokens tokens = context.appTokens;
        expect(cardWidget.color, colors.surface);
        expect(cardWidget.elevation, 0);
        final RoundedRectangleBorder shape = cardWidget.shape! as RoundedRectangleBorder;
        expect(shape.side.color, tokens.colors.subtleBorder);

        await tester.tap(rowLabel);
        await tester.pumpAndSettle();

        expect(find.byType(ThemeCustomizationScreen), findsOneWidget);
      },
    );

    testWidgets('the Appearance row renders in Japanese', (tester) async {
      final (AppDatabase db, String profileId) = await seededDb();
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container, locale: const Locale('ja')));
      await tester.pumpAndSettle();

      expect(find.text('外観'), findsOneWidget); // appearanceSectionTitle
    });
  });
}
