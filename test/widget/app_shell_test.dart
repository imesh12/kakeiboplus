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
}
