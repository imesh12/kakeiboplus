import 'package:ai_financial_coach/l10n/generated/app_localizations.dart';
import 'package:ai_financial_coach/shared/widgets/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import '../support/rtl_harness.dart';

/// Release-gate-adjacent widget test: "Navigation shell renders exactly
/// the four Beta 0 destinations" (Home / Activity / Add / Profile — no
/// Goals tab yet) and the Add sheet opens with only Expense / Income /
/// Transfer enabled — see `STAGE1_BETA0_IMPLEMENTATION_PLAN.md` §14 and
/// Decision 12. Uses a small standalone [GoRouter] rather than the full
/// [routerProvider] to keep this test independent of database setup.
void main() {
  // CP5.6: `{bool rtl = false}` threads an RTL `Directionality` through
  // `MaterialApp.router`'s own `builder:` -- see
  // `test/support/rtl_harness.dart` for why that's the only place it can
  // be injected. Every existing call site keeps working unchanged
  // (`rtl` defaults to false).
  // CP6.1 (Localization Phase 1): `AppShell` now reads
  // `AppLocalizations.of(context)` for its four destination labels, so
  // every test app -- not just the new Japanese-locale ones -- must wire
  // `AppLocalizations.localizationsDelegates`/`supportedLocales`, exactly
  // like `international_preferences_screen_test.dart` already does for
  // its own MaterialApp. `{Locale locale = const Locale('en')}` keeps
  // every pre-existing call site passing (English is still the default),
  // while the new Japanese-proof tests pass `locale: const Locale('ja')`.
  Widget buildApp({bool rtl = false, Locale locale = const Locale('en')}) {
    final GoRouter router = GoRouter(
      initialLocation: '/home',
      routes: <RouteBase>[
        ShellRoute(
          builder: (context, state, child) => AppShell(child: child),
          routes: <RouteBase>[
            GoRoute(path: '/home', builder: (context, state) => const Text('Home body')),
            GoRoute(path: '/activity', builder: (context, state) => const Text('Activity body')),
            GoRoute(path: '/profile', builder: (context, state) => const Text('Profile body')),
          ],
        ),
      ],
    );
    return MaterialApp.router(
      routerConfig: router,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: rtl ? rtlAppBuilder : null,
    );
  }

  testWidgets('shows exactly Home, Activity, Add, and Profile — no Goals tab', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.widgetWithText(NavigationDestination, 'Home'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Activity'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Add'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Profile'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Goals'), findsNothing);
    expect(find.byType(NavigationDestination), findsNWidgets(4));
  });

  testWidgets('tapping Activity navigates to the Activity screen', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(NavigationDestination, 'Activity'));
    await tester.pumpAndSettle();

    expect(find.text('Activity body'), findsOneWidget);
  });

  testWidgets('the Add destination opens a sheet with Expense/Income/Transfer '
      'and no Receipt or Goal Contribution option', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(NavigationDestination, 'Add'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ListTile, 'Expense'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Income'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Transfer'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Receipt'), findsNothing);
    expect(find.widgetWithText(ListTile, 'Goal Contribution'), findsNothing);
  });

  // -- Checkpoint 6 (Transaction UX Phase B): a visually stronger circular
  // tonal Add icon. Add stays NavigationDestination index 2 and stays an
  // ACTION -- these tests prove _currentIndex still never reports 2 for
  // Add, and that opening/dismissing the sheet never disturbs whichever
  // tab was actually selected.

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

    expect(find.widgetWithText(ListTile, 'Expense'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Income'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Transfer'), findsOneWidget);
    // The sheet is modal, layered above the shell -- the underlying
    // NavigationBar is still mounted, unchanged, proving Add never became
    // the "current" destination and no route was ever pushed for it.
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 0);
  });

  testWidgets(
      'from Activity, tapping Add opens the sheet and Activity remains '
      'NavigationBar selectedIndex 1', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(NavigationDestination, 'Activity'));
    await tester.pumpAndSettle();
    expect(find.text('Activity body'), findsOneWidget);
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 1);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Add'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ListTile, 'Expense'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Income'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Transfer'), findsOneWidget);
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 1);
  });

  testWidgets(
      'the Add icon renders inside a circular tonal container sized/colored per '
      'ColorScheme, and no other destination gets that treatment', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    final ColorScheme colors = Theme.of(tester.element(find.byType(NavigationBar))).colorScheme;

    // On Home, Add is unselected, so it's rendering its `icon:` (not
    // `selectedIcon:`) -- add_circle_outline, per the approved spec.
    final Icon addIcon = tester.widget<Icon>(find.byIcon(Icons.add_circle_outline));
    expect(addIcon.size, 27);
    expect(addIcon.color, colors.onPrimaryContainer);

    bool isAddTonalCircle(Widget w) =>
        w is Container &&
        w.constraints?.maxWidth == 44 &&
        w.constraints?.maxHeight == 44 &&
        (w.decoration as BoxDecoration?)?.shape == BoxShape.circle &&
        (w.decoration as BoxDecoration?)?.color == colors.primaryContainer;

    // Exactly one circular tonal container exists on the whole bar, and
    // it's the Add icon's own ancestor -- proving Home/Activity/Profile's
    // plain Icons were never given the same treatment.
    final Finder tonalCircle = find.byWidgetPredicate(isAddTonalCircle);
    expect(tonalCircle, findsOneWidget);
    expect(
      find.ancestor(of: find.byIcon(Icons.add_circle_outline), matching: tonalCircle),
      findsOneWidget,
    );
  });

  testWidgets(
      'CP5.5 A: shell renders all four destinations with correct labels and no '
      'exceptions/overflow at normal (1.0x) text scale', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.widgetWithText(NavigationDestination, 'Home'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Activity'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Add'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Profile'), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'CP5.5 B: all four destinations remain represented with labels visible and '
      'no overflow/render exceptions at 1.6x text scale', (tester) async {
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.widgetWithText(NavigationDestination, 'Home'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Activity'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Add'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Profile'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'CP5.5 C: all four destinations remain represented and tappable, and '
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

    await tester.tap(find.widgetWithText(NavigationDestination, 'Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Profile body'), findsOneWidget);
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 3);
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Home'));
    await tester.pumpAndSettle();
    expect(find.text('Home body'), findsOneWidget);
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'CP5.5 C: the Add action still opens the transaction sheet at 2.0x text scale '
      'without disturbing the selected destination', (tester) async {
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(NavigationDestination, 'Add'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ListTile, 'Expense'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Income'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Transfer'), findsOneWidget);
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'CP5.5 D: a narrow 320px width combined with 1.6x text scale keeps all '
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
    expect(find.widgetWithText(NavigationDestination, 'Profile'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Activity'));
    await tester.pumpAndSettle();
    expect(find.text('Activity body'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'CP5.5 D: a narrow 320px width combined with 2.0x text scale keeps all '
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
    expect(find.widgetWithText(NavigationDestination, 'Profile'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Add'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Expense'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'CP5.5 F: destinations remain discoverable via semantics at 2.0x text scale',
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
    // body" / "Activity body" / "Profile body" `Text` (each `Text` widget
    // exposes a semantics node whose label is its own text), so a bare
    // 'Home'/'Activity'/'Profile' regex is ambiguous against the whole
    // tree -- it is not a production defect. Scoping to descendants of
    // the `NavigationBar` proves the bottom-navigation destinations
    // themselves expose the expected semantics labels.
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
      find.descendant(of: navBar, matching: find.bySemanticsLabel(RegExp('Profile'))),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    handle.dispose();
  });
  testWidgets(
      'CP5.6: under RTL, the shell still renders all four destinations with no '
      'exceptions/overflow -- Material NavigationBar handles the mirroring itself',
      (tester) async {
    await tester.pumpWidget(buildApp(rtl: true));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(NavigationDestination, 'Home'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Activity'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Add'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Profile'), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'CP5.6: under RTL, Home/Activity/Profile destinations remain tappable and switching '
      'between them still works, with no exceptions', (tester) async {
    await tester.pumpWidget(buildApp(rtl: true));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Activity'));
    await tester.pumpAndSettle();
    expect(find.text('Activity body'), findsOneWidget);
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 1);
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Profile body'), findsOneWidget);
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 3);
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Home'));
    await tester.pumpAndSettle();
    expect(find.text('Home body'), findsOneWidget);
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'CP5.6: under RTL, the Add action still opens the transaction sheet without '
      'disturbing the selected destination or routing semantics', (tester) async {
    await tester.pumpWidget(buildApp(rtl: true));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(NavigationDestination, 'Add'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ListTile, 'Expense'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Income'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Transfer'), findsOneWidget);
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'CP5.6: under RTL, destinations remain discoverable via semantics',
      (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    // See CP5.5's fix: disposed explicitly at the end of the test body,
    // not via addTearDown -- `_endOfTestVerifications` checks handle
    // disposal before this test's own async callback returns, i.e.
    // before any addTearDown queue would fire.

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
      find.descendant(of: navBar, matching: find.bySemanticsLabel(RegExp('Profile'))),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    handle.dispose();
  });

  // ---------------------------------------------------------------------
  // CP6.1 (Localization Phase 1): Japanese AppShell + Core Navigation
  // Proof. AppShell now reads real ARB-backed strings via
  // `AppLocalizations.of(context)` (see `lib/shared/widgets/app_shell.dart`)
  // instead of literal English -- these tests exercise the REAL AppShell
  // under the Japanese locale rather than a standalone stand-in
  // NavigationBar (the old CP5.5 E `buildJapaneseLabelStressBar` proof is
  // removed; this supersedes it now that the production widget itself is
  // locale-aware).
  // ---------------------------------------------------------------------

  testWidgets(
      'CP6.1 A: under the English locale, the real AppShell renders the '
      'ARB-backed English destination labels with no exceptions', (tester) async {
    await tester.pumpWidget(buildApp(locale: const Locale('en')));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(NavigationDestination, 'Home'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Activity'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Add'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Profile'), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'CP6.1 B: under the Japanese locale, the real AppShell renders the '
      'ARB-backed Japanese destination labels with no exceptions', (tester) async {
    await tester.pumpWidget(buildApp(locale: const Locale('ja')));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(NavigationDestination, 'ホーム'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'アクティビティ'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, '追加'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'プロフィール'), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'CP6.1 C: Japanese destination labels remain represented with no '
      'overflow/render exceptions at 1.6x text scale', (tester) async {
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;

    await tester.pumpWidget(buildApp(locale: const Locale('ja')));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(NavigationDestination, 'ホーム'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'アクティビティ'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, '追加'), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'プロフィール'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'CP6.1 D: at 2.0x text scale under Japanese, all destinations remain '
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
    expect(find.widgetWithText(ListTile, '支出'), findsOneWidget);
    expect(find.widgetWithText(ListTile, '収入'), findsOneWidget);
    expect(find.widgetWithText(ListTile, '振替'), findsOneWidget);
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'CP6.1 E: at a narrow 320px width combined with 2.0x text scale under '
      'Japanese, the shell remains renderable, destination semantics remain '
      'available, and Add remains usable', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;

    final SemanticsHandle handle = tester.ensureSemantics();
    // See CP5.5's fix (reused throughout CP5.6/CP6.1): disposed explicitly
    // at the end of the test body, not via addTearDown -- `_endOfTestVerifications`
    // checks handle disposal before this test's own async callback returns.

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
      find.descendant(of: navBar, matching: find.bySemanticsLabel(RegExp('プロフィール'))),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(NavigationDestination, '追加'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, '支出'), findsOneWidget);
    expect(find.widgetWithText(ListTile, '収入'), findsOneWidget);
    expect(find.widgetWithText(ListTile, '振替'), findsOneWidget);
    expect(tester.takeException(), isNull);
    handle.dispose();
  });

  testWidgets(
      "CP6.1 F: switching the locale from English to Japanese through the same "
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
            GoRoute(path: '/profile', builder: (context, state) => const Text('Profile body')),
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
    expect(find.widgetWithText(NavigationDestination, 'Profile'), findsOneWidget);

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
    expect(find.widgetWithText(NavigationDestination, 'プロフィール'), findsOneWidget);
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
}
