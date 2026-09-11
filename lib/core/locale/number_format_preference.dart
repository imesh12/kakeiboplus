/// Pure, deterministic number-format PRESENTATION preference metadata for
/// Checkpoint 1 of the International / Localization Foundation.
///
/// This is presentation policy ONLY. It never changes stored `Money`,
/// `Currency.minorUnits`, arithmetic, or parsing invariants -- see
/// `lib/core/money/money_formatter.dart` (untouched by this checkpoint)
/// for the actual deterministic Money-to-string formatter. This file
/// exists so a future checkpoint has a policy seam to plug into, without
/// having modified `MoneyFormatter` speculatively today.
library;

/// A grouping/decimal separator style for presenting numbers.
/// Deliberately minimal: only a flat pair of separators. Does NOT model
/// positional grouping rules (e.g. Indian 2-3-2 / lakh-crore grouping),
/// which need more than a single separator to express and are
/// explicitly deferred.
class NumberFormatPreference {
  const NumberFormatPreference({
    required this.id,
    required this.groupSeparator,
    required this.decimalSeparator,
  });

  /// Stable persisted identifier. Persisted as `Profiles.numberFormat`.
  final String id;

  /// Separator inserted between digit groups, e.g. ',' in "1,234,567".
  final String groupSeparator;

  /// Separator between the integer and fractional parts, e.g. '.' in
  /// "1.89".
  final String decimalSeparator;
}

/// Registry of selectable number-format presentation preferences.
class NumberFormatRegistry {
  const NumberFormatRegistry._();

  /// Style A: 1,234,567.89 -- matches the separators `MoneyFormatter`
  /// already defaults to today.
  static const NumberFormatPreference commaGroupPeriodDecimal = NumberFormatPreference(
    id: 'comma_period',
    groupSeparator: ',',
    decimalSeparator: '.',
  );

  /// Style B: 1.234.567,89
  static const NumberFormatPreference periodGroupCommaDecimal = NumberFormatPreference(
    id: 'period_comma',
    groupSeparator: '.',
    decimalSeparator: ',',
  );

  /// The user-selectable preferences. Exactly these two styles for this
  /// checkpoint -- Indian grouping and any other style are explicitly
  /// out of scope. This list intentionally excludes legacy raw values;
  /// see [_legacyAliases].
  static const List<NumberFormatPreference> supported = <NumberFormatPreference>[
    commaGroupPeriodDecimal,
    periodGroupCommaDecimal,
  ];

  /// Safe default for missing, unknown, or corrupt persisted values.
  static const NumberFormatPreference fallback = commaGroupPeriodDecimal;

  /// Explicit legacy aliases: raw values that existing persisted profile
  /// data may already contain, mapped to the preference they are known
  /// to mean. Kept separate from [supported] -- and from generic
  /// unknown-value fallback -- so it is clear these are deliberately
  /// recognized, not an accident of [fallback] happening to match. Not
  /// user-selectable: a Settings UI iterating [supported] will never
  /// offer these as choices.
  static const Map<String, NumberFormatPreference> _legacyAliases =
      <String, NumberFormatPreference>{
    // Onboarding has persisted this literal intl-style skeleton as
    // `Profiles.numberFormat` since Beta 0. It renders identically to
    // [commaGroupPeriodDecimal], so existing profiles get correct
    // behavior without a data migration.
    '#,##0.##': commaGroupPeriodDecimal,
  };

  /// Looks up a preference by its persisted id. Recognizes both the
  /// stable [supported] ids and the [_legacyAliases] raw values. Returns
  /// [fallback] for `null` or anything else unrecognized -- this must
  /// never throw, since it may be fed old or corrupt persisted data.
  static NumberFormatPreference byId(String? id) {
    if (id == null) return fallback;
    final NumberFormatPreference? legacy = _legacyAliases[id];
    if (legacy != null) return legacy;
    for (final NumberFormatPreference preference in supported) {
      if (preference.id == id) return preference;
    }
    return fallback;
  }
}
