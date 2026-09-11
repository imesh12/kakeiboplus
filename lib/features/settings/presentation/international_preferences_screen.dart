import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/currency/currency.dart';
import '../../../core/currency/currency_registry.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/providers.dart';
import '../../../core/locale/app_language.dart';
import '../../../core/locale/date_format_preference.dart';
import '../../../core/locale/number_format_preference.dart';
import '../../../core/locale/timezone_preference.dart';
import '../../onboarding/domain/country_registry.dart';
import '../../onboarding/presentation/profile_providers.dart';

/// International / Localization Foundation Checkpoint 3B: one lightweight
/// screen for viewing/editing the 8 preference fields CP3A's
/// `ProfileRepository.updateInternationalPreferences` already persists
/// atomically. UI/navigation only -- no schema, repository, MoneyFormatter,
/// transaction, or recurrence change lives here.
///
/// # Raw-value-is-source-of-truth policy (critical -- see CP3 audit +
/// CP3A's "critical unknown-value safety" rule)
///
/// Every field's local state variable below is seeded ONCE, directly from
/// the persisted [ProfileRow] (see [_ensureSeeded]), and is the exact
/// value [_save] sends back to `updateInternationalPreferences` --
/// unchanged, for any field the user never touches. Nothing in this file
/// ever resolves a raw value through a registry and then stores the
/// *resolved* value back as if it were the user's selection: registries
/// are consulted ONLY to decide what label to show for a value, never to
/// decide what value to persist. That is what guarantees: opening this
/// screen never mutates persistence; an existing unknown/legacy value
/// (e.g. a country code CountryRegistry doesn't know, or the historical
/// raw `date_format`/`number_format` strings onboarding wrote before this
/// checkpoint) survives a Save that only changed a *different* field,
/// completely unchanged, not silently canonicalized.
///
/// Each dropdown's item list is built by [_itemsPreservingCurrentValue]:
/// the registry's normal selectable options, PLUS -- only when the
/// field's current raw value isn't one of them -- one extra synthetic
/// item whose `value` is that exact raw string, labeled safely (never a
/// crash, never a silent substitution of some other persisted-looking
/// value). Selecting that synthetic item is a no-op (it's already what's
/// there); selecting any other item is what actually changes what gets
/// saved.
class InternationalPreferencesScreen extends ConsumerStatefulWidget {
  const InternationalPreferencesScreen({super.key});

  @override
  ConsumerState<InternationalPreferencesScreen> createState() =>
      _InternationalPreferencesScreenState();
}

class _InternationalPreferencesScreenState extends ConsumerState<InternationalPreferencesScreen> {
  static final List<String> _countryCodes =
      CountryRegistry.all.map((OnboardingCountry c) => c.code).toList();
  static final List<String> _currencyCodes =
      CurrencyRegistry.seed.map((Currency c) => c.code).toList();
  static final List<String> _languageCodes = <String>[AppLanguageRegistry.english.code];
  static final List<String> _dateFormatIds =
      DateFormatRegistry.supported.map((DateFormatPreference p) => p.id).toList();
  static final List<String> _numberFormatIds =
      NumberFormatRegistry.supported.map((NumberFormatPreference p) => p.id).toList();
  static final List<String> _timezoneIds =
      TimezoneRegistry.supported.map((TimezonePreference p) => p.id).toList();

  bool _seeded = false;
  String? _profileId;
  String? _homeCountry;
  String? _currentCountry;
  String? _homeCurrency;
  String? _livingCurrency;
  String? _preferredLanguage;
  String? _timezone;
  String? _dateFormat;
  String? _numberFormat;

  bool _isSaving = false;
  String? _errorMessage;

  /// Seeds every field from the persisted [ProfileRow] exactly once --
  /// never again for the lifetime of this screen, even if the profile
  /// stream re-emits (e.g. right after this screen's own successful
  /// Save). This is what makes "opening the screen performs no write"
  /// and "raw values are the source of truth" hold: nothing here ever
  /// re-derives a field from a registry's resolved/canonical form.
  void _ensureSeeded(ProfileRow profile) {
    if (_seeded) return;
    _seeded = true;
    _profileId = profile.id;
    _homeCountry = profile.homeCountry;
    _currentCountry = profile.currentCountry;
    _homeCurrency = profile.homeCurrency;
    _livingCurrency = profile.livingCurrency;
    _preferredLanguage = profile.preferredLanguage;
    _timezone = profile.timezone;
    _dateFormat = profile.dateFormat;
    _numberFormat = profile.numberFormat;
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      await ref.read(profileRepositoryProvider).updateInternationalPreferences(
            profileId: _profileId!,
            homeCountry: _homeCountry!,
            currentCountry: _currentCountry!,
            homeCurrency: _homeCurrency!,
            livingCurrency: _livingCurrency!,
            preferredLanguage: _preferredLanguage!,
            timezone: _timezone!,
            dateFormat: _dateFormat!,
            numberFormat: _numberFormat!,
          );
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Could not save: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<ProfileRow?> profileAsync = ref.watch(activeProfileProvider);
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('International preferences')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace st) => Center(child: Text('Could not load profile: $e')),
        data: (ProfileRow? profile) {
          if (profile == null) return const SizedBox.shrink();
          _ensureSeeded(profile);

          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: <Widget>[
                Text('Location', style: text.titleMedium),
                const SizedBox(height: 8),
                _DropdownField(
                  key: const Key('homeCountryField'),
                  label: 'Home country',
                  value: _homeCountry!,
                  items: _itemsPreservingCurrentValue(
                    currentValue: _homeCountry!,
                    knownValues: _countryCodes,
                    labelFor: _countryLabel,
                  ),
                  onChanged: (String v) => setState(() => _homeCountry = v),
                ),
                _DropdownField(
                  key: const Key('currentCountryField'),
                  label: 'Current country',
                  value: _currentCountry!,
                  items: _itemsPreservingCurrentValue(
                    currentValue: _currentCountry!,
                    knownValues: _countryCodes,
                    labelFor: _countryLabel,
                  ),
                  onChanged: (String v) => setState(() => _currentCountry = v),
                ),
                const SizedBox(height: 24),
                Text('Currency', style: text.titleMedium),
                const SizedBox(height: 8),
                _DropdownField(
                  key: const Key('homeCurrencyField'),
                  label: 'Home currency',
                  value: _homeCurrency!,
                  items: _itemsPreservingCurrentValue(
                    currentValue: _homeCurrency!,
                    knownValues: _currencyCodes,
                    labelFor: _currencyLabel,
                  ),
                  onChanged: (String v) => setState(() => _homeCurrency = v),
                ),
                _DropdownField(
                  key: const Key('livingCurrencyField'),
                  label: 'Living currency',
                  value: _livingCurrency!,
                  items: _itemsPreservingCurrentValue(
                    currentValue: _livingCurrency!,
                    knownValues: _currencyCodes,
                    labelFor: _currencyLabel,
                  ),
                  onChanged: (String v) => setState(() => _livingCurrency = v),
                ),
                const SizedBox(height: 24),
                Text('Language & format', style: text.titleMedium),
                const SizedBox(height: 8),
                _DropdownField(
                  key: const Key('languageField'),
                  label: 'Language',
                  value: _preferredLanguage!,
                  items: _itemsPreservingCurrentValue(
                    currentValue: _preferredLanguage!,
                    knownValues: _languageCodes,
                    labelFor: _languageLabel,
                  ),
                  onChanged: (String v) => setState(() => _preferredLanguage = v),
                ),
                _DropdownField(
                  key: const Key('dateFormatField'),
                  label: 'Date format',
                  value: _dateFormat!,
                  items: _itemsPreservingCurrentValue(
                    currentValue: _dateFormat!,
                    knownValues: _dateFormatIds,
                    labelFor: _dateFormatLabel,
                  ),
                  onChanged: (String v) => setState(() => _dateFormat = v),
                ),
                _DropdownField(
                  key: const Key('numberFormatField'),
                  label: 'Number format',
                  value: _numberFormat!,
                  items: _itemsPreservingCurrentValue(
                    currentValue: _numberFormat!,
                    knownValues: _numberFormatIds,
                    labelFor: _numberFormatLabel,
                  ),
                  onChanged: (String v) => setState(() => _numberFormat = v),
                ),
                _DropdownField(
                  key: const Key('timezoneField'),
                  label: 'Timezone',
                  value: _timezone!,
                  items: _itemsPreservingCurrentValue(
                    currentValue: _timezone!,
                    knownValues: _timezoneIds,
                    labelFor: _timezoneLabel,
                  ),
                  onChanged: (String v) => setState(() => _timezone = v),
                ),
                const SizedBox(height: 32),
                if (_errorMessage != null) ...<Widget>[
                  Text(_errorMessage!, style: TextStyle(color: colors.error)),
                  const SizedBox(height: 12),
                ],
                FilledButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Builds a dropdown's item list: every selectable [knownValues] entry,
/// plus -- only when [currentValue] isn't already one of them -- one
/// extra item whose `value` is [currentValue] itself, so an
/// unknown/legacy persisted value always has a matching item (Flutter's
/// `DropdownButtonFormField` requires this) without ever being silently
/// replaced by a different value. [labelFor] must be safe for ANY input
/// string, known or not -- see the per-field `_...Label` functions below,
/// each of which returns a safe "Unknown (...)"-style label instead of
/// throwing for a value outside its own registry.
List<DropdownMenuItem<String>> _itemsPreservingCurrentValue({
  required String currentValue,
  required List<String> knownValues,
  required String Function(String) labelFor,
}) {
  final List<DropdownMenuItem<String>> items = <DropdownMenuItem<String>>[
    for (final String v in knownValues) DropdownMenuItem<String>(value: v, child: Text(labelFor(v))),
  ];
  if (!knownValues.contains(currentValue)) {
    items.insert(
      0,
      DropdownMenuItem<String>(value: currentValue, child: Text(labelFor(currentValue))),
    );
  }
  return items;
}

/// English display name for a known ISO country code; a safe
/// "Unknown (...)" label for anything [CountryRegistry] doesn't
/// recognize. Deliberately uses [CountryRegistry.findByCode] (added in
/// CP3A specifically for this purpose) rather than [CountryRegistry.byCode]
/// -- `byCode`'s JP fallback is right for onboarding's always-must-pick-
/// something picker, but wrong here: an unrecognized *existing* profile
/// value must never display (and therefore never risk being saved back)
/// as if it were Japan.
String _countryLabel(String code) {
  final OnboardingCountry? country = CountryRegistry.findByCode(code);
  return country == null ? 'Unknown ($code)' : country.displayName;
}

/// Currency code plus its English display name when [CurrencyRegistry]
/// recognizes it; a safe "Unknown (...)" label otherwise.
String _currencyLabel(String code) {
  final Currency? currency = CurrencyRegistry.byCode(code);
  return currency == null ? 'Unknown ($code)' : '${currency.code} — ${currency.displayName}';
}

/// English display name for the one currently-selectable language
/// ('en'). For any other code: if [AppLanguageRegistry] already knows it
/// (e.g. 'ja' -- planned for CP4, not yet selectable), shows that known
/// name marked not-yet-selectable rather than a bare code; for a
/// genuinely unrecognized code, a safe "Unknown (...)" label. Never
/// calls [AppLanguageRegistry.byCode] here -- that method's English
/// fallback exists for a different purpose (a safe default when nothing
/// is persisted yet) and would incorrectly mask a genuinely unknown code
/// as if it were English.
String _languageLabel(String code) {
  if (code == AppLanguageRegistry.english.code) return AppLanguageRegistry.english.englishName;
  for (final AppLanguage language in AppLanguageRegistry.knownLanguages) {
    if (language.code.toLowerCase() == code.toLowerCase()) {
      return '${language.englishName} (not yet selectable)';
    }
  }
  return 'Unknown ($code)';
}

/// Understandable English example for a date format id. Any id outside
/// [DateFormatRegistry.supported] -- including the historical raw
/// `'yyyy-MM-dd'` onboarding wrote, and any genuinely corrupt value --
/// resolves visually through [DateFormatRegistry.byId]'s existing
/// alias/fallback behavior (never a crash), per CP3B's explicit policy
/// that legacy date/number values may resolve visually this way. This
/// never writes anything -- it only decides what label to show; see the
/// class doc comment on [InternationalPreferencesScreen] for why that
/// distinction matters.
String _dateFormatLabel(String id) {
  switch (id) {
    case 'ymd':
      return 'Year, Month, Day (2026-08-30)';
    case 'dmy':
      return 'Day, Month, Year (30-08-2026)';
    case 'mdy':
      return 'Month, Day, Year (08-30-2026)';
    default:
      return _dateFormatLabel(DateFormatRegistry.byId(id).id);
  }
}

/// Understandable English example for a number format id. Same
/// visual-resolution-only policy as [_dateFormatLabel], via
/// [NumberFormatRegistry.byId].
String _numberFormatLabel(String id) {
  switch (id) {
    case 'comma_period':
      return '1,234,567.89 (comma thousands)';
    case 'period_comma':
      return '1.234.567,89 (period thousands)';
    default:
      return _numberFormatLabel(NumberFormatRegistry.byId(id).id);
  }
}

/// English city name plus IANA id for a known timezone id; a safe
/// "Unknown (...)" label for anything outside [TimezoneRegistry.supported]
/// -- deliberately does NOT use [TimezoneRegistry.byId]'s UTC fallback
/// for display, for the same reason [_countryLabel] avoids `byCode`'s
/// fallback: an unrecognized existing value must never display (or risk
/// being saved back) as if it were UTC.
String _timezoneLabel(String id) {
  final bool known = TimezoneRegistry.supported.any((TimezonePreference p) => p.id == id);
  if (!known) return 'Unknown ($id)';
  if (id == 'UTC') return 'UTC';
  return '${TimezoneRegistry.byId(id).englishName} ($id)';
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: items,
        onChanged: (String? v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}
