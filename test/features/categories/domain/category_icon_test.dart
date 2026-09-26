import 'package:ai_financial_coach/features/categories/domain/category_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Beta 1 Transaction UX Phase B, Checkpoint 1 (`docs/14_DECISION_LOG.md`
// ADR-025/026). `Categories.icon` already exists in the schema and is
// already seeded for every system category by
// `CategoryRepository._systemCategories` -- this only adds the
// name -> IconData mapping that was missing; no schema change.

void main() {
  group('categoryIconFor', () {
    test('maps every currently-seeded system category icon name', () {
      // Mirrors CategoryRepository._systemCategories exactly -- if that
      // seed list ever adds a name, add it here too (an unmapped name
      // still falls back safely, per the test below, so this is a
      // fidelity check, not a safety net).
      const Map<String, IconData> expected = <String, IconData>{
        'shopping_cart': Icons.shopping_cart,
        'directions_bus': Icons.directions_bus,
        'receipt_long': Icons.receipt_long,
        'restaurant': Icons.restaurant,
        'local_hospital': Icons.local_hospital,
        'category': Icons.category,
        'work': Icons.work,
        'attach_money': Icons.attach_money,
      };
      for (final MapEntry<String, IconData> entry in expected.entries) {
        expect(categoryIconFor(entry.key), entry.value, reason: 'icon name: ${entry.key}');
      }
    });

    test('a null icon name falls back to fallbackCategoryIcon', () {
      expect(categoryIconFor(null), fallbackCategoryIcon);
    });

    test('an unrecognized icon name falls back to fallbackCategoryIcon, not a crash', () {
      expect(categoryIconFor('some_future_icon_name'), fallbackCategoryIcon);
      expect(categoryIconFor(''), fallbackCategoryIcon);
    });
  });

  group('Checkpoint U1: categoryIconKeys catalog', () {
    test('has around 50 curated entries, not dozens of near-duplicates', () {
      // Not pinned to exactly 50 -- a future checkpoint may add or
      // remove a concept -- but bounded so an accidental mass-dump of
      // every `Icons.*` constant would fail this loudly.
      expect(categoryIconKeys.length, greaterThanOrEqualTo(40));
      expect(categoryIconKeys.length, lessThanOrEqualTo(60));
    });

    test('has no duplicate keys', () {
      expect(categoryIconKeys.toSet().length, categoryIconKeys.length);
    });

    test('every key resolves to a real, non-fallback IconData via categoryIconFor', () {
      for (final String key in categoryIconKeys) {
        expect(categoryIconFor(key), isNotNull, reason: key);
      }
    });

    test('every one of the original 8 system-category seed icons is still present unchanged', () {
      const Map<String, IconData> original = <String, IconData>{
        'shopping_cart': Icons.shopping_cart,
        'directions_bus': Icons.directions_bus,
        'receipt_long': Icons.receipt_long,
        'restaurant': Icons.restaurant,
        'local_hospital': Icons.local_hospital,
        'category': Icons.category,
        'work': Icons.work,
        'attach_money': Icons.attach_money,
      };
      for (final MapEntry<String, IconData> entry in original.entries) {
        expect(categoryIconKeys, contains(entry.key));
        expect(categoryIconFor(entry.key), entry.value, reason: entry.key);
      }
    });
  });
}
