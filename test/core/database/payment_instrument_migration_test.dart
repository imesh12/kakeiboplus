import 'dart:io';

import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/repositories/account_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/payment_instrument_repository.dart';
import 'package:ai_financial_coach/core/finance/balance_class.dart';
import 'package:ai_financial_coach/core/finance/financial_account_subtype.dart';
import 'package:ai_financial_coach/core/finance/payment_instrument_type.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

// NOTE: this file exercises generated Drift code (AppDatabase, etc. from
// app_database.g.dart) that could not be generated inside the sandbox
// that wrote it -- run `dart run build_runner build
// --delete-conflicting-outputs` locally before running this test. See
// CLAUDE_FIRST_CODING_PROMPT.md.
//
// This test proves the v9 -> current (v10) schema migration --
// Checkpoint D, the PaymentInstrument foundation. See
// `docs/20_ACCOUNTS_ASSETS_HOUSEHOLD_ARCHITECTURE.md` §13.9 and
// `AppDatabase.migration`'s own doc comment for the exact `from < 10`
// behavior this test exercises.
//
// Per `docs/14_DECISION_LOG.md` ADR-022's "logical data survives, not
// byte-for-byte" standard (already followed by every other migration
// test in this directory), this test asserts existing v9 LOGICAL data
// survives the upgrade unchanged: row counts, ids, and every seeded
// field value -- not serialized database-file bytes.
//
// The v9 fixture below is a hand-authored raw-SQL schema, deliberately
// NOT built through any Drift-generated class -- if it were, opening it
// would just create the CURRENT (v10) schema directly via `onCreate`
// rather than exercising the `onUpgrade` migration path at all. It
// mirrors `financial_account_classification_migration_test.dart`'s own
// v8 fixture, with Checkpoint B's `financial_institutions` table and
// `accounts` columns folded in (i.e. this IS what v9 looks like) --
// every CREATE TABLE statement is hand-matched, column-for-column,
// against `lib/core/database/tables.dart` as it stood at schema v9
// (i.e. before this checkpoint's `PaymentInstruments` table and
// `Transactions.paymentInstrumentId` column), cross-checked against the
// generated `$XyzTable` column definitions in `app_database.g.dart`.
// Known limitation: unlike a real migration-testing tool, this fixture
// is hand-maintained and must be updated by hand if the v9 table shapes
// it mirrors ever change.
//
// Two encoding choices below could not be executed/verified in the
// sandbox that wrote this file (no Dart/Flutter toolchain was available
// there) and are the first place to look if this test fails locally --
// same two gotchas `savings_goals_migration_test.dart`'s file-level doc
// comment already flags:
//   1. `_epochSeconds` assumes drift ^2.20.3's DEFAULT (non-text)
//      DateTime encoding for `NativeDatabase` -- unix seconds since the
//      epoch, stored as an SQLite INTEGER.
//   2. Booleans are encoded as SQLite INTEGER 0/1, drift's standard
//      convention.
const String _v9Schema = '''
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

  CREATE TABLE financial_institutions (
    id TEXT NOT NULL,
    profile_id TEXT NOT NULL REFERENCES profiles (id),
    name TEXT NOT NULL,
    country_code TEXT,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    deleted_at INTEGER,
    sync_version INTEGER NOT NULL DEFAULT 0,
    sync_status TEXT NOT NULL DEFAULT 'localOnly',
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
    balance_class TEXT NOT NULL DEFAULT 'asset',
    subtype TEXT NOT NULL DEFAULT 'legacyUnknownNeedsReview',
    institution_id TEXT REFERENCES financial_institutions (id),
    sync_version INTEGER NOT NULL DEFAULT 0,
    sync_status TEXT NOT NULL DEFAULT 'localOnly',
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

  CREATE TABLE reference_exchange_rates (
    base_currency TEXT NOT NULL,
    quote_currency TEXT NOT NULL,
    rate TEXT NOT NULL,
    provider TEXT NOT NULL,
    observed_at INTEGER NOT NULL,
    fetched_at INTEGER NOT NULL,
    PRIMARY KEY (base_currency, quote_currency)
  );

  CREATE TABLE cloud_account_links (
    profile_id TEXT NOT NULL REFERENCES profiles (id),
    cloud_user_id TEXT NOT NULL,
    status TEXT NOT NULL,
    linked_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    PRIMARY KEY (profile_id)
  );
''';

int _epochSeconds(DateTime dateTime) => dateTime.toUtc().millisecondsSinceEpoch ~/ 1000;

void main() {
  test(
    'v9 -> current (v10) upgrade creates payment_instruments and adds '
    'transactions.payment_instrument_id, leaving existing v9 accounts/transactions '
    'data completely intact and fabricating zero instrument rows',
    () async {
      final Directory tempDir =
          Directory.systemTemp.createTempSync('afc_v9_to_v10_migration_test_');
      final File dbFile = File('${tempDir.path}/v9_fixture.sqlite');
      addTearDown(() {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });

      final DateTime profileCreatedAt = DateTime.utc(2026, 1, 1, 9, 30);
      final DateTime accountCreatedAt = DateTime.utc(2026, 2, 1, 8, 0);
      final DateTime txOccurredAt = DateTime.utc(2026, 8, 15, 12, 0);

      final sqlite3.Database fixture = sqlite3.sqlite3.open(dbFile.path);
      try {
        fixture.execute(_v9Schema);
        fixture.execute('PRAGMA user_version = 9;');

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
            'profile-v9-fixture',
            'Migration Test User',
            'US',
            'US',
            'USD',
            'USD',
            'en',
            'America/New_York',
            'yyyy-MM-dd',
            '#,##0.##',
            'light',
            _epochSeconds(profileCreatedAt),
            _epochSeconds(profileCreatedAt),
          ],
        );

        fixture.execute(
          'INSERT INTO accounts (id, profile_id, name, type, currency_code, '
          'opening_balance_minor_units, is_active, created_at, updated_at, deleted_at, '
          'balance_class, subtype, institution_id, sync_version, sync_status) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);',
          <Object?>[
            'account-checking',
            'profile-v9-fixture',
            'Checking',
            'bank',
            'USD',
            500000,
            1,
            _epochSeconds(accountCreatedAt),
            _epochSeconds(accountCreatedAt),
            null,
            'asset',
            'bank',
            null,
            0,
            'localOnly',
          ],
        );

        fixture.execute(
          'INSERT INTO transactions (id, profile_id, account_id, destination_account_id, type, '
          'amount_minor_units, currency_code, category_id, note, occurred_at, created_at, '
          'updated_at, deleted_at, sync_version, sync_status) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);',
          <Object?>[
            'transaction-v9-fixture',
            'profile-v9-fixture',
            'account-checking',
            null,
            'expense',
            2500,
            'USD',
            null,
            'Coffee',
            _epochSeconds(txOccurredAt),
            _epochSeconds(txOccurredAt),
            _epochSeconds(txOccurredAt),
            null,
            0,
            'localOnly',
          ],
        );
      } finally {
        fixture.dispose();
      }

      // --- "App upgrade": open the same file through the REAL, current
      // (v10) AppDatabase. This must run the `onUpgrade` `from < 10`
      // branch, since the file's `user_version` is 9. ---
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase(dbFile));
      addTearDown(() async => db.close());

      // 33. Zero payment_instruments rows are ever fabricated by this
      // migration.
      final List<PaymentInstrumentRow> instruments = await db.select(db.paymentInstruments).get();
      expect(instruments, isEmpty);

      // 34. Account rows remain completely unchanged -- this migration
      // never touches `accounts` at all.
      final List<AccountRow> accounts = await db.select(db.accounts).get();
      expect(accounts.length, 1);
      final AccountRow account = accounts.single;
      expect(account.id, 'account-checking');
      expect(account.name, 'Checking');
      expect(account.type, 'bank');
      expect(account.currencyCode, 'USD');
      expect(account.openingBalanceMinorUnits, 500000);
      expect(account.balanceClassValue, BalanceClass.asset);
      expect(account.subtypeValue, FinancialAccountSubtype.bank);
      expect(account.institutionId, isNull);

      // 32. Every existing transaction remains unchanged except the new
      // (null) field.
      final List<Transaction> transactions = await db.select(db.transactions).get();
      expect(transactions.length, 1);
      final Transaction tx = transactions.single;
      expect(tx.id, 'transaction-v9-fixture');
      expect(tx.accountId, 'account-checking');
      expect(tx.type, 'expense');
      expect(tx.amountMinorUnits, 2500);
      expect(tx.currencyCode, 'USD');
      expect(tx.note, 'Coffee');
      expect(tx.occurredAt.toUtc(), txOccurredAt);
      // The one new field: null for every pre-existing row, never
      // fabricated.
      expect(tx.paymentInstrumentId, isNull);

      // A brand-new payment instrument can be written through the
      // CURRENT repository API and correctly links to the migrated
      // account, proving the post-migration schema is genuinely usable,
      // not just structurally present.
      final AccountRepository accountRepo = AccountRepository(db);
      final PaymentInstrumentRepository instrumentRepo =
          PaymentInstrumentRepository(db, accountRepo);
      final String newInstrumentId = await instrumentRepo.createInstrument(
        profileId: 'profile-v9-fixture',
        accountId: 'account-checking',
        instrumentType: PaymentInstrumentType.debitCard,
        nickname: 'New debit card',
      );
      final PaymentInstrumentRow newInstrument =
          await instrumentRepo.requireActiveById(newInstrumentId);
      expect(newInstrument.accountId, 'account-checking');
      expect(newInstrument.instrumentTypeValue, PaymentInstrumentType.debitCard);
    },
  );

  test('35. empty (never-populated) v9 database upgrades cleanly to v10', () async {
    final Directory tempDir =
        Directory.systemTemp.createTempSync('afc_v9_empty_migration_test_');
    final File dbFile = File('${tempDir.path}/v9_empty_fixture.sqlite');
    addTearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    final sqlite3.Database fixture = sqlite3.sqlite3.open(dbFile.path);
    try {
      fixture.execute(_v9Schema);
      fixture.execute('PRAGMA user_version = 9;');
    } finally {
      fixture.dispose();
    }

    final AppDatabase db = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(() async => db.close());

    final List<AccountRow> accounts = await db.select(db.accounts).get();
    expect(accounts, isEmpty);
    final List<PaymentInstrumentRow> instruments = await db.select(db.paymentInstruments).get();
    expect(instruments, isEmpty);
  });

  test('36. a brand-new (never-upgraded) database created at latest schema (v10) works', () async {
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() async => db.close());

    // onCreate path -- proves the current table definitions themselves
    // (not just the upgrade path) are internally consistent and
    // creatable from scratch.
    final List<AccountRow> accounts = await db.select(db.accounts).get();
    expect(accounts, isEmpty);
    final List<PaymentInstrumentRow> instruments = await db.select(db.paymentInstruments).get();
    expect(instruments, isEmpty);
  });
}
