import 'dart:io';

import 'package:ai_financial_coach/core/database/app_database.dart';
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
// This test proves the v14 -> v15 schema migration (Checkpoint U2,
// Service / Merchant Identity Integration & App-Wide Financial Visual
// Consistency): a database file left at schema v14 (Checkpoint U1 --
// before `service_identity_key` existed on either table) opens cleanly
// under the current (v15) `AppDatabase`, the `onUpgrade` `from < 15`
// branch adds the new nullable column to BOTH `transactions` and
// `recurring_rules`, every pre-existing row on both tables reads back
// with `serviceIdentityKey == null` (nobody is retroactively assigned a
// service just because this column now exists), and a fresh row on
// either table can be written with the new field set. See
// `docs/14_DECISION_LOG.md`'s U2 ADR for the full rationale.
//
// A MINIMAL fixture -- `currencies`/`profiles`/`accounts`/`categories`/
// `transactions`/`recurring_rules` (the two tables this step touches,
// plus their own FK dependencies) -- following the same "minimal
// fixture" convention every other migration test in this directory
// uses: a v14 fixture only triggers this ONE `from < 15` branch when
// opened by TODAY's `AppDatabase` (every earlier `from < N` branch, N <=
// 14, is already false for `from == 14`), so no other table needs to
// exist here.
void main() {
  test(
    'v14 -> v15 upgrade adds service_identity_key to transactions and recurring_rules, '
    'leaving every pre-existing row null',
    () async {
      final Directory tempDir = Directory.systemTemp.createTempSync('afc_v14_to_v15_migration_test_');
      final File dbFile = File('${tempDir.path}/v14_fixture.sqlite');
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

          CREATE TABLE categories (
            id TEXT NOT NULL,
            profile_id TEXT REFERENCES profiles (id),
            parent_id TEXT,
            type TEXT NOT NULL,
            name TEXT NOT NULL,
            icon TEXT,
            color_key TEXT,
            sort_order INTEGER NOT NULL DEFAULT 0,
            is_system INTEGER NOT NULL DEFAULT 0,
            is_active INTEGER NOT NULL DEFAULT 1,
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
            category_id TEXT REFERENCES categories (id),
            note TEXT,
            frequency TEXT NOT NULL,
            interval INTEGER NOT NULL DEFAULT 1,
            start_date INTEGER NOT NULL,
            end_date INTEGER,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            deleted_at INTEGER,
            notifications_enabled INTEGER NOT NULL DEFAULT 0,
            sync_version INTEGER NOT NULL DEFAULT 0,
            sync_status TEXT NOT NULL DEFAULT 'localOnly',
            PRIMARY KEY (id)
          );
        ''');
        fixture.execute('PRAGMA user_version = 14;');

        fixture.execute(
          "INSERT INTO currencies (code, display_name, symbol, minor_units, is_active) "
          "VALUES ('JPY', 'Japanese Yen', '¥', 0, 1);",
        );
        fixture.execute(
          "INSERT INTO profiles (id, display_name, home_country, current_country, home_currency, "
          "living_currency, preferred_language, timezone, date_format, number_format, created_at, "
          "updated_at) VALUES ('profile-v14-fixture', 'Migration Test User', 'JP', 'JP', 'JPY', "
          "'JPY', 'en', 'Asia/Tokyo', 'yyyy-MM-dd', '#,##0.##', 0, 0);",
        );
        fixture.execute(
          "INSERT INTO accounts (id, profile_id, name, type, currency_code, created_at, updated_at) "
          "VALUES ('account-v14-fixture', 'profile-v14-fixture', 'Wallet', 'cash', 'JPY', 0, 0);",
        );
        fixture.execute(
          "INSERT INTO transactions (id, profile_id, account_id, type, amount_minor_units, "
          "currency_code, occurred_at, created_at, updated_at) VALUES ('txn-v14-fixture', "
          "'profile-v14-fixture', 'account-v14-fixture', 'expense', 128000, 'JPY', 0, 0, 0);",
        );
        fixture.execute(
          "INSERT INTO recurring_rules (id, profile_id, kind, name, amount_minor_units, "
          "currency_code, account_id, frequency, start_date, created_at, updated_at) VALUES "
          "('rule-v14-fixture', 'profile-v14-fixture', 'expense', 'Rent', 80000, 'JPY', "
          "'account-v14-fixture', 'monthly', 0, 0, 0);",
        );
      } finally {
        fixture.dispose();
      }

      final AppDatabase db = AppDatabase.forTesting(NativeDatabase(dbFile));
      addTearDown(() async => db.close());

      // Pre-existing rows on BOTH tables survive, with the new column
      // defaulting to null -- nobody is retroactively assigned a
      // service identity just because this column now exists.
      final Transaction existingTxn = await db.select(db.transactions).getSingle();
      expect(existingTxn.id, 'txn-v14-fixture');
      expect(existingTxn.serviceIdentityKey, isNull);

      final RecurringRuleRow existingRule = await db.select(db.recurringRules).getSingle();
      expect(existingRule.id, 'rule-v14-fixture');
      expect(existingRule.serviceIdentityKey, isNull);

      // A fresh row on each table can set the new field explicitly
      // through the current generated companion.
      await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              id: 'txn-after-migration',
              profileId: 'profile-v14-fixture',
              accountId: 'account-v14-fixture',
              type: 'expense',
              amountMinorUnits: 1500,
              currencyCode: 'JPY',
              occurredAt: DateTime.utc(2026, 9, 20),
              createdAt: DateTime.utc(2026, 9, 20),
              updatedAt: DateTime.utc(2026, 9, 20),
              serviceIdentityKey: const Value<String?>('netflix'),
            ),
          );
      final Transaction freshTxn = await (db.select(db.transactions)
            ..where((tbl) => tbl.id.equals('txn-after-migration')))
          .getSingle();
      expect(freshTxn.serviceIdentityKey, 'netflix');

      await db.into(db.recurringRules).insert(
            RecurringRulesCompanion.insert(
              id: 'rule-after-migration',
              profileId: 'profile-v14-fixture',
              kind: 'expense',
              name: 'Streaming',
              amountMinorUnits: 1500,
              currencyCode: 'JPY',
              accountId: 'account-v14-fixture',
              frequency: 'monthly',
              startDate: DateTime.utc(2026, 9, 1),
              createdAt: DateTime.utc(2026, 9, 1),
              updatedAt: DateTime.utc(2026, 9, 1),
              serviceIdentityKey: const Value<String?>('netflix'),
            ),
          );
      final RecurringRuleRow freshRule = await (db.select(db.recurringRules)
            ..where((tbl) => tbl.id.equals('rule-after-migration')))
          .getSingle();
      expect(freshRule.serviceIdentityKey, 'netflix');
    },
  );

  test('a brand-new (never-upgraded) database created at latest schema (v15) works', () async {
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() async => db.close());

    final List<Transaction> transactions = await db.select(db.transactions).get();
    expect(transactions, isEmpty);
    final List<RecurringRuleRow> rules = await db.select(db.recurringRules).get();
    expect(rules, isEmpty);
  });
}
