import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../app_database.dart';

/// A small starter set of system categories, seeded once so onboarding
/// isn't a blank slate. Users can add their own categories on top; Beta 0
/// has no UI to edit/remove the system set. `id`s are fixed strings
/// (rather than generated UUIDs) so seeding is idempotent —
/// `insertOrIgnore` makes re-seeding a no-op after the first run.
///
/// Checkpoint U1 (Category, Service, Currency & Card Visual Identity
/// Foundation): each seed now also carries a fixed [colorKey] --
/// `lib/features/categories/domain/category_color.dart`'s
/// `CategoryColorKey.storageValue`. These are the exact same 8
/// id -> color assignments `app_database.dart`'s v13 -> v14 migration
/// backfills for an UPGRADING install; keeping both lists in sync is
/// what makes a fresh install (`onCreate` -> this seed) and an upgraded
/// install (migration backfill) end up with identical system-category
/// colors -- see that migration step's own comment for why the
/// migration itself uses frozen literals rather than importing this
/// file.
class _SystemCategorySeed {
  const _SystemCategorySeed(this.id, this.name, this.type, this.icon, this.colorKey);
  final String id;
  final String name;
  final String type; // 'expense' | 'income'
  final String icon;
  final String colorKey; // CategoryColorKey.storageValue
}

const List<_SystemCategorySeed> _systemCategories = <_SystemCategorySeed>[
  _SystemCategorySeed('sys-groceries', 'Groceries', 'expense', 'shopping_cart', 'green'),
  _SystemCategorySeed('sys-transport', 'Transport', 'expense', 'directions_bus', 'blue'),
  _SystemCategorySeed('sys-bills', 'Bills & Utilities', 'expense', 'receipt_long', 'amber'),
  _SystemCategorySeed('sys-dining', 'Dining Out', 'expense', 'restaurant', 'orange'),
  _SystemCategorySeed('sys-health', 'Health', 'expense', 'local_hospital', 'red'),
  _SystemCategorySeed('sys-other-expense', 'Other', 'expense', 'category', 'slate'),
  _SystemCategorySeed('sys-salary', 'Salary', 'income', 'work', 'teal'),
  _SystemCategorySeed('sys-other-income', 'Other Income', 'income', 'attach_money', 'lime'),
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
            colorKey: Value<String?>(seed.colorKey),
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
    String? colorKey,
  }) async {
    final String id = _uuid.v4();
    await _db.into(_db.categories).insert(
          CategoriesCompanion.insert(
            id: id,
            profileId: Value<String?>(profileId),
            type: type,
            name: name,
            icon: Value<String?>(icon),
            colorKey: Value<String?>(colorKey),
          ),
        );
    return id;
  }

  /// Checkpoint U1: updates a category's visual identity ([icon]/
  /// [colorKey]) and, for a non-system category only, its [name].
  ///
  /// [name] is `null` to leave the name unchanged -- the category icon/
  /// color picker (`categories_screen.dart`'s edit dialog) never offers a
  /// name field for a system category (`CategoryRow.isSystem`), matching
  /// this class's own pre-existing "Beta 0 has no UI to edit/remove the
  /// system set" boundary: a system category's fixed `id`/`name`/`type`
  /// stay exactly as seeded, but its presentation-only `icon`/`colorKey`
  /// -- the whole point of this checkpoint -- can still be customized by
  /// the user, since neither ever affects `FinanceEngine`/any balance,
  /// budget, or goal calculation. [icon]/[colorKey] are written
  /// unconditionally (never merged/skipped when null) -- the caller
  /// always passes the picker's full current selection, exactly like
  /// [createCategory] already does.
  Future<void> updateCategory({
    required String id,
    String? name,
    required String? icon,
    required String? colorKey,
  }) {
    return (_db.update(_db.categories)..where((tbl) => tbl.id.equals(id))).write(
      CategoriesCompanion(
        name: name == null ? const Value<String>.absent() : Value<String>(name),
        icon: Value<String?>(icon),
        colorKey: Value<String?>(colorKey),
      ),
    );
  }
}
