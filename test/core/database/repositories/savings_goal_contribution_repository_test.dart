import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/savings_goal_contribution_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/savings_goal_repository.dart';
import 'package:ai_financial_coach/core/money/currency_mismatch_exception.dart';
import 'package:ai_financial_coach/core/money/money.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// NOTE: exercises generated Drift code — see CLAUDE_FIRST_CODING_PROMPT.md.

void main() {
  late AppDatabase db;
  late ProfileRepository profileRepo;
  late SavingsGoalRepository goalRepo;
  late SavingsGoalContributionRepository contributionRepo;
  late String profileId;
  late String jpyGoalId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    profileRepo = ProfileRepository(db);
    goalRepo = SavingsGoalRepository(db);
    contributionRepo = SavingsGoalContributionRepository(db, goalRepo);

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
    jpyGoalId = await goalRepo.createGoal(
      profileId: profileId,
      name: 'Emergency Fund',
      targetAmount: Money.fromMinorUnits(500000, 'JPY'),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('addContribution validation', () {
    test('rejects a zero amount', () {
      expect(
        () => contributionRepo.addContribution(goalId: jpyGoalId, amount: Money.zero('JPY')),
        throwsA(isA<InvalidSavingsGoalContributionAmountException>()),
      );
    });

    test('rejects a negative amount', () {
      expect(
        () => contributionRepo.addContribution(
          goalId: jpyGoalId,
          amount: Money.fromMinorUnits(-500, 'JPY'),
        ),
        throwsA(isA<InvalidSavingsGoalContributionAmountException>()),
      );
    });

    test('rejects a currency that does not match the goal\'s currency', () {
      expect(
        () => contributionRepo.addContribution(
          goalId: jpyGoalId,
          amount: Money.fromMinorUnits(1000, 'USD'),
        ),
        throwsA(isA<CurrencyMismatchException>()),
      );
    });

    test('rejects a contribution against a goal id that does not exist', () {
      expect(
        () => contributionRepo.addContribution(
          goalId: 'does-not-exist',
          amount: Money.fromMinorUnits(1000, 'JPY'),
        ),
        throwsA(isA<SavingsGoalNotFoundException>()),
      );
    });

    test('rejects a contribution against a soft-deleted goal, even in the goal\'s own currency', () async {
      await goalRepo.softDeleteGoal(jpyGoalId);
      expect(
        () => contributionRepo.addContribution(
          goalId: jpyGoalId,
          amount: Money.fromMinorUnits(1000, 'JPY'),
        ),
        throwsA(isA<SavingsGoalNotFoundException>()),
      );
    });
  });

  group('addContribution / read back', () {
    test('a recorded contribution is readable and creates no Transactions row', () async {
      await contributionRepo.addContribution(goalId: jpyGoalId, amount: Money.fromMinorUnits(5000, 'JPY'));

      final List<SavingsGoalContributionRow> rows =
          await contributionRepo.watchActiveForGoal(jpyGoalId).first;
      expect(rows, hasLength(1));
      expect(rows.single.amountMinorUnits, 5000);
      expect(rows.single.currencyCode, 'JPY');
      expect(rows.single.deletedAt, isNull);

      // ADR-022: a contribution has no income/expense/transfer side
      // effect -- it must never create a Transactions row.
      final List<Transaction> transactions = await db.select(db.transactions).get();
      expect(transactions, isEmpty);
    });

    test('defaults contributedAt to now (UTC) when omitted', () async {
      final DateTime before = DateTime.now().toUtc();
      await contributionRepo.addContribution(goalId: jpyGoalId, amount: Money.fromMinorUnits(5000, 'JPY'));
      final DateTime after = DateTime.now().toUtc();

      final SavingsGoalContributionRow row =
          (await contributionRepo.watchActiveForGoal(jpyGoalId).first).single;
      expect(
        row.contributedAt.isAfter(before.subtract(const Duration(seconds: 1))) &&
            row.contributedAt.isBefore(after.add(const Duration(seconds: 1))),
        isTrue,
      );
    });

    test('normalizes a supplied contributedAt to a UTC instant', () async {
      final DateTime local = DateTime(2026, 6, 15, 10, 30);
      await contributionRepo.addContribution(
        goalId: jpyGoalId,
        amount: Money.fromMinorUnits(5000, 'JPY'),
        contributedAt: local,
      );
      final SavingsGoalContributionRow row =
          (await contributionRepo.watchActiveForGoal(jpyGoalId).first).single;
      expect(row.contributedAt, local.toUtc());
    });

    test('preserves full minor-unit precision for a 3-decimal currency (KWD)', () async {
      final String kwdGoalId = await goalRepo.createGoal(
        profileId: profileId,
        name: 'Kuwait Trip',
        targetAmount: Money.fromMinorUnits(1000000, 'KWD'),
      );
      // 1.234 KWD == 1234 minor units (KWD has 3 minor-unit digits).
      await contributionRepo.addContribution(
        goalId: kwdGoalId,
        amount: Money.fromMinorUnits(1234, 'KWD'),
      );
      final SavingsGoalContributionRow row =
          (await contributionRepo.watchActiveForGoal(kwdGoalId).first).single;
      expect(row.amountMinorUnits, 1234);
      expect(row.currencyCode, 'KWD');
    });
  });

  group('watchActiveForGoal / watchActiveTotalForGoal', () {
    test('orders active contributions newest first', () async {
      final String earlyId = await contributionRepo.addContribution(
        goalId: jpyGoalId,
        amount: Money.fromMinorUnits(1000, 'JPY'),
        contributedAt: DateTime.utc(2026, 1, 1),
      );
      final String lateId = await contributionRepo.addContribution(
        goalId: jpyGoalId,
        amount: Money.fromMinorUnits(2000, 'JPY'),
        contributedAt: DateTime.utc(2026, 6, 1),
      );

      final List<SavingsGoalContributionRow> rows =
          await contributionRepo.watchActiveForGoal(jpyGoalId).first;
      expect(rows.map((row) => row.id).toList(), <String>[lateId, earlyId]);
    });

    test('excludes a soft-deleted contribution from both the list and the total', () async {
      await contributionRepo.addContribution(goalId: jpyGoalId, amount: Money.fromMinorUnits(1000, 'JPY'));
      final String deletedId = await contributionRepo.addContribution(
        goalId: jpyGoalId,
        amount: Money.fromMinorUnits(4000, 'JPY'),
      );
      await contributionRepo.softDeleteContribution(deletedId);

      final List<SavingsGoalContributionRow> rows =
          await contributionRepo.watchActiveForGoal(jpyGoalId).first;
      expect(rows, hasLength(1));
      expect(rows.single.amountMinorUnits, 1000);

      final Money total =
          await contributionRepo.watchActiveTotalForGoal(goalId: jpyGoalId, currencyCode: 'JPY').first;
      expect(total, Money.fromMinorUnits(1000, 'JPY'));
    });

    test('watchActiveTotalForGoal sums every active contribution', () async {
      await contributionRepo.addContribution(goalId: jpyGoalId, amount: Money.fromMinorUnits(1000, 'JPY'));
      await contributionRepo.addContribution(goalId: jpyGoalId, amount: Money.fromMinorUnits(2500, 'JPY'));
      final Money total =
          await contributionRepo.watchActiveTotalForGoal(goalId: jpyGoalId, currencyCode: 'JPY').first;
      expect(total, Money.fromMinorUnits(3500, 'JPY'));
    });

    test('watchActiveTotalForGoal is Money.zero, not null, for a goal with no contributions', () async {
      final Money total =
          await contributionRepo.watchActiveTotalForGoal(goalId: jpyGoalId, currencyCode: 'JPY').first;
      expect(total, Money.zero('JPY'));
    });
  });
}
