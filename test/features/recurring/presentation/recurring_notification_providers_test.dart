import 'dart:async';

import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/providers.dart';
import 'package:ai_financial_coach/core/database/repositories/account_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/recurring_occurrence_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/recurring_rule_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/transaction_repository.dart';
import 'package:ai_financial_coach/core/money/money.dart';
import 'package:ai_financial_coach/core/notifications/notification_providers.dart';
import 'package:ai_financial_coach/core/notifications/notification_scheduler.dart';
import 'package:ai_financial_coach/features/recurring/domain/recurrence_frequency.dart';
import 'package:ai_financial_coach/features/recurring/domain/recurring_rule_kind.dart';
import 'package:ai_financial_coach/features/recurring/domain/recurring_schedule.dart';
import 'package:ai_financial_coach/features/recurring/presentation/recurring_notification_providers.dart';
import 'package:ai_financial_coach/features/recurring/presentation/recurring_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_notification_scheduler.dart';

/// Attaches a listener BEFORE the write that should be awaited and
/// resolves on the first emission satisfying [predicate] -- same
/// precedent `recurring_providers_test.dart` established (attaching
/// after the write risks missing the exact transition).
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

// NOTE: exercises generated Drift code -- see CLAUDE_FIRST_CODING_PROMPT.md.
//
// Beta 1 Task 4B. Covers `reconcileRecurringReminders` (the algorithm
// behind every lifecycle correction -- see that function's doc comment)
// against a real in-memory database and repositories, plus one
// end-to-end test of `recurringNotificationReconcilerProvider` itself
// reacting to a Riverpod data change. Notification ID collision
// handling has its own dedicated coverage in
// `test/core/notifications/notification_id_allocator_test.dart`; the
// pure eligibility/horizon math has its own in
// `test/features/recurring/domain/recurring_reminder_planner_test.dart`
// -- nothing here re-checks either.
void main() {
  late AppDatabase db;
  late ProfileRepository profileRepo;
  late AccountRepository accountRepo;
  late RecurringRuleRepository ruleRepo;
  late RecurringOccurrenceRepository occurrenceRepo;
  late String profileId;
  late String accountId;
  late DateTime today;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    profileRepo = ProfileRepository(db);
    accountRepo = AccountRepository(db);
    ruleRepo = RecurringRuleRepository(db, accountRepo);
    occurrenceRepo = RecurringOccurrenceRepository(db, ruleRepo, TransactionRepository(db, accountRepo));
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
    accountId = await accountRepo.createAccount(
      profileId: profileId,
      name: 'Wallet',
      type: 'cash',
      currencyCode: 'JPY',
    );
    addTearDown(() async => db.close());
  });

  Future<String> createDailyRule({
    String name = 'Coffee',
    int amountMinorUnits = 500,
    bool notificationsEnabled = true,
    DateTime? startDate,
  }) {
    return ruleRepo.createRule(
      profileId: profileId,
      kind: RecurringRuleKind.expense,
      name: name,
      amount: Money.fromMinorUnits(amountMinorUnits, 'JPY'),
      accountId: accountId,
      frequency: RecurrenceFrequency.daily,
      interval: 1,
      startDate: startDate ?? today,
      notificationsEnabled: notificationsEnabled,
    );
  }

  Future<List<RecurringRuleRow>> activeRules() => ruleRepo.watchActiveRules(profileId).first;
  Future<List<RecurringOccurrenceRow>> handledFor(List<String> ruleIds) =>
      occurrenceRepo.watchHandledForRules(ruleIds).first;

  test('schedules one reminder per day from today through the 14-day horizon, inclusive', () async {
    await createDailyRule();
    final FakeNotificationScheduler fake = FakeNotificationScheduler();

    await reconcileRecurringReminders(
      rules: await activeRules(),
      handledOccurrences: const <RecurringOccurrenceRow>[],
      scheduler: fake,
      nowUtc: today,
    );

    expect(fake.scheduled.length, 15); // today + 14 more days
  });

  test('a rule with notificationsEnabled=false never gets any reminder scheduled', () async {
    await createDailyRule(notificationsEnabled: false);
    final FakeNotificationScheduler fake = FakeNotificationScheduler();

    await reconcileRecurringReminders(
      rules: await activeRules(),
      handledOccurrences: const <RecurringOccurrenceRow>[],
      scheduler: fake,
      nowUtc: today,
    );

    expect(fake.scheduled, isEmpty);
  });

  test('posting today\'s occurrence cancels its exact pending reminder on the next pass', () async {
    final String ruleId = await createDailyRule();
    final FakeNotificationScheduler fake = FakeNotificationScheduler();
    await reconcileRecurringReminders(
      rules: await activeRules(),
      handledOccurrences: await handledFor(<String>[ruleId]),
      scheduler: fake,
      nowUtc: today,
    );
    expect(fake.scheduled.length, 15);

    await occurrenceRepo.postOccurrence(ruleId: ruleId, scheduledDateUtc: today);
    await reconcileRecurringReminders(
      rules: await activeRules(),
      handledOccurrences: await handledFor(<String>[ruleId]),
      scheduler: fake,
      nowUtc: today,
    );

    expect(fake.scheduled.length, 14);
    expect(fake.scheduled.values.any((ScheduledReminder r) => r.scheduledDateUtc == today), isFalse);
  });

  test('skipping today\'s occurrence cancels its exact pending reminder, same as posting', () async {
    final String ruleId = await createDailyRule();
    final FakeNotificationScheduler fake = FakeNotificationScheduler();
    await reconcileRecurringReminders(
      rules: await activeRules(),
      handledOccurrences: await handledFor(<String>[ruleId]),
      scheduler: fake,
      nowUtc: today,
    );
    expect(fake.scheduled.length, 15);

    await occurrenceRepo.skipOccurrence(ruleId: ruleId, scheduledDateUtc: today);
    await reconcileRecurringReminders(
      rules: await activeRules(),
      handledOccurrences: await handledFor(<String>[ruleId]),
      scheduler: fake,
      nowUtc: today,
    );

    expect(fake.scheduled.length, 14);
    expect(fake.scheduled.values.any((ScheduledReminder r) => r.scheduledDateUtc == today), isFalse);
  });

  test('editing a rule\'s schedule replaces stale reminders with the new dates, no duplicates', () async {
    final String ruleId = await createDailyRule();
    final FakeNotificationScheduler fake = FakeNotificationScheduler();
    await reconcileRecurringReminders(
      rules: await activeRules(),
      handledOccurrences: const <RecurringOccurrenceRow>[],
      scheduler: fake,
      nowUtc: today,
    );
    expect(fake.scheduled.length, 15); // today .. today+14

    await ruleRepo.updateRule(id: ruleId, startDate: today.add(const Duration(days: 5)));
    await reconcileRecurringReminders(
      rules: await activeRules(),
      handledOccurrences: const <RecurringOccurrenceRow>[],
      scheduler: fake,
      nowUtc: today,
    );

    // Only today+5 .. today+14 remain desired (10 dates) -- today ..
    // today+4's reminders must be gone, not left dangling alongside the
    // new ones.
    expect(fake.scheduled.length, 10);
    expect(
      fake.scheduled.values.map((ScheduledReminder r) => r.scheduledDateUtc).toSet(),
      <DateTime>{for (int i = 5; i <= 14; i++) today.add(Duration(days: i))},
    );
  });

  test('editing name/amount only refreshes the existing reminder\'s content under the same id', () async {
    final String ruleId = await createDailyRule(name: 'Old Name', amountMinorUnits: 500);
    final FakeNotificationScheduler fake = FakeNotificationScheduler();
    await reconcileRecurringReminders(
      rules: await activeRules(),
      handledOccurrences: const <RecurringOccurrenceRow>[],
      scheduler: fake,
      nowUtc: today,
    );
    final MapEntry<int, ScheduledReminder> todayEntry =
        fake.scheduled.entries.firstWhere((e) => e.value.scheduledDateUtc == today);
    expect(todayEntry.value.title, contains('Old Name'));

    await ruleRepo.updateRule(
      id: ruleId,
      name: 'New Name',
      amount: Money.fromMinorUnits(999, 'JPY'),
    );
    await reconcileRecurringReminders(
      rules: await activeRules(),
      handledOccurrences: const <RecurringOccurrenceRow>[],
      scheduler: fake,
      nowUtc: today,
    );

    expect(fake.scheduled.length, 15); // no duplicate id was created
    final ScheduledReminder refreshed = fake.scheduled[todayEntry.key]!;
    expect(refreshed.title, contains('New Name'));
    expect(refreshed.body, contains('999'));
  });

  test('soft-deleting a rule cancels every one of its pending reminders', () async {
    final String ruleId = await createDailyRule();
    final FakeNotificationScheduler fake = FakeNotificationScheduler();
    await reconcileRecurringReminders(
      rules: await activeRules(),
      handledOccurrences: const <RecurringOccurrenceRow>[],
      scheduler: fake,
      nowUtc: today,
    );
    expect(fake.scheduled, isNotEmpty);

    await ruleRepo.softDelete(ruleId);
    await reconcileRecurringReminders(
      rules: await activeRules(), // now excludes the soft-deleted rule
      handledOccurrences: const <RecurringOccurrenceRow>[],
      scheduler: fake,
      nowUtc: today,
    );

    expect(fake.scheduled, isEmpty);
  });

  test('repeated reconciliation with nothing changed never grows the pending set', () async {
    await createDailyRule();
    final FakeNotificationScheduler fake = FakeNotificationScheduler();
    for (int pass = 0; pass < 3; pass++) {
      await reconcileRecurringReminders(
        rules: await activeRules(),
        handledOccurrences: const <RecurringOccurrenceRow>[],
        scheduler: fake,
        nowUtc: today,
      );
    }
    expect(fake.scheduled.length, 15);
  });

  test('two different rules due on the same date are both scheduled, under distinct ids', () async {
    final String ruleA = await createDailyRule(name: 'Rent');
    final String ruleB = await ruleRepo.createRule(
      profileId: profileId,
      kind: RecurringRuleKind.income,
      name: 'Salary',
      amount: Money.fromMinorUnits(300000, 'JPY'),
      accountId: accountId,
      frequency: RecurrenceFrequency.daily,
      interval: 1,
      startDate: today,
      notificationsEnabled: true,
    );
    final FakeNotificationScheduler fake = FakeNotificationScheduler();

    await reconcileRecurringReminders(
      rules: await activeRules(),
      handledOccurrences: const <RecurringOccurrenceRow>[],
      scheduler: fake,
      nowUtc: today,
    );

    final List<ScheduledReminder> todaysReminders =
        fake.scheduled.values.where((ScheduledReminder r) => r.scheduledDateUtc == today).toList();
    expect(todaysReminders.length, 2);
    expect(todaysReminders.map((ScheduledReminder r) => r.ruleId).toSet(), <String>{ruleA, ruleB});
    // Distinct ids -- two entries in the map keyed by different ids.
    expect(fake.scheduled.keys.toSet().length, fake.scheduled.length);
  });

  test('reconciliation never requests notification permission -- only schedule/cancel/pendingIds', () async {
    await createDailyRule();
    final FakeNotificationScheduler fake = FakeNotificationScheduler(
      permission: NotificationPermissionStatus.denied,
    );

    await reconcileRecurringReminders(
      rules: await activeRules(),
      handledOccurrences: const <RecurringOccurrenceRow>[],
      scheduler: fake,
      nowUtc: today,
    );

    // Beta 1 Task 4B correction 3: permission is requested ONLY as the
    // direct result of the user enabling "Remind me" in the UI -- never
    // by reconciliation, regardless of the current permission state.
    expect(fake.requestPermissionCallCount, 0);
  });

  test(
    'recurringNotificationReconcilerProvider reconciles reactively when active rules change',
    () async {
      final FakeNotificationScheduler fake = FakeNotificationScheduler();
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          notificationSchedulerProvider.overrideWithValue(fake),
        ],
      );
      addTearDown(container.dispose);

      // Instantiate the reconciler (same one-time `ref.watch` app.dart
      // performs) so it starts reacting, and wait for the underlying
      // rule stream to actually resolve (empty) before asserting --
      // asserting immediately risks racing `activeRecurringRulesProvider`
      // 's own async first emission.
      container.listen(recurringNotificationReconcilerProvider, (_, __) {});
      await _waitFor(container, activeRecurringRulesProvider, (List<RecurringRuleRow> r) => true);
      // One more turn for reconcileRecurringReminders' own await chain
      // (fake.schedule calls) to finish for this empty pass.
      await Future<void>.delayed(Duration.zero);
      expect(fake.scheduled, isEmpty);

      await createDailyRule();
      await _waitFor(
        container,
        activeRecurringRulesProvider,
        (List<RecurringRuleRow> r) => r.isNotEmpty,
      );
      // Let the reconciler's own (unawaited) async work finish.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(fake.scheduled, isNotEmpty);
    },
  );
}
