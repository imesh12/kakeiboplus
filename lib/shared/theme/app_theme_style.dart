/// Checkpoint 8.1 (Premium Theme Personalization Foundation): the closed
/// set of product themes a user can choose from, plus the stable string
/// identifier each one persists as.
///
/// This is deliberately a plain `dart:core` [enum], not Flutter's
/// [dart:ui]-adjacent `ThemeMode` -- `ThemeMode` only ever means
/// light/dark/system (an automatic, OS-brightness-driven switch), which
/// is a different and narrower concept than a 5-way *decorative*
/// product theme choice the user makes explicitly (of which "Dark" is
/// only one option, not a system-linked mode). See `app_theme.dart` for
/// how each [AppThemeStyle] resolves to an actual `ThemeData`, and
/// `app_theme_provider.dart` for how the persisted choice is read back
/// into one of these values. `lib/app/app.dart` sets `themeMode:
/// ThemeMode.light` explicitly so Flutter's own automatic dark
/// switching never fights this enum's own explicit user choice.
///
/// Exactly 5 values, per this checkpoint's explicit "do NOT add
/// additional themes in this checkpoint" instruction -- Light, Dark,
/// Pink, Ocean, Forest. Adding a 6th later is purely additive (a new
/// enum value + a new `AppTheme` factory branch) and does not require
/// touching any existing value here.
enum AppThemeStyle {
  light('light'),
  dark('dark'),
  pink('pink'),
  ocean('ocean'),
  forest('forest');

  const AppThemeStyle(this.storageValue);

  /// Stable, lowercase identifier persisted as
  /// `Profiles.themePreference` (see `tables.dart`). Never a
  /// translated/localized name -- the Theme Customization screen owns
  /// the localized display name shown to the user for each value. This
  /// must never change for an existing enum value once shipped, or
  /// every profile that persisted the old value would silently fall
  /// back to [fallback] on next read.
  final String storageValue;

  /// Safe default when a persisted value is missing, unknown, or
  /// corrupt -- also the default for a brand-new profile (kept in sync
  /// with `Profiles.themePreference`'s own column default).
  static const AppThemeStyle fallback = AppThemeStyle.light;

  /// Looks up a style by its persisted [storageValue]. Returns
  /// [fallback] for `null`, empty, or any value not among [values] --
  /// this must never throw, since it may be fed old, corrupt, or
  /// future-downgrade persisted data.
  static AppThemeStyle fromStorageValue(String? value) {
    if (value == null) return fallback;
    for (final AppThemeStyle style in AppThemeStyle.values) {
      if (style.storageValue == value) return style;
    }
    return fallback;
  }
}
