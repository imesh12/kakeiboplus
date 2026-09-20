import 'package:ai_financial_coach/shared/theme/app_theme.dart';
import 'package:ai_financial_coach/shared/widgets/app_icon_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Checkpoint 10 (Icon-Led UI Foundation): focused widget tests for the
// shared AppIconTile primitive -- the generalized form of
// TransactionIconBadge's pre-existing tinted-container idiom (see that
// widget's own updated doc comment). Asserts the shape/size contract each
// size tier promises, and that TransactionIconBadge's own pre-existing
// numbers (40 container / radius 12 / alpha 0.14 / 20 glyph) are exactly
// what AppIconTileSize.medium now produces -- proving that refactor is a
// pure rename, not a visual change.
void main() {
  Widget buildApp(Widget child) {
    return MaterialApp(theme: AppTheme.light(), home: Scaffold(body: Center(child: child)));
  }

  testWidgets('renders the given icon tinted with the given color', (tester) async {
    await tester.pumpWidget(
      buildApp(const AppIconTile(icon: Icons.restaurant, color: Colors.deepOrange)),
    );

    final Icon icon = tester.widget<Icon>(find.byIcon(Icons.restaurant));
    expect(icon.color, Colors.deepOrange);
  });

  testWidgets('medium tier matches TransactionIconBadge\'s pre-existing 40/12/20/0.14 shape', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildApp(
        const AppIconTile(icon: Icons.restaurant, color: Colors.deepOrange),
      ),
    );

    final Container container = tester.widget<Container>(find.byType(Container));
    expect(container.constraints!.maxWidth, 40);
    final BoxDecoration decoration = container.decoration! as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(12));
    expect(decoration.color, Colors.deepOrange.withValues(alpha: 0.14));

    final Icon icon = tester.widget<Icon>(find.byIcon(Icons.restaurant));
    expect(icon.size, 20);
  });

  testWidgets('small and large tiers resolve to distinct, ascending sizes', (tester) async {
    await tester.pumpWidget(
      buildApp(
        const Column(
          children: <Widget>[
            SizedBox(
              key: Key('small'),
              child: AppIconTile(
                icon: Icons.star,
                color: Colors.blue,
                size: AppIconTileSize.small,
              ),
            ),
            SizedBox(
              key: Key('medium'),
              child: AppIconTile(icon: Icons.star, color: Colors.blue),
            ),
            SizedBox(
              key: Key('large'),
              child: AppIconTile(
                icon: Icons.star,
                color: Colors.blue,
                size: AppIconTileSize.large,
              ),
            ),
          ],
        ),
      ),
    );

    double widthOf(Key key) => tester
        .widget<Container>(find.descendant(of: find.byKey(key), matching: find.byType(Container)))
        .constraints!
        .maxWidth;

    final double small = widthOf(const Key('small'));
    final double medium = widthOf(const Key('medium'));
    final double large = widthOf(const Key('large'));

    expect(small, lessThan(medium));
    expect(medium, lessThan(large));
  });

  testWidgets('an optional semanticLabel reaches the underlying Icon', (tester) async {
    await tester.pumpWidget(
      buildApp(
        const AppIconTile(icon: Icons.savings, color: Colors.green, semanticLabel: 'Savings'),
      ),
    );

    final Icon icon = tester.widget<Icon>(find.byIcon(Icons.savings));
    expect(icon.semanticLabel, 'Savings');
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
          home: const Scaffold(
            body: AppIconTile(icon: Icons.account_balance_wallet_rounded, color: Colors.teal),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
