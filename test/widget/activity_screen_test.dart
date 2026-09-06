import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/providers.dart';
import 'package:ai_financial_coach/core/database/repositories/account_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/category_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/transaction_repository.dart';
import 'package:ai_financial_coach/core/money/money.dart';
import 'package:ai_financial_coach/core/routing/app_routes.dart';
import 'package:ai_financial_coach/features/transactions/presentation/activity_screen.dart';
import 'package:ai_financial_coach/features/transactions/presentation/transaction_detail_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// NOTE: exercises generated Drift code -- see CLAUDE_FIRST_CODING_PROMPT.md.
//
// Beta 1 Transaction UX (`docs/14_DECISION_LOG.md` ADR-025/026), Phase B
// Checkpoint 2 & Checkpoint 3. Uses a real (minimal) `GoRouter` -- same
// pattern as `test/widget/transaction_detail_screen_test.dart`'s
// `appWithRouter' -- since a row's tap navigates via `context.push`,
// which throws without a `GoRouter` ancestor. The real (unmodified this
// checkpoint) `TransactionDetailScreen` is registered at the real detail
// route so navigation can be verified end to end.
//
// Date-grouping fixtures below deliberately use only "today" and
// "yesterday" (relative to a `now` captured once per test), never a
// hard-coded weekday/date label -- `ActivityScreen` calls the real
// `DateTime.now()` internally (proven correct in isolation, with a fully
// controlled clock, by `activity_date_group_test.dart`), so a widget
// test asserting an exact weekday name would be flaky depending on which
// real-world day the suite happens to run on. "Today" and "Yesterday"
// are the only two labels that are exact regardless of the real date.
//
// Checkpoint 3's search/filter fixtures use the real seeded system
// categories `sys-dining` ("Dining Out", expense) and `sys-salary`
// ("Salary", income) -- see `CategoryRepository._systemCategories` --
// plus a same-currency transfer, so every fixture exercises the exact
// five searchable fields `activity_filter.dart` documents (category
// name, source account name, destination account name, note, formatted
// amount) without inventing new categories.

void main() {
  Future<(AppDatabase, String profileId, String accountId)> seededDb() async {
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    final ProfileRepository profileRepo = ProfileRepository(db);
    final AccountRepository accountRepo = AccountRepository(db);
    await CategoryRepository(db).seedSystemCategoriesIfNeeded();
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
    final String accountId = await accountRepo.createAccount(
      profileId: profileId,
      name: 'Wallet',
      type: 'cash',
      currencyCode: 'JPY',
    );
    return (db, profileId, accountId);
  }

  /// Seeds one expense (category "Dining Out", note "Lunch with team",
  /// ¥1,200), one income (category "Salary", no note, ¥500,000), and one
  /// same-currency transfer from "Wallet" to a new "Savings" account
  /// (¥3,000, no category, no note) -- the shared fixture for every
  /// Checkpoint 3 search/filter test below. Returns the account name
  /// pair as well so tests don't need to re-derive them.
  Future<(AppDatabase, String profileId, String accountId, String secondAccountId)>
      seededDbWithSearchFixtures() async {
    final (AppDatabase db, String profileId, String accountId) = await seededDb();
    final AccountRepository accountRepo = AccountRepository(db);
    final String secondAccountId = await accountRepo.createAccount(
      profileId: profileId,
      name: 'Savings',
      type: 'cash',
      currencyCode: 'JPY',
    );
    final TransactionRepository txRepo = TransactionRepository(db, accountRepo);
    final DateTime nowUtc = DateTime.now().toUtc();

    await txRepo.recordExpense(
      profileId: profileId,
      accountId: accountId,
      amount: Money.fromMinorUnits(1200, 'JPY'),
      categoryId: 'sys-dining',
      note: 'Lunch with team',
      occurredAtUtc: nowUtc,
    );
    await txRepo.recordIncome(
      profileId: profileId,
      accountId: accountId,
      amount: Money.fromMinorUnits(500000, 'JPY'),
      categoryId: 'sys-salary',
      occurredAtUtc: nowUtc,
    );
    await txRepo.recordTransfer(
      profileId: profileId,
      sourceAccountId: accountId,
      destinationAccountId: secondAccountId,
      amount: Money.fromMinorUnits(3000, 'JPY'),
      occurredAtUtc: nowUtc,
    );

    return (db, profileId, accountId, secondAccountId);
  }

  Widget appWithRouter(ProviderContainer container) {
    final GoRouter router = GoRouter(
      initialLocation: AppRoutes.activity,
      routes: <RouteBase>[
        GoRoute(path: AppRoutes.activity, builder: (context, state) => const ActivityScreen()),
        GoRoute(
          path: AppRoutes.transactionDetailPath,
          builder: (context, state) =>
              TransactionDetailScreen(transactionId: state.pathParameters['id']!),
        ),
      ],
    );
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    );
  }

  /// Like [appWithRouter], but also registers a trivial second route so
  /// Checkpoint 3's disposal test can navigate away from
  /// [ActivityScreen] and back without needing anything from the real
  /// route table -- returns the [GoRouter] itself so the test can drive
  /// navigation directly (`router.go(...)`) rather than simulating taps.
  (Widget, GoRouter) appWithNavigableRouter(ProviderContainer container) {
    final GoRouter router = GoRouter(
      initialLocation: AppRoutes.activity,
      routes: <RouteBase>[
        GoRoute(path: AppRoutes.activity, builder: (context, state) => const ActivityScreen()),
        GoRoute(
          path: '/elsewhere',
          builder: (context, state) => const Scaffold(body: Text('Elsewhere')),
        ),
      ],
    );
    return (
      UncontrolledProviderScope(container: container, child: MaterialApp.router(routerConfig: router)),
      router,
    );
  }

  Future<void> disposeInOrder(WidgetTester tester, ProviderContainer container, AppDatabase db) async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pumpAndSettle();
    await db.close();
  }

  /// Whether any [Semantics] widget currently in the tree carries exactly
  /// [label] -- reads the widget tree directly rather than the
  /// accessibility/semantics tree, so it needs no special test-binding
  /// setup and works regardless of whether the semantics tree is enabled.
  bool hasSemanticsLabel(WidgetTester tester, String label) {
    return tester
        .widgetList<Semantics>(find.byType(Semantics))
        .any((Semantics s) => s.properties.label == label);
  }

  testWidgets('zero transactions shows the true empty state', (tester) async {
    final (AppDatabase db, String _, String _) = await seededDb();
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithRouter(container));
    await tester.pumpAndSettle();

    expect(find.text('No transactions yet. Tap Add to record one.'), findsOneWidget);
    // Checkpoint 3: the true empty state has no search/filter UI at all.
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(FilterChip), findsNothing);
  });

  testWidgets(
      'groups a Today and a Yesterday transaction into two sections, and two '
      'Today transactions into one shared section', (tester) async {
    final (AppDatabase db, String profileId, String accountId) = await seededDb();
    final TransactionRepository txRepo = TransactionRepository(db, AccountRepository(db));
    final DateTime now = DateTime.now();

    await txRepo.recordExpense(
      profileId: profileId,
      accountId: accountId,
      amount: Money.fromMinorUnits(500, 'JPY'),
      categoryId: 'sys-dining',
      note: 'today-a',
      occurredAtUtc: now.toUtc(),
    );
    await txRepo.recordExpense(
      profileId: profileId,
      accountId: accountId,
      amount: Money.fromMinorUnits(600, 'JPY'),
      categoryId: 'sys-dining',
      note: 'today-b',
      occurredAtUtc: now.toUtc(),
    );
    await txRepo.recordExpense(
      profileId: profileId,
      accountId: accountId,
      amount: Money.fromMinorUnits(700, 'JPY'),
      categoryId: 'sys-dining',
      note: 'yesterday-a',
      occurredAtUtc: now.subtract(const Duration(days: 1)).toUtc(),
    );

    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithRouter(container));
    await tester.pumpAndSettle();

    // Exactly one "TODAY" section header, exactly one "YESTERDAY" one --
    // the two Today transactions share it rather than each getting their
    // own section.
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('YESTERDAY'), findsOneWidget);
    // Notes render inside a combined "account · note" subtitle string,
    // not as a standalone Text widget -- match by substring.
    expect(find.textContaining('today-a'), findsOneWidget);
    expect(find.textContaining('today-b'), findsOneWidget);
    expect(find.textContaining('yesterday-a'), findsOneWidget);
  });

  testWidgets(
      'renders the resolved category icon, and falls back safely for a category with no '
      'icon, an unrecognized icon name, or no category at all', (tester) async {
    final (AppDatabase db, String profileId, String accountId) = await seededDb();
    final CategoryRepository categoryRepo = CategoryRepository(db);
    final TransactionRepository txRepo = TransactionRepository(db, AccountRepository(db));
    final DateTime nowUtc = DateTime.now().toUtc();

    // sys-dining's seeded icon is 'restaurant' -- CategoryRepository's
    // own _systemCategories seed list.
    await txRepo.recordExpense(
      profileId: profileId,
      accountId: accountId,
      amount: Money.fromMinorUnits(100, 'JPY'),
      categoryId: 'sys-dining',
      note: 'known-icon',
      occurredAtUtc: nowUtc,
    );

    final String noIconCategoryId = await categoryRepo.createCategory(
      profileId: profileId,
      name: 'No Icon Category',
      type: 'expense',
    ); // icon defaults to null
    await txRepo.recordExpense(
      profileId: profileId,
      accountId: accountId,
      amount: Money.fromMinorUnits(200, 'JPY'),
      categoryId: noIconCategoryId,
      note: 'no-icon-category',
      occurredAtUtc: nowUtc,
    );

    final String unknownIconCategoryId = await categoryRepo.createCategory(
      profileId: profileId,
      name: 'Mystery Category',
      type: 'expense',
      icon: 'some_future_icon_name_not_in_the_map',
    );
    await txRepo.recordExpense(
      profileId: profileId,
      accountId: accountId,
      amount: Money.fromMinorUnits(300, 'JPY'),
      categoryId: unknownIconCategoryId,
      note: 'unknown-icon-category',
      occurredAtUtc: nowUtc,
    );

    await txRepo.recordExpense(
      profileId: profileId,
      accountId: accountId,
      amount: Money.fromMinorUnits(400, 'JPY'),
      note: 'no-category-at-all',
      occurredAtUtc: nowUtc,
    );

    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithRouter(container));
    await tester.pumpAndSettle();

    // sys-dining's mapped icon.
    expect(find.byIcon(Icons.restaurant), findsOneWidget);
    // categoryIconFor's own safe fallback for an unrecognized (but
    // non-null) icon name -- proves that path never throws.
    expect(find.byIcon(Icons.category), findsOneWidget);
    // Both "a category with no icon set" and "no category at all" fall
    // back to the same plain expense icon Activity used before this
    // checkpoint -- two rows, safely, neither crashing nor rendering
    // nothing.
    expect(find.byIcon(Icons.remove), findsNWidgets(2));
  });

  testWidgets(
      'expense, income, and transfer rows stay visually distinguishable without relying on '
      'color alone, and each keeps its own amount sign convention', (tester) async {
    final (AppDatabase db, String profileId, String accountId) = await seededDb();
    final AccountRepository accountRepo = AccountRepository(db);
    final String secondAccountId = await accountRepo.createAccount(
      profileId: profileId,
      name: 'Savings',
      type: 'cash',
      currencyCode: 'JPY',
    );
    final TransactionRepository txRepo = TransactionRepository(db, accountRepo);
    final DateTime nowUtc = DateTime.now().toUtc();

    await txRepo.recordExpense(
      profileId: profileId,
      accountId: accountId,
      amount: Money.fromMinorUnits(1000, 'JPY'),
      occurredAtUtc: nowUtc,
    );
    await txRepo.recordIncome(
      profileId: profileId,
      accountId: accountId,
      amount: Money.fromMinorUnits(2000, 'JPY'),
      occurredAtUtc: nowUtc,
    );
    await txRepo.recordTransfer(
      profileId: profileId,
      sourceAccountId: accountId,
      destinationAccountId: secondAccountId,
      amount: Money.fromMinorUnits(3000, 'JPY'),
      occurredAtUtc: nowUtc,
    );

    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithRouter(container));
    await tester.pumpAndSettle();

    // Distinct icon shapes -- not just distinct colors.
    expect(find.byIcon(Icons.remove), findsOneWidget); // expense, no category
    expect(find.byIcon(Icons.add), findsOneWidget); // income, no category
    expect(find.byIcon(Icons.swap_horiz), findsOneWidget); // transfer

    // The existing sign-prefix convention is unchanged: '-' expense,
    // '+' income, no sign for transfer.
    expect(find.text('-¥1,000'), findsOneWidget);
    expect(find.text('+¥2,000'), findsOneWidget);
    expect(find.text('¥3,000'), findsOneWidget);

    // A third, non-visual signal (semantics), independent of icon shape
    // and color, for accessibility.
    expect(hasSemanticsLabel(tester, 'Expense'), isTrue);
    expect(hasSemanticsLabel(tester, 'Income'), isTrue);
    expect(hasSemanticsLabel(tester, 'Transfer'), isTrue);
  });

  testWidgets('tapping a transaction row navigates to its transaction detail screen',
      (tester) async {
    final (AppDatabase db, String profileId, String accountId) = await seededDb();
    final TransactionRepository txRepo = TransactionRepository(db, AccountRepository(db));
    await txRepo.recordExpense(
      profileId: profileId,
      accountId: accountId,
      amount: Money.fromMinorUnits(1200, 'JPY'),
      categoryId: 'sys-dining',
      note: 'Lunch',
      occurredAtUtc: DateTime.now().toUtc(),
    );

    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithRouter(container));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dining Out'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('editTransaction')), findsOneWidget);
    expect(find.byKey(const Key('deleteTransaction')), findsOneWidget);
  });

  // ---------------------------------------------------------------------
  // Checkpoint 3: search and type-filter tests.
  // ---------------------------------------------------------------------

  testWidgets('search matches by category name, case-insensitively', (tester) async {
    final (AppDatabase db, String _, String _, String _) = await seededDbWithSearchFixtures();
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithRouter(container));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'DiNiNg'); // mixed case, substring
    await tester.pumpAndSettle();

    expect(find.text('Dining Out'), findsOneWidget);
    expect(find.text('Salary'), findsNothing);
    expect(find.text('Wallet → Savings'), findsNothing);
  });

  testWidgets('search matches the source account name (every fixture shares it)', (tester) async {
    final (AppDatabase db, String _, String _, String _) = await seededDbWithSearchFixtures();
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithRouter(container));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'wallet');
    await tester.pumpAndSettle();

    expect(find.text('Dining Out'), findsOneWidget);
    expect(find.text('Salary'), findsOneWidget);
    expect(find.text('Wallet → Savings'), findsOneWidget);
  });

  testWidgets('search matches the transfer destination account name', (tester) async {
    final (AppDatabase db, String _, String _, String _) = await seededDbWithSearchFixtures();
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithRouter(container));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'savings');
    await tester.pumpAndSettle();

    expect(find.text('Wallet → Savings'), findsOneWidget);
    expect(find.text('Dining Out'), findsNothing);
    expect(find.text('Salary'), findsNothing);
  });

  testWidgets('search matches the note', (tester) async {
    final (AppDatabase db, String _, String _, String _) = await seededDbWithSearchFixtures();
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithRouter(container));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'lunch');
    await tester.pumpAndSettle();

    expect(find.text('Dining Out'), findsOneWidget);
    expect(find.text('Salary'), findsNothing);
    expect(find.text('Wallet → Savings'), findsNothing);
  });

  testWidgets('search matches the formatted amount', (tester) async {
    final (AppDatabase db, String _, String _, String _) = await seededDbWithSearchFixtures();
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithRouter(container));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '500,000');
    await tester.pumpAndSettle();

    expect(find.text('Salary'), findsOneWidget);
    expect(find.text('Dining Out'), findsNothing);
    expect(find.text('Wallet → Savings'), findsNothing);
  });

  testWidgets('Expense-only filter narrows to just the expense row', (tester) async {
    final (AppDatabase db, String _, String _, String _) = await seededDbWithSearchFixtures();
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithRouter(container));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, 'Expense'));
    await tester.pumpAndSettle();

    expect(find.text('Dining Out'), findsOneWidget);
    expect(find.text('Salary'), findsNothing);
    expect(find.text('Wallet → Savings'), findsNothing);
  });

  testWidgets('Income-only filter narrows to just the income row', (tester) async {
    final (AppDatabase db, String _, String _, String _) = await seededDbWithSearchFixtures();
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithRouter(container));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, 'Income'));
    await tester.pumpAndSettle();

    expect(find.text('Salary'), findsOneWidget);
    expect(find.text('Dining Out'), findsNothing);
    expect(find.text('Wallet → Savings'), findsNothing);
  });

  testWidgets('Transfer-only filter narrows to just the transfer row', (tester) async {
    final (AppDatabase db, String _, String _, String _) = await seededDbWithSearchFixtures();
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithRouter(container));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, 'Transfer'));
    await tester.pumpAndSettle();

    expect(find.text('Wallet → Savings'), findsOneWidget);
    expect(find.text('Dining Out'), findsNothing);
    expect(find.text('Salary'), findsNothing);
  });

  testWidgets(
      'multiple selected types are OR-ed together, and clearing back to an empty selection '
      'shows every type again', (tester) async {
    final (AppDatabase db, String _, String _, String _) = await seededDbWithSearchFixtures();
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithRouter(container));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, 'Expense'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Income'));
    await tester.pumpAndSettle();

    // Expense + Income selected -- both show, transfer hidden.
    expect(find.text('Dining Out'), findsOneWidget);
    expect(find.text('Salary'), findsOneWidget);
    expect(find.text('Wallet → Savings'), findsNothing);

    // Deselect both -- back to an empty type selection, which means
    // "show all", not "show none".
    await tester.tap(find.widgetWithText(FilterChip, 'Expense'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Income'));
    await tester.pumpAndSettle();

    expect(find.text('Dining Out'), findsOneWidget);
    expect(find.text('Salary'), findsOneWidget);
    expect(find.text('Wallet → Savings'), findsOneWidget);
  });

  testWidgets('a type filter and a search query combine with AND, not OR', (tester) async {
    final (AppDatabase db, String _, String _, String _) = await seededDbWithSearchFixtures();
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithRouter(container));
    await tester.pumpAndSettle();

    // 'wallet' alone would match all three (shared source account name),
    // but the Income filter should still narrow it to just Salary.
    await tester.tap(find.widgetWithText(FilterChip, 'Income'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'wallet');
    await tester.pumpAndSettle();

    expect(find.text('Salary'), findsOneWidget);
    expect(find.text('Dining Out'), findsNothing);
    expect(find.text('Wallet → Savings'), findsNothing);
  });

  testWidgets(
      'shows "No matching transactions" (not the true empty state) when transactions exist '
      'but the filter matches none', (tester) async {
    final (AppDatabase db, String _, String _, String _) = await seededDbWithSearchFixtures();
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithRouter(container));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, 'Income'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'transport'); // matches nothing income-typed
    await tester.pumpAndSettle();

    expect(find.text('No matching transactions'), findsOneWidget);
    expect(find.text('No transactions yet. Tap Add to record one.'), findsNothing);
    expect(find.text('Dining Out'), findsNothing);
    expect(find.text('Salary'), findsNothing);
  });

  testWidgets('Clear search clears only the query, leaving the type filter selected',
      (tester) async {
    final (AppDatabase db, String _, String _, String _) = await seededDbWithSearchFixtures();
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithRouter(container));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, 'Income'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'dining'); // narrows income+dining to nothing
    await tester.pumpAndSettle();
    expect(find.text('No matching transactions'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();

    // Query cleared -- but the Income filter is still active, so only
    // Salary (not Dining Out or the transfer) should reappear.
    final TextField field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, isEmpty);
    expect(find.text('Salary'), findsOneWidget);
    expect(find.text('Dining Out'), findsNothing);
    expect(find.text('Wallet → Savings'), findsNothing);
  });

  testWidgets('Clear filters clears both the query and every selected type, restoring the list',
      (tester) async {
    final (AppDatabase db, String _, String _, String _) = await seededDbWithSearchFixtures();
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithRouter(container));
    await tester.pumpAndSettle();

    // Select Income only (still one visible row, so exactly one "Clear
    // filters" button exists -- the no-match state's own button only
    // renders once the filtered result is empty).
    await tester.tap(find.widgetWithText(FilterChip, 'Income'));
    await tester.pumpAndSettle();
    expect(find.text('Salary'), findsOneWidget);
    expect(find.text('Dining Out'), findsNothing);

    await tester.tap(find.widgetWithText(TextButton, 'Clear filters'));
    await tester.pumpAndSettle();

    final TextField field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, isEmpty);
    expect(find.text('Dining Out'), findsOneWidget);
    expect(find.text('Salary'), findsOneWidget);
    expect(find.text('Wallet → Savings'), findsOneWidget);
  });

  testWidgets(
      'leaving Activity and coming back starts from a fresh, unfiltered filter state '
      '(filter state is screen-local, never persisted)', (tester) async {
    final (AppDatabase db, String _, String _, String _) = await seededDbWithSearchFixtures();
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    final (Widget app, GoRouter router) = appWithNavigableRouter(container);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'dining');
    await tester.pumpAndSettle();
    expect(find.text('Salary'), findsNothing); // narrowed by the search above

    router.go('/elsewhere');
    await tester.pumpAndSettle();
    // A second settle for the same reason Checkpoint 1/2 needed it
    // elsewhere in this codebase: leaving Activity disposes
    // `categoriesForTypeProvider` (a Drift-backed `autoDispose` family),
    // whose underlying `StreamQueryStore` schedules a zero-duration
    // cleanup `Timer` that doesn't always drain within a single
    // `pumpAndSettle()` right after the disposing navigation.
    await tester.pumpAndSettle();
    expect(find.text('Elsewhere'), findsOneWidget);

    router.go(AppRoutes.activity);
    await tester.pumpAndSettle();

    // A freshly-built ActivityScreen -- the search field is empty again
    // and the previously-filtered-out transaction is back.
    final TextField field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, isEmpty);
    expect(find.text('Dining Out'), findsOneWidget);
    expect(find.text('Salary'), findsOneWidget);
    expect(find.text('Wallet → Savings'), findsOneWidget);
  });
}
