import 'dart:io';

import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/repositories/account_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/credit_facility_repository.dart';
import 'package:ai_financial_coach/core/finance/balance_class.dart';
import 'package:ai_financial_coach/core/finance/financial_account_subtype.dart';
import 'package:ai_financial_coach/core/money/money.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

// NOTE: this file exercises generated Drift code (AppDatabase, etc. from
// app_database.g.dart) that could not be generated inside the sandbox
// that wrote it -- run `dart run build_runner build
// --delete-conflicting-outputs` locally before running this test. See
// CLAUDE_FIRST_CODING_PROMPT.md.
//
// This test proves the v10 -> current (v11) schema migration --
// Checkpoint E, the CreditFacilityDetails foundation. See
// `docs/20_ACCOUNTS_ASSETS_HOUSEHOLD_ARCHITECTURE.md` §13.9/§13.4 and
// `AppDatabase.migration`'s own doc comment for the exact `from < 11`
// behavior this test exercises.
//
// Per `docs/14_DECISION_LOG.md` ADR-022's "logical data survives, not
// byte-for-byte" standard (already followed by every other migration
// test in this directory), this test asserts existing v10 LOGICAL data
// survives the upgrade unchanged.
//
// The v10 fixture below is `payment_instrument_migration_test.dart`'s
// own `_v9Schema` PLUS the `payment_instruments` table and the
// `transactions.payment_instrument_id` column -- i.e. this IS what v10
// looks like (Checkpoint D's own migration only ever adds those two
// things to v9). Unlike the v9 -> v10 step (which ALTERs the
// already-existing `transactions` table and therefore requires that
// table to already exist in the fixture -- see this repo's
// `recurring_notifications_migration_test.dart` regression fix), this
// checkpoint's v10 -> v11 step only ever CREATEs one brand-new table
// (`credit_facility_details`), which cannot fail merely because some
// unrelated table is absent -- so, unlike that earlier regression, this
// migration step introduces no new requirement on any OTHER historical
// fixture in this directory; none of them needed a corresponding change.
const String _v10Schema = '''
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

  CREATE TABLE payment_instruments (
    id TEXT NOT NULL,
    profile_id TEXT NOT NULL REFERENCES profiles (id),
    account_id TEXT NOT NULL REFERENCES accounts (id),
    institution_id TEXT REFERENCES financial_institutions (id),
    instrument_type TEXT NOT NULL,
    network TEXT,
    nickname TEXT NOT NULL,
    last4 TEXT,
    expiry_month INTEGER,
    expiry_year INTEGER,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    deleted_at INTEGER,
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
    payment_instrument_id TEXT REFERENCES payment_instruments (id),
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
    '19. v10 -> current (v11) upgrade creates credit_facility_details, leaving existing v10 '
    'accounts/transactions/payment_instruments data completely intact and fabricating zero '
    'facility rows',
    () async {
      final Directory tempDir =
          Directory.systemTemp.createTempSync('afc_v10_to_v11_migration_test_');
      final File dbFile = File('${tempDir.path}/v10_fixture.sqlite');
      addTearDown(() {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });

      final DateTime profileCreatedAt = DateTime.utc(2026, 1, 1, 9, 30);
      final DateTime accountCreatedAt = DateTime.utc(2026, 2, 1, 8, 0);
      final DateTime txOccurredAt = DateTime.utc(2026, 8, 15, 12, 0);
      final DateTime instrumentCreatedAt = DateTime.utc(2026, 2, 1, 8, 0);

      final sqlite3.Database fixture = sqlite3.sqlite3.open(dbFile.path);
      try {
        fixture.execute(_v10Schema);
        fixture.execute('PRAGMA user_version = 10;');

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
            'profile-v10-fixture',
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

        // A liability/creditCard account -- exactly the shape Checkpoint E
        // introduces -- already existing at v10 (hand-classified, since no
        // production path could create one before this checkpoint's
        // `CreditFacilityRepository` exists; a real historical install
        // could only reach this shape via a future checkpoint's Add
        // Account UX, but this fixture proves the migration does not
        // choke on -- or fabricate a facility for -- one either way).
        fixture.execute(
          'INSERT INTO accounts (id, profile_id, name, type, currency_code, '
          'opening_balance_minor_units, is_active, created_at, updated_at, deleted_at, '
          'balance_class, subtype, institution_id, sync_version, sync_status) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);',
          <Object?>[
            'account-credit-card',
            'profile-v10-fixture',
            'Credit Card',
            'card',
            'USD',
            0,
            1,
            _epochSeconds(accountCreatedAt),
            _epochSeconds(accountCreatedAt),
            null,
            'liability',
            'creditCard',
            null,
            0,
            'localOnly',
          ],
        );

        fixture.execute(
          'INSERT INTO payment_instruments (id, profile_id, account_id, institution_id, '
          'instrument_type, network, nickname, last4, expiry_month, expiry_year, created_at, '
          'updated_at, deleted_at, sync_version, sync_status) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);',
          <Object?>[
            'instrument-v10-fixture',
            'profile-v10-fixture',
            'account-credit-card',
            null,
            'creditCard',
            'visa',
            'Rakuten Visa',
            null,
            null,
            null,
            _epochSeconds(instrumentCreatedAt),
            _epochSeconds(instrumentCreatedAt),
            null,
            0,
            'localOnly',
          ],
        );

        fixture.execute(
          'INSERT INTO transactions (id, profile_id, account_id, destination_account_id, type, '
          'amount_minor_units, currency_code, category_id, note, occurred_at, created_at, '
          'updated_at, deleted_at, sync_version, sync_status, payment_instrument_id) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);',
          <Object?>[
            'transaction-v10-fixture',
            'profile-v10-fixture',
            'account-credit-card',
            null,
            'expense',
            5000,
            'USD',
            null,
            'Groceries',
            _epochSeconds(txOccurredAt),
            _epochSeconds(txOccurredAt),
            _epochSeconds(txOccurredAt),
            null,
            0,
            'localOnly',
            'instrument-v10-fixture',
          ],
        );
      } finally {
        fixture.dispose();
      }

      // --- "App upgrade": open the same file through the REAL, current
      // (v11) AppDatabase. This must run the `onUpgrade` `from < 11`
      // branch, since the file's `user_version` is 10. ---
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase(dbFile));
      addTearDown(() async => db.close());

      // Zero credit_facility_details rows are ever fabricated by this
      // migration -- not even for the pre-existing liability/creditCard
      // account above.
      final List<CreditFacilityDetailsRow> facilities =
          await db.select(db.creditFacilityDetails).get();
      expect(facilities, isEmpty);

      // Account rows remain completely unchanged.
      final List<AccountRow> accounts = await db.select(db.accounts).get();
      expect(accounts.length, 1);
      final AccountRow account = accounts.single;
      expect(account.id, 'account-credit-card');
      expect(account.balanceClassValue, BalanceClass.liability);
      expect(account.subtypeValue, FinancialAccountSubtype.creditCard);
      expect(account.openingBalanceMinorUnits, 0);

      // Payment instrument rows remain completely unchanged.
      final List<PaymentInstrumentRow> instruments = await db.select(db.paymentInstruments).get();
      expect(instruments.length, 1);
      expect(instruments.single.id, 'instrument-v10-fixture');
      expect(instruments.single.accountId, 'account-credit-card');

      // Transaction rows remain completely unchanged, including the
      // Checkpoint-D-era payment_instrument_id already set on it.
      final List<Transaction> transactions = await db.select(db.transactions).get();
      expect(transactions.length, 1);
      final Transaction tx = transactions.single;
      expect(tx.id, 'transaction-v10-fixture');
      expect(tx.accountId, 'account-credit-card');
      expect(tx.amountMinorUnits, 5000);
      expect(tx.paymentInstrumentId, 'instrument-v10-fixture');

      // A brand-new credit facility can be written through the CURRENT
      // repository API and correctly links to the migrated account,
      // proving the post-migration schema is genuinely usable, not just
      // structurally present.
      final AccountRepository accountRepo = AccountRepository(db);
      final CreditFacilityRepository facilityRepo = CreditFacilityRepository(db, accountRepo);
      final String newFacilityId = await facilityRepo.createFacility(
        profileId: 'profile-v10-fixture',
        accountId: 'account-credit-card',
        creditLimit: Money.fromMinorUnits(500000, 'USD'),
      );
      final CreditFacilityDetailsRow newFacility =
          await facilityRepo.requireActiveForAccount('account-credit-card');
      expect(newFacility.id, newFacilityId);
      expect(newFacility.creditLimitMinorUnits, 500000);
    },
  );

  test('empty (never-populated) v10 database upgrades cleanly to v11', () async {
    final Directory tempDir =
        Directory.systemTemp.createTempSync('afc_v10_empty_migration_test_');
    final File dbFile = File('${tempDir.path}/v10_empty_fixture.sqlite');
    addTearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    final sqlite3.Database fixture = sqlite3.sqlite3.open(dbFile.path);
    try {
      fixture.execute(_v10Schema);
      fixture.execute('PRAGMA user_version = 10;');
    } finally {
      fixture.dispose();
    }

    final AppDatabase db = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(() async => db.close());

    final List<AccountRow> accounts = await db.select(db.accounts).get();
    expect(accounts, isEmpty);
    final List<CreditFacilityDetailsRow> facilities =
        await db.select(db.creditFacilityDetails).get();
    expect(facilities, isEmpty);
  });

  test('a brand-new (never-upgraded) database created at latest schema (v11) works', () async {
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() async => db.close());

    // onCreate path -- proves the current table definitions themselves
    // (not just the upgrade path) are internally consistent and
    // creatable from scratch.
    final List<AccountRow> accounts = await db.select(db.accounts).get();
    expect(accounts, isEmpty);
    final List<CreditFacilityDetailsRow> facilities =
        await db.select(db.creditFacilityDetails).get();
    expect(facilities, isEmpty);
  });
}
