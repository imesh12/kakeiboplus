import 'package:ai_financial_coach/shared/theme/app_theme_style.dart';
import 'package:flutter_test/flutter_test.dart';

// Checkpoint 8.1 (Premium Theme Personalization Foundation):
// AppThemeStyle's own tests. Plain test()s -- pure enum logic, no
// widget tree, no database -- mirroring
// test/core/locale/app_language_test.dart's shape for the same reason
// that file is a plain test file.
void main() {
  group('AppThemeStyle', () {
    test('exposes exactly 5 values -- the locked initial theme family', () {
      expect(AppThemeStyle.values, hasLength(5));
      expect(
        AppThemeStyle.values.map((AppThemeStyle s) => s.storageValue).toSet(),
        <String>{'light', 'dark', 'pink', 'ocean', 'forest'},
      );
    });

    test('storageValue is stable/lowercase for every value', () {
      expect(AppThemeStyle.light.storageValue, 'light');
      expect(AppThemeStyle.dark.storageValue, 'dark');
      expect(AppThemeStyle.pink.storageValue, 'pink');
      expect(AppThemeStyle.ocean.storageValue, 'ocean');
      expect(AppThemeStyle.forest.storageValue, 'forest');
    });

    test('fallback is Light', () {
      expect(AppThemeStyle.fallback, AppThemeStyle.light);
    });

    test('fromStorageValue resolves every known storage value back to its own style', () {
      for (final AppThemeStyle style in AppThemeStyle.values) {
        expect(AppThemeStyle.fromStorageValue(style.storageValue), style);
      }
    });

    test('fromStorageValue falls back to Light for null', () {
      expect(AppThemeStyle.fromStorageValue(null), AppThemeStyle.light);
    });

    test('fromStorageValue falls back to Light for an empty string', () {
      expect(AppThemeStyle.fromStorageValue(''), AppThemeStyle.light);
    });

    test('fromStorageValue falls back to Light for an unknown/corrupt value -- never throws', () {
      expect(AppThemeStyle.fromStorageValue('not-a-theme'), AppThemeStyle.light);
      expect(AppThemeStyle.fromStorageValue('LIGHT'), AppThemeStyle.light); // case-sensitive
      expect(AppThemeStyle.fromStorageValue('midnight'), AppThemeStyle.light);
    });
  });
}
