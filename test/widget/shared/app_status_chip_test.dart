import 'package:ai_financial_coach/shared/widgets/app_status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Visual System Convergence Checkpoint 7.1 §16: focused widget tests for
/// the shared [AppStatusChip] primitive -- renders its label styled with the
/// given color, and survives a long localized label at a constrained width
/// without throwing.
void main() {
  Widget buildApp(Widget child) {
    return MaterialApp(home: Scaffold(body: Center(child: child)));
  }

  testWidgets('renders its label', (tester) async {
    await tester.pumpWidget(
      buildApp(const AppStatusChip(label: 'On track', color: Colors.green)),
    );

    expect(find.text('On track'), findsOneWidget);
  });

  testWidgets('styles the label with the given color and a one-line ellipsis', (tester) async {
    await tester.pumpWidget(buildApp(const AppStatusChip(label: 'Overdue', color: Colors.red)));

    final Text text = tester.widget<Text>(find.text('Overdue'));
    expect(text.style?.color, Colors.red);
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
  });

  testWidgets('the pill background is the given color at low alpha', (tester) async {
    await tester.pumpWidget(buildApp(const AppStatusChip(label: 'Due today', color: Colors.blue)));

    final Container container = tester.widget<Container>(find.byType(Container));
    final BoxDecoration decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, Colors.blue.withValues(alpha: 0.14));
  });

  testWidgets('renders a long localized label at a constrained width without exceptions', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildApp(
        const SizedBox(
          width: 80,
          child: AppStatusChip(
            // A plausible long Japanese status label ("ahead of pace").
            label: '予定より進んでいます',
            color: Colors.orange,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(AppStatusChip), findsOneWidget);
  });
}
