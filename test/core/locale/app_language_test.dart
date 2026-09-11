import 'package:ai_financial_coach/core/locale/app_language.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppLanguageRegistry', () {
    test('byCode returns English for "en"', () {
      expect(AppLanguageRegistry.byCode('en'), AppLanguageRegistry.english);
    });

    test('byCode returns Japanese for "ja"', () {
      expect(AppLanguageRegistry.byCode('ja'), AppLanguageRegistry.japanese);
    });

    test('byCode is case-insensitive', () {
      expect(AppLanguageRegistry.byCode('EN'), AppLanguageRegistry.english);
      expect(AppLanguageRegistry.byCode('Ja'), AppLanguageRegistry.japanese);
      expect(AppLanguageRegistry.byCode('JA'), AppLanguageRegistry.japanese);
    });

    test('byCode falls back to English for null', () {
      expect(AppLanguageRegistry.byCode(null), AppLanguageRegistry.english);
    });

    test('byCode falls back to English for an unknown/corrupt code', () {
      expect(AppLanguageRegistry.byCode('fr'), AppLanguageRegistry.english);
      expect(AppLanguageRegistry.byCode(''), AppLanguageRegistry.english);
      expect(AppLanguageRegistry.byCode('not-a-language'), AppLanguageRegistry.english);
    });

    test('knownLanguages contains exactly en and ja metadata entries', () {
      expect(AppLanguageRegistry.knownLanguages, hasLength(2));
      expect(
        AppLanguageRegistry.knownLanguages.map((AppLanguage language) => language.code).toSet(),
        <String>{'en', 'ja'},
      );
    });

    test('fallback is English', () {
      expect(AppLanguageRegistry.fallback, AppLanguageRegistry.english);
    });
  });
}
