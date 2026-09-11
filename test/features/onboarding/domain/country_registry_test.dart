import 'package:ai_financial_coach/features/onboarding/domain/country_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CountryRegistry', () {
    group('byCode (onboarding default-selection lookup -- unchanged by CP3A)', () {
      test('resolves a known code', () {
        final OnboardingCountry country = CountryRegistry.byCode('JP');
        expect(country.code, 'JP');
        expect(country.displayName, 'Japan');
      });

      test('falls back to the first entry for an unknown code -- existing onboarding default '
          'behavior, must remain unchanged', () {
        expect(CountryRegistry.byCode('ZZ'), CountryRegistry.all.first);
        expect(CountryRegistry.byCode('ZZ').code, 'JP');
      });
    });

    group('findByCode (safe lookup, added in CP3A)', () {
      test('a known code resolves correctly, and matches what byCode returns for the same code',
          () {
        expect(CountryRegistry.findByCode('JP'), CountryRegistry.byCode('JP'));
        expect(CountryRegistry.findByCode('LK')?.code, 'LK');
        expect(CountryRegistry.findByCode('LK')?.displayName, 'Sri Lanka');
      });

      test('an unknown code returns null -- never a silently substituted fallback country', () {
        expect(CountryRegistry.findByCode('ZZ'), isNull);
      });

      test('a null code returns null', () {
        expect(CountryRegistry.findByCode(null), isNull);
      });

      test('an empty code returns null', () {
        expect(CountryRegistry.findByCode(''), isNull);
      });

      test('is case-sensitive, matching byCode\'s own comparison', () {
        expect(CountryRegistry.findByCode('jp'), isNull);
      });
    });
  });
}
