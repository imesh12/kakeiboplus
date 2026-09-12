import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/providers.dart';
import 'package:ai_financial_coach/core/database/repositories/account_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/category_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/transaction_repository.dart';
import 'package:ai_financial_coach/core/money/money.dart';
import 'package:ai_financial_coach/core/money/money_formatter.dart';
import 'package:ai_financial_coach/core/routing/app_routes.dart';
import 'package:ai_financial_coach/features/transactions/presentation/activity_screen.dart';
import 'package:ai_financial_coach/features/transactions/presentation/transaction_detail_screen.dart';
import 'package:ai_financial_coach/l10n/generated/app_localizations.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../support/rtl_harness.dart';

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

// Checkpoint 2 (International / Localization Foundation) large-amount
// hardening tests use the SAME MoneyFormatter convention every existing
// Activity row test above already relies on, to build the exact expected
// rendered string -- never a hand-typed string guess.
const MoneyFormatter formatter = MoneyFormatter();

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

  // CP5.6: `{bool rtl = false}` threads an RTL `Directionality` through
  // `MaterialApp.router`'s own `builder:` -- see
  // `test/support/rtl_harness.dart`.
  // CP6.4: `ActivityScreen` now reads `AppLocalizations.of(context)`, so
  // this harness needs the same localization wiring already established
  // in `add_transaction_screen_test.dart`'s `appWithPushedScreen()` and
  // `app_shell_test.dart`'s `buildApp()` -- `{Locale locale = const
  // Locale('en')}` keeps every pre-existing English test passing
  // unchanged, while the new Japanese-proof tests pass `locale: const
  // Locale('ja')`.
  Widget appWithRouter(
    ProviderContainer container, {
    bool rtl = false,
    Locale locale = const Locale('en'),
  }) {
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
      child: MaterialApp.router(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
        builder: rtl ? rtlAppBuilder : null,
      ),
    );
  }

  /// Like [appWithRouter], but also registers a trivial second route so
  /// Checkpoint 3's disposal test can navigate away from
  /// [ActivityScreen] and back without needing anything from the real
  /// route table -- returns the [GoRouter] itself so the test can drive
  /// navigation directly (`router.go(...)`) rather than simulating taps.
  // CP6.4: same localization wiring as `appWithRouter` above -- see its
  // comment for why.
  (Widget, GoRouter) appWithNavigableRouter(
    ProviderContainer container, {
    Locale locale = const Locale('en'),
  }) {
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
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
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

  // ---------------------------------------------------------------------
  // International / Localization Foundation, Checkpoint 2: large-amount
  // Activity layout hardening. `_TransactionRow` no longer uses
  // `ListTile` -- see its class doc comment in `activity_screen.dart` --
  // specifically to survive long formatted amounts (large VND/MMK-scale
  // values, KWD's extra minor-unit digit) at narrow widths and/or larger
  // text scales without ever ellipsizing/shrinking/dropping a digit from
  // the amount itself. These tests assert absence of any layout
  // exception and presence of the complete formatted amount string --
  // never pixel coordinates.
  // ---------------------------------------------------------------------

  testWidgets('a large MMK expense amount renders in full with no layout overflow',
      (tester) async {
    final (AppDatabase db, String profileId, String _) = await seededDb();
    final AccountRepository accountRepo = AccountRepository(db);
    final String mmkAccountId = await accountRepo.createAccount(
      profileId: profileId,
      name: 'Myanmar Wallet',
      type: 'cash',
      currencyCode: 'MMK',
    );
    final TransactionRepository txRepo = TransactionRepository(db, accountRepo);
    final Money amount = Money.fromMinorUnits(987654321, 'MMK'); // 9,876,543.21 MMK
    await txRepo.recordExpense(
      profileId: profileId,
      accountId: mmkAccountId,
      amount: amount,
      categoryId: 'sys-dining',
      occurredAtUtc: DateTime.now().toUtc(),
    );

    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithRouter(container));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('-${formatter.format(amount)}'), findsOneWidget);
  });

  testWidgets('a large VND income amount renders in full with no layout overflow',
      (tester) async {
    final (AppDatabase db, String profileId, String _) = await seededDb();
    final AccountRepository accountRepo = AccountRepository(db);
    final String vndAccountId = await accountRepo.createAccount(
      profileId: profileId,
      name: 'Vietnam Wallet',
      type: 'cash',
      currencyCode: 'VND',
    );
    final TransactionRepository txRepo = TransactionRepository(db, accountRepo);
    final Money amount = Money.fromMinorUnits(987654321, 'VND'); // 987,654,321 VND (0 minor units)
    await txRepo.recordIncome(
      profileId: profileId,
      accountId: vndAccountId,
      amount: amount,
      categoryId: 'sys-salary',
      occurredAtUtc: DateTime.now().toUtc(),
    );

    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithRouter(container));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('+${formatter.format(amount)}'), findsOneWidget);
  });

  testWidgets(
      'a KWD amount with 3 minor-unit decimals renders in full with no layout overflow',
      (tester) async {
    final (AppDatabase db, String profileId, String _) = await seededDb();
    final AccountRepository accountRepo = AccountRepository(db);
    final String kwdAccountId = await accountRepo.createAccount(
      profileId: profileId,
      name: 'Kuwait Wallet',
      type: 'cash',
      currencyCode: 'KWD',
    );
    final TransactionRepository txRepo = TransactionRepository(db, accountRepo);
    final Money amount = Money.fromMinorUnits(987654, 'KWD'); // 987.654 KWD
    await txRepo.recordExpense(
      profileId: profileId,
      accountId: kwdAccountId,
      amount: amount,
      occurredAtUtc: DateTime.now().toUtc(),
    );

    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithRouter(container));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('-${formatter.format(amount)}'), findsOneWidget);
  });

  testWidgets('a transfer row with a large amount renders in full with no layout overflow',
      (tester) async {
    final (AppDatabase db, String profileId, String _) = await seededDb();
    final AccountRepository accountRepo = AccountRepository(db);
    final String sourceId = await accountRepo.createAccount(
      profileId: profileId,
      name: 'MMK Primary',
      type: 'cash',
      currencyCode: 'MMK',
    );
    final String destinationId = await accountRepo.createAccount(
      profileId: profileId,
      name: 'MMK Savings',
      type: 'cash',
      currencyCode: 'MMK',
    );
    final TransactionRepository txRepo = TransactionRepository(db, accountRepo);
    final Money amount = Money.fromMinorUnits(500000000, 'MMK'); // 5,000,000.00 MMK
    await txRepo.recordTransfer(
      profileId: profileId,
      sourceAccountId: sourceId,
      destinationAccountId: destinationId,
      amount: amount,
      occurredAtUtc: DateTime.now().toUtc(),
    );

    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithRouter(container));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Transfer rows carry no sign prefix -- unchanged from before this checkpoint.
    expect(find.text(formatter.format(amount)), findsOneWidget);
    expect(find.text('MMK Primary → MMK Savings'), findsOneWidget);
  });

  testWidgets(
      'the row lays out without overflow on a narrow (320px-wide) surface with a large amount',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1.0;

    final (AppDatabase db, String profileId, String _) = await seededDb();
    final AccountRepository accountRepo = AccountRepository(db);
    final String vndAccountId = await accountRepo.createAccount(
      profileId: profileId,
      name: 'Vietnam Wallet',
      type: 'cash',
      currencyCode: 'VND',
    );
    final TransactionRepository txRepo = TransactionRepository(db, accountRepo);
    final Money amount = Money.fromMinorUnits(987654321, 'VND');
    await txRepo.recordExpense(
      profileId: profileId,
      accountId: vndAccountId,
      amount: amount,
      categoryId: 'sys-dining',
      occurredAtUtc: DateTime.now().toUtc(),
    );

    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithRouter(container));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('-${formatter.format(amount)}'), findsOneWidget);
  });

  testWidgets(
      'the row lays out without overflow at an increased text scale with a large amount',
      (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final (AppDatabase db, String profileId, String _) = await seededDb();
    final AccountRepository accountRepo = AccountRepository(db);
    final String mmkAccountId = await accountRepo.createAccount(
      profileId: profileId,
      name: 'Myanmar Wallet',
      type: 'cash',
      currencyCode: 'MMK',
    );
    final TransactionRepository txRepo = TransactionRepository(db, accountRepo);
    final Money amount = Money.fromMinorUnits(987654321, 'MMK');
    await txRepo.recordExpense(
      profileId: profileId,
      accountId: mmkAccountId,
      amount: amount,
      categoryId: 'sys-dining',
      occurredAtUtc: DateTime.now().toUtc(),
    );

    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithRouter(container));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('-${formatter.format(amount)}'), findsOneWidget);
  });

  testWidgets(
      'the row lays out without overflow with narrow width AND an increased text scale '
      'together', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final (AppDatabase db, String profileId, String _) = await seededDb();
    final AccountRepository accountRepo = AccountRepository(db);
    final String vndAccountId = await accountRepo.createAccount(
      profileId: profileId,
      name: 'Vietnam Wallet',
      type: 'cash',
      currencyCode: 'VND',
    );
    final TransactionRepository txRepo = TransactionRepository(db, accountRepo);
    final Money amount = Money.fromMinorUnits(987654321, 'VND');
    await txRepo.recordExpense(
      profileId: profileId,
      accountId: vndAccountId,
      amount: amount,
      categoryId: 'sys-dining',
      occurredAtUtc: DateTime.now().toUtc(),
    );

    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithRouter(container));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('-${formatter.format(amount)}'), findsOneWidget);
    // This worst-case combination is exactly what's expected to push the
    // row into the stacked arrangement -- see the dedicated structural
    // test below for the direct proof via the `transactionRowStacked` key.
    expect(find.byKey(const Key('transactionRowStacked')), findsOneWidget);
  });

  testWidgets(
      'long account/category/descriptive text together with a long amount lays out without '
      'overflow, and the title ellipsizes rather than squeezing the amount', (tester) async {
    final (AppDatabase db, String profileId, String _) = await seededDb();
    final AccountRepository accountRepo = AccountRepository(db);
    final String sourceId = await accountRepo.createAccount(
      profileId: profileId,
      name: 'International Kuwaiti Dinar Primary Household Wallet',
      type: 'cash',
      currencyCode: 'KWD',
    );
    final String destinationId = await accountRepo.createAccount(
      profileId: profileId,
      name: 'Overseas Long Term Kuwaiti Dinar Savings Reserve Account',
      type: 'cash',
      currencyCode: 'KWD',
    );
    final TransactionRepository txRepo = TransactionRepository(db, accountRepo);
    final Money amount = Money.fromMinorUnits(987654321, 'KWD'); // 987,654.321 KWD
    await txRepo.recordTransfer(
      profileId: profileId,
      sourceAccountId: sourceId,
      destinationAccountId: destinationId,
      amount: amount,
      occurredAtUtc: DateTime.now().toUtc(),
    );

    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithRouter(container));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final String expectedAmount = formatter.format(amount);
    const String fullTransferTitle =
        'International Kuwaiti Dinar Primary Household Wallet → '
        'Overseas Long Term Kuwaiti Dinar Savings Reserve Account';

    // The full amount is always present in full -- never ellipsized.
    expect(find.text(expectedAmount), findsOneWidget);

    // The long combined transfer title is exactly the element this policy
    // allows to ellipsize. Asserted structurally on the Text widget's own
    // configuration -- maxLines and overflow -- rather than on rendered
    // output, so this does not depend on RenderParagraph/rendering.dart.
    final Finder titleFinder = find.text(fullTransferTitle);
    expect(titleFinder, findsOneWidget);

    final Text titleText = tester.widget<Text>(titleFinder);
    expect(titleText.maxLines, 1);
    expect(titleText.overflow, TextOverflow.ellipsis);

    expect(find.text(expectedAmount), findsOneWidget);
  });

  testWidgets('tapping a transaction row with a large amount still navigates to transaction '
      'detail', (tester) async {
    final (AppDatabase db, String profileId, String _) = await seededDb();
    final AccountRepository accountRepo = AccountRepository(db);
    final String mmkAccountId = await accountRepo.createAccount(
      profileId: profileId,
      name: 'Myanmar Wallet',
      type: 'cash',
      currencyCode: 'MMK',
    );
    final TransactionRepository txRepo = TransactionRepository(db, accountRepo);
    final Money amount = Money.fromMinorUnits(987654321, 'MMK');
    await txRepo.recordExpense(
      profileId: profileId,
      accountId: mmkAccountId,
      amount: amount,
      categoryId: 'sys-dining',
      note: 'Big purchase',
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
  });

  testWidgets('the row uses the horizontal layout at normal width, not the stacked one',
      (tester) async {
    final (AppDatabase db, String profileId, String _) = await seededDb();
    final AccountRepository accountRepo = AccountRepository(db);
    final String vndAccountId = await accountRepo.createAccount(
      profileId: profileId,
      name: 'Vietnam Wallet',
      type: 'cash',
      currencyCode: 'VND',
    );
    final TransactionRepository txRepo = TransactionRepository(db, accountRepo);
    final Money amount = Money.fromMinorUnits(987654321, 'VND');
    await txRepo.recordExpense(
      profileId: profileId,
      accountId: vndAccountId,
      amount: amount,
      categoryId: 'sys-dining',
      occurredAtUtc: DateTime.now().toUtc(),
    );

    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithRouter(container));
    await tester.pumpAndSettle();

    // Plenty of room at the default widget-test surface size -- this is
    // the direct structural proof (a Key, not a pixel coordinate) that
    // the horizontal arrangement is what's actually built here.
    expect(find.byKey(const Key('transactionRowHorizontal')), findsOneWidget);
    expect(find.byKey(const Key('transactionRowStacked')), findsNothing);
  });

  testWidgets(
      'the same row/data switches to the stacked layout once genuinely constrained by width '
      'and text scale', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final (AppDatabase db, String profileId, String _) = await seededDb();
    final AccountRepository accountRepo = AccountRepository(db);
    final String vndAccountId = await accountRepo.createAccount(
      profileId: profileId,
      name: 'Vietnam Wallet',
      type: 'cash',
      currencyCode: 'VND',
    );
    final TransactionRepository txRepo = TransactionRepository(db, accountRepo);
    final Money amount = Money.fromMinorUnits(987654321, 'VND');
    await txRepo.recordExpense(
      profileId: profileId,
      accountId: vndAccountId,
      amount: amount,
      categoryId: 'sys-dining',
      occurredAtUtc: DateTime.now().toUtc(),
    );

    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithRouter(container));
    await tester.pumpAndSettle();

    // Same fixture as the horizontal-layout test above, now genuinely
    // constrained -- the direct structural proof (via Key, independent
    // of any pixel coordinate) that the adaptive layout is actually
    // exercised, not just that no exception happened to be thrown.
    expect(find.byKey(const Key('transactionRowStacked')), findsOneWidget);
    expect(find.byKey(const Key('transactionRowHorizontal')), findsNothing);
  });

  testWidgets(
      'CP5.6: RTL + text-scale stress -- a narrow 320px width, 1.6x text scale, a long '
      'descriptive note, and a large international (VND) amount together under RTL, with '
      "the amount expected to hug the stacked row's reading-end edge", (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final (AppDatabase db, String profileId, String _) = await seededDb();
    final AccountRepository accountRepo = AccountRepository(db);
    final String vndAccountId = await accountRepo.createAccount(
      profileId: profileId,
      name: 'Vietnam Wallet',
      type: 'cash',
      currencyCode: 'VND',
    );
    final TransactionRepository txRepo = TransactionRepository(db, accountRepo);
    final Money amount = Money.fromMinorUnits(987654321, 'VND'); // ₫987,654,321
    await txRepo.recordExpense(
      profileId: profileId,
      accountId: vndAccountId,
      amount: amount,
      categoryId: 'sys-dining',
      note: 'A rather long note to stress narrow-width description content',
      occurredAtUtc: DateTime.now().toUtc(),
    );

    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithRouter(container, rtl: true));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final Finder rowLayout = find.byKey(const Key('transactionRowStacked'));
    expect(rowLayout, findsOneWidget);
    final Finder amountText =
        find.descendant(of: rowLayout, matching: find.textContaining('987,654,321'));
    expect(amountText, findsOneWidget);
    expect(
      find.descendant(of: rowLayout, matching: find.textContaining('Dining Out')),
      findsOneWidget,
    );

    // `activity_screen.dart`'s stacked fallback explicitly keeps the
    // amount "right-aligned" (its own comment) via a physical
    // `Alignment.centerRight`, matching the horizontal Row's trailing
    // placement in LTR. But `Row` mirrors its trailing child to the
    // physical LEFT under RTL (a `Row`'s last child sits at the "end",
    // which is left in RTL) -- while the hardcoded `Alignment.centerRight`
    // stays physically right regardless of direction. CP5.6's audit
    // expects the amount to also move to the row's left/end edge under
    // RTL for consistency with the horizontal layout; this assertion
    // demonstrates whether that's actually the case today -- see CP5.6
    // report finding B.
    final double rowLeft = tester.getTopLeft(rowLayout).dx;
    final double amountLeft = tester.getTopLeft(amountText).dx;
    expect(
      amountLeft,
      closeTo(rowLeft, 1.0),
      reason: "expected the amount to hug the stacked row's reading-end edge "
          "(the row's left edge under RTL), matching how the horizontal layout's "
          'trailing amount already mirrors',
    );
  });

  // ============================================================
  // CP6.4 (Localization Phase 1, Activity): exercises the REAL
  // `ActivityScreen` under a real Japanese locale -- same pattern
  // established in CP6.1-6.3. Every existing test above this point
  // keeps its default `locale: const Locale('en')`, so all pre-existing
  // English assertions -- including the CP5.6 RTL test just above --
  // are unaffected by this section.
  // ============================================================

  group('CP6.4 Japanese localization', () {
    testWidgets(
      'A: standard Japanese Activity -- principal labels render in Japanese, no render '
      'exceptions',
      (tester) async {
        final (AppDatabase db, String _, String _, String _) = await seededDbWithSearchFixtures();
        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRouter(container, locale: const Locale('ja')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('アクティビティ'), findsOneWidget); // AppBar title (reuses navActivity)
        expect(find.widgetWithText(FilterChip, '支出'), findsOneWidget);
        expect(find.widgetWithText(FilterChip, '収入'), findsOneWidget);
        expect(find.widgetWithText(FilterChip, '振替'), findsOneWidget);
        // User/database content (category and account names) renders
        // exactly as stored, in English, under the Japanese UI.
        expect(find.text('Dining Out'), findsOneWidget);
        expect(find.text('Salary'), findsOneWidget);
        expect(find.text('Wallet → Savings'), findsOneWidget);
      },
    );

    testWidgets(
      'B: the Japanese-labeled filter chips still select the correct transactions, and '
      'clearing filters via the localized button restores the full list -- the underlying '
      'TransactionType enum values never change',
      (tester) async {
        final (AppDatabase db, String _, String _, String _) = await seededDbWithSearchFixtures();
        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRouter(container, locale: const Locale('ja')));
        await tester.pumpAndSettle();

        // Tap the Japanese "支出" (Expense) chip -- narrows to just the
        // expense row, exactly like the existing English-locale
        // "Expense-only filter" test, proving the filter predicate is
        // still keyed by `TransactionType.expense`, not by the chip's
        // visible text.
        await tester.tap(find.widgetWithText(FilterChip, '支出'));
        await tester.pumpAndSettle();

        expect(find.text('Dining Out'), findsOneWidget);
        expect(find.text('Salary'), findsNothing);
        expect(find.text('Wallet → Savings'), findsNothing);

        await tester.tap(find.widgetWithText(TextButton, 'フィルターをクリア'));
        await tester.pumpAndSettle();

        expect(find.text('Dining Out'), findsOneWidget);
        expect(find.text('Salary'), findsOneWidget);
        expect(find.text('Wallet → Savings'), findsOneWidget);
      },
    );

    testWidgets(
      'C: Japanese date-group headers ("today"/"yesterday") render correctly and preserve '
      'the same grouping/order behavior as the English-locale equivalent',
      (tester) async {
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

        await tester.pumpWidget(appWithRouter(container, locale: const Locale('ja')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        // Same one-section-per-day grouping as the English-locale test --
        // the two "today" transactions still share a single section
        // (grouping is keyed by `dateKey`, never by the displayed label).
        expect(find.text('今日'), findsOneWidget);
        expect(find.text('昨日'), findsOneWidget);
        expect(find.textContaining('today-a'), findsOneWidget);
        expect(find.textContaining('today-b'), findsOneWidget);
        expect(find.textContaining('yesterday-a'), findsOneWidget);
      },
    );

    testWidgets(
      'D: Japanese Activity renders a large MMK (2-decimal) expense amount in full, with no '
      'ellipsis/clipping/dropped digits and no render exceptions',
      (tester) async {
        final (AppDatabase db, String profileId, String _) = await seededDb();
        final AccountRepository accountRepo = AccountRepository(db);
        final String mmkAccountId = await accountRepo.createAccount(
          profileId: profileId,
          name: 'Myanmar Wallet',
          type: 'cash',
          currencyCode: 'MMK',
        );
        final TransactionRepository txRepo = TransactionRepository(db, accountRepo);
        final Money amount = Money.fromMinorUnits(987654321, 'MMK'); // 9,876,543.21 MMK
        await txRepo.recordExpense(
          profileId: profileId,
          accountId: mmkAccountId,
          amount: amount,
          categoryId: 'sys-dining',
          occurredAtUtc: DateTime.now().toUtc(),
        );

        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRouter(container, locale: const Locale('ja')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        // Every digit (and MMK's registry-defined 2 decimal places --
        // never 0) still renders in full alongside the Japanese UI.
        expect(find.text('-${formatter.format(amount)}'), findsOneWidget);
      },
    );

    testWidgets(
      'E: Japanese Activity keeps a large KWD amount fully intact alongside long account '
      'names, ellipsizing only the descriptive title -- never the amount',
      (tester) async {
        final (AppDatabase db, String profileId, String _) = await seededDb();
        final AccountRepository accountRepo = AccountRepository(db);
        final String sourceId = await accountRepo.createAccount(
          profileId: profileId,
          name: 'International Kuwaiti Dinar Primary Household Wallet',
          type: 'cash',
          currencyCode: 'KWD',
        );
        final String destinationId = await accountRepo.createAccount(
          profileId: profileId,
          name: 'Overseas Long Term Kuwaiti Dinar Savings Reserve Account',
          type: 'cash',
          currencyCode: 'KWD',
        );
        final TransactionRepository txRepo = TransactionRepository(db, accountRepo);
        final Money amount = Money.fromMinorUnits(987654321, 'KWD'); // 987,654.321 KWD
        await txRepo.recordTransfer(
          profileId: profileId,
          sourceAccountId: sourceId,
          destinationAccountId: destinationId,
          amount: amount,
          occurredAtUtc: DateTime.now().toUtc(),
        );

        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRouter(container, locale: const Locale('ja')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final String expectedAmount = formatter.format(amount);
        expect(find.text(expectedAmount), findsOneWidget);

        const String fullTransferTitle =
            'International Kuwaiti Dinar Primary Household Wallet → '
            'Overseas Long Term Kuwaiti Dinar Savings Reserve Account';
        final Finder titleFinder = find.text(fullTransferTitle);
        expect(titleFinder, findsOneWidget);
        final Text titleText = tester.widget<Text>(titleFinder);
        expect(titleText.maxLines, 1);
        expect(titleText.overflow, TextOverflow.ellipsis);
      },
    );

    testWidgets(
      'F: Japanese Activity at 1.6x text scale remains renderable, and the localized filter '
      'chips remain usable, with no overflow/render exceptions',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 1.6;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        final (AppDatabase db, String _, String _, String _) = await seededDbWithSearchFixtures();
        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRouter(container, locale: const Locale('ja')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.widgetWithText(FilterChip, '支出'), findsOneWidget);
        expect(find.widgetWithText(FilterChip, '収入'), findsOneWidget);
        expect(find.widgetWithText(FilterChip, '振替'), findsOneWidget);

        await tester.tap(find.widgetWithText(FilterChip, '収入'));
        await tester.pumpAndSettle();
        expect(find.text('Salary'), findsOneWidget);
        expect(find.text('Dining Out'), findsNothing);
      },
    );

    testWidgets(
      'G: Japanese Activity at 2.0x text scale keeps key content usable/readable, with no '
      'overflow/render exceptions',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        final (AppDatabase db, String profileId, String accountId) = await seededDb();
        final TransactionRepository txRepo = TransactionRepository(db, AccountRepository(db));
        await txRepo.recordExpense(
          profileId: profileId,
          accountId: accountId,
          amount: Money.fromMinorUnits(1200, 'JPY'),
          categoryId: 'sys-dining',
          note: 'Lunch with team',
          occurredAtUtc: DateTime.now().toUtc(),
        );

        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRouter(container, locale: const Locale('ja')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('今日'), findsOneWidget);
        expect(find.text('Dining Out'), findsOneWidget);
      },
    );

    testWidgets(
      'H: Japanese Activity at 320px width with enlarged text keeps a large VND amount fully '
      'intact alongside a long note, using the stacked row arrangement',
      (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1.0;
        tester.platformDispatcher.textScaleFactorTestValue = 1.6;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        final (AppDatabase db, String profileId, String _) = await seededDb();
        final AccountRepository accountRepo = AccountRepository(db);
        final String vndAccountId = await accountRepo.createAccount(
          profileId: profileId,
          name: 'Vietnam Wallet',
          type: 'cash',
          currencyCode: 'VND',
        );
        final TransactionRepository txRepo = TransactionRepository(db, accountRepo);
        final Money amount = Money.fromMinorUnits(987654321, 'VND'); // ₫987,654,321
        await txRepo.recordExpense(
          profileId: profileId,
          accountId: vndAccountId,
          amount: amount,
          categoryId: 'sys-dining',
          note: 'A rather long note to stress narrow-width description content',
          occurredAtUtc: DateTime.now().toUtc(),
        );

        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRouter(container, locale: const Locale('ja')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final Finder rowLayout = find.byKey(const Key('transactionRowStacked'));
        expect(rowLayout, findsOneWidget);
        expect(
          find.descendant(of: rowLayout, matching: find.textContaining('987,654,321')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: rowLayout, matching: find.textContaining('Dining Out')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'I: navigation regression -- tapping a transaction row still navigates to transaction '
      'detail under the Japanese locale',
      (tester) async {
        final (AppDatabase db, String profileId, String accountId) = await seededDb();
        final TransactionRepository txRepo = TransactionRepository(db, AccountRepository(db));
        await txRepo.recordExpense(
          profileId: profileId,
          accountId: accountId,
          amount: Money.fromMinorUnits(1200, 'JPY'),
          categoryId: 'sys-dining',
          note: 'Lunch with team',
          occurredAtUtc: DateTime.now().toUtc(),
        );

        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRouter(container, locale: const Locale('ja')));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Dining Out'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('editTransaction')), findsOneWidget);
      },
    );
  });
}
