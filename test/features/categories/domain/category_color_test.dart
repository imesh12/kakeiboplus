import 'package:ai_financial_coach/features/categories/domain/category_color.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveCategoryColorKey', () {
    test('a recognized storedColorKey is used as-is', () {
      expect(
        resolveCategoryColorKey(categoryId: 'any-id', storedColorKey: 'teal'),
        CategoryColorKey.teal,
      );
    });

    test('a null storedColorKey falls back deterministically by categoryId, never randomly', () {
      final CategoryColorKey first = resolveCategoryColorKey(categoryId: 'user-cat-1', storedColorKey: null);
      final CategoryColorKey second = resolveCategoryColorKey(categoryId: 'user-cat-1', storedColorKey: null);
      expect(first, second, reason: 'same id must resolve to the same fallback every time');
    });

    test('an unrecognized storedColorKey falls back deterministically, not a crash', () {
      final CategoryColorKey resolved =
          resolveCategoryColorKey(categoryId: 'user-cat-2', storedColorKey: 'some_future_color_key');
      expect(resolved, resolveCategoryColorKey(categoryId: 'user-cat-2', storedColorKey: null));
    });

    test('two different category ids can fall back to different colors', () {
      // Not a strict requirement (a hash collision is fine), but with
      // 14 palette entries and these two ids, they land on different
      // slots -- a smoke check that the fallback isn't secretly
      // constant regardless of id.
      final CategoryColorKey a = resolveCategoryColorKey(categoryId: 'aaaaaaaa', storedColorKey: null);
      final CategoryColorKey b = resolveCategoryColorKey(categoryId: 'zzzzzzzz', storedColorKey: null);
      expect(a == b, isFalse);
    });
  });

  group('categoryColorFor', () {
    test('never throws for any combination of null/unrecognized inputs', () {
      expect(
        () => categoryColorFor(categoryId: 'x', storedColorKey: null, isDark: false),
        returnsNormally,
      );
      expect(
        () => categoryColorFor(categoryId: 'x', storedColorKey: 'nonsense', isDark: true),
        returnsNormally,
      );
    });

    test('light and dark resolve to different (but both real) colors for the same key', () {
      final light = categoryColorFor(categoryId: 'x', storedColorKey: 'blue', isDark: false);
      final dark = categoryColorFor(categoryId: 'x', storedColorKey: 'blue', isDark: true);
      expect(light, isNotNull);
      expect(dark, isNotNull);
      expect(light, isNot(dark));
    });

    test('every CategoryColorKey has both a light and a dark color, never throwing', () {
      for (final CategoryColorKey key in CategoryColorKey.values) {
        expect(() => categoryColorForKey(key, isDark: false), returnsNormally, reason: key.storageValue);
        expect(() => categoryColorForKey(key, isDark: true), returnsNormally, reason: key.storageValue);
      }
    });
  });

  group('CategoryColorKey.fromStorageValue', () {
    test('round-trips every value\'s own storageValue', () {
      for (final CategoryColorKey key in CategoryColorKey.values) {
        expect(CategoryColorKey.fromStorageValue(key.storageValue), key);
      }
    });

    test('null and an unrecognized string both return null, never throwing', () {
      expect(CategoryColorKey.fromStorageValue(null), isNull);
      expect(CategoryColorKey.fromStorageValue('not_a_real_key'), isNull);
    });
  });
}
