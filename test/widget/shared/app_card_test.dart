import 'package:ai_financial_coach/shared/theme/app_theme.dart';
import 'package:ai_financial_coach/shared/theme/app_tokens.dart';
import 'package:ai_financial_coach/shared/widgets/app_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Visual System Convergence Checkpoint 7.1 §16: focused widget tests for
/// the shared [AppCard] primitive -- renders its child, uses the expected
/// surface/shape/elevation from the real [AppTheme], and stays exception-free
/// at a narrow width. Deliberately not a pixel-perfect golden test (per the
/// checkpoint's own "no golden tests yet" scope boundary) -- these assert on
/// the actual [Card] properties `AppCard` builds instead.
void main() {
  Widget buildApp(Widget child) {
    return MaterialApp(theme: AppTheme.light(), home: Scaffold(body: Center(child: child)));
  }

  testWidgets('renders its child', (tester) async {
    await tester.pumpWidget(buildApp(const AppCard(child: Text('hello'))));

    expect(find.text('hello'), findsOneWidget);
  });

  testWidgets(
    'uses the theme surface color, medium radius, zero elevation, and zero margin by default',
    (tester) async {
      await tester.pumpWidget(buildApp(const AppCard(child: Text('content'))));

      final BuildContext context = tester.element(find.text('content'));
      final ColorScheme colors = Theme.of(context).colorScheme;

      final Card card = tester.widget<Card>(find.byType(Card));
      expect(card.elevation, 0);
      expect(card.color, colors.surfaceContainerHigh);
      expect(card.margin, EdgeInsets.zero);
      final RoundedRectangleBorder shape = card.shape! as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(16));
    },
  );

  testWidgets('an explicit color/radius overrides the defaults', (tester) async {
    await tester.pumpWidget(
      buildApp(const AppCard(color: Colors.purple, radius: 4, child: Text('content'))),
    );

    final Card card = tester.widget<Card>(find.byType(Card));
    expect(card.color, Colors.purple);
    final RoundedRectangleBorder shape = card.shape! as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.circular(4));
  });

  testWidgets('an explicit padding overrides the default internal padding', (tester) async {
    await tester.pumpWidget(
      buildApp(const AppCard(padding: EdgeInsets.all(2), child: Text('tight'))),
    );

    final Padding padding = tester.widget<Padding>(
      find.ancestor(of: find.text('tight'), matching: find.byType(Padding)).first,
    );
    expect(padding.padding, const EdgeInsets.all(2));
  });

  testWidgets('wraps the child in an InkWell and invokes onTap only when provided', (
    tester,
  ) async {
    int taps = 0;
    await tester.pumpWidget(buildApp(AppCard(onTap: () => taps++, child: const Text('tap me'))));

    expect(find.byType(InkWell), findsOneWidget);
    await tester.tap(find.text('tap me'));
    expect(taps, 1);
  });

  testWidgets('has no InkWell when onTap is null', (tester) async {
    await tester.pumpWidget(buildApp(const AppCard(child: Text('static'))));

    expect(find.byType(InkWell), findsNothing);
  });

  // Visual System Convergence Checkpoint 7.2: `bordered` -- the flat
  // white/near-surface card with a thin `subtleBorder` outline used to
  // match the approved Claude Design reference's card treatment.

  testWidgets(
    'CP7.2: bordered defaults to false and is pixel-identical to the CP7.1 card '
    '(tonal surface, no border side)',
    (tester) async {
      await tester.pumpWidget(buildApp(const AppCard(child: Text('content'))));

      final BuildContext context = tester.element(find.text('content'));
      final ColorScheme colors = Theme.of(context).colorScheme;
      final Card card = tester.widget<Card>(find.byType(Card));
      expect(card.color, colors.surfaceContainerHigh);
      final RoundedRectangleBorder shape = card.shape! as RoundedRectangleBorder;
      expect(shape.side, BorderSide.none);
    },
  );

  testWidgets(
    'CP7.2: bordered: true renders a colorScheme.surface background with a '
    'subtleBorder-colored side',
    (tester) async {
      await tester.pumpWidget(buildApp(const AppCard(bordered: true, child: Text('content'))));

      final BuildContext context = tester.element(find.text('content'));
      final ColorScheme colors = Theme.of(context).colorScheme;
      final AppTokens tokens = context.appTokens;
      final Card card = tester.widget<Card>(find.byType(Card));
      expect(card.color, colors.surface);
      final RoundedRectangleBorder shape = card.shape! as RoundedRectangleBorder;
      expect(shape.side.color, tokens.colors.subtleBorder);
    },
  );

  testWidgets(
    'CP7.2: an explicit color still wins over bordered\'s own default background',
    (tester) async {
      await tester.pumpWidget(
        buildApp(const AppCard(bordered: true, color: Colors.purple, child: Text('content'))),
      );

      final Card card = tester.widget<Card>(find.byType(Card));
      expect(card.color, Colors.purple);
      final RoundedRectangleBorder shape = card.shape! as RoundedRectangleBorder;
      // The border side is still drawn even when color is overridden --
      // only the background is caller-controlled.
      expect(shape.side, isNot(BorderSide.none));
    },
  );

  testWidgets('renders without exceptions at a narrow 320px width', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      buildApp(
        const AppCard(
          child: Text('A reasonably long line of card content that could wrap at narrow widths'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
