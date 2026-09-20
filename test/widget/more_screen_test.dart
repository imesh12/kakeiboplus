import 'package:ai_financial_coach/core/routing/app_routes.dart';
import 'package:ai_financial_coach/features/settings/presentation/more_screen.dart';
import 'package:ai_financial_coach/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// V1 Navigation Shell Implementation Checkpoint
/// (`docs/22_UI_REFERENCE_PRODUCT_ARCHITECTURE.md` §26 / ADR-034):
/// coverage for the new `MoreScreen`, which now owns every nav row (and
/// the Beta 0 disclaimer) that used to live directly on `SettingsScreen`
/// -- see that screen's own trimmed `settings_screen_test.dart` for
/// confirmation nothing was duplicated there. Each row is proven the
/// same way this repo's existing nav-row tests already do: a minimal
/// marker screen at the real `AppRoutes.*` path, proving the tap reaches
/// the correct route without re-exercising that destination's own
/// dependencies (its own test file already does that).

/// `MoreScreen`'s body is a real (non-`shrinkWrap`) `ListView`, so at the
/// default 800x600 widget-test surface, sections/rows below the fold
/// (Personalization, Cloud & Security) are not mounted into the element
/// tree at all -- `find.text(...)` on them resolves to zero widgets, and
/// `tester.tap(...)` on zero widgets throws ("Bad state: No element"),
/// exactly like a real user who hasn't scrolled there yet. This drags the
/// screen's own `Scrollable` in small steps, re-evaluating [finder] after
/// each step, until it is built, then settles it fully into view --
/// mirroring real scrolling rather than inflating the test surface.
/// Every call site below scrolls strictly forward, in the same top-to-
/// bottom order `MoreScreen` renders its sections, so this never needs to
/// scroll back up.
Future<void> scrollUntilFound(WidgetTester tester, Finder finder) {
  return tester.scrollUntilVisible(finder, 300.0);
}

/// The `Scrollable` that belongs to `MoreScreen` itself (its own
/// top-level `ListView`), scoped by ancestor so this can never
/// accidentally drag some other Scrollable that happens to also be in
/// the tree.
Finder _moreScreenScrollable() {
  return find.descendant(of: find.byType(MoreScreen), matching: find.byType(Scrollable));
}

/// A tap-safe alternative to [scrollUntilFound] for rows that are about
/// to be tapped rather than merely asserted present.
///
/// [scrollUntilFound] (via `tester.scrollUntilVisible`) stops looping the
/// instant [finder] is non-empty -- i.e. as soon as the lazy `ListView`
/// has mounted it within its build/cache extent -- but that is not the
/// same as being inside the test surface's actual hittable viewport: on
/// Windows, the Profile/International preferences/Appearance/Japanese
/// Profile rows were each mounted (found by the finder) while still
/// rendered below y=600 on the default 800x600 surface, so the
/// subsequent `tester.tap` silently missed. This helper scrolls
/// `MoreScreen`'s own `ListView` downward in small bounded steps until
/// [finder] resolves to at least one element, then finishes with
/// `tester.ensureVisible(finder)` so the match is brought fully inside
/// the hittable viewport -- not merely mounted -- before the caller taps
/// it. Bounded at [maxScrolls] attempts (never an infinite loop), with a
/// clear failure message if the target never appears.
///
/// [finder] must resolve to EXACTLY one match once found, and must NOT
/// already end in `.first`/`.at(...)` if its underlying match count
/// could currently be zero: `Finder.first` calls `.evaluate().first` on
/// its parent eagerly, which throws `StateError` ("Bad state: No
/// element") the instant the parent has zero matches, rather than
/// reporting "not found yet, keep scrolling" -- this is exactly what
/// made the Cloud Account tap test throw instead of scrolling further.
/// Disambiguate to a unique match BEFORE calling this (e.g.
/// `find.descendant(of: find.byType(ListTile), matching:
/// find.text(label))`, which every row below is already unique via,
/// since no row label collides with its own non-`ListTile` section
/// header) rather than appending `.first` after the fact.
Future<void> scrollMoreScreenUntilVisible(
  WidgetTester tester,
  Finder finder, {
  int maxScrolls = 30,
}) async {
  final Finder scrollable = _moreScreenScrollable();
  for (int i = 0; i < maxScrolls && finder.evaluate().isEmpty; i++) {
    await tester.drag(scrollable, const Offset(0, -200));
    await tester.pump();
  }
  if (finder.evaluate().isEmpty) {
    fail(
      'Target was not found in MoreScreen after $maxScrolls bounded scroll '
      'attempts: $finder',
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

void main() {
  Widget appWithRouter({Locale locale = const Locale('en')}) {
    final GoRouter router = GoRouter(
      initialLocation: AppRoutes.more,
      routes: <RouteBase>[
        GoRoute(path: AppRoutes.more, builder: (context, state) => const MoreScreen()),
        GoRoute(
          path: AppRoutes.budgets,
          builder: (context, state) => const Scaffold(body: Text('BUDGETS_MARKER')),
        ),
        GoRoute(
          path: AppRoutes.goals,
          builder: (context, state) => const Scaffold(body: Text('GOALS_MARKER')),
        ),
        GoRoute(
          path: AppRoutes.recurring,
          builder: (context, state) => const Scaffold(body: Text('RECURRING_MARKER')),
        ),
        GoRoute(
          path: AppRoutes.currencyConverter,
          builder: (context, state) => const Scaffold(body: Text('CURRENCY_CONVERTER_MARKER')),
        ),
        GoRoute(
          path: AppRoutes.categories,
          builder: (context, state) => const Scaffold(body: Text('CATEGORIES_MARKER')),
        ),
        GoRoute(
          path: AppRoutes.profile,
          builder: (context, state) => const Scaffold(body: Text('PROFILE_MARKER')),
        ),
        GoRoute(
          path: AppRoutes.internationalPreferences,
          builder: (context, state) => const Scaffold(body: Text('INTERNATIONAL_PREFS_MARKER')),
        ),
        GoRoute(
          path: AppRoutes.themeCustomization,
          builder: (context, state) => const Scaffold(body: Text('APPEARANCE_MARKER')),
        ),
        GoRoute(
          path: AppRoutes.cloudAccount,
          builder: (context, state) => const Scaffold(body: Text('CLOUD_ACCOUNT_MARKER')),
        ),
      ],
    );
    return MaterialApp.router(
      routerConfig: router,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }

  group('actionable rows -- English', () {
    testWidgets('renders the AppBar title, subtitle, and every actionable section header', (
      tester,
    ) async {
      await tester.pumpWidget(appWithRouter());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // AppBar title/subtitle sit above the scrollable body -- always
      // mounted, never scrolled.
      expect(find.text('More'), findsOneWidget); // navMore (AppBar title)
      expect(
        find.text('Manage your money tools and preferences'),
        findsOneWidget,
      ); // moreScreenSubtitle

      // Every section header below is verified while scrolling through
      // the real screen, top to bottom, exactly as a user would --
      // headers past the fold (Personalization, Cloud & Security) are
      // not mounted until scrolled into view. See scrollUntilFound.
      await scrollUntilFound(tester, find.text('Planning'));
      expect(find.text('Planning'), findsOneWidget);

      await scrollUntilFound(tester, find.text('Recurring').first);
      // The group header and its single row both literally render 'Recurring'.
      expect(find.text('Recurring'), findsNWidgets(2));

      await scrollUntilFound(tester, find.text('Money Tools'));
      expect(find.text('Money Tools'), findsOneWidget);

      await scrollUntilFound(tester, find.text('Organization'));
      expect(find.text('Organization'), findsOneWidget);

      await scrollUntilFound(tester, find.text('Personalization'));
      expect(find.text('Personalization'), findsOneWidget);

      await scrollUntilFound(tester, find.text('Cloud & Security'));
      expect(find.text('Cloud & Security'), findsOneWidget);
    });

    testWidgets('renders every reused row label exactly once', (tester) async {
      await tester.pumpWidget(appWithRouter());
      await tester.pumpAndSettle();

      // Scrolled through top to bottom, in the same order the screen
      // renders them -- rows past the fold are not mounted until
      // scrolled into view. See scrollUntilFound.
      for (final String label in <String>[
        'Budgets',
        'Savings Goals',
        'Currency Converter',
        'Categories',
        'Profile',
        'International preferences',
        'Appearance',
        'Cloud Account',
      ]) {
        await scrollUntilFound(tester, find.text(label));
        expect(find.text(label), findsOneWidget);
      }
    });

    for (final (String label, String marker) in <(String, String)>[
      ('Budgets', 'BUDGETS_MARKER'),
      ('Savings Goals', 'GOALS_MARKER'),
      ('Recurring', 'RECURRING_MARKER'),
      ('Currency Converter', 'CURRENCY_CONVERTER_MARKER'),
      ('Categories', 'CATEGORIES_MARKER'),
      ('Profile', 'PROFILE_MARKER'),
      ('International preferences', 'INTERNATIONAL_PREFS_MARKER'),
      ('Appearance', 'APPEARANCE_MARKER'),
      ('Cloud Account', 'CLOUD_ACCOUNT_MARKER'),
    ]) {
      testWidgets('tapping "$label" navigates to its real route (marker: $marker)', (tester) async {
        await tester.pumpWidget(appWithRouter());
        await tester.pumpAndSettle();

        // "Recurring" is both a section header and its own single row --
        // the row's `Text` is found via the more specific `ListTile`
        // ancestor (no `.first` needed: the header lives outside any
        // `ListTile`, so this is already unique) so this doesn't
        // accidentally match the non-interactive `AppSectionHeader` text
        // above it.
        final Finder rowText = find.descendant(
          of: find.byType(ListTile),
          matching: find.text(label),
        );
        // Tap the row's own `ListTile` ancestor -- its whole area is
        // hittable via its internal `InkWell`, which is more robust than
        // relying on the exact center of its `Text` child.
        final Finder rowTile = find.ancestor(of: rowText, matching: find.byType(ListTile));
        // Rows past the fold (Personalization, Cloud & Security) are not
        // mounted, or not yet inside the hittable viewport, at the
        // default test surface -- see scrollMoreScreenUntilVisible.
        await scrollMoreScreenUntilVisible(tester, rowText);
        await tester.tap(rowTile);
        await tester.pumpAndSettle();

        expect(find.text(marker), findsOneWidget);
      });
    }

    testWidgets('renders the Beta 0 disclaimer, moved here from Profile', (tester) async {
      await tester.pumpWidget(appWithRouter());
      await tester.pumpAndSettle();

      final Finder disclaimer = find.textContaining('Multi-currency tracking');
      await tester.scrollUntilVisible(disclaimer, 300.0);
      await tester.pumpAndSettle();
      expect(disclaimer, findsOneWidget);
    });
  });

  group('no dead links', () {
    testWidgets(
      'omits every canonical More destination that has no real V1 screen/route '
      '(Insights, Exchange Rates, Notifications, Sync, Security, Privacy & Data, About), '
      'and omits Accounts (now a primary tab, not a More row)',
      (tester) async {
        await tester.pumpWidget(appWithRouter());
        await tester.pumpAndSettle();

        expect(find.text('Insights'), findsNothing);
        expect(find.text('Exchange Rates'), findsNothing);
        expect(find.text('Notifications'), findsNothing);
        expect(find.text('Sync'), findsNothing);
        expect(find.text('Security'), findsNothing);
        expect(find.text('Privacy & Data'), findsNothing);
        expect(find.text('About'), findsNothing);
        expect(find.text('Accounts'), findsNothing);
        // Exactly one row per Recurring group (no separate "Recurring
        // Transactions"/"Subscriptions" rows -- both live inside the one
        // existing Recurring screen; see class doc comment).
        expect(find.widgetWithText(ListTile, 'Recurring'), findsOneWidget);
        expect(find.text('Subscriptions'), findsNothing);
        expect(find.text('Recurring Transactions'), findsNothing);
      },
    );
  });

  group('Japanese locale', () {
    testWidgets('renders every section header and row label in Japanese', (tester) async {
      await tester.pumpWidget(appWithRouter(locale: const Locale('ja')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // AppBar title/subtitle sit above the scrollable body -- always
      // mounted, never scrolled.
      expect(find.text('その他'), findsOneWidget); // navMore (AppBar title)
      expect(find.text('お金の管理ツールと設定'), findsOneWidget); // moreScreenSubtitle

      // Scrolled through top to bottom, in the same order the screen
      // renders them -- headers/rows past the fold are not mounted until
      // scrolled into view. See scrollUntilFound.
      await scrollUntilFound(tester, find.text('プランニング'));
      expect(find.text('プランニング'), findsOneWidget);
      expect(find.text('予算'), findsOneWidget); // budgetsTitle
      expect(find.text('貯蓄目標'), findsOneWidget); // savingsGoalsTitle

      await scrollUntilFound(tester, find.text('定期').first);
      // recurringTitle -- the group header and its single row both render this text.
      expect(find.text('定期'), findsNWidgets(2));

      await scrollUntilFound(tester, find.text('マネーツール'));
      expect(find.text('マネーツール'), findsOneWidget);
      expect(find.text('通貨換算'), findsOneWidget); // currencyConverterTitle

      await scrollUntilFound(tester, find.text('整理'));
      expect(find.text('整理'), findsOneWidget);
      expect(find.text('カテゴリ'), findsOneWidget); // categoriesScreenTitle

      await scrollUntilFound(tester, find.text('個人設定'));
      expect(find.text('個人設定'), findsOneWidget);
      expect(find.text('プロフィール'), findsOneWidget); // navProfile

      await scrollUntilFound(tester, find.text('言語・地域設定'));
      expect(find.text('言語・地域設定'), findsOneWidget); // internationalPreferences

      await scrollUntilFound(tester, find.text('外観'));
      expect(find.text('外観'), findsOneWidget); // appearanceSectionTitle

      await scrollUntilFound(tester, find.text('クラウドとセキュリティ'));
      expect(find.text('クラウドとセキュリティ'), findsOneWidget);
      expect(find.text('クラウドアカウント'), findsOneWidget); // cloudAccountSectionTitle
    });

    testWidgets('tapping the localized Profile row still navigates to AppRoutes.profile', (
      tester,
    ) async {
      await tester.pumpWidget(appWithRouter(locale: const Locale('ja')));
      await tester.pumpAndSettle();

      // Same fold as the English Profile row -- see
      // scrollMoreScreenUntilVisible. Tap the row's own `ListTile`
      // ancestor, same as the English tap-loop tests above, rather than
      // the `Text` itself.
      final Finder profileText = find.text('プロフィール');
      final Finder profileTile = find.ancestor(
        of: profileText,
        matching: find.byType(ListTile),
      );
      await scrollMoreScreenUntilVisible(tester, profileText);
      await tester.tap(profileTile);
      await tester.pumpAndSettle();

      expect(find.text('PROFILE_MARKER'), findsOneWidget);
    });
  });

  group('narrow width and large text', () {
    testWidgets('renders without overflow at a narrow 320px width and 1.6x text scale', (
      tester,
    ) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(appWithRouter());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('More'), findsOneWidget);
    });

    testWidgets('renders without overflow at an extreme 2.0x text scale', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(appWithRouter());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('More'), findsOneWidget);
    });

    testWidgets(
      'renders without overflow under Japanese at a narrow 320px width and 2.0x text scale',
      (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1.0;
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await tester.pumpWidget(appWithRouter(locale: const Locale('ja')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('その他'), findsOneWidget);
      },
    );
  });
}
