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

  // Visual System Convergence Checkpoint 7.3: the underlying `Card` always
  // clips to its rounded shape now, regardless of `onTap`/`bordered` -- see
  // the `clipBehavior` doc comment on `AppCard` itself for why (Activity's
  // transaction row is the first call site to combine `onTap`'s InkWell
  // ripple with this card's rounded corners).
  testWidgets('CP7.3: always clips to its rounded shape, with or without onTap', (tester) async {
    await tester.pumpWidget(buildApp(const AppCard(child: Text('content'))));
    final Card staticCard = tester.widget<Card>(find.byType(Card));
    expect(staticCard.clipBehavior, Clip.antiAlias);

    await tester.pumpWidget(buildApp(AppCard(onTap: () {}, child: const Text('tappable'))));
    final Card tappableCard = tester.widget<Card>(find.byType(Card));
    expect(tappableCard.clipBehavior, Clip.antiAlias);
  });

  // Checkpoint 10 (Icon-Led UI Foundation): `softShadow` -- the restrained
  // soft-drop-shadow feature-card treatment, matching the approved
  // reference's white hero/feature cards.
  testWidgets(
    'CP10: softShadow defaults to false and is pixel-identical to every pre-existing '
    'AppCard (elevation 0, no explicit shadowColor)',
    (tester) async {
      await tester.pumpWidget(buildApp(const AppCard(child: Text('content'))));

      final Card card = tester.widget<Card>(find.byType(Card));
      expect(card.elevation, 0);
      expect(card.shadowColor, isNull);
    },
  );

  testWidgets('CP10: softShadow: true renders a restrained, non-zero elevation with a low-alpha shadowColor', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp(const AppCard(softShadow: true, child: Text('content'))));

    final BuildContext context = tester.element(find.text('content'));
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Card card = tester.widget<Card>(find.byType(Card));
    expect(card.elevation, greaterThan(0));
    expect(card.shadowColor, colors.shadow.withValues(alpha: 0.16));
  });

  testWidgets(
    'Checkpoint U3: an explicit gradient paints instead of color, via a Container/DecoratedBox '
    'rather than a Card (so the flat Card.color path is never used for it)',
    (tester) async {
      const Gradient gradient = LinearGradient(
        colors: <Color>[Color(0xFF0F9E9A), Color(0xFF19B7A5)],
      );
      await tester.pumpWidget(
        buildApp(const AppCard(color: Colors.purple, gradient: gradient, child: Text('content'))),
      );

      // The gradient branch renders no Card at all -- color (even
      // though explicitly passed here) is documented as ignored
      // whenever gradient is non-null.
      expect(find.byType(Card), findsNothing);

      final Container container = tester.widget<Container>(
        find.ancestor(of: find.text('content'), matching: find.byType(Container)).first,
      );
      final BoxDecoration decoration = container.decoration! as BoxDecoration;
      expect(decoration.gradient, gradient);
    },
  );

  testWidgets(
    'Checkpoint U3: a gradient AppCard still clips to its rounded shape and still wraps an '
    'onTap in a working InkWell',
    (tester) async {
      const Gradient gradient = LinearGradient(
        colors: <Color>[Color(0xFF0F9E9A), Color(0xFF19B7A5)],
      );
      bool tapped = false;
      await tester.pumpWidget(
        buildApp(
          AppCard(
            gradient: gradient,
            radius: 24,
            onTap: () => tapped = true,
            child: const Text('content'),
          ),
        ),
      );

      final Container container = tester.widget<Container>(
        find.ancestor(of: find.text('content'), matching: find.byType(Container)).first,
      );
      expect(container.clipBehavior, Clip.antiAlias);
      final BoxDecoration decoration = container.decoration! as BoxDecoration;
      final BorderRadius radius = decoration.borderRadius! as BorderRadius;
      expect(radius, BorderRadius.circular(24));

      await tester.tap(find.text('content'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
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
