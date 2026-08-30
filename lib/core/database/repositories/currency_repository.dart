import '../app_database.dart';

/// Read access to the seeded `currencies` table. Beta 0 does not let
/// users add/edit currencies — the registry is fixed seed data (see
/// `lib/core/currency/currency_registry.dart`) surfaced here purely for
/// UI (e.g. a currency picker) to read from the database rather than the
/// static list directly, so the database stays the single runtime source
/// of truth once the app has launched once.
class CurrencyRepository {
  CurrencyRepository(this._db);

  final AppDatabase _db;

  Stream<List<CurrencyRow>> watchActive() {
    return (_db.select(_db.currencies)..where((tbl) => tbl.isActive.equals(true))).watch();
  }

  Future<List<CurrencyRow>> getActive() {
    return (_db.select(_db.currencies)..where((tbl) => tbl.isActive.equals(true))).get();
  }

  Future<CurrencyRow> requireByCode(String code) {
    return (_db.select(_db.currencies)..where((tbl) => tbl.code.equals(code))).getSingle();
  }
}
