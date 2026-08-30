import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../app_database.dart';

/// A small starter set of system categories, seeded once so onboarding
/// isn't a blank slate. Users can add their own categories on top; Beta 0
/// has no UI to edit/remove the system set. `id`s are fixed strings
/// (rather than generated UUIDs) so seeding is idempotent —
/// `insertOrIgnore` makes re-seeding a no-op after the first run.
class _SystemCategorySeed {
  const _SystemCategorySeed(this.id, this.name, this.type, this.icon);
  final String id;
  final String name;
  final String type; // 'expense' | 'income'
  final String icon;
}

const List<_SystemCategorySeed> _systemCategories = <_SystemCategorySeed>[
  _SystemCategorySeed('sys-groceries', 'Groceries', 'expense', 'shopping_cart'),
  _SystemCategorySeed('sys-transport', 'Transport', 'expense', 'directions_bus'),
  _SystemCategorySeed('sys-bills', 'Bills & Utilities', 'expense', 'receipt_long'),
  _SystemCategorySeed('sys-dining', 'Dining Out', 'expense', 'restaurant'),
  _SystemCategorySeed('sys-health', 'Health', 'expense', 'local_hospital'),
  _SystemCategorySeed('sys-other-expense', 'Other', 'expense', 'category'),
  _SystemCategorySeed('sys-salary', 'Salary', 'income', 'work'),
  _SystemCategorySeed('sys-other-income', 'Other Income', 'income', 'attach_money'),
];

class CategoryRepository {
  CategoryRepository(this._db);

  final AppDatabase _db;
  static const Uuid _uuid = Uuid();

  /// Inserts the system category set if it isn't already present. Safe
  /// to call on every app start — `insertOrIgnore` makes it a no-op
  /// after the first run.
  Future<void> seedSystemCategoriesIfNeeded() async {
    await _db.batch((Batch b) {
      b.insertAll(
        _db.categories,
        _systemCategories.map(
          (seed) => CategoriesCompanion.insert(
            id: seed.id,
            profileId: const Value<String?>(null),
            type: seed.type,
            name: seed.name,
            icon: Value<String?>(seed.icon),
            isSystem: const Value<bool>(true),
          ),
        ),
        mode: InsertMode.insertOrIgnore,
      );
    });
  }

  /// System categories (profileId is null) plus any the given profile has
  /// added of its own, filtered to categories usable for [type]
  /// ('expense' or 'income' — 'both' categories always match).
  Stream<List<CategoryRow>> watchAvailableFor({
    required String profileId,
    required String type,
  }) {
    final query = _db.select(_db.categories)
      ..where(
        (tbl) =>
            (tbl.profileId.equals(profileId) | tbl.profileId.isNull()) &
            tbl.isActive.equals(true) &
            (tbl.type.equals(type) | tbl.type.equals('both')),
      )
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.sortOrder), (tbl) => OrderingTerm.asc(tbl.name)]);
    return query.watch();
  }

  Future<CategoryRow> requireById(String id) {
    return (_db.select(_db.categories)..where((tbl) => tbl.id.equals(id))).getSingle();
  }

  Future<String> createCategory({
    required String profileId,
    required String name,
    required String type,
    String? icon,
  }) async {
    final String id = _uuid.v4();
    await _db.into(_db.categories).insert(
          CategoriesCompanion.insert(
            id: id,
            profileId: Value<String?>(profileId),
            type: type,
            name: name,
            icon: Value<String?>(icon),
          ),
        );
    return id;
  }
}
