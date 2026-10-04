import 'package:ai_financial_coach/shared/theme/app_theme.dart';
import 'package:ai_financial_coach/shared/widgets/app_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Checkpoint 10 (Icon-Led UI Foundation): focused widget tests for the
// shared AppProgressBar primitive -- the generalized, named form of
// goal_detail_screen.dart's pre-existing ClipRRect+LinearProgressIndicator
// pattern (see that screen's own updated call site). Asserts the exact
// shape that pattern already had (thin, rounded, semantic color, no
// clamping of its own), so moving a call site onto this widget stays a
// pure rename.
void main() {
  Widget buildApp(Widget child) {
    return MaterialApp(theme: AppTheme.light(), home: Scaffold(body: child));
  }

  testWidgets('renders a LinearProgressIndicator with the given value and color', (tester) async {
    await tester.pumpWidget(buildApp(const AppProgressBar(value: 0.65, color: Colors.green)));

    final LinearProgressIndicator indicator = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(indicator.value, 0.65);
    expect(indicator.color, Colors.green);
    expect(indicator.minHeight, 8);
  });

  testWidgets('clips to a fully-rounded shape matching its own thickness', (tester) async {
    await tester.pumpWidget(buildApp(const AppProgressBar(value: 0.3, color: Colors.red)));

    final ClipRRect clip = tester.widget<ClipRRect>(find.byType(ClipRRect));
    expect(clip.borderRadius, BorderRadius.circular(8));
  });

  testWidgets('a custom minHeight changes thickness and radius together', (tester) async {
    await tester.pumpWidget(
      buildApp(const AppProgressBar(value: 0.5, color: Colors.blue, minHeight: 4)),
    );

    final LinearProgressIndicator indicator = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(indicator.minHeight, 4);
    final ClipRRect clip = tester.widget<ClipRRect>(find.byType(ClipRRect));
    expect(clip.borderRadius, BorderRadius.circular(4));
  });

  testWidgets('does not clamp an out-of-range value itself -- matches '
      'LinearProgressIndicator\'s own contract', (tester) async {
    await tester.pumpWidget(buildApp(const AppProgressBar(value: 1.4, color: Colors.orange)));

    final LinearProgressIndicator indicator = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(indicator.value, 1.4);
  });

  testWidgets('an optional semanticLabel reaches the underlying indicator', (tester) async {
    await tester.pumpWidget(
      buildApp(
        const AppProgressBar(value: 0.5, color: Colors.blue, semanticLabel: 'Food & Dining budget'),
      ),
    );

    final LinearProgressIndicator indicator = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(indicator.semanticsLabel, 'Food & Dining budget');
  });

  testWidgets(
    'Test-bug fix (round 3): when a gradient is supplied, the internal fill fraction '
    'matches the real value -- a 0.30 value fills exactly 30% of the track, never '
    'artificially widened or narrowed, and never coupled to the track\'s own pixel width',
    (tester) async {
      await tester.pumpWidget(
        buildApp(
          const AppProgressBar(
            value: 0.3,
            color: Colors.green,
            gradient: LinearGradient(colors: <Color>[Colors.green, Colors.teal]),
          ),
        ),
      );

      // The gradient branch paints its fill via a `FractionallySizedBox`
      // sized to `widthFactor: value` (see `AppProgressBar`'s own doc
      // comment on its gradient path) -- there is exactly one in the
      // tree for a single `AppProgressBar`, so `find.byType` is
      // unambiguous here, unlike in a full screen with many widgets.
      final FractionallySizedBox fill = tester.widget<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      expect(fill.widthFactor, 0.3);

      // The underlying `LinearProgressIndicator` still carries the same
      // real value too (kept transparent, purely for its `Semantics`
      // contract -- see that same doc comment), so both halves of the
      // gradient branch agree on the one real value.
      final LinearProgressIndicator indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, 0.3);
    },
  );

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
          home: const Scaffold(body: AppProgressBar(value: 0.42, color: Colors.purple)),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
