import 'dart:io';

import 'package:ai_financial_coach/shared/theme/app_theme.dart';
import 'package:flutter/semantics.dart';
import 'package:ai_financial_coach/core/database/repositories/category_repository.dart';
import 'package:ai_financial_coach/features/categories/presentation/category_identity_icon.dart';
import 'package:ai_financial_coach/features/services/presentation/service_icon_asset.dart';
import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/providers.dart';
import 'package:ai_financial_coach/core/database/repositories/account_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/recurring_rule_repository.dart';
import 'package:ai_financial_coach/core/money/money.dart';
import 'package:ai_financial_coach/core/routing/app_routes.dart';
import 'package:ai_financial_coach/core/notifications/notification_providers.dart';
import 'package:ai_financial_coach/core/notifications/notification_scheduler.dart';
import 'package:intl/intl.dart';
import 'package:ai_financial_coach/features/recurring/domain/recurrence_frequency.dart';
import 'package:ai_financial_coach/features/recurring/domain/recurring_rule_kind.dart';
import 'package:ai_financial_coach/features/recurring/domain/recurring_schedule.dart';
import 'package:ai_financial_coach/features/recurring/presentation/recurring_history_screen.dart';
import 'package:ai_financial_coach/features/recurring/presentation/recurring_icon_asset.dart';
import 'package:ai_financial_coach/features/recurring/presentation/recurring_screen.dart';
import 'package:ai_financial_coach/l10n/generated/app_localizations.dart';
import 'package:ai_financial_coach/shared/theme/app_tokens.dart';
import 'package:ai_financial_coach/shared/widgets/app_card.dart';
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../support/fake_notification_scheduler.dart';

// NOTE: exercises generated Drift code — see CLAUDE_FIRST_CODING_PROMPT.md.
//
// Beta 1 Task 4A originally; rewritten for the Recurring UX checkpoint's
// full screen redesign (Checkpoint R2, `docs/14_DECISION_LOG.md` ADR-TBD).
// The screen's old Overdue/Due today/Upcoming sections and its
// Recurring/Subscriptions tab split are both retired -- this file no
// longer asserts against `sectionOverdue`/`sectionDueToday`/
// `sectionUpcoming`, `addRecurringRuleFab`, `editRule_`/`deleteRule_`,
// `subscriptionsListView`, `subscriptionTotalsCard`/`subscriptionTotal_`,
// or the "Subscriptions" tab-switch gesture, none of which exist in the
// redesigned screen. It covers: the create/edit/delete dialog flows
// (unchanged), posting/skipping a due occurrence, the reused per-currency
// estimate card (now always inline, never behind a tab), the new
// All/Active/Upcoming/Expired filter bar, the search box, the swipe-reveal
// Edit/Delete panel and its one-row-open-at-a-time rule, the overflow-menu
// accessibility fallback for the exact same two actions, the empty state,
// and the narrow-width/text-scale/Japanese-locale regressions the prior
// checkpoints already locked in. Deterministic scheduling itself has its
// own dedicated coverage in
// `test/features/recurring/domain/recurring_schedule_test.dart`, and the
// new per-rule summary/filter/search selectors have their own dedicated
// pure-function coverage in
// `test/features/recurring/presentation/recurring_rule_summary_test.dart`
// -- nothing here re-checks recurrence math or re-derives those selectors'
// own logic; this file only exercises the widget wiring on top of them.

class _SeedAccount {
  const _SeedAccount({required this.name, required this.currencyCode});
  final String name;
  final String currencyCode;
}

Future<void> invokeRuleAction(WidgetTester tester, String id, String label) async {
  final handle = tester.ensureSemantics();
  try {
    await tester.pump();
    final node = tester.getSemantics(find.byKey(Key('ruleSemanticActions_$id')));
    final actionIds = node.getSemanticsData().customSemanticsActionIds!;
    final actionId = actionIds.singleWhere((id) => CustomSemanticsAction.getAction(id)!.label == label);
    node.owner!.performAction(node.id, SemanticsAction.customAction, actionId);
    await tester.pumpAndSettle();
  } finally {
    handle.dispose();
  }
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
    ThemeData? theme,
  }) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: locale,
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const RecurringScreen(),
      ),
    );
  }

  /// Recurring History Final Corrections checkpoint: a real `GoRouter`
  /// harness, needed because this checkpoint makes both the summary
  /// card AND a closed row's own foreground content actually call
  /// `context.push` -- `appWithRecurring`'s plain `MaterialApp(home:
  /// ...)` (no `GoRouter` ancestor) is enough for every test that only
  /// checks a callback is non-null or exercises Edit/Delete (which use
  /// `showDialog`/`Navigator`, not `GoRouter`), but a test that
  /// actually performs one of these taps and expects real navigation
  /// needs this instead -- same precedent
  /// `account_detail_screen_test.dart`'s own `appWithRouter` already
  /// established for `AccountDetailScreen`'s Edit action. Registers
  /// exactly the three routes `app_router.dart` itself registers for
  /// this feature (`recurring`, `recurringHistory`,
  /// `recurringRuleHistoryPath`), nothing more.
  Widget appWithRecurringRouter(
    ProviderContainer container, {
    Locale locale = const Locale('en'),
  }) {
    final GoRouter router = GoRouter(
      initialLocation: AppRoutes.recurring,
      routes: <RouteBase>[
        GoRoute(path: AppRoutes.recurring, builder: (context, state) => const RecurringScreen()),
        GoRoute(
          path: AppRoutes.recurringHistory,
          builder: (context, state) => const RecurringHistoryScreen(),
        ),
        GoRoute(
          path: AppRoutes.recurringRuleHistoryPath,
          builder: (context, state) =>
              RecurringHistoryScreen(ruleId: state.pathParameters['ruleId']!),
        ),
      ],
    );
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }

  /// Same deterministic shutdown sequence every other widget test file in
  /// this project uses -- see the identical comment this replaced for the
  /// full history of why: `seededDb()` opens the test database with
  /// `closeStreamsSynchronously: true`, which removes the `Timer.run()`
  /// Drift's `StreamQueryStore.markAsClosed` would otherwise schedule, so
  /// this screen (with its several concurrent `QueryStream`s: the rule
  /// summaries, the estimate totals, the create/edit dialog's own
  /// accounts/categories streams) can unwind deterministically with no
  /// special-cased pump count.
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

  /// Drags rule [ruleId]'s row card (keyed `pendingItem_${ruleId}_
  /// $dateKey`, same key the row's own `AppCard` always carries -- see
  /// `_RecurringRuleRow.build`) by [dx] and settles the 180ms reveal
  /// animation. Positive [dx] (left-to-right) reveals Edit on the left;
  /// negative [dx] (right-to-left) reveals Delete on the right -- see
  /// `_SwipeRevealRowState`'s own doc comment for the full two-directional
  /// contract. A drag past half of `_SwipeRevealRow.revealWidth` (144)
  /// always counts as "open" per `_SwipeRevealRowState._onDragEnd`, so
  /// +-200 (clamped internally to +-144) is comfortably past that
  /// threshold.
  Future<void> dragReveal(WidgetTester tester, String ruleId, String dateKey, double dx) async {
    await tester.drag(find.byKey(Key('pendingItem_${ruleId}_$dateKey')), Offset(dx, 0));
    await tester.pumpAndSettle();
  }

  /// Finds rule [ruleId]'s row card by id alone, matching the
  /// `pendingItem_${ruleId}_` PREFIX of its `AppCard` key rather than
  /// reconstructing the exact trailing date-key string. A test has no
  /// reliable way to independently predict that trailing value (it is
  /// whatever `RecurringPendingItem.scheduledDateUtc` the production
  /// pending-items computation resolved to for this rule), so matching
  /// on the id-scoped prefix finds the actual rendered row directly,
  /// with zero assumptions about its date suffix.
  Finder ruleRowFinder(String ruleId) {
    return find.byWidgetPredicate((Widget widget) {
      final Key? key = widget.key;
      return key is ValueKey<String> && key.value.startsWith('pendingItem_${ruleId}_');
    });
  }

  // Assert both actual hit testing and foreground displacement without tapping
  // hidden controls (a tap there can legitimately close the currently open row).
  void expectRevealState(WidgetTester tester, String ruleId, int side) {
    final edit = find.byKey(Key('recurringEditAction_$ruleId'));
    final delete = find.byKey(Key('recurringDeleteAction_$ruleId'));
    expect(edit, findsOneWidget);
    expect(delete, findsOneWidget);
    expect(edit.hitTestable(), side == 1 ? findsOneWidget : findsNothing);
    expect(delete.hitTestable(), side == -1 ? findsOneWidget : findsNothing);
    final clippedRow = find.ancestor(of: edit, matching: find.byType(ClipRRect));
    expect(clippedRow, findsOneWidget);
    final displacement = tester.getRect(ruleRowFinder(ruleId)).left - tester.getRect(clippedRow).left;
    expect(displacement, closeTo(side * tester.getSize(edit).width, 0.01));
  }
  /// Same contract as [dragReveal] but located by [ruleRowFinder]
  /// instead of a caller-supplied `dateKey`. Asserts the finder
  /// resolves to exactly one widget first, so a fixture problem (the
  /// row not existing, or an unexpectedly duplicated key) fails with
  /// an explicit, readable `findsOneWidget` mismatch here rather than
  /// surfacing later as a confusing "could not find any matching
  /// widgets" error from `tester.drag` itself.
  Future<void> dragRevealByRuleId(WidgetTester tester, String ruleId, double dx) async {
    expect(ruleRowFinder(ruleId), findsOneWidget);
    await tester.drag(ruleRowFinder(ruleId), Offset(dx, 0));
    await tester.pumpAndSettle();
  }

  /// Reveals rule [ruleId]'s Edit panel (drag left-to-right).
  Future<void> openEditReveal(WidgetTester tester, String ruleId, String dateKey) =>
      dragReveal(tester, ruleId, dateKey, 200);

  /// Reveals rule [ruleId]'s Delete panel (drag right-to-left) -- the
  /// same gesture the single-direction `openSwipeReveal` used to perform
  /// before the two-directional redesign.
  Future<void> openDeleteReveal(WidgetTester tester, String ruleId, String dateKey) =>
      dragReveal(tester, ruleId, dateKey, -200);

  testWidgets(
    'the empty state is shown when there are no recurring rules yet, under the default (All) '
    'filter',
    (tester) async {
      final (AppDatabase db, _, _) = await seededDb();
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRecurring(container));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('recurringEmptyMessage')), findsOneWidget);
      expect(find.textContaining('No recurring rules yet'), findsOneWidget);
      // Nothing to estimate yet -- the card never renders with zero
      // active expense rules (see `_RecurringRuleListBodyState.build`'s
      // `if (totals.isNotEmpty)` guard).
      expect(find.byKey(const Key('recurringEstimateSummaryCard')), findsNothing);
    },
  );

  testWidgets(
    'creating a monthly expense rule anchored today shows it with a "Due today" badge',
    (tester) async {
      useTallSurface(tester);
      final (AppDatabase db, _, List<AccountRow> accounts) = await seededDb();
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRecurring(container));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('addRecurringRuleAction')));
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
      expect(find.text('Rent'), findsOneWidget);
      // findsNWidgets(2): the row's own amount AND the estimate card's
      // monthly total coincide, since this is a single active
      // monthly-interval-1 expense rule (its monthly estimate equals
      // its own amount exactly).
      expect(find.textContaining('¥80,000'), findsNWidgets(2));
      expect(find.text('Due today'), findsOneWidget); // the row's own urgency chip
    },
  );

  testWidgets(
    'two rapid submit attempts when creating a recurring rule create only one rule, not two',
    (tester) async {
      useTallSurface(tester);
      final (AppDatabase db, _, List<AccountRow> accounts) = await seededDb();
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRecurring(container));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('addRecurringRuleAction')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('recurringNameField')), 'Rent');
      await tester.tap(find.byKey(const Key('recurringAccountDropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('${accounts.first.name} (JPY)').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('recurringAmountField')), '80000');

      // NOT two physical `tester.tap()` calls -- see
      // `recurring_providers.dart`'s ADR-043 precedent this reuses: a
      // physical tap's own internal gesture-dispatch `await`s let the
      // first tap's `_submit()` run to completion and pop this dialog
      // before the second tap's hit-test ever runs, which would make
      // "only one rule created" true for an uninteresting reason. Two
      // back-to-back synchronous `onPressed!()` invocations with no
      // `await` between them deterministically fire `_submit()` twice
      // before either call's `await createRule(...)` can resolve.
      final FilledButton saveButton =
          tester.widget<FilledButton>(find.byKey(const Key('saveRecurringRule')));
      saveButton.onPressed!();
      saveButton.onPressed!();
      await tester.pumpAndSettle();

      expect(find.text('New recurring rule'), findsNothing); // dialog closed
      final List<RecurringRuleRow> rules = await db.select(db.recurringRules).get();
      expect(rules, hasLength(1)); // not 2
      expect(rules.single.name, 'Rent');
    },
  );

  // Manual Android testing found: a JPY -> USD recurring transfer reached
  // Save, the repository correctly threw `CurrencyMismatchException`
  // (see `recurring_rule_repository_test.dart`'s 'rejects a
  // cross-currency transfer' test -- untouched by this change), but
  // `_submit` had no handler for it, so Save appeared unresponsive. These
  // four tests cover the UI-only fix: filtering the destination dropdown
  // to same-currency, non-source accounts; clearing an incompatible
  // destination when the source changes; disabling Save with a helper
  // message when no eligible destination exists; and that a valid
  // same-currency transfer still saves cleanly.
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

      await tester.tap(find.byKey(const Key('addRecurringRuleAction')));
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

      await tester.tap(find.byKey(const Key('addRecurringRuleAction')));
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

      await tester.tap(find.byKey(const Key('addRecurringRuleAction')));
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

      expect(
        tester
            .widget<DropdownButtonFormField<String>>(
              find.byKey(const Key('recurringDestinationAccountDropdown')),
            )
            .initialValue,
        isNotNull,
      );

      await tester.tap(find.byKey(const Key('recurringAccountDropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('USD A (USD)').last);
      await tester.pumpAndSettle();

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

      await tester.tap(find.byKey(const Key('addRecurringRuleAction')));
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
    'surfaces the rule\'s next real occurrence',
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
      expect(find.text('Due today'), findsOneWidget);
      final Finder postButton = find.byWidgetPredicate(
        (Widget w) => w is FilledButton && (w.key as ValueKey<String>?)?.value.startsWith(
              'postOccurrence_$ruleId',
            ) == true,
      );
      expect(postButton, findsOneWidget);
      await tester.tap(postButton);
      await tester.pumpAndSettle();

      // Today's occurrence is handled -- its own post button (keyed by
      // today's date) is gone, and the "Due today" chip no longer
      // applies to this rule. The rule itself stays active, so its next
      // legitimate occurrence (computed by the same `RecurringSchedule`
      // production uses, not a hand-derived date) now surfaces as this
      // one row's new, later next-date -- never the same handled date.
      expect(
        find.byKey(Key('postOccurrence_${ruleId}_${today.toIso8601String()}')),
        findsNothing,
      );
      expect(find.text('Due today'), findsNothing);

      final DateTime nextOccurrence = RecurringSchedule(
        frequency: RecurrenceFrequency.monthly,
        interval: 1,
        startDateUtc: today,
      ).nextOccurrenceAfter(today)!;
      expect(nextOccurrence.isAfter(today), isTrue); // a genuinely later date
      expect(find.text('Rent'), findsOneWidget); // still exactly one row for this rule
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
      // `_withUtcDateTimes`): drift's default (non-text) DateTime storage
      // always returns a local-tagged value, and `DateTime.==` requires
      // both the same moment AND the same zone tag -- `.toUtc()` only
      // re-tags this read value for the comparison below; it never
      // touches storage or moves the instant.
      expect(occurrences.single.scheduledDate.toUtc(), today);
      expect(occurrences.single.transactionId, isNotNull);

      final List<Transaction> transactions = await db.select(db.transactions).get();
      expect(transactions, hasLength(1));
      expect(transactions.single.id, occurrences.single.transactionId);
      expect(transactions.single.type, 'expense');
    },
  );

  testWidgets(
    'two rapid post attempts for the same occurrence create only one transaction, not two',
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

      final Finder postButtonFinder = find.byWidgetPredicate(
        (Widget w) =>
            w is FilledButton &&
            (w.key as ValueKey<String>?)?.value.startsWith('postOccurrence_$ruleId') == true,
      );
      final FilledButton postButton = tester.widget<FilledButton>(postButtonFinder);
      postButton.onPressed!();
      postButton.onPressed!();
      await tester.pumpAndSettle();

      final List<Transaction> transactions = await db.select(db.transactions).get();
      expect(transactions, hasLength(1)); // not 2
      final List<RecurringOccurrenceRow> occurrences =
          await db.select(db.recurringOccurrences).get();
      expect(occurrences, hasLength(1));
      expect(occurrences.single.status, 'posted');
      expect(find.byType(SnackBar), findsNothing); // no error snackbar from a rejected second post
    },
  );

  testWidgets(
    'skipping a due occurrence creates no transaction and surfaces the rule\'s next real '
    'occurrence',
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

      expect(
        find.byKey(Key('skipOccurrence_${ruleId}_${today.toIso8601String()}')),
        findsNothing,
      );
      expect(find.text('Due today'), findsNothing);

      final DateTime nextOccurrence = RecurringSchedule(
        frequency: RecurrenceFrequency.monthly,
        interval: 1,
        startDateUtc: today,
      ).nextOccurrenceAfter(today)!;
      expect(nextOccurrence.isAfter(today), isTrue); // a genuinely later date
      expect(find.text('Salary'), findsOneWidget); // still exactly one row for this rule
      expect(
        find.byKey(Key('skipOccurrence_${ruleId}_${nextOccurrence.toIso8601String()}')),
        findsOneWidget,
      );

      final List<RecurringOccurrenceRow> occurrences =
          await db.select(db.recurringOccurrences).get();
      expect(occurrences, hasLength(1));
      expect(occurrences.single.status, 'skipped');
      expect(occurrences.single.scheduledDate.toUtc(), today);
      expect(occurrences.single.transactionId, isNull);

      final List<Transaction> transactions = await db.select(db.transactions).get();
      expect(transactions, isEmpty);
    },
  );

  testWidgets(
    'editing a rule via the semantic actions renders its new name without touching its '
    'schedule',
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

      await invokeRuleAction(tester, ruleId, 'Edit');
      await tester.pumpAndSettle();
      expect(find.text('Edit recurring rule'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('recurringNameField')), 'Apartment Rent');
      await tester.tap(find.byKey(const Key('saveRecurringRule')));
      await tester.pumpAndSettle();

      expect(find.text('Edit recurring rule'), findsNothing);
      expect(find.text('Apartment Rent'), findsOneWidget);
      expect(find.text('Rent'), findsNothing);
    },
  );

  testWidgets(
    'deleting a rule via the semantic actions (soft delete) removes it from the list but '
    'keeps the rule row itself',
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

      await invokeRuleAction(tester, ruleId, 'Delete');
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
    'editing a rule via its swipe-reveal panel opens the exact same edit dialog as the overflow '
    'menu',
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

      await openEditReveal(tester, ruleId, today.toIso8601String());

      await tester.tap(
        find.descendant(
          of: find.byKey(Key('recurringRuleRow_$ruleId')),
          matching: find.text('Edit'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit recurring rule'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('recurringNameField')), 'Apartment Rent');
      await tester.tap(find.byKey(const Key('saveRecurringRule')));
      await tester.pumpAndSettle();

      expect(find.text('Apartment Rent'), findsOneWidget);
    },
  );

  testWidgets(
    'deleting a rule via its swipe-reveal panel opens the exact same confirm dialog as the '
    'overflow menu',
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

      await openDeleteReveal(tester, ruleId, today.toIso8601String());

      await tester.tap(
        find.descendant(
          of: find.byKey(Key('recurringRuleRow_$ruleId')),
          matching: find.text('Delete'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Delete this recurring rule?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.textContaining('No recurring rules yet'), findsOneWidget);
      final RecurringRuleRow row = await (db.select(db.recurringRules)
            ..where((tbl) => tbl.id.equals(ruleId)))
          .getSingle();
      expect(row.deletedAt, isNotNull);
    },
  );

  testWidgets(
    'opening one row\'s swipe-reveal panel closes any other row that was already open',
    (tester) async {
      useTallSurface(tester);
      final (AppDatabase db, String profileId, List<AccountRow> accounts) = await seededDb();
      final DateTime todayUtc = DateTime.now().toUtc();
      final DateTime today = DateTime.utc(todayUtc.year, todayUtc.month, todayUtc.day);
      final RecurringRuleRepository ruleRepo = RecurringRuleRepository(db, AccountRepository(db));
      final String ruleId1 = await ruleRepo.createRule(
        profileId: profileId,
        kind: RecurringRuleKind.expense,
        name: 'Rent',
        amount: Money.fromMinorUnits(80000, 'JPY'),
        accountId: accounts.first.id,
        frequency: RecurrenceFrequency.monthly,
        interval: 1,
        startDate: today,
      );
      final String ruleId2 = await ruleRepo.createRule(
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

      expect(ruleRowFinder(ruleId1), findsOneWidget);
      expect(ruleRowFinder(ruleId2), findsOneWidget);
      expectRevealState(tester, ruleId1, 0);
      expectRevealState(tester, ruleId2, 0);

      await dragRevealByRuleId(tester, ruleId1, 200);
      expectRevealState(tester, ruleId1, 1);
      expectRevealState(tester, ruleId2, 0);

      await dragRevealByRuleId(tester, ruleId2, 200);
      expectRevealState(tester, ruleId1, 0);
      expectRevealState(tester, ruleId2, 1);
      expect(find.text('Edit recurring rule'), findsNothing);
    },
  );

  // Recurring UX checkpoint (closed-state swipe fix + two-directional
  // redesign): the nine properties explicitly required of the rebuilt
  // `_SwipeRevealRow`. Each creates its own single rule (plus a second
  // rule where the behavior under test genuinely needs another row) so
  // failures are independently diagnosable.

  testWidgets(
    'a closed row has zero exposed Edit/Delete action surface -- tapping where either '
    'action sits lands on the foreground instead, which opens history, never Edit/Delete',
    (tester) async {
      // Recurring History Final Corrections checkpoint: this test's
      // own title/behavior shifted -- a closed row's foreground tap
      // used to be an intentional no-op (see this file's git history);
      // it now deliberately opens that rule's own history (Case 2),
      // per that checkpoint's explicit requirement. What this test
      // still exists to prove is unchanged: tapping at either hidden
      // action's nominal location NEVER fires Edit or Delete while
      // closed (they stay `IgnorePointer`-wrapped, exactly as always)
      // -- it only ever reaches the ordinary foreground underneath,
      // whatever that foreground now does. Needs the real-`GoRouter`
      // harness (`appWithRecurringRouter`) since that foreground tap
      // now performs a real `context.push`.
      useTallSurface(tester);
      final (AppDatabase db, String profileId, List<AccountRow> accounts) = await seededDb();
      final DateTime todayUtc = DateTime.now().toUtc();
      final DateTime today = DateTime.utc(todayUtc.year, todayUtc.month, todayUtc.day);
      // The rule's id is never referenced below -- this test identifies
      // its one row by label ('Rent'/'Edit'), never by key -- so the
      // created rule's side effect (a row existing to tap against) is
      // all this needs; binding its id would be unused.
      await RecurringRuleRepository(db, AccountRepository(db)).createRule(
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

      await tester.pumpWidget(appWithRecurringRouter(container));
      await tester.pumpAndSettle();

      // No drag performed -- the row is closed (`_dragExtent == 0`). A
      // tap at the Edit action's nominal location must miss it (it is
      // `IgnorePointer`-wrapped) and land on the foreground instead, so
      // `warnIfMissed: false` is the expected, correct outcome here,
      // not a hidden bug.
      await tester.tap(find.text('Edit'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('Edit recurring rule'), findsNothing);
      expect(find.text('Delete this recurring rule?'), findsNothing);
      // The foreground tap landed instead -- this rule's own history
      // screen, never Edit/Delete.
      expect(find.byType(RecurringHistoryScreen), findsOneWidget);
      expect(find.text('Rent history'), findsOneWidget);
    },
  );

  testWidgets(
    'dragging left-to-right reveals Edit only -- Delete is never reachable while Edit is open',
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

      await openEditReveal(tester, ruleId, today.toIso8601String());

      // Edit is reachable.
      await tester.tap(
        find.descendant(of: find.byKey(Key('recurringRuleRow_$ruleId')), matching: find.text('Edit')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Edit recurring rule'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Re-open Edit; Delete is not reachable from the same (Edit-open)
      // state -- the tap misses Delete's `IgnorePointer`-wrapped panel
      // and lands on the foreground instead.
      await openEditReveal(tester, ruleId, today.toIso8601String());
      await tester.tap(find.text('Delete'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('Delete this recurring rule?'), findsNothing);
    },
  );

  testWidgets(
    'dragging right-to-left reveals Delete only -- Edit is never reachable while Delete is open',
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

      await openDeleteReveal(tester, ruleId, today.toIso8601String());

      // Delete is reachable.
      await tester.tap(
        find.descendant(of: find.byKey(Key('recurringRuleRow_$ruleId')), matching: find.text('Delete')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Delete this recurring rule?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Re-open Delete; Edit is not reachable from the same
      // (Delete-open) state.
      await openDeleteReveal(tester, ruleId, today.toIso8601String());
      await tester.tap(find.text('Edit'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('Edit recurring rule'), findsNothing);
    },
  );

  testWidgets(
    'an incomplete swipe (less than half the reveal width) snaps fully closed',
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

      // Located by rule id alone (`ruleRowFinder`), not by
      // reconstructing `today`'s exact `toIso8601String()` suffix --
      // see that helper's doc comment for why a test cannot reliably
      // predict that trailing value independently of what the widget
      // tree's own pending-items computation actually resolved to.
      //
      // 40px is well under half of `_SwipeRevealRow.revealWidth` (144 / 2
      // = 72), on either side -- both must snap back to fully closed.
      //
      // Recurring History Final Corrections checkpoint: verified
      // directly via [expectRevealState] (hit-testability + foreground
      // displacement), never by tapping 'Edit'/'Delete' and checking no
      // dialog opened -- a closed row's ordinary foreground tap now
      // has its own real effect (opening that rule's history), so it
      // is no longer a safe no-op probe for "is this row closed",
      // and asserting the actual internal state is the more direct,
      // more correct check anyway.
      await dragRevealByRuleId(tester, ruleId, 40);
      expectRevealState(tester, ruleId, 0);

      await dragRevealByRuleId(tester, ruleId, -40);
      expectRevealState(tester, ruleId, 0);
    },
  );

  testWidgets(
    'opening Edit then dragging toward Delete replaces the open side with Delete, never showing '
    'both',
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

      expect(ruleRowFinder(ruleId), findsOneWidget);
      expectRevealState(tester, ruleId, 0);
      await dragRevealByRuleId(tester, ruleId, 200);
      expectRevealState(tester, ruleId, 1);

      // Start inside the visible part of the translated foreground, never
      // the hidden label or the revealed action button itself.
      final bounds = tester.getRect(find.byKey(Key('recurringRuleRow_$ruleId')));
      final foreground = tester.getRect(ruleRowFinder(ruleId));
      final actionWidth = tester.getSize(find.byKey(Key('recurringEditAction_$ruleId'))).width;
      final gesture = await tester.startGesture(foreground.intersect(bounds).center);
      for (int step = 0; step < 12; step++) {
        await gesture.moveBy(Offset(-(actionWidth * 2 + 60) / 12, 0));
        await tester.pump();
        final editActive = find.byKey(Key('recurringEditAction_$ruleId')).hitTestable().evaluate().isNotEmpty;
        final deleteActive = find.byKey(Key('recurringDeleteAction_$ruleId')).hitTestable().evaluate().isNotEmpty;
        expect(editActive && deleteActive, isFalse, reason: 'Only one side may be exposed during the drag');
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expectRevealState(tester, ruleId, -1);
      expect(find.text('Edit recurring rule'), findsNothing);
      expect(find.text('Delete this recurring rule?'), findsNothing);
    },
  );

  testWidgets(
    'tapping genuinely blank list space while a row is open closes its reveal panel',
    (tester) async {
      useTallSurface(tester);
      final (AppDatabase db, String profileId, List<AccountRow> accounts) = await seededDb();
      final DateTime todayUtc = DateTime.now().toUtc();
      final DateTime today = DateTime.utc(todayUtc.year, todayUtc.month, todayUtc.day);
      final RecurringRuleRepository ruleRepo = RecurringRuleRepository(db, AccountRepository(db));
      final String ruleId1 = await ruleRepo.createRule(
        profileId: profileId,
        kind: RecurringRuleKind.expense,
        name: 'Rent',
        amount: Money.fromMinorUnits(80000, 'JPY'),
        accountId: accounts.first.id,
        frequency: RecurrenceFrequency.monthly,
        interval: 1,
        startDate: today,
      );
      // row 2's id is never referenced below -- this test only needs a
      // second row to exist so the list isn't trivially a single-row
      // edge case; binding its id would be unused.
      await ruleRepo.createRule(
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

      await openEditReveal(tester, ruleId1, today.toIso8601String());

      // Tap elsewhere in the list -- genuinely empty space below both
      // rows (`useTallSurface` gives a 2000px-tall surface, and these
      // two short rows occupy only a small region near the top). No
      // row's own `GestureDetector` hit-tests here, so this exercises
      // ONLY the list body's own ancestor "tap anywhere closes the
      // open row" `GestureDetector.onTap` -- distinct from, and kept
      // alongside, the "tap another row's own content" case covered
      // by the next test below.
      final Rect listRect = tester.getRect(find.byKey(const Key('recurringRuleListView')));
      await tester.tapAt(Offset(listRect.left + 20, listRect.bottom - 20));
      await tester.pumpAndSettle();

      // Recurring History Final Corrections checkpoint: verified
      // directly via [expectRevealState] rather than by tapping row 1's
      // own 'Edit' text -- a closed row's ordinary foreground tap now
      // has its own real effect (opening that rule's history), so it
      // is no longer a safe no-op probe for "is this row closed".
      expectRevealState(tester, ruleId1, 0);
    },
  );

  testWidgets(
    'tapping ordinary content inside a DIFFERENT (closed) row while one row is open closes '
    'the open row\'s reveal AND opens the tapped row\'s own history (cross-row tap, not just '
    'blank space)',
    (tester) async {
      useTallSurface(tester);
      final (AppDatabase db, String profileId, List<AccountRow> accounts) = await seededDb();
      final DateTime todayUtc = DateTime.now().toUtc();
      final DateTime today = DateTime.utc(todayUtc.year, todayUtc.month, todayUtc.day);
      final RecurringRuleRepository ruleRepo = RecurringRuleRepository(db, AccountRepository(db));
      final String ruleId1 = await ruleRepo.createRule(
        profileId: profileId,
        kind: RecurringRuleKind.expense,
        name: 'Rent',
        amount: Money.fromMinorUnits(80000, 'JPY'),
        accountId: accounts.first.id,
        frequency: RecurrenceFrequency.monthly,
        interval: 1,
        startDate: today,
      );
      await ruleRepo.createRule(
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

      // Recurring History Final Corrections checkpoint: this test now
      // needs the real-`GoRouter` harness -- tapping row 2's own
      // ordinary (closed) foreground content legitimately opens row
      // 2's own history (the whole point of that checkpoint's Case 2),
      // which this test must now observe rather than treat as
      // impossible.
      await tester.pumpWidget(appWithRecurringRouter(container));
      await tester.pumpAndSettle();

      await openEditReveal(tester, ruleId1, today.toIso8601String());
      expectRevealState(tester, ruleId1, 1);

      // Tap row 2's own ordinary content ('Salary', its title text) --
      // NOT blank list space, and not a swipe gesture on row 2. This
      // is the cross-row-tap fix's whole point: row 2's own
      // `_SwipeRevealRow` `GestureDetector` (registering its own
      // `onTap`/drag recognizers for its own self-close/swipe
      // handling) sits in the SAME gesture arena as the list body's
      // ancestor "tap anywhere closes the open row" `GestureDetector`,
      // and the ancestor's plain `onTap` can lose that arena -- which
      // is exactly why `_SwipeRevealRow` now also fires
      // `onInteractionStart` from `onTapDown` (see that callback's doc
      // comment in `recurring_screen.dart`), reaching the parent
      // regardless of which recognizer wins. `_handleRowInteractionStart`
      // never opens row 2's OWN REVEAL PANEL by itself; only
      // [openEditReveal]/a completed swipe does that -- so tapping row
      // 2's plain title here must close row 1's reveal WITHOUT opening
      // row 2's reveal. It is a SEPARATE, intentional effect (Case 2's
      // own closed-row contract) that this same tap also now opens row
      // 2's own history screen, since row 2 was closed at the moment it
      // was tapped.
      await tester.tap(find.text('Salary'));
      await tester.pumpAndSettle();

      // Row 2's own history opened -- the closed-row foreground tap's
      // real, intended effect.
      expect(find.byType(RecurringHistoryScreen), findsOneWidget);
      expect(find.text('Salary history'), findsOneWidget);

      // Row 1's reveal panel closed as a side effect of the same tap
      // (via `onInteractionStart`, fired from `onTapDown` regardless of
      // which recognizer ultimately wins) -- never opened Edit, and
      // row 2's own reveal panel (as opposed to its history) was never
      // opened either. Checked by navigating back (the standard
      // `BackButton` tooltip) rather than by tapping into either row
      // again, since both rows' own foreground taps now have their own
      // real navigation effect and are no longer safe no-op probes.
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expectRevealState(tester, ruleId1, 0);
    },
  );

  testWidgets(
    'deleting a rule via its swipe-reveal panel still requires the existing confirmation '
    'dialog -- swiping never auto-executes Delete',
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

      // The drag alone -- revealing Delete -- must never delete anything
      // by itself.
      await openDeleteReveal(tester, ruleId, today.toIso8601String());
      RecurringRuleRow row = await (db.select(db.recurringRules)..where((tbl) => tbl.id.equals(ruleId)))
          .getSingle();
      expect(row.deletedAt, isNull);

      await tester.tap(
        find.descendant(of: find.byKey(Key('recurringRuleRow_$ruleId')), matching: find.text('Delete')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Delete this recurring rule?'), findsOneWidget);

      row = await (db.select(db.recurringRules)..where((tbl) => tbl.id.equals(ruleId))).getSingle();
      expect(row.deletedAt, isNull); // still not deleted -- only confirming does it

      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      row = await (db.select(db.recurringRules)..where((tbl) => tbl.id.equals(ruleId))).getSingle();
      expect(row.deletedAt, isNotNull); // soft-deleted, never hard-deleted
    },
  );

  testWidgets(
    'Post/Skip remain visible, outside the swipe-reveal panel, before and after swiping',
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

      final String dateKey = today.toIso8601String();
      final Finder post = find.byKey(Key('postOccurrence_${ruleId}_$dateKey'));
      final Finder skip = find.byKey(Key('skipOccurrence_${ruleId}_$dateKey'));

      expect(post, findsOneWidget);
      expect(skip, findsOneWidget);

      await openEditReveal(tester, ruleId, dateKey);
      expect(post, findsOneWidget);
      expect(skip, findsOneWidget);

      await openDeleteReveal(tester, ruleId, dateKey);
      expect(post, findsOneWidget);
      expect(skip, findsOneWidget);
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

  // CP5.4b: the row's amount/subtitle text is plain `Text` with no
  // `overflow`/`maxLines` forcing a clip -- it wraps rather than clips, so
  // this stress case confirms every digit of a large, precision-sensitive
  // currency amount and the scheduled date both survive intact alongside
  // a long rule name at a narrow width and a large text scale.
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
        // د.ك12,345.678 -- KWD has 3 minor units per `CurrencyRegistry`.
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
      expect(find.text(longName), findsOneWidget);
      // findsNWidgets(2): row amount + estimate card's monthly total
      // coincide (single active monthly-interval-1 expense rule).
      expect(find.textContaining('د.ك12,345.678'), findsNWidgets(2));
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

        expect(
          find.descendant(of: find.byType(AppBar), matching: find.text('定期')),
          findsOneWidget,
        ); // AppBar title
        expect(find.textContaining('定期ルールがまだありません'), findsOneWidget); // empty state

        await tester.tap(find.byKey(const Key('addRecurringRuleAction')));
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

        await tester.tap(find.byKey(const Key('addRecurringRuleAction')));
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

        await tester.tap(find.byKey(const Key('addRecurringRuleAction')));
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

        await tester.tap(find.byKey(const Key('addRecurringRuleAction')));
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
        // findsNWidgets(2): row amount + estimate card's monthly total
        // coincide (single active monthly-interval-1 expense rule).
        expect(find.textContaining('K5,000.00'), findsNWidgets(2));
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
        // findsNWidgets(2): row amount + estimate card's monthly total
        // coincide (single active monthly-interval-1 expense rule).
        expect(find.textContaining('₫25,000,000'), findsNWidgets(2));
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
        // findsNWidgets(2): row amount + estimate card's monthly total
        // coincide (single active monthly-interval-1 expense rule).
        expect(find.textContaining('د.ك12,345.678'), findsNWidgets(2));
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
        // findsNWidgets(2): row amount + estimate card's monthly total
        // coincide (single active monthly-interval-1 expense rule).
        expect(find.textContaining('د.ك12,345.678'), findsNWidgets(2));
        expect(find.textContaining(DateFormat.yMMMd().format(anchor)), findsOneWidget);
      },
    );

    testWidgets(
      'CP6.7 (K): creating and then deleting a rule works end-to-end through the fully '
      'localized Japanese dialogs and overflow menu',
      (tester) async {
        useTallSurface(tester);
        final (AppDatabase db, _, List<AccountRow> accounts) = await seededDb();
        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRecurring(container, locale: const Locale('ja')));
        await tester.pumpAndSettle();

        // Create via the localized "new rule" dialog.
        await tester.tap(find.byKey(const Key('addRecurringRuleAction')));
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

        // Delete via the localized overflow menu + confirmation dialog.
        await invokeRuleAction(tester, created.id, '削除');
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
  // Visual System Convergence Checkpoint 7.5: locks in the row card's
  // bordered visual treatment (`AppCard(bordered: true)`) via the same
  // shape/side/color contract `app_card_test.dart`/`accounts_screen_test
  // .dart` already assert for `AppCard` -- never a pixel value.
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

      // The urgency chip renders as its own localized text -- never a
      // section header duplicate now that sections are retired, so this
      // is exactly one match.
      expect(find.text('Due today'), findsOneWidget);
    },
  );

  // ---------------------------------------------------------------------
  // Checkpoint R2 -- the reused, currency-safe estimate summary card
  // (ADR-031), now always shown inline above the filter bar rather than
  // behind a retired Subscriptions tab.
  // ---------------------------------------------------------------------
  testWidgets(
    'the estimate summary card shows the per-currency monthly and yearly totals for active '
    'expense rules only, excluding income and transfer rules',
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

      expect(find.text('Netflix'), findsOneWidget);
      expect(find.text('Salary'), findsOneWidget); // the income rule is still a normal row...

      expect(find.byKey(const Key('recurringEstimateSummaryCard')), findsOneWidget);
      expect(find.byKey(const Key('recurringEstimateBlock_JPY')), findsOneWidget);
      // Interval-1 monthly expense: the estimated monthly total equals
      // the rule's own amount exactly -- shown once on the row itself
      // and once in the estimate card. Salary's much larger amount
      // never shows up here, since the card is expense-only.
      expect(find.textContaining('¥150,000'), findsNWidgets(2));
      // Estimated yearly total = amount * 12, shown only in the card.
      expect(find.textContaining('¥1,800,000'), findsOneWidget);
    },
  );

  testWidgets(
    'the estimate summary card is absent when there are no active expense rules',
    (tester) async {
      final (AppDatabase db, String profileId, List<AccountRow> accounts) = await seededDb();
      final DateTime todayUtc = DateTime.now().toUtc();
      final DateTime today = DateTime.utc(todayUtc.year, todayUtc.month, todayUtc.day);
      // Only an income rule exists -- never contributes to the
      // expense-only estimate card.
      await RecurringRuleRepository(db, AccountRepository(db)).createRule(
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

      expect(find.text('Salary'), findsOneWidget); // the rule itself still renders as a row
      expect(find.byKey(const Key('recurringEstimateSummaryCard')), findsNothing);
    },
  );

  testWidgets(
    'expense rules in different currencies show separate estimate blocks, never a combined '
    'figure',
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

      expect(find.byKey(const Key('recurringEstimateBlock_JPY')), findsOneWidget);
      expect(find.byKey(const Key('recurringEstimateBlock_KWD')), findsOneWidget);
      for (final currency in ['JPY', 'KWD']) {
        final card = find.byKey(Key('recurringCurrencySummary_$currency'));
        expect(tester.widget<AppCard>(card).onTap, isNotNull);
        expect(find.descendant(of: card, matching:
          find.byKey(Key('recurringEstimateBlock_$currency'))), findsOneWidget);
        expect(find.descendant(of: card, matching: find.byIcon(Icons.chevron_right_rounded)),
          findsOneWidget);
      }
      expect(find.textContaining('¥150,000'), findsWidgets);
      expect(find.textContaining('د.ك12.345'), findsWidgets);
    },
  );

  testWidgets(
    'the estimate summary card and its totals labels render in Japanese',
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

      expect(find.byKey(const Key('recurringEstimateSummaryCard')), findsOneWidget);
      // Recurring UI Upgrade + History Views checkpoint: the card's
      // title/yearly-total wording moved from subscriptionsEstimated
      // MonthlyTotalLabel/subscriptionsEstimatedYearlyTotalLabel
      // ('Est. monthly'/'推定月額', 'Est. yearly'/'推定年額') to the new
      // recurringEstimateCardTitle/recurringEstimateYearlyTotalLabel keys
      // ('Monthly estimated total'/'月間見積もり合計', 'Yearly total'/
      // '年間合計') -- this test now asserts the new Japanese wording.
      expect(find.textContaining('月間見積もり合計'), findsOneWidget); // Monthly estimated total
      expect(find.textContaining('年間合計'), findsOneWidget); // Yearly total
      expect(find.text('Netflix'), findsOneWidget);
    },
  );

  testWidgets(
    'the estimate summary card renders without overflow at a narrow width and a 1.6x text scale',
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

      expect(tester.takeException(), isNull);
      expect(find.textContaining('د.ك12,345.678'), findsWidgets);
    },
  );

  testWidgets(
    'handling a rule\'s only upcoming occurrence early still leaves its later occurrence '
    'visible, and its estimate stays counted the whole time -- regression for the Android QA '
    'subscription-state-inconsistency investigation, now against the unified list',
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

      // Before handling anything: the rule's one upcoming occurrence is
      // visible, and its estimate is already counted (computed
      // independently of pending/handled state by
      // `computeSubscriptionEstimatedTotals`).
      expect(find.text('Netflix'), findsOneWidget);
      expect(find.byKey(const Key('recurringEstimateSummaryCard')), findsOneWidget);
      expect(find.byKey(const Key('recurringEstimateBlock_JPY')), findsOneWidget);
      final Finder skipButton = find.byWidgetPredicate(
        (Widget w) => w is OutlinedButton && (w.key as ValueKey<String>?)?.value.startsWith(
              'skipOccurrence_$ruleId',
            ) == true,
      );
      expect(skipButton, findsOneWidget);

      // Handle that single upcoming occurrence EARLY, via the same Skip
      // button that already exists and is never disabled for an
      // `upcoming`-urgency item -- exactly how the original Android QA
      // report reproduced this by ordinary tapping, not a special code
      // path.
      await tester.tap(skipButton);
      await tester.pumpAndSettle();

      // The rule is still active and still has a real future occurrence,
      // so it must NOT disappear from the list, and the estimate card
      // (driven independently of any pending-item state) must still
      // show its figure.
      expect(find.text('Netflix'), findsOneWidget);
      expect(find.byKey(const Key('recurringEstimateSummaryCard')), findsOneWidget);
      expect(find.byKey(const Key('recurringEstimateBlock_JPY')), findsOneWidget);

      final DateTime laterOccurrence = RecurringSchedule(
        frequency: RecurrenceFrequency.monthly,
        interval: 1,
        startDateUtc: nearestUpcoming,
      ).nextOccurrenceAfter(nearestUpcoming)!;
      expect(laterOccurrence.isAfter(nearestUpcoming), isTrue); // a genuinely later date
      expect(
        find.byKey(Key('skipOccurrence_${ruleId}_${laterOccurrence.toIso8601String()}')),
        findsOneWidget,
      );
      expect(
        find.byKey(Key('skipOccurrence_${ruleId}_${nearestUpcoming.toIso8601String()}')),
        findsNothing,
      );

      final List<RecurringOccurrenceRow> occurrences =
          await db.select(db.recurringOccurrences).get();
      expect(occurrences, hasLength(1));
      expect(occurrences.single.status, 'skipped');
      expect(occurrences.single.scheduledDate.toUtc(), nearestUpcoming);
      final List<Transaction> transactions = await db.select(db.transactions).get();
      expect(transactions, isEmpty);
    },
  );

  // ---------------------------------------------------------------------
  // Checkpoint R2 -- the new All/Active/Upcoming/Expired filter bar.
  // ---------------------------------------------------------------------
  testWidgets(
    'the All/Active/Upcoming/Expired filter bar narrows the list to the rules matching each tab',
    (tester) async {
      useTallSurface(tester);
      final (AppDatabase db, String profileId, List<AccountRow> accounts) = await seededDb();
      final RecurringRuleRepository ruleRepo = RecurringRuleRepository(db, AccountRepository(db));
      final DateTime todayUtc = DateTime.now().toUtc();
      final DateTime today = DateTime.utc(todayUtc.year, todayUtc.month, todayUtc.day);

      // Due today -- active, and within the Upcoming tab's window (an
      // overdue/due-today item always counts there, unconditionally).
      await ruleRepo.createRule(
        profileId: profileId,
        kind: RecurringRuleKind.expense,
        name: 'Rent',
        amount: Money.fromMinorUnits(80000, 'JPY'),
        accountId: accounts.first.id,
        frequency: RecurrenceFrequency.monthly,
        interval: 1,
        startDate: today,
      );
      // Active, but its only occurrence is 10 days out -- beyond the
      // Upcoming tab's `kHomeUpcomingWindowDays` (7) window, so it
      // belongs in Active but not Upcoming.
      await ruleRepo.createRule(
        profileId: profileId,
        kind: RecurringRuleKind.expense,
        name: 'Annual Insurance',
        amount: Money.fromMinorUnits(500000, 'JPY'),
        accountId: accounts.first.id,
        frequency: RecurrenceFrequency.yearly,
        interval: 1,
        startDate: today.add(const Duration(days: 10)),
      );
      // Already ended as of today, with its one-and-only occurrence
      // already handled -- genuinely expired AND has no leftover
      // pendingItem. (An expired rule that still has an *unhandled*
      // past occurrence would legitimately show up as "overdue" and
      // therefore remain Upcoming-eligible -- that is correct product
      // behavior, but it's a different scenario than the one this test
      // wants to isolate, so the occurrence is skipped below before the
      // filter assertions run.)
      final DateTime oldGymOccurrence = today.subtract(const Duration(days: 90));
      final String oldGymRuleId = await ruleRepo.createRule(
        profileId: profileId,
        kind: RecurringRuleKind.expense,
        name: 'Old Gym Membership',
        amount: Money.fromMinorUnits(30000, 'JPY'),
        accountId: accounts.first.id,
        frequency: RecurrenceFrequency.monthly,
        interval: 1,
        startDate: oldGymOccurrence,
        endDate: oldGymOccurrence,
      );

      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRecurring(container));
      await tester.pumpAndSettle();

      // Mark Old Gym Membership's only occurrence as handled so the
      // rule has no pendingItem left (see comment above).
      await tester.tap(
        find.byKey(
          Key('skipOccurrence_${oldGymRuleId}_${oldGymOccurrence.toIso8601String()}'),
        ),
      );
      await tester.pumpAndSettle();

      final Finder filterBar = find.byKey(const Key('recurringFilterSegmentedControl'));
      Future<void> selectFilter(String label) async {
        await tester.tap(find.descendant(of: filterBar, matching: find.text(label)));
        await tester.pumpAndSettle();
      }

      // All (default): every rule.
      expect(find.text('Rent'), findsOneWidget);
      expect(find.text('Annual Insurance'), findsOneWidget);
      expect(find.text('Old Gym Membership'), findsOneWidget);

      await selectFilter('Active');
      expect(find.text('Rent'), findsOneWidget);
      expect(find.text('Annual Insurance'), findsOneWidget);
      expect(find.text('Old Gym Membership'), findsNothing);

      await selectFilter('Upcoming');
      expect(find.text('Rent'), findsOneWidget);
      expect(find.text('Annual Insurance'), findsNothing);
      expect(find.text('Old Gym Membership'), findsNothing);

      await selectFilter('Expired');
      expect(find.text('Rent'), findsNothing);
      expect(find.text('Annual Insurance'), findsNothing);
      expect(find.text('Old Gym Membership'), findsOneWidget);

      await selectFilter('All');
      expect(find.text('Rent'), findsOneWidget);
      expect(find.text('Annual Insurance'), findsOneWidget);
      expect(find.text('Old Gym Membership'), findsOneWidget);
    },
  );

  // ---------------------------------------------------------------------
  // Checkpoint R2 -- the new search box.
  // ---------------------------------------------------------------------
  testWidgets(
    'toggling search shows/hides the search field, and closing it clears the query and restores '
    'the full list',
    (tester) async {
      useTallSurface(tester);
      final (AppDatabase db, String profileId, List<AccountRow> accounts) = await seededDb();
      final RecurringRuleRepository ruleRepo = RecurringRuleRepository(db, AccountRepository(db));
      final DateTime todayUtc = DateTime.now().toUtc();
      final DateTime today = DateTime.utc(todayUtc.year, todayUtc.month, todayUtc.day);
      await ruleRepo.createRule(
        profileId: profileId,
        kind: RecurringRuleKind.expense,
        name: 'Grocery Shopping',
        amount: Money.fromMinorUnits(500000, 'JPY'),
        accountId: accounts.first.id,
        frequency: RecurrenceFrequency.monthly,
        interval: 1,
        startDate: today,
      );
      await ruleRepo.createRule(
        profileId: profileId,
        kind: RecurringRuleKind.expense,
        name: 'Internet Bill',
        amount: Money.fromMinorUnits(600000, 'JPY'),
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

      expect(find.byKey(const Key('recurringSearchField')), findsNothing);
      await tester.tap(find.byKey(const Key('toggleRecurringSearch')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('recurringSearchField')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('recurringSearchField')), 'Grocery');
      await tester.pumpAndSettle();
      expect(find.text('Grocery Shopping'), findsOneWidget);
      expect(find.text('Internet Bill'), findsNothing);

      // Closing search (the same icon now shows a close glyph) clears
      // the query -- both rules are visible again.
      await tester.tap(find.byKey(const Key('toggleRecurringSearch')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('recurringSearchField')), findsNothing);
      expect(find.text('Grocery Shopping'), findsOneWidget);
      expect(find.text('Internet Bill'), findsOneWidget);
    },
  );

  testWidgets(
    'a search query matching no rule shows the "no matching" empty state, distinct from the '
    'ordinary empty state',
    (tester) async {
      useTallSurface(tester);
      final (AppDatabase db, String profileId, List<AccountRow> accounts) = await seededDb();
      final DateTime todayUtc = DateTime.now().toUtc();
      final DateTime today = DateTime.utc(todayUtc.year, todayUtc.month, todayUtc.day);
      await RecurringRuleRepository(db, AccountRepository(db)).createRule(
        profileId: profileId,
        kind: RecurringRuleKind.expense,
        name: 'Grocery Shopping',
        amount: Money.fromMinorUnits(500000, 'JPY'),
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

      await tester.tap(find.byKey(const Key('toggleRecurringSearch')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('recurringSearchField')), 'Nonexistent Rule');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('recurringEmptyMessage')), findsOneWidget);
      expect(find.text('No matching recurring rules.'), findsOneWidget);
      expect(find.textContaining('No recurring rules yet'), findsNothing);
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

      await tester.tap(find.byKey(const Key('addRecurringRuleAction')));
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

      await tester.tap(find.byKey(const Key('addRecurringRuleAction')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('recurringNameField')), 'Rent');
      await tester.tap(find.byKey(const Key('recurringAccountDropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('${accounts.first.name} (JPY)').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('recurringAmountField')), '80000');

      await tester.tap(find.byKey(const Key('recurringNotificationsToggle')));
      await tester.pumpAndSettle();

      expect(
        tester.widget<SwitchListTile>(find.byKey(const Key('recurringNotificationsToggle'))).value,
        isFalse,
      );
      expect(find.textContaining("wasn't granted"), findsOneWidget);
      expect(find.text('New recurring rule'), findsOneWidget); // dialog still open

      await tester.tap(find.byKey(const Key('saveRecurringRule')));
      await tester.pumpAndSettle();
      final RecurringRuleRow saved = await db.select(db.recurringRules).getSingle();
      expect(saved.notificationsEnabled, isFalse);
    },
  );

  group('Checkpoint U2 -- service identity on a recurring rule', () {
    testWidgets(
      'choosing "Netflix" in the create dialog persists it, and the row\'s subtitle includes '
      'the service display name',
      (tester) async {
        useTallSurface(tester);
        final (AppDatabase db, _, List<AccountRow> accounts) = await seededDb();
        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRecurring(container));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('addRecurringRuleAction')));
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(const Key('recurringNameField')), 'Netflix subscription');
        await tester.tap(find.byKey(const Key('recurringAccountDropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('${accounts.first.name} (JPY)').last);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('serviceIdentityDropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Netflix').last);
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(const Key('recurringAmountField')), '1500');
        await tester.tap(find.byKey(const Key('saveRecurringRule')));
        await tester.pumpAndSettle();

        expect(find.text('New recurring rule'), findsNothing); // dialog closed
        expect(tester.takeException(), isNull);

        final RecurringRuleRow saved = await db.select(db.recurringRules).getSingle();
        expect(saved.serviceIdentityKey, 'netflix');
        expect(find.textContaining('Netflix'), findsWidgets); // the row's own subtitle
      },
    );

    testWidgets(
      'editing an existing rule via semantic actions prefills the service dropdown from '
      'serviceIdentityKey, and changing it back to None persists a null serviceIdentityKey',
      (tester) async {
        useTallSurface(tester);
        final (AppDatabase db, String profileId, List<AccountRow> accounts) = await seededDb();
        final String ruleId = await RecurringRuleRepository(db, AccountRepository(db)).createRule(
          profileId: profileId,
          kind: RecurringRuleKind.expense,
          name: 'Netflix subscription',
          amount: Money.fromMinorUnits(1500, 'JPY'),
          accountId: accounts.first.id,
          serviceIdentityKey: 'netflix',
          frequency: RecurrenceFrequency.monthly,
          interval: 1,
          startDate: DateTime.now().toUtc(),
        );
        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRecurring(container));
        await tester.pumpAndSettle();

        await invokeRuleAction(tester, ruleId, 'Edit');
        await tester.pumpAndSettle();

        expect(find.text('Edit recurring rule'), findsOneWidget);
        expect(find.text('Netflix'), findsOneWidget); // prefilled from serviceIdentityKey

        await tester.tap(find.byKey(const Key('serviceIdentityDropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('None').last);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('saveRecurringRule')));
        await tester.pumpAndSettle();

        expect(find.text('Edit recurring rule'), findsNothing); // dialog closed
        expect(tester.takeException(), isNull);
        final RecurringRuleRow updated =
            await (db.select(db.recurringRules)..where((tbl) => tbl.id.equals(ruleId)))
                .getSingle();
        expect(updated.serviceIdentityKey, isNull);
      },
    );

    testWidgets(
      'a rule created as a Transfer never offers the service dropdown, matching its existing '
      'category exclusion',
      (tester) async {
        useTallSurface(tester);
        final (AppDatabase db, _, List<AccountRow> accounts) = await seededDb(
          accounts: const <_SeedAccount>[
            _SeedAccount(name: 'JPY Wallet', currencyCode: 'JPY'),
            _SeedAccount(name: 'JPY Savings', currencyCode: 'JPY'),
          ],
        );
        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRecurring(container));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('addRecurringRuleAction')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('recurringKindDropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Transfer').last);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('serviceIdentityDropdown')), findsNothing);
      },
    );

    testWidgets(
      'the premium service picker sheet renders the selected service\'s approved artwork for '
      'both the new-rule and edit-rule flows, and the collapsed field mirrors the same artwork',
      (tester) async {
        useTallSurface(tester);
        final (AppDatabase db, _, List<AccountRow> _) = await seededDb();
        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRecurring(container));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('addRecurringRuleAction')));
        await tester.pumpAndSettle();

        // Before any selection, the collapsed field shows no artwork at all.
        expect(
          find.image(const AssetImage('assets/icons/services/netflix.png')),
          findsNothing,
        );

        await tester.tap(find.byKey(const Key('serviceIdentityDropdown')));
        await tester.pumpAndSettle();

        // The premium sheet itself -- header, search field, and a scrollable
        // list of rows, each with a real icon slot (not a legacy dropdown).
        expect(find.byKey(const Key('serviceIdentitySearchField')), findsOneWidget);
        final Finder pickerList = find.byKey(const Key('serviceIdentityPickerList'));
        expect(pickerList, findsOneWidget);
        final Finder netflixRowArtwork = find.descendant(
          of: pickerList,
          matching: find.image(const AssetImage('assets/icons/services/netflix.png')),
        );
        expect(netflixRowArtwork, findsOneWidget);

        await tester.tap(find.text('Netflix').last);
        await tester.pumpAndSettle();

        // Sheet closed; the collapsed field now mirrors the exact same artwork.
        expect(
          find.image(const AssetImage('assets/icons/services/netflix.png')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'reopening the picker for an existing Netflix rule marks the Netflix row selected with a '
      'check mark, and dismissing the sheet without tapping a row never changes the saved value',
      (tester) async {
        useTallSurface(tester);
        final (AppDatabase db, String profileId, List<AccountRow> accounts) = await seededDb();
        final String ruleId = await RecurringRuleRepository(db, AccountRepository(db)).createRule(
          profileId: profileId,
          kind: RecurringRuleKind.expense,
          name: 'Netflix subscription',
          amount: Money.fromMinorUnits(1500, 'JPY'),
          accountId: accounts.first.id,
          serviceIdentityKey: 'netflix',
          frequency: RecurrenceFrequency.monthly,
          interval: 1,
          startDate: DateTime.now().toUtc(),
        );
        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRecurring(container));
        await tester.pumpAndSettle();

        await invokeRuleAction(tester, ruleId, 'Edit');
        await tester.pumpAndSettle();

        // The collapsed field's own artwork, scoped to the trigger
        // itself -- correct regardless of whether the picker sheet is
        // open or closed at the time (the trigger route stays mounted,
        // just covered, while the sheet is up, so a global image count
        // is not a safe way to prove this; scoping to the keyed trigger
        // is).
        final Finder triggerArtwork = find.descendant(
          of: find.byKey(const Key('serviceIdentityDropdown')),
          matching: find.image(const AssetImage('assets/icons/services/netflix.png')),
        );
        expect(triggerArtwork, findsOneWidget); // prefilled from serviceIdentityKey

        await tester.tap(find.byKey(const Key('serviceIdentityDropdown')));
        await tester.pumpAndSettle();

        // The Netflix row inside the open picker sheet -- scoped to the
        // sheet's own list, not a bare `find.text('Netflix')`, since the
        // covered trigger behind the sheet also still renders "Netflix"
        // and its own artwork at this point. Two visible Netflix
        // images (the trigger's preview and the sheet row's) is the
        // correct, expected state here, not a bug.
        final Finder netflixRow = find.ancestor(
          of: find.descendant(
            of: find.byKey(const Key('serviceIdentityPickerList')),
            matching: find.text('Netflix'),
          ),
          matching: find.byType(InkWell),
        ).first;
        expect(
          find.descendant(of: netflixRow, matching: find.image(const AssetImage('assets/icons/services/netflix.png'))),
          findsOneWidget,
        );
        expect(
          find.descendant(of: netflixRow, matching: find.byIcon(Icons.check_circle_rounded)),
          findsOneWidget,
        );
        // The form's own selected-service preview, independently, still
        // shows the same artwork while the sheet is open.
        expect(triggerArtwork, findsOneWidget);

        // Dismiss the sheet by tapping its modal barrier, well outside the
        // sheet itself (which only covers up to 85% of the screen height,
        // leaving the top strip as barrier) -- this must never silently
        // clear or change the persisted selection.
        await tester.tapAt(const Offset(20, 20));
        await tester.pumpAndSettle();

        expect(triggerArtwork, findsOneWidget);

        await tester.tap(find.byKey(const Key('saveRecurringRule')));
        await tester.pumpAndSettle();
        final RecurringRuleRow unchanged =
            await (db.select(db.recurringRules)..where((tbl) => tbl.id.equals(ruleId)))
                .getSingle();
        expect(unchanged.serviceIdentityKey, 'netflix');
      },
    );

    testWidgets(
      '"None" in the premium picker renders a neutral icon, never a fake service logo, and '
      'remains a valid, selectable choice',
      (tester) async {
        useTallSurface(tester);
        final (AppDatabase db, _, List<AccountRow> accounts) = await seededDb();
        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRecurring(container));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('addRecurringRuleAction')));
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(const Key('recurringNameField')), 'Gym membership');
        await tester.tap(find.byKey(const Key('recurringAccountDropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('${accounts.first.name} (JPY)').last);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('serviceIdentityDropdown')));
        await tester.pumpAndSettle();

        final Finder noneRow = find.ancestor(
          of: find.text('None').last,
          matching: find.byType(InkWell),
        ).first;
        expect(
          find.descendant(of: noneRow, matching: find.byIcon(Icons.not_interested_rounded)),
          findsOneWidget,
        );
        // The neutral "None" row never renders any bundled service artwork.
        expect(
          find.descendant(of: noneRow, matching: find.byWidgetPredicate((w) => w is Image)),
          findsNothing,
        );

        await tester.tap(find.text('None').last);
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(const Key('recurringAmountField')), '3000');
        await tester.tap(find.byKey(const Key('saveRecurringRule')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final RecurringRuleRow saved = await db.select(db.recurringRules).getSingle();
        expect(saved.serviceIdentityKey, isNull);
      },
    );
  });

  group('Premium Create/Edit Rule UI checkpoint -- same business behavior, new presentation', () {
    testWidgets(
      'the new-rule premium form still renders every existing field and control, unchanged',
      (tester) async {
        useTallSurface(tester);
        final (AppDatabase db, _, List<AccountRow> _) = await seededDb();
        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRecurring(container));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('addRecurringRuleAction')));
        await tester.pumpAndSettle();

        expect(find.text('New recurring rule'), findsOneWidget);
        for (final key in <String>[
          'recurringKindDropdown',
          'recurringNameField',
          'recurringAccountDropdown',
          'recurringCategoryDropdown',
          'serviceIdentityDropdown',
          'recurringAmountField',
          'recurringFrequencyDropdown',
          'recurringIntervalField',
          'recurringNotificationsToggle',
          'pickRecurringStartDate',
          'saveRecurringRule',
        ]) {
          expect(find.byKey(Key(key)), findsOneWidget, reason: 'missing $key');
        }
        expect(find.text('Cancel'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'the edit premium form pre-populates every persisted field -- type, name, account, '
      'category, service, amount, frequency, interval, start/end date, and notifications',
      (tester) async {
        useTallSurface(tester);
        final (AppDatabase db, String profileId, List<AccountRow> accounts) = await seededDb();
        final String category = await CategoryRepository(db).createCategory(
          profileId: profileId, name: 'Bills & Utilities', type: 'expense', icon: 'shopping');
        final DateTime start = DateTime.utc(2030, 3, 10);
        final DateTime end = DateTime.utc(2031, 3, 10);
        final String ruleId = await RecurringRuleRepository(db, AccountRepository(db)).createRule(
          profileId: profileId,
          kind: RecurringRuleKind.expense,
          name: 'Netflix subscription',
          amount: Money.fromMinorUnits(1500, 'JPY'),
          accountId: accounts.first.id,
          categoryId: category,
          serviceIdentityKey: 'netflix',
          frequency: RecurrenceFrequency.monthly,
          interval: 2,
          startDate: start,
          endDate: end,
          notificationsEnabled: true,
        );
        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRecurring(container));
        await tester.pumpAndSettle();

        await invokeRuleAction(tester, ruleId, 'Edit');
        await tester.pumpAndSettle();

        expect(find.text('Edit recurring rule'), findsOneWidget);

        // Every prepopulation check below is scoped to the dialog's own
        // field/control, never a bare global `find.text`/`find.textContaining`
        // -- the existing recurring list row for this same rule stays
        // mounted (just covered) behind the dialog, and independently
        // shows this rule's own name/category/service/amount, so a
        // global text search is ambiguous by design, not a bug.

        // Name: read the field's own controller text via its EditableText,
        // rather than searching the whole tree for the literal string.
        final Finder nameEditable = find.descendant(
          of: find.byKey(const Key('recurringNameField')),
          matching: find.byType(EditableText),
        );
        expect(nameEditable, findsOneWidget);
        expect(tester.widget<EditableText>(nameEditable).controller.text, 'Netflix subscription');

        // Category: the dropdown's own collapsed display, scoped to its key.
        expect(
          find.descendant(
            of: find.byKey(const Key('recurringCategoryDropdown')),
            matching: find.text('Bills & Utilities'),
          ),
          findsOneWidget,
        );

        // Service: the premium picker trigger's own collapsed display,
        // scoped to its key -- see the dedicated picker tests above for
        // why a bare `find.text('Netflix')` is ambiguous once the sheet
        // (or, as here, the background list row) is in play.
        expect(
          find.descendant(
            of: find.byKey(const Key('serviceIdentityDropdown')),
            matching: find.text('Netflix'),
          ),
          findsOneWidget,
        );

        // Amount: the background row's own formatted total also contains
        // this substring, so this stays `findsWidgets` deliberately
        // rather than asserting a specific count of an unrelated row.
        expect(find.textContaining('1,500'), findsWidgets); // amount

        // Interval: the field's own controller text, same reasoning as name.
        final Finder intervalEditable = find.descendant(
          of: find.byKey(const Key('recurringIntervalField')),
          matching: find.byType(EditableText),
        );
        expect(intervalEditable, findsOneWidget);
        expect(tester.widget<EditableText>(intervalEditable).controller.text, '2');

        // Start date: scoped to its own tappable row.
        expect(
          find.descendant(
            of: find.byKey(const Key('pickRecurringStartDate')),
            matching: find.textContaining(DateFormat.yMMMd().format(start)),
          ),
          findsOneWidget,
        );

        // End date: that row has no key of its own, so anchor on its
        // keyed "Choose" button and scope to its ListTile ancestor.
        final Finder endDateRow = find.ancestor(
          of: find.byKey(const Key('pickRecurringEndDate')),
          matching: find.byType(ListTile),
        ).first;
        expect(
          find.descendant(
            of: endDateRow,
            matching: find.textContaining(DateFormat.yMMMd().format(end)),
          ),
          findsOneWidget,
        );

        expect(
          tester.widget<SwitchListTile>(find.byKey(const Key('recurringNotificationsToggle'))).value,
          isTrue,
        );
        // Editing never offers the kind selector -- same pre-existing rule.
        expect(find.byKey(const Key('recurringKindDropdown')), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    for (final width in <double>[320, 360, 390, 430]) {
      for (final scale in <double>[1, 1.6]) {
        testWidgets(
          'the premium new-rule form renders without overflow at $width / $scale',
          (tester) async {
            useTallSurface(tester);
            tester.view.physicalSize = Size(width, 2400);
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
            final (AppDatabase db, _, List<AccountRow> _) = await seededDb();
            final ProviderContainer container =
                ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
            addTearDown(() => disposeInOrder(tester, container, db));

            await tester.pumpWidget(appWithRecurring(container));
            await tester.pumpAndSettle();

            await tester.tap(find.byKey(const Key('addRecurringRuleAction')));
            await tester.pumpAndSettle();

            expect(tester.takeException(), isNull);
            expect(find.byKey(const Key('recurringNameField')), findsOneWidget);

            // Save/Cancel live in a fixed bottom action bar, outside the
            // scrollable form content -- "Save remains reachable" means
            // it must stay hit-testable at every width/scale without any
            // scrolling, which also proves the dialog itself never
            // overflowed its own constraints (an overflowed `Column`
            // would already have thrown above).
            expect(find.byKey(const Key('saveRecurringRule')).hitTestable(), findsOneWidget);
            expect(find.text('Cancel').hitTestable(), findsOneWidget);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  });

  test('approved service artwork resolves only exact catalog IDs, never from docs/design, and '
      'every resolved asset ships as a real bundled file', () {
    const List<String> namedServiceKeys = <String>[
      'netflix', 'youtube', 'youtubePremium', 'spotify', 'chatgpt', 'gemini', 'steam',
      'claude', 'adobe', 'github',
    ];
    const List<String> genericAndBundledFamilyKeys = <String>[
      'ai', 'other',
      'icloud', 'appleMusic', 'primeVideo', 'aws',
      'googleDrive', 'googleOne', 'googleCloud', 'googleWorkspace',
      'microsoft365', 'azure',
    ];
    for (final key in <String>[...namedServiceKeys, ...genericAndBundledFamilyKeys]) {
      final String? asset = serviceIconAssetFor(key);
      expect(asset, isNotNull, reason: 'expected approved artwork for "$key"');
      expect(asset, startsWith('assets/icons/services/'));
      // Approved artwork is migrated into the runtime bundle; the design
      // source folder is never a live reference.
      expect(asset, isNot(contains('docs/design')));
      expect(
        File(asset!).existsSync(),
        isTrue,
        reason: '$asset must be a real bundled production file, not a dangling reference',
      );
    }
    // A key with no approved artwork (no catalog entry, or genuinely
    // unmapped) must degrade to null, never to a guess.
    for (final key in <String?>[null, 'Netflix', 'unrecognized', 'disneyPlus']) {
      expect(serviceIconAssetFor(key), isNull);
    }
  });

  for (final width in <double>[320, 360, 390, 430]) {
    for (final scale in <double>[1, 1.6]) {
      testWidgets('premium identity and real content at $width / $scale', (tester) async {
        useTallSurface(tester);
        tester.view.physicalSize = Size(width, 2400);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final (db, profileId, accounts) = await seededDb();
        final category = await CategoryRepository(db).createCategory(
          profileId: profileId, name: 'Bills & Utilities', type: 'expense', icon: 'shopping');
        final repo = RecurringRuleRepository(db, AccountRepository(db));
        final start = DateTime.utc(2035, 1, 15);
        final ids = <String>[];
        for (int i = 0; i < 3; i++) {
          ids.add(await repo.createRule(
            profileId: profileId, kind: RecurringRuleKind.expense,
            name: i == 2 ? 'Netflix' : 'Plan $i',
            amount: Money.fromMinorUnits(1590, 'JPY'), accountId: accounts.first.id,
            categoryId: i == 2 ? null : category,
            serviceIdentityKey: i == 0 ? 'netflix' : i == 1 ? 'disneyPlus' : null,
            frequency: RecurrenceFrequency.monthly, interval: 1, startDate: start,
          ));
        }
        final container = ProviderContainer(overrides: [appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));
        await tester.pumpWidget(appWithRecurring(container, theme: AppTheme.light()));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (int i = 0; i < 3; i++) {
          final row = ruleRowFinder(ids[i]);          if (width == 430 && scale == 1 && i == 2) {
            expect(tester.getSize(row).height, lessThanOrEqualTo(100));
          }
          expect(find.descendant(of: row, matching: find.text(i == 2 ? 'Netflix' : 'Plan $i')), findsOneWidget);
          expect(find.descendant(of: row, matching: find.text('¥1,590')), findsOneWidget);
          expect(find.descendant(of: row, matching: find.textContaining(DateFormat.yMMMd().format(start))), findsOneWidget);
          expect(find.descendant(of: row, matching: find.text('JPY Wallet')), findsOneWidget);
          expect(find.descendant(of: row, matching: find.textContaining('••••')), findsNothing);
          expect(find.descendant(of: row, matching: find.text('Bills & Utilities')), i == 2 ? findsNothing : findsOneWidget);
          expect(find.descendant(of: row, matching: find.image(const AssetImage('assets/icons/services/netflix.png'))),
            i == 0 ? findsOneWidget : findsNothing);
          expect(find.descendant(of: row, matching: find.byType(CategoryIdentityIcon)),
            i == 1 ? findsOneWidget : findsNothing);
          expect(find.descendant(of: row, matching: find.byIcon(Icons.more_horiz)), findsNothing);
          final post = find.descendant(of: row, matching: find.byType(FilledButton));
          final skip = find.descendant(of: row, matching: find.byType(OutlinedButton));
          expect(post.hitTestable(), findsOneWidget);
          expect(skip.hitTestable(), findsOneWidget);
          final amount = find.descendant(of: row, matching: find.text('¥1,590'));
          expect(amount.hitTestable(), findsOneWidget);
          final postRect = tester.getRect(post);
          final skipRect = tester.getRect(skip);
          expect(postRect.bottom, lessThanOrEqualTo(skipRect.top));
          expect(postRect.center.dx, closeTo(skipRect.center.dx, 1));
          expect(tester.getRect(amount).right, lessThanOrEqualTo(postRect.left));
          expect(tester.widget<FilledButton>(post).onPressed, isNotNull);
          expect(tester.widget<OutlinedButton>(skip).onPressed, isNotNull);
          if (i == 0) {
            final artwork = find.descendant(of: row, matching:
              find.image(const AssetImage('assets/icons/services/netflix.png')));
            expect(tester.getRect(artwork).right, lessThan(tester.getRect(amount).left));
            final badge = find.descendant(of: row, matching: find.text('Bills & Utilities'));
            expect(badge, findsOneWidget);
            final badgeText = tester.widget<Text>(badge);
            expect(badgeText.maxLines, isNull);
            expect(badgeText.overflow, isNot(TextOverflow.ellipsis));
            expect(tester.getSize(badge).width, lessThanOrEqualTo(tester.getSize(row).width));
            if (width == 320 || scale == 1.6) {
              final title = find.descendant(of: row, matching: find.text('Plan 0'));
              expect(tester.getRect(badge).top, greaterThanOrEqualTo(tester.getRect(title).bottom));
            }
          }
          if (i == 2) expect(find.descendant(of: row, matching: find.byIcon(Icons.trending_down_rounded)), findsOneWidget);
        }
      });
    }
  }

  group('Recurring History Final Corrections checkpoint -- Case 1 (summary card)', () {
    testWidgets(
      'the summary card is tappable, shows the approved subscription icon plus a trailing '
      'chevron, and actually opens the all-services year history',
      (tester) async {
        useTallSurface(tester);
        final (AppDatabase db, String profileId, List<AccountRow> accounts) = await seededDb();
        final DateTime todayUtc = DateTime.now().toUtc();
        final DateTime today = DateTime.utc(todayUtc.year, todayUtc.month, todayUtc.day);
        await RecurringRuleRepository(db, AccountRepository(db)).createRule(
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

        await tester.pumpWidget(appWithRecurringRouter(container));
        await tester.pumpAndSettle();

        final Finder cardFinder = find.byKey(const Key('recurringCurrencySummary_JPY'));
        expect(cardFinder, findsOneWidget);
        final AppCard card = tester.widget<AppCard>(cardFinder);
        expect(card.onTap, isNotNull);
        expect(
          find.descendant(of: cardFinder, matching: find.byIcon(Icons.chevron_right_rounded)),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: cardFinder,
            matching: find.image(const AssetImage(RecurringIconAssets.subscriptionSummary)),
          ),
          findsOneWidget,
        );

        await tester.tap(cardFinder);
        await tester.pumpAndSettle();

        // Case 1 opened -- the generic "Recurring history" title, never
        // a single rule's own `"$name history"` title (that is Case 2's
        // shape, see the group below).
        expect(find.byType(RecurringHistoryScreen), findsOneWidget);
        expect(find.text('Recurring history'), findsOneWidget);
      },
    );
  });

  group('Recurring History Final Corrections checkpoint -- Case 2 (row tap)', () {
    testWidgets(
      'a closed row\'s ordinary foreground tap opens that rule\'s own history',
      (tester) async {
        useTallSurface(tester);
        final (AppDatabase db, String profileId, List<AccountRow> accounts) = await seededDb();
        final DateTime todayUtc = DateTime.now().toUtc();
        final DateTime today = DateTime.utc(todayUtc.year, todayUtc.month, todayUtc.day);
        await RecurringRuleRepository(db, AccountRepository(db)).createRule(
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

        await tester.pumpWidget(appWithRecurringRouter(container));
        await tester.pumpAndSettle();

        expect(find.text('Rent'), findsOneWidget); // still on the Recurring screen
        await tester.tap(find.text('Rent')); // ordinary row content, not a button
        await tester.pumpAndSettle();

        expect(find.byType(RecurringHistoryScreen), findsOneWidget);
        expect(find.text('Rent history'), findsOneWidget); // AppBar title names this exact rule
      },
    );

    testWidgets('tapping Post does not also navigate to history', (tester) async {
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

      await tester.pumpWidget(appWithRecurringRouter(container));
      await tester.pumpAndSettle();

      final Finder postFinder = find.byWidgetPredicate(
        (Widget w) => w is FilledButton &&
            (w.key as ValueKey<String>?)?.value.startsWith('postOccurrence_$ruleId') == true,
      );
      expect(postFinder, findsOneWidget);
      await tester.tap(postFinder);
      await tester.pumpAndSettle();

      // Never navigated. Still on the Recurring screen, not Case 2 --
      // posting is still what happened (not asserted further here;
      // `postOccurrence`'s own behavior is already covered by this
      // file's existing posting tests above).
      expect(find.byType(RecurringHistoryScreen), findsNothing);
      expect(find.text('Rent'), findsOneWidget);
    });

    testWidgets('tapping Skip does not also navigate to history', (tester) async {
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

      await tester.pumpWidget(appWithRecurringRouter(container));
      await tester.pumpAndSettle();

      final Finder skipFinder = find.byWidgetPredicate(
        (Widget w) => w is OutlinedButton &&
            (w.key as ValueKey<String>?)?.value.startsWith('skipOccurrence_$ruleId') == true,
      );
      expect(skipFinder, findsOneWidget);
      await tester.tap(skipFinder);
      await tester.pumpAndSettle();

      // Never navigated. Still on the Recurring screen.
      expect(find.byType(RecurringHistoryScreen), findsNothing);
      expect(find.text('Rent'), findsOneWidget);
    });

    testWidgets('invoking semantic Edit does not navigate to history', (tester) async {
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

      await tester.pumpWidget(appWithRecurringRouter(container));
      await tester.pumpAndSettle();

      await invokeRuleAction(tester, ruleId, 'Edit');
      await tester.pumpAndSettle();

      expect(find.byType(RecurringHistoryScreen), findsNothing);
      // The real-functional-menu sheet opened instead.
      expect(find.text('Edit recurring rule'), findsOneWidget);
    });

    testWidgets(
      'tapping an open row\'s foreground closes the swipe reveal without navigating',
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

        await tester.pumpWidget(appWithRecurringRouter(container));
        await tester.pumpAndSettle();

        await dragRevealByRuleId(tester, ruleId, 200); // open Edit (left-to-right)
        expectRevealState(tester, ruleId, 1);

        await tester.tap(find.text('Rent')); // ordinary foreground content, while open
        await tester.pumpAndSettle();

        expectRevealState(tester, ruleId, 0); // closed again, not navigated
        expect(find.byType(RecurringHistoryScreen), findsNothing);
        expect(find.text('Edit recurring rule'), findsNothing);
      },
    );

    testWidgets(
      'swipe edit/delete still works exactly as before, unaffected by foreground-tap '
      'history navigation and the gradient-styled Post/Skip buttons',
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

        await openEditReveal(tester, ruleId, today.toIso8601String());
        // Tap the actual reveal-action widget by its own key (the same
        // widget `expectRevealState` hit-tests) rather than searching for
        // 'Edit' text under [ruleRowFinder] -- the reveal action lives in
        // a sibling Positioned panel inside the enclosing Stack, not
        // inside the foreground AppCard that [ruleRowFinder] matches, so
        // a descendant-of-row-card query for it can never find anything.
        await tester.tap(find.byKey(Key('recurringEditAction_$ruleId')));
        await tester.pumpAndSettle();
        expect(find.text('Edit recurring rule'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        // Post/Skip are still real FilledButton/OutlinedButton instances
        // at their existing keys -- only their paint changed (a gradient
        // `DecoratedBox` now sits behind each), never their type, key, or
        // `onPressed`.
        final Finder postFinder = find.byWidgetPredicate(
          (Widget w) => w is FilledButton && (w.key as ValueKey<String>?)?.value.startsWith('postOccurrence_') == true,
        );
        expect(postFinder, findsOneWidget);
        expect(tester.widget<FilledButton>(postFinder).onPressed, isNotNull);
      },
    );
  });
}
