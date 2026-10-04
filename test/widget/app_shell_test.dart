import 'package:ai_financial_coach/l10n/generated/app_localizations.dart';
import 'package:ai_financial_coach/shared/theme/app_theme.dart';
import 'package:ai_financial_coach/shared/theme/app_tokens.dart';
import 'package:ai_financial_coach/shared/widgets/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import '../support/rtl_harness.dart';

/// Release-gate-adjacent widget test: "Navigation shell renders exactly
/// the five V1 destinations" (Home / Activity / Add / Accounts / More)
/// and the Add sheet opens with only Expense / Income / Transfer
/// enabled -- see `docs/22_UI_REFERENCE_PRODUCT_ARCHITECTURE.md` §26 and
/// `docs/14_DECISION_LOG.md` ADR-034 (V1 Navigation Shell Implementation
/// Checkpoint). This supersedes the Beta 0 shell this same file proved
/// before this checkpoint (Home / Activity / Add / Profile -- ADR-015 /
/// Decision 12): Accounts is promoted to a primary destination and
/// Profile is replaced by More in the bottom nav (Profile itself is NOT
/// removed from the app -- see `more_screen_test.dart` for coverage that
/// it stays reachable from a More row). Uses a small standalone
/// [GoRouter] rather than the full [routerProvider] to keep this test
/// independent of database setup.
void main() {
  // `{bool rtl = false}` threads an RTL `Directionality` through
  // `MaterialApp.router`'s own `builder:` -- see
  // `test/support/rtl_harness.dart` for why that's the only place it can
  // be injected. `AppShell` reads `AppLocalizations.of(context)` for its
  // five destination labels, so every test app must wire
  // `AppLocalizations.localizationsDelegates`/`supportedLocales`, exactly
  // like `international_preferences_screen_test.dart` already does for
  // its own MaterialApp. `{Locale locale = const Locale('en')}` keeps
  // every pre-existing call site passing (English is still the default),
  // while the Japanese-proof tests pass `locale: const Locale('ja')`.
  Widget buildApp({bool rtl = false, Locale locale = const Locale('en'), ThemeData? theme}) {
    final GoRouter router = GoRouter(
      initialLocation: '/home',
      routes: <RouteBase>[
        ShellRoute(
          builder: (context, state, child) => AppShell(child: child),
          routes: <RouteBase>[
            GoRoute(path: '/home', builder: (context, state) => const Text('Home body')),
            GoRoute(path: '/activity', builder: (context, state) => const Text('Activity body')),
            GoRoute(path: '/accounts', builder: (context, state) => const Text('Accounts body')),
            GoRoute(path: '/more', builder: (context, state) => const Text('More body')),
          ],
        ),
      ],
    );
    return MaterialApp.router(
      routerConfig: router,
      theme: theme,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: rtl ? rtlAppBuilder : null,
    );
  }

  testWidgets('shows exactly Home, Activity, Add, Accounts, and More -- no Profile tab',
      (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.widgetWithText(NavigationDestination, 'Home'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Activity'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Add'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Accounts'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'More'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Profile'), findsNothing);
    expect(find.widgetWithText(NavigationDestination, 'Goals'), findsNothing);
    expect(find.byType(NavigationDestination), findsNWidgets(5));
  });

  testWidgets('tapping Activity navigates to the Activity screen', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(NavigationDestination, 'Activity'));
    await tester.pumpAndSettle();

    expect(find.text('Activity body'), findsOneWidget);
  });

  testWidgets('tapping Accounts navigates to the Accounts screen and selects index 3',
      (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(NavigationDestination, 'Accounts'));
    await tester.pumpAndSettle();

    expect(find.text('Accounts body'), findsOneWidget);
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 3);
  });

  testWidgets('tapping More navigates to the More screen and selects index 4', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(NavigationDestination, 'More'));
    await tester.pumpAndSettle();

    expect(find.text('More body'), findsOneWidget);
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 4);
  });

  testWidgets('the Add destination opens a sheet with Expense/Income/Transfer '
      'and no Receipt or Goal Contribution option', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(NavigationDestination, 'Add'));
    await tester.pumpAndSettle();

    expect(find.text('Expense'), findsOneWidget);
    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Transfer'), findsOneWidget);
    expect(find.text('Receipt'), findsNothing);
    expect(find.text('Goal Contribution'), findsNothing);
  });

  // -- Add stays NavigationDestination index 2 and stays an ACTION -- these
  // tests prove _currentIndex still never reports 2 for Add, and that
  // opening/dismissing the sheet never disturbs whichever tab was
  // actually selected.

  testWidgets('Home maps to NavigationBar selectedIndex 0', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 0);
  });

  testWidgets(
      'Add remains an action: tapping it from Home opens the existing sheet with '
      'Expense/Income/Transfer, and the shell selection does not change', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 0);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Add'));
    // The modal sheet's own entrance animation -- not a workaround for
    // broken state, the same settle every other sheet-opening test here
    // already relies on.
    await tester.pumpAndSettle();

    expect(find.text('Expense'), findsOneWidget);
    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Transfer'), findsOneWidget);
    // The sheet is modal, layered above the shell -- the underlying
    // NavigationBar is still mounted, unchanged, proving Add never became
    // the "current" destination and no route was ever pushed for it.
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 0);
  });

  testWidgets(
      'from Accounts, tapping Add opens the sheet and Accounts remains '
      'NavigationBar selectedIndex 3', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(NavigationDestination, 'Accounts'));
    await tester.pumpAndSettle();
    expect(find.text('Accounts body'), findsOneWidget);
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 3);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Add'));
    await tester.pumpAndSettle();

    expect(find.text('Expense'), findsOneWidget);
    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Transfer'), findsOneWidget);
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 3);
  });

  testWidgets(
      'the Add icon renders inside a raised, solid-color circular Material '
      'sized/colored per ColorScheme, and no other destination gets that treatment',
      (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    final ColorScheme colors = Theme.of(tester.element(find.byType(NavigationBar))).colorScheme;

    // On Home, Add is unselected, so it's rendering its `icon:` (not
    // `selectedIcon:`) -- add_circle_outline, per the approved spec.
    final Icon addIcon = tester.widget<Icon>(find.byIcon(Icons.add_circle_outline));
    expect(addIcon.size, 30);
    expect(addIcon.color, colors.onPrimary);

    bool isAddCircle(Widget w) =>
        w is Material &&
        w.color == colors.primary &&
        w.shape is CircleBorder &&
        w.elevation > 0;

    // Exactly one raised, solid-primary-colored circular Material exists
    // on the whole bar, and it's the Add icon's own ancestor -- proving
    // Home/Activity/Accounts/More's plain Icons were never given the
    // same treatment.
    final Finder addCircle = find.byWidgetPredicate(isAddCircle);
    expect(addCircle, findsOneWidget);
    expect(
      find.ancestor(of: find.byIcon(Icons.add_circle_outline), matching: addCircle),
      findsOneWidget,
    );

    expect(
      find.ancestor(of: addCircle, matching: find.byType(Transform)),
      findsWidgets,
    );
  });

  testWidgets(
      'shell renders all five destinations with correct labels and no '
      'exceptions/overflow at normal (1.0x) text scale', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.widgetWithText(NavigationDestination, 'Home'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Activity'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Add'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Accounts'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'More'), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(5));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'all five destinations remain represented with labels visible and '
      'no overflow/render exceptions at 1.6x text scale', (tester) async {
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.widgetWithText(NavigationDestination, 'Home'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Activity'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Add'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Accounts'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'More'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'all five destinations remain represented and tappable, and '
      'switching destinations still works, at 2.0x text scale', (tester) async {
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Activity'));
    await tester.pumpAndSettle();
    expect(find.text('Activity body'), findsOneWidget);
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 1);
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(NavigationDestination, 'More'));
    await tester.pumpAndSettle();
    expect(find.text('More body'), findsOneWidget);
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 4);
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Home'));
    await tester.pumpAndSettle();
    expect(find.text('Home body'), findsOneWidget);
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'the Add action still opens the transaction sheet at 2.0x text scale '
      'without disturbing the selected destination', (tester) async {
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(NavigationDestination, 'Add'));
    await tester.pumpAndSettle();

    expect(find.text('Expense'), findsOneWidget);
    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Transfer'), findsOneWidget);
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'a narrow 320px width combined with 1.6x text scale keeps all '
      'destinations usable with no overflow', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.widgetWithText(NavigationDestination, 'Home'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Activity'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Add'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Accounts'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'More'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Activity'));
    await tester.pumpAndSettle();
    expect(find.text('Activity body'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'a narrow 320px width combined with 2.0x text scale keeps all '
      'destinations usable and tappable with no overflow', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.widgetWithText(NavigationDestination, 'Home'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Activity'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Add'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Accounts'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'More'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Add'));
    await tester.pumpAndSettle();
    expect(find.text('Expense'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'destinations remain discoverable via semantics at 2.0x text scale',
      (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    // NOT addTearDown(handle.dispose): `TestWidgetsFlutterBinding`
    // verifies every `SemanticsHandle` is disposed inside
    // `_endOfTestVerifications`, which runs before this test's own
    // `async` callback returns -- i.e. before package:test's
    // `addTearDown` queue (registered on the outer test function) ever
    // fires. Disposing via `addTearDown` here fails with "A
    // SemanticsHandle was active at the end of the test." every time, so
    // `handle` is disposed explicitly at the end of the test body below
    // instead.
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // Scoped to the NavigationBar's own semantics subtree: an unscoped
    // `find.bySemanticsLabel` also matches the route body's plain "Home
    // body" / "Activity body" / "Accounts body" / "More body" `Text`
    // (each `Text` widget exposes a semantics node whose label is its
    // own text), so a bare 'Home'/'Activity'/'Accounts'/'More' regex is
    // ambiguous against the whole tree -- it is not a production
    // defect. Scoping to descendants of the `NavigationBar` proves the
    // bottom-navigation destinations themselves expose the expected
    // semantics labels.
    final Finder navBar = find.byType(NavigationBar);
    expect(
      find.descendant(of: navBar, matching: find.bySemanticsLabel(RegExp('Home'))),
      findsOneWidget,
    );
    expect(
      find.descendant(of: navBar, matching: find.bySemanticsLabel(RegExp('Activity'))),
      findsOneWidget,
    );
    expect(
      find.descendant(of: navBar, matching: find.bySemanticsLabel(RegExp('Add'))),
      findsOneWidget,
    );
    expect(
      find.descendant(of: navBar, matching: find.bySemanticsLabel(RegExp('Accounts'))),
      findsOneWidget,
    );
    expect(
      find.descendant(of: navBar, matching: find.bySemanticsLabel(RegExp('More'))),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    handle.dispose();
  });

  testWidgets(
      'under RTL, the shell still renders all five destinations with no '
      'exceptions/overflow -- Material NavigationBar handles the mirroring itself',
      (tester) async {
    await tester.pumpWidget(buildApp(rtl: true));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(NavigationDestination, 'Home'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Activity'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Add'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Accounts'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'More'), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(5));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'under RTL, Home/Activity/Accounts/More destinations remain tappable and switching '
      'between them still works, with no exceptions', (tester) async {
    await tester.pumpWidget(buildApp(rtl: true));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Activity'));
    await tester.pumpAndSettle();
    expect(find.text('Activity body'), findsOneWidget);
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 1);
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(NavigationDestination, 'More'));
    await tester.pumpAndSettle();
    expect(find.text('More body'), findsOneWidget);
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 4);
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Home'));
    await tester.pumpAndSettle();
    expect(find.text('Home body'), findsOneWidget);
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'under RTL, the Add action still opens the transaction sheet without '
      'disturbing the selected destination or routing semantics', (tester) async {
    await tester.pumpWidget(buildApp(rtl: true));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(NavigationDestination, 'Add'));
    await tester.pumpAndSettle();

    expect(find.text('Expense'), findsOneWidget);
    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Transfer'), findsOneWidget);
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'under RTL, destinations remain discoverable via semantics',
      (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    // See the non-RTL test's fix above: disposed explicitly at the end
    // of the test body, not via addTearDown -- `_endOfTestVerifications`
    // checks handle disposal before this test's own async callback
    // returns, i.e. before any addTearDown queue would fire.

    await tester.pumpWidget(buildApp(rtl: true));
    await tester.pumpAndSettle();

    final Finder navBar = find.byType(NavigationBar);
    expect(
      find.descendant(of: navBar, matching: find.bySemanticsLabel(RegExp('Home'))),
      findsOneWidget,
    );
    expect(
      find.descendant(of: navBar, matching: find.bySemanticsLabel(RegExp('Activity'))),
      findsOneWidget,
    );
    expect(
      find.descendant(of: navBar, matching: find.bySemanticsLabel(RegExp('Add'))),
      findsOneWidget,
    );
    expect(
      find.descendant(of: navBar, matching: find.bySemanticsLabel(RegExp('Accounts'))),
      findsOneWidget,
    );
    expect(
      find.descendant(of: navBar, matching: find.bySemanticsLabel(RegExp('More'))),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    handle.dispose();
  });

  // ---------------------------------------------------------------------
  // Localization: AppShell reads real ARB-backed strings via
  // `AppLocalizations.of(context)` (see `lib/shared/widgets/app_shell.dart`)
  // for all five labels, including the two new ones (`navAccounts`,
  // `navMore`) this checkpoint adds.
  // ---------------------------------------------------------------------

  testWidgets(
      'under the English locale, the real AppShell renders the '
      'ARB-backed English destination labels with no exceptions', (tester) async {
    await tester.pumpWidget(buildApp(locale: const Locale('en')));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(NavigationDestination, 'Home'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Activity'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Add'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Accounts'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'More'), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(5));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'under the Japanese locale, the real AppShell renders the '
      'ARB-backed Japanese destination labels with no exceptions', (tester) async {
    await tester.pumpWidget(buildApp(locale: const Locale('ja')));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(NavigationDestination, 'ホーム'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'アクティビティ'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, '追加'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, '口座'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'その他'), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(5));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Japanese destination labels remain represented with no '
      'overflow/render exceptions at 1.6x text scale', (tester) async {
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;

    await tester.pumpWidget(buildApp(locale: const Locale('ja')));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(NavigationDestination, 'ホーム'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'アクティビティ'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, '追加'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, '口座'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'その他'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'at 2.0x text scale under Japanese, all destinations remain '
      'represented and tappable, and Add opens the sheet with its localized '
      'Japanese labels, with no exceptions', (tester) async {
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;

    await tester.pumpWidget(buildApp(locale: const Locale('ja')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(NavigationDestination, 'アクティビティ'));
    await tester.pumpAndSettle();
    expect(find.text('Activity body'), findsOneWidget);
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 1);
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(NavigationDestination, 'ホーム'));
    await tester.pumpAndSettle();
    expect(find.text('Home body'), findsOneWidget);
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 0);
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(NavigationDestination, '追加'));
    await tester.pumpAndSettle();
    expect(find.text('支出'), findsOneWidget);
    expect(find.text('収入'), findsOneWidget);
    expect(find.text('振替'), findsOneWidget);
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'at a narrow 320px width combined with 2.0x text scale under '
      'Japanese, the shell remains renderable, destination semantics remain '
      'available, and Add remains usable', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;

    final SemanticsHandle handle = tester.ensureSemantics();
    // Disposed explicitly at the end of the test body, not via
    // addTearDown -- see the non-Japanese semantics tests above.

    await tester.pumpWidget(buildApp(locale: const Locale('ja')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final Finder navBar = find.byType(NavigationBar);
    expect(
      find.descendant(of: navBar, matching: find.bySemanticsLabel(RegExp('ホーム'))),
      findsOneWidget,
    );
    expect(
      find.descendant(of: navBar, matching: find.bySemanticsLabel(RegExp('アクティビティ'))),
      findsOneWidget,
    );
    expect(
      find.descendant(of: navBar, matching: find.bySemanticsLabel(RegExp('追加'))),
      findsOneWidget,
    );
    expect(
      find.descendant(of: navBar, matching: find.bySemanticsLabel(RegExp('口座'))),
      findsOneWidget,
    );
    expect(
      find.descendant(of: navBar, matching: find.bySemanticsLabel(RegExp('その他'))),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(NavigationDestination, '追加'));
    await tester.pumpAndSettle();
    expect(find.text('支出'), findsOneWidget);
    expect(find.text('収入'), findsOneWidget);
    expect(find.text('振替'), findsOneWidget);
    expect(tester.takeException(), isNull);
    handle.dispose();
  });

  testWidgets(
      "switching the locale from English to Japanese through the same "
      "mechanism AppShell reads (MaterialApp.router's locale:) updates the "
      'rendered labels without disturbing the underlying GoRouter/selection state',
      (tester) async {
    final ValueNotifier<Locale> localeNotifier = ValueNotifier<Locale>(const Locale('en'));
    addTearDown(localeNotifier.dispose);
    final GoRouter router = GoRouter(
      initialLocation: '/home',
      routes: <RouteBase>[
        ShellRoute(
          builder: (context, state, child) => AppShell(child: child),
          routes: <RouteBase>[
            GoRoute(path: '/home', builder: (context, state) => const Text('Home body')),
            GoRoute(path: '/activity', builder: (context, state) => const Text('Activity body')),
            GoRoute(path: '/accounts', builder: (context, state) => const Text('Accounts body')),
            GoRoute(path: '/more', builder: (context, state) => const Text('More body')),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ValueListenableBuilder<Locale>(
        valueListenable: localeNotifier,
        builder: (BuildContext context, Locale locale, Widget? _) {
          return MaterialApp.router(
            routerConfig: router,
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(NavigationDestination, 'Home'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Activity'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Add'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Accounts'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'More'), findsOneWidget);

    // Same GoRouter instance throughout -- switching AppLocalizations
    // through `locale:` alone, exactly the mechanism `appLocaleProvider`
    // feeds `MaterialApp.router` in production (see `lib/app/app.dart`),
    // never touches routing: current location/selection carries across
    // the switch below unchanged.
    await tester.tap(find.widgetWithText(NavigationDestination, 'Activity'));
    await tester.pumpAndSettle();
    expect(find.text('Activity body'), findsOneWidget);
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 1);

    localeNotifier.value = const Locale('ja');
    await tester.pumpAndSettle();

    expect(find.widgetWithText(NavigationDestination, 'ホーム'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'アクティビティ'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, '追加'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, '口座'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'その他'), findsOneWidget);
    // The pre-switch English labels are gone -- this really re-resolved
    // AppLocalizations, not just left stale English text mounted.
    expect(find.text('Home'), findsNothing);
    expect(find.text('Activity'), findsNothing);
    // Routing/selection state (still on Activity, still matchedLocation
    // `/activity`) is exactly what it was before the locale switched --
    // no persisted identifier or routing semantic changed, only display
    // strings did.
    expect(find.text('Activity body'), findsOneWidget);
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 1);
    expect(tester.takeException(), isNull);
  });

  // ---------------------------------------------------------------------
  // U3 Final Polish Pass, item 10: "Current selected bottom-nav color
  // looks gray. Change the selected-state visual treatment to
  // KakeiboPlus light green/mint." -- see `AppShell.build()`'s own doc
  // comment and `AppSemanticColors.navSelectedColor`'s doc comment for
  // the full root-cause/fix explanation. Every test above this point
  // uses `buildApp()` with no `theme:` -- proving those pre-existing
  // 30 tests are completely unaffected by this pass, since the new
  // `theme` parameter defaults to `null`, byte-for-byte identical to
  // every one of those call sites before this pass added the parameter.
  // ---------------------------------------------------------------------

  group('bottom-nav selected-state color (item 10)', () {
    testWidgets(
        "under the real KakeiboPlus Light theme, the selected destination's icon/label "
        'read the theme\'s teal/emerald navSelectedColor token, and the indicator pill is '
        'a soft mint tint derived from that same color -- not the plain gray '
        'secondaryContainer this bar used before this pass', (tester) async {
      final ThemeData light = AppTheme.light();
      final Color navSelected = light.extension<AppTokens>()!.colors.navSelectedColor!;

      await tester.pumpWidget(buildApp(theme: light));
      await tester.pumpAndSettle();

      final NavigationBarThemeData navTheme =
          Theme.of(tester.element(find.byType(NavigationBar))).navigationBarTheme;

      expect(navTheme.iconTheme!.resolve(<WidgetState>{WidgetState.selected})!.color, navSelected);
      expect(
        navTheme.labelTextStyle!.resolve(<WidgetState>{WidgetState.selected})!.color,
        navSelected,
      );

      // Unselected keeps the same muted gray-blue Material 3 already
      // used for the unselected state before this pass -- only the
      // SELECTED treatment changed.
      final Color onSurfaceVariant = light.colorScheme.onSurfaceVariant;
      expect(navTheme.iconTheme!.resolve(<WidgetState>{})!.color, onSurfaceVariant);
      expect(navTheme.labelTextStyle!.resolve(<WidgetState>{})!.color, onSurfaceVariant);

      // The pill/indicator behind the selected icon is DERIVED from
      // `navSelected` (the same tinted-background idiom `AppIconTile`
      // already uses elsewhere), not the plain
      // `colorScheme.secondaryContainer` this bar fell back to before
      // this pass.
      expect(navTheme.indicatorColor, navSelected.withValues(alpha: 0.16));
      expect(navTheme.indicatorColor, isNot(light.colorScheme.secondaryContainer));
    });

    testWidgets(
        'without the KakeiboPlus theme (no navSelectedColor token available), the bar '
        'renders with its original, unwrapped NavigationBarThemeData -- proving this '
        'pass never forces the new colors onto a theme that does not opt in',
        (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      final NavigationBarThemeData navTheme =
          Theme.of(tester.element(find.byType(NavigationBar))).navigationBarTheme;

      // No local override was installed -- iconTheme/labelTextStyle are
      // whatever the ambient (here, Flutter's own default) ThemeData
      // already provides, never the KakeiboPlus teal/emerald token.
      expect(navTheme.iconTheme, isNull);
      expect(navTheme.labelTextStyle, isNull);
    });

    testWidgets(
        'the KakeiboPlus-themed bar still selects/navigates correctly -- the color '
        'change is purely a paint layer, not a behavior change', (tester) async {
      await tester.pumpWidget(buildApp(theme: AppTheme.light()));
      await tester.pumpAndSettle();
      expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 0);

      await tester.tap(find.widgetWithText(NavigationDestination, 'Accounts'));
      await tester.pumpAndSettle();

      expect(find.text('Accounts body'), findsOneWidget);
      expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 3);
      expect(tester.takeException(), isNull);
    });
  });
}
