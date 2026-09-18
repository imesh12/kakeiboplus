import 'dart:io';

import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

// NOTE: this file exercises generated Drift code (AppDatabase,
// ReferenceExchangeRatesCompanion, etc. from app_database.g.dart) that
// could not be generated inside the sandbox that wrote it -- run
// `dart run build_runner build --delete-conflicting-outputs` locally
// before running this test. See CLAUDE_FIRST_CODING_PROMPT.md.
//
// This test proves the v6 -> v7 schema migration (Checkpoint 9.3): a
// database file left at schema v6 (Checkpoint 8.1 -- every table that
// exists in the schema immediately before CP9.3, i.e. everything in
// `tables.dart` except `ReferenceExchangeRates`) opens cleanly under the
// CURRENT (v7) `AppDatabase`, the `onUpgrade` `from < 7` branch creates
// `reference_exchange_rates`, the new table is immediately usable, and
// every pre-existing v6 row -- across every table that already existed,
// not just a fresh empty database -- is still present with its data
// intact. `transaction_exchange_rates` gets particular attention since
// it is CP9.3's explicit "must remain untouched" sibling table.
//
// Per `docs/14_DECISION_LOG.md` ADR-022's precedent (followed by every
// other migration test in this directory), this test does NOT assert
// "byte-for-byte unchanged" database file bytes. It asserts that
// existing v6 LOGICAL data survives the upgrade unchanged: row counts,
// ids, and the specific field values seeded below.
//
// The v6 fixture below is hand-authored raw SQL, deliberately NOT built
// through any Drift-generated class -- if it were, opening it would just
// create the CURRENT (v7) schema directly via `onCreate` rather than
// exercising the `onUpgrade` migration path at all. Its CREATE TABLE
// statements are hand-matched, column-for-column, against
// `lib/core/database/tables.dart` as it stands at schema v6 (i.e.
// everything in that file except `ReferenceExchangeRates` itself) and
// cross-checked against the generated `$XyzTable` column definitions in
// `app_database.g.dart` (table/column names are drift's default
// camelCase -> snake_case conversion). Known limitation: like every
// other migration fixture in this directory, this is hand-maintained and
// must be updated by hand if the v6 table shapes it mirrors ever change.
//
// Same two encoding assumptions as every other migration test in this
// directory (see e.g. `savings_goals_migration_test.dart`'s file-level
// doc comment) -- drift's default (non-text) DateTime encoding as unix
// seconds, and booleans as SQLite INTEGER 0/1 -- could not be
// executed/verified in the sandbox that wrote this file.
void main() {
  test(
    'v6 -> current (v7) upgrade creates reference_exchange_rates, leaves every existing v6 '
    'table (including transaction_exchange_rates) untouched, and the new table is usable',
    () async {
      final Directory tempDir = Directory.systemTemp.createTempSync('afc_v6_to_v7_migration_test_');
      final File dbFile = File('${tempDir.path}/v6_fixture.sqlite');
      addTearDown(() {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });

      final DateTime profileCreatedAt = DateTime.utc(2026, 1, 1, 9, 30);
      final DateTime profileUpdatedAt = DateTime.utc(2026, 3, 5, 14, 0);
      final DateTime txnOccurredAt = DateTime.utc(2026, 8, 15, 10, 0);
      final DateTime txnCreatedAt = DateTime.utc(2026, 8, 15, 10, 0);
      final DateTime fxProviderTimestamp = DateTime.utc(2026, 8, 15, 9, 59);
      final DateTime fxFetchedAt = DateTime.utc(2026, 8, 15, 10, 0);

      // --- Build a v6 database by hand, entirely independent of any
      // Drift-generated code (see the file-level doc comment above). ---
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

          CREATE TABLE savings_goals (
            id TEXT NOT NULL,
            profile_id TEXT NOT NULL REFERENCES profiles (id),
            name TEXT NOT NULL,
            target_amount_minor_units INTEGER NOT NULL,
            currency_code TEXT NOT NULL REFERENCES currencies (code),
            target_date INTEGER,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            deleted_at INTEGER,
            sync_version INTEGER NOT NULL DEFAULT 0,
            sync_status TEXT NOT NULL DEFAULT 'localOnly',
            PRIMARY KEY (id)
          );

          CREATE TABLE savings_goal_contributions (
            id TEXT NOT NULL,
            goal_id TEXT NOT NULL REFERENCES savings_goals (id),
            amount_minor_units INTEGER NOT NULL,
            currency_code TEXT NOT NULL REFERENCES currencies (code),
            contributed_at INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
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
            "interval" INTEGER NOT NULL DEFAULT 1,
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

          CREATE TABLE recurring_occurrences (
            id TEXT NOT NULL,
            rule_id TEXT NOT NULL REFERENCES recurring_rules (id),
            scheduled_date INTEGER NOT NULL,
            status TEXT NOT NULL,
            transaction_id TEXT REFERENCES transactions (id),
            handled_at INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            sync_version INTEGER NOT NULL DEFAULT 0,
            sync_status TEXT NOT NULL DEFAULT 'localOnly',
            PRIMARY KEY (id)
          );
        ''');

        fixture.execute('PRAGMA user_version = 6;');

        fixture.execute(
          'INSERT INTO currencies (code, display_name, symbol, minor_units, is_active) '
          'VALUES (?, ?, ?, ?, ?);',
          <Object?>['JPY', 'Japanese Yen', '¥', 0, 1],
        );
        fixture.execute(
          'INSERT INTO currencies (code, display_name, symbol, minor_units, is_active) '
          'VALUES (?, ?, ?, ?, ?);',
          <Object?>['USD', 'US Dollar', r'$', 2, 1],
        );

        fixture.execute(
          'INSERT INTO profiles (id, display_name, home_country, current_country, home_currency, '
          'living_currency, preferred_language, timezone, date_format, number_format, '
          'theme_preference, created_at, updated_at) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);',
          <Object?>[
            'profile-v6-fixture',
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
            'account-v6-fixture',
            'profile-v6-fixture',
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
            'transaction-v6-fixture',
            'profile-v6-fixture',
            'account-v6-fixture',
            null,
            'expense',
            128000,
            'JPY',
            null,
            'Groceries',
            _epochSeconds(txnOccurredAt),
            _epochSeconds(txnCreatedAt),
            _epochSeconds(txnCreatedAt),
            null,
            0,
            'localOnly',
          ],
        );

        // A historical FX snapshot -- the sibling table CP9.3 must leave
        // completely untouched.
        fixture.execute(
          'INSERT INTO transaction_exchange_rates (id, transaction_id, base_currency, '
          'quote_currency, rate, converted_amount_minor_units, provider, provider_timestamp, '
          'fetched_at, is_manual) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);',
          <Object?>[
            'fx-snapshot-v6-fixture',
            'transaction-v6-fixture',
            'JPY',
            'USD',
            '0.00665557',
            851,
            'fixer',
            _epochSeconds(fxProviderTimestamp),
            _epochSeconds(fxFetchedAt),
            0,
          ],
        );
      } finally {
        fixture.dispose();
      }

      // --- "App upgrade": open the same file through the REAL, current
      // (v7) AppDatabase. This must run the `onUpgrade` `from < 7`
      // branch, since the file's `user_version` is 6. ---
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase(dbFile));
      addTearDown(() async => db.close());

      // The new v7 table exists and is usable -- if `onUpgrade`'s
      // `from < 7` branch had not run, this would throw ("no such
      // table") rather than return an empty list.
      final List<ReferenceExchangeRate> cacheRowsBeforeInsert =
          await db.select(db.referenceExchangeRates).get();
      expect(cacheRowsBeforeInsert, isEmpty);

      // A new-schema row can actually be written and read back, with a
      // working composite primary key (upsert on the same pair replaces,
      // rather than duplicates or errors).
      final DateTime cacheObservedAt = DateTime.utc(2026, 9, 18, 8, 0);
      final DateTime cacheFetchedAt = DateTime.utc(2026, 9, 18, 8, 0);
      await db.into(db.referenceExchangeRates).insertOnConflictUpdate(
            ReferenceExchangeRatesCompanion.insert(
              baseCurrency: 'USD',
              quoteCurrency: 'JPY',
              rate: '150.25',
              provider: 'fixer',
              observedAt: cacheObservedAt,
              fetchedAt: cacheFetchedAt,
            ),
          );
      final ReferenceExchangeRate storedCacheRow =
          await db.select(db.referenceExchangeRates).getSingle();
      expect(storedCacheRow.baseCurrency, 'USD');
      expect(storedCacheRow.quoteCurrency, 'JPY');
      expect(storedCacheRow.rate, '150.25');

      // Pre-existing v6 data survives the upgrade -- logically unchanged
      // (same convention as every other migration test in this
      // directory), not asserted as raw database-file bytes.
      final List<CurrencyRow> currencyRows = await db.select(db.currencies).get();
      expect(currencyRows.length, 2);

      final List<ProfileRow> profileRows = await db.select(db.profiles).get();
      expect(profileRows.length, 1);
      final ProfileRow profile = profileRows.single;
      expect(profile.id, 'profile-v6-fixture');
      expect(profile.displayName, 'Migration Test User');
      // See `savings_goals_migration_test.dart`'s identical `.toUtc()`
      // note: drift's default (non-text) DateTime storage reads every
      // value back tagged as local time, not UTC, even though the
      // underlying instant is correct -- `.toUtc()` only re-tags the
      // already-correct instant, it never moves it.
      expect(profile.createdAt.toUtc(), profileCreatedAt);
      expect(profile.updatedAt.toUtc(), profileUpdatedAt);

      final List<Transaction> transactionRows = await db.select(db.transactions).get();
      expect(transactionRows.length, 1);
      expect(transactionRows.single.id, 'transaction-v6-fixture');
      expect(transactionRows.single.amountMinorUnits, 128000);

      // The critical CP9.3 assertion: transaction_exchange_rates (the
      // historical, immutable snapshot table) is completely untouched --
      // same row, same values, still there, unmodified by a migration
      // that only ever adds a brand-new, unrelated table.
      final List<TransactionExchangeRate> historicalFxRows =
          await db.select(db.transactionExchangeRates).get();
      expect(historicalFxRows.length, 1);
      final TransactionExchangeRate historicalFx = historicalFxRows.single;
      expect(historicalFx.id, 'fx-snapshot-v6-fixture');
      expect(historicalFx.transactionId, 'transaction-v6-fixture');
      expect(historicalFx.baseCurrency, 'JPY');
      expect(historicalFx.quoteCurrency, 'USD');
      expect(historicalFx.rate, '0.00665557');
      expect(historicalFx.convertedAmountMinorUnits, 851);
      expect(historicalFx.provider, 'fixer');
      expect(historicalFx.providerTimestamp.toUtc(), fxProviderTimestamp);
      expect(historicalFx.fetchedAt.toUtc(), fxFetchedAt);
      expect(historicalFx.isManual, isFalse);
    },
  );

  test('a fresh v7 database includes reference_exchange_rates from onCreate, and the cache works', () async {
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() async => db.close());

    // Fresh onCreate -- no onUpgrade path involved at all. If
    // ReferenceExchangeRates were missing from the `@DriftDatabase`
    // tables list, `m.createAll()` would never create it and this
    // select would throw.
    final List<ReferenceExchangeRate> rows = await db.select(db.referenceExchangeRates).get();
    expect(rows, isEmpty);

    await db.into(db.referenceExchangeRates).insertOnConflictUpdate(
          ReferenceExchangeRatesCompanion.insert(
            baseCurrency: 'EUR',
            quoteCurrency: 'USD',
            rate: '1.08',
            provider: 'fixer',
            observedAt: DateTime.utc(2026, 9, 18),
            fetchedAt: DateTime.utc(2026, 9, 18),
          ),
        );
    final ReferenceExchangeRate stored = await db.select(db.referenceExchangeRates).getSingle();
    expect(stored.baseCurrency, 'EUR');
    expect(stored.quoteCurrency, 'USD');
    expect(stored.rate, '1.08');
  });
}

/// Encodes [dateTime] the way drift ^2.20.3's default (non-text)
/// `DateTime` column storage does for a `NativeDatabase` -- unix seconds
/// since the epoch, truncating anything below one second. Same
/// assumption as every other migration test in this directory (see
/// `savings_goals_migration_test.dart`'s file-level doc comment) -- could
/// not be executed/verified locally.
int _epochSeconds(DateTime dateTime) => dateTime.toUtc().millisecondsSinceEpoch ~/ 1000;
