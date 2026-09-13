import 'package:ai_financial_coach/shared/widgets/app_empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Visual System Convergence Checkpoint 7.1 §16: focused widget tests for
/// the shared [AppEmptyState] primitive -- message and action render,
/// [onAction] fires, an explicit [AppEmptyState.actionKey] is forwarded
/// (needed by `home_screen_test.dart`'s existing key-based lookups), and a
/// long Japanese message/action survive a narrow width without exceptions.
void main() {
  Widget buildApp(Widget child) {
    return MaterialApp(home: Scaffold(body: Center(child: child)));
  }

  testWidgets('renders the message and action label', (tester) async {
    await tester.pumpWidget(
      buildApp(
        AppEmptyState(
          message: 'No budget set for this month',
          actionLabel: 'Set a monthly budget',
          onAction: () {},
        ),
      ),
    );

    expect(find.text('No budget set for this month'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Set a monthly budget'), findsOneWidget);
  });

  testWidgets('invokes onAction when the button is tapped', (tester) async {
    int taps = 0;
    await tester.pumpWidget(
      buildApp(
        AppEmptyState(
          message: 'No savings goal yet',
          actionLabel: 'Set a savings goal',
          onAction: () => taps++,
        ),
      ),
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'Set a savings goal'));
    expect(taps, 1);
  });

  testWidgets('forwards an explicit actionKey to the action button', (tester) async {
    await tester.pumpWidget(
      buildApp(
        AppEmptyState(
          actionKey: const Key('setSavingsGoalButton'),
          message: 'No savings goal yet',
          actionLabel: 'Set a savings goal',
          onAction: () {},
        ),
      ),
    );

    expect(find.byKey(const Key('setSavingsGoalButton')), findsOneWidget);
  });

  testWidgets('defaults to the add icon', (tester) async {
    await tester.pumpWidget(
      buildApp(AppEmptyState(message: 'Nothing yet', actionLabel: 'Add', onAction: () {})),
    );

    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
  });

  testWidgets('accepts a custom icon', (tester) async {
    await tester.pumpWidget(
      buildApp(
        AppEmptyState(
          message: 'Nothing yet',
          actionLabel: 'Retry',
          icon: Icons.refresh_rounded,
          onAction: () {},
        ),
      ),
    );

    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsNothing);
  });

  testWidgets(
    'renders a long Japanese message and action label without exceptions at narrow width',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        buildApp(
          AppEmptyState(
            message: 'まだ今月の予算が設定されていません。予算を設定して支出を管理しましょう。',
            actionLabel: '毎月の予算を設定',
            onAction: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );
}
