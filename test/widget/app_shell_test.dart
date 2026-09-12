import 'package:ai_financial_coach/shared/widgets/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Release-gate-adjacent widget test: "Navigation shell renders exactly
/// the four Beta 0 destinations" (Home / Activity / Add / Profile — no
/// Goals tab yet) and the Add sheet opens with only Expense / Income /
/// Transfer enabled — see `STAGE1_BETA0_IMPLEMENTATION_PLAN.md` §14 and
/// Decision 12. Uses a small standalone [GoRouter] rather than the full
/// [routerProvider] to keep this test independent of database setup.
void main() {
  Widget buildApp() {
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
    return MaterialApp.router(routerConfig: router);
  }

  /// CP5.5 (AppShell / Bottom Navigation Text-Scale Validation): a
  /// standalone `NavigationBar` mirroring the exact shape `AppShell`
  /// builds (four destinations, `icon`/`selectedIcon` pairs, Material 3
  /// theme) but with real Japanese labels -- the project's proof
  /// localization -- substituted for the English ones.
  ///
  /// `AppShell`'s destination labels are literal English strings today;
  /// there is no `AppLocalizations` wiring for the shell and no matching
  /// keys in `lib/l10n/app_en.arb`/`app_ja.arb`. Broadening shell
  /// localization is out of scope for this TEST-FIRST checkpoint (see
  /// CP5.5 instructions, scenario E), so this does not claim `AppShell`
  /// itself is localized -- it proves the underlying Material 3
  /// `NavigationBar` layout mechanism `AppShell` relies on survives
  /// longer/localized labels, as the smallest safe test seam available
  /// without changing product behavior. `アクティビティ`
  /// ("Activity") is a deliberately long katakana label to stress width.
  Widget buildJapaneseLabelStressBar() {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(
        bottomNavigationBar: NavigationBar(
          selectedIndex: 0,
          onDestinationSelected: (_) {},
          destinations: const <NavigationDestination>[
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'ホーム',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'アクティビティ',
            ),
            NavigationDestination(
              icon: Icon(Icons.add_circle_outline),
              selectedIcon: Icon(Icons.add_circle),
              label: '追加',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'プロフィール',
            ),
          ],
        ),
      ),
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
      "CP5.5 E: the underlying Material 3 NavigationBar layout survives realistic "
      "Japanese labels (the project's proof localization) at a narrow width and "
      '1.6x text scale', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;

    await tester.pumpWidget(buildJapaneseLabelStressBar());
    await tester.pumpAndSettle();

    expect(find.text('ホーム'), findsOneWidget);
    expect(find.text('アクティビティ'), findsOneWidget);
    expect(find.text('追加'), findsOneWidget);
    expect(find.text('プロフィール'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'CP5.5 E: the underlying Material 3 NavigationBar layout survives realistic '
      'Japanese labels at a narrow width and 2.0x text scale', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;

    await tester.pumpWidget(buildJapaneseLabelStressBar());
    await tester.pumpAndSettle();

    expect(find.text('ホーム'), findsOneWidget);
    expect(find.text('アクティビティ'), findsOneWidget);
    expect(find.text('追加'), findsOneWidget);
    expect(find.text('プロフィール'), findsOneWidget);
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
}
