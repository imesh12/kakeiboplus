import 'package:ai_financial_coach/features/categories/domain/category_icon_asset.dart';
import 'package:flutter_test/flutter_test.dart';

// App Icon Integration checkpoint: unit coverage for the additive,
// presentation-only `categoryIconAssetFor` resolver
// (`category_icon_asset.dart`). This is a pure function test -- no
// widget pump needed -- mirroring `category_icon_test.dart`'s own style
// for `categoryIconFor`.
void main() {
  group('categoryIconAssetFor', () {
    test('resolves every approved system-category icon key to its expected production PNG', () {
      const Map<String, String> expected = <String, String>{
        'shopping_cart': 'assets/icons/categories/groceries.png',
        'directions_bus': 'assets/icons/categories/transport.png',
        'receipt_long': 'assets/icons/categories/bills_utilities.png',
        'restaurant': 'assets/icons/categories/dining_out.png',
        'local_hospital': 'assets/icons/categories/health.png',
        'category': 'assets/icons/categories/other.png',
        'work': 'assets/icons/categories/salary.png',
        'attach_money': 'assets/icons/categories/other_income.png',
      };
      for (final MapEntry<String, String> entry in expected.entries) {
        expect(categoryIconAssetFor(entry.key), entry.value, reason: 'icon key: ${entry.key}');
      }
    });

    test('shopping_bag resolves to the Shopping.png production asset', () {
      // Checkpoint brief: "Use Shopping.png as the presentation asset
      // for the existing `shopping_bag` icon key" -- a custom category
      // may select this key without any system-category/schema change.
      expect(categoryIconAssetFor('shopping_bag'), 'assets/icons/categories/shopping_bag.png');
    });

    test('the generic fallback key "category" now resolves to the approved Other artwork, but '
        'the fallback mechanism itself is untouched', () {
      // Category Icon Source Correction checkpoint: `'category'` is the
      // seeded "Other" expense category's own icon value (and also what
      // a user gets by explicitly picking "Other" from the icon
      // picker), so it is now mapped like any other catalog key. This
      // does NOT make `categoryIconAssetFor` leak onto every
      // null/unrecognized category -- see the two tests below, which
      // independently confirm both of those still return `null`.
      expect(categoryIconAssetFor('category'), 'assets/icons/categories/other.png');
    });

    test('a null icon key returns null, never throws', () {
      expect(categoryIconAssetFor(null), isNull);
    });

    test('an unrecognized icon key returns null, never throws', () {
      expect(categoryIconAssetFor('some_future_icon_name'), isNull);
      expect(categoryIconAssetFor(''), isNull);
    });
  });
}
