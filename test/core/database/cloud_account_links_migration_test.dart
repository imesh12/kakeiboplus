import 'dart:io';

import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

// NOTE: this file exercises generated Drift code (AppDatabase,
// CloudAccountLinksCompanion, etc. from app_database.g.dart) that could
// not be generated inside the sandbox that wrote it -- run
// `dart run build_runner build --delete-conflicting-outputs` locally
// before running this test. See CLAUDE_FIRST_CODING_PROMPT.md.
//
// This test proves the v7 -> v8 schema migration (Checkpoint 12.2): a
// database file left at schema v7 (Checkpoint 9.3 -- every table that
// exists in the schema immediately before CP12.2, i.e. everything in
// `tables.dart` except `CloudAccountLinks`) opens cleanly under the
// CURRENT (v8) `AppDatabase`, the `onUpgrade` `from < 8` branch creates
// `cloud_account_links`, the new table is immediately usable, and every
// pre-existing v7 row -- across profiles/accounts/transactions and the
// v7-introduced `reference_exchange_rates` cache -- is still present
// with its data intact. `profiles` gets particular attention since
// `cloud_account_links.profile_id` is a natural-key foreign reference
// into it.
//
// Per `docs/14_DECISION_LOG.md` ADR-022's precedent (followed by every
// other migration test in this directory), this test does NOT assert
// "byte-for-byte unchanged" database file bytes. It asserts that
// existing v7 LOGICAL data survives the upgrade unchanged: row counts,
// ids, and the specific field values seeded below.
//
// The v7 fixture below is hand-authored raw SQL, deliberately NOT built
// through any Drift-generated class -- if it were, opening it would just
// create the CURRENT (v8) schema directly via `onCreate` rather than
// exercising the `onUpgrade` migration path at all. Its CREATE TABLE
// statements are hand-matched, column-for-column, against
// `lib/core/database/tables.dart` as it stands at schema v7 (i.e.
// everything in that file except `CloudAccountLinks` itself).
//
// Same two encoding assumptions as every other migration test in this
// directory -- drift's default (non-text) DateTime encoding as unix
// seconds, and booleans as SQLite INTEGER 0/1 -- could not be
// executed/verified in the sandbox that wrote this file.
void main() {
  test(
    'v7 -> current (v8) upgrade creates cloud_account_links, leaves every existing v7 table '
    '(including profiles and reference_exchange_rates) untouched, and the new table is usable',
    () async {
      final Directory tempDir = Directory.systemTemp.createTempSync('afc_v7_to_v8_migration_test_');
      final File dbFile = File('${tempDir.path}/v7_fixture.sqlite');
      addTearDown(() {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });

      final DateTime profileCreatedAt = DateTime.utc(2026, 1, 1, 9, 30);
      final DateTime profileUpdatedAt = DateTime.utc(2026, 3, 5, 14, 0);
      final DateTime txnOccurredAt = DateTime.utc(2026, 8, 15, 10, 0);

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

          CREATE TABLE reference_exchange_rates (
            base_currency TEXT NOT NULL,
            quote_currency TEXT NOT NULL,
            rate TEXT NOT NULL,
            provider TEXT NOT NULL,
            observed_at INTEGER NOT NULL,
            fetched_at INTEGER NOT NULL,
            PRIMARY KEY (base_currency, quote_currency)
          );
        ''');

        fixture.execute('PRAGMA user_version = 7;');

        fixture.execute(
          'INSERT INTO currencies (code, display_name, symbol, minor_units, is_active) '
          'VALUES (?, ?, ?, ?, ?);',
          <Object?>['JPY', 'Japanese Yen', '¥', 0, 1],
        );

        fixture.execute(
          'INSERT INTO profiles (id, display_name, home_country, current_country, home_currency, '
          'living_currency, preferred_language, timezone, date_format, number_format, '
          'theme_preference, created_at, updated_at) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);',
          <Object?>[
            'profile-v7-fixture',
            'Migration Test User',
            'JP',
            'JP',
            'JPY',
            'JPY',
            'en',
            'Asia/Tokyo',
            'yyyy-MM-dd',
            '#,##0.##',
            'light',
            _epochSeconds(profileCreatedAt),
            _epochSeconds(profileUpdatedAt),
          ],
        );

        fixture.execute(
          'INSERT INTO accounts (id, profile_id, name, type, currency_code, '
          'opening_balance_minor_units, is_active, created_at, updated_at, deleted_at) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);',
          <Object?>[
            'account-v7-fixture',
            'profile-v7-fixture',
            'Wallet',
            'cash',
            'JPY',
            0,
            1,
            _epochSeconds(profileCreatedAt),
            _epochSeconds(profileCreatedAt),
            null,
          ],
        );

        fixture.execute(
          'INSERT INTO transactions (id, profile_id, account_id, destination_account_id, type, '
          'amount_minor_units, currency_code, category_id, note, occurred_at, created_at, '
          'updated_at, deleted_at, sync_version, sync_status) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);',
          <Object?>[
            'transaction-v7-fixture',
            'profile-v7-fixture',
            'account-v7-fixture',
            null,
            'expense',
            128000,
            'JPY',
            null,
            'Groceries',
            _epochSeconds(txnOccurredAt),
            _epochSeconds(txnOccurredAt),
            _epochSeconds(txnOccurredAt),
            null,
            0,
            'localOnly',
          ],
        );

        fixture.execute(
          'INSERT INTO reference_exchange_rates (base_currency, quote_currency, rate, provider, '
          'observed_at, fetched_at) VALUES (?, ?, ?, ?, ?, ?);',
          <Object?>['USD', 'JPY', '150.25', 'fixer', _epochSeconds(txnOccurredAt), _epochSeconds(txnOccurredAt)],
        );
      } finally {
        fixture.dispose();
      }

      // --- "App upgrade": open the same file through the REAL, current
      // (v8) AppDatabase. This must run the `onUpgrade` `from < 8`
      // branch, since the file's `user_version` is 7. ---
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase(dbFile));
      addTearDown(() async => db.close());

      // The new v8 table exists and is usable -- if `onUpgrade`'s
      // `from < 8` branch had not run, this would throw ("no such
      // table") rather than return an empty list.
      final List<CloudAccountLink> linksBeforeInsert = await db.select(db.cloudAccountLinks).get();
      expect(linksBeforeInsert, isEmpty);

      // A new-schema row can actually be written and read back,
      // referencing the pre-existing v7 profile.
      final DateTime linkedAt = DateTime.utc(2026, 9, 20, 8, 0);
      await db.into(db.cloudAccountLinks).insert(
            CloudAccountLinksCompanion.insert(
              profileId: 'profile-v7-fixture',
              cloudUserId: 'cloud-user-post-upgrade',
              status: 'active',
              linkedAt: linkedAt,
              updatedAt: linkedAt,
            ),
          );
      final CloudAccountLink storedLink = await db.select(db.cloudAccountLinks).getSingle();
      expect(storedLink.profileId, 'profile-v7-fixture');
      expect(storedLink.cloudUserId, 'cloud-user-post-upgrade');
      expect(storedLink.status, 'active');

      // Pre-existing v7 data survives the upgrade -- logically unchanged.
      final List<ProfileRow> profileRows = await db.select(db.profiles).get();
      expect(profileRows.length, 1);
      final ProfileRow profile = profileRows.single;
      expect(profile.id, 'profile-v7-fixture');
      expect(profile.displayName, 'Migration Test User');
      expect(profile.createdAt.toUtc(), profileCreatedAt);
      expect(profile.updatedAt.toUtc(), profileUpdatedAt);

      final List<Transaction> transactionRows = await db.select(db.transactions).get();
      expect(transactionRows.length, 1);
      expect(transactionRows.single.id, 'transaction-v7-fixture');
      expect(transactionRows.single.amountMinorUnits, 128000);

      final List<ReferenceExchangeRate> refRateRows =
          await db.select(db.referenceExchangeRates).get();
      expect(refRateRows.length, 1);
      expect(refRateRows.single.baseCurrency, 'USD');
      expect(refRateRows.single.quoteCurrency, 'JPY');
    },
  );

  test('a fresh v8 database includes cloud_account_links from onCreate, and it starts empty',
      () async {
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() async => db.close());

    // Fresh onCreate -- no onUpgrade path involved at all. If
    // CloudAccountLinks were missing from the `@DriftDatabase` tables
    // list, `m.createAll()` would never create it and this select would
    // throw.
    final List<CloudAccountLink> rows = await db.select(db.cloudAccountLinks).get();
    expect(rows, isEmpty);

    // No backfill: a brand-new install starts fully local-only, with
    // zero rows in this table -- there is nothing to link on first run.
  });
}

/// Encodes [dateTime] the way drift ^2.20.3's default (non-text)
/// `DateTime` column storage does for a `NativeDatabase` -- unix seconds
/// since the epoch, truncating anything below one second. Same
/// assumption as every other migration test in this directory -- could
/// not be executed/verified locally.
int _epochSeconds(DateTime dateTime) => dateTime.toUtc().millisecondsSinceEpoch ~/ 1000;
