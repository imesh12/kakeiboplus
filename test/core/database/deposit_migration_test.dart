import 'dart:io';

import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/repositories/account_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/deposit_repository.dart';
import 'package:ai_financial_coach/core/finance/balance_class.dart';
import 'package:ai_financial_coach/core/finance/deposit_interest_method.dart';
import 'package:ai_financial_coach/core/finance/deposit_term_unit.dart';
import 'package:ai_financial_coach/core/finance/deposit_type.dart';
import 'package:ai_financial_coach/core/finance/financial_account_subtype.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

// NOTE: this file exercises generated Drift code (AppDatabase, etc. from
// app_database.g.dart) that could not be generated inside the sandbox
// that wrote it -- run `dart run build_runner build
// --delete-conflicting-outputs` locally before running this test. See
// CLAUDE_FIRST_CODING_PROMPT.md.
//
// This test proves the v11 -> current (v12) schema migration --
// Checkpoint F, the DepositDetails foundation. See
// `docs/20_ACCOUNTS_ASSETS_HOUSEHOLD_ARCHITECTURE.md` §13.10/§13.4 and
// `AppDatabase.migration`'s own doc comment for the exact `from < 12`
// behavior this test exercises.
//
// Per `docs/14_DECISION_LOG.md` ADR-022's "logical data survives, not
// byte-for-byte" standard, this test asserts existing v11 LOGICAL data
// survives the upgrade unchanged.
//
// The v11 fixture below is `credit_facility_migration_test.dart`'s own
// `_v10Schema` PLUS the `credit_facility_details` table -- i.e. this IS
// what v11 looks like (Checkpoint E's own migration only ever adds that
// one table to v10). Exactly like the v10 -> v11 step, this checkpoint's
// v11 -> v12 step only ever CREATEs one brand-new table
// (`deposit_details`), which cannot fail merely because some unrelated
// table is absent -- so, like Checkpoint E, this migration step
// introduces no new requirement on any OTHER historical fixture in this
// directory; none of them needed a corresponding change (item 30).
const String _v11Schema = '''
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

  CREATE TABLE credit_facility_details (
    id TEXT NOT NULL,
    profile_id TEXT NOT NULL REFERENCES profiles (id),
    account_id TEXT NOT NULL UNIQUE REFERENCES accounts (id),
    credit_limit_minor_units INTEGER NOT NULL,
    statement_closing_day INTEGER,
    due_day INTEGER,
    linked_payment_account_id TEXT REFERENCES accounts (id),
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
    '29. v11 -> current (v12) upgrade creates deposit_details, leaving existing v11 '
    'accounts/transactions data completely intact and fabricating zero deposit rows',
    () async {
      final Directory tempDir =
          Directory.systemTemp.createTempSync('afc_v11_to_v12_migration_test_');
      final File dbFile = File('${tempDir.path}/v11_fixture.sqlite');
      addTearDown(() {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });

      final DateTime profileCreatedAt = DateTime.utc(2026, 1, 1, 9, 30);
      final DateTime accountCreatedAt = DateTime.utc(2026, 2, 1, 8, 0);
      final DateTime txOccurredAt = DateTime.utc(2026, 8, 15, 12, 0);

      final sqlite3.Database fixture = sqlite3.sqlite3.open(dbFile.path);
      try {
        fixture.execute(_v11Schema);
        fixture.execute('PRAGMA user_version = 11;');

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
            'profile-v11-fixture',
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

        // A `subtype: deposit` account -- exactly the shape Checkpoint F
        // introduces -- already existing at v11 (hand-classified, since
        // no production path could create one before this checkpoint's
        // `DepositRepository` exists). Proves the migration does not
        // choke on -- or fabricate deposit details for -- one either way.
        fixture.execute(
          'INSERT INTO accounts (id, profile_id, name, type, currency_code, '
          'opening_balance_minor_units, is_active, created_at, updated_at, deleted_at, '
          'balance_class, subtype, institution_id, sync_version, sync_status) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);',
          <Object?>[
            'account-deposit',
            'profile-v11-fixture',
            'Fixed Deposit',
            'bank',
            'USD',
            50000,
            1,
            _epochSeconds(accountCreatedAt),
            _epochSeconds(accountCreatedAt),
            null,
            'asset',
            'deposit',
            null,
            0,
            'localOnly',
          ],
        );

        // A funding transfer INTO the deposit -- proves an ordinary,
        // pre-existing transfer transaction targeting a `deposit`-subtype
        // account survives the migration untouched.
        fixture.execute(
          'INSERT INTO transactions (id, profile_id, account_id, destination_account_id, type, '
          'amount_minor_units, currency_code, category_id, note, occurred_at, created_at, '
          'updated_at, deleted_at, sync_version, sync_status, payment_instrument_id) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);',
          <Object?>[
            'transaction-v11-fixture',
            'profile-v11-fixture',
            'account-deposit',
            null,
            'income',
            2750,
            'USD',
            null,
            'Interest credited',
            _epochSeconds(txOccurredAt),
            _epochSeconds(txOccurredAt),
            _epochSeconds(txOccurredAt),
            null,
            0,
            'localOnly',
            null,
          ],
        );
      } finally {
        fixture.dispose();
      }

      // --- "App upgrade": open the same file through the REAL, current
      // (v12) AppDatabase. This must run the `onUpgrade` `from < 12`
      // branch, since the file's `user_version` is 11. ---
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase(dbFile));
      addTearDown(() async => db.close());

      // Zero deposit_details rows are ever fabricated by this migration
      // -- not even for the pre-existing deposit account above.
      final List<DepositDetailsRow> deposits = await db.select(db.depositDetails).get();
      expect(deposits, isEmpty);

      // Account rows remain completely unchanged.
      final List<AccountRow> accounts = await db.select(db.accounts).get();
      expect(accounts.length, 1);
      final AccountRow account = accounts.single;
      expect(account.id, 'account-deposit');
      expect(account.balanceClassValue, BalanceClass.asset);
      expect(account.subtypeValue, FinancialAccountSubtype.deposit);
      expect(account.openingBalanceMinorUnits, 50000);

      // Transaction rows remain completely unchanged.
      final List<Transaction> transactions = await db.select(db.transactions).get();
      expect(transactions.length, 1);
      final Transaction tx = transactions.single;
      expect(tx.id, 'transaction-v11-fixture');
      expect(tx.accountId, 'account-deposit');
      expect(tx.amountMinorUnits, 2750);
      expect(tx.type, 'income');

      // Brand-new deposit details can be written through the CURRENT
      // repository API and correctly link to the migrated account,
      // proving the post-migration schema is genuinely usable, not just
      // structurally present.
      final AccountRepository accountRepo = AccountRepository(db);
      final DepositRepository depositRepo = DepositRepository(db, accountRepo);
      final String newDepositId = await depositRepo.createDetails(
        profileId: 'profile-v11-fixture',
        accountId: 'account-deposit',
        depositType: DepositType.fixed,
        termNumber: 12,
        termUnit: DepositTermUnit.months,
        startDateUtc: DateTime.utc(2026, 1, 1),
        interestRateBasisPoints: 500,
        interestMethod: DepositInterestMethod.simple,
      );
      final DepositDetailsRow newDeposit =
          await depositRepo.requireActiveForAccount('account-deposit');
      expect(newDeposit.id, newDepositId);
      expect(newDeposit.interestRateBasisPoints, 500);
    },
  );

  test('empty (never-populated) v11 database upgrades cleanly to v12', () async {
    final Directory tempDir =
        Directory.systemTemp.createTempSync('afc_v11_empty_migration_test_');
    final File dbFile = File('${tempDir.path}/v11_empty_fixture.sqlite');
    addTearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    final sqlite3.Database fixture = sqlite3.sqlite3.open(dbFile.path);
    try {
      fixture.execute(_v11Schema);
      fixture.execute('PRAGMA user_version = 11;');
    } finally {
      fixture.dispose();
    }

    final AppDatabase db = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(() async => db.close());

    final List<AccountRow> accounts = await db.select(db.accounts).get();
    expect(accounts, isEmpty);
    final List<DepositDetailsRow> deposits = await db.select(db.depositDetails).get();
    expect(deposits, isEmpty);
  });

  test('a brand-new (never-upgraded) database created at latest schema (v12) works', () async {
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() async => db.close());

    // onCreate path -- proves the current table definitions themselves
    // (not just the upgrade path) are internally consistent and
    // creatable from scratch.
    final List<AccountRow> accounts = await db.select(db.accounts).get();
    expect(accounts, isEmpty);
    final List<DepositDetailsRow> deposits = await db.select(db.depositDetails).get();
    expect(deposits, isEmpty);
  });
}
