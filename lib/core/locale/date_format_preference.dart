/// Pure, deterministic date-format PRESENTATION preference metadata for
/// Checkpoint 1 of the International / Localization Foundation.
///
/// This is presentation policy ONLY. It never changes stored `DateTime`
/// values, transaction `occurredAt` semantics, or the deterministic UTC
/// calendar-day arithmetic in
/// `lib/features/recurring/domain/recurring_schedule.dart` -- none of
/// that is touched by this checkpoint. No date is actually rendered by
/// this file; it defines the preference metadata a future presentation
/// layer will consult. `DateFormat` is deliberately not imported here --
/// [DateFormatPreference.skeleton] is stored as a plain string, not
/// applied to anything yet.
library;

/// A date-field-order presentation preference, identified by a stable
/// persisted id.
class DateFormatPreference {
  const DateFormatPreference({required this.id, required this.skeleton});

  /// Stable persisted identifier, e.g. 'ymd', 'dmy', 'mdy'. Persisted as
  /// `Profiles.dateFormat`.
  final String id;

  /// An `intl` `DateFormat` SKELETON name (field-order only, e.g.
  /// 'yMMMd'), not a raw pattern and not yet passed to `DateFormat`
  /// anywhere. A skeleton lets a real locale later localize month
  /// names/punctuation via `DateFormat.yMMMd(locale)`; this checkpoint
  /// only stores the identifier.
  final String skeleton;
}

/// Registry of selectable date-format presentation preferences.
class DateFormatRegistry {
  const DateFormatRegistry._();

  static const DateFormatPreference yearMonthDay = DateFormatPreference(
    id: 'ymd',
    skeleton: 'yMMMd',
  );
  static const DateFormatPreference dayMonthYear = DateFormatPreference(
    id: 'dmy',
    skeleton: 'dMMMy',
  );
  static const DateFormatPreference monthDayYear = DateFormatPreference(
    id: 'mdy',
    skeleton: 'MMMdy',
  );

  /// The user-selectable preferences: exactly these three stable ids.
  /// The legacy raw pattern persisted by onboarding today
  /// (`'yyyy-MM-dd'`) is deliberately NOT included here -- see
  /// [_legacyAliases] -- so a Settings UI iterating this list will never
  /// offer it as a choice.
  static const List<DateFormatPreference> supported = <DateFormatPreference>[
    yearMonthDay,
    dayMonthYear,
    monthDayYear,
  ];

  /// Safe default for missing, unknown, or corrupt persisted values.
  static const DateFormatPreference fallback = yearMonthDay;

  /// Explicit legacy aliases: raw values that existing persisted profile
  /// data may already contain, mapped to the preference they are known
  /// to mean. Kept separate from [supported] -- and from generic
  /// unknown-value fallback -- so it is clear these are deliberately
  /// recognized, not an accident of [fallback] happening to match.
  static const Map<String, DateFormatPreference> _legacyAliases = <String, DateFormatPreference>{
    // Onboarding has persisted this literal DateTime-format pattern as
    // `Profiles.dateFormat` since Beta 0. It is year-month-day ordered,
    // so it aliases to [yearMonthDay] without a data migration.
    'yyyy-MM-dd': yearMonthDay,
  };

  /// Looks up a preference by its persisted id. Recognizes both the
  /// stable [supported] ids and the [_legacyAliases] raw values. Returns
  /// [fallback] for `null` or anything else unrecognized -- this must
  /// never throw, since it may be fed old or corrupt persisted data.
  static DateFormatPreference byId(String? id) {
    if (id == null) return fallback;
    final DateFormatPreference? legacy = _legacyAliases[id];
    if (legacy != null) return legacy;
    for (final DateFormatPreference preference in supported) {
      if (preference.id == id) return preference;
    }
    return fallback;
  }
}
