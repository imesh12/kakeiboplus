import 'dart:io';

import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

// NOTE: this file exercises generated Drift code (AppDatabase,
// RecurringRulesCompanion, etc. from app_database.g.dart) that could not
// be generated inside the sandbox that wrote it -- run
// `dart run build_runner build --delete-conflicting-outputs` locally
// before running this test. See CLAUDE_FIRST_CODING_PROMPT.md.
//
// This test proves the v4 -> v5 schema migration (Beta 1 Task 4B,
// `docs/14_DECISION_LOG.md` ADR-024): a database file left at schema v4
// (Beta 1 Task 4A -- before `recurring_rules.notifications_enabled`
// existed) opens cleanly under the current (v5) `AppDatabase`, the
// `onUpgrade` `from < 5` branch adds the new column, every pre-existing
// v4 recurring rule reads back with `notificationsEnabled == false`
// (nobody is retroactively opted in), and a fresh row can still be
// written with the new field.
//
// Deliberately a MINIMAL fixture -- just the tables this migration step
// actually touches or that `recurring_rules`/`recurring_occurrences`
// reference, PLUS `transactions` (see below) -- rather than every
// table. Unlike `recurring_migration_test.dart`'s v3 -> v4 test (which
// had to prove every OTHER table's data survives a migration that
// created brand-new tables), the v4 -> v5 step itself only ever adds
// one column to one already-existing table; drift does not validate
// the rest of the file's schema shape on open, so there is nothing
// else this test needs to ASSERT against.
//
// `transactions` is included even though this test never reads or
// writes it, for a reason unrelated to the v4 -> v5 step this test
// proves: opening this fixture through the CURRENT `AppDatabase` also
// runs every LATER `onUpgrade` branch up to today's schema version
// (Checkpoint D's `from < 10` branch adds
// `transactions.payment_instrument_id` via `ALTER TABLE transactions
// ADD COLUMN ...`), and that statement fails with "no such table:
// transactions" if the table isn't here. `transactions`' shape below
// is its historically accurate v1-era shape (unchanged by any
// migration before v10, matching the same table's shape in
// `financial_account_classification_migration_test.dart`'s v8 fixture)
// -- deliberately excluding `payment_instrument_id`, which v10's own
// migration is what adds it. No row is ever inserted into this table;
// only its existence is needed for the later `ALTER TABLE` to succeed.
//
// Checkpoint U1 repair: `categories` is included below for the
// identical reason -- Checkpoint U1's `from < 14` branch runs `ALTER
// TABLE categories ADD COLUMN color_key ...`, which fails with "no
// such table: categories" if the table isn't here. Its shape below is
// its historically accurate pre-v14 shape (every column has existed
// since `onCreate`'s original schema; only `color_key` was ever added
// later, by v14). No row is ever inserted into it either.
void main() {
  test(
    'v4 -> v5 upgrade adds recurring_rules.notifications_enabled, defaulting existing rows to false',
    () async {
      final Directory tempDir = Directory.systemTemp.createTempSync('afc_v4_to_v5_migration_test_');
      final File dbFile = File('${tempDir.path}/v4_fixture.sqlite');
      addTearDown(() {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });

      final DateTime ruleCreatedAt = DateTime.utc(2026, 8, 1, 9, 0);

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

          CREATE TABLE recurring_rules (
            id TEXT NOT NULL,
            profile_id TEXT NOT NULL REFERENCES profiles (id),
            kind TEXT NOT NULL,
            name TEXT NOT NULL,
            amount_minor_units INTEGER NOT NULL,
            currency_code TEXT NOT NULL REFERENCES currencies (code),
            account_id TEXT NOT NULL REFERENCES accounts (id),
            destination_account_id TEXT REFERENCES accounts (id),
            category_id TEXT,
            note TEXT,
            frequency TEXT NOT NULL,
            interval INTEGER NOT NULL DEFAULT 1,
            start_date INTEGER NOT NULL,
            end_date INTEGER,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            deleted_at INTEGER,
            sync_version INTEGER NOT NULL DEFAULT 0,
            sync_status TEXT NOT NULL DEFAULT 'localOnly',
            PRIMARY KEY (id)
          );

          CREATE TABLE recurring_occurrences (
            id TEXT NOT NULL,
            rule_id TEXT NOT NULL REFERENCES recurring_rules (id),
            scheduled_date INTEGER NOT NULL,
            status TEXT NOT NULL,
            transaction_id TEXT,
            handled_at INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            sync_version INTEGER NOT NULL DEFAULT 0,
            sync_status TEXT NOT NULL DEFAULT 'localOnly',
            PRIMARY KEY (id)
          );
        ''');

        fixture.execute('PRAGMA user_version = 4;');

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
            'profile-v4-fixture',
            'Migration Test User',
            'JP',
            'JP',
            'JPY',
            'JPY',
            'en',
            'Asia/Tokyo',
            'yyyy-MM-dd',
            '#,##0.##',
            _epochSeconds(ruleCreatedAt),
            _epochSeconds(ruleCreatedAt),
          ],
        );
        fixture.execute(
          'INSERT INTO accounts (id, profile_id, name, type, currency_code, '
          'opening_balance_minor_units, is_active, created_at, updated_at, deleted_at) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);',
          <Object?>[
            'account-v4-fixture',
            'profile-v4-fixture',
            'Wallet',
            'cash',
            'JPY',
            500000,
            1,
            _epochSeconds(ruleCreatedAt),
            _epochSeconds(ruleCreatedAt),
            null,
          ],
        );
        fixture.execute(
          'INSERT INTO recurring_rules (id, profile_id, kind, name, amount_minor_units, '
          'currency_code, account_id, frequency, interval, start_date, created_at, updated_at) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);',
          <Object?>[
            'rule-v4-fixture',
            'profile-v4-fixture',
            'expense',
            'Rent',
            80000,
            'JPY',
            'account-v4-fixture',
            'monthly',
            1,
            _epochSeconds(DateTime.utc(2026, 1, 1)),
            _epochSeconds(ruleCreatedAt),
            _epochSeconds(ruleCreatedAt),
          ],
        );
      } finally {
        fixture.dispose();
      }

      // --- "App upgrade": open the same file through the REAL, current
      // (v5) AppDatabase. This must run the `onUpgrade` `from < 5`
      // branch, since the file's `user_version` is 4. ---
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase(dbFile));
      addTearDown(() async => db.close());

      // The pre-existing v4 rule survives, and the new column defaults
      // to false -- nobody is retroactively opted in to notifications
      // just because this column now exists.
      final RecurringRuleRow existingRule = await db.select(db.recurringRules).getSingle();
      expect(existingRule.id, 'rule-v4-fixture');
      expect(existingRule.name, 'Rent');
      expect(existingRule.notificationsEnabled, isFalse);

      // A newly-created rule can set the new column explicitly.
      await db.into(db.recurringRules).insert(
            RecurringRulesCompanion.insert(
              id: 'rule-after-migration',
              profileId: 'profile-v4-fixture',
              kind: 'income',
              name: 'Salary',
              amountMinorUnits: 300000,
              currencyCode: 'JPY',
              accountId: 'account-v4-fixture',
              frequency: 'monthly',
              startDate: DateTime.utc(2026, 9, 1),
              createdAt: DateTime.utc(2026, 9, 3),
              updatedAt: DateTime.utc(2026, 9, 3),
              notificationsEnabled: const Value<bool>(true),
            ),
          );
      final List<RecurringRuleRow> allRules = await db.select(db.recurringRules).get();
      expect(allRules.length, 2);
      final RecurringRuleRow newRule =
          allRules.singleWhere((RecurringRuleRow r) => r.id == 'rule-after-migration');
      expect(newRule.notificationsEnabled, isTrue);

      // This v4 fixture also proves every LATER `onUpgrade` branch runs
      // cleanly on top of the v4 -> v5 step this test targets -- in
      // particular Checkpoint U1's v13 -> v14 `ALTER TABLE categories
      // ADD COLUMN color_key`, which requires `categories` to already
      // exist (same reasoning as this file's own `transactions` table,
      // included above for an unrelated later `onUpgrade` branch). A
      // bare, empty-but-present `categories` table is enough for that
      // `ALTER TABLE` to succeed; this fixture was never meant to
      // exercise category behavior, so nothing more than its continued
      // existence is asserted here.
      final List<CategoryRow> categoryRows = await db.select(db.categories).get();
      expect(categoryRows, isEmpty);
    },
  );
}

/// Encodes [dateTime] the way drift ^2.20.3's default (non-text)
/// `DateTime` column storage does for a `NativeDatabase` -- unix seconds
/// since the epoch, truncating anything below one second.
int _epochSeconds(DateTime dateTime) => dateTime.toUtc().millisecondsSinceEpoch ~/ 1000;
