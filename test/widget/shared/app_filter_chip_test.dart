import 'package:ai_financial_coach/shared/theme/app_theme.dart';
import 'package:ai_financial_coach/shared/widgets/app_filter_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Checkpoint 10 (Icon-Led UI Foundation): focused widget tests for the
// shared AppFilterChip primitive -- a thin wrapper around Flutter's
// built-in FilterChip (see activity_screen.dart's own updated
// _TypeFilterChip, which now delegates here instead of calling
// FilterChip directly).
void main() {
  Widget buildApp(Widget child) {
    return MaterialApp(theme: AppTheme.light(), home: Scaffold(body: child));
  }

  testWidgets('renders a FilterChip carrying the given label and selected state', (tester) async {
    await tester.pumpWidget(
      buildApp(AppFilterChip(label: 'Expense', selected: true, onSelected: (_) {})),
    );

    final FilterChip chip = tester.widget<FilterChip>(find.byType(FilterChip));
    expect(chip.selected, isTrue);
    expect(find.text('Expense'), findsOneWidget);
  });

  testWidgets('tapping calls onSelected with the toggled value', (tester) async {
    bool? received;
    await tester.pumpWidget(
      buildApp(
        AppFilterChip(
          label: 'Income',
          selected: false,
          onSelected: (bool value) => received = value,
        ),
      ),
    );

    await tester.tap(find.byType(FilterChip));
    await tester.pump();

    expect(received, isTrue);
  });

  testWidgets('picks up the app-wide pill shape from AppTheme\'s ChipThemeData', (tester) async {
    await tester.pumpWidget(
      buildApp(AppFilterChip(label: 'Transfer', selected: false, onSelected: (_) {})),
    );

    final FilterChip chip = tester.widget<FilterChip>(find.byType(FilterChip));
    // AppTheme sets ChipThemeData.shape to a fully-rounded
    // RoundedRectangleBorder (pillRadius) -- FilterChip itself sets no
    // per-widget shape override, so it inherits that theme shape.
    expect(chip.shape, isNull);
  });

  testWidgets('renders without exceptions under every theme', (tester) async {
    for (final ThemeData theme in <ThemeData>[
      AppTheme.light(),
      AppTheme.dark(),
      AppTheme.pink(),
      AppTheme.ocean(),
      AppTheme.forest(),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: AppFilterChip(label: 'Expense', selected: true, onSelected: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
