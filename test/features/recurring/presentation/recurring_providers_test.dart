import 'dart:async';

import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/providers.dart';
import 'package:ai_financial_coach/core/database/repositories/account_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/recurring_occurrence_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/recurring_rule_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/transaction_repository.dart';
import 'package:ai_financial_coach/core/money/money.dart';
import 'package:ai_financial_coach/features/recurring/domain/recurrence_frequency.dart';
import 'package:ai_financial_coach/features/recurring/domain/recurring_rule_kind.dart';
import 'package:ai_financial_coach/features/recurring/domain/recurring_schedule.dart';
import 'package:ai_financial_coach/features/recurring/presentation/recurring_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// NOTE: exercises generated Drift code -- see CLAUDE_FIRST_CODING_PROMPT.md.

/// Attaches a listener BEFORE any mutating write that should be
/// awaited, and resolves the first emission satisfying [predicate].
/// Attaching after the write risks missing the exact transition (a
/// non-autoDispose provider can go directly `AsyncData(old)` ->
/// `AsyncData(new)` without re-entering `isLoading`) -- same fix applied
/// to `savings_goal_providers_test.dart`'s soft-delete test in Beta 1
/// Task 3.
Future<T> _waitFor<T>(
  ProviderContainer container,
  ProviderListenable<AsyncValue<T>> provider,
  bool Function(T) predicate,
) {
  final Completer<T> completer = Completer<T>();
  late final ProviderSubscription<AsyncValue<T>> sub;
  sub = container.listen(provider, (AsyncValue<T>? previous, AsyncValue<T> next) {
    final T? data = next.valueOrNull;
    if (data != null && predicate(data) && !completer.isCompleted) {
      completer.complete(data);
    }
  }, fireImmediately: true);
  return completer.future.whenComplete(sub.close);
}

void main() {
  late AppDatabase db;
  late ProfileRepository profileRepo;
  late AccountRepository accountRepo;
  late RecurringRuleRepository ruleRepo;
  late RecurringOccurrenceRepository occurrenceRepo;
  late String profileId;
  late String jpyAccountId;
  late String usdAccountId;
  late ProviderContainer container;
  late DateTime today;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    profileRepo = ProfileRepository(db);
    accountRepo = AccountRepository(db);
    ruleRepo = RecurringRuleRepository(db, accountRepo);
    occurrenceRepo = RecurringOccurrenceRepository(
      db,
      ruleRepo,
      TransactionRepository(db, accountRepo),
    );
    today = normalizeRecurringDate(DateTime.now().toUtc());

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
    usdAccountId = await accountRepo.createAccount(
      profileId: profileId,
      name: 'US Wallet',
      type: 'cash',
      currencyCode: 'USD',
    );

    container = ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
  });

  Future<String> createDailyRule({
    required DateTime startDate,
    String name = 'Coffee',
    String accountId = '',
    String currencyCode = 'JPY',
    int amountMinorUnits = 500,
  }) {
    return ruleRepo.createRule(
      profileId: profileId,
      kind: RecurringRuleKind.expense,
      name: name,
      amount: Money.fromMinorUnits(amountMinorUnits, currencyCode),
      accountId: accountId.isEmpty ? jpyAccountId : accountId,
      frequency: RecurrenceFrequency.daily,
      interval: 1,
      startDate: startDate,
    );
  }

  test('overdue ordering -- oldest missed date first', () async {
    final String ruleId = await createDailyRule(startDate: today.subtract(const Duration(days: 3)));
    final List<RecurringPendingItem> items = await _waitFor(
      container,
      recurringPendingItemsProvider,
      (list) => list.where((i) => i.rule.id == ruleId).length == 4, // 3 overdue + today
    );

    final List<DateTime> overdueDates = items
        .where((i) => i.urgency == RecurringItemUrgency.overdue)
        .map((i) => i.scheduledDateUtc)
        .toList();
    expect(overdueDates, <DateTime>[
      today.subtract(const Duration(days: 3)),
      today.subtract(const Duration(days: 2)),
      today.subtract(const Duration(days: 1)),
    ]);
  });

  test('today ordering -- a rule scheduled for today appears exactly once as dueToday', () async {
    final String ruleId = await createDailyRule(startDate: today);
    final List<RecurringPendingItem> items = await _waitFor(
      container,
      recurringPendingItemsProvider,
      (list) => list.any((i) => i.rule.id == ruleId),
    );

    final List<RecurringPendingItem> forRule = items.where((i) => i.rule.id == ruleId).toList();
    final List<RecurringPendingItem> dueToday =
        forRule.where((i) => i.urgency == RecurringItemUrgency.dueToday).toList();
    expect(dueToday, hasLength(1));
    expect(dueToday.single.scheduledDateUtc, today);
  });

  test('upcoming ordering -- nearest upcoming date sorts before a farther one', () async {
    final String nearId = await createDailyRule(
      name: 'Near',
      startDate: today.add(const Duration(days: 2)),
    );
    final String farId = await createDailyRule(
      name: 'Far',
      startDate: today.add(const Duration(days: 10)),
    );

    final List<RecurringPendingItem> items = await _waitFor(
      container,
      recurringPendingItemsProvider,
      (list) => list.any((i) => i.rule.id == nearId) && list.any((i) => i.rule.id == farId),
    );

    final List<RecurringPendingItem> upcoming =
        items.where((i) => i.urgency == RecurringItemUrgency.upcoming).toList();
    final int nearIndex = upcoming.indexWhere((i) => i.rule.id == nearId);
    final int farIndex = upcoming.indexWhere((i) => i.rule.id == farId);
    expect(nearIndex, greaterThanOrEqualTo(0));
    expect(farIndex, greaterThanOrEqualTo(0));
    expect(nearIndex, lessThan(farIndex));
  });

  test('overdue/dueToday always sort before upcoming', () async {
    await createDailyRule(name: 'Overdue one', startDate: today.subtract(const Duration(days: 1)));
    await createDailyRule(name: 'Future one', startDate: today.add(const Duration(days: 5)));

    final List<RecurringPendingItem> items = await _waitFor(
      container,
      recurringPendingItemsProvider,
      (list) => list.length >= 3, // 1 overdue + 1 dueToday (from the first rule) + 1 upcoming
    );

    final List<int> ranks = items
        .map(
          (i) => switch (i.urgency) {
            RecurringItemUrgency.overdue => 0,
            RecurringItemUrgency.dueToday => 1,
            RecurringItemUrgency.upcoming => 2,
          },
        )
        .toList();
    final List<int> sortedRanks = List<int>.from(ranks)..sort();
    expect(ranks, sortedRanks);
  });

  test('a soft-deleted rule is excluded from pending items', () async {
    final String ruleId = await createDailyRule(startDate: today.subtract(const Duration(days: 2)));
    await _waitFor(
      container,
      recurringPendingItemsProvider,
      (list) => list.any((i) => i.rule.id == ruleId),
    );

    await ruleRepo.softDelete(ruleId);
    final List<RecurringPendingItem> afterDelete = await _waitFor(
      container,
      recurringPendingItemsProvider,
      (list) => list.every((i) => i.rule.id != ruleId),
    );
    expect(afterDelete.where((i) => i.rule.id == ruleId), isEmpty);
  });

  test('a posted date is excluded from pending items; a skipped date is excluded too', () async {
    final String ruleId = await createDailyRule(startDate: today.subtract(const Duration(days: 2)));
    await _waitFor(
      container,
      recurringPendingItemsProvider,
      (list) => list.where((i) => i.rule.id == ruleId).length == 3, // 2 overdue + today
    );

    final DateTime overdueDate = today.subtract(const Duration(days: 2));
    await occurrenceRepo.postOccurrence(ruleId: ruleId, scheduledDateUtc: overdueDate);

    final List<RecurringPendingItem> afterPost = await _waitFor(
      container,
      recurringPendingItemsProvider,
      (list) => list.where((i) => i.rule.id == ruleId).length == 2,
    );
    expect(
      afterPost.where((i) => i.rule.id == ruleId).map((i) => i.scheduledDateUtc),
      isNot(contains(overdueDate)),
    );

    final DateTime otherOverdueDate = today.subtract(const Duration(days: 1));
    await occurrenceRepo.skipOccurrence(ruleId: ruleId, scheduledDateUtc: otherOverdueDate);

    final List<RecurringPendingItem> afterSkip = await _waitFor(
      container,
      recurringPendingItemsProvider,
      (list) => list.where((i) => i.rule.id == ruleId).length == 1,
    );
    final List<DateTime> remainingDates =
        afterSkip.where((i) => i.rule.id == ruleId).map((i) => i.scheduledDateUtc).toList();
    expect(remainingDates, <DateTime>[today]);
  });

  test(
    'a rule created AFTER the pending-items provider is already subscribed still has its '
    'posted occurrence excluded -- regression for the _handledOccurrencesProvider '
    'asyncExpand/never-completing-inner-stream bug (MANUAL TASK4A BUG FOUND)',
    () async {
      // Rule A exists first, and the provider is subscribed to BEFORE Rule
      // B is ever created -- this ordering is the whole point of the test.
      // Every other test in this file creates all of its rules before the
      // first `_waitFor`, so none of them would have caught a bug where a
      // later rule creation is never picked up by the handled-occurrences
      // stream.
      final String ruleAId = await createDailyRule(name: 'Rule A', startDate: today);
      await _waitFor(
        container,
        recurringPendingItemsProvider,
        (list) => list.any((i) => i.rule.id == ruleAId),
      );

      final String ruleBId = await createDailyRule(name: 'Rule B', startDate: today);
      await _waitFor(
        container,
        recurringPendingItemsProvider,
        (list) => list.any((i) => i.rule.id == ruleBId),
      );

      await occurrenceRepo.postOccurrence(ruleId: ruleBId, scheduledDateUtc: today);

      // Before the fix, `_handledOccurrencesProvider`'s `ruleIds` was
      // frozen at `[ruleAId]` (the set active when this provider was
      // first subscribed, above), so Rule B's posted occurrence was
      // never watched and this predicate never became true.
      final List<RecurringPendingItem> afterPost = await _waitFor(
        container,
        recurringPendingItemsProvider,
        (list) => list.where((i) => i.rule.id == ruleBId).every((i) => i.scheduledDateUtc != today),
      );

      final List<RecurringPendingItem> ruleBItems =
          afterPost.where((i) => i.rule.id == ruleBId).toList();
      expect(
        ruleBItems.map((i) => i.scheduledDateUtc),
        isNot(contains(today)),
      );

      // The occurrence really is posted -- a raw table read, independent
      // of the provider under test.
      final List<RecurringOccurrenceRow> occurrences =
          await (db.select(db.recurringOccurrences)..where((tbl) => tbl.ruleId.equals(ruleBId))).get();
      expect(occurrences, hasLength(1));
      expect(occurrences.single.status, 'posted');

      // Same "prefer overdue, then today, then nearest upcoming" per-rule
      // semantics the "posted date excluded" test above already exercises
      // for Rule A: once Rule B has nothing unhandled on or before today,
      // its next daily occurrence surfaces as a single Upcoming preview.
      expect(ruleBItems, hasLength(1));
      expect(ruleBItems.single.urgency, RecurringItemUrgency.upcoming);
      expect(ruleBItems.single.scheduledDateUtc, today.add(const Duration(days: 1)));
    },
  );

  test('the Home selection never sums mixed currencies -- exactly one item, one currency', () async {
    final String jpyRuleId = await createDailyRule(
      name: 'JPY overdue',
      startDate: today.subtract(const Duration(days: 1)),
      currencyCode: 'JPY',
      accountId: jpyAccountId,
    );
    await createDailyRule(
      name: 'USD overdue',
      startDate: today.subtract(const Duration(days: 1)),
      currencyCode: 'USD',
      accountId: usdAccountId,
    );

    final RecurringHomeSelection selection = await _waitFor(
      container,
      homeRecurringSelectionProvider,
      (sel) => sel.kind == RecurringHomeSelectionKind.item,
    );

    expect(selection.kind, RecurringHomeSelectionKind.item);
    expect(selection.item, isNotNull);
    // A single, real rule's currency -- never a combined/fabricated
    // total across JPY and USD.
    expect(<String>['JPY', 'USD'], contains(selection.item!.rule.currencyCode));
    // The selected item is whichever rule sorts first (overdue,
    // tie-broken alphabetically: "JPY overdue" < "USD overdue").
    expect(selection.item!.rule.id, jpyRuleId);
  });

  test('no active rules -- Home selection is empty, not a loading/zero placeholder', () async {
    final RecurringHomeSelection selection = await _waitFor(
      container,
      homeRecurringSelectionProvider,
      (sel) => true,
    );
    expect(selection.kind, RecurringHomeSelectionKind.empty);
    expect(selection.item, isNull);
  });
}
