import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/providers.dart';
import 'package:ai_financial_coach/core/database/repositories/account_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/recurring_rule_repository.dart';
import 'package:ai_financial_coach/core/money/money.dart';
import 'package:ai_financial_coach/core/notifications/notification_providers.dart';
import 'package:ai_financial_coach/core/notifications/notification_scheduler.dart';
import 'package:ai_financial_coach/features/recurring/domain/recurrence_frequency.dart';
import 'package:ai_financial_coach/features/recurring/domain/recurring_rule_kind.dart';
import 'package:ai_financial_coach/features/recurring/domain/recurring_schedule.dart';
import 'package:ai_financial_coach/features/recurring/presentation/recurring_screen.dart';
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_notification_scheduler.dart';

// NOTE: exercises generated Drift code — see CLAUDE_FIRST_CODING_PROMPT.md.
//
// Beta 1 Task 4A. Covers the recurring screen's list rendering
// (Overdue/Due today/Upcoming grouping), the create/edit form, posting
// and skipping a due occurrence, the empty state, and a narrow-width
// (320px) overflow regression -- see `docs/14_DECISION_LOG.md` ADR-023.
// Deterministic scheduling itself has its own dedicated coverage in
// `test/features/recurring/domain/recurring_schedule_test.dart`; nothing
// here re-checks recurrence math.

class _SeedAccount {
  const _SeedAccount({required this.name, required this.currencyCode});
  final String name;
  final String currencyCode;
}

void main() {
  Future<(AppDatabase, String, List<AccountRow>)> seededDb({
    List<_SeedAccount> accounts = const <_SeedAccount>[
      _SeedAccount(name: 'JPY Wallet', currencyCode: 'JPY'),
    ],
  }) async {
    final AppDatabase db = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    final ProfileRepository profileRepo = ProfileRepository(db);
    final AccountRepository accountRepo = AccountRepository(db);
    final String profileId = await profileRepo.createProfile(
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
    final List<AccountRow> created = <AccountRow>[];
    for (final _SeedAccount account in accounts) {
      final String id = await accountRepo.createAccount(
        profileId: profileId,
        name: account.name,
        type: 'cash',
        currencyCode: account.currencyCode,
      );
      created.add(await accountRepo.requireById(id));
    }
    return (db, profileId, created);
  }

  Widget appWithRecurring(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: RecurringScreen()),
    );
  }

  /// Same deterministic shutdown sequence every other widget test file in
  /// this project uses: unmount, then dispose, then one `pumpAndSettle()`
  /// so Drift can finish cancelling every active `QueryStream` before
  /// `db.close()`.
  ///
  /// This is safe to keep identical to `savings_goals_screen_test.dart`/
  /// `budgets_screen_test.dart`/`home_screen_test.dart`/
  /// `add_transaction_screen_test.dart` now that `seededDb()` opens the
  /// test database with `closeStreamsSynchronously: true` (see the
  /// comment there): the actual root cause of this file's two "Timer is
  /// still pending" failures was never pump ordering. Drift's
  /// `StreamQueryStore.markAsClosed` deliberately keeps a query stream's
  /// underlying statement cached for exactly one real event-loop
  /// iteration after its last listener unsubscribes (a `Timer.run()`,
  /// by design, so `StreamBuilder`-style resubscription during a
  /// rebuild can reuse it -- see
  /// https://drift.simonbinder.eu/testing/) -- a genuinely scheduled
  /// `Timer`, not a `pumpAndSettle()`/frame-scheduling artifact, so no
  /// number or ordering of pumps in THIS helper could reliably beat it:
  /// this screen has more concurrent `QueryStream`s to unwind than the
  /// other test files (the create/edit dialog additionally watches
  /// `accountsProvider`/`categoriesForTypeProvider`, and
  /// `_handledOccurrencesProvider` re-subscribes its inner stream via
  /// `asyncExpand` whenever `activeRecurringRulesProvider` re-emits),
  /// and any one of those cancellations -- including ones triggered
  /// only once `db.close()` itself runs -- could still schedule a fresh
  /// `Timer.zero` after this helper's last controlled pump. Configuring
  /// the connection to close streams synchronously removes the
  /// `Timer.run()` at its source instead, so this teardown no longer
  /// needs to be any different from every other file's.
  Future<void> disposeInOrder(WidgetTester tester, ProviderContainer container, AppDatabase db) async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pumpAndSettle();
    await db.close();
  }

  void useTallSurface(WidgetTester tester) {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(400, 2000);
    tester.view.devicePixelRatio = 1.0;
  }

  testWidgets('the empty state is shown when there are no recurring rules yet', (tester) async {
    final (AppDatabase db, _, _) = await seededDb();
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithRecurring(container));
    await tester.pumpAndSettle();

    expect(find.textContaining('No recurring rules yet'), findsOneWidget);
  });

  testWidgets(
    'creating a monthly expense rule anchored today shows it under "Due today"',
    (tester) async {
      useTallSurface(tester);
      final (AppDatabase db, _, List<AccountRow> accounts) = await seededDb();
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRecurring(container));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('addRecurringRuleFab')));
      await tester.pumpAndSettle();
      expect(find.text('New recurring rule'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('recurringNameField')), 'Rent');

      await tester.tap(find.byKey(const Key('recurringAccountDropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('${accounts.first.name} (JPY)').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('recurringAmountField')), '80000');
      await tester.tap(find.byKey(const Key('saveRecurringRule')));
      await tester.pumpAndSettle();

      expect(find.text('New recurring rule'), findsNothing); // dialog closed
      expect(find.byKey(const Key('sectionDueToday')), findsOneWidget);
      expect(find.text('Rent'), findsOneWidget);
      expect(find.textContaining('¥80,000'), findsOneWidget);
    },
  );

  // Manual Android testing found: a JPY -> USD recurring transfer reached
  // Save, the repository correctly threw `CurrencyMismatchException`
  // (see `recurring_rule_repository_test.dart`'s
  // 'rejects a cross-currency transfer' test -- untouched by this
  // change), but `_submit` had no handler for it, so Save appeared
  // unresponsive. These four tests cover the UI-only fix: filtering the
  // destination dropdown to same-currency, non-source accounts;
  // clearing an incompatible destination when the source changes;
  // disabling Save with a helper message when no eligible destination
  // exists; and (in the next test) that a valid same-currency transfer
  // still saves cleanly. `_submit`'s new exception handling itself has
  // no dedicated widget test here because triggering it now requires
  // deliberately bypassing the UI filter -- exactly what the untouched
  // repository-level test already covers.
  testWidgets(
    'a transfer form only offers same-currency, non-source accounts as the destination',
    (tester) async {
      useTallSurface(tester);
      final (AppDatabase db, _, _) = await seededDb(
        accounts: const <_SeedAccount>[
          _SeedAccount(name: 'JPY A', currencyCode: 'JPY'),
          _SeedAccount(name: 'JPY B', currencyCode: 'JPY'),
          _SeedAccount(name: 'USD A', currencyCode: 'USD'),
          _SeedAccount(name: 'USD B', currencyCode: 'USD'),
        ],
      );
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRecurring(container));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('addRecurringRuleFab')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('recurringKindDropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('transfer').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('recurringAccountDropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('JPY A (JPY)').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('recurringDestinationAccountDropdown')));
      await tester.pumpAndSettle();

      // Same currency, not the source itself: offered.
      expect(find.text('JPY B (JPY)'), findsOneWidget);
      // Different currency: never offered, regardless of account.
      expect(find.text('USD A (USD)'), findsNothing);
      expect(find.text('USD B (USD)'), findsNothing);
      // The source account itself still appears exactly once -- as the
      // source dropdown's own collapsed selection -- never duplicated
      // into the destination menu as a choice for itself.
      expect(find.text('JPY A (JPY)'), findsOneWidget);
    },
  );

  testWidgets(
    'a same-currency transfer saves successfully with no error message',
    (tester) async {
      useTallSurface(tester);
      final (AppDatabase db, _, _) = await seededDb(
        accounts: const <_SeedAccount>[
          _SeedAccount(name: 'JPY A', currencyCode: 'JPY'),
          _SeedAccount(name: 'JPY B', currencyCode: 'JPY'),
        ],
      );
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRecurring(container));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('addRecurringRuleFab')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('recurringKindDropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('transfer').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('recurringNameField')), 'Move to savings');

      await tester.tap(find.byKey(const Key('recurringAccountDropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('JPY A (JPY)').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('recurringDestinationAccountDropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('JPY B (JPY)').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('recurringAmountField')), '5000');
      await tester.tap(find.byKey(const Key('saveRecurringRule')));
      await tester.pumpAndSettle();

      expect(find.text('New recurring rule'), findsNothing); // dialog closed -- nothing blocked Save
      expect(find.byKey(const Key('recurringFormErrorMessage')), findsNothing);
      expect(find.text('Move to savings'), findsOneWidget);
    },
  );

  testWidgets(
    'changing the source account clears a destination that is no longer eligible',
    (tester) async {
      useTallSurface(tester);
      final (AppDatabase db, _, _) = await seededDb(
        accounts: const <_SeedAccount>[
          _SeedAccount(name: 'JPY A', currencyCode: 'JPY'),
          _SeedAccount(name: 'JPY B', currencyCode: 'JPY'),
          _SeedAccount(name: 'USD A', currencyCode: 'USD'),
          _SeedAccount(name: 'USD B', currencyCode: 'USD'),
        ],
      );
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRecurring(container));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('addRecurringRuleFab')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('recurringKindDropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('transfer').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('recurringAccountDropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('JPY A (JPY)').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('recurringDestinationAccountDropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('JPY B (JPY)').last);
      await tester.pumpAndSettle();

      // Destination really is selected before the source changes.
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(
              find.byKey(const Key('recurringDestinationAccountDropdown')),
            )
            .initialValue,
        isNotNull,
      );

      // Switch the source to a USD account -- JPY B is no longer a
      // valid destination for it.
      await tester.tap(find.byKey(const Key('recurringAccountDropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('USD A (USD)').last);
      await tester.pumpAndSettle();

      // The stale JPY destination is cleared (a real state change, not
      // merely hidden by the new item list) -- USD B is offered
      // instead, unselected.
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(
              find.byKey(const Key('recurringDestinationAccountDropdown')),
            )
            .initialValue,
        isNull,
      );
      await tester.tap(find.byKey(const Key('recurringDestinationAccountDropdown')));
      await tester.pumpAndSettle();
      expect(find.text('USD B (USD)'), findsOneWidget);
      expect(find.text('JPY B (JPY)'), findsNothing);
    },
  );

  testWidgets(
    'no eligible destination accounts disables Save and shows a helper message',
    (tester) async {
      useTallSurface(tester);
      final (AppDatabase db, _, _) = await seededDb(
        accounts: const <_SeedAccount>[
          _SeedAccount(name: 'JPY A', currencyCode: 'JPY'),
          _SeedAccount(name: 'USD A', currencyCode: 'USD'),
        ],
      );
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRecurring(container));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('addRecurringRuleFab')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('recurringKindDropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('transfer').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('recurringAccountDropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('JPY A (JPY)').last);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('noEligibleDestinationMessage')), findsOneWidget);
      expect(find.text('No same-currency destination accounts available.'), findsOneWidget);
      expect(find.byKey(const Key('recurringDestinationAccountDropdown')), findsNothing);

      final FilledButton saveButton = tester.widget<FilledButton>(
        find.byKey(const Key('saveRecurringRule')),
      );
      expect(saveButton.onPressed, isNull);
    },
  );

  testWidgets(
    'posting a due occurrence creates a real transaction, links it to the occurrence, and '
    'removes the pending item from the list',
    (tester) async {
      useTallSurface(tester);
      final (AppDatabase db, String profileId, List<AccountRow> accounts) = await seededDb();
      final DateTime todayUtc = DateTime.now().toUtc();
      final DateTime today = DateTime.utc(todayUtc.year, todayUtc.month, todayUtc.day);
      final String ruleId = await RecurringRuleRepository(db, AccountRepository(db)).createRule(
        profileId: profileId,
        kind: RecurringRuleKind.expense,
        name: 'Rent',
        amount: Money.fromMinorUnits(80000, 'JPY'),
        accountId: accounts.first.id,
        frequency: RecurrenceFrequency.monthly,
        interval: 1,
        startDate: today,
      );
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRecurring(container));
      await tester.pumpAndSettle();

      expect(find.text('Rent'), findsOneWidget);
      final Finder postButton = find.byWidgetPredicate(
        (Widget w) => w is FilledButton && (w.key as ValueKey<String>?)?.value.startsWith(
              'postOccurrence_$ruleId',
            ) == true,
      );
      expect(postButton, findsOneWidget);
      await tester.tap(postButton);
      await tester.pumpAndSettle();

      // Today's occurrence is handled -- its own card (keyed by today's
      // date) is gone, and the "Due today" section no longer applies to
      // this rule. The rule itself stays active, so its next legitimate
      // occurrence (computed by the same `RecurringSchedule` production
      // uses, not a hand-derived date) now surfaces as a new "Upcoming"
      // item -- a real, later scheduled date, not the same handled one.
      expect(
        find.byKey(Key('postOccurrence_${ruleId}_${today.toIso8601String()}')),
        findsNothing,
      );
      expect(find.byKey(const Key('sectionDueToday')), findsNothing);

      final DateTime nextOccurrence = RecurringSchedule(
        frequency: RecurrenceFrequency.monthly,
        interval: 1,
        startDateUtc: today,
      ).nextOccurrenceAfter(today)!;
      expect(nextOccurrence.isAfter(today), isTrue); // a genuinely later date
      expect(find.byKey(const Key('sectionUpcoming')), findsOneWidget);
      expect(find.text('Rent'), findsOneWidget); // the upcoming occurrence's card
      expect(
        find.byKey(Key('postOccurrence_${ruleId}_${nextOccurrence.toIso8601String()}')),
        findsOneWidget,
      );

      final List<RecurringOccurrenceRow> occurrences =
          await db.select(db.recurringOccurrences).get();
      expect(occurrences, hasLength(1));
      expect(occurrences.single.status, 'posted');
      // Raw table read (bypassing `RecurringOccurrenceRepository`'s
      // stream API, which already re-tags every read via its private
      // `_withUtcDateTimes` -- see that method's doc comment): drift's
      // default (non-text) DateTime storage always returns a
      // local-tagged value, and `DateTime.==` requires both the same
      // moment AND the same zone tag (UTC vs. local) -- see the
      // `isAtSameMomentAs` doc comparison -- so a same-instant but
      // differently-tagged value fails `==` even though the persisted
      // calendar date is correct. `.toUtc()` only re-tags this read
      // value for the comparison below; it never touches storage or
      // moves the instant, exactly like every repository's own
      // `_withUtcDateTimes`.
      expect(occurrences.single.scheduledDate.toUtc(), today);
      expect(occurrences.single.transactionId, isNotNull);

      final List<Transaction> transactions = await db.select(db.transactions).get();
      expect(transactions, hasLength(1));
      expect(transactions.single.id, occurrences.single.transactionId);
      expect(transactions.single.type, 'expense');
    },
  );

  testWidgets(
    'skipping a due occurrence creates no transaction and removes the pending item',
    (tester) async {
      useTallSurface(tester);
      final (AppDatabase db, String profileId, List<AccountRow> accounts) = await seededDb();
      final DateTime todayUtc = DateTime.now().toUtc();
      final DateTime today = DateTime.utc(todayUtc.year, todayUtc.month, todayUtc.day);
      final String ruleId = await RecurringRuleRepository(db, AccountRepository(db)).createRule(
        profileId: profileId,
        kind: RecurringRuleKind.income,
        name: 'Salary',
        amount: Money.fromMinorUnits(300000, 'JPY'),
        accountId: accounts.first.id,
        frequency: RecurrenceFrequency.monthly,
        interval: 1,
        startDate: today,
      );
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRecurring(container));
      await tester.pumpAndSettle();

      expect(find.text('Salary'), findsOneWidget);
      final Finder skipButton = find.byWidgetPredicate(
        (Widget w) => w is OutlinedButton && (w.key as ValueKey<String>?)?.value.startsWith(
              'skipOccurrence_$ruleId',
            ) == true,
      );
      expect(skipButton, findsOneWidget);
      await tester.tap(skipButton);
      await tester.pumpAndSettle();

      // Today's occurrence is handled (skipped) -- its own card (keyed by
      // today's date) is gone, and the "Due today" section no longer
      // applies to this rule. The rule itself stays active, so its next
      // legitimate occurrence (computed by the same `RecurringSchedule`
      // production uses, not a hand-derived date) now surfaces as a new
      // "Upcoming" item -- a real, later scheduled date, not the same
      // handled one.
      expect(
        find.byKey(Key('skipOccurrence_${ruleId}_${today.toIso8601String()}')),
        findsNothing,
      );
      expect(find.byKey(const Key('sectionDueToday')), findsNothing);

      final DateTime nextOccurrence = RecurringSchedule(
        frequency: RecurrenceFrequency.monthly,
        interval: 1,
        startDateUtc: today,
      ).nextOccurrenceAfter(today)!;
      expect(nextOccurrence.isAfter(today), isTrue); // a genuinely later date
      expect(find.byKey(const Key('sectionUpcoming')), findsOneWidget);
      expect(find.text('Salary'), findsOneWidget); // the upcoming occurrence's card
      expect(
        find.byKey(Key('skipOccurrence_${ruleId}_${nextOccurrence.toIso8601String()}')),
        findsOneWidget,
      );

      final List<RecurringOccurrenceRow> occurrences =
          await db.select(db.recurringOccurrences).get();
      expect(occurrences, hasLength(1));
      expect(occurrences.single.status, 'skipped');
      // Raw table read (bypassing `RecurringOccurrenceRepository`'s
      // stream API, which already re-tags every read via its private
      // `_withUtcDateTimes` -- see that method's doc comment): drift's
      // default (non-text) DateTime storage always returns a
      // local-tagged value, and `DateTime.==` requires both the same
      // moment AND the same zone tag (UTC vs. local) -- see the
      // `isAtSameMomentAs` doc comparison -- so a same-instant but
      // differently-tagged value fails `==` even though the persisted
      // calendar date is correct. `.toUtc()` only re-tags this read
      // value for the comparison below; it never touches storage or
      // moves the instant, exactly like every repository's own
      // `_withUtcDateTimes`.
      expect(occurrences.single.scheduledDate.toUtc(), today);
      expect(occurrences.single.transactionId, isNull);

      final List<Transaction> transactions = await db.select(db.transactions).get();
      expect(transactions, isEmpty);
    },
  );

  testWidgets('editing a rule renders its new name without touching its schedule', (tester) async {
    useTallSurface(tester);
    final (AppDatabase db, String profileId, List<AccountRow> accounts) = await seededDb();
    final DateTime todayUtc = DateTime.now().toUtc();
    final String ruleId = await RecurringRuleRepository(db, AccountRepository(db)).createRule(
      profileId: profileId,
      kind: RecurringRuleKind.expense,
      name: 'Rent',
      amount: Money.fromMinorUnits(80000, 'JPY'),
      accountId: accounts.first.id,
      frequency: RecurrenceFrequency.monthly,
      interval: 1,
      startDate: DateTime.utc(todayUtc.year, todayUtc.month, todayUtc.day),
    );
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithRecurring(container));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(Key('editRule_$ruleId')));
    await tester.pumpAndSettle();
    expect(find.text('Edit recurring rule'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('recurringNameField')), 'Apartment Rent');
    await tester.tap(find.byKey(const Key('saveRecurringRule')));
    await tester.pumpAndSettle();

    expect(find.text('Edit recurring rule'), findsNothing);
    expect(find.text('Apartment Rent'), findsOneWidget);
    expect(find.text('Rent'), findsNothing);
  });

  testWidgets(
    'deleting a rule (soft delete) removes it from the list but keeps the rule row itself',
    (tester) async {
      useTallSurface(tester);
      final (AppDatabase db, String profileId, List<AccountRow> accounts) = await seededDb();
      final DateTime todayUtc = DateTime.now().toUtc();
      final String ruleId = await RecurringRuleRepository(db, AccountRepository(db)).createRule(
        profileId: profileId,
        kind: RecurringRuleKind.expense,
        name: 'Rent',
        amount: Money.fromMinorUnits(80000, 'JPY'),
        accountId: accounts.first.id,
        frequency: RecurrenceFrequency.monthly,
        interval: 1,
        startDate: DateTime.utc(todayUtc.year, todayUtc.month, todayUtc.day),
      );
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRecurring(container));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(Key('deleteRule_$ruleId')));
      await tester.pumpAndSettle();
      expect(find.text('Delete this recurring rule?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.textContaining('No recurring rules yet'), findsOneWidget);

      final RecurringRuleRow row = await (db.select(db.recurringRules)
            ..where((tbl) => tbl.id.equals(ruleId)))
          .getSingle();
      expect(row.deletedAt, isNotNull); // soft-deleted, never hard-deleted
    },
  );

  testWidgets(
    'the recurring list lays out without overflow on a narrow (320px-wide) screen with a '
    'long rule name',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1.0;

      final (AppDatabase db, String profileId, List<AccountRow> accounts) = await seededDb();
      final DateTime todayUtc = DateTime.now().toUtc();
      await RecurringRuleRepository(db, AccountRepository(db)).createRule(
        profileId: profileId,
        kind: RecurringRuleKind.expense,
        name: 'A rather long recurring rule name to stress narrow-width layout',
        amount: Money.fromMinorUnits(80000, 'JPY'),
        accountId: accounts.first.id,
        frequency: RecurrenceFrequency.monthly,
        interval: 1,
        startDate: DateTime.utc(todayUtc.year, todayUtc.month, todayUtc.day),
      );
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRecurring(container));
      await tester.pumpAndSettle();

      final Object? overflowException = tester.takeException();
      if (overflowException != null) {
        fail('Narrow-screen (320px) recurring list layout threw an exception:\n\n$overflowException');
      }
    },
  );

  // Beta 1 Task 4B: the "Remind me" toggle and its permission flow.
  // `appDatabaseProvider` is overridden as usual; `notificationSchedulerProvider`
  // is additionally overridden with an in-memory fake -- no test here
  // needs a real device or the `flutter_local_notifications` plugin.
  testWidgets(
    'enabling "Remind me" with permission granted saves the rule with notificationsEnabled=true',
    (tester) async {
      useTallSurface(tester);
      final (AppDatabase db, _, List<AccountRow> accounts) = await seededDb();
      final FakeNotificationScheduler fakeScheduler =
          FakeNotificationScheduler(permission: NotificationPermissionStatus.granted);
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          notificationSchedulerProvider.overrideWithValue(fakeScheduler),
        ],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRecurring(container));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('addRecurringRuleFab')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('recurringNameField')), 'Rent');
      await tester.tap(find.byKey(const Key('recurringAccountDropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('${accounts.first.name} (JPY)').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('recurringAmountField')), '80000');

      expect(fakeScheduler.requestPermissionCallCount, 0); // not yet -- toggle untouched
      await tester.tap(find.byKey(const Key('recurringNotificationsToggle')));
      await tester.pumpAndSettle();
      expect(fakeScheduler.requestPermissionCallCount, 1);
      expect(
        tester.widget<SwitchListTile>(find.byKey(const Key('recurringNotificationsToggle'))).value,
        isTrue,
      );

      await tester.tap(find.byKey(const Key('saveRecurringRule')));
      await tester.pumpAndSettle();

      final RecurringRuleRow saved = await db.select(db.recurringRules).getSingle();
      expect(saved.notificationsEnabled, isTrue);
    },
  );

  testWidgets(
    'enabling "Remind me" when permission is denied reverts the toggle to off and shows feedback',
    (tester) async {
      useTallSurface(tester);
      final (AppDatabase db, _, List<AccountRow> accounts) = await seededDb();
      final FakeNotificationScheduler fakeScheduler =
          FakeNotificationScheduler(permission: NotificationPermissionStatus.denied);
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          notificationSchedulerProvider.overrideWithValue(fakeScheduler),
        ],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRecurring(container));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('addRecurringRuleFab')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('recurringNameField')), 'Rent');
      await tester.tap(find.byKey(const Key('recurringAccountDropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('${accounts.first.name} (JPY)').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('recurringAmountField')), '80000');

      await tester.tap(find.byKey(const Key('recurringNotificationsToggle')));
      await tester.pumpAndSettle();

      // Reverted to off -- persisted state should reflect actually-usable
      // behavior (correction 3) -- and the dialog is still open/usable,
      // never crashed or blocked.
      expect(
        tester.widget<SwitchListTile>(find.byKey(const Key('recurringNotificationsToggle'))).value,
        isFalse,
      );
      expect(find.textContaining("wasn't granted"), findsOneWidget);
      expect(find.text('New recurring rule'), findsOneWidget); // dialog still open

      // Recurring functionality itself is unaffected -- Save still works.
      await tester.tap(find.byKey(const Key('saveRecurringRule')));
      await tester.pumpAndSettle();
      final RecurringRuleRow saved = await db.select(db.recurringRules).getSingle();
      expect(saved.notificationsEnabled, isFalse);
    },
  );
}
