import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../app_database.dart';

/// Beta 0 has exactly one local profile (no auth, no multi-profile
/// switching yet) — see `docs/01_MVP_SCOPE.md`. This repository reflects
/// that: there is no `profileId` parameter on the read/create methods
/// because there is, by construction, at most one row in `profiles`.
class ProfileRepository {
  ProfileRepository(this._db);

  final AppDatabase _db;
  static const Uuid _uuid = Uuid();

  /// Emits the single local profile, or `null` before onboarding has
  /// created one.
  Stream<ProfileRow?> watchProfile() {
    return _db.select(_db.profiles).watchSingleOrNull();
  }

  Future<ProfileRow?> getProfile() {
    return _db.select(_db.profiles).getSingleOrNull();
  }

  /// Creates the local profile during onboarding. Throws
  /// [StateError] if a profile already exists — onboarding should only
  /// ever run once per install in Beta 0.
  Future<String> createProfile({
    required String displayName,
    required String homeCountry,
    required String currentCountry,
    required String homeCurrency,
    required String livingCurrency,
    required String preferredLanguage,
    required String timezone,
    required String dateFormat,
    required String numberFormat,
  }) async {
    final ProfileRow? existing = await getProfile();
    if (existing != null) {
      throw StateError('A local profile already exists (id: ${existing.id}).');
    }
    final String id = _uuid.v4();
    final DateTime now = DateTime.now().toUtc();
    await _db.into(_db.profiles).insert(
          ProfilesCompanion.insert(
            id: id,
            displayName: displayName,
            homeCountry: homeCountry,
            currentCountry: currentCountry,
            homeCurrency: homeCurrency,
            livingCurrency: livingCurrency,
            preferredLanguage: preferredLanguage,
            timezone: timezone,
            dateFormat: dateFormat,
            numberFormat: numberFormat,
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Future<void> updateHomeAndLivingCurrency({
    required String profileId,
    required String homeCurrency,
    required String livingCurrency,
  }) {
    return (_db.update(_db.profiles)..where((tbl) => tbl.id.equals(profileId))).write(
      ProfilesCompanion(
        homeCurrency: Value<String>(homeCurrency),
        livingCurrency: Value<String>(livingCurrency),
        updatedAt: Value<DateTime>(DateTime.now().toUtc()),
      ),
    );
  }
}
