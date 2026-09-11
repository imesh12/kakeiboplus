/// Pure, deterministic language metadata for Checkpoint 1 of the
/// International / Localization Foundation.
///
/// This is presentation-preference METADATA only. It does not wire
/// Flutter's `Localizations` / `MaterialApp.locale` / `supportedLocales`,
/// does not load any `.arb` translation, and does not change runtime UI
/// language. `ja` is registered here as a known, planned language --
/// not yet translated, not yet selectable in any UI -- so later
/// checkpoints have a stable identifier to build against instead of
/// inventing one ad hoc.
library;

/// A language the app knows about, identified by a stable, persisted code
/// (never a translated display name -- codes are for storage/comparison;
/// [englishName] is only a readable label to show before translations
/// exist).
class AppLanguage {
  const AppLanguage({required this.code, required this.englishName});

  /// Stable identifier, e.g. 'en', 'ja'. Persisted as
  /// `Profiles.preferredLanguage`. Never a translated/localized name.
  final String code;

  /// English name for UI display before translations exist, e.g.
  /// "English", "Japanese".
  final String englishName;
}

/// Registry of language metadata known to the app.
///
/// IMPORTANT: [knownLanguages] is NOT Flutter's `supportedLocales` and
/// does not drive `MaterialApp.supportedLocales` or any `Localizations`
/// behavior. It is a deterministic metadata list for the
/// presentation-preference layer (future Settings UI, profile
/// validation) to consult. Registering a language here does not mean it
/// is translated or selectable anywhere yet.
class AppLanguageRegistry {
  const AppLanguageRegistry._();

  static const AppLanguage english = AppLanguage(code: 'en', englishName: 'English');

  /// Planned second proof language. Metadata only: no translations and no
  /// runtime locale wiring exist yet. Registering it here lets later
  /// checkpoints reference a stable 'ja' code rather than inventing one
  /// once translation work actually starts.
  static const AppLanguage japanese = AppLanguage(code: 'ja', englishName: 'Japanese');

  /// Known language metadata entries. NOT Flutter's `supportedLocales` --
  /// see the class doc comment above.
  static const List<AppLanguage> knownLanguages = <AppLanguage>[english, japanese];

  /// Safe default when a code is missing, unknown, or corrupt.
  static const AppLanguage fallback = english;

  /// Looks up a language by its stable code. Case-insensitive. Returns
  /// [fallback] for `null`, empty, or any code not in [knownLanguages] --
  /// this must never throw, since it may be fed old or corrupt persisted
  /// data.
  static AppLanguage byCode(String? code) {
    if (code == null) return fallback;
    for (final AppLanguage language in knownLanguages) {
      if (language.code.toLowerCase() == code.toLowerCase()) return language;
    }
    return fallback;
  }
}
