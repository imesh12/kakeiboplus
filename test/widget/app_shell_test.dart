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
}
