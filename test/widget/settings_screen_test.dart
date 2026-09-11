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

// International / Localization Foundation Checkpoint 4.3.
//
// `SettingsScreen` has exactly one localized string in this checkpoint's
// locked scope: the "International preferences" row's own `title`. This
// file verifies that string actually renders through
// `AppLocalizations.of(context)` in both supported locales, and that
// tapping the row still navigates correctly with localization delegates
// wired into the test harness.
//
// Reuses the same seeding / router / disposal patterns already
// established (and separately verified) in
// `test/widget/international_preferences_screen_test.dart`, kept minimal
// here since this file only needs to reach `SettingsScreen` itself --
// none of that file's dropdown-interaction helpers are needed.
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
}
