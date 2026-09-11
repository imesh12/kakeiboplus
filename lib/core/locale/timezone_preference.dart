/// Pure, deterministic timezone PRESENTATION preference metadata for
/// Checkpoint 3A of the International / Localization Foundation.
///
/// This is presentation-preference METADATA only:
///
///  * No device-timezone detection happens here. `flutter_timezone` /
///    `FlutterTimezone.getLocalTimezone()` are deliberately NOT used in
///    this checkpoint -- see `lib/core/notifications/local_notification_scheduler.dart`
///    for the app's one existing, unrelated use of that package (local
///    notification scheduling), which this file does not touch and does
///    not depend on.
///  * `Profile.timezone` is not consumed by any computation anywhere in
///    the app today (see the timezone-convention note in
///    `lib/features/budgets/domain/budget_month.dart`), so selecting a
///    value here cannot change recurrence calendar-day semantics or any
///    stored `DateTime` -- there is nothing yet that reads this field
///    for that purpose.
///  * Like `date_format_preference.dart` / `number_format_preference.dart`,
///    this is a deterministic, side-effect-free metadata registry: no
///    database access, no formatting actually performed, just the
///    catalog a future presentation layer will consult.
///
/// A deliberately small, curated list -- not the full ~400-entry IANA
/// timezone database the `timezone` package carries (see
/// `local_notification_scheduler.dart` for where that full database is
/// already used elsewhere in the app) -- matching the 13 onboarding
/// countries (`lib/features/onboarding/domain/country_registry.dart`)
/// plus UTC. A full searchable picker is out of scope for this
/// checkpoint.
library;

/// A timezone presentation preference, identified by its IANA id.
class TimezonePreference {
  const TimezonePreference({required this.id, required this.englishName});

  /// The persisted IANA timezone identifier, e.g. 'Asia/Tokyo'. Persisted
  /// as `Profiles.timezone`. IANA ids are case-sensitive by convention --
  /// [TimezoneRegistry.byId] does an exact-match lookup, matching this
  /// project's existing `DateFormatRegistry`/`NumberFormatRegistry`
  /// id-lookup convention (no case-folding).
  final String id;

  /// English display name for UI display before translations exist, e.g.
  /// "Tokyo".
  final String englishName;
}

/// Registry of selectable timezone presentation preferences.
class TimezoneRegistry {
  const TimezoneRegistry._();

  static const TimezonePreference utc = TimezonePreference(id: 'UTC', englishName: 'UTC');
  static const TimezonePreference tokyo =
      TimezonePreference(id: 'Asia/Tokyo', englishName: 'Tokyo');
  static const TimezonePreference seoul =
      TimezonePreference(id: 'Asia/Seoul', englishName: 'Seoul');
  static const TimezonePreference hoChiMinhCity =
      TimezonePreference(id: 'Asia/Ho_Chi_Minh', englishName: 'Ho Chi Minh City');
  static const TimezonePreference kuwaitCity =
      TimezonePreference(id: 'Asia/Kuwait', englishName: 'Kuwait City');
  static const TimezonePreference colombo =
      TimezonePreference(id: 'Asia/Colombo', englishName: 'Colombo');
  static const TimezonePreference kathmandu =
      TimezonePreference(id: 'Asia/Kathmandu', englishName: 'Kathmandu');
  static const TimezonePreference kolkata =
      TimezonePreference(id: 'Asia/Kolkata', englishName: 'Kolkata');
  static const TimezonePreference dhaka =
      TimezonePreference(id: 'Asia/Dhaka', englishName: 'Dhaka');
  static const TimezonePreference yangon =
      TimezonePreference(id: 'Asia/Yangon', englishName: 'Yangon');
  static const TimezonePreference qatar =
      TimezonePreference(id: 'Asia/Qatar', englishName: 'Qatar');
  static const TimezonePreference toronto =
      TimezonePreference(id: 'America/Toronto', englishName: 'Toronto');
  static const TimezonePreference dublin =
      TimezonePreference(id: 'Europe/Dublin', englishName: 'Dublin');
  static const TimezonePreference newYork =
      TimezonePreference(id: 'America/New_York', englishName: 'New York');

  /// The user-selectable preferences -- this deliberately small curated
  /// list, not the full IANA database. See the library doc comment.
  static const List<TimezonePreference> supported = <TimezonePreference>[
    utc,
    tokyo,
    seoul,
    hoChiMinhCity,
    kuwaitCity,
    colombo,
    kathmandu,
    kolkata,
    dhaka,
    yangon,
    qatar,
    toronto,
    dublin,
    newYork,
  ];

  /// Safe default for missing, unknown, or corrupt persisted values.
  static const TimezonePreference fallback = utc;

  /// Looks up a preference by its persisted IANA id. Exact (case-sensitive)
  /// match -- matching both IANA's own case-sensitive identifier
  /// convention and this project's existing `DateFormatRegistry`/
  /// `NumberFormatRegistry` id-lookup behavior. Returns [fallback] for
  /// `null` or anything not in [supported] -- this must never throw,
  /// since it may be fed old or corrupt persisted data. This is a
  /// presentation-resolution lookup only: it never reads from or writes
  /// to the database, and calling it does not rewrite whatever raw value
  /// is actually persisted (see `ProfileRepository` -- persistence never
  /// normalizes through this registry).
  static TimezonePreference byId(String? id) {
    if (id == null) return fallback;
    for (final TimezonePreference preference in supported) {
      if (preference.id == id) return preference;
    }
    return fallback;
  }
}
