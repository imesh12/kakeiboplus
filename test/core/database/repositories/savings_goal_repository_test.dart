import 'dart:io';

import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/savings_goal_repository.dart';
import 'package:ai_financial_coach/core/money/currency_mismatch_exception.dart';
import 'package:ai_financial_coach/core/money/money.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// NOTE: exercises generated Drift code — see CLAUDE_FIRST_CODING_PROMPT.md.

void main() {
  group('In-memory repository behavior', () {
    late AppDatabase db;
    late ProfileRepository profileRepo;
    late SavingsGoalRepository goalRepo;
    late String profileId;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      profileRepo = ProfileRepository(db);
      goalRepo = SavingsGoalRepository(db);

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

    group('createGoal validation', () {
      test('rejects a zero target amount', () {
        expect(
          () => goalRepo.createGoal(
            profileId: profileId,
            name: 'Emergency Fund',
            targetAmount: Money.zero('JPY'),
          ),
          throwsA(isA<InvalidSavingsGoalTargetAmountException>()),
        );
      });

      test('rejects a negative target amount', () {
        expect(
          () => goalRepo.createGoal(
            profileId: profileId,
            name: 'Emergency Fund',
            targetAmount: Money.fromMinorUnits(-100, 'JPY'),
          ),
          throwsA(isA<InvalidSavingsGoalTargetAmountException>()),
        );
      });

      test('rejects an unsupported currency code', () {
        expect(
          () => goalRepo.createGoal(
            profileId: profileId,
            name: 'Emergency Fund',
            targetAmount: Money.fromMinorUnits(1000, 'ZZZ'),
          ),
          throwsArgumentError,
        );
      });

      test('rejects an empty name', () {
        expect(
          () => goalRepo.createGoal(
            profileId: profileId,
            name: '',
            targetAmount: Money.fromMinorUnits(100000, 'JPY'),
          ),
          throwsA(isA<InvalidSavingsGoalNameException>()),
        );
      });

      test('rejects a whitespace-only name', () {
        expect(
          () => goalRepo.createGoal(
            profileId: profileId,
            name: '   ',
            targetAmount: Money.fromMinorUnits(100000, 'JPY'),
          ),
          throwsA(isA<InvalidSavingsGoalNameException>()),
        );
      });

      test('stores a trimmed name, not the raw whitespace-padded input', () async {
        final String id = await goalRepo.createGoal(
          profileId: profileId,
          name: '  Emergency Fund  ',
          targetAmount: Money.fromMinorUnits(100000, 'JPY'),
        );
        final SavingsGoalRow row = await goalRepo.requireActiveGoal(id);
        expect(row.name, 'Emergency Fund');
      });
    });

    group('createGoal / read back', () {
      test('a created goal with no target date is readable with a null targetDate', () async {
        final String id = await goalRepo.createGoal(
          profileId: profileId,
          name: 'Rainy Day',
          targetAmount: Money.fromMinorUnits(50000, 'JPY'),
        );
        final SavingsGoalRow row = await goalRepo.requireActiveGoal(id);
        expect(row.targetDate, isNull);
        expect(row.targetAmountMinorUnits, 50000);
        expect(row.currencyCode, 'JPY');
        expect(row.deletedAt, isNull);
      });

      test('a created goal with a target date has it normalized to a UTC calendar date', () async {
        // A non-UTC DateTime with a non-midnight time component -- the
        // stored value must be exactly the calendar date selected, per
        // `normalizeCalendarDateToUtc` (`docs/14_DECISION_LOG.md`
        // ADR-022), never shifted by a `.toUtc()` conversion.
        final DateTime pickedLocalDate = DateTime(2026, 12, 25, 23, 45);
        final String id = await goalRepo.createGoal(
          profileId: profileId,
          name: 'Holiday Fund',
          targetAmount: Money.fromMinorUnits(80000, 'JPY'),
          targetDate: pickedLocalDate,
        );
        final SavingsGoalRow row = await goalRepo.requireActiveGoal(id);
        expect(row.targetDate, DateTime.utc(2026, 12, 25));
      });
    });

    group('updateGoal', () {
      test('throws SavingsGoalNotFoundException for an id that does not exist', () {
        expect(
          () => goalRepo.updateGoal(id: 'does-not-exist', name: 'New Name'),
          throwsA(isA<SavingsGoalNotFoundException>()),
        );
      });

      test('updates the name, trimmed', () async {
        final String id = await goalRepo.createGoal(
          profileId: profileId,
          name: 'Old Name',
          targetAmount: Money.fromMinorUnits(100000, 'JPY'),
        );
        await goalRepo.updateGoal(id: id, name: '  New Name  ');
        final SavingsGoalRow row = await goalRepo.requireActiveGoal(id);
        expect(row.name, 'New Name');
      });

      test('rejects an empty name and leaves the stored name unchanged', () async {
        final String id = await goalRepo.createGoal(
          profileId: profileId,
          name: 'Original Name',
          targetAmount: Money.fromMinorUnits(100000, 'JPY'),
        );
        await expectLater(
          goalRepo.updateGoal(id: id, name: '   '),
          throwsA(isA<InvalidSavingsGoalNameException>()),
        );
        final SavingsGoalRow row = await goalRepo.requireActiveGoal(id);
        expect(row.name, 'Original Name');
      });

      test('updates the target amount within the same currency', () async {
        final String id = await goalRepo.createGoal(
          profileId: profileId,
          name: 'Emergency Fund',
          targetAmount: Money.fromMinorUnits(100000, 'JPY'),
        );
        await goalRepo.updateGoal(id: id, targetAmount: Money.fromMinorUnits(200000, 'JPY'));
        final SavingsGoalRow row = await goalRepo.requireActiveGoal(id);
        expect(row.targetAmountMinorUnits, 200000);
        expect(row.currencyCode, 'JPY');
      });

      test(
        'rejects a target amount in a different currency and leaves the original goal unchanged '
        '(currency is permanently anchored -- ADR-022)',
        () async {
          final String id = await goalRepo.createGoal(
            profileId: profileId,
            name: 'Emergency Fund',
            targetAmount: Money.fromMinorUnits(100000, 'JPY'),
          );
          await expectLater(
            goalRepo.updateGoal(id: id, targetAmount: Money.fromMinorUnits(1000, 'USD')),
            throwsA(isA<CurrencyMismatchException>()),
          );
          final SavingsGoalRow row = await goalRepo.requireActiveGoal(id);
          expect(row.currencyCode, 'JPY');
          expect(row.targetAmountMinorUnits, 100000);
        },
      );

      test('omitting targetDate leaves the existing target date unchanged', () async {
        final String id = await goalRepo.createGoal(
          profileId: profileId,
          name: 'Emergency Fund',
          targetAmount: Money.fromMinorUnits(100000, 'JPY'),
          targetDate: DateTime.utc(2026, 12, 25),
        );
        await goalRepo.updateGoal(id: id, name: 'Renamed');
        final SavingsGoalRow row = await goalRepo.requireActiveGoal(id);
        expect(row.targetDate, DateTime.utc(2026, 12, 25));
      });

      test('Value(someDate) replaces the target date', () async {
        final String id = await goalRepo.createGoal(
          profileId: profileId,
          name: 'Emergency Fund',
          targetAmount: Money.fromMinorUnits(100000, 'JPY'),
          targetDate: DateTime.utc(2026, 12, 25),
        );
        await goalRepo.updateGoal(id: id, targetDate: Value<DateTime?>(DateTime.utc(2027, 1, 1)));
        final SavingsGoalRow row = await goalRepo.requireActiveGoal(id);
        expect(row.targetDate, DateTime.utc(2027, 1, 1));
      });

      test('Value(null) explicitly clears the target date', () async {
        final String id = await goalRepo.createGoal(
          profileId: profileId,
          name: 'Emergency Fund',
          targetAmount: Money.fromMinorUnits(100000, 'JPY'),
          targetDate: DateTime.utc(2026, 12, 25),
        );
        await goalRepo.updateGoal(id: id, targetDate: const Value<DateTime?>(null));
        final SavingsGoalRow row = await goalRepo.requireActiveGoal(id);
        expect(row.targetDate, isNull);
      });
    });

    group('softDeleteGoal', () {
      test('an active goal excludes a soft-deleted goal from watchActiveGoals', () async {
        final String keptId = await goalRepo.createGoal(
          profileId: profileId,
          name: 'Kept',
          targetAmount: Money.fromMinorUnits(100000, 'JPY'),
        );
        final String deletedId = await goalRepo.createGoal(
          profileId: profileId,
          name: 'Deleted',
          targetAmount: Money.fromMinorUnits(100000, 'JPY'),
        );
        await goalRepo.softDeleteGoal(deletedId);

        final List<SavingsGoalRow> active = await goalRepo.watchActiveGoals(profileId).first;
        expect(active.map((row) => row.id), <String>[keptId]);
      });

      test('watchById returns null for a soft-deleted goal', () async {
        final String id = await goalRepo.createGoal(
          profileId: profileId,
          name: 'Temporary',
          targetAmount: Money.fromMinorUnits(100000, 'JPY'),
        );
        await goalRepo.softDeleteGoal(id);
        final SavingsGoalRow? row = await goalRepo.watchById(id).first;
        expect(row, isNull);
      });

      test('requireActiveGoal throws SavingsGoalNotFoundException for a soft-deleted goal', () async {
        final String id = await goalRepo.createGoal(
          profileId: profileId,
          name: 'Temporary',
          targetAmount: Money.fromMinorUnits(100000, 'JPY'),
        );
        await goalRepo.softDeleteGoal(id);
        expect(() => goalRepo.requireActiveGoal(id), throwsA(isA<SavingsGoalNotFoundException>()));
      });

      test('updateGoal on a soft-deleted goal throws SavingsGoalNotFoundException', () async {
        final String id = await goalRepo.createGoal(
          profileId: profileId,
          name: 'Temporary',
          targetAmount: Money.fromMinorUnits(100000, 'JPY'),
        );
        await goalRepo.softDeleteGoal(id);
        expect(
          () => goalRepo.updateGoal(id: id, name: 'Renamed'),
          throwsA(isA<SavingsGoalNotFoundException>()),
        );
      });
    });

    group('watchActiveGoals ordering', () {
      test('returns only the given profile\'s active goals, oldest first', () async {
        // `ProfileRepository.createProfile` enforces a single local
        // profile (throws `StateError` on a second call -- Beta 0/1 has
        // no multi-profile support). This test only needs a second
        // *profile row* to prove `watchActiveGoals` filters by
        // `profileId`, so it inserts one directly, bypassing the
        // repository's single-profile invariant as test-only fixture
        // infrastructure rather than weakening that invariant in
        // production code.
        const String otherProfileId = 'other-profile-fixture';
        final DateTime otherProfileNow = DateTime.now().toUtc();
        await db.into(db.profiles).insert(
              ProfilesCompanion.insert(
                id: otherProfileId,
                displayName: 'Other User',
                homeCountry: 'LK',
                currentCountry: 'JP',
                homeCurrency: 'LKR',
                livingCurrency: 'JPY',
                preferredLanguage: 'en',
                timezone: 'Asia/Tokyo',
                dateFormat: 'yyyy-MM-dd',
                numberFormat: '#,##0.##',
                createdAt: otherProfileNow,
                updatedAt: otherProfileNow,
              ),
            );
        final String firstId = await goalRepo.createGoal(
          profileId: profileId,
          name: 'First',
          targetAmount: Money.fromMinorUnits(100000, 'JPY'),
        );
        final String secondId = await goalRepo.createGoal(
          profileId: profileId,
          name: 'Second',
          targetAmount: Money.fromMinorUnits(100000, 'JPY'),
        );
        await goalRepo.createGoal(
          profileId: otherProfileId,
          name: 'Someone Else\'s Goal',
          targetAmount: Money.fromMinorUnits(100000, 'JPY'),
        );

        final List<SavingsGoalRow> active = await goalRepo.watchActiveGoals(profileId).first;
        expect(active.map((row) => row.id).toList(), <String>[firstId, secondId]);
      });
    });
  });

  group('Persistence survives a database reload', () {
    test(
      'a created goal is still readable through a newly-opened AppDatabase/SavingsGoalRepository '
      'against the same on-disk file',
      () async {
        final Directory tempDir = Directory.systemTemp.createTempSync('afc_goal_persistence_test_');
        final File dbFile = File('${tempDir.path}/test.sqlite');
        addTearDown(() {
          if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
        });

        AppDatabase fileDb = AppDatabase.forTesting(NativeDatabase(dbFile));
        final ProfileRepository fileProfileRepo = ProfileRepository(fileDb);
        SavingsGoalRepository fileGoalRepo = SavingsGoalRepository(fileDb);
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
        final String goalId = await fileGoalRepo.createGoal(
          profileId: fileProfileId,
          name: 'Emergency Fund',
          targetAmount: Money.fromMinorUnits(120000, 'JPY'),
        );

        await fileDb.close();
        fileDb = AppDatabase.forTesting(NativeDatabase(dbFile));
        fileGoalRepo = SavingsGoalRepository(fileDb);

        final SavingsGoalRow row = await fileGoalRepo.requireActiveGoal(goalId);
        expect(row.name, 'Emergency Fund');
        expect(row.targetAmountMinorUnits, 120000);

        await fileDb.close();
      },
    );
  });
}
