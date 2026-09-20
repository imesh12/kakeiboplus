import 'package:ai_financial_coach/shared/theme/app_theme.dart';
import 'package:ai_financial_coach/shared/widgets/app_segmented_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Checkpoint 10 (Icon-Led UI Foundation): focused widget tests for the
// new AppSegmentedControl foundation primitive -- a genuinely new shape
// (the CP10 audit found no existing segmented-control pattern anywhere in
// the app to generalize from; see that widget's own doc comment for why).
// Built and tested standalone this checkpoint, not yet wired into an
// existing screen -- see the CP10 final report's "Deferred visual work".
void main() {
  const List<AppSegmentedControlOption<String>> options = <AppSegmentedControlOption<String>>[
    AppSegmentedControlOption<String>(value: 'all', label: 'All'),
    AppSegmentedControlOption<String>(value: 'cash', label: 'Cash'),
    AppSegmentedControlOption<String>(value: 'bank', label: 'Bank'),
  ];

  Widget buildApp(Widget child) {
    return MaterialApp(theme: AppTheme.light(), home: Scaffold(body: child));
  }

  testWidgets('renders every option\'s label exactly once', (tester) async {
    await tester.pumpWidget(
      buildApp(
        AppSegmentedControl<String>(options: options, selected: 'all', onChanged: (_) {}),
      ),
    );

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Cash'), findsOneWidget);
    expect(find.text('Bank'), findsOneWidget);
  });

  testWidgets(
    'exactly one segment is exposed as Semantics(selected: true) -- the rest false',
    (tester) async {
      await tester.pumpWidget(
        buildApp(
          AppSegmentedControl<String>(options: options, selected: 'cash', onChanged: (_) {}),
        ),
      );

      final List<Semantics> ownSemantics = tester
          .widgetList<Semantics>(
            find.descendant(
              of: find.byType(AppSegmentedControl<String>),
              matching: find.byType(Semantics),
            ),
          )
          .where((Semantics s) => s.properties.selected != null)
          .toList();

      expect(ownSemantics, hasLength(options.length));
      expect(ownSemantics.where((Semantics s) => s.properties.selected == true), hasLength(1));
      expect(ownSemantics.where((Semantics s) => s.properties.selected == false), hasLength(2));
    },
  );

  testWidgets('tapping an unselected option calls onChanged with its value', (tester) async {
    String? changedTo;
    await tester.pumpWidget(
      buildApp(
        AppSegmentedControl<String>(
          options: options,
          selected: 'all',
          onChanged: (String value) => changedTo = value,
        ),
      ),
    );

    await tester.tap(find.text('Bank'));
    await tester.pump();

    expect(changedTo, 'bank');
  });

  testWidgets('a longer translated label still renders on one line without overflow', (
    tester,
  ) async {
    const List<AppSegmentedControlOption<String>> longOptions = <AppSegmentedControlOption<String>>[
      AppSegmentedControlOption<String>(
        value: 'a',
        label: 'A dramatically longer localized segment label than usual',
      ),
      AppSegmentedControlOption<String>(value: 'b', label: 'Short'),
    ];

    await tester.pumpWidget(
      buildApp(
        SizedBox(
          width: 300,
          child: AppSegmentedControl<String>(
            options: longOptions,
            selected: 'a',
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('remains structurally correct under RTL', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: AppSegmentedControl<String>(options: options, selected: 'all', onChanged: (_) {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Cash'), findsOneWidget);
    expect(find.text('Bank'), findsOneWidget);
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
            body: AppSegmentedControl<String>(options: options, selected: 'all', onChanged: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('remains usable at 2.0x text scale', (tester) async {
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;

    await tester.pumpWidget(
      buildApp(
        AppSegmentedControl<String>(options: options, selected: 'all', onChanged: (_) {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
