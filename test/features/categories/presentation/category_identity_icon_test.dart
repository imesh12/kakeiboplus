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
    // App Icon Integration checkpoint: deliberately an icon key with
    // NO curated asset mapping (category_icon_asset.dart). This test's
    // whole point is proving Icon-level glyph+color identity across
    // screens; 'shopping_cart' now resolves to Image.asset instead of
    // Icon, which would make find.byType(Icon) fail for an unrelated
    // reason. 'diamond' preserves the original Icon-based intent.
    const String iconKey = 'diamond';
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

  // App Icon Integration checkpoint: proves the additive
  // `categoryIconAssetFor` wiring inside `build()` -- an icon key with
  // curated artwork renders the PNG via `Image.asset` instead of the
  // Material `Icon`, while an unmapped/unrecognized/null key keeps
  // rendering exactly the same `Icon` as every pre-existing call site.
  group('App Icon Integration: asset vs. Material-icon fallback', () {
    testWidgets('an icon key with curated artwork (e.g. "restaurant") renders Image.asset, '
        'not Icon', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CategoryIdentityIcon(
            categoryId: 'cat-dining',
            iconKey: 'restaurant',
            colorKey: 'orange',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
      final Image image = tester.widget<Image>(find.byType(Image));
      final AssetImage assetImage = image.image as AssetImage;
      expect(assetImage.assetName, 'assets/icons/categories/dining_out.png');
    });

    testWidgets('shopping_bag (a non-system, explicitly-selectable key) renders '
        'shopping_bag.png', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CategoryIdentityIcon(
            categoryId: 'cat-custom-shopping',
            iconKey: 'shopping_bag',
            colorKey: 'purple',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Image image = tester.widget<Image>(find.byType(Image));
      expect(
        (image.image as AssetImage).assetName,
        'assets/icons/categories/shopping_bag.png',
      );
    });

    testWidgets('the "category" key (seeded Other Expense, or user-picked "Other") now '
        'renders the approved other.png artwork, not the Material Icon', (tester) async {
      // Category Icon Source Correction checkpoint: `'category'` is no
      // longer left unmapped in `category_icon_asset.dart` -- see that
      // file's own doc comment for why this is narrowly scoped to
      // exactly this key, not every null/unrecognized category (the two
      // tests below independently cover those).
      await tester.pumpWidget(
        _wrap(
          const CategoryIdentityIcon(
            categoryId: 'cat-other-expense',
            iconKey: 'category',
            colorKey: 'grey',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
      final Image image = tester.widget<Image>(find.byType(Image));
      expect(
        (image.image as AssetImage).assetName,
        'assets/icons/categories/other.png',
      );
    });

    testWidgets('an unrecognized icon key falls back to the Material icon, not a broken/blank '
        'render', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CategoryIdentityIcon(
            categoryId: 'cat-future',
            iconKey: 'some_future_icon_name',
            colorKey: 'teal',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(Icon), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });
  });
}
