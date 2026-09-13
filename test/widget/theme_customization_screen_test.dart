import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/providers.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/features/settings/presentation/theme_customization_screen.dart';
import 'package:ai_financial_coach/l10n/generated/app_localizations.dart';
import 'package:ai_financial_coach/shared/theme/app_theme.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Checkpoint 8.1 (Premium Theme Personalization Foundation), Phase 5:
// ThemeCustomizationScreen's own widget tests. Follows the same
// seeding/container/disposal pattern established across every other
// screen test in this repo (see settings_screen_test.dart /
// international_preferences_screen_test.dart).
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

  /// The `Semantics` widget for one swatch. Each `_ThemeSwatchCard` is
  /// keyed on its own root widget (`themeSwatch_<storageValue>`) --
  /// `find.byKey` alone resolves to that root, not the `Semantics`
  /// descendant it builds internally, so this walks down to the actual
  /// `Semantics` widget whose `selected`/`button` properties this file
  /// asserts on.
  Finder swatchSemantics(String storageValue) {
    return find
        .descendant(
          of: find.byKey(Key('themeSwatch_$storageValue')),
          matching: find.byType(Semantics),
        )
        .first;
  }

  Widget buildScreen(ProviderContainer container, {Locale locale = const Locale('en')}) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ThemeCustomizationScreen(),
      ),
    );
  }

  testWidgets('renders all 5 preset themes with their localized display names', (tester) async {
    final (AppDatabase db, String profileId) = await seededDb();
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(buildScreen(container));
    await tester.pumpAndSettle();

    expect(find.text('Theme Customization'), findsOneWidget); // AppBar title
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('Pink'), findsOneWidget);
    expect(find.text('Ocean'), findsOneWidget);
    expect(find.text('Forest'), findsOneWidget);
  });

  testWidgets('Light is selected by default for a freshly-created profile', (tester) async {
    final (AppDatabase db, String profileId) = await seededDb();
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(buildScreen(container));
    await tester.pumpAndSettle();

    final Semantics semantics = tester.widget<Semantics>(swatchSemantics('light'));
    expect(semantics.properties.selected, isTrue);

    final Semantics darkSemantics = tester.widget<Semantics>(swatchSemantics('dark'));
    expect(darkSemantics.properties.selected, isFalse);
  });

  testWidgets(
    'the selected state is identifiable without color alone -- it is exposed via '
    'Semantics.selected regardless of any visual styling',
    (tester) async {
      final (AppDatabase db, String profileId) = await seededDb();
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(buildScreen(container));
      await tester.pumpAndSettle();

      for (final String storageValue in <String>['light', 'dark', 'pink', 'ocean', 'forest']) {
        final Semantics semantics = tester.widget<Semantics>(swatchSemantics(storageValue));
        expect(semantics.properties.button, isTrue);
        expect(semantics.properties.selected, storageValue == 'light');
      }
    },
  );

  testWidgets('tapping a theme swatch persists the selection and updates the selected state '
      'immediately -- no restart, no Save button', (tester) async {
    final (AppDatabase db, String profileId) = await seededDb();
    final ProfileRepository profileRepo = ProfileRepository(db);
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(buildScreen(container));
    await tester.pumpAndSettle();

    // No explicit Save affordance anywhere on this screen.
    expect(find.widgetWithText(FilledButton, 'Save'), findsNothing);
    expect(find.text('Save'), findsNothing);

    await tester.tap(find.byKey(const Key('themeSwatch_forest')));
    await tester.pumpAndSettle();

    final ProfileRow? profile = await profileRepo.getProfile();
    expect(profile!.themePreference, 'forest');

    final Semantics forestSemantics = tester.widget<Semantics>(swatchSemantics('forest'));
    expect(forestSemantics.properties.selected, isTrue);
    final Semantics lightSemantics = tester.widget<Semantics>(swatchSemantics('light'));
    expect(lightSemantics.properties.selected, isFalse);
  });

  testWidgets('renders in Japanese with localized theme names and title/subtitle', (tester) async {
    final (AppDatabase db, String profileId) = await seededDb();
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(buildScreen(container, locale: const Locale('ja')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('テーマのカスタマイズ'), findsOneWidget); // themeCustomizationTitle
    expect(find.text('プリセットテーマ'), findsOneWidget); // presetThemesSectionTitle
    expect(find.text('ライト'), findsOneWidget); // themeStyleLight
    expect(find.text('フォレスト'), findsOneWidget); // themeStyleForest
  });

  testWidgets('renders without overflow at a narrow 320px width', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1.0;

    final (AppDatabase db, String profileId) = await seededDb();
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(buildScreen(container));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Light'), findsOneWidget);
  });

  testWidgets('renders without overflow under the Japanese locale at a 1.6x text scale',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final (AppDatabase db, String profileId) = await seededDb();
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(buildScreen(container, locale: const Locale('ja')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('テーマのカスタマイズ'), findsOneWidget);
  });
}
