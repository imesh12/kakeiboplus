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
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/theme/app_typography.dart';
import '../../onboarding/domain/country_registry.dart';
import '../../onboarding/presentation/profile_providers.dart';

/// International / Localization Foundation Checkpoint 3B: one lightweight
/// screen for viewing/editing the 8 preference fields CP3A's
/// `ProfileRepository.updateInternationalPreferences` already persists
/// atomically. UI/navigation only -- no schema, repository, MoneyFormatter,
/// transaction, or recurrence change lives here.
///
/// Checkpoint 4.3 moves this screen's own static chrome (title, section
/// headers, field labels, Save) onto `AppLocalizations`, and makes
/// Japanese a normal selectable [_languageCodes] entry alongside English
/// -- see [_languageLabel]. The dynamic, per-item registry labels below
/// (`_countryLabel`, `_currencyLabel`, `_dateFormatLabel`,
/// `_numberFormatLabel`, `_timezoneLabel`) are deliberately OUT of CP4.3's
/// scope and stay English literals -- translating 14+ country/currency/
/// timezone display names and format examples is a separate, much larger
/// effort, not part of this checkpoint's small proof surface.
///
/// Checkpoint 6.8 (Localization Phase 1) finishes this screen's remaining
/// two literal-English messages -- the profile-load error (reuses the
/// same `couldNotLoadProfile` key `SettingsScreen` uses, since both
/// screens hit the exact same error branch on the exact same
/// `activeProfileProvider`) and the Save-failure message (a new
/// `couldNotSavePreferencesMessage` key, kept separate from the
/// similarly-generic `couldNotSaveTransaction` key so a save failure here
/// is never conflated with a transaction save failure even though the
/// English text happens to coincide). `_save` resolves `l10n` once,
/// before its first `await`, matching this project's established
/// pattern (see `RecurringScreen._submit`). [_languageLabel] is left
/// exactly as CP4.3 defined it -- still English self-names ("English"/
/// "Japanese") for both options regardless of the active UI locale.
/// Showing each language's own native name instead (e.g. "日本語") would
/// be a reasonable follow-up, but changing it now would also mean
/// rewriting two already-passing tests below for a purely cosmetic
/// change outside this checkpoint's mandate, so it's deliberately
/// deferred rather than bundled in here.
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
  static final List<String> _languageCodes = <String>[
    AppLanguageRegistry.english.code,
    AppLanguageRegistry.japanese.code,
  ];
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
    final AppLocalizations l10n = AppLocalizations.of(context);
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
      if (mounted) setState(() => _errorMessage = l10n.couldNotSavePreferencesMessage('$e'));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<ProfileRow?> profileAsync = ref.watch(activeProfileProvider);
    final ColorScheme colors = Theme.of(context).colorScheme;
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.internationalPreferences)),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace st) => Center(child: Text(l10n.couldNotLoadProfile('$e'))),
        data: (ProfileRow? profile) {
          if (profile == null) return const SizedBox.shrink();
          _ensureSeeded(profile);

          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: <Widget>[
                // CP7.9: `context.appTypography.sectionTitle` -- the same
                // section-header role every other converged screen uses --
                // instead of raw `Theme.of(context).textTheme.titleMedium`,
                // which rendered this (and the two section headers below)
                // visibly lighter than every other section header in the
                // app (`sectionTitle` adds `FontWeight.w600`). Text/labels
                // unchanged.
                Text(l10n.locationSection, style: context.appTypography.sectionTitle),
                const SizedBox(height: 8),
                _DropdownField(
                  key: const Key('homeCountryField'),
                  label: l10n.homeCountry,
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
                  label: l10n.currentCountry,
                  value: _currentCountry!,
                  items: _itemsPreservingCurrentValue(
                    currentValue: _currentCountry!,
                    knownValues: _countryCodes,
                    labelFor: _countryLabel,
                  ),
                  onChanged: (String v) => setState(() => _currentCountry = v),
                ),
                const SizedBox(height: 24),
                Text(l10n.currencySection, style: context.appTypography.sectionTitle),
                const SizedBox(height: 8),
                _DropdownField(
                  key: const Key('homeCurrencyField'),
                  label: l10n.homeCurrency,
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
                  label: l10n.livingCurrency,
                  value: _livingCurrency!,
                  items: _itemsPreservingCurrentValue(
                    currentValue: _livingCurrency!,
                    knownValues: _currencyCodes,
                    labelFor: _currencyLabel,
                  ),
                  onChanged: (String v) => setState(() => _livingCurrency = v),
                ),
                const SizedBox(height: 24),
                Text(l10n.languageAndFormatSection, style: context.appTypography.sectionTitle),
                const SizedBox(height: 8),
                _DropdownField(
                  key: const Key('languageField'),
                  label: l10n.language,
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
                  label: l10n.dateFormat,
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
                  label: l10n.numberFormat,
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
                  label: l10n.timezone,
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
                      : Text(l10n.save),
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
    for (final String v in knownValues) _dropdownItem(v, labelFor(v)),
  ];
  if (!knownValues.contains(currentValue)) {
    items.insert(0, _dropdownItem(currentValue, labelFor(currentValue)));
  }
  return items;
}

/// Builds one dropdown item whose label is protected against overflow --
/// International / Localization Foundation Checkpoint 5.3. A plain
/// `Text` here would render with the default `TextOverflow.clip`, so a
/// long localized display name (a future language's country/timezone
/// name, or a synthetic "Unknown (...)" label for an unrecognized
/// persisted value) could silently overflow this dropdown's bounded
/// width at narrow screens or large text scales -- both when this item
/// is shown inside the open menu and when it's the one currently
/// selected and shown inside the closed field itself (`DropdownButton`
/// reuses the same item widget for both roles here; `_DropdownField`
/// below supplies no separate `selectedItemBuilder`). `maxLines: 1` +
/// `TextOverflow.ellipsis` lets the label yield gracefully instead --
/// nothing about the *persisted* `value` changes, only how its label is
/// presented when there isn't room for all of it. Used uniformly for
/// every known item and the synthetic current-value item alike, so the
/// unknown-value display path gets the exact same protection as every
/// other one, with no per-field or per-registry branching.
DropdownMenuItem<String> _dropdownItem(String value, String label) {
  return DropdownMenuItem<String>(
    value: value,
    child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, softWrap: false),
  );
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

/// English display name for a known, currently-selectable language
/// ('en' or 'ja' -- see [_languageCodes]); a safe "Unknown (...)" label
/// for anything [AppLanguageRegistry] doesn't recognize at all. Never
/// calls [AppLanguageRegistry.byCode] here -- that method's English
/// fallback exists for a different purpose (a safe default when nothing
/// is persisted yet) and would incorrectly mask a genuinely unknown code
/// as if it were English. (Checkpoint 4.3: both languages
/// [AppLanguageRegistry.knownLanguages] currently contains are
/// selectable, so there is no longer a "known but not yet selectable"
/// case to special-case here -- that branch existed only for 'ja' prior
/// to this checkpoint.)
String _languageLabel(String code) {
  for (final AppLanguage language in AppLanguageRegistry.knownLanguages) {
    if (language.code.toLowerCase() == code.toLowerCase()) {
      return language.englishName;
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
        // CP5.3: without `isExpanded`, this button sizes itself to the
        // intrinsic width of its widest item -- forcing the field itself
        // to grow rather than letting a long label yield -- which is
        // exactly backwards for narrow screens/large text scales. With
        // `isExpanded: true`, the button instead fills the available
        // width the surrounding `InputDecorator` already gives it, so
        // each item's own `maxLines: 1` + `TextOverflow.ellipsis` (see
        // `_dropdownItem`) can actually take effect.
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: items,
        onChanged: (String? v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}
