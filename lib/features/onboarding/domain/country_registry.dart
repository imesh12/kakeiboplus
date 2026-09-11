import 'package:meta/meta.dart';

/// A small country list for onboarding's country pickers, each paired
/// with the currency it's most likely to default to. This is
/// intentionally the same 13-country/13-currency set as
/// `CurrencyRegistry.seed` (see `lib/core/currency/currency_registry.dart`)
/// — the countries named across the Blueprint V2 personas and OCR
/// test-country lists — rather than a full ISO 3166 list. The currency
/// and country pickers in the onboarding form are independent controls
/// (a user can pick any seeded currency regardless of country); this
/// list only supplies a sensible default so onboarding doesn't start
/// with an arbitrary currency selected.
@immutable
class OnboardingCountry {
  const OnboardingCountry(this.code, this.displayName, this.defaultCurrencyCode);

  /// ISO 3166-1 alpha-2 code.
  final String code;
  final String displayName;
  final String defaultCurrencyCode;
}

class CountryRegistry {
  CountryRegistry._();

  static const List<OnboardingCountry> all = <OnboardingCountry>[
    OnboardingCountry('JP', 'Japan', 'JPY'),
    OnboardingCountry('KR', 'South Korea', 'KRW'),
    OnboardingCountry('VN', 'Vietnam', 'VND'),
    OnboardingCountry('KW', 'Kuwait', 'KWD'),
    OnboardingCountry('LK', 'Sri Lanka', 'LKR'),
    OnboardingCountry('NP', 'Nepal', 'NPR'),
    OnboardingCountry('IN', 'India', 'INR'),
    OnboardingCountry('BD', 'Bangladesh', 'BDT'),
    OnboardingCountry('MM', 'Myanmar', 'MMK'),
    OnboardingCountry('QA', 'Qatar', 'QAR'),
    OnboardingCountry('CA', 'Canada', 'CAD'),
    OnboardingCountry('IE', 'Ireland', 'EUR'),
    OnboardingCountry('US', 'United States', 'USD'),
  ];

  static OnboardingCountry byCode(String code) =>
      all.firstWhere((c) => c.code == code, orElse: () => all.first);

  /// Safe lookup by ISO code for International / Localization Foundation
  /// Checkpoint 3A: returns `null` for `null`, empty, or any code not in
  /// [all], rather than silently falling back to a default country.
  ///
  /// [byCode] above exists specifically for onboarding's country picker,
  /// where the control always needs *some* valid selection and falling
  /// back to [all]'s first entry is the right default-selection
  /// behavior -- that method is unchanged and still used that way.
  /// [findByCode] must be used instead anywhere an *existing persisted*
  /// value (e.g. a profile's already-stored `home_country` /
  /// `current_country`) needs to be distinguished from a genuinely known
  /// one: an unrecognized existing value must never be silently
  /// reinterpreted as Japan (or any other country) merely by reading it.
  /// Exact (case-sensitive) match, matching [byCode]'s own comparison.
  static OnboardingCountry? findByCode(String? code) {
    if (code == null) return null;
    for (final OnboardingCountry country in all) {
      if (country.code == code) return country;
    }
    return null;
  }
}
