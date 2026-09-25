import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../app_database.dart';

/// Checkpoint G: minimal repository for `FinancialInstitutions` -- the
/// Add Account UX's optional institution selector (docs/20 §12.1) needs
/// somewhere to list a profile's existing institutions and to reuse one
/// by name rather than creating a duplicate row every time a user types
/// the same bank name twice. This is deliberately NOT a full
/// institution-management product -- the checkpoint's own brief is
/// explicit that no edit/merge/logo/branch UX belongs here. Exactly two
/// operations exist.
///
/// **Deduplication is deterministic, never fuzzy** (the checkpoint's own
/// brief prefers "a simple mechanism (e.g., exact-match reuse) over
/// building fuzzy matching for V1"): [findOrCreate] reuses an existing
/// active institution for the same profile only when its `name`,
/// trimmed, is exactly equal (case-insensitively) to the requested
/// name, trimmed. "Chase" and "chase " reuse the same row; "Chase Bank"
/// and "Chase" do not.
class FinancialInstitutionRepository {
  FinancialInstitutionRepository(this._db);

  final AppDatabase _db;
  static const Uuid _uuid = Uuid();

  /// All active (non-soft-deleted) institutions for [profileId],
  /// ordered by name -- the Add Account UX's institution picker list.
  Stream<List<FinancialInstitutionRow>> watchActiveForProfile(String profileId) {
    final query = _db.select(_db.financialInstitutions)
      ..where((tbl) => tbl.profileId.equals(profileId) & tbl.deletedAt.isNull())
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.name)]);
    return query.watch();
  }

  /// Returns the id of an existing active institution belonging to
  /// [profileId] whose `name`, trimmed, matches [name], trimmed,
  /// case-insensitively -- or creates a new one and returns its id if
  /// none exists. Never fuzzy-matches (see class doc). [name] is stored
  /// trimmed, with its original casing preserved as typed by whichever
  /// caller first created the row for that name -- a later caller
  /// typing different casing for the same (case-insensitive) name
  /// reuses that existing row rather than creating a second one or
  /// rewriting its casing.
  ///
  /// Throws [ArgumentError] if [name], trimmed, is empty.
  Future<String> findOrCreate({
    required String profileId,
    required String name,
    String? countryCode,
  }) async {
    final String trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be blank.');
    }
    final List<FinancialInstitutionRow> existing = await (_db.select(_db.financialInstitutions)
          ..where((tbl) => tbl.profileId.equals(profileId) & tbl.deletedAt.isNull()))
        .get();
    for (final FinancialInstitutionRow row in existing) {
      if (row.name.trim().toLowerCase() == trimmedName.toLowerCase()) {
        return row.id;
      }
    }
    final String id = _uuid.v4();
    final DateTime now = DateTime.now().toUtc();
    await _db.into(_db.financialInstitutions).insert(
          FinancialInstitutionsCompanion.insert(
            id: id,
            profileId: profileId,
            name: trimmedName,
            countryCode: Value<String?>(countryCode),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }
}
