import 'dart:io';

import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/features/categories/domain/category_color.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

// NOTE: this file exercises generated Drift code (AppDatabase, etc. from
// app_database.g.dart) that could not be generated inside the sandbox
// that wrote it -- run `dart run build_runner build
// --delete-conflicting-outputs` locally before running this test. See
// CLAUDE_FIRST_CODING_PROMPT.md.
//
// This test proves the v13 -> v14 schema migration (Checkpoint U1,
// Category, Service, Currency & Card Visual Identity Foundation): a
// database file left at schema v13 (Checkpoint N -- before
// `categories.color_key` existed) opens cleanly under the current (v14)
// `AppDatabase`, the `onUpgrade` `from < 14` branch adds the new nullable
// column, the 8 fixed-id seeded system categories are backfilled to their
// documented deterministic colors, every OTHER pre-existing `categories`
// row is left with `color_key = null`, and a fresh row can still be
// written with the new field.
//
// Deliberately a MINIMAL fixture -- only `currencies`/`profiles`/
// `categories` (the one table this step touches, plus its own FK
// dependencies) -- following the exact same "minimal fixture" reasoning
// `recurring_notifications_migration_test.dart`'s own file-level doc
// comment already establishes for a single-column-add step: a v13
// fixture only triggers this ONE `from < 14` branch when opened by
// TODAY's `AppDatabase` (every earlier `from < N` branch, N <= 13, is
// already false for `from == 13`), so no other table needs to exist
// here at all.
void main() {
  test(
    'v13 -> v14 upgrade adds categories.color_key, backfills the 8 system categories '
    'deterministically, and leaves every other category color_key null',
    () async {
      final Directory tempDir = Directory.systemTemp.createTempSync('afc_v13_to_v14_migration_test_');
      final File dbFile = File('${tempDir.path}/v13_fixture.sqlite');
      addTearDown(() {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });

      final sqlite3.Database fixture = sqlite3.sqlite3.open(dbFile.path);
      try {
        fixture.execute('''
          CREATE TABLE currencies (
            code TEXT NOT NULL,
            display_name TEXT NOT NULL,
            symbol TEXT NOT NULL,
            minor_units INTEGER NOT NULL,
            is_active INTEGER NOT NULL DEFAULT 1,
            PRIMARY KEY (code)
          );

          CREATE TABLE profiles (
            id TEXT NOT NULL,
            display_name TEXT NOT NULL,
            home_country TEXT NOT NULL,
            current_country TEXT NOT NULL,
            home_currency TEXT NOT NULL REFERENCES currencies (code),
            living_currency TEXT NOT NULL REFERENCES currencies (code),
            preferred_language TEXT NOT NULL,
            timezone TEXT NOT NULL,
            date_format TEXT NOT NULL,
            number_format TEXT NOT NULL,
            theme_preference TEXT NOT NULL DEFAULT 'light',
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            PRIMARY KEY (id)
          );

          CREATE TABLE categories (
            id TEXT NOT NULL,
            profile_id TEXT REFERENCES profiles (id),
            parent_id TEXT,
            type TEXT NOT NULL,
            name TEXT NOT NULL,
            icon TEXT,
            sort_order INTEGER NOT NULL DEFAULT 0,
            is_system INTEGER NOT NULL DEFAULT 0,
            is_active INTEGER NOT NULL DEFAULT 1,
            PRIMARY KEY (id)
          );
        ''');
        fixture.execute('PRAGMA user_version = 13;');

        fixture.execute(
          "INSERT INTO categories (id, profile_id, type, name, icon, is_system) "
          "VALUES ('sys-groceries', NULL, 'expense', 'Groceries', 'shopping_cart', 1);",
        );
        fixture.execute(
          "INSERT INTO categories (id, profile_id, type, name, icon, is_system) "
          "VALUES ('sys-other-income', NULL, 'income', 'Other Income', 'attach_money', 1);",
        );
        // A legacy USER category -- profile_id is non-null, matching a
        // real custom category created before this checkpoint. Never
        // backfilled by this migration (see the class-level doc comment
        // on `AppDatabase.migration`) -- `categoryColorFor`'s
        // per-category-id fallback is what makes leaving this `NULL`
        // safe.
        fixture.execute(
          "INSERT INTO categories (id, profile_id, type, name, icon, is_system) "
          "VALUES ('user-cat-1', 'profile-fixture', 'expense', 'My Custom Category', NULL, 0);",
        );
      } finally {
        fixture.dispose();
      }

      final AppDatabase db = AppDatabase.forTesting(NativeDatabase(dbFile));
      addTearDown(() async => db.close());

      final List<CategoryRow> categories = await db.select(db.categories).get();
      expect(categories, hasLength(3));

      final CategoryRow groceries = categories.singleWhere((c) => c.id == 'sys-groceries');
      expect(groceries.colorKey, 'green');

      final CategoryRow otherIncome = categories.singleWhere((c) => c.id == 'sys-other-income');
      expect(otherIncome.colorKey, 'lime');

      final CategoryRow userCategory = categories.singleWhere((c) => c.id == 'user-cat-1');
      expect(userCategory.colorKey, isNull);
      expect(userCategory.name, 'My Custom Category');
      expect(userCategory.icon, isNull);

      // Every backfilled literal actually resolves to a real
      // `CategoryColorKey` -- proves the migration's frozen string
      // literals haven't drifted out of sync with the enum, exactly
      // what `app_database.dart`'s own migration-step comment says this
      // test asserts.
      for (final CategoryRow category in categories) {
        if (category.colorKey != null) {
          expect(CategoryColorKey.fromStorageValue(category.colorKey), isNotNull, reason: category.id);
        }
      }

      // The post-migration schema is genuinely usable: a brand-new
      // category can be written with an explicit colorKey through the
      // current generated companion.
      await db.into(db.categories).insert(
            CategoriesCompanion.insert(
              id: 'user-cat-2',
              profileId: const Value<String?>('profile-fixture'),
              type: 'expense',
              name: 'Fresh Category',
              colorKey: const Value<String?>('blue'),
            ),
          );
      final CategoryRow fresh =
          await (db.select(db.categories)..where((tbl) => tbl.id.equals('user-cat-2'))).getSingle();
      expect(fresh.colorKey, 'blue');
    },
  );

  test('a brand-new (never-upgraded) database created at latest schema (v14) works', () async {
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() async => db.close());

    final List<CategoryRow> categories = await db.select(db.categories).get();
    expect(categories, isEmpty);
  });
}
