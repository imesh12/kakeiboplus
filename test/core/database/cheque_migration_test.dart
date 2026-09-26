import 'dart:io';

import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/repositories/account_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/cheque_book_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/cheque_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/transaction_repository.dart';
import 'package:ai_financial_coach/core/finance/balance_class.dart';
import 'package:ai_financial_coach/core/finance/cheque_direction.dart';
import 'package:ai_financial_coach/core/finance/cheque_status.dart';
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
// This test proves the v12 -> current (v13) schema migration --
// Checkpoint N, the ChequeBooks/Cheques foundation. See
// `docs/20_ACCOUNTS_ASSETS_HOUSEHOLD_ARCHITECTURE.md` §13.16 and
// `AppDatabase.migration`'s own doc comment for the exact `from < 13`
// behavior this test exercises.
//
// The v12 fixture below is `deposit_migration_test.dart`'s own
// `_v11Schema` PLUS the `deposit_details` table -- i.e. this IS what v12
// looks like (Checkpoint F's own migration only ever adds that one
// table to v11). Exactly like the v10 -> v11 / v11 -> v12 steps, this
// checkpoint's v12 -> v13 step only ever CREATEs two brand-new tables
// (`cheque_books`, `cheques`), which cannot fail merely because some
// unrelated table is absent -- so this migration step introduces no new
// requirement on any OTHER historical fixture in this directory.
const String _v12Schema = '''
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

  CREATE TABLE deposit_details (
    id TEXT NOT NULL,
    profile_id TEXT NOT NULL REFERENCES profiles (id),
    account_id TEXT NOT NULL UNIQUE REFERENCES accounts (id),
    deposit_type TEXT NOT NULL,
    term_number INTEGER NOT NULL,
    term_unit TEXT NOT NULL,
    start_date INTEGER NOT NULL,
    maturity_date INTEGER NOT NULL,
    interest_rate_basis_points INTEGER NOT NULL,
    interest_method TEXT NOT NULL,
    compounding_frequency TEXT,
    auto_renew INTEGER NOT NULL DEFAULT 0,
    renewal_mode TEXT,
    interest_destination_account_id TEXT REFERENCES accounts (id),
    installment_amount_minor_units INTEGER,
    installment_frequency TEXT,
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
    '30. v12 -> current (v13) upgrade creates cheque_books/cheques, leaving existing v12 '
    'accounts/transactions/deposit_details data completely intact and fabricating zero '
    'cheque rows',
    () async {
      final Directory tempDir =
          Directory.systemTemp.createTempSync('afc_v12_to_v13_migration_test_');
      final File dbFile = File('${tempDir.path}/v12_fixture.sqlite');
      addTearDown(() {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });

      final DateTime profileCreatedAt = DateTime.utc(2026, 1, 1, 9, 30);
      final DateTime accountCreatedAt = DateTime.utc(2026, 2, 1, 8, 0);
      final DateTime txOccurredAt = DateTime.utc(2026, 8, 15, 12, 0);

      final sqlite3.Database fixture = sqlite3.sqlite3.open(dbFile.path);
      try {
        fixture.execute(_v12Schema);
        fixture.execute('PRAGMA user_version = 12;');

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
            'profile-v12-fixture',
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

        // An ordinary `bank`-subtype asset account, already existing at
        // v12 -- the shape Checkpoint N's chequebooks/cheques will
        // attach to. Proves the migration does not choke on -- or
        // fabricate a chequebook/cheque for -- a pre-existing eligible
        // account.
        fixture.execute(
          'INSERT INTO accounts (id, profile_id, name, type, currency_code, '
          'opening_balance_minor_units, is_active, created_at, updated_at, deleted_at, '
          'balance_class, subtype, institution_id, sync_version, sync_status) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);',
          <Object?>[
            'account-bank',
            'profile-v12-fixture',
            'Everyday Chequing',
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

        // An ordinary, pre-existing expense transaction against that
        // account -- proves the migration leaves unrelated transaction
        // history completely untouched.
        fixture.execute(
          'INSERT INTO transactions (id, profile_id, account_id, destination_account_id, type, '
          'amount_minor_units, currency_code, category_id, note, occurred_at, created_at, '
          'updated_at, deleted_at, sync_version, sync_status, payment_instrument_id) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);',
          <Object?>[
            'transaction-v12-fixture',
            'profile-v12-fixture',
            'account-bank',
            null,
            'expense',
            1500,
            'USD',
            null,
            'Groceries',
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
      // (v13) AppDatabase. This must run the `onUpgrade` `from < 13`
      // branch, since the file's `user_version` is 12. ---
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase(dbFile));
      addTearDown(() async => db.close());

      // Zero cheque_books/cheques rows are ever fabricated by this
      // migration -- not even for the pre-existing eligible bank account
      // above.
      final List<ChequeBookRow> chequeBooks = await db.select(db.chequeBooks).get();
      expect(chequeBooks, isEmpty);
      final List<ChequeRow> cheques = await db.select(db.cheques).get();
      expect(cheques, isEmpty);

      // Account rows remain completely unchanged.
      final List<AccountRow> accounts = await db.select(db.accounts).get();
      expect(accounts.length, 1);
      final AccountRow account = accounts.single;
      expect(account.id, 'account-bank');
      expect(account.balanceClassValue, BalanceClass.asset);
      expect(account.subtypeValue, FinancialAccountSubtype.bank);
      expect(account.openingBalanceMinorUnits, 500000);

      // Transaction rows remain completely unchanged.
      final List<Transaction> transactions = await db.select(db.transactions).get();
      expect(transactions.length, 1);
      final Transaction tx = transactions.single;
      expect(tx.id, 'transaction-v12-fixture');
      expect(tx.accountId, 'account-bank');
      expect(tx.amountMinorUnits, 1500);
      expect(tx.type, 'expense');

      // Brand-new chequebooks/cheques can be written through the
      // CURRENT repository API and correctly link to the migrated
      // account, proving the post-migration schema is genuinely usable,
      // not just structurally present -- and that clearing an issued
      // cheque posts exactly one linked expense transaction.
      final AccountRepository accountRepo = AccountRepository(db);
      final TransactionRepository transactionRepo = TransactionRepository(db, accountRepo);
      final ChequeBookRepository chequeBookRepo = ChequeBookRepository(db, accountRepo);
      final ChequeRepository chequeRepo =
          ChequeRepository(db, accountRepo, chequeBookRepo, transactionRepo);

      final String chequeBookId = await chequeBookRepo.createChequeBook(
        profileId: 'profile-v12-fixture',
        accountId: 'account-bank',
        label: 'Primary chequebook',
      );

      final String chequeId = await chequeRepo.recordIssued(
        profileId: 'profile-v12-fixture',
        accountId: 'account-bank',
        chequeBookId: chequeBookId,
        chequeNumber: '000101',
        amount: Money.fromMinorUnits(25000, 'USD'),
        payeeName: 'Landlord',
        issueDateUtc: DateTime.utc(2026, 9, 1),
      );

      final ChequeRow pending = await chequeRepo.requireById(chequeId);
      expect(pending.statusValue, ChequeStatus.pending);
      expect(pending.directionValue, ChequeDirection.issued);
      expect(pending.chequeNumber, '000101');
      expect(pending.transactionId, isNull);

      final String postedTransactionId = await chequeRepo.markCleared(
        chequeId: chequeId,
        clearedDateUtc: DateTime.utc(2026, 9, 5),
      );

      final ChequeRow cleared = await chequeRepo.requireById(chequeId);
      expect(cleared.statusValue, ChequeStatus.cleared);
      expect(cleared.transactionId, postedTransactionId);

      final Transaction postedTransaction =
          await (db.select(db.transactions)..where((tbl) => tbl.id.equals(postedTransactionId)))
              .getSingle();
      expect(postedTransaction.type, 'expense');
      expect(postedTransaction.amountMinorUnits, 25000);
      expect(postedTransaction.accountId, 'account-bank');
    },
  );

  test('empty (never-populated) v12 database upgrades cleanly to v13', () async {
    final Directory tempDir =
        Directory.systemTemp.createTempSync('afc_v12_empty_migration_test_');
    final File dbFile = File('${tempDir.path}/v12_empty_fixture.sqlite');
    addTearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    final sqlite3.Database fixture = sqlite3.sqlite3.open(dbFile.path);
    try {
      fixture.execute(_v12Schema);
      fixture.execute('PRAGMA user_version = 12;');
    } finally {
      fixture.dispose();
    }

    final AppDatabase db = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(() async => db.close());

    final List<AccountRow> accounts = await db.select(db.accounts).get();
    expect(accounts, isEmpty);
    final List<ChequeBookRow> chequeBooks = await db.select(db.chequeBooks).get();
    expect(chequeBooks, isEmpty);
    final List<ChequeRow> cheques = await db.select(db.cheques).get();
    expect(cheques, isEmpty);
  });

  test('a brand-new (never-upgraded) database created at latest schema (v13) works', () async {
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() async => db.close());

    // onCreate path -- proves the current table definitions themselves
    // (not just the upgrade path) are internally consistent and
    // creatable from scratch.
    final List<AccountRow> accounts = await db.select(db.accounts).get();
    expect(accounts, isEmpty);
    final List<ChequeBookRow> chequeBooks = await db.select(db.chequeBooks).get();
    expect(chequeBooks, isEmpty);
    final List<ChequeRow> cheques = await db.select(db.cheques).get();
    expect(cheques, isEmpty);
  });
}
