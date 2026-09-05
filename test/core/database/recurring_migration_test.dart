import 'dart:io';

import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

// NOTE: this file exercises generated Drift code (AppDatabase,
// RecurringRulesCompanion, etc. from app_database.g.dart) that could not
// be generated inside the sandbox that wrote it -- run
// `dart run build_runner build --delete-conflicting-outputs` locally
// before running this test. See CLAUDE_FIRST_CODING_PROMPT.md.
//
// This test proves the v3 -> v4 schema migration (`docs/14_DECISION_LOG.md`
// ADR-023): a database file left at schema v3 (Beta 1 Task 3, before
// `recurring_rules`/`recurring_occurrences` existed) opens cleanly under
// the current (v4) `AppDatabase`, the `onUpgrade` `from < 4` branch
// creates both new tables, and every pre-existing v3 row -- across every
// table Beta 0/1 defined by that point -- is still present with its data
// intact.
//
// Per `docs/14_DECISION_LOG.md` ADR-022/ADR-023, this test does NOT
// assert "byte-for-byte unchanged". It asserts that existing v3 LOGICAL
// data survives the upgrade unchanged: row counts, ids, and the specific
// field values seeded below. DateTime fields read back via raw
// `db.select(...)` (not through a repository's read-side UTC re-tagging
// -- see `SavingsGoalRepository._withUtcDateTimes`'s doc comment) are
// compared via `.toUtc()` on the actual side: Drift's default
// (non-text) DateTime storage round-trips the correct instant but reads
// it back tagged as local time, not UTC -- `.toUtc()` only re-tags the
// already-correct instant, it never moves it.
//
// The v3 fixture below is a hand-authored raw-SQL schema, deliberately
// NOT built through any Drift-generated class -- if it were, opening it
// would just create the CURRENT (v4) schema directly via `onCreate`
// rather than exercising the `onUpgrade` migration path at all. Its
// CREATE TABLE statements are hand-matched, column-for-column, against
// `lib/core/database/tables.dart` as it stood at schema v3 (i.e.
// everything in that file except `RecurringRules` and
// `RecurringOccurrences`) and cross-checked against the generated
// `$XyzTable` column definitions in `app_database.g.dart` (table/column
// names are drift's default camelCase -> snake_case conversion).
//
// DateTime encoding: `_epochSeconds` assumes drift ^2.20.3's DEFAULT
// (non-text) `DateTime` encoding for `NativeDatabase` -- unix seconds
// since the epoch, stored as an SQLite INTEGER -- confirmed correct
// against the generated code while fixing Beta 1 Task 3's analyzer/test
// feedback (see `SavingsGoalRepository._withUtcDateTimes`'s doc
// comment); this project still has no `build.yaml`
// `store_date_time_values_as_text` override, so the same default
// applies here. Booleans are encoded as SQLite INTEGER 0/1, drift's
// standard convention.
void main() {
  test(
    'v3 -> v4 upgrade creates recurring_rules/recurring_occurrences and leaves existing v3 data intact',
    () async {
      final Directory tempDir = Directory.systemTemp.createTempSync('afc_v3_to_v4_migration_test_');
      final File dbFile = File('${tempDir.path}/v3_fixture.sqlite');
      addTearDown(() {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });

      final DateTime profileCreatedAt = DateTime.utc(2026, 1, 1, 9, 30);
      final DateTime profileUpdatedAt = DateTime.utc(2026, 3, 5, 14, 0);
      final DateTime accountCreatedAt = DateTime.utc(2026, 1, 2, 8, 0);
      final DateTime transactionOccurredAt = DateTime.utc(2026, 4, 10, 12, 0);
      final DateTime budgetCreatedAt = DateTime.utc(2026, 8, 1, 8, 0);
      final DateTime goalCreatedAt = DateTime.utc(2026, 8, 2, 9, 0);
      final DateTime goalTargetDate = DateTime.utc(2026, 12, 25);
      final DateTime contributionAt = DateTime.utc(2026, 8, 3, 10, 0);

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
        ''');

        fixture.execute('PRAGMA user_version = 3;');

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
            'profile-v3-fixture',
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
          'INSERT INTO accounts (id, profile_id, name, type, currency_code, '
          'opening_balance_minor_units, is_active, created_at, updated_at, deleted_at) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);',
          <Object?>[
            'account-v3-fixture',
            'profile-v3-fixture',
            'Wallet',
            'cash',
            'JPY',
            500000,
            1,
            _epochSeconds(accountCreatedAt),
            _epochSeconds(accountCreatedAt),
            null,
          ],
        );

        fixture.execute(
          'INSERT INTO transactions (id, profile_id, account_id, destination_account_id, type, '
          'amount_minor_units, currency_code, category_id, note, occurred_at, created_at, '
          'updated_at, deleted_at, sync_version, sync_status) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);',
          <Object?>[
            'transaction-v3-fixture',
            'profile-v3-fixture',
            'account-v3-fixture',
            null,
            'expense',
            12000,
            'JPY',
            null,
            'Groceries',
            _epochSeconds(transactionOccurredAt),
            _epochSeconds(transactionOccurredAt),
            _epochSeconds(transactionOccurredAt),
            null,
            0,
            'localOnly',
          ],
        );

        fixture.execute(
          'INSERT INTO budgets (id, profile_id, category_id, currency_code, year, month, '
          'amount_minor_units, created_at, updated_at, deleted_at, sync_version, sync_status) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);',
          <Object?>[
            'budget-v3-fixture',
            'profile-v3-fixture',
            null,
            'JPY',
            2026,
            8,
            150000,
            _epochSeconds(budgetCreatedAt),
            _epochSeconds(budgetCreatedAt),
            null,
            0,
            'localOnly',
          ],
        );

        fixture.execute(
          'INSERT INTO savings_goals (id, profile_id, name, target_amount_minor_units, '
          'currency_code, target_date, created_at, updated_at, deleted_at, sync_version, '
          'sync_status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);',
          <Object?>[
            'goal-v3-fixture',
            'profile-v3-fixture',
            'Emergency Fund',
            500000,
            'JPY',
            _epochSeconds(goalTargetDate),
            _epochSeconds(goalCreatedAt),
            _epochSeconds(goalCreatedAt),
            null,
            0,
            'localOnly',
          ],
        );

        fixture.execute(
          'INSERT INTO savings_goal_contributions (id, goal_id, amount_minor_units, '
          'currency_code, contributed_at, created_at, deleted_at, sync_version, sync_status) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);',
          <Object?>[
            'contribution-v3-fixture',
            'goal-v3-fixture',
            10000,
            'JPY',
            _epochSeconds(contributionAt),
            _epochSeconds(contributionAt),
            null,
            0,
            'localOnly',
          ],
        );
      } finally {
        fixture.dispose();
      }

      // --- "App upgrade": open the same file through the REAL, current
      // (v4) AppDatabase. This must run the `onUpgrade` `from < 4`
      // branch, since the file's `user_version` is 3. ---
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase(dbFile));
      addTearDown(() async => db.close());

      // The new v4 tables exist and are usable -- if `onUpgrade`'s
      // `from < 4` branch had not run, these would throw ("no such
      // table") rather than return empty lists.
      final List<RecurringRuleRow> rulesBeforeInsert = await db.select(db.recurringRules).get();
      expect(rulesBeforeInsert, isEmpty);
      final List<RecurringOccurrenceRow> occurrencesBeforeInsert =
          await db.select(db.recurringOccurrences).get();
      expect(occurrencesBeforeInsert, isEmpty);

      // A new-schema row can actually be written and read back.
      await db.into(db.recurringRules).insert(
            RecurringRulesCompanion.insert(
              id: 'rule-after-migration',
              profileId: 'profile-v3-fixture',
              kind: 'expense',
              name: 'Rent',
              amountMinorUnits: 80000,
              currencyCode: 'JPY',
              accountId: 'account-v3-fixture',
              frequency: 'monthly',
              startDate: DateTime.utc(2026, 9, 1),
              createdAt: DateTime.utc(2026, 9, 3),
              updatedAt: DateTime.utc(2026, 9, 3),
            ),
          );
      await db.into(db.recurringOccurrences).insert(
            RecurringOccurrencesCompanion.insert(
              id: 'occurrence-after-migration',
              ruleId: 'rule-after-migration',
              scheduledDate: DateTime.utc(2026, 9, 1),
              status: 'skipped',
              handledAt: DateTime.utc(2026, 9, 3),
              createdAt: DateTime.utc(2026, 9, 3),
            ),
          );
      final RecurringRuleRow storedRule = await db.select(db.recurringRules).getSingle();
      expect(storedRule.name, 'Rent');
      final RecurringOccurrenceRow storedOccurrence =
          await db.select(db.recurringOccurrences).getSingle();
      expect(storedOccurrence.status, 'skipped');

      // Pre-existing v3 data survives the upgrade -- logically unchanged,
      // not asserted as raw database-file bytes (see the file-level doc
      // comment).
      final List<CurrencyRow> currencyRows = await db.select(db.currencies).get();
      expect(currencyRows.length, 1);
      expect(currencyRows.single.code, 'JPY');

      final List<ProfileRow> profileRows = await db.select(db.profiles).get();
      expect(profileRows.length, 1);
      final ProfileRow profile = profileRows.single;
      expect(profile.id, 'profile-v3-fixture');
      expect(profile.displayName, 'Migration Test User');
      expect(profile.createdAt.toUtc(), profileCreatedAt);
      expect(profile.updatedAt.toUtc(), profileUpdatedAt);

      final List<AccountRow> accountRows = await db.select(db.accounts).get();
      expect(accountRows.length, 1);
      expect(accountRows.single.id, 'account-v3-fixture');
      expect(accountRows.single.openingBalanceMinorUnits, 500000);

      final List<Transaction> transactionRows = await db.select(db.transactions).get();
      expect(transactionRows.length, 1);
      expect(transactionRows.single.id, 'transaction-v3-fixture');
      expect(transactionRows.single.amountMinorUnits, 12000);
      expect(transactionRows.single.occurredAt.toUtc(), transactionOccurredAt);

      final List<BudgetRow> budgetRows = await db.select(db.budgets).get();
      expect(budgetRows.length, 1);
      final BudgetRow budget = budgetRows.single;
      expect(budget.id, 'budget-v3-fixture');
      expect(budget.year, 2026);
      expect(budget.month, 8);
      expect(budget.amountMinorUnits, 150000);
      expect(budget.createdAt.toUtc(), budgetCreatedAt);

      final List<SavingsGoalRow> goalRows = await db.select(db.savingsGoals).get();
      expect(goalRows.length, 1);
      final SavingsGoalRow goal = goalRows.single;
      expect(goal.id, 'goal-v3-fixture');
      expect(goal.name, 'Emergency Fund');
      expect(goal.targetAmountMinorUnits, 500000);
      expect(goal.targetDate?.toUtc(), goalTargetDate);
      expect(goal.createdAt.toUtc(), goalCreatedAt);

      final List<SavingsGoalContributionRow> contributionRows =
          await db.select(db.savingsGoalContributions).get();
      expect(contributionRows.length, 1);
      final SavingsGoalContributionRow contribution = contributionRows.single;
      expect(contribution.id, 'contribution-v3-fixture');
      expect(contribution.goalId, 'goal-v3-fixture');
      expect(contribution.amountMinorUnits, 10000);
      expect(contribution.contributedAt.toUtc(), contributionAt);
    },
  );
}

/// Encodes [dateTime] the way drift ^2.20.3's default (non-text)
/// `DateTime` column storage does for a `NativeDatabase` -- unix seconds
/// since the epoch, truncating anything below one second.
int _epochSeconds(DateTime dateTime) => dateTime.toUtc().millisecondsSinceEpoch ~/ 1000;
