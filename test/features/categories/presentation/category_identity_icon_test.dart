import 'package:ai_financial_coach/features/categories/domain/category_color.dart';
import 'package:ai_financial_coach/features/categories/domain/category_icon.dart';
import 'package:ai_financial_coach/features/categories/presentation/category_identity_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Checkpoint U1 (Category, Service, Currency & Card Visual Identity
// Foundation): proves the specific property the checkpoint brief calls
// out explicitly -- "the same iconKey+colorKey must resolve identically
// across screens... No screen should independently reinterpret stored
// visual identifiers." `CategoryIdentityIcon` is the ONE widget every
// category surface (the category list, every category dropdown, a
// budget tile) renders through specifically so this holds by
// construction; this test proves it by pumping the SAME identity
// through two structurally different surrounding widget trees (mimicking
// two different screens) and asserting the rendered `Icon` is pixel-
// value identical in both.

Widget _wrap(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    theme: ThemeData(brightness: brightness),
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets(
      'the same categoryId/iconKey/colorKey renders an identical icon+color inside two '
      'differently-structured surrounding widgets', (tester) async {
    const String categoryId = 'cat-groceries';
    const String iconKey = 'shopping_cart';
    const String colorKey = 'green';

    // "Screen A": the icon rendered alone, centered.
    await tester.pumpWidget(
      _wrap(
        const Center(
          child: CategoryIdentityIcon(categoryId: categoryId, iconKey: iconKey, colorKey: colorKey),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final Icon iconA = tester.widget<Icon>(find.byType(Icon));
    final Color colorA = iconA.color!;
    final IconData glyphA = iconA.icon!;

    // "Screen B": the same identity, but nested inside a completely
    // different ancestor structure (a Row inside a Card inside a
    // ListView) -- exactly the kind of "different screen, same
    // category" situation the checkpoint brief is concerned about.
    await tester.pumpWidget(
      _wrap(
        ListView(
          children: <Widget>[
            const Card(
              child: Row(
                children: <Widget>[
                  CategoryIdentityIcon(categoryId: categoryId, iconKey: iconKey, colorKey: colorKey),
                  Text('Groceries'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final Icon iconB = tester.widget<Icon>(find.byType(Icon));

    expect(iconB.icon, glyphA, reason: 'same iconKey must resolve to the same IconData everywhere');
    expect(iconB.color, colorA, reason: 'same colorKey must resolve to the same Color everywhere');

    // Cross-checked directly against the pure resolver functions too --
    // the widget must not be doing anything beyond what those already
    // guarantee.
    expect(glyphA, categoryIconFor(iconKey));
    expect(
      colorA,
      categoryColorFor(categoryId: categoryId, storedColorKey: colorKey, isDark: false),
    );
  });

  testWidgets('a null iconKey/colorKey still renders a real, non-throwing icon', (tester) async {
    await tester.pumpWidget(
      _wrap(const CategoryIdentityIcon(categoryId: 'legacy-cat')),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(Icon), findsOneWidget);
  });

  testWidgets('dark mode resolves a different (but still non-null) color than light mode',
      (tester) async {
    const String categoryId = 'cat-x';
    const String colorKey = 'blue';

    await tester.pumpWidget(
      _wrap(const CategoryIdentityIcon(categoryId: categoryId, colorKey: colorKey)),
    );
    await tester.pumpAndSettle();
    final Color light = tester.widget<Icon>(find.byType(Icon)).color!;

    await tester.pumpWidget(
      _wrap(
        const CategoryIdentityIcon(categoryId: categoryId, colorKey: colorKey),
        brightness: Brightness.dark,
      ),
    );
    await tester.pumpAndSettle();
    final Color dark = tester.widget<Icon>(find.byType(Icon)).color!;

    expect(light, isNot(dark));
  });
}
