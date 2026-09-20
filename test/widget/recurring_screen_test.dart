import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/providers.dart';
import 'package:ai_financial_coach/core/database/repositories/account_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/recurring_rule_repository.dart';
import 'package:ai_financial_coach/core/money/money.dart';
import 'package:ai_financial_coach/core/notifications/notification_providers.dart';
import 'package:ai_financial_coach/core/notifications/notification_scheduler.dart';
import 'package:intl/intl.dart';
import 'package:ai_financial_coach/features/recurring/domain/recurrence_frequency.dart';
import 'package:ai_financial_coach/features/recurring/domain/recurring_rule_kind.dart';
import 'package:ai_financial_coach/features/recurring/domain/recurring_schedule.dart';
import 'package:ai_financial_coach/features/recurring/presentation/recurring_screen.dart';
import 'package:ai_financial_coach/l10n/generated/app_localizations.dart';
import 'package:ai_financial_coach/shared/theme/app_tokens.dart';
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

  Widget appWithRecurring(
    ProviderContainer container, {
    Locale locale = const Locale('en'),
  }) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const RecurringScreen(),
      ),
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
      await tester.tap(find.text('Transfer').last);
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
      await tester.tap(find.text('Transfer').last);
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
      await tester.tap(find.text('Transfer').last);
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
      await tester.tap(find.text('Transfer').last);
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

  // CP5.4b: `_PendingItemTile`'s amount/date line
  // ('${amount} \u00b7 ${date}') is one plain `Text` with no
  // `overflow`/`maxLines` set -- it wraps rather than clips (per the
  // CP5.4 audit), so this stress case confirms every digit of a large,
  // precision-sensitive currency amount and the scheduled date both
  // survive intact alongside a long rule name at a narrow width and a
  // large text scale, without requiring the amount and date to stay on
  // one line.
  testWidgets(
    'CP5.4b: a long rule name and a large 3-decimal KWD amount survive intact at a narrow '
    '320px width and a 1.6x text scale',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      const String longName = 'A rather long recurring rule name to stress narrow-width layout';
      final (AppDatabase db, String profileId, List<AccountRow> accounts) = await seededDb(
        accounts: const <_SeedAccount>[_SeedAccount(name: 'KWD Wallet', currencyCode: 'KWD')],
      );
      final DateTime todayUtc = DateTime.now().toUtc();
      final DateTime anchor = DateTime.utc(todayUtc.year, todayUtc.month, todayUtc.day);
      await RecurringRuleRepository(db, AccountRepository(db)).createRule(
        profileId: profileId,
        kind: RecurringRuleKind.expense,
        name: longName,
        // \u062F.\u064312,345.678 -- KWD has 3 minor units per
        // `CurrencyRegistry`, not 0; same magnitude already verified
        // correct by a real Windows run in CP5.2a/CP5.4a.
        amount: Money.fromMinorUnits(12345678, 'KWD'),
        accountId: accounts.first.id,
        frequency: RecurrenceFrequency.monthly,
        interval: 1,
        startDate: anchor,
      );

      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRecurring(container));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Only one rule is seeded and this screen shows no aggregate/
      // total elsewhere (unlike the goal detail hero row, where
      // "Remaining" can echo the same figure), so an unscoped
      // page-wide search carries no duplicate-match risk here.
      expect(find.text(longName), findsOneWidget);
      expect(find.textContaining('\u062F.\u064312,345.678'), findsOneWidget);
      expect(find.textContaining(DateFormat.yMMMd().format(anchor)), findsOneWidget);
    },
  );

  group('CP6.7 Japanese localization', () {
    testWidgets(
      'CP6.7 (A): the recurring screen renders in Japanese -- app bar, empty state, and the '
      "new-rule dialog's labels",
      (tester) async {
        useTallSurface(tester);
        final (AppDatabase db, _, _) = await seededDb();
        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRecurring(container, locale: const Locale('ja')));
        await tester.pumpAndSettle();

        // Scoped to the AppBar specifically -- the CP11 segmented
        // control's own "Recurring" segment renders the same
        // localized '定期' string, so an unscoped `find.text` now
        // matches both. This keeps the original intent (assert the
        // AppBar title is localized) exactly, without weakening to
        // `findsWidgets`.
        expect(
          find.descendant(of: find.byType(AppBar), matching: find.text('定期')),
          findsOneWidget,
        ); // AppBar title
        expect(find.textContaining('定期ルールがまだありません'), findsOneWidget); // empty state

        await tester.tap(find.byKey(const Key('addRecurringRuleFab')));
        await tester.pumpAndSettle();

        expect(find.text('新しい定期ルール'), findsOneWidget); // dialog title
        expect(find.text('名前'), findsOneWidget); // name field label
        expect(find.text('口座'), findsOneWidget); // account label (non-transfer)
        expect(find.text('金額'), findsOneWidget); // amount label
        expect(find.text('頻度'), findsOneWidget); // frequency label
        expect(find.text('リマインドする'), findsOneWidget); // remind-me switch title
        expect(find.text('キャンセル'), findsOneWidget);
        expect(find.text('保存'), findsOneWidget);
      },
    );

    testWidgets(
      'CP6.7 (B): a Japanese-language user-entered rule name renders exactly as typed under '
      'the Japanese locale',
      (tester) async {
        useTallSurface(tester);
        final (AppDatabase db, _, List<AccountRow> accounts) = await seededDb();
        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRecurring(container, locale: const Locale('ja')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('addRecurringRuleFab')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('recurringNameField')), '家賃');
        await tester.tap(find.byKey(const Key('recurringAccountDropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('${accounts.first.name} (JPY)').last);
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('recurringAmountField')), '80000');
        await tester.tap(find.byKey(const Key('saveRecurringRule')));
        await tester.pumpAndSettle();

        expect(find.text('家賃'), findsOneWidget); // untouched user text, never translated
      },
    );

    testWidgets(
      'CP6.7 (C): the rule-kind dropdown shows localized Japanese labels while the persisted '
      '`kind` value stays the untranslated English enum name',
      (tester) async {
        useTallSurface(tester);
        final (AppDatabase db, _, List<AccountRow> accounts) = await seededDb();
        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRecurring(container, locale: const Locale('ja')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('addRecurringRuleFab')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('recurringKindDropdown')));
        await tester.pumpAndSettle();
        expect(find.text('支出'), findsWidgets); // Expense -- also the current selection
        expect(find.text('収入'), findsOneWidget); // Income
        expect(find.text('振替'), findsOneWidget); // Transfer
        await tester.tap(find.text('収入').last);
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(const Key('recurringNameField')), '給与');
        await tester.tap(find.byKey(const Key('recurringAccountDropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('${accounts.first.name} (JPY)').last);
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('recurringAmountField')), '300000');
        await tester.tap(find.byKey(const Key('saveRecurringRule')));
        await tester.pumpAndSettle();

        final RecurringRuleRow saved = await db.select(db.recurringRules).getSingle();
        expect(saved.kind, 'income'); // persisted value is the untranslated enum name
      },
    );

    testWidgets(
      'CP6.7 (D): the frequency dropdown shows localized Japanese labels while the persisted '
      '`frequency` value stays the untranslated English enum name',
      (tester) async {
        useTallSurface(tester);
        final (AppDatabase db, _, List<AccountRow> accounts) = await seededDb();
        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRecurring(container, locale: const Locale('ja')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('addRecurringRuleFab')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('recurringFrequencyDropdown')));
        await tester.pumpAndSettle();
        expect(find.text('毎日'), findsOneWidget); // Daily
        expect(find.text('毎週'), findsOneWidget); // Weekly
        expect(find.text('毎年'), findsOneWidget); // Yearly
        await tester.tap(find.text('毎週').last);
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(const Key('recurringNameField')), 'サブスク');
        await tester.tap(find.byKey(const Key('recurringAccountDropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('${accounts.first.name} (JPY)').last);
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('recurringAmountField')), '1200');
        await tester.tap(find.byKey(const Key('saveRecurringRule')));
        await tester.pumpAndSettle();

        final RecurringRuleRow saved = await db.select(db.recurringRules).getSingle();
        expect(saved.frequency, 'weekly'); // persisted value is the untranslated enum name
      },
    );

    testWidgets(
      'CP6.7 (E): a 2-decimal MMK recurring amount renders its registry-defined precision '
      '(never 0) under the Japanese locale',
      (tester) async {
        useTallSurface(tester);
        final (AppDatabase db, String profileId, List<AccountRow> accounts) = await seededDb(
          accounts: const <_SeedAccount>[_SeedAccount(name: 'MMK Wallet', currencyCode: 'MMK')],
        );
        final DateTime todayUtc = DateTime.now().toUtc();
        final DateTime today = DateTime.utc(todayUtc.year, todayUtc.month, todayUtc.day);
        await RecurringRuleRepository(db, AccountRepository(db)).createRule(
          profileId: profileId,
          kind: RecurringRuleKind.expense,
          name: 'Utility',
          amount: Money.fromMinorUnits(500000, 'MMK'), // K5,000.00
          accountId: accounts.first.id,
          frequency: RecurrenceFrequency.monthly,
          interval: 1,
          startDate: today,
        );
        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRecurring(container, locale: const Locale('ja')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.textContaining('K5,000.00'), findsOneWidget);
      },
    );

    testWidgets(
      'CP6.7 (F): a large 0-decimal VND recurring amount renders intact under the Japanese '
      'locale',
      (tester) async {
        useTallSurface(tester);
        final (AppDatabase db, String profileId, List<AccountRow> accounts) = await seededDb(
          accounts: const <_SeedAccount>[_SeedAccount(name: 'VND Wallet', currencyCode: 'VND')],
        );
        final DateTime todayUtc = DateTime.now().toUtc();
        final DateTime today = DateTime.utc(todayUtc.year, todayUtc.month, todayUtc.day);
        await RecurringRuleRepository(db, AccountRepository(db)).createRule(
          profileId: profileId,
          kind: RecurringRuleKind.expense,
          name: 'Rent',
          amount: Money.fromMinorUnits(25000000, 'VND'), // ₫25,000,000 -- 0 decimals, never divided
          accountId: accounts.first.id,
          frequency: RecurrenceFrequency.monthly,
          interval: 1,
          startDate: today,
        );
        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRecurring(container, locale: const Locale('ja')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.textContaining('₫25,000,000'), findsOneWidget);
      },
    );

    testWidgets(
      'CP6.7 (G): a 3-decimal KWD recurring amount renders its registry-defined precision '
      'under the Japanese locale',
      (tester) async {
        useTallSurface(tester);
        final (AppDatabase db, String profileId, List<AccountRow> accounts) = await seededDb(
          accounts: const <_SeedAccount>[_SeedAccount(name: 'KWD Wallet', currencyCode: 'KWD')],
        );
        final DateTime todayUtc = DateTime.now().toUtc();
        final DateTime today = DateTime.utc(todayUtc.year, todayUtc.month, todayUtc.day);
        await RecurringRuleRepository(db, AccountRepository(db)).createRule(
          profileId: profileId,
          kind: RecurringRuleKind.expense,
          name: 'Rent',
          amount: Money.fromMinorUnits(12345678, 'KWD'), // د.ك12,345.678
          accountId: accounts.first.id,
          frequency: RecurrenceFrequency.monthly,
          interval: 1,
          startDate: today,
        );
        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRecurring(container, locale: const Locale('ja')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.textContaining('د.ك12,345.678'), findsOneWidget);
      },
    );

    testWidgets(
      'CP6.7 (H): the recurring list renders without overflow under the Japanese locale at a '
      '1.6x text scale',
      (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.view.physicalSize = const Size(400, 2000);
        tester.view.devicePixelRatio = 1.0;
        tester.platformDispatcher.textScaleFactorTestValue = 1.6;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        final (AppDatabase db, String profileId, List<AccountRow> accounts) = await seededDb();
        final DateTime todayUtc = DateTime.now().toUtc();
        await RecurringRuleRepository(db, AccountRepository(db)).createRule(
          profileId: profileId,
          kind: RecurringRuleKind.expense,
          name: '家賃',
          amount: Money.fromMinorUnits(80000, 'JPY'),
          accountId: accounts.first.id,
          frequency: RecurrenceFrequency.monthly,
          interval: 1,
          startDate: DateTime.utc(todayUtc.year, todayUtc.month, todayUtc.day),
        );
        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRecurring(container, locale: const Locale('ja')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('家賃'), findsOneWidget);
      },
    );

    testWidgets(
      'CP6.7 (I): the recurring list renders without overflow under the Japanese locale at an '
      'extreme 2.0x text scale',
      (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.view.physicalSize = const Size(400, 2000);
        tester.view.devicePixelRatio = 1.0;
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        final (AppDatabase db, String profileId, List<AccountRow> accounts) = await seededDb();
        final DateTime todayUtc = DateTime.now().toUtc();
        await RecurringRuleRepository(db, AccountRepository(db)).createRule(
          profileId: profileId,
          kind: RecurringRuleKind.expense,
          name: '家賃',
          amount: Money.fromMinorUnits(80000, 'JPY'),
          accountId: accounts.first.id,
          frequency: RecurrenceFrequency.monthly,
          interval: 1,
          startDate: DateTime.utc(todayUtc.year, todayUtc.month, todayUtc.day),
        );
        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRecurring(container, locale: const Locale('ja')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('家賃'), findsOneWidget);
      },
    );

    testWidgets(
      'CP6.7 (J): a long Japanese rule name and a 3-decimal KWD amount survive intact at a '
      'narrow 320px width and a 1.6x text scale',
      (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1.0;
        tester.platformDispatcher.textScaleFactorTestValue = 1.6;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        const String longName = '狭い画面のレイアウトを検証するための、かなり長い定期ルールの名前';
        final (AppDatabase db, String profileId, List<AccountRow> accounts) = await seededDb(
          accounts: const <_SeedAccount>[_SeedAccount(name: 'KWD Wallet', currencyCode: 'KWD')],
        );
        final DateTime todayUtc = DateTime.now().toUtc();
        final DateTime anchor = DateTime.utc(todayUtc.year, todayUtc.month, todayUtc.day);
        await RecurringRuleRepository(db, AccountRepository(db)).createRule(
          profileId: profileId,
          kind: RecurringRuleKind.expense,
          name: longName,
          amount: Money.fromMinorUnits(12345678, 'KWD'), // د.ك12,345.678
          accountId: accounts.first.id,
          frequency: RecurrenceFrequency.monthly,
          interval: 1,
          startDate: anchor,
        );

        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRecurring(container, locale: const Locale('ja')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text(longName), findsOneWidget);
        expect(find.textContaining('د.ك12,345.678'), findsOneWidget);
        expect(find.textContaining(DateFormat.yMMMd().format(anchor)), findsOneWidget);
      },
    );

    testWidgets(
      'CP6.7 (K): creating and then deleting a rule works end-to-end through the fully '
      'localized Japanese dialogs',
      (tester) async {
        useTallSurface(tester);
        final (AppDatabase db, _, List<AccountRow> accounts) = await seededDb();
        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRecurring(container, locale: const Locale('ja')));
        await tester.pumpAndSettle();

        // Create via the localized "new rule" dialog.
        await tester.tap(find.byKey(const Key('addRecurringRuleFab')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('recurringNameField')), '定期購読');
        await tester.tap(find.byKey(const Key('recurringAccountDropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('${accounts.first.name} (JPY)').last);
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('recurringAmountField')), '1500');
        await tester.tap(find.text('保存')); // Save
        await tester.pumpAndSettle();

        expect(find.text('新しい定期ルール'), findsNothing); // dialog closed
        expect(find.text('定期購読'), findsOneWidget);

        final RecurringRuleRow created = await db.select(db.recurringRules).getSingle();

        // Delete via the localized confirmation dialog.
        await tester.tap(find.byKey(Key('deleteRule_${created.id}')));
        await tester.pumpAndSettle();
        expect(find.text('この定期ルールを削除しますか？'), findsOneWidget);
        await tester.tap(find.widgetWithText(FilledButton, '削除')); // Delete
        await tester.pumpAndSettle();

        expect(find.textContaining('定期ルールがまだありません'), findsOneWidget);
        final RecurringRuleRow row = await (db.select(db.recurringRules)
              ..where((tbl) => tbl.id.equals(created.id)))
            .getSingle();
        expect(row.deletedAt, isNotNull); // soft-deleted, never hard-deleted
      },
    );
  });

  // ---------------------------------------------------------------------
  // Visual System Convergence Checkpoint 7.5: locks in the pending-item
  // card's new bordered visual treatment (`AppCard(bordered: true)`) via
  // the same shape/side/color contract `app_card_test.dart`/
  // `accounts_screen_test.dart` already assert for `AppCard` -- never a
  // pixel value. The card previously was a bare `Card()` with no such
  // contract at all -- this locks in the now-converged appearance.
  // ---------------------------------------------------------------------
  testWidgets(
    'CP7.5: a pending recurring item renders inside a bordered, near-white card matching the '
    'converged visual system',
    (tester) async {
      useTallSurface(tester);
      final (AppDatabase db, String profileId, List<AccountRow> accounts) = await seededDb();
      await RecurringRuleRepository(db, AccountRepository(db)).createRule(
        profileId: profileId,
        kind: RecurringRuleKind.expense,
        name: 'Rent',
        amount: Money.fromMinorUnits(80000, 'JPY'),
        accountId: accounts.first.id,
        destinationAccountId: null,
        categoryId: null,
        note: null,
        frequency: RecurrenceFrequency.monthly,
        interval: 1,
        startDate: DateTime.now().toUtc(),
        endDate: null,
        notificationsEnabled: false,
      );
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRecurring(container));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('sectionDueToday')), findsOneWidget);
      final Finder ruleNameFinder = find.text('Rent');
      final Card cardWidget = tester.widget<Card>(
        find.ancestor(of: ruleNameFinder, matching: find.byType(Card)).first,
      );
      final BuildContext context = tester.element(ruleNameFinder);
      final ColorScheme colors = Theme.of(context).colorScheme;
      final AppTokens tokens = context.appTokens;

      expect(cardWidget.color, colors.surface);
      expect(cardWidget.elevation, 0);
      final RoundedRectangleBorder shape = cardWidget.shape! as RoundedRectangleBorder;
      expect(shape.side.color, tokens.colors.subtleBorder);

      // The urgency label still renders as its own localized text --
      // `AppStatusChip` never reformats or drops the supplied label.
      // (Matches twice: once as the section header, once as the item's
      // own status chip -- both share the same localized string.)
      expect(find.text('Due today'), findsNWidgets(2));
    },
  );


  // ---------------------------------------------------------------------
  // Checkpoint 11 -- Recurring + Subscriptions V1: the Subscriptions tab
  // is a VIEW over the same recurring engine (see
  // `subscription_providers.dart`'s own doc comment), reached from this
  // same screen via a segmented control rather than a new bottom-nav
  // destination or a duplicate route. None of the tests above this
  // point ever select a tab, so they all continue to exercise the
  // Recurring tab exactly as before this checkpoint.
  // ---------------------------------------------------------------------
  testWidgets(
    'Checkpoint 11: tapping the Subscriptions segment switches tabs and hides the add-rule FAB',
    (tester) async {
      useTallSurface(tester);
      final (AppDatabase db, _, _) = await seededDb();
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRecurring(container));
      await tester.pumpAndSettle();

      // Default tab is Recurring -- identical to every test above.
      expect(find.byKey(const Key('addRecurringRuleFab')), findsOneWidget);
      expect(find.byKey(const Key('subscriptionsListView')), findsNothing);

      await tester.tap(find.text('Subscriptions'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('addRecurringRuleFab')), findsNothing);
      expect(find.byKey(const Key('subscriptionsListView')), findsOneWidget);

      // Switching back restores the Recurring tab's own FAB. Scoped to
      // the segmented control itself (`recurringTabSegmentedControl`,
      // already keyed in production) rather than a bare `find.text`,
      // since the AppBar's own title is also literally "Recurring" in
      // English -- an unscoped finder now matches both.
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('recurringTabSegmentedControl')),
          matching: find.text('Recurring'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('addRecurringRuleFab')), findsOneWidget);
      expect(find.byKey(const Key('subscriptionsListView')), findsNothing);
    },
  );

  testWidgets(
    'Checkpoint 11: the Subscriptions tab shows only expense-kind rules and their deterministic '
    'estimated totals',
    (tester) async {
      useTallSurface(tester);
      final (AppDatabase db, String profileId, List<AccountRow> accounts) = await seededDb();
      final RecurringRuleRepository ruleRepo = RecurringRuleRepository(db, AccountRepository(db));
      final DateTime todayUtc = DateTime.now().toUtc();
      final DateTime today = DateTime.utc(todayUtc.year, todayUtc.month, todayUtc.day);
      await ruleRepo.createRule(
        profileId: profileId,
        kind: RecurringRuleKind.expense,
        name: 'Netflix',
        amount: Money.fromMinorUnits(150000, 'JPY'),
        accountId: accounts.first.id,
        frequency: RecurrenceFrequency.monthly,
        interval: 1,
        startDate: today,
      );
      await ruleRepo.createRule(
        profileId: profileId,
        kind: RecurringRuleKind.income,
        name: 'Salary',
        amount: Money.fromMinorUnits(3000000, 'JPY'),
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

      await tester.tap(find.text('Subscriptions'));
      await tester.pumpAndSettle();

      expect(find.text('Netflix'), findsOneWidget);
      expect(find.text('Salary'), findsNothing); // income rule never shown as a subscription

      expect(find.byKey(const Key('subscriptionTotalsCard')), findsOneWidget);
      expect(find.byKey(const Key('subscriptionTotal_JPY')), findsOneWidget);
      // Interval-1 monthly expense: the estimated monthly total equals
      // the rule's own amount exactly -- shown once on the row itself
      // and once in the totals header.
      expect(find.textContaining('\u00a5150,000'), findsNWidgets(2));
      // Estimated yearly total = amount * 12, shown only in the header.
      expect(find.textContaining('\u00a51,800,000'), findsOneWidget);
    },
  );

  testWidgets(
    'Checkpoint 11: the Subscriptions tab shows an empty-state message when there are no active '
    'subscriptions',
    (tester) async {
      final (AppDatabase db, _, _) = await seededDb();
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRecurring(container));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Subscriptions'));
      await tester.pumpAndSettle();

      expect(find.textContaining('No active subscriptions yet'), findsOneWidget);
      expect(find.byKey(const Key('subscriptionTotalsCard')), findsNothing);
    },
  );

  testWidgets(
    'Checkpoint 11: subscriptions in different currencies show separate totals blocks, never a '
    'combined figure',
    (tester) async {
      useTallSurface(tester);
      final (AppDatabase db, String profileId, List<AccountRow> accounts) = await seededDb(
        accounts: const <_SeedAccount>[
          _SeedAccount(name: 'JPY Wallet', currencyCode: 'JPY'),
          _SeedAccount(name: 'KWD Wallet', currencyCode: 'KWD'),
        ],
      );
      final RecurringRuleRepository ruleRepo = RecurringRuleRepository(db, AccountRepository(db));
      final DateTime todayUtc = DateTime.now().toUtc();
      final DateTime today = DateTime.utc(todayUtc.year, todayUtc.month, todayUtc.day);
      await ruleRepo.createRule(
        profileId: profileId,
        kind: RecurringRuleKind.expense,
        name: 'Netflix',
        amount: Money.fromMinorUnits(150000, 'JPY'),
        accountId: accounts[0].id,
        frequency: RecurrenceFrequency.monthly,
        interval: 1,
        startDate: today,
      );
      await ruleRepo.createRule(
        profileId: profileId,
        kind: RecurringRuleKind.expense,
        name: 'Gym',
        amount: Money.fromMinorUnits(12345, 'KWD'), // د.ك12.345
        accountId: accounts[1].id,
        frequency: RecurrenceFrequency.monthly,
        interval: 1,
        startDate: today,
      );

      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRecurring(container));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Subscriptions'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('subscriptionTotal_JPY')), findsOneWidget);
      expect(find.byKey(const Key('subscriptionTotal_KWD')), findsOneWidget);
      expect(find.textContaining('\u00a5150,000'), findsWidgets);
      expect(find.textContaining('\u062F.\u064312.345'), findsWidgets);
    },
  );

  testWidgets(
    'Checkpoint 11: the Subscriptions tab and its totals labels render in Japanese',
    (tester) async {
      useTallSurface(tester);
      final (AppDatabase db, String profileId, List<AccountRow> accounts) = await seededDb();
      final DateTime todayUtc = DateTime.now().toUtc();
      final DateTime today = DateTime.utc(todayUtc.year, todayUtc.month, todayUtc.day);
      await RecurringRuleRepository(db, AccountRepository(db)).createRule(
        profileId: profileId,
        kind: RecurringRuleKind.expense,
        name: 'Netflix',
        amount: Money.fromMinorUnits(150000, 'JPY'),
        accountId: accounts.first.id,
        frequency: RecurrenceFrequency.monthly,
        interval: 1,
        startDate: today,
      );
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRecurring(container, locale: const Locale('ja')));
      await tester.pumpAndSettle();

      expect(find.text('\u30b5\u30d6\u30b9\u30af\u30ea\u30d7\u30b7\u30e7\u30f3'), findsOneWidget);

      await tester.tap(find.text('\u30b5\u30d6\u30b9\u30af\u30ea\u30d7\u30b7\u30e7\u30f3'));
      await tester.pumpAndSettle();

      expect(find.text('\u63a8\u5b9a\u6708\u984d'), findsOneWidget);
      expect(find.text('\u63a8\u5b9a\u5e74\u984d'), findsOneWidget);
      expect(find.text('Netflix'), findsOneWidget);
    },
  );

  testWidgets(
    'Checkpoint 11: the Subscriptions tab renders without overflow at a narrow width and a 1.6x '
    'text scale',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final (AppDatabase db, String profileId, List<AccountRow> accounts) = await seededDb(
        accounts: const <_SeedAccount>[_SeedAccount(name: 'KWD Wallet', currencyCode: 'KWD')],
      );
      final DateTime todayUtc = DateTime.now().toUtc();
      final DateTime anchor = DateTime.utc(todayUtc.year, todayUtc.month, todayUtc.day);
      await RecurringRuleRepository(db, AccountRepository(db)).createRule(
        profileId: profileId,
        kind: RecurringRuleKind.expense,
        name: 'A rather long subscription name to stress narrow-width layout',
        amount: Money.fromMinorUnits(12345678, 'KWD'),
        accountId: accounts.first.id,
        frequency: RecurrenceFrequency.monthly,
        interval: 1,
        startDate: anchor,
      );

      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRecurring(container));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Subscriptions'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('\u062F.\u064312,345.678'), findsWidgets);
    },
  );

  testWidgets(
    'Checkpoint 11 FINAL FIX: handling a subscription\'s only Upcoming occurrence early still '
    'leaves the later occurrence visible, and the Subscriptions tab never shows the '
    'contradictory empty state while that subscription still contributes to its totals '
    '-- regression for the Android QA subscription-state-inconsistency investigation',
    (tester) async {
      useTallSurface(tester);
      final (AppDatabase db, String profileId, List<AccountRow> accounts) = await seededDb();
      final DateTime todayUtc = DateTime.now().toUtc();
      final DateTime today = DateTime.utc(todayUtc.year, todayUtc.month, todayUtc.day);
      final DateTime nearestUpcoming = today.add(const Duration(days: 1));
      final String ruleId = await RecurringRuleRepository(db, AccountRepository(db)).createRule(
        profileId: profileId,
        kind: RecurringRuleKind.expense,
        name: 'Netflix',
        amount: Money.fromMinorUnits(150000, 'JPY'),
        accountId: accounts.first.id,
        frequency: RecurrenceFrequency.monthly,
        interval: 1,
        startDate: nearestUpcoming, // starts tomorrow -- nothing due/overdue yet
      );
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRecurring(container));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Subscriptions'));
      await tester.pumpAndSettle();

      // Before handling anything: the subscription's one Upcoming
      // occurrence is visible, its totals are shown, and there is no
      // empty state.
      expect(find.text('Netflix'), findsOneWidget);
      expect(find.byKey(const Key('subscriptionTotalsCard')), findsOneWidget);
      expect(find.byKey(const Key('subscriptionTotal_JPY')), findsOneWidget);
      expect(find.textContaining('No active subscriptions yet'), findsNothing);
      final Finder skipButton = find.byWidgetPredicate(
        (Widget w) => w is OutlinedButton && (w.key as ValueKey<String>?)?.value.startsWith(
              'skipOccurrence_$ruleId',
            ) == true,
      );
      expect(skipButton, findsOneWidget);

      // Handle that single Upcoming occurrence EARLY, via the same
      // Skip button that already exists and is never disabled for an
      // `upcoming`-urgency item -- exactly how the Android QA report
      // reproduced this by ordinary tapping, not a special code path.
      await tester.tap(skipButton);
      await tester.pumpAndSettle();

      // The rule is still active and still has a real future
      // occurrence, so it must NOT disappear from the Subscriptions
      // tab, and the totals card (driven independently by
      // `computeSubscriptionEstimatedTotals`, which has no such
      // blind spot) must still show its figure -- this is the exact
      // "totals shown + No active subscriptions yet" contradiction the
      // investigation reported, and it must not reproduce here anymore.
      expect(find.textContaining('No active subscriptions yet'), findsNothing);
      expect(find.byKey(const Key('subscriptionTotalsCard')), findsOneWidget);
      expect(find.byKey(const Key('subscriptionTotal_JPY')), findsOneWidget);

      // The later, still-unhandled occurrence is what now surfaces --
      // computed by the same production `RecurringSchedule`, never a
      // hand-derived date.
      final DateTime laterOccurrence = RecurringSchedule(
        frequency: RecurrenceFrequency.monthly,
        interval: 1,
        startDateUtc: nearestUpcoming,
      ).nextOccurrenceAfter(nearestUpcoming)!;
      expect(laterOccurrence.isAfter(nearestUpcoming), isTrue); // a genuinely later date
      expect(find.text('Netflix'), findsOneWidget); // the later occurrence's own row
      expect(
        find.byKey(Key('skipOccurrence_${ruleId}_${laterOccurrence.toIso8601String()}')),
        findsOneWidget,
      );
      // The handled date's own row/button is gone.
      expect(
        find.byKey(Key('skipOccurrence_${ruleId}_${nearestUpcoming.toIso8601String()}')),
        findsNothing,
      );

      // The occurrence really was skipped (no transaction created) --
      // a raw table read, independent of the provider/UI under test.
      final List<RecurringOccurrenceRow> occurrences =
          await db.select(db.recurringOccurrences).get();
      expect(occurrences, hasLength(1));
      expect(occurrences.single.status, 'skipped');
      expect(occurrences.single.scheduledDate.toUtc(), nearestUpcoming);
      final List<Transaction> transactions = await db.select(db.transactions).get();
      expect(transactions, isEmpty);
    },
  );
}
