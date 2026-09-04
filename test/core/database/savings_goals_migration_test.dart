import 'dart:io';

import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

// NOTE: this file exercises generated Drift code (AppDatabase,
// SavingsGoalsCompanion, etc. from app_database.g.dart) that could not be
// generated inside the sandbox that wrote it -- run
// `dart run build_runner build --delete-conflicting-outputs` locally
// before running this test. See CLAUDE_FIRST_CODING_PROMPT.md.
//
// This test proves the v2 -> v3 schema migration (`docs/14_DECISION_LOG.md`
// ADR-022): a database file that was left at schema v2 (Beta 1 Task 2,
// before `savings_goals`/`savings_goal_contributions` existed) opens
// cleanly under the current (v3) `AppDatabase`, the `onUpgrade` `from < 3`
// branch creates both new tables, and every pre-existing v2 row is still
// present with its data intact.
//
// Per `docs/14_DECISION_LOG.md` ADR-022, this test does NOT assert
// "byte-for-byte unchanged" (that would require comparing serialized
// database-file bytes, which this test does not do). It instead asserts
// that existing v2 LOGICAL data survives the upgrade unchanged: row
// counts, ids, and the specific field values seeded below.
//
// The v2 fixture below is a hand-authored raw-SQL schema, deliberately
// NOT built through any Drift-generated class -- if it were, opening it
// would just create the CURRENT (v3) schema directly via `onCreate`
// rather than exercising the `onUpgrade` migration path at all. Its
// CREATE TABLE statements are hand-matched, column-for-column, against
// `lib/core/database/tables.dart` as it stood at schema v2 (i.e.
// everything in that file except `SavingsGoals` and
// `SavingsGoalContributions`) and cross-checked against the generated
// `$XyzTable` column definitions in `app_database.g.dart` (table/column
// names are drift's default camelCase -> snake_case conversion). Known
// limitation: unlike a real migration-testing tool, this fixture is
// hand-maintained and must be updated by hand if the v2 table shapes it
// mirrors ever change.
//
// Two encoding choices below could not be executed/verified in the
// sandbox that wrote this file (no Dart/Flutter toolchain was available
// there) and are the first place to look if this test fails locally:
//   1. `_epochSeconds` assumes drift ^2.20.3's DEFAULT (non-text)
//      DateTime encoding for `NativeDatabase` -- unix seconds since the
//      epoch, stored as an SQLite INTEGER. This project has no
//      `build.yaml` `store_date_time_values_as_text` override, so the
//      default should apply, but this was not locally verified.
//   2. Booleans are encoded as SQLite INTEGER 0/1, drift's standard
//      convention.
void main() {
  test(
    'v2 -> v3 upgrade creates savings_goals/savings_goal_contributions '
    'and leaves existing v2 data intact',
    () async {
      final Directory tempDir = Directory.systemTemp.createTempSync('afc_v2_to_v3_migration_test_');
      final File dbFile = File('${tempDir.path}/v2_fixture.sqlite');
      addTearDown(() {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });

      // --- Build a v2 database by hand, entirely independent of any
      // Drift-generated code (see the file-level doc comment above). ---
      final DateTime profileCreatedAt = DateTime.utc(2026, 1, 1, 9, 30);
      final DateTime profileUpdatedAt = DateTime.utc(2026, 3, 5, 14, 0);
      final DateTime budgetCreatedAt = DateTime.utc(2026, 8, 1, 8, 0);
      final DateTime budgetUpdatedAt = DateTime.utc(2026, 8, 1, 8, 0);

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

          CREATE TABLE accounts (
            id TEXT NOT NULL,
            profile_id TEXT NOT NULL REFERENCES profiles (id),
            name TEXT NOT NULL,
            type TEXT NOT NULL,
            currency_code TEXT NOT NULL REFERENCES currencies (code),
            opening_balance_minor_units INTEGER NOT NULL DEFAULT 0,
            is_active INTEGER NOT NULL DEFAULT 1,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            deleted_at INTEGER,
            PRIMARY KEY (id)
          );

          CREATE TABLE transactions (
            id TEXT NOT NULL,
            profile_id TEXT NOT NULL REFERENCES profiles (id),
            account_id TEXT NOT NULL REFERENCES accounts (id),
            destination_account_id TEXT REFERENCES accounts (id),
            type TEXT NOT NULL,
            amount_minor_units INTEGER NOT NULL,
            currency_code TEXT NOT NULL REFERENCES currencies (code),
            category_id TEXT REFERENCES categories (id),
            note TEXT,
            occurred_at INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            deleted_at INTEGER,
            sync_version INTEGER NOT NULL DEFAULT 0,
            sync_status TEXT NOT NULL DEFAULT 'localOnly',
            PRIMARY KEY (id)
          );

          CREATE TABLE transaction_exchange_rates (
            id TEXT NOT NULL,
            transaction_id TEXT NOT NULL REFERENCES transactions (id),
            base_currency TEXT NOT NULL,
            quote_currency TEXT NOT NULL,
            rate TEXT NOT NULL,
            converted_amount_minor_units INTEGER NOT NULL,
            provider TEXT NOT NULL,
            provider_timestamp INTEGER NOT NULL,
            fetched_at INTEGER NOT NULL,
            is_manual INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (id)
          );

          CREATE TABLE budgets (
            id TEXT NOT NULL,
            profile_id TEXT NOT NULL REFERENCES profiles (id),
            category_id TEXT REFERENCES categories (id),
            currency_code TEXT NOT NULL REFERENCES currencies (code),
            year INTEGER NOT NULL,
            month INTEGER NOT NULL,
            amount_minor_units INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            deleted_at INTEGER,
            sync_version INTEGER NOT NULL DEFAULT 0,
            sync_status TEXT NOT NULL DEFAULT 'localOnly',
            PRIMARY KEY (id)
          );
        ''');

        fixture.execute('PRAGMA user_version = 2;');

        fixture.execute(
          'INSERT INTO currencies (code, display_name, symbol, minor_units, is_active) '
          'VALUES (?, ?, ?, ?, ?);',
          <Object?>['JPY', 'Japanese Yen', '¥', 0, 1],
        );

        fixture.execute(
          'INSERT INTO profiles (id, display_name, home_country, current_country, home_currency, '
          'living_currency, preferred_language, timezone, date_format, number_format, created_at, '
          'updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);',
          <Object?>[
            'profile-v2-fixture',
            'Migration Test User',
            'JP',
            'JP',
            'JPY',
            'JPY',
            'en',
            'Asia/Tokyo',
            'yyyy-MM-dd',
            '#,##0.##',
            _epochSeconds(profileCreatedAt),
            _epochSeconds(profileUpdatedAt),
          ],
        );

        fixture.execute(
          'INSERT INTO budgets (id, profile_id, category_id, currency_code, year, month, '
          'amount_minor_units, created_at, updated_at, deleted_at, sync_version, sync_status) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);',
          <Object?>[
            'budget-v2-fixture',
            'profile-v2-fixture',
            null,
            'JPY',
            2026,
            8,
            150000,
            _epochSeconds(budgetCreatedAt),
            _epochSeconds(budgetUpdatedAt),
            null,
            0,
            'localOnly',
          ],
        );
      } finally {
        fixture.dispose();
      }

      // --- "App upgrade": open the same file through the REAL, current
      // (v3) AppDatabase. This must run the `onUpgrade` `from < 3`
      // branch, since the file's `user_version` is 2. ---
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase(dbFile));
      addTearDown(() async => db.close());

      // The new v3 tables exist and are usable -- if `onUpgrade`'s
      // `from < 3` branch had not run, these would throw ("no such
      // table") rather than return empty lists.
      final List<SavingsGoalRow> goalsBeforeInsert = await db.select(db.savingsGoals).get();
      expect(goalsBeforeInsert, isEmpty);
      final List<SavingsGoalContributionRow> contributionsBeforeInsert =
          await db.select(db.savingsGoalContributions).get();
      expect(contributionsBeforeInsert, isEmpty);

      // A new-schema row can actually be written and read back.
      await db.into(db.savingsGoals).insert(
            SavingsGoalsCompanion.insert(
              id: 'goal-after-migration',
              profileId: 'profile-v2-fixture',
              name: 'Emergency Fund',
              targetAmountMinorUnits: 500000,
              currencyCode: 'JPY',
              createdAt: DateTime.utc(2026, 9, 3),
              updatedAt: DateTime.utc(2026, 9, 3),
            ),
          );
      await db.into(db.savingsGoalContributions).insert(
            SavingsGoalContributionsCompanion.insert(
              id: 'contribution-after-migration',
              goalId: 'goal-after-migration',
              amountMinorUnits: 10000,
              currencyCode: 'JPY',
              contributedAt: DateTime.utc(2026, 9, 3),
              createdAt: DateTime.utc(2026, 9, 3),
            ),
          );
      final SavingsGoalRow storedGoal = await db.select(db.savingsGoals).getSingle();
      expect(storedGoal.name, 'Emergency Fund');
      final SavingsGoalContributionRow storedContribution =
          await db.select(db.savingsGoalContributions).getSingle();
      expect(storedContribution.amountMinorUnits, 10000);

      // Pre-existing v2 data survives the upgrade -- logically unchanged
      // (ADR-022), not asserted as raw database-file bytes.
      final List<CurrencyRow> currencyRows = await db.select(db.currencies).get();
      expect(currencyRows.length, 1);
      expect(currencyRows.single.code, 'JPY');
      expect(currencyRows.single.minorUnits, 0);

      final List<ProfileRow> profileRows = await db.select(db.profiles).get();
      expect(profileRows.length, 1);
      final ProfileRow profile = profileRows.single;
      expect(profile.id, 'profile-v2-fixture');
      expect(profile.displayName, 'Migration Test User');
      expect(profile.homeCurrency, 'JPY');
      expect(profile.livingCurrency, 'JPY');
      // DateTime round-trips only to the second (see the file-level doc
      // comment on `_epochSeconds`). Compared via `.toUtc()` rather than
      // direct `==`: drift's default (non-text) DateTime storage reads
      // every value back tagged as local time, not UTC, even though the
      // underlying instant is correct (see
      // `SavingsGoalRepository._withUtcDateTimes`'s doc comment) --
      // `.toUtc()` only re-tags the already-correct instant, it never
      // moves it, so this still proves the stored instant survived the
      // upgrade unchanged.
      expect(profile.createdAt.toUtc(), profileCreatedAt);
      expect(profile.updatedAt.toUtc(), profileUpdatedAt);

      final List<BudgetRow> budgetRows = await db.select(db.budgets).get();
      expect(budgetRows.length, 1);
      final BudgetRow budget = budgetRows.single;
      expect(budget.id, 'budget-v2-fixture');
      expect(budget.profileId, 'profile-v2-fixture');
      expect(budget.currencyCode, 'JPY');
      expect(budget.year, 2026);
      expect(budget.month, 8);
      expect(budget.amountMinorUnits, 150000);
      expect(budget.categoryId, isNull);
      expect(budget.deletedAt, isNull);
      // See the `.toUtc()` note above `profile.createdAt`/`updatedAt`.
      expect(budget.createdAt.toUtc(), budgetCreatedAt);
      expect(budget.updatedAt.toUtc(), budgetUpdatedAt);
    },
  );
}

/// Encodes [dateTime] the way drift ^2.20.3's default (non-text)
/// `DateTime` column storage does for a `NativeDatabase` -- unix seconds
/// since the epoch, truncating anything below one second. See the
/// file-level doc comment: this specific encoding assumption could not
/// be executed/verified locally.
int _epochSeconds(DateTime dateTime) => dateTime.toUtc().millisecondsSinceEpoch ~/ 1000;
