import 'dart:io';

import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/repositories/budget_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/money/money.dart';
import 'package:ai_financial_coach/features/budgets/domain/budget_month.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// NOTE: exercises generated Drift code — see CLAUDE_FIRST_CODING_PROMPT.md.

void main() {
  final BudgetMonth sept2026 = BudgetMonth(year: 2026, month: 9);

  // Scoped to its own group -- rather than declared directly under
  // `main()` -- so its setUp/tearDown, and the single shared in-memory
  // `db` they open per test, can never overlap with "Persistence
  // survives a database reload" below. That group deliberately manages
  // its own on-disk AppDatabase instances one at a time (open, close,
  // reopen); if the in-memory `db` here stayed alive at `main()` level
  // for the whole file, it would still be open while the reload
  // test's AppDatabase instances are open too -- two live AppDatabase
  // instances at once, which is exactly what trips Drift's "multiple
  // databases" warning, even though they target entirely different
  // backing stores.
  group('In-memory repository behavior', () {
    late AppDatabase db;
    late ProfileRepository profileRepo;
    late BudgetRepository budgetRepo;
    late String profileId;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      profileRepo = ProfileRepository(db);
      budgetRepo = BudgetRepository(db);

      profileId = await profileRepo.createProfile(
        displayName: 'Test User',
        homeCountry: 'LK',
        currentCountry: 'JP',
        homeCurrency: 'LKR',
        livingCurrency: 'JPY',
        preferredLanguage: 'en',
        timezone: 'Asia/Tokyo',
        dateFormat: 'yyyy-MM-dd',
        numberFormat: '#,##0.##',
      );
    });

    tearDown(() async {
      await db.close();
    });

    group('Validation', () {
      test('rejects a zero budget amount', () async {
        expect(
          () => budgetRepo.setOverallBudget(
            profileId: profileId,
            month: sept2026,
            amount: Money.zero('JPY'),
          ),
          throwsA(isA<InvalidBudgetAmountException>()),
        );
      });

      test('rejects a negative budget amount', () async {
        expect(
          () => budgetRepo.setOverallBudget(
            profileId: profileId,
            month: sept2026,
            amount: Money.fromMinorUnits(-100, 'JPY'),
          ),
          throwsA(isA<InvalidBudgetAmountException>()),
        );
      });

      test('rejects an unsupported currency code', () async {
        expect(
          () => budgetRepo.setOverallBudget(
            profileId: profileId,
            month: sept2026,
            amount: Money.fromMinorUnits(1000, 'ZZZ'),
          ),
          throwsArgumentError,
        );
      });

      test('rejects an invalid month before a BudgetMonth can even be constructed', () {
        // Same check as test/features/budgets/domain/budget_month_test.dart
        // -- repeated here because BudgetMonth is the repository's only
        // month API, so an invalid month can never reach BudgetRepository
        // at all.
        expect(() => BudgetMonth(year: 2026, month: 13), throwsArgumentError);
      });

      test('a zero-amount budget is never considered "configured" -- setOverallBudget throws '
          'before any row is written', () async {
        await expectLater(
          budgetRepo.setOverallBudget(
            profileId: profileId,
            month: sept2026,
            amount: Money.zero('JPY'),
          ),
          throwsA(isA<InvalidBudgetAmountException>()),
        );
        final BudgetRow? row = await budgetRepo
            .watchActiveOverallBudget(profileId: profileId, currencyCode: 'JPY', month: sept2026)
            .first;
        expect(row, isNull);
      });
    });

    group('Create / update / delete', () {
      test('creating an overall budget makes it readable back', () async {
        await budgetRepo.setOverallBudget(
          profileId: profileId,
          month: sept2026,
          amount: Money.fromMinorUnits(120000, 'JPY'),
        );
        final BudgetRow? row = await budgetRepo
            .watchActiveOverallBudget(profileId: profileId, currencyCode: 'JPY', month: sept2026)
            .first;
        expect(row, isNotNull);
        expect(row!.amountMinorUnits, 120000);
        expect(row.categoryId, isNull);
      });

      test('setting an overall budget again for the same key updates the existing row in place '
          'rather than creating a duplicate', () async {
        final String firstId = await budgetRepo.setOverallBudget(
          profileId: profileId,
          month: sept2026,
          amount: Money.fromMinorUnits(100000, 'JPY'),
        );
        final String secondId = await budgetRepo.setOverallBudget(
          profileId: profileId,
          month: sept2026,
          amount: Money.fromMinorUnits(150000, 'JPY'),
        );
        expect(secondId, firstId);

        final List<BudgetRow> all =
            await budgetRepo.watchActiveForMonth(profileId: profileId, month: sept2026).first;
        expect(all.length, 1);
        expect(all.single.amountMinorUnits, 150000);
      });

      test('setting a category budget again for the same key updates in place, and does not '
          'affect the overall budget for the same currency/month', () async {
        await budgetRepo.setOverallBudget(
          profileId: profileId,
          month: sept2026,
          amount: Money.fromMinorUnits(120000, 'JPY'),
        );
        final String firstId = await budgetRepo.setCategoryBudget(
          profileId: profileId,
          categoryId: 'sys-dining',
          month: sept2026,
          amount: Money.fromMinorUnits(20000, 'JPY'),
        );
        final String secondId = await budgetRepo.setCategoryBudget(
          profileId: profileId,
          categoryId: 'sys-dining',
          month: sept2026,
          amount: Money.fromMinorUnits(25000, 'JPY'),
        );
        expect(secondId, firstId);

        final List<BudgetRow> all =
            await budgetRepo.watchActiveForMonth(profileId: profileId, month: sept2026).first;
        expect(all.length, 2); // overall + one category budget, not duplicated
        final BudgetRow? overall = await budgetRepo
            .watchActiveOverallBudget(profileId: profileId, currencyCode: 'JPY', month: sept2026)
            .first;
        expect(overall!.amountMinorUnits, 120000); // untouched by the category update
      });

      test('soft-deleting a budget removes it from active reads', () async {
        final String id = await budgetRepo.setOverallBudget(
          profileId: profileId,
          month: sept2026,
          amount: Money.fromMinorUnits(120000, 'JPY'),
        );
        await budgetRepo.softDelete(id);

        final BudgetRow? row = await budgetRepo
            .watchActiveOverallBudget(profileId: profileId, currencyCode: 'JPY', month: sept2026)
            .first;
        expect(row, isNull);
      });

      test('recreating a budget after it was soft-deleted succeeds and is readable again', () async {
        final String firstId = await budgetRepo.setOverallBudget(
          profileId: profileId,
          month: sept2026,
          amount: Money.fromMinorUnits(120000, 'JPY'),
        );
        await budgetRepo.softDelete(firstId);

        final String secondId = await budgetRepo.setOverallBudget(
          profileId: profileId,
          month: sept2026,
          amount: Money.fromMinorUnits(90000, 'JPY'),
        );
        expect(secondId, isNot(firstId)); // a genuinely new row, not a resurrection of the old one

        final BudgetRow? row = await budgetRepo
            .watchActiveOverallBudget(profileId: profileId, currencyCode: 'JPY', month: sept2026)
            .first;
        expect(row, isNotNull);
        expect(row!.amountMinorUnits, 90000);

        final List<BudgetRow> all =
            await budgetRepo.watchActiveForMonth(profileId: profileId, month: sept2026).first;
        expect(all.length, 1); // the soft-deleted row is excluded, not conflicting
      });
    });

    group('Independence across currency and category', () {
      test('an overall budget in one currency never contaminates another currency\'s budget for '
          'the same month', () async {
        await budgetRepo.setOverallBudget(
          profileId: profileId,
          month: sept2026,
          amount: Money.fromMinorUnits(120000, 'JPY'),
        );
        await budgetRepo.setOverallBudget(
          profileId: profileId,
          month: sept2026,
          amount: Money.fromMinorUnits(50000, 'USD'), // $500.00
        );

        final BudgetRow? jpy = await budgetRepo
            .watchActiveOverallBudget(profileId: profileId, currencyCode: 'JPY', month: sept2026)
            .first;
        final BudgetRow? usd = await budgetRepo
            .watchActiveOverallBudget(profileId: profileId, currencyCode: 'USD', month: sept2026)
            .first;
        expect(jpy!.amountMinorUnits, 120000);
        expect(usd!.amountMinorUnits, 50000);
      });

      test('a category budget only matches its own exact category, currency, and month', () async {
        await budgetRepo.setCategoryBudget(
          profileId: profileId,
          categoryId: 'sys-dining',
          month: sept2026,
          amount: Money.fromMinorUnits(20000, 'JPY'),
        );

        final BudgetRow? diningBudget = await budgetRepo
            .watchActiveCategoryBudget(
              profileId: profileId,
              categoryId: 'sys-dining',
              currencyCode: 'JPY',
              month: sept2026,
            )
            .first;
        final BudgetRow? groceriesBudget = await budgetRepo
            .watchActiveCategoryBudget(
              profileId: profileId,
              categoryId: 'sys-groceries',
              currencyCode: 'JPY',
              month: sept2026,
            )
            .first;
        final BudgetRow? nextMonthBudget = await budgetRepo
            .watchActiveCategoryBudget(
              profileId: profileId,
              categoryId: 'sys-dining',
              currencyCode: 'JPY',
              month: sept2026.next,
            )
            .first;

        expect(diningBudget, isNotNull);
        expect(groceriesBudget, isNull);
        expect(nextMonthBudget, isNull);
      });
    });
  });

  group('Persistence survives a database reload', () {
    test('a created budget is still readable through a newly-opened AppDatabase/BudgetRepository '
        'against the same on-disk file', () async {
      final Directory tempDir = Directory.systemTemp.createTempSync('afc_budget_persistence_test_');
      final File dbFile = File('${tempDir.path}/test.sqlite');
      addTearDown(() {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });

      // --- "First app launch": write through one AppDatabase instance ---
      AppDatabase fileDb = AppDatabase.forTesting(NativeDatabase(dbFile));
      final ProfileRepository fileProfileRepo = ProfileRepository(fileDb);
      BudgetRepository fileBudgetRepo = BudgetRepository(fileDb);
      final String fileProfileId = await fileProfileRepo.createProfile(
        displayName: 'Restart Test User',
        homeCountry: 'LK',
        currentCountry: 'JP',
        homeCurrency: 'LKR',
        livingCurrency: 'JPY',
        preferredLanguage: 'en',
        timezone: 'Asia/Tokyo',
        dateFormat: 'yyyy-MM-dd',
        numberFormat: '#,##0.##',
      );
      await fileBudgetRepo.setOverallBudget(
        profileId: fileProfileId,
        month: sept2026,
        amount: Money.fromMinorUnits(120000, 'JPY'),
      );

      // --- "App restart": fully close, then open a fresh AppDatabase and
      // a fresh BudgetRepository against the same file ---
      await fileDb.close();
      fileDb = AppDatabase.forTesting(NativeDatabase(dbFile));
      fileBudgetRepo = BudgetRepository(fileDb);

      final BudgetRow? row = await fileBudgetRepo
          .watchActiveOverallBudget(profileId: fileProfileId, currencyCode: 'JPY', month: sept2026)
          .first;
      expect(row, isNotNull);
      expect(row!.amountMinorUnits, 120000);

      await fileDb.close();
    });
  });
}
