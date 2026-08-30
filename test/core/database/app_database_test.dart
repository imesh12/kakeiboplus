import 'package:ai_financial_coach/core/currency/currency_registry.dart';
import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// NOTE: this file exercises generated Drift code (AppDatabase,
// CurrenciesCompanion, etc. from app_database.g.dart) that could not be
// generated inside the sandbox that wrote it — run
// `dart run build_runner build --delete-conflicting-outputs` locally
// before running this test. See CLAUDE_FIRST_CODING_PROMPT.md.

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('AppDatabase schema v1', () {
    test('onCreate seeds every currency in CurrencyRegistry.seed', () async {
      final List<CurrencyRow> rows = await db.select(db.currencies).get();
      expect(rows.length, CurrencyRegistry.seed.length);
      for (final currency in CurrencyRegistry.seed) {
        final CurrencyRow row = rows.singleWhere((r) => r.code == currency.code);
        expect(row.minorUnits, currency.minorUnits, reason: currency.code);
        expect(row.symbol, currency.symbol, reason: currency.code);
      }
    });

    test('release-gate precision spot check: JPY/KRW/VND=0, KWD=3', () async {
      Future<int> minorUnitsOf(String code) async {
        final CurrencyRow row = await (db.select(db.currencies)
              ..where((tbl) => tbl.code.equals(code)))
            .getSingle();
        return row.minorUnits;
      }

      expect(await minorUnitsOf('JPY'), 0);
      expect(await minorUnitsOf('KRW'), 0);
      expect(await minorUnitsOf('VND'), 0);
      expect(await minorUnitsOf('KWD'), 3);
    });

    test('a profile can be created and read back', () async {
      await db.into(db.profiles).insert(
            ProfilesCompanion.insert(
              id: 'profile-1',
              displayName: 'Test User',
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
      final ProfileRow profile = await db.select(db.profiles).getSingle();
      expect(profile.displayName, 'Test User');
      expect(profile.homeCurrency, 'LKR');
      expect(profile.livingCurrency, 'JPY');
    });

    test('an account and a transaction referencing it can be created', () async {
      await db.into(db.profiles).insert(
            ProfilesCompanion.insert(
              id: 'profile-1',
              displayName: 'Test User',
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

      final Transaction tx = await db.select(db.transactions).getSingle();
      expect(tx.amountMinorUnits, 1200);
      expect(tx.currencyCode, 'JPY');
      // Forward-compatible columns default correctly (ADR-020).
      expect(tx.syncVersion, 0);
      expect(tx.syncStatus, 'localOnly');
      expect(tx.deletedAt, isNull);
    });
  });
}
