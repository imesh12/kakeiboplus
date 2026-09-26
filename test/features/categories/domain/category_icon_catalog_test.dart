import 'package:ai_financial_coach/features/categories/domain/category_icon.dart';
import 'package:ai_financial_coach/features/categories/domain/category_icon_catalog.dart';
import 'package:ai_financial_coach/l10n/generated/app_localizations_en.dart';
import 'package:ai_financial_coach/l10n/generated/app_localizations_ja.dart';
import 'package:flutter_test/flutter_test.dart';

// Checkpoint U1 (Category, Service, Currency & Card Visual Identity
// Foundation): `categoryIconLabel` is the localized-label half of the
// icon picker catalog -- see that function's own doc comment. Every
// assertion below constructs `AppLocalizationsEn`/`AppLocalizationsJa`
// directly (no `BuildContext`/widget pump needed), matching
// `more_screen_test.dart`'s own precedent for a pure-Dart localization
// assertion.

void main() {
  test('every categoryIconKeys entry has a non-empty English label', () {
    final AppLocalizationsEn l10n = AppLocalizationsEn();
    for (final String key in categoryIconKeys) {
      final String label = categoryIconLabel(l10n, key);
      expect(label, isNotEmpty, reason: key);
    }
  });

  test('every categoryIconKeys entry has a non-empty Japanese label', () {
    final AppLocalizationsJa l10n = AppLocalizationsJa();
    for (final String key in categoryIconKeys) {
      final String label = categoryIconLabel(l10n, key);
      expect(label, isNotEmpty, reason: key);
    }
  });

  test('an unrecognized icon key falls back to the "Other" label, not a crash', () {
    final AppLocalizationsEn l10n = AppLocalizationsEn();
    expect(categoryIconLabel(l10n, 'some_future_icon_name'), l10n.categoryIconOther);
  });

  test('labels are not accidentally identical across every key (would indicate a copy-paste bug)', () {
    final AppLocalizationsEn l10n = AppLocalizationsEn();
    final Set<String> labels = categoryIconKeys.map((String key) => categoryIconLabel(l10n, key)).toSet();
    // Not strictly one-label-per-key (a future concept could reasonably
    // share wording), but this many distinct concepts should produce
    // meaningfully more than a handful of distinct labels.
    expect(labels.length, greaterThan(30));
  });
}
