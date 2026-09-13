import 'package:ai_financial_coach/shared/theme/app_theme.dart';
import 'package:ai_financial_coach/shared/widgets/app_section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Visual System Convergence Checkpoint 7.1 §16: focused widget tests for
/// the shared [AppSectionHeader] primitive -- title renders, the optional
/// icon/trailing action render, and a long Japanese title survives a narrow
/// width at large text scale without overflowing.
void main() {
  Widget buildApp(Widget child, {double width = 400}) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: SizedBox(width: width, child: child)),
    );
  }

  testWidgets('renders the title', (tester) async {
    await tester.pumpWidget(buildApp(const AppSectionHeader(title: 'Accounts')));

    expect(find.text('Accounts'), findsOneWidget);
  });

  testWidgets('renders an optional leading icon in the theme primary color', (tester) async {
    await tester.pumpWidget(
      buildApp(const AppSectionHeader(title: 'Budget', icon: Icons.savings_outlined)),
    );

    final BuildContext context = tester.element(find.text('Budget'));
    final ColorScheme colors = Theme.of(context).colorScheme;

    final Icon icon = tester.widget<Icon>(find.byIcon(Icons.savings_outlined));
    expect(icon.color, colors.primary);
  });

  testWidgets('has no icon when none is provided', (tester) async {
    await tester.pumpWidget(buildApp(const AppSectionHeader(title: 'Accounts')));

    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('renders an optional trailing action', (tester) async {
    await tester.pumpWidget(
      buildApp(
        AppSectionHeader(
          title: 'Accounts',
          trailing: TextButton(onPressed: () {}, child: const Text('Manage')),
        ),
      ),
    );

    expect(find.widgetWithText(TextButton, 'Manage'), findsOneWidget);
  });

  testWidgets('has no trailing widget when none is provided', (tester) async {
    await tester.pumpWidget(buildApp(const AppSectionHeader(title: 'Accounts')));

    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets(
    'a long Japanese title and trailing action both render without overflow '
    'at 320px width and 2.0x text scale',
    (tester) async {
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;

      await tester.pumpWidget(
        buildApp(
          AppSectionHeader(
            title: 'これは非常に長い日本語のセクションタイトルのテキストです',
            trailing: TextButton(onPressed: () {}, child: const Text('管理')),
          ),
          width: 320,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextButton, '管理'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
