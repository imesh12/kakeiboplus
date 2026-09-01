import 'dart:io';

import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// Release gate: "persisted transactions survive database/app restart"
// (docs/19_PRIVATE_BETA_BUILD_PLAN.md Beta 0 exit criteria; Decision 14).
// This test simulates a restart at the database layer: write data through
// one AppDatabase instance backed by a real on-disk SQLite file, close
// it completely, open a NEW AppDatabase instance against the same file
// (exactly as a fresh app launch would), and confirm the data reads back
// unchanged.
//
// NOTE: exercises generated Drift code — see CLAUDE_FIRST_CODING_PROMPT.md.

void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('afc_persistence_test_');
    dbFile = File('${tempDir.path}/test.sqlite');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('transactions, accounts, and profile survive a full close/reopen cycle', () async {
    // --- "First app launch": write data ---
    AppDatabase db = AppDatabase.forTesting(NativeDatabase(dbFile));

    await db.into(db.profiles).insert(
          ProfilesCompanion.insert(
            id: 'profile-1',
            displayName: 'Restart Test User',
            homeCountry: 'LK',
            currentCountry: 'JP',
            homeCurrency: 'LKR',
            livingCurrency: 'JPY',
            preferredLanguage: 'en',
            timezone: 'Asia/Tokyo',
            dateFormat: 'yyyy-MM-dd',
            numberFormat: '#,##0.##',
            createdAt: DateTime.utc(2026, 1, 1),
            updatedAt: DateTime.utc(2026, 1, 1),
          ),
        );
    await db.into(db.accounts).insert(
          AccountsCompanion.insert(
            id: 'account-1',
            profileId: 'profile-1',
            name: 'Wallet',
            type: 'cash',
            currencyCode: 'JPY',
            openingBalanceMinorUnits: const Value<int>(50000),
            createdAt: DateTime.utc(2026, 1, 1),
            updatedAt: DateTime.utc(2026, 1, 1),
          ),
        );
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            id: 'tx-1',
            profileId: 'profile-1',
            accountId: 'account-1',
            type: 'expense',
            amountMinorUnits: 1200,
            currencyCode: 'JPY',
            occurredAt: DateTime.utc(2026, 1, 2),
            createdAt: DateTime.utc(2026, 1, 2),
            updatedAt: DateTime.utc(2026, 1, 2),
          ),
        );

    // --- "App restart": fully close, then open a fresh instance ---
    await db.close();
    db = AppDatabase.forTesting(NativeDatabase(dbFile));

    final ProfileRow profile = await db.select(db.profiles).getSingle();
    final AccountRow account = await db.select(db.accounts).getSingle();
    final Transaction tx = await db.select(db.transactions).getSingle();

    expect(profile.displayName, 'Restart Test User');
    expect(account.openingBalanceMinorUnits, 50000);
    expect(tx.amountMinorUnits, 1200);
    expect(tx.currencyCode, 'JPY');

    await db.close();
  });

  test('a soft-deleted transaction is excluded from an "active transactions" query', () async {
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase(dbFile));

    await db.into(db.profiles).insert(
          ProfilesCompanion.insert(
            id: 'profile-1',
            displayName: 'User',
            homeCountry: 'LK',
            currentCountry: 'JP',
            homeCurrency: 'LKR',
            livingCurrency: 'JPY',
            preferredLanguage: 'en',
            timezone: 'Asia/Tokyo',
            dateFormat: 'yyyy-MM-dd',
            numberFormat: '#,##0.##',
            createdAt: DateTime.utc(2026, 1, 1),
            updatedAt: DateTime.utc(2026, 1, 1),
          ),
        );
    await db.into(db.accounts).insert(
          AccountsCompanion.insert(
            id: 'account-1',
            profileId: 'profile-1',
            name: 'Wallet',
            type: 'cash',
            currencyCode: 'JPY',
            createdAt: DateTime.utc(2026, 1, 1),
            updatedAt: DateTime.utc(2026, 1, 1),
          ),
        );
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            id: 'tx-active',
            profileId: 'profile-1',
            accountId: 'account-1',
            type: 'expense',
            amountMinorUnits: 100,
            currencyCode: 'JPY',
            occurredAt: DateTime.utc(2026, 1, 2),
            createdAt: DateTime.utc(2026, 1, 2),
            updatedAt: DateTime.utc(2026, 1, 2),
          ),
        );
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            id: 'tx-deleted',
            profileId: 'profile-1',
            accountId: 'account-1',
            type: 'expense',
            amountMinorUnits: 999999,
            currencyCode: 'JPY',
            occurredAt: DateTime.utc(2026, 1, 2),
            createdAt: DateTime.utc(2026, 1, 2),
            updatedAt: DateTime.utc(2026, 1, 2),
            deletedAt: Value<DateTime?>(DateTime.utc(2026, 1, 3)),
          ),
        );

    final List<Transaction> active = await (db.select(db.transactions)
          ..where((tbl) => tbl.deletedAt.isNull()))
        .get();

    expect(active.length, 1);
    expect(active.single.id, 'tx-active');

    await db.close();
  });
}
