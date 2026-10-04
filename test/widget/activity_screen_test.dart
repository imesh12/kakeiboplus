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
import 'package:ai_financial_coach/shared/theme/app_theme.dart';
import 'package:ai_financial_coach/shared/theme/app_tokens.dart';
import 'package:ai_financial_coach/shared/widgets/app_icon_tile.dart';
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
    // UI/Icon Polish checkpoint: optional, additive -- `null` (every
    // pre-existing call site) is pixel-identical to before, since
    // `MaterialApp.router`'s own `theme` default (a plain `ThemeData()`
    // with no `AppTokens` extension registered) is exactly what
    // omitting this parameter already produced. Only a test that
    // explicitly needs a REAL theme -- i.e. one that registers
    // `AppTokens.positiveGradient`/`negativeGradient` via
    // `AppTheme.light()`/`.dark()` (`Pink`/`Ocean`/`Forest` deliberately
    // leave those two `null`, see `app_theme.dart`) -- passes one.
    ThemeData? theme,
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
        theme: theme,
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

    // sys-dining's mapped icon -- UI/Icon Polish checkpoint: 'restaurant'
    // now has curated artwork (`category_icon_asset.dart`), so this row
    // renders via `Image.asset` through `TransactionIconBadge`, not the
    // `Icons.restaurant` glyph directly. This still proves the exact
    // same thing the test's own name promises ("renders the resolved
    // category icon") -- just via the new, intentionally-upgraded
    // rendering path for a mapped key, not a regression in the glyph
    // resolver itself (which `category_icon_asset_test.dart`/
    // `category_icon_test.dart` cover directly).
    expect(find.byIcon(Icons.restaurant), findsNothing);
    expect(find.byType(Image), findsOneWidget);
    expect(
      (tester.widget<Image>(find.byType(Image)).image as AssetImage).assetName,
      'assets/icons/categories/dining_out.png',
    );
    // categoryIconFor's own safe fallback for an unrecognized (but
    // non-null) icon name -- proves that path never throws. This
    // category's icon is the literal string
    // 'some_future_icon_name_not_in_the_map', which has no entry in
    // either `category_icon.dart`'s glyph map or
    // `category_icon_asset.dart`'s curated asset map, so it stays a
    // plain Icon rendering the generic `Icons.category` fallback glyph.
    // (As of the Category Icon Source Correction checkpoint, the
    // literal string `'category'` itself DOES have curated artwork --
    // see `category_icon_asset_test.dart` -- but that is a different,
    // specific key from the genuinely-unrecognized one this row uses,
    // so it does not affect this assertion.)
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

  // ---------------------------------------------------------------------
  // Visual System Convergence Checkpoint 7.3: locks in the transaction
  // row's new bordered-card visual treatment (`AppCard(bordered: true)`)
  // via the same shape/side/color contract `app_card_test.dart` already
  // asserts for `AppCard` itself -- never a pixel value, so this stays
  // resilient to future spacing/radius tuning.
  // ---------------------------------------------------------------------
  testWidgets(
      'CP7.3: a transaction row renders inside a bordered, near-white card matching the '
      'converged visual system', (tester) async {
    final (AppDatabase db, String profileId, String accountId) = await seededDb();
    final TransactionRepository txRepo = TransactionRepository(db, AccountRepository(db));
    await txRepo.recordExpense(
      profileId: profileId,
      accountId: accountId,
      amount: Money.fromMinorUnits(1200, 'JPY'),
      categoryId: 'sys-dining',
      occurredAtUtc: DateTime.now().toUtc(),
    );

    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithRouter(container));
    await tester.pumpAndSettle();

    final Finder rowLayout = find.byKey(const Key('transactionRowHorizontal'));
    final Card cardWidget = tester.widget<Card>(
      find.ancestor(of: rowLayout, matching: find.byType(Card)).first,
    );
    final BuildContext context = tester.element(rowLayout);
    final ColorScheme colors = Theme.of(context).colorScheme;
    final AppTokens tokens = context.appTokens;

    expect(cardWidget.color, colors.surface);
    expect(cardWidget.elevation, 0);
    final RoundedRectangleBorder shape = cardWidget.shape! as RoundedRectangleBorder;
    expect(shape.side.color, tokens.colors.subtleBorder);
  });

  // ---------------------------------------------------------------------
  // Account Lifecycle UX polish: a transaction referencing a CURRENTLY
  // closed account keeps rendering exactly as before (real name, full
  // history, no disabled/error look) with a small muted "Closed" label
  // added beside that account's name -- resolved fresh from
  // `allAccountsProvider` at presentation time, never written into the
  // transaction row itself.
  // ---------------------------------------------------------------------
  group('Account Lifecycle UX polish: Closed indicator', () {
    testWidgets(
      'A: an active account\'s historical transaction shows its name with no Closed label',
      (tester) async {
        final (AppDatabase db, String profileId, String accountId) = await seededDb();
        final TransactionRepository txRepo = TransactionRepository(db, AccountRepository(db));
        await txRepo.recordExpense(
          profileId: profileId,
          accountId: accountId,
          amount: Money.fromMinorUnits(1200, 'JPY'),
          occurredAtUtc: DateTime.now().toUtc(),
        );
        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRouter(container));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Wallet'), findsOneWidget);
        expect(find.text('Wallet · Closed'), findsNothing);
        expect(find.textContaining('Closed'), findsNothing);
      },
    );

    testWidgets(
      'B: a closed account\'s historical transaction remains visible, keeps its original '
      'account name, and shows a small Closed label',
      (tester) async {
        final (AppDatabase db, String profileId, String accountId) = await seededDb();
        final TransactionRepository txRepo = TransactionRepository(db, AccountRepository(db));
        await txRepo.recordExpense(
          profileId: profileId,
          accountId: accountId,
          amount: Money.fromMinorUnits(1200, 'JPY'),
          occurredAtUtc: DateTime.now().toUtc(),
        );
        await AccountRepository(db).softDelete(accountId);
        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRouter(container));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        // The transaction itself is still fully present -- amount and
        // category still render exactly as an active account's would.
        expect(find.text('-¥1,200'), findsOneWidget);
        // Real account name preserved, with the small muted label right
        // beside it -- not a strikethrough, not an error color, not a
        // separate "this transaction is invalid" state.
        expect(find.text('Wallet · Closed'), findsOneWidget);
      },
    );

    testWidgets(
      'D: reactivating the account removes the Closed label from its still-existing historical '
      'transaction, without touching the transaction itself',
      (tester) async {
        final (AppDatabase db, String profileId, String accountId) = await seededDb();
        final TransactionRepository txRepo = TransactionRepository(db, AccountRepository(db));
        final String txId = await txRepo.recordExpense(
          profileId: profileId,
          accountId: accountId,
          amount: Money.fromMinorUnits(1200, 'JPY'),
          occurredAtUtc: DateTime.now().toUtc(),
        );
        final AccountRepository accountRepo = AccountRepository(db);
        await accountRepo.softDelete(accountId);
        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRouter(container));
        await tester.pumpAndSettle();
        expect(find.text('Wallet · Closed'), findsOneWidget);

        await accountRepo.reactivate(accountId);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        // Same historical transaction, same account name, label gone.
        expect(find.text('-¥1,200'), findsOneWidget);
        expect(find.text('Wallet'), findsOneWidget);
        expect(find.text('Wallet · Closed'), findsNothing);
        expect(find.textContaining('Closed'), findsNothing);
        final Transaction stillThere = await (db.select(db.transactions)
              ..where((tbl) => tbl.id.equals(txId)))
            .getSingle();
        expect(stillThere.deletedAt, isNull);
        expect(stillThere.amountMinorUnits, 1200);
      },
    );

    testWidgets(
      'E1: a transfer with a closed DESTINATION account marks only that side, not the source',
      (tester) async {
        final (AppDatabase db, String profileId, String sourceId) = await seededDb();
        final AccountRepository accountRepo = AccountRepository(db);
        final String destinationId = await accountRepo.createAccount(
          profileId: profileId,
          name: 'Savings',
          type: 'cash',
          currencyCode: 'JPY',
        );
        await accountRepo.softDelete(destinationId);
        final TransactionRepository txRepo = TransactionRepository(db, accountRepo);
        await txRepo.recordTransfer(
          profileId: profileId,
          sourceAccountId: sourceId,
          destinationAccountId: destinationId,
          amount: Money.fromMinorUnits(3000, 'JPY'),
          occurredAtUtc: DateTime.now().toUtc(),
        );
        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRouter(container));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.textContaining('Wallet'), findsOneWidget);
        expect(find.textContaining('Savings'), findsOneWidget);
        // The closed side (destination) carries the label; the active
        // source side does not.
        final Text titleWidget = tester.widget<Text>(
          find.descendant(
            of: find.byKey(const Key('transactionRowHorizontal')),
            matching: find.byWidgetPredicate(
              (Widget w) => w is Text && w.textSpan?.toPlainText().contains('→') == true,
            ),
          ),
        );
        final String plainTitle = titleWidget.textSpan!.toPlainText();
        expect(plainTitle, contains('Savings'));
        expect(plainTitle, contains('Closed'));
        expect(plainTitle.indexOf('Closed'), greaterThan(plainTitle.indexOf('→')));
      },
    );

    testWidgets(
      'E2: a transfer with a closed SOURCE account marks only that side, not the destination',
      (tester) async {
        final (AppDatabase db, String profileId, String sourceId) = await seededDb();
        final AccountRepository accountRepo = AccountRepository(db);
        final String destinationId = await accountRepo.createAccount(
          profileId: profileId,
          name: 'Savings',
          type: 'cash',
          currencyCode: 'JPY',
        );
        await accountRepo.softDelete(sourceId);
        final TransactionRepository txRepo = TransactionRepository(db, accountRepo);
        await txRepo.recordTransfer(
          profileId: profileId,
          sourceAccountId: sourceId,
          destinationAccountId: destinationId,
          amount: Money.fromMinorUnits(3000, 'JPY'),
          occurredAtUtc: DateTime.now().toUtc(),
        );
        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRouter(container));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final Text titleWidget = tester.widget<Text>(
          find.descendant(
            of: find.byKey(const Key('transactionRowHorizontal')),
            matching: find.byWidgetPredicate(
              (Widget w) => w is Text && w.textSpan?.toPlainText().contains('→') == true,
            ),
          ),
        );
        final String plainTitle = titleWidget.textSpan!.toPlainText();
        expect(plainTitle, contains('Wallet'));
        expect(plainTitle, contains('Closed'));
        // The closed source's label appears BEFORE the arrow, and the
        // active destination's name after it carries no label.
        expect(plainTitle.indexOf('Closed'), lessThan(plainTitle.indexOf('→')));
      },
    );
  });

  group('Checkpoint U2 -- service identity on a transaction row', () {
    testWidgets(
      'a service identity takes over the row title, and the category name moves into the '
      'subtitle instead of disappearing',
      (tester) async {
        final (AppDatabase db, String profileId, String accountId) = await seededDb();
        final AccountRepository accountRepo = AccountRepository(db);
        final TransactionRepository txRepo = TransactionRepository(db, accountRepo);
        await txRepo.recordExpense(
          profileId: profileId,
          accountId: accountId,
          amount: Money.fromMinorUnits(1500, 'JPY'),
          categoryId: 'sys-dining',
          serviceIdentityKey: 'netflix',
          occurredAtUtc: DateTime.now().toUtc(),
        );
        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRouter(container));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        // The service display name ("Netflix") wins the title slot that
        // would otherwise show "Dining Out" -- but the category name is
        // not lost, it appears in the subtitle alongside the account
        // name instead.
        expect(find.text('Netflix'), findsOneWidget);
        expect(find.text('Dining Out'), findsNothing); // no longer the title
        expect(find.textContaining('Dining Out'), findsOneWidget); // now in the subtitle
      },
    );

    testWidgets(
      'a transaction with no service identity is completely unaffected -- the category name '
      'still wins the title slot, exactly as before this checkpoint',
      (tester) async {
        final (AppDatabase db, String profileId, String accountId) = await seededDb();
        final AccountRepository accountRepo = AccountRepository(db);
        final TransactionRepository txRepo = TransactionRepository(db, accountRepo);
        await txRepo.recordExpense(
          profileId: profileId,
          accountId: accountId,
          amount: Money.fromMinorUnits(1200, 'JPY'),
          categoryId: 'sys-dining',
          occurredAtUtc: DateTime.now().toUtc(),
        );
        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRouter(container));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Dining Out'), findsOneWidget); // still the title
      },
    );

    testWidgets(
      'tapping through to the detail screen shows a "Service" metadata row alongside the '
      'existing "Category" row',
      (tester) async {
        final (AppDatabase db, String profileId, String accountId) = await seededDb();
        final AccountRepository accountRepo = AccountRepository(db);
        final TransactionRepository txRepo = TransactionRepository(db, accountRepo);
        await txRepo.recordExpense(
          profileId: profileId,
          accountId: accountId,
          amount: Money.fromMinorUnits(1500, 'JPY'),
          categoryId: 'sys-dining',
          serviceIdentityKey: 'netflix',
          occurredAtUtc: DateTime.now().toUtc(),
        );
        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRouter(container));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Netflix'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Category'), findsOneWidget);
        expect(find.text('Dining Out'), findsOneWidget); // still shown, in the metadata card
        expect(find.text('Service'), findsOneWidget);
        // "Netflix" now appears twice: once in the header (taking the
        // category-name slot there too), once in the new Service row.
        expect(find.text('Netflix'), findsNWidgets(2));
      },
    );
  });

  // ============================================================
  // UI/Icon Polish checkpoint: Activity rows show the SELECTED
  // category's identity (curated PNG when mapped, Material fallback
  // otherwise) rather than a generic Expense/Income glyph, and the
  // amount text picks up a premium Income-green/Expense-red gradient
  // sourced from `AppTokens.colors.positiveGradient`/`negativeGradient`
  // -- see `TransactionIconBadge`'s and `_TransactionRow.build`'s own
  // updated doc comments. Every test here that needs the GRADIENT
  // specifically pumps with `theme: AppTheme.light()` (via
  // `appWithRouter`'s new optional `theme` param): the file's other,
  // pre-existing tests all use the default (no theme, no registered
  // `AppTokens` extension, so `positiveGradient`/`negativeGradient`
  // fall back to `null`, and the whole gradient branch is skipped) --
  // which is exactly why none of them needed to change for this
  // checkpoint.
  // ============================================================
  group('UI/Icon Polish: Activity category icons + amount gradients', () {
    testWidgets('an Expense row with a mapped category shows the curated PNG and a '
        'negativeGradient-filled amount', (tester) async {
      final (AppDatabase db, String profileId, String accountId) = await seededDb();
      final TransactionRepository txRepo = TransactionRepository(db, AccountRepository(db));
      await txRepo.recordExpense(
        profileId: profileId,
        accountId: accountId,
        amount: Money.fromMinorUnits(1200, 'JPY'),
        categoryId: 'sys-dining', // icon 'restaurant' -- curated
        occurredAtUtc: DateTime.now().toUtc(),
      );

      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container, theme: AppTheme.light()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // The row's own leading identity -- not a generic minus/expense
      // glyph -- is the selected category's curated artwork.
      expect(find.byIcon(Icons.remove), findsNothing);
      expect(
        (tester.widget<Image>(find.byType(Image)).image as AssetImage).assetName,
        'assets/icons/categories/dining_out.png',
      );
      expect(find.text('-¥1,200'), findsOneWidget);
      // The amount is painted through a ShaderMask (the gradient-text
      // recipe) -- light theme defines a real `negativeGradient`, so
      // this branch is actually exercised, not skipped.
      expect(find.byType(ShaderMask), findsOneWidget);
    });

    testWidgets('an Income row with a mapped category shows the curated PNG and a '
        'positiveGradient-filled amount', (tester) async {
      final (AppDatabase db, String profileId, String accountId) = await seededDb();
      final TransactionRepository txRepo = TransactionRepository(db, AccountRepository(db));
      await txRepo.recordIncome(
        profileId: profileId,
        accountId: accountId,
        amount: Money.fromMinorUnits(500000, 'JPY'),
        categoryId: 'sys-salary', // icon 'work' -- curated
        occurredAtUtc: DateTime.now().toUtc(),
      );

      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container, theme: AppTheme.light()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.add), findsNothing);
      expect(
        (tester.widget<Image>(find.byType(Image)).image as AssetImage).assetName,
        'assets/icons/categories/salary.png',
      );
      expect(find.text('+¥500,000'), findsOneWidget);
      expect(find.byType(ShaderMask), findsOneWidget);
    });

    testWidgets('a category with an unmapped/unrecognized icon key still falls back safely '
        'to the Material glyph, never a broken asset', (tester) async {
      final (AppDatabase db, String profileId, String accountId) = await seededDb();
      final CategoryRepository categoryRepo = CategoryRepository(db);
      final TransactionRepository txRepo = TransactionRepository(db, AccountRepository(db));
      final String mysteryCategoryId = await categoryRepo.createCategory(
        profileId: profileId,
        name: 'Mystery Category',
        type: 'expense',
        icon: 'some_future_icon_name_not_in_the_map',
      );
      await txRepo.recordExpense(
        profileId: profileId,
        accountId: accountId,
        amount: Money.fromMinorUnits(900, 'JPY'),
        categoryId: mysteryCategoryId,
        occurredAtUtc: DateTime.now().toUtc(),
      );

      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container, theme: AppTheme.light()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.category), findsOneWidget); // categoryIconFor's own safe fallback
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('a transaction with no category at all still falls back safely to the plain '
        'type glyph, never a broken asset', (tester) async {
      final (AppDatabase db, String profileId, String accountId) = await seededDb();
      final TransactionRepository txRepo = TransactionRepository(db, AccountRepository(db));
      await txRepo.recordExpense(
        profileId: profileId,
        accountId: accountId,
        amount: Money.fromMinorUnits(900, 'JPY'),
        occurredAtUtc: DateTime.now().toUtc(),
      );

      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container, theme: AppTheme.light()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.remove), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('an established service identity still takes precedence over a mapped '
        'category -- this checkpoint never regresses that ladder', (tester) async {
      final (AppDatabase db, String profileId, String accountId) = await seededDb();
      final TransactionRepository txRepo = TransactionRepository(db, AccountRepository(db));
      await txRepo.recordExpense(
        profileId: profileId,
        accountId: accountId,
        amount: Money.fromMinorUnits(1500, 'JPY'),
        categoryId: 'sys-dining', // icon 'restaurant' -- curated, but...
        serviceIdentityKey: 'netflix', // ...service identity outranks it.
        occurredAtUtc: DateTime.now().toUtc(),
      );

      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container, theme: AppTheme.light()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Neither the category's Material glyph NOR its curated PNG
      // render -- the service identity's own glyph wins, exactly as
      // before this checkpoint (see `TransactionIconBadge`'s ladder).
      expect(find.byIcon(Icons.restaurant), findsNothing);
      expect(find.byType(Image), findsNothing);
      // The amount gradient is still applied (an Expense row is an
      // Expense row regardless of which icon rung won) -- service
      // identity only overrides the GLYPH, never the amount's color
      // (see `TransactionIconBadge`'s own precedence doc comment: the
      // tinted container's `color` always stays the transaction-type
      // color, never a service color).
      expect(find.byType(ShaderMask), findsOneWidget);
    });

    testWidgets('a Transfer row never gets the Income/Expense gradient treatment -- it keeps '
        'its existing neutral styling', (tester) async {
      final (AppDatabase db, String profileId, String accountId) = await seededDb();
      final AccountRepository accountRepo = AccountRepository(db);
      final String savingsAccountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Savings',
        type: 'savings',
        currencyCode: 'JPY',
      );
      final TransactionRepository txRepo = TransactionRepository(db, accountRepo);
      await txRepo.recordExpense(
        profileId: profileId,
        accountId: accountId,
        amount: Money.fromMinorUnits(1200, 'JPY'),
        categoryId: 'sys-dining',
        occurredAtUtc: DateTime.now().toUtc(),
      );
      await txRepo.recordIncome(
        profileId: profileId,
        accountId: accountId,
        amount: Money.fromMinorUnits(500000, 'JPY'),
        categoryId: 'sys-salary',
        occurredAtUtc: DateTime.now().toUtc(),
      );
      await txRepo.recordTransfer(
        profileId: profileId,
        sourceAccountId: accountId,
        destinationAccountId: savingsAccountId,
        amount: Money.fromMinorUnits(3000, 'JPY'),
        occurredAtUtc: DateTime.now().toUtc(),
      );

      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container, theme: AppTheme.light()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Exactly 2 ShaderMasks on screen -- the Expense and Income rows'
      // amounts -- never a 3rd for the Transfer row's amount.
      expect(find.byType(ShaderMask), findsNWidgets(2));
      expect(find.byIcon(Icons.swap_horiz), findsOneWidget); // transfer's own plain glyph, untouched
    });

    testWidgets(
      'a mapped-category Expense row renders without overflow across phone widths '
      '(320/360/390/430) and a 1.6x text scale, with the amount never pushed offscreen',
      (tester) async {
        for (final double width in <double>[320, 360, 390, 430]) {
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          tester.view.physicalSize = Size(width, 700);
          tester.view.devicePixelRatio = 1.0;
          tester.platformDispatcher.textScaleFactorTestValue = 1.6;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

          final (AppDatabase db, String profileId, String accountId) = await seededDb();
          final TransactionRepository txRepo = TransactionRepository(db, AccountRepository(db));
          await txRepo.recordExpense(
            profileId: profileId,
            accountId: accountId,
            amount: Money.fromMinorUnits(987654321, 'VND'),
            categoryId: 'sys-dining',
            note: 'A rather long note to stress narrow-width description content',
            occurredAtUtc: DateTime.now().toUtc(),
          );

          final ProviderContainer container =
              ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);

          await tester.pumpWidget(appWithRouter(container, theme: AppTheme.light()));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull, reason: 'width=$width');
          // The medium-sized identity (curated PNG, this checkpoint's
          // bumped 44px slot) stays mounted and on-screen.
          final Finder iconTile = find.byType(AppIconTile).first;
          expect(iconTile, findsOneWidget, reason: 'width=$width');
          expect(
            tester.widget<AppIconTile>(iconTile).containerSize,
            44,
            reason: 'width=$width',
          );
          expect(find.byType(Image), findsOneWidget, reason: 'width=$width');
          // The amount's full text is present SOMEWHERE on screen --
          // never clipped/ellipsized (this row's amount Text never sets
          // `overflow`/`maxLines` beyond 1 with `softWrap: false`, so
          // "present" here already proves "not truncated") -- whether
          // the adaptive layout chose the horizontal or stacked
          // arrangement at this width.
          expect(find.textContaining('987,654,321'), findsOneWidget, reason: 'width=$width');
          expect(find.textContaining('Dining Out'), findsOneWidget, reason: 'width=$width');

          // The amount must never render to the LEFT of the icon/title
          // column -- i.e. never visually "pushed offscreen" to the
          // left past the row's own leading content -- in EITHER
          // adaptive arrangement.
          //
          // `>=` (not strict `>`) is the correct bound here, not a
          // weakened one. In the horizontal arrangement the amount
          // always sits strictly right of the icon (separated by the
          // description column), so its dx is strictly greater. In the
          // stacked arrangement (this 320px/1.6x/huge-VND-amount case),
          // the full amount is placed via
          // `Align(alignment: Alignment.centerRight, ...)` inside a
          // full-width, stretched column that starts at the SAME left
          // inset as the leading icon (both sit `outerPadding(16) +
          // AppCard.padding(16) = 32px` from the row's left edge -- see
          // `_TransactionRow`'s own "TOTAL horizontal inset ... 64
          // total" comment). When the amount's natural width at this
          // scale is wide enough to exactly fill that available column
          // width, its right-aligned left edge coincides with -- not
          // past -- the icon's left edge: flush, never offscreen to the
          // left. That is the documented contract this test proves, and
          // exactly-equal dx is a valid instance of it, not a failure of
          // it.
          final Finder amountFinder = find.textContaining('987,654,321');
          final Finder iconFinder = find.byType(AppIconTile).first;
          expect(
            tester.getTopLeft(amountFinder).dx,
            greaterThanOrEqualTo(tester.getTopLeft(iconFinder).dx),
            reason: 'width=$width',
          );

          // This test loops over four widths, each building its own
          // fresh `db`/`container` and `pumpWidget` tree -- unlike
          // every other test here (one `db`/`container` pair per test,
          // safely deferred to an `addTearDown`), deferring disposal to
          // `addTearDown` here would leave EVERY iteration's `db` and
          // `container` open simultaneously (they only run at the very
          // end of the test body, not between loop iterations), which
          // is exactly the "created the database class AppDatabase
          // multiple times" / "Timer is still pending even after the
          // widget tree was disposed" failure this masked: the next
          // iteration's `pumpWidget` call replaces the widget tree
          // without the previous iteration's Drift streams/container
          // ever being torn down first. Disposing explicitly, in the
          // same order `disposeInOrder` always uses, before the next
          // iteration starts avoids that entirely.
          await disposeInOrder(tester, container, db);
        }
      },
    );
  });
}
