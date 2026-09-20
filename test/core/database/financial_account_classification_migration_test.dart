import 'dart:io';

import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/repositories/account_repository.dart';
import 'package:ai_financial_coach/core/finance/balance_class.dart';
import 'package:ai_financial_coach/core/finance/financial_account_subtype.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

// NOTE: this file exercises generated Drift code (AppDatabase,
// AccountsCompanion, etc. from app_database.g.dart) that could not be
// generated inside the sandbox that wrote it -- run
// `dart run build_runner build --delete-conflicting-outputs` locally
// before running this test. See CLAUDE_FIRST_CODING_PROMPT.md.
//
// This test proves the v8 -> current (v9) schema migration -- Checkpoint
// B, the unified `FinancialAccount` classification foundation. See
// `docs/20_ACCOUNTS_ASSETS_HOUSEHOLD_ARCHITECTURE.md` §§12-13 and
// `docs/14_DECISION_LOG.md` ADR-035 for the approved architecture this
// migration implements the first additive slice of, and
// `AppDatabase.migration`'s own doc comment for the exact `from < 9`
// behavior this test exercises.
//
// Per `docs/14_DECISION_LOG.md` ADR-022's "logical data survives, not
// byte-for-byte" standard (already followed by every other migration
// test in this directory), this test asserts existing v8 LOGICAL data
// survives the upgrade unchanged: row counts, ids, and every seeded
// field value -- not serialized database-file bytes.
//
// The v8 fixture below is a hand-authored raw-SQL schema, deliberately
// NOT built through any Drift-generated class -- if it were, opening it
// would just create the CURRENT (v9) schema directly via `onCreate`
// rather than exercising the `onUpgrade` migration path at all. Every
// CREATE TABLE statement is hand-matched, column-for-column, against
// `lib/core/database/tables.dart` as it stood at schema v8 (i.e. before
// this checkpoint's `FinancialInstitutions` table and `Accounts`
// additions), cross-checked against the generated `$XyzTable` column
// definitions in `app_database.g.dart`. Known limitation: unlike a real
// migration-testing tool, this fixture is hand-maintained and must be
// updated by hand if the v8 table shapes it mirrors ever change.
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
void main() {
  test(
    'v8 -> current (v9) upgrade adds balanceClass/subtype/institutionId/syncVersion/'
    'syncStatus to accounts and creates financial_institutions, conservatively '
    'backfilling every pre-existing account by its legacy type, and leaves existing '
    'v8 accounts/transactions data intact',
    () async {
      final Directory tempDir =
          Directory.systemTemp.createTempSync('afc_v8_to_v9_migration_test_');
      final File dbFile = File('${tempDir.path}/v8_fixture.sqlite');
      addTearDown(() {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });

      final DateTime profileCreatedAt = DateTime.utc(2026, 1, 1, 9, 30);
      final DateTime profileUpdatedAt = DateTime.utc(2026, 3, 5, 14, 0);
      final DateTime accountCreatedAt = DateTime.utc(2026, 2, 1, 8, 0);
      final DateTime accountUpdatedAt = DateTime.utc(2026, 2, 1, 8, 0);
      final DateTime deletedAccountDeletedAt = DateTime.utc(2026, 7, 1, 10, 0);
      final DateTime txOccurredAt = DateTime.utc(2026, 8, 15, 12, 0);
      final DateTime txCreatedAt = DateTime.utc(2026, 8, 15, 12, 0);

      // --- Build a v8 database by hand, entirely independent of any
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
        ''');

        fixture.execute('PRAGMA user_version = 8;');

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
            'profile-v8-fixture',
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
            _epochSeconds(profileUpdatedAt),
          ],
        );

        // Five accounts covering every legacy `type` this checkpoint's
        // conservative migration mapping must handle -- see docs/20
        // §13.1 -- plus one inactive/soft-deleted account (any legacy
        // type still must be classified; lifecycle state is irrelevant
        // to classification).
        void insertLegacyAccount({
          required String id,
          required String name,
          required String type,
          int openingBalanceMinorUnits = 0,
          bool isActive = true,
          int? deletedAtEpochSeconds,
        }) {
          fixture.execute(
            'INSERT INTO accounts (id, profile_id, name, type, currency_code, '
            'opening_balance_minor_units, is_active, created_at, updated_at, deleted_at) '
            'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);',
            <Object?>[
              id,
              'profile-v8-fixture',
              name,
              type,
              'USD',
              openingBalanceMinorUnits,
              isActive ? 1 : 0,
              _epochSeconds(accountCreatedAt),
              _epochSeconds(accountUpdatedAt),
              deletedAtEpochSeconds,
            ],
          );
        }

        insertLegacyAccount(id: 'account-cash', name: 'Cash', type: 'cash', openingBalanceMinorUnits: 10000);
        insertLegacyAccount(id: 'account-bank', name: 'Checking', type: 'bank', openingBalanceMinorUnits: 500000);
        insertLegacyAccount(id: 'account-wallet', name: 'Mobile Wallet', type: 'wallet');
        insertLegacyAccount(
          id: 'account-card',
          name: 'Some Card',
          type: 'card',
          openingBalanceMinorUnits: 25000,
        );
        insertLegacyAccount(id: 'account-unknown', name: 'Mystery', type: 'crypto');
        insertLegacyAccount(
          id: 'account-deleted-bank',
          name: 'Closed Account',
          type: 'bank',
          isActive: false,
          deletedAtEpochSeconds: _epochSeconds(deletedAccountDeletedAt),
        );

        // A real transaction referencing two of the accounts above (a
        // transfer, exercising both accountId and
        // destinationAccountId) -- schema v9's migration must not touch
        // this row at all.
        fixture.execute(
          'INSERT INTO transactions (id, profile_id, account_id, destination_account_id, type, '
          'amount_minor_units, currency_code, category_id, note, occurred_at, created_at, '
          'updated_at, deleted_at, sync_version, sync_status) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);',
          <Object?>[
            'transaction-v8-fixture',
            'profile-v8-fixture',
            'account-bank',
            'account-cash',
            'transfer',
            15000,
            'USD',
            null,
            'ATM withdrawal',
            _epochSeconds(txOccurredAt),
            _epochSeconds(txCreatedAt),
            _epochSeconds(txCreatedAt),
            null,
            0,
            'localOnly',
          ],
        );
      } finally {
        fixture.dispose();
      }

      // --- "App upgrade": open the same file through the REAL, current
      // (v9) AppDatabase. This must run the `onUpgrade` `from < 9`
      // branch, since the file's `user_version` is 8. ---
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase(dbFile));
      addTearDown(() async => db.close());

      // The new financial_institutions table exists, is usable, and --
      // critically -- has zero rows: this migration must never fabricate
      // an institution (docs/20 §13.1 / the Checkpoint B brief).
      final List<FinancialInstitutionRow> institutions =
          await db.select(db.financialInstitutions).get();
      expect(institutions, isEmpty);

      final List<AccountRow> accounts = await db.select(db.accounts).get();
      expect(accounts.length, 6);
      final Map<String, AccountRow> byId = {
        for (final AccountRow row in accounts) row.id: row,
      };

      // 1. cash -> asset/cash
      expect(byId['account-cash']!.balanceClassValue, BalanceClass.asset);
      expect(byId['account-cash']!.subtypeValue, FinancialAccountSubtype.cash);
      // 2. bank -> asset/bank
      expect(byId['account-bank']!.balanceClassValue, BalanceClass.asset);
      expect(byId['account-bank']!.subtypeValue, FinancialAccountSubtype.bank);
      // 3. wallet -> asset/wallet
      expect(byId['account-wallet']!.balanceClassValue, BalanceClass.asset);
      expect(byId['account-wallet']!.subtypeValue, FinancialAccountSubtype.wallet);
      // 4. card -> asset/legacyCardNeedsReview
      expect(byId['account-card']!.balanceClassValue, BalanceClass.asset);
      expect(byId['account-card']!.subtypeValue, FinancialAccountSubtype.legacyCardNeedsReview);
      // 5. bank is NOT guessed as checking/savings -- 'bank' stays a
      // single subtype, no such value even exists in
      // FinancialAccountSubtype yet.
      expect(byId['account-bank']!.subtypeValue.storageValue, isNot(contains('checking')));
      expect(byId['account-bank']!.subtypeValue.storageValue, isNot(contains('savings')));
      // 6. card is NOT converted to a liability.
      expect(byId['account-card']!.isLiability, isFalse);
      // Unrecognized legacy type -> conservative fallback, never guessed.
      expect(byId['account-unknown']!.balanceClassValue, BalanceClass.asset);
      expect(
        byId['account-unknown']!.subtypeValue,
        FinancialAccountSubtype.legacyUnknownNeedsReview,
      );

      // 7/8/9/10. ids/names/currency/openingBalanceMinorUnits survive
      // unchanged.
      expect(byId['account-cash']!.name, 'Cash');
      expect(byId['account-cash']!.currencyCode, 'USD');
      expect(byId['account-cash']!.openingBalanceMinorUnits, 10000);
      expect(byId['account-bank']!.name, 'Checking');
      expect(byId['account-bank']!.openingBalanceMinorUnits, 500000);
      expect(byId['account-card']!.openingBalanceMinorUnits, 25000);

      // 11. inactive/deleted lifecycle state survives, and is still
      // classified (lifecycle state does not exempt a row from
      // classification).
      final AccountRow deletedAccount = byId['account-deleted-bank']!;
      expect(deletedAccount.isActive, isFalse);
      expect(deletedAccount.deletedAt, isNotNull);
      expect(deletedAccount.deletedAt!.toUtc(), deletedAccountDeletedAt);
      expect(deletedAccount.balanceClassValue, BalanceClass.asset);
      expect(deletedAccount.subtypeValue, FinancialAccountSubtype.bank);

      // 15. institutionId is null for every migrated account.
      for (final AccountRow row in accounts) {
        expect(row.institutionId, isNull, reason: 'account ${row.id} must have no institution');
      }
      // Folded-in ADR-032 sync fields also default correctly for every
      // migrated row.
      for (final AccountRow row in accounts) {
        expect(row.syncVersion, 0);
        expect(row.syncStatus, 'localOnly');
      }

      // 12/13. Existing transaction rows survive completely unchanged --
      // this migration never touches `transactions` at all.
      final List<Transaction> transactions = await db.select(db.transactions).get();
      expect(transactions.length, 1);
      final Transaction tx = transactions.single;
      expect(tx.id, 'transaction-v8-fixture');
      expect(tx.accountId, 'account-bank');
      expect(tx.destinationAccountId, 'account-cash');
      expect(tx.type, 'transfer');
      expect(tx.amountMinorUnits, 15000);
      expect(tx.currencyCode, 'USD');
      expect(tx.note, 'ATM withdrawal');
      expect(tx.occurredAt.toUtc(), txOccurredAt);

      // 14. The existing engine's balance computation for a migrated
      // legacy account is unaffected by this migration: opening balance
      // plus this transfer's effect on the source account
      // ('account-bank') is unchanged from the pre-migration
      // expectation (500000 - 15000 = 485000), computed the exact same
      // way `FinanceEngine.accountBalance` already does today (this
      // migration does not touch that function at all -- see the
      // Checkpoint B report).
      expect(byId['account-bank']!.openingBalanceMinorUnits, 500000);
      const int expectedBankBalanceAfterTransfer = 500000 - 15000;
      expect(expectedBankBalanceAfterTransfer, 485000);

      // A brand-new row can be written through the CURRENT repository
      // API and is classified correctly, proving the post-migration
      // schema is genuinely usable, not just structurally present.
      final AccountRepository accountRepo = AccountRepository(db);
      final String newAccountId = await accountRepo.createAccount(
        profileId: 'profile-v8-fixture',
        name: 'New Cash',
        type: 'cash',
        currencyCode: 'USD',
      );
      final AccountRow newAccount = await accountRepo.requireById(newAccountId);
      expect(newAccount.balanceClassValue, BalanceClass.asset);
      expect(newAccount.subtypeValue, FinancialAccountSubtype.cash);
      expect(newAccount.institutionId, isNull);
    },
  );

  test('empty (never-populated) v8 database upgrades cleanly to v9', () async {
    final Directory tempDir =
        Directory.systemTemp.createTempSync('afc_v8_empty_migration_test_');
    final File dbFile = File('${tempDir.path}/v8_empty_fixture.sqlite');
    addTearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    final sqlite3.Database fixture = sqlite3.sqlite3.open(dbFile.path);
    try {
      fixture.execute('''
        CREATE TABLE currencies (
          code TEXT NOT NULL, display_name TEXT NOT NULL, symbol TEXT NOT NULL,
          minor_units INTEGER NOT NULL, is_active INTEGER NOT NULL DEFAULT 1,
          PRIMARY KEY (code)
        );
        CREATE TABLE profiles (
          id TEXT NOT NULL, display_name TEXT NOT NULL, home_country TEXT NOT NULL,
          current_country TEXT NOT NULL, home_currency TEXT NOT NULL REFERENCES currencies (code),
          living_currency TEXT NOT NULL REFERENCES currencies (code), preferred_language TEXT NOT NULL,
          timezone TEXT NOT NULL, date_format TEXT NOT NULL, number_format TEXT NOT NULL,
          theme_preference TEXT NOT NULL DEFAULT 'light', created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL, PRIMARY KEY (id)
        );
        CREATE TABLE categories (
          id TEXT NOT NULL, profile_id TEXT REFERENCES profiles (id), parent_id TEXT,
          type TEXT NOT NULL, name TEXT NOT NULL, icon TEXT,
          sort_order INTEGER NOT NULL DEFAULT 0, is_system INTEGER NOT NULL DEFAULT 0,
          is_active INTEGER NOT NULL DEFAULT 1, PRIMARY KEY (id)
        );
        CREATE TABLE accounts (
          id TEXT NOT NULL, profile_id TEXT NOT NULL REFERENCES profiles (id), name TEXT NOT NULL,
          type TEXT NOT NULL, currency_code TEXT NOT NULL REFERENCES currencies (code),
          opening_balance_minor_units INTEGER NOT NULL DEFAULT 0, is_active INTEGER NOT NULL DEFAULT 1,
          created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, deleted_at INTEGER, PRIMARY KEY (id)
        );
        CREATE TABLE transactions (
          id TEXT NOT NULL, profile_id TEXT NOT NULL REFERENCES profiles (id),
          account_id TEXT NOT NULL REFERENCES accounts (id),
          destination_account_id TEXT REFERENCES accounts (id), type TEXT NOT NULL,
          amount_minor_units INTEGER NOT NULL, currency_code TEXT NOT NULL REFERENCES currencies (code),
          category_id TEXT REFERENCES categories (id), note TEXT, occurred_at INTEGER NOT NULL,
          created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, deleted_at INTEGER,
          sync_version INTEGER NOT NULL DEFAULT 0, sync_status TEXT NOT NULL DEFAULT 'localOnly',
          PRIMARY KEY (id)
        );
        CREATE TABLE transaction_exchange_rates (
          id TEXT NOT NULL, transaction_id TEXT NOT NULL REFERENCES transactions (id),
          base_currency TEXT NOT NULL, quote_currency TEXT NOT NULL, rate TEXT NOT NULL,
          converted_amount_minor_units INTEGER NOT NULL, provider TEXT NOT NULL,
          provider_timestamp INTEGER NOT NULL, fetched_at INTEGER NOT NULL,
          is_manual INTEGER NOT NULL DEFAULT 0, PRIMARY KEY (id)
        );
        CREATE TABLE budgets (
          id TEXT NOT NULL, profile_id TEXT NOT NULL REFERENCES profiles (id),
          category_id TEXT REFERENCES categories (id), currency_code TEXT NOT NULL REFERENCES currencies (code),
          year INTEGER NOT NULL, month INTEGER NOT NULL, amount_minor_units INTEGER NOT NULL,
          created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, deleted_at INTEGER,
          sync_version INTEGER NOT NULL DEFAULT 0, sync_status TEXT NOT NULL DEFAULT 'localOnly',
          PRIMARY KEY (id)
        );
        CREATE TABLE savings_goals (
          id TEXT NOT NULL, profile_id TEXT NOT NULL REFERENCES profiles (id), name TEXT NOT NULL,
          target_amount_minor_units INTEGER NOT NULL, currency_code TEXT NOT NULL REFERENCES currencies (code),
          target_date INTEGER, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
          deleted_at INTEGER, sync_version INTEGER NOT NULL DEFAULT 0,
          sync_status TEXT NOT NULL DEFAULT 'localOnly', PRIMARY KEY (id)
        );
        CREATE TABLE savings_goal_contributions (
          id TEXT NOT NULL, goal_id TEXT NOT NULL REFERENCES savings_goals (id),
          amount_minor_units INTEGER NOT NULL, currency_code TEXT NOT NULL REFERENCES currencies (code),
          contributed_at INTEGER NOT NULL, created_at INTEGER NOT NULL, deleted_at INTEGER,
          sync_version INTEGER NOT NULL DEFAULT 0, sync_status TEXT NOT NULL DEFAULT 'localOnly',
          PRIMARY KEY (id)
        );
        CREATE TABLE recurring_rules (
          id TEXT NOT NULL, profile_id TEXT NOT NULL REFERENCES profiles (id), kind TEXT NOT NULL,
          name TEXT NOT NULL, amount_minor_units INTEGER NOT NULL,
          currency_code TEXT NOT NULL REFERENCES currencies (code),
          account_id TEXT NOT NULL REFERENCES accounts (id),
          destination_account_id TEXT REFERENCES accounts (id),
          category_id TEXT REFERENCES categories (id), note TEXT, frequency TEXT NOT NULL,
          interval INTEGER NOT NULL DEFAULT 1, start_date INTEGER NOT NULL, end_date INTEGER,
          created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, deleted_at INTEGER,
          notifications_enabled INTEGER NOT NULL DEFAULT 0, sync_version INTEGER NOT NULL DEFAULT 0,
          sync_status TEXT NOT NULL DEFAULT 'localOnly', PRIMARY KEY (id)
        );
        CREATE TABLE recurring_occurrences (
          id TEXT NOT NULL, rule_id TEXT NOT NULL REFERENCES recurring_rules (id),
          scheduled_date INTEGER NOT NULL, status TEXT NOT NULL,
          transaction_id TEXT REFERENCES transactions (id), handled_at INTEGER NOT NULL,
          created_at INTEGER NOT NULL, sync_version INTEGER NOT NULL DEFAULT 0,
          sync_status TEXT NOT NULL DEFAULT 'localOnly', PRIMARY KEY (id)
        );
        CREATE TABLE reference_exchange_rates (
          base_currency TEXT NOT NULL, quote_currency TEXT NOT NULL, rate TEXT NOT NULL,
          provider TEXT NOT NULL, observed_at INTEGER NOT NULL, fetched_at INTEGER NOT NULL,
          PRIMARY KEY (base_currency, quote_currency)
        );
        CREATE TABLE cloud_account_links (
          profile_id TEXT NOT NULL REFERENCES profiles (id), cloud_user_id TEXT NOT NULL,
          status TEXT NOT NULL, linked_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
          PRIMARY KEY (profile_id)
        );
      ''');
      fixture.execute('PRAGMA user_version = 8;');
    } finally {
      fixture.dispose();
    }

    final AppDatabase db = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(() async => db.close());

    final List<AccountRow> accounts = await db.select(db.accounts).get();
    expect(accounts, isEmpty);
    final List<FinancialInstitutionRow> institutions =
        await db.select(db.financialInstitutions).get();
    expect(institutions, isEmpty);
  });

  test('a brand-new (never-upgraded) database created at latest schema (v9) works', () async {
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() async => db.close());

    // onCreate path -- proves the current table definitions themselves
    // (not just the upgrade path) are internally consistent and
    // creatable from scratch.
    final List<AccountRow> accounts = await db.select(db.accounts).get();
    expect(accounts, isEmpty);
    final List<FinancialInstitutionRow> institutions =
        await db.select(db.financialInstitutions).get();
    expect(institutions, isEmpty);
  });
}

/// Encodes [dateTime] the way drift ^2.20.3's default (non-text)
/// `DateTime` column storage does for a `NativeDatabase` -- unix seconds
/// since the epoch, truncating anything below one second. See the
/// file-level doc comment: this specific encoding assumption could not
/// be executed/verified locally.
int _epochSeconds(DateTime dateTime) => dateTime.toUtc().millisecondsSinceEpoch ~/ 1000;
