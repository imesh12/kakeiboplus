import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/repositories/account_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/recurring_rule_repository.dart';
import 'package:ai_financial_coach/core/money/currency_mismatch_exception.dart';
import 'package:ai_financial_coach/core/money/money.dart';
import 'package:ai_financial_coach/features/recurring/domain/recurrence_frequency.dart';
import 'package:ai_financial_coach/features/recurring/domain/recurring_rule_kind.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// NOTE: exercises generated Drift code -- see CLAUDE_FIRST_CODING_PROMPT.md.

void main() {
  late AppDatabase db;
  late ProfileRepository profileRepo;
  late AccountRepository accountRepo;
  late RecurringRuleRepository ruleRepo;
  late String profileId;
  late String jpyAccountId;
  late String jpyAccountId2;
  late String usdAccountId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    profileRepo = ProfileRepository(db);
    accountRepo = AccountRepository(db);
    ruleRepo = RecurringRuleRepository(db, accountRepo);

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
    jpyAccountId = await accountRepo.createAccount(
      profileId: profileId,
      name: 'Wallet',
      type: 'cash',
      currencyCode: 'JPY',
    );
    jpyAccountId2 = await accountRepo.createAccount(
      profileId: profileId,
      name: 'Savings',
      type: 'bank',
      currencyCode: 'JPY',
    );
    usdAccountId = await accountRepo.createAccount(
      profileId: profileId,
      name: 'US Account',
      type: 'bank',
      currencyCode: 'USD',
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<String> createExpenseRule({
    String? accountId,
    Money? amount,
    RecurrenceFrequency frequency = RecurrenceFrequency.monthly,
    int interval = 1,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return ruleRepo.createRule(
      profileId: profileId,
      kind: RecurringRuleKind.expense,
      name: 'Rent',
      amount: amount ?? Money.fromMinorUnits(80000, 'JPY'),
      accountId: accountId ?? jpyAccountId,
      frequency: frequency,
      interval: interval,
      startDate: startDate ?? DateTime.utc(2026, 1, 1),
      endDate: endDate,
    );
  }

  group('createRule validation', () {
    test('rejects a zero amount', () {
      expect(
        () => createExpenseRule(amount: Money.zero('JPY')),
        throwsA(isA<InvalidRecurringRuleAmountException>()),
      );
    });

    test('rejects a negative amount', () {
      expect(
        () => createExpenseRule(amount: Money.fromMinorUnits(-100, 'JPY')),
        throwsA(isA<InvalidRecurringRuleAmountException>()),
      );
    });

    test('rejects an unsupported currency code', () {
      expect(
        () => createExpenseRule(amount: Money.fromMinorUnits(1000, 'ZZZ')),
        throwsArgumentError,
      );
    });

    test('rejects an interval below 1', () {
      expect(() => createExpenseRule(interval: 0), throwsArgumentError);
      expect(() => createExpenseRule(interval: -1), throwsArgumentError);
    });

    test('accepts an interval of 1 or more', () async {
      await createExpenseRule(interval: 1);
      await createExpenseRule(interval: 2);
    });

    test('expense/income: rule currency must match the account currency', () {
      expect(
        () => createExpenseRule(accountId: jpyAccountId, amount: Money.fromMinorUnits(1000, 'USD')),
        throwsA(isA<CurrencyMismatchException>()),
      );
    });

    test('expense/income: an account in the rule currency is accepted', () async {
      final String id = await createExpenseRule(accountId: jpyAccountId, amount: Money.fromMinorUnits(1000, 'JPY'));
      final RecurringRuleRow row = await ruleRepo.requireActiveRule(id);
      expect(row.accountId, jpyAccountId);
      expect(row.destinationAccountId, isNull);
    });
  });

  group('transfer rule validation', () {
    Future<String> createTransferRule({
      String? sourceId,
      String? destinationId,
      Money? amount,
    }) {
      return ruleRepo.createRule(
        profileId: profileId,
        kind: RecurringRuleKind.transfer,
        name: 'Move to savings',
        amount: amount ?? Money.fromMinorUnits(20000, 'JPY'),
        accountId: sourceId ?? jpyAccountId,
        destinationAccountId: destinationId ?? jpyAccountId2,
        frequency: RecurrenceFrequency.monthly,
        interval: 1,
        startDate: DateTime.utc(2026, 1, 1),
      );
    }

    test('requires a destination account', () {
      expect(
        () => ruleRepo.createRule(
          profileId: profileId,
          kind: RecurringRuleKind.transfer,
          name: 'Move to savings',
          amount: Money.fromMinorUnits(20000, 'JPY'),
          accountId: jpyAccountId,
          frequency: RecurrenceFrequency.monthly,
          interval: 1,
          startDate: DateTime.utc(2026, 1, 1),
        ),
        throwsArgumentError,
      );
    });

    test('rejects source == destination', () {
      expect(
        () => createTransferRule(sourceId: jpyAccountId, destinationId: jpyAccountId),
        throwsArgumentError,
      );
    });

    test('rejects a cross-currency transfer (destination currency differs from source)', () {
      expect(
        () => createTransferRule(sourceId: jpyAccountId, destinationId: usdAccountId),
        throwsA(isA<CurrencyMismatchException>()),
      );
    });

    test('rejects a rule currency that does not match both accounts', () {
      expect(
        () => createTransferRule(
          sourceId: jpyAccountId,
          destinationId: jpyAccountId2,
          amount: Money.fromMinorUnits(1000, 'USD'),
        ),
        throwsA(isA<CurrencyMismatchException>()),
      );
    });

    test('accepts a same-currency transfer between two different accounts', () async {
      final String id = await createTransferRule();
      final RecurringRuleRow row = await ruleRepo.requireActiveRule(id);
      expect(row.accountId, jpyAccountId);
      expect(row.destinationAccountId, jpyAccountId2);
      expect(row.kind, 'transfer');
    });

    test('expense/income rules must not set a destination account', () {
      expect(
        () => ruleRepo.createRule(
          profileId: profileId,
          kind: RecurringRuleKind.expense,
          name: 'Rent',
          amount: Money.fromMinorUnits(1000, 'JPY'),
          accountId: jpyAccountId,
          destinationAccountId: jpyAccountId2,
          frequency: RecurrenceFrequency.monthly,
          interval: 1,
          startDate: DateTime.utc(2026, 1, 1),
        ),
        throwsArgumentError,
      );
    });
  });

  group('schedule normalization', () {
    test('startDate/endDate are normalized to a UTC calendar date, not a genuine instant', () async {
      final DateTime pickedStart = DateTime(2026, 1, 15, 23, 45);
      final DateTime pickedEnd = DateTime(2026, 12, 31, 1, 0);
      final String id = await createExpenseRule(startDate: pickedStart, endDate: pickedEnd);
      final RecurringRuleRow row = await ruleRepo.requireActiveRule(id);
      expect(row.startDate, DateTime.utc(2026, 1, 15));
      expect(row.endDate, DateTime.utc(2026, 12, 31));
    });

    test('rejects an endDate before startDate', () {
      expect(
        () => createExpenseRule(
          startDate: DateTime.utc(2026, 6, 1),
          endDate: DateTime.utc(2026, 1, 1),
        ),
        throwsArgumentError,
      );
    });
  });

  group('updateRule', () {
    test('throws RecurringRuleNotFoundException for an id that does not exist', () {
      expect(
        () => ruleRepo.updateRule(id: 'does-not-exist', name: 'New Name'),
        throwsA(isA<RecurringRuleNotFoundException>()),
      );
    });

    test('updates the name and leaves other fields unchanged', () async {
      final String id = await createExpenseRule();
      await ruleRepo.updateRule(id: id, name: 'New Rent Amount');
      final RecurringRuleRow row = await ruleRepo.requireActiveRule(id);
      expect(row.name, 'New Rent Amount');
      expect(row.amountMinorUnits, 80000);
    });

    test('re-validates account/currency when either changes', () async {
      final String id = await createExpenseRule();
      await expectLater(
        ruleRepo.updateRule(id: id, amount: Money.fromMinorUnits(1000, 'USD')),
        throwsA(isA<CurrencyMismatchException>()),
      );
    });

    test('editing schedule fields never touches an existing RecurringOccurrences row', () async {
      // No occurrences exist yet in this test -- this asserts the
      // update itself never writes to recurring_occurrences.
      final String id = await createExpenseRule();
      await ruleRepo.updateRule(id: id, interval: 3);
      final List<RecurringOccurrenceRow> occurrences =
          await db.select(db.recurringOccurrences).get();
      expect(occurrences, isEmpty);
    });
  });

  group('soft delete', () {
    test('a deleted rule is excluded from watchActiveRules', () async {
      final String keptId = await createExpenseRule();
      final String deletedId = await createExpenseRule();
      await ruleRepo.softDelete(deletedId);

      final List<RecurringRuleRow> active = await ruleRepo.watchActiveRules(profileId).first;
      expect(active.map((row) => row.id), <String>[keptId]);
    });

    test('watchById returns null for a deleted rule', () async {
      final String id = await createExpenseRule();
      await ruleRepo.softDelete(id);
      final RecurringRuleRow? row = await ruleRepo.watchById(id).first;
      expect(row, isNull);
    });

    test('requireActiveRule throws for a deleted rule', () async {
      final String id = await createExpenseRule();
      await ruleRepo.softDelete(id);
      expect(() => ruleRepo.requireActiveRule(id), throwsA(isA<RecurringRuleNotFoundException>()));
    });
  });
}
