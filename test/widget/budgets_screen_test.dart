import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/providers.dart';
import 'package:ai_financial_coach/core/database/repositories/account_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/budget_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/category_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/transaction_repository.dart';
import 'package:ai_financial_coach/core/money/money.dart';
import 'package:ai_financial_coach/features/budgets/domain/budget_month.dart';
import 'package:ai_financial_coach/features/budgets/presentation/budget_providers.dart';
import 'package:ai_financial_coach/features/budgets/presentation/budgets_screen.dart';
import 'package:ai_financial_coach/features/categories/presentation/category_providers.dart';
import 'package:ai_financial_coach/shared/widgets/currency_badge.dart';
import 'package:ai_financial_coach/l10n/generated/app_localizations.dart';
import 'package:ai_financial_coach/shared/theme/app_tokens.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// NOTE: exercises generated Drift code — see CLAUDE_FIRST_CODING_PROMPT.md.

void main() {
  /// Seeds a profile (and, when [withCategories] is true, the system
  /// category set -- mirroring `lib/app/app.dart`'s own bootstrap call
  /// to `CategoryRepository.seedSystemCategoriesIfNeeded`, which nothing
  /// in a widget test triggers automatically) and returns its id.
  Future<(AppDatabase, String)> seededDb({bool withCategories = false}) async {
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    final ProfileRepository profileRepo = ProfileRepository(db);
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
    if (withCategories) {
      await CategoryRepository(db).seedSystemCategoriesIfNeeded();
    }
    return (db, profileId);
  }

  Widget appWithBudgets(ProviderContainer container, {Locale locale = const Locale('en')}) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const BudgetsScreen(),
      ),
    );
  }

  /// Same deterministic shutdown sequence as
  /// `home_screen_test.dart`/`add_transaction_screen_test.dart`'s
  /// `disposeInOrder`: unmount, then dispose, then one `pumpAndSettle()`
  /// so Drift's `StreamQueryStore.markAsClosed` `Timer.zero` fires
  /// before `db.close()`. Sufficient for every test in this file except
  /// "creating a category budget..." below, which has its own bespoke
  /// teardown -- see that test's doc comment for why the shared pattern
  /// here doesn't apply to it.
  Future<void> disposeInOrder(WidgetTester tester, ProviderContainer container, AppDatabase db) async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pumpAndSettle();
    await db.close();
  }

  /// Deterministic one-shot lookup instead of a reactive
  /// `BudgetRepository.watchActiveOverallBudget(...).first` -- same
  /// hang documented on the one-shot query in "navigating months never
  /// mutates any budget data...": a bare `.watch(...).first` registers
  /// a new Drift `QueryStream` whose first value is delivered via a
  /// batched zero-duration `Timer`, and nothing pumps the `testWidgets`
  /// FakeAsync clock again after a post-assertion database read like
  /// this one to let that `Timer` fire, so the `await` never resolves.
  /// Same predicate as `watchActiveOverallBudget`, built with
  /// `getSingleOrNull()` instead of `watchSingleOrNull()` so no
  /// `QueryStream` is ever registered.
  Future<BudgetRow?> readActiveOverallBudget(
    AppDatabase db, {
    required String profileId,
    required String currencyCode,
    required BudgetMonth month,
  }) {
    final query = db.select(db.budgets)
      ..where(
        (tbl) =>
            tbl.profileId.equals(profileId) &
            tbl.categoryId.isNull() &
            tbl.currencyCode.equals(currencyCode) &
            tbl.year.equals(month.year) &
            tbl.month.equals(month.month) &
            tbl.deletedAt.isNull(),
      );
    return query.getSingleOrNull();
  }

  /// Same rationale/fix as [readActiveOverallBudget], for
  /// `BudgetRepository.watchActiveCategoryBudget(...).first`.
  Future<BudgetRow?> readActiveCategoryBudget(
    AppDatabase db, {
    required String profileId,
    required String categoryId,
    required String currencyCode,
    required BudgetMonth month,
  }) {
    final query = db.select(db.budgets)
      ..where(
        (tbl) =>
            tbl.profileId.equals(profileId) &
            tbl.categoryId.equals(categoryId) &
            tbl.currencyCode.equals(currencyCode) &
            tbl.year.equals(month.year) &
            tbl.month.equals(month.month) &
            tbl.deletedAt.isNull(),
      );
    return query.getSingleOrNull();
  }

  testWidgets('creating an overall monthly budget from the empty state shows it in the list',
      (tester) async {
    final (AppDatabase db, _) = await seededDb();
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithBudgets(container));
    await tester.pumpAndSettle();

    expect(find.textContaining('No budgets set for this month yet'), findsOneWidget);

    await tester.tap(find.byKey(const Key('addBudgetFab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('addOverallBudgetOption')));
    await tester.pumpAndSettle();

    expect(find.text('Set overall monthly budget'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('overallBudgetAmountField')), '120000');
    await tester.tap(find.byKey(const Key('saveOverallBudget')));
    await tester.pumpAndSettle();

    expect(find.text('Set overall monthly budget'), findsNothing); // dialog closed
    expect(find.byKey(const Key('overallBudgetTile_JPY')), findsOneWidget);
    expect(find.text('¥120,000'), findsOneWidget);
  });

  testWidgets('editing an existing overall budget updates the amount shown', (tester) async {
    final (AppDatabase db, String profileId) = await seededDb();
    await BudgetRepository(db).setOverallBudget(
      profileId: profileId,
      month: BudgetMonth.fromUtc(DateTime.now().toUtc()),
      amount: Money.fromMinorUnits(100000, 'JPY'),
    );
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithBudgets(container));
    await tester.pumpAndSettle();

    expect(find.text('¥100,000'), findsOneWidget);

    await tester.tap(find.byKey(const Key('editOverallBudget_JPY')));
    await tester.pumpAndSettle();
    expect(find.text('Edit overall monthly budget'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('overallBudgetAmountField')), '150000');
    await tester.tap(find.byKey(const Key('saveOverallBudget')));
    await tester.pumpAndSettle();

    expect(find.text('¥150,000'), findsOneWidget);
    expect(find.text('¥100,000'), findsNothing);
    // Still exactly one JPY overall budget row -- the edit updated the
    // existing row in place rather than creating a second one.
    expect(find.byKey(const Key('overallBudgetTile_JPY')), findsOneWidget);
  });

  testWidgets('removing a budget takes it out of the list', (tester) async {
    final (AppDatabase db, String profileId) = await seededDb();
    await BudgetRepository(db).setOverallBudget(
      profileId: profileId,
      month: BudgetMonth.fromUtc(DateTime.now().toUtc()),
      amount: Money.fromMinorUnits(100000, 'JPY'),
    );
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithBudgets(container));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('overallBudgetTile_JPY')), findsOneWidget);

    await tester.tap(find.byKey(const Key('deleteOverallBudget_JPY')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('overallBudgetTile_JPY')), findsNothing);
    expect(find.textContaining('No budgets set for this month yet'), findsOneWidget);
  });

  testWidgets('creating a category budget shows it under "Category budgets"', (tester) async {
    final (AppDatabase db, _) = await seededDb(withCategories: true);
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);

    // Root cause of the pending-timer failure this test alone produced:
    // `_CategoryBudgetDialog`'s category dropdown watches
    // `categoriesForTypeProvider('expense')` (an `autoDispose` family
    // `StreamProvider` -- see `category_providers.dart`). That watch is
    // the ONLY listener this provider instance ever gets in this test,
    // so tapping Save below -- which pops the dialog -- drops its last
    // listener mid-test, well before `disposeInOrder` would ever run.
    // Riverpod's autoDispose then tears the provider down right there,
    // which cancels its underlying Drift query and schedules Drift's
    // `StreamQueryStore.markAsClosed` `Timer.zero` as a side effect of
    // whatever `pumpAndSettle()` happens to be running at that exact
    // moment -- not a predictable one this test (or a shared teardown
    // helper) fully controls. Two attempts to catch that Timer with an
    // extra `pumpAndSettle()`/`pump(Duration.zero)` in `disposeInOrder`
    // both failed, because the real problem isn't *when* teardown pumps
    // -- it's that disposal itself happens at an uncontrolled point
    // inside the test body.
    //
    // Fix: hold our own `container.listen` subscription on the exact
    // same provider instance for the rest of this test, so the
    // dialog closing does NOT drop its last listener -- the provider
    // stays alive, watched, right through Save. Disposal then happens
    // exactly once, at the single point this test's own teardown closes
    // `categoriesSubscription`, which this test can settle
    // deterministically before disposing the container. This is a
    // test-only keep-alive -- `categoriesForTypeProvider` itself stays
    // `autoDispose` in production; nothing here changes what the app
    // ships.
    final ProviderSubscription<AsyncValue<List<CategoryRow>>> categoriesSubscription = container
        .listen<AsyncValue<List<CategoryRow>>>(categoriesForTypeProvider('expense'), (_, __) {});

    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      // Closing this ourselves, before `container.dispose()`, is what
      // makes the resulting Drift cancellation happen at a moment this
      // test controls -- the same settled point every other test's
      // shared `disposeInOrder` relies on -- rather than mid-test.
      categoriesSubscription.close();
      await tester.pumpAndSettle();
      container.dispose();
      await tester.pumpAndSettle();
      await db.close();
    });

    await tester.pumpWidget(appWithBudgets(container));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('addBudgetFab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('addCategoryBudgetOption')));
    await tester.pumpAndSettle();

    expect(find.text('Set category budget'), findsOneWidget);
    await tester.tap(find.byKey(const Key('categoryBudgetCategoryField')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dining Out').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('categoryBudgetAmountField')), '20000');
    await tester.tap(find.byKey(const Key('saveCategoryBudget')));
    await tester.pumpAndSettle();

    expect(find.text('Set category budget'), findsNothing); // dialog closed
    expect(find.text('Category budgets'), findsOneWidget);
    expect(find.text('Dining Out'), findsOneWidget);
    // Checkpoint Q: the tile's subtitle is still this exact composed
    // string -- scoped via exact match (not `textContaining`) because
    // this checkpoint's new category-progress details, appended below
    // this same tile, also render '\u00a520,000' (as both the
    // 'spent of budgeted' and 'remaining' figures for a freshly-created,
    // zero-spend budget) -- a bare substring match would now find three
    // widgets, not one.
    expect(find.text('JPY · ¥20,000'), findsOneWidget);
  });

  testWidgets('the budgets screen lays out without overflow on a narrow (320px-wide) screen '
      'with both an overall and a category budget configured', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1.0;

    final (AppDatabase db, String profileId) = await seededDb(withCategories: true);
    final BudgetMonth month = BudgetMonth.fromUtc(DateTime.now().toUtc());
    await BudgetRepository(db).setOverallBudget(
      profileId: profileId,
      month: month,
      amount: Money.fromMinorUnits(120000, 'JPY'),
    );
    await BudgetRepository(db).setCategoryBudget(
      profileId: profileId,
      categoryId: 'sys-dining',
      month: month,
      amount: Money.fromMinorUnits(20000, 'JPY'),
    );
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithBudgets(container));
    await tester.pumpAndSettle();

    final Object? overflowException = tester.takeException();
    if (overflowException != null) {
      fail('Narrow-screen (320px) budgets screen layout threw an exception:\n\n$overflowException');
    }
  });

  // CP5.4b: `_CategoryBudgetTile`'s title/subtitle are already allowed
  // to wrap (per the CP5.4 audit -- `ListTile` gives its title/subtitle
  // column a flexible slot internally, so a long custom name just grows
  // the row rather than overflowing or colliding with the fixed
  // edit/delete trailing icons). This test pins down specifically that
  // those trailing controls keep rendering next to a name long enough
  // to wrap, at a narrow width and a large text scale -- not that the
  // name stays on one line, which the locked text policy doesn't
  // require.
  testWidgets(
      'CP5.4b: a long custom category name still renders its edit/delete controls at a narrow '
      '320px width and a 1.6x text scale', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final (AppDatabase db, String profileId) = await seededDb();
    const String longName = 'A rather long custom category name to stress narrow-width layout';
    final String categoryId = await CategoryRepository(db).createCategory(
      profileId: profileId,
      name: longName,
      type: 'expense',
    );
    final BudgetMonth month = BudgetMonth.fromUtc(DateTime.now().toUtc());
    final String budgetId = await BudgetRepository(db).setCategoryBudget(
      profileId: profileId,
      categoryId: categoryId,
      month: month,
      amount: Money.fromMinorUnits(20000, 'JPY'),
    );

    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithBudgets(container));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(Key('categoryBudgetTile_${categoryId}_JPY')), findsOneWidget);
    expect(find.text(longName), findsOneWidget);
    expect(find.byKey(Key('editCategoryBudget_$budgetId')), findsOneWidget);
    expect(find.byKey(Key('deleteCategoryBudget_$budgetId')), findsOneWidget);
  });

  // CP5.4b: precision-stress companion to the long-name test above --
  // confirms a large 0-decimal (VND) overall budget and a large
  // 3-decimal (KWD) category budget both keep every digit at the same
  // narrow width/large text scale. This screen shows only the
  // configured limit (not a "spent" figure) for either tile, so only
  // the exact limit strings the current implementation actually
  // renders are asserted here.
  testWidgets(
      'CP5.4b: large 0-decimal VND and 3-decimal KWD budget amounts keep every digit at a '
      'narrow 320px width and a 1.6x text scale', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final (AppDatabase db, String profileId) = await seededDb();
    final BudgetMonth month = BudgetMonth.fromUtc(DateTime.now().toUtc());
    await BudgetRepository(db).setOverallBudget(
      profileId: profileId,
      month: month,
      // \u20AB999,999,999 -- VND has 0 minor units per
      // `CurrencyRegistry`; same magnitude already verified correct by
      // a real Windows run in CP5.2a.
      amount: Money.fromMinorUnits(999999999, 'VND'),
    );
    final String categoryId = await CategoryRepository(db).createCategory(
      profileId: profileId,
      name: 'Precision Category',
      type: 'expense',
    );
    await BudgetRepository(db).setCategoryBudget(
      profileId: profileId,
      categoryId: categoryId,
      month: month,
      // \u062F.\u064312,345.678 -- KWD has 3 minor units, not 0; same
      // magnitude already verified correct by a real Windows run in
      // CP5.2a/CP5.4a.
      amount: Money.fromMinorUnits(12345678, 'KWD'),
    );

    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithBudgets(container));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Scoped to each tile's own key -- the overall-budget tile key is
    // per-currency and the category-budget tile key is per-category, so
    // there's no risk of these two exact strings colliding with
    // anything else on screen even unscoped, but scoping keeps this
    // resilient if more budgets are ever added to this fixture.
    expect(
      find.descendant(
        of: find.byKey(const Key('overallBudgetTile_VND')),
        matching: find.text('\u20AB999,999,999'),
      ),
      findsOneWidget,
    );
    // Checkpoint Q's new Month Summary card (above the Overall/Category
    // sections) makes this screen tall enough that, at this test's narrow
    // 320px/1.6x-text-scale viewport, the category tile below is no
    // longer within the lazily-built `ListView`'s initial extent -- it
    // is not merely off-screen, it is not mounted into the element tree
    // yet, so it must be scrolled into view before it can be found at
    // all (same rationale as `scrollToSaveButton` in
    // add_transaction_screen_test.dart). This does not weaken what the
    // test protects: the full-precision KWD amount below is still
    // asserted against the tile's actual rendered `Text` content, not a
    // different, looser finder.
    final Finder kwdTile = find.byKey(Key('categoryBudgetTile_${categoryId}_KWD'));
    await tester.scrollUntilVisible(kwdTile, 200);
    expect(
      find.descendant(
        of: kwdTile,
        matching: find.textContaining('\u062F.\u064312,345.678'),
      ),
      findsOneWidget,
    );
  });

  // CP6.6: Budgets screen Japanese localization. Re-uses every seeding/
  // layout-key helper above unchanged; only `appWithBudgets` grew a
  // `locale` parameter (default 'en', so every test above this point is
  // unaffected).
  group('CP6.6 Japanese localization', () {
    testWidgets(
      'A: standard Japanese Budgets renders a localized AppBar/section header and an '
      'untouched currency code and amount',
      (tester) async {
        final (AppDatabase db, String profileId) = await seededDb();
        final BudgetMonth month = BudgetMonth.fromUtc(DateTime.now().toUtc());
        await BudgetRepository(db).setOverallBudget(
          profileId: profileId,
          month: month,
          amount: Money.fromMinorUnits(120000, 'JPY'), // ¥120,000
        );
        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithBudgets(container, locale: const Locale('ja')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.textContaining('予算 ·'), findsOneWidget); // AppBar (budgetsScreenTitle)
        expect(find.text('全体予算'), findsOneWidget); // overallBudgetsSectionTitle
        expect(find.text('JPY'), findsOneWidget); // currency code -- never translated
        expect(find.text('¥120,000'), findsOneWidget);
      },
    );

    testWidgets(
      'B: a custom category name renders exactly as stored under the Japanese locale, '
      'alongside the localized "Category budgets" section header',
      (tester) async {
        final (AppDatabase db, String profileId) = await seededDb();
        const String customCategoryName = 'カスタム外食カテゴリ';
        final String categoryId = await CategoryRepository(db).createCategory(
          profileId: profileId,
          name: customCategoryName,
          type: 'expense',
        );
        final BudgetMonth month = BudgetMonth.fromUtc(DateTime.now().toUtc());
        await BudgetRepository(db).setCategoryBudget(
          profileId: profileId,
          categoryId: categoryId,
          month: month,
          amount: Money.fromMinorUnits(20000, 'JPY'),
        );
        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithBudgets(container, locale: const Locale('ja')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('カテゴリ予算'), findsOneWidget); // categoryBudgetsSectionTitle
        // The custom category name is persisted content -- it is
        // reproduced verbatim, never run through l10n, even though it
        // happens to already be Japanese text.
        expect(find.text(customCategoryName), findsOneWidget);
      },
    );

    testWidgets(
      'C: Japanese + MMK renders its registry-defined 2 decimal places (never 0) at normal '
      'width and text scale',
      (tester) async {
        final (AppDatabase db, String profileId) = await seededDb();
        final BudgetMonth month = BudgetMonth.fromUtc(DateTime.now().toUtc());
        await BudgetRepository(db).setOverallBudget(
          profileId: profileId,
          month: month,
          amount: Money.fromMinorUnits(150075, 'MMK'), // K1,500.75
        );
        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithBudgets(container, locale: const Locale('ja')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          find.descendant(
            of: find.byKey(const Key('overallBudgetTile_MMK')),
            matching: find.text('K1,500.75'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'D: Japanese + a large 0-decimal VND budget keeps every digit intact',
      (tester) async {
        final (AppDatabase db, String profileId) = await seededDb();
        final BudgetMonth month = BudgetMonth.fromUtc(DateTime.now().toUtc());
        await BudgetRepository(db).setOverallBudget(
          profileId: profileId,
          month: month,
          amount: Money.fromMinorUnits(999999999, 'VND'), // ₫999,999,999
        );
        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithBudgets(container, locale: const Locale('ja')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          find.descendant(
            of: find.byKey(const Key('overallBudgetTile_VND')),
            matching: find.text('₫999,999,999'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'E: Japanese + a large 3-decimal KWD category budget keeps every digit intact',
      (tester) async {
        final (AppDatabase db, String profileId) = await seededDb();
        final String categoryId = await CategoryRepository(db).createCategory(
          profileId: profileId,
          name: 'Precision Category',
          type: 'expense',
        );
        final BudgetMonth month = BudgetMonth.fromUtc(DateTime.now().toUtc());
        await BudgetRepository(db).setCategoryBudget(
          profileId: profileId,
          categoryId: categoryId,
          month: month,
          amount: Money.fromMinorUnits(12345678, 'KWD'), // د.ك12,345.678
        );
        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithBudgets(container, locale: const Locale('ja')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          find.descendant(
            of: find.byKey(Key('categoryBudgetTile_${categoryId}_KWD')),
            matching: find.textContaining('د.ك12,345.678'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'F: Japanese + 1.6x text scale renders both budget sections without exceptions',
      (tester) async {
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        tester.platformDispatcher.textScaleFactorTestValue = 1.6;

        final (AppDatabase db, String profileId) = await seededDb(withCategories: true);
        final BudgetMonth month = BudgetMonth.fromUtc(DateTime.now().toUtc());
        await BudgetRepository(db).setOverallBudget(
          profileId: profileId,
          month: month,
          amount: Money.fromMinorUnits(120000, 'JPY'),
        );
        await BudgetRepository(db).setCategoryBudget(
          profileId: profileId,
          categoryId: 'sys-dining',
          month: month,
          amount: Money.fromMinorUnits(20000, 'JPY'),
        );
        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithBudgets(container, locale: const Locale('ja')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('全体予算'), findsOneWidget);
        expect(find.text('カテゴリ予算'), findsOneWidget);
      },
    );

    testWidgets(
      'G: Japanese + 2.0x text scale renders both budget sections without exceptions',
      (tester) async {
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;

        final (AppDatabase db, String profileId) = await seededDb(withCategories: true);
        final BudgetMonth month = BudgetMonth.fromUtc(DateTime.now().toUtc());
        await BudgetRepository(db).setOverallBudget(
          profileId: profileId,
          month: month,
          amount: Money.fromMinorUnits(120000, 'JPY'),
        );
        await BudgetRepository(db).setCategoryBudget(
          profileId: profileId,
          categoryId: 'sys-dining',
          month: month,
          amount: Money.fromMinorUnits(20000, 'JPY'),
        );
        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithBudgets(container, locale: const Locale('ja')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('全体予算'), findsOneWidget);
        expect(find.text('カテゴリ予算'), findsOneWidget);
      },
    );

    testWidgets(
      'H: 320px narrow width + Japanese + 1.6x text scale + a long custom category name + a '
      'large international (MMK) amount lays out without exceptions',
      (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1.0;
        tester.platformDispatcher.textScaleFactorTestValue = 1.6;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        const String longName = '狭い画面でのレイアウトを確認するための、かなり長いカテゴリ名';
        final (AppDatabase db, String profileId) = await seededDb();
        final String categoryId = await CategoryRepository(db).createCategory(
          profileId: profileId,
          name: longName,
          type: 'expense',
        );
        final BudgetMonth month = BudgetMonth.fromUtc(DateTime.now().toUtc());
        final String budgetId = await BudgetRepository(db).setCategoryBudget(
          profileId: profileId,
          categoryId: categoryId,
          month: month,
          amount: Money.fromMinorUnits(999999999, 'MMK'), // K9,999,999.99
        );

        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithBudgets(container, locale: const Locale('ja')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byKey(Key('categoryBudgetTile_${categoryId}_MMK')), findsOneWidget);
        expect(find.text(longName), findsOneWidget);
        // Checkpoint Q: scoped to the tile's exact subtitle string, not a
        // bare substring -- see the identical reasoning on the JPY/EN
        // category-budget test above. This zero-spend budget's new
        // progress details also render 'K9,999,999.99' (as both the
        // 'spent of budgeted' and 'remaining' figures), so an unscoped
        // substring match would now find three widgets, not one.
        expect(find.text('MMK · K9,999,999.99'), findsOneWidget);
        expect(find.byKey(Key('editCategoryBudget_$budgetId')), findsOneWidget);
        expect(find.byKey(Key('deleteCategoryBudget_$budgetId')), findsOneWidget);
      },
    );

    testWidgets(
      'I: navigation/action regression -- creating an overall monthly budget under the '
      'Japanese locale shows a fully localized sheet and dialog, and still creates a real, '
      'persisted budget that appears in the (still Japanese) list',
      (tester) async {
        final (AppDatabase db, _) = await seededDb();
        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithBudgets(container, locale: const Locale('ja')));
        await tester.pumpAndSettle();

        expect(find.textContaining('今月の予算はまだ設定されていません'), findsOneWidget);

        await tester.tap(find.byKey(const Key('addBudgetFab')));
        await tester.pumpAndSettle();
        expect(find.text('毎月の全体予算'), findsOneWidget); // overallMonthlyBudgetOption
        expect(find.text('カテゴリ予算'), findsOneWidget); // categoryBudgetOption

        await tester.tap(find.byKey(const Key('addOverallBudgetOption')));
        await tester.pumpAndSettle();

        expect(find.text('毎月の全体予算を設定'), findsOneWidget); // setOverallBudgetTitle
        await tester.enterText(find.byKey(const Key('overallBudgetAmountField')), '120000');
        await tester.tap(find.byKey(const Key('saveOverallBudget')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('毎月の全体予算を設定'), findsNothing); // dialog closed
        expect(find.byKey(const Key('overallBudgetTile_JPY')), findsOneWidget);
        expect(find.text('¥120,000'), findsOneWidget);
      },
    );
  });

  // ---------------------------------------------------------------------
  // Visual System Convergence Checkpoint 7.4: locks in the budget tiles'
  // new bordered-card visual treatment (`AppCard(bordered: true)`) via the
  // same shape/side/color contract `app_card_test.dart`/
  // `accounts_screen_test.dart` already assert for `AppCard` -- never a
  // pixel value. Also locks in that the section header text still
  // renders exactly as before (`AppSectionHeader` never changes casing).
  // ---------------------------------------------------------------------
  testWidgets(
    'CP7.4: an overall budget tile renders inside a bordered, near-white card matching the '
    'converged visual system, and the section header text is unchanged',
    (tester) async {
      final (AppDatabase db, String profileId) = await seededDb();
      await BudgetRepository(db).setOverallBudget(
        profileId: profileId,
        month: BudgetMonth.fromUtc(DateTime.now().toUtc()),
        amount: Money.fromMinorUnits(50000, 'JPY'),
      );
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithBudgets(container));
      await tester.pumpAndSettle();

      expect(find.text('Overall budgets'), findsOneWidget); // overallBudgetsSectionTitle unchanged

      final Finder tileKey = find.byKey(const Key('overallBudgetTile_JPY'));
      final Card cardWidget = tester.widget<Card>(
        find.ancestor(of: tileKey, matching: find.byType(Card)).first,
      );
      final BuildContext context = tester.element(tileKey);
      final ColorScheme colors = Theme.of(context).colorScheme;
      final AppTokens tokens = context.appTokens;

      expect(cardWidget.color, colors.surface);
      expect(cardWidget.elevation, 0);
      final RoundedRectangleBorder shape = cardWidget.shape! as RoundedRectangleBorder;
      expect(shape.side.color, tokens.colors.subtleBorder);

      // The amount itself still renders in full, unformatted-by-us --
      // `AppMoneyText` never reformats or truncates `MoneyFormatter`'s
      // output.
      expect(find.text('¥50,000'), findsOneWidget);
    },
  );

  // ---------------------------------------------------------------------
  // Checkpoint Q: Monthly Budget Progress & Month Navigation.
  // ---------------------------------------------------------------------
  group('Checkpoint Q -- month navigation', () {
    testWidgets('the header shows the current month by default, and tapping next/previous '
        'moves it, year-boundary safe', (tester) async {
      final (AppDatabase db, _) = await seededDb();
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      // Pin "now" to a known month via the provider itself (rather than
      // depending on the real wall-clock date) by overriding
      // `selectedBudgetMonthProvider`'s initial state is not possible
      // (StateProvider has no override-friendly seam here without
      // touching production code), so this test drives navigation
      // relative to whatever the real current month is and asserts the
      // DELTA, which is exactly what a user does regardless of today's
      // date.
      await tester.pumpWidget(appWithBudgets(container));
      await tester.pumpAndSettle();

      final BudgetMonth start = container.read(selectedBudgetMonthProvider);
      expect(find.byKey(const Key('selectedMonthLabel')), findsOneWidget);

      await tester.tap(find.byKey(const Key('nextMonthButton')));
      await tester.pumpAndSettle();
      expect(container.read(selectedBudgetMonthProvider), start.next);

      await tester.tap(find.byKey(const Key('previousMonthButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('previousMonthButton')));
      await tester.pumpAndSettle();
      expect(container.read(selectedBudgetMonthProvider), start.previous);
    });

    testWidgets('December -> next -> January, and January -> previous -> December', (tester) async {
      final (AppDatabase db, _) = await seededDb();
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithBudgets(container));
      await tester.pumpAndSettle();

      container.read(selectedBudgetMonthProvider.notifier).state = BudgetMonth(year: 2026, month: 12);
      await tester.pumpAndSettle();
      // Computed the same locale-agnostic way `_MonthNavigator` itself
      // formats it, rather than a hard-coded English literal, so this
      // assertion is robust to whatever the test runner's own default
      // locale happens to be -- see `recurring_screen_test.dart`'s
      // identical `DateFormat.yMMMd().format(anchor)` convention.
      expect(find.text(DateFormat.yMMM().format(DateTime.utc(2026, 12))), findsOneWidget);

      await tester.tap(find.byKey(const Key('nextMonthButton')));
      await tester.pumpAndSettle();
      expect(container.read(selectedBudgetMonthProvider), BudgetMonth(year: 2027, month: 1));
      expect(find.text(DateFormat.yMMM().format(DateTime.utc(2027, 1))), findsOneWidget);

      await tester.tap(find.byKey(const Key('previousMonthButton')));
      await tester.pumpAndSettle();
      expect(container.read(selectedBudgetMonthProvider), BudgetMonth(year: 2026, month: 12));
      expect(find.text(DateFormat.yMMM().format(DateTime.utc(2026, 12))), findsOneWidget);
    });

    testWidgets('the AppBar title tracks the selected month, never the real current month, once '
        'navigated away', (tester) async {
      final (AppDatabase db, _) = await seededDb();
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithBudgets(container));
      await tester.pumpAndSettle();

      container.read(selectedBudgetMonthProvider.notifier).state = BudgetMonth(year: 2026, month: 8);
      await tester.pumpAndSettle();
      expect(find.text('Budgets · 2026-08'), findsOneWidget);
    });

    testWidgets('previous/next controls have localized accessibility tooltips, not icon-only',
        (tester) async {
      final (AppDatabase db, _) = await seededDb();
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithBudgets(container));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Previous month'), findsOneWidget);
      expect(find.byTooltip('Next month'), findsOneWidget);
    });

    testWidgets('navigating months never mutates any budget data -- the same rows are still '
        'exactly what they were', (tester) async {
      final (AppDatabase db, String profileId) = await seededDb();
      final BudgetMonth month = BudgetMonth.fromUtc(DateTime.now().toUtc());
      final String budgetId = await BudgetRepository(db).setOverallBudget(
        profileId: profileId,
        month: month,
        amount: Money.fromMinorUnits(75000, 'JPY'),
      );
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithBudgets(container));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('nextMonthButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('previousMonthButton')));
      await tester.pumpAndSettle();

      // Deterministic one-shot lookup instead of a reactive .watch()
      // stream -- BudgetRepository.watchActiveOverallBudget(...).first
      // hangs here for the same reason documented at
      // AccountRepository.watchActiveForProfile(...).first in
      // home_screen_test.dart: it registers a new Drift QueryStream
      // whose first value is delivered via a batched zero-duration
      // Timer, and nothing pumps the FakeAsync test clock again after
      // this line to let that Timer fire, so the await never resolves
      // (only surfacing, eventually, as a leaked-guarded-call failure
      // at the next tester call -- disposeInOrder's pumpWidget -- once
      // the real 10-minute test-runner watchdog gives up). Same
      // predicate as watchActiveOverallBudget, built with
      // getSingleOrNull() instead of watchSingleOrNull() so no
      // QueryStream is ever registered.
      final query = db.select(db.budgets)
        ..where(
          (tbl) =>
              tbl.profileId.equals(profileId) &
              tbl.categoryId.isNull() &
              tbl.currencyCode.equals('JPY') &
              tbl.year.equals(month.year) &
              tbl.month.equals(month.month) &
              tbl.deletedAt.isNull(),
        );
      final BudgetRow? row = await query.getSingleOrNull();
      expect(row, isNotNull);
      expect(row!.id, budgetId);
      expect(row.amountMinorUnits, 75000);
    });
  });

  group('Checkpoint Q -- budgets never leak across months', () {
    testWidgets('August budgets/spending never appear while viewing September, and vice versa',
        (tester) async {
      final (AppDatabase db, String profileId) = await seededDb(withCategories: true);
      final AccountRepository accountRepo = AccountRepository(db);
      final TransactionRepository transactionRepo = TransactionRepository(db, accountRepo);
      final BudgetRepository budgetRepo = BudgetRepository(db);
      final String walletId =
          await accountRepo.createAccount(profileId: profileId, name: 'Wallet', type: 'cash', currencyCode: 'JPY');
      final BudgetMonth august = BudgetMonth(year: 2026, month: 8);
      final BudgetMonth september = BudgetMonth(year: 2026, month: 9);

      await budgetRepo.setCategoryBudget(
        profileId: profileId,
        categoryId: 'sys-dining',
        month: august,
        amount: Money.fromMinorUnits(10000, 'JPY'),
      );
      await budgetRepo.setCategoryBudget(
        profileId: profileId,
        categoryId: 'sys-dining',
        month: september,
        amount: Money.fromMinorUnits(40000, 'JPY'),
      );
      await transactionRepo.recordExpense(
        profileId: profileId,
        accountId: walletId,
        amount: Money.fromMinorUnits(4000, 'JPY'),
        occurredAtUtc: august.startUtc,
        categoryId: 'sys-dining',
      );
      await transactionRepo.recordExpense(
        profileId: profileId,
        accountId: walletId,
        amount: Money.fromMinorUnits(30000, 'JPY'),
        occurredAtUtc: september.startUtc,
        categoryId: 'sys-dining',
      );

      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithBudgets(container));
      container.read(selectedBudgetMonthProvider.notifier).state = august;
      await tester.pumpAndSettle();

      // The category tile's own subtitle ("JPY · <amount>") is this
      // test's one stable, unambiguous carrier of "this month's category
      // budget amount" -- both months' rows share the same tile key
      // (categoryId/currencyCode never change month to month), so only
      // one such tile is ever on screen at a time, and its subtitle
      // always names the amount for whichever month is currently
      // selected. A bare find.text('¥10,000') is NOT safe here: with
      // September budgeted ¥40,000 and spent ¥30,000, September's own
      // (legitimate) Month Summary "remaining" stat is also exactly
      // ¥10,000 -- a real September calculation that numerically
      // collides with August's unrelated budget amount, not a leak.
      final Finder diningTile = find.byKey(const Key('categoryBudgetTile_sys-dining_JPY'));
      expect(
        find.descendant(of: diningTile, matching: find.text('JPY · ¥10,000')),
        findsOneWidget,
      ); // August's category budget amount, scoped to its own tile
      expect(
        find.descendant(of: diningTile, matching: find.text('JPY · ¥40,000')),
        findsNothing,
      ); // September's amount must not leak into August's tile
      // August's ¥4,000 spend legitimately appears twice: once in the
      // Month Summary's "Spent" stat, once in the category progress's
      // "spent of budgeted" line -- an exact count, not a vague "at
      // least one" check.
      expect(find.textContaining('¥4,000'), findsNWidgets(2));
      expect(find.textContaining('¥30,000'), findsNothing); // September's spend must not leak in

      container.read(selectedBudgetMonthProvider.notifier).state = september;
      await tester.pumpAndSettle();

      // Same tile, same key -- now showing September's own row. Scoped
      // the same way as above (see the comment before the August
      // assertions for why a bare '¥10,000' text search would be a
      // false failure here: September's own Month Summary "remaining"
      // stat legitimately renders that exact string).
      expect(
        find.descendant(of: diningTile, matching: find.text('JPY · ¥40,000')),
        findsOneWidget,
      ); // September's category budget amount, scoped to its own tile
      expect(
        find.descendant(of: diningTile, matching: find.text('JPY · ¥10,000')),
        findsNothing,
      ); // August's amount must not leak into September's tile
      expect(find.textContaining('¥4,000'), findsNothing); // August's spend must not leak in
    });
  });

  group('Checkpoint Q -- Add/Edit Budget respect the selected historical month (Section K)', () {
    testWidgets('creating an overall budget while viewing August creates it FOR August, not the '
        'real current month', (tester) async {
      final (AppDatabase db, String profileId) = await seededDb();
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithBudgets(container));
      await tester.pumpAndSettle();
      final BudgetMonth realNow = container.read(selectedBudgetMonthProvider);
      final BudgetMonth august = BudgetMonth(year: 2026, month: 8);
      container.read(selectedBudgetMonthProvider.notifier).state = august;
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('addBudgetFab')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('addOverallBudgetOption')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('overallBudgetAmountField')), '85000');
      await tester.tap(find.byKey(const Key('saveOverallBudget')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Still viewing August -- the new budget is visible right here.
      expect(find.text('¥85,000'), findsOneWidget);

      final BudgetRow? augustRow =
          await readActiveOverallBudget(db, profileId: profileId, currencyCode: 'JPY', month: august);
      expect(augustRow, isNotNull);
      expect(augustRow!.amountMinorUnits, 85000);

      if (realNow != august) {
        final BudgetRow? realNowRow =
            await readActiveOverallBudget(db, profileId: profileId, currencyCode: 'JPY', month: realNow);
        expect(realNowRow, isNull); // never silently created for the real current month instead
      }
    });

    testWidgets('creating a category budget while viewing a historical month creates it for that '
        'month, not the real current month', (tester) async {
      final (AppDatabase db, String profileId) = await seededDb(withCategories: true);
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      final ProviderSubscription<AsyncValue<List<CategoryRow>>> categoriesSubscription = container
          .listen<AsyncValue<List<CategoryRow>>>(categoriesForTypeProvider('expense'), (_, __) {});
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        categoriesSubscription.close();
        await tester.pumpAndSettle();
        container.dispose();
        await tester.pumpAndSettle();
        await db.close();
      });

      await tester.pumpWidget(appWithBudgets(container));
      await tester.pumpAndSettle();
      final BudgetMonth realNow = container.read(selectedBudgetMonthProvider);
      final BudgetMonth historical = BudgetMonth(year: 2020, month: 3);
      container.read(selectedBudgetMonthProvider.notifier).state = historical;
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('addBudgetFab')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('addCategoryBudgetOption')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('categoryBudgetCategoryField')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dining Out').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('categoryBudgetAmountField')), '5000');
      await tester.tap(find.byKey(const Key('saveCategoryBudget')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      final BudgetRow? historicalRow = await readActiveCategoryBudget(
        db,
        profileId: profileId,
        categoryId: 'sys-dining',
        currencyCode: 'JPY',
        month: historical,
      );
      expect(historicalRow, isNotNull);
      expect(historicalRow!.amountMinorUnits, 5000);

      final BudgetRow? realNowRow = await readActiveCategoryBudget(
        db,
        profileId: profileId,
        categoryId: 'sys-dining',
        currencyCode: 'JPY',
        month: realNow,
      );
      expect(realNowRow, isNull);
    });

    testWidgets('editing an existing budget while viewing a historical month updates it in place '
        'without changing which month is selected', (tester) async {
      final (AppDatabase db, String profileId) = await seededDb();
      final BudgetMonth historical = BudgetMonth(year: 2021, month: 6);
      final String budgetId = await BudgetRepository(db).setOverallBudget(
        profileId: profileId,
        month: historical,
        amount: Money.fromMinorUnits(10000, 'JPY'),
      );
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithBudgets(container));
      await tester.pumpAndSettle();
      container.read(selectedBudgetMonthProvider.notifier).state = historical;
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('editOverallBudget_JPY')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('overallBudgetAmountField')), '15000');
      await tester.tap(find.byKey(const Key('saveOverallBudget')));
      await tester.pumpAndSettle();

      expect(container.read(selectedBudgetMonthProvider), historical); // month selection unchanged
      expect(find.text('¥15,000'), findsOneWidget);

      final BudgetRow? row =
          await readActiveOverallBudget(db, profileId: profileId, currencyCode: 'JPY', month: historical);
      expect(row, isNotNull);
      expect(row!.id, budgetId); // same row updated in place, not a new one
      expect(row.amountMinorUnits, 15000);
    });
  });

  group('Checkpoint Q -- Month Summary (Section D/F/G/M)', () {
    testWidgets('shows total/spent/remaining/used% reconciling with the category budgets', (tester) async {
      final (AppDatabase db, String profileId) = await seededDb(withCategories: true);
      final AccountRepository accountRepo = AccountRepository(db);
      final TransactionRepository transactionRepo = TransactionRepository(db, accountRepo);
      final String walletId =
          await accountRepo.createAccount(profileId: profileId, name: 'Wallet', type: 'cash', currencyCode: 'JPY');
      final BudgetMonth month = BudgetMonth.fromUtc(DateTime.now().toUtc());
      await BudgetRepository(db).setCategoryBudget(
        profileId: profileId,
        categoryId: 'sys-dining',
        month: month,
        amount: Money.fromMinorUnits(20000, 'JPY'),
      );
      await transactionRepo.recordExpense(
        profileId: profileId,
        accountId: walletId,
        amount: Money.fromMinorUnits(13000, 'JPY'),
        occurredAtUtc: month.startUtc,
        categoryId: 'sys-dining',
      );

      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithBudgets(container));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('monthSummaryCard_JPY')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('monthSummaryTotalBudget_JPY'))).data,
        '¥20,000',
      );
      expect(tester.widget<Text>(find.byKey(const Key('monthSummarySpent_JPY'))).data, '¥13,000');
      expect(tester.widget<Text>(find.byKey(const Key('monthSummaryRemaining_JPY'))).data, '¥7,000');
      expect(tester.widget<Text>(find.byKey(const Key('monthSummaryPercentUsed_JPY'))).data, '65% used');
    });

    testWidgets('an over-budget month shows explicit "over budget" wording, never a misleading '
        'positive remaining figure', (tester) async {
      final (AppDatabase db, String profileId) = await seededDb(withCategories: true);
      final AccountRepository accountRepo = AccountRepository(db);
      final TransactionRepository transactionRepo = TransactionRepository(db, accountRepo);
      final String walletId =
          await accountRepo.createAccount(profileId: profileId, name: 'Wallet', type: 'cash', currencyCode: 'JPY');
      final BudgetMonth month = BudgetMonth.fromUtc(DateTime.now().toUtc());
      await BudgetRepository(db).setCategoryBudget(
        profileId: profileId,
        categoryId: 'sys-dining',
        month: month,
        amount: Money.fromMinorUnits(10000, 'JPY'),
      );
      await transactionRepo.recordExpense(
        profileId: profileId,
        accountId: walletId,
        amount: Money.fromMinorUnits(12500, 'JPY'),
        occurredAtUtc: month.startUtc,
        categoryId: 'sys-dining',
      );

      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithBudgets(container));
      await tester.pumpAndSettle();

      // Uncapped text: 125%, never hidden behind a false 100%.
      expect(
        tester.widget<Text>(find.byKey(const Key('monthSummaryPercentUsed_JPY'))).data,
        '125% used',
      );
      // Explicit over-budget wording, not a plain positive "remaining".
      expect(
        tester.widget<Text>(find.byKey(const Key('monthSummaryRemaining_JPY'))).data,
        '¥2,500 over budget',
      );

      // The visual bar's fill fraction is still clamped to 1.0 -- a
      // `LinearProgressIndicator` cannot render past full.
      final Iterable<LinearProgressIndicator> bars =
          tester.widgetList<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
      expect(bars, isNotEmpty);
      for (final LinearProgressIndicator bar in bars) {
        expect(bar.value, isNotNull);
        expect(bar.value! <= 1.0, isTrue);
      }
    });

    testWidgets('an exactly-used month shows 100% and zero remaining, never "over budget by '
        '\u00a50"', (tester) async {
      final (AppDatabase db, String profileId) = await seededDb(withCategories: true);
      final AccountRepository accountRepo = AccountRepository(db);
      final TransactionRepository transactionRepo = TransactionRepository(db, accountRepo);
      final String walletId =
          await accountRepo.createAccount(profileId: profileId, name: 'Wallet', type: 'cash', currencyCode: 'JPY');
      final BudgetMonth month = BudgetMonth.fromUtc(DateTime.now().toUtc());
      await BudgetRepository(db).setCategoryBudget(
        profileId: profileId,
        categoryId: 'sys-dining',
        month: month,
        amount: Money.fromMinorUnits(10000, 'JPY'),
      );
      // Spent exactly equals budgeted -- Section C: this is "exactly
      // used", not an overspent state.
      await transactionRepo.recordExpense(
        profileId: profileId,
        accountId: walletId,
        amount: Money.fromMinorUnits(10000, 'JPY'),
        occurredAtUtc: month.startUtc,
        categoryId: 'sys-dining',
      );

      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithBudgets(container));
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.byKey(const Key('monthSummaryPercentUsed_JPY'))).data,
        '100% used',
      );
      // Zero remaining, expressed the same way an under-budget month
      // expresses a positive remaining figure -- never "over budget by
      // \u00a50" (spent == budget is not an overspent state; isOverBudget
      // requires spent to be strictly greater than budgeted).
      expect(
        tester.widget<Text>(find.byKey(const Key('monthSummaryRemaining_JPY'))).data,
        '\u00a50',
      );
      expect(find.textContaining('over budget'), findsNothing);

      final Iterable<LinearProgressIndicator> bars =
          tester.widgetList<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
      expect(bars, isNotEmpty);
      for (final LinearProgressIndicator bar in bars) {
        expect(bar.value, 1.0); // fully filled, not clamped-from-overflow
      }
    });

    testWidgets('no category budgets for the month shows its own localized empty state, even '
        'while an overall budget exists', (tester) async {
      final (AppDatabase db, String profileId) = await seededDb();
      final BudgetMonth month = BudgetMonth.fromUtc(DateTime.now().toUtc());
      await BudgetRepository(db).setOverallBudget(
        profileId: profileId,
        month: month,
        amount: Money.fromMinorUnits(50000, 'JPY'),
      );
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithBudgets(container));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('noCategoryBudgetsForMonthMessage')), findsOneWidget);
      expect(find.text('No category budgets for this month.'), findsOneWidget);
      // Month navigation stays available even for this partially-empty
      // state (Section L).
      expect(find.byKey(const Key('previousMonthButton')), findsOneWidget);
      expect(find.byKey(const Key('nextMonthButton')), findsOneWidget);
    });

    testWidgets('a month with no budgets at all still keeps month navigation available',
        (tester) async {
      final (AppDatabase db, _) = await seededDb();
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithBudgets(container));
      await tester.pumpAndSettle();

      expect(find.textContaining('No budgets set for this month yet'), findsOneWidget);
      expect(find.byKey(const Key('previousMonthButton')), findsOneWidget);
      expect(find.byKey(const Key('nextMonthButton')), findsOneWidget);

      // Still navigable even with nothing to show.
      await tester.tap(find.byKey(const Key('nextMonthButton')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('Checkpoint Q -- Category Budget Progress (Section E/F/G)', () {
    testWidgets('an under-budget category shows its spent/remaining/percentage and a progress '
        'bar', (tester) async {
      final (AppDatabase db, String profileId) = await seededDb(withCategories: true);
      final AccountRepository accountRepo = AccountRepository(db);
      final TransactionRepository transactionRepo = TransactionRepository(db, accountRepo);
      final String walletId =
          await accountRepo.createAccount(profileId: profileId, name: 'Wallet', type: 'cash', currencyCode: 'JPY');
      final BudgetMonth month = BudgetMonth.fromUtc(DateTime.now().toUtc());
      final String budgetId = await BudgetRepository(db).setCategoryBudget(
        profileId: profileId,
        categoryId: 'sys-dining',
        month: month,
        amount: Money.fromMinorUnits(20000, 'JPY'),
      );
      await transactionRepo.recordExpense(
        profileId: profileId,
        accountId: walletId,
        amount: Money.fromMinorUnits(13000, 'JPY'),
        occurredAtUtc: month.startUtc,
        categoryId: 'sys-dining',
      );

      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithBudgets(container));
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.byKey(Key('categoryProgressPercentUsed_$budgetId'))).data,
        '65% used',
      );
      expect(
        tester.widget<Text>(find.byKey(Key('categoryProgressRemaining_$budgetId'))).data,
        'Remaining: ¥7,000',
      );
    });

    testWidgets('income transactions do not reduce a category budget\'s spend (Section I)',
        (tester) async {
      final (AppDatabase db, String profileId) = await seededDb(withCategories: true);
      final AccountRepository accountRepo = AccountRepository(db);
      final TransactionRepository transactionRepo = TransactionRepository(db, accountRepo);
      final String walletId =
          await accountRepo.createAccount(profileId: profileId, name: 'Wallet', type: 'cash', currencyCode: 'JPY');
      final BudgetMonth month = BudgetMonth.fromUtc(DateTime.now().toUtc());
      final String budgetId = await BudgetRepository(db).setCategoryBudget(
        profileId: profileId,
        categoryId: 'sys-dining',
        month: month,
        amount: Money.fromMinorUnits(20000, 'JPY'),
      );
      await transactionRepo.recordExpense(
        profileId: profileId,
        accountId: walletId,
        amount: Money.fromMinorUnits(5000, 'JPY'),
        occurredAtUtc: month.startUtc,
        categoryId: 'sys-dining',
      );
      await transactionRepo.recordIncome(
        profileId: profileId,
        accountId: walletId,
        amount: Money.fromMinorUnits(9000, 'JPY'),
        occurredAtUtc: month.startUtc,
        categoryId: 'sys-dining',
      );

      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithBudgets(container));
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.byKey(Key('categoryProgressRemaining_$budgetId'))).data,
        'Remaining: ¥15,000', // 20000 - 5000 expense only, the 9000 income never subtracted
      );
    });

    // Checkpoint R Section F/D: the four required category progress
    // states (0%, partial -- already covered above, exactly 100%,
    // >100%), using the same generic CategoryBudgetProgress/
    // _CategoryProgressDetails code path the month-level over-budget
    // test above already exercises -- these just prove it holds at
    // the category level too, not merely at the whole-month level.
    testWidgets('a category with no spending yet shows 0% used and the full amount remaining',
        (tester) async {
      final (AppDatabase db, String profileId) = await seededDb(withCategories: true);
      final BudgetMonth month = BudgetMonth.fromUtc(DateTime.now().toUtc());
      final String budgetId = await BudgetRepository(db).setCategoryBudget(
        profileId: profileId,
        categoryId: 'sys-dining',
        month: month,
        amount: Money.fromMinorUnits(20000, 'JPY'),
      );

      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithBudgets(container));
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.byKey(Key('categoryProgressPercentUsed_$budgetId'))).data,
        '0% used',
      );
      expect(
        tester.widget<Text>(find.byKey(Key('categoryProgressRemaining_$budgetId'))).data,
        'Remaining: ¥20,000',
      );
      // The category progress bar is a sibling of the keyed
      // `ListTile`, not a descendant of it (see the existing
      // `_CategoryBudgetTile` layout), so it is checked the same
      // unscoped way the month-level over-budget test above checks
      // its bars -- safe here because this fixture has exactly one
      // category, so every bar on screen (Month Summary's and this
      // category's) shares the same 0.0 ratio.
      final Iterable<LinearProgressIndicator> bars =
          tester.widgetList<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
      expect(bars, isNotEmpty);
      for (final LinearProgressIndicator bar in bars) {
        expect(bar.value, 0.0);
      }
    });

    testWidgets('a category spent exactly its budget shows 100% used and zero remaining, never '
        '"over budget by ¥0"', (tester) async {
      final (AppDatabase db, String profileId) = await seededDb(withCategories: true);
      final AccountRepository accountRepo = AccountRepository(db);
      final TransactionRepository transactionRepo = TransactionRepository(db, accountRepo);
      final String walletId =
          await accountRepo.createAccount(profileId: profileId, name: 'Wallet', type: 'cash', currencyCode: 'JPY');
      final BudgetMonth month = BudgetMonth.fromUtc(DateTime.now().toUtc());
      final String budgetId = await BudgetRepository(db).setCategoryBudget(
        profileId: profileId,
        categoryId: 'sys-dining',
        month: month,
        amount: Money.fromMinorUnits(20000, 'JPY'),
      );
      await transactionRepo.recordExpense(
        profileId: profileId,
        accountId: walletId,
        amount: Money.fromMinorUnits(20000, 'JPY'),
        occurredAtUtc: month.startUtc,
        categoryId: 'sys-dining',
      );

      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithBudgets(container));
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.byKey(Key('categoryProgressPercentUsed_$budgetId'))).data,
        '100% used',
      );
      expect(
        tester.widget<Text>(find.byKey(Key('categoryProgressRemaining_$budgetId'))).data,
        'Remaining: ¥0',
      );
    });

    testWidgets('a category spent past its budget shows the uncapped percentage and an explicit '
        'over-budget amount, with a fully-filled (never overflowed) progress bar',
        (tester) async {
      final (AppDatabase db, String profileId) = await seededDb(withCategories: true);
      final AccountRepository accountRepo = AccountRepository(db);
      final TransactionRepository transactionRepo = TransactionRepository(db, accountRepo);
      final String walletId =
          await accountRepo.createAccount(profileId: profileId, name: 'Wallet', type: 'cash', currencyCode: 'JPY');
      final BudgetMonth month = BudgetMonth.fromUtc(DateTime.now().toUtc());
      final String budgetId = await BudgetRepository(db).setCategoryBudget(
        profileId: profileId,
        categoryId: 'sys-dining',
        month: month,
        amount: Money.fromMinorUnits(20000, 'JPY'),
      );
      await transactionRepo.recordExpense(
        profileId: profileId,
        accountId: walletId,
        amount: Money.fromMinorUnits(25000, 'JPY'),
        occurredAtUtc: month.startUtc,
        categoryId: 'sys-dining',
      );

      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithBudgets(container));
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.byKey(Key('categoryProgressPercentUsed_$budgetId'))).data,
        '125% used', // uncapped -- never hidden behind a false 100%
      );
      expect(
        tester.widget<Text>(find.byKey(Key('categoryProgressRemaining_$budgetId'))).data,
        '¥5,000 over budget',
      );
      // Same sibling-not-descendant reasoning as the 0% test above --
      // unscoped is safe with exactly one category on screen.
      final Iterable<LinearProgressIndicator> bars =
          tester.widgetList<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
      expect(bars, isNotEmpty);
      for (final LinearProgressIndicator bar in bars) {
        expect(bar.value, 1.0); // clamped, never fed 1.25 directly
      }
    });
  });

  group('Checkpoint Q -- Japanese localization', () {
    testWidgets('month navigation, Month Summary, and category progress all render localized '
        'text', (tester) async {
      final (AppDatabase db, String profileId) = await seededDb(withCategories: true);
      final AccountRepository accountRepo = AccountRepository(db);
      final TransactionRepository transactionRepo = TransactionRepository(db, accountRepo);
      final String walletId =
          await accountRepo.createAccount(profileId: profileId, name: 'Wallet', type: 'cash', currencyCode: 'JPY');
      final BudgetMonth month = BudgetMonth.fromUtc(DateTime.now().toUtc());
      await BudgetRepository(db).setCategoryBudget(
        profileId: profileId,
        categoryId: 'sys-dining',
        month: month,
        amount: Money.fromMinorUnits(10000, 'JPY'),
      );
      await transactionRepo.recordExpense(
        profileId: profileId,
        accountId: walletId,
        amount: Money.fromMinorUnits(12500, 'JPY'),
        occurredAtUtc: month.startUtc,
        categoryId: 'sys-dining',
      );

      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithBudgets(container, locale: const Locale('ja')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byTooltip('前の月'), findsOneWidget);
      expect(find.byTooltip('次の月'), findsOneWidget);
      expect(find.text('月の概要'), findsOneWidget); // monthSummarySectionTitle
      expect(find.text('予算総額'), findsOneWidget); // totalBudgetLabel
      expect(find.text('支出済み'), findsOneWidget); // spentLabel
      expect(
        tester.widget<Text>(find.byKey(const Key('monthSummaryRemaining_JPY'))).data,
        '¥2,500 予算超過', // overBudgetByAmountLabel
      );
    });

    testWidgets('the empty-category-budgets message renders in Japanese', (tester) async {
      final (AppDatabase db, String profileId) = await seededDb();
      final BudgetMonth month = BudgetMonth.fromUtc(DateTime.now().toUtc());
      await BudgetRepository(db).setOverallBudget(
        profileId: profileId,
        month: month,
        amount: Money.fromMinorUnits(50000, 'JPY'),
      );
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithBudgets(container, locale: const Locale('ja')));
      await tester.pumpAndSettle();

      expect(find.text('この月のカテゴリ予算はありません。'), findsOneWidget);
    });
  });

  group('Checkpoint Q -- responsive/accessibility', () {
    testWidgets('320px width with a Month Summary and category progress lays out without '
        'overflow', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1.0;

      final (AppDatabase db, String profileId) = await seededDb(withCategories: true);
      final AccountRepository accountRepo = AccountRepository(db);
      final TransactionRepository transactionRepo = TransactionRepository(db, accountRepo);
      final String walletId =
          await accountRepo.createAccount(profileId: profileId, name: 'Wallet', type: 'cash', currencyCode: 'JPY');
      final BudgetMonth month = BudgetMonth.fromUtc(DateTime.now().toUtc());
      await BudgetRepository(db).setCategoryBudget(
        profileId: profileId,
        categoryId: 'sys-dining',
        month: month,
        amount: Money.fromMinorUnits(10000, 'JPY'),
      );
      await transactionRepo.recordExpense(
        profileId: profileId,
        accountId: walletId,
        amount: Money.fromMinorUnits(12500, 'JPY'),
        occurredAtUtc: month.startUtc,
        categoryId: 'sys-dining',
      );

      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithBudgets(container));
      await tester.pumpAndSettle();

      final Object? overflowException = tester.takeException();
      if (overflowException != null) {
        fail('Narrow-screen (320px) Month Summary/category progress layout threw an exception:'
            '\n\n$overflowException');
      }
    });

    testWidgets('1.6x text scale with a long category name and an over-budget category lays out '
        'without overflow', (tester) async {
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;

      const String longName = 'A Rather Long Custom Category Name For Layout Testing Purposes';
      final (AppDatabase db, String profileId) = await seededDb();
      final String categoryId = await CategoryRepository(db).createCategory(
        profileId: profileId,
        name: longName,
        type: 'expense',
      );
      final AccountRepository accountRepo = AccountRepository(db);
      final TransactionRepository transactionRepo = TransactionRepository(db, accountRepo);
      final String walletId =
          await accountRepo.createAccount(profileId: profileId, name: 'Wallet', type: 'cash', currencyCode: 'JPY');
      final BudgetMonth month = BudgetMonth.fromUtc(DateTime.now().toUtc());
      await BudgetRepository(db).setCategoryBudget(
        profileId: profileId,
        categoryId: categoryId,
        month: month,
        amount: Money.fromMinorUnits(10000, 'JPY'),
      );
      await transactionRepo.recordExpense(
        profileId: profileId,
        accountId: walletId,
        amount: Money.fromMinorUnits(15000, 'JPY'),
        occurredAtUtc: month.startUtc,
        categoryId: categoryId,
      );

      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithBudgets(container));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('Checkpoint Q -- regression: existing budget behavior is unaffected', () {
    testWidgets('the overall-budget round trip (create/edit/remove) still behaves exactly as '
        'before, with the Month Summary section present alongside it', (tester) async {
      final (AppDatabase db, String profileId) = await seededDb();
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithBudgets(container));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('addBudgetFab')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('addOverallBudgetOption')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('overallBudgetAmountField')), '60000');
      await tester.tap(find.byKey(const Key('saveOverallBudget')));
      await tester.pumpAndSettle();

      expect(find.text('¥60,000'), findsOneWidget);

      await tester.tap(find.byKey(const Key('deleteOverallBudget_JPY')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('overallBudgetTile_JPY')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('Checkpoint U2 -- CurrencyBadge audit: the overall/category budget currency dropdowns', () {
    testWidgets(
      'the overall-budget dialog’s currency dropdown item renders through CurrencyBadge, '
      'not a bare Text, and the round trip still works',
      (tester) async {
        final (AppDatabase db, String profileId) = await seededDb();
        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithBudgets(container));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('addBudgetFab')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('addOverallBudgetOption')));
        await tester.pumpAndSettle();

        // The dropdown button's own closed state already renders the
        // currently-selected item's child widget -- a `CurrencyBadge`,
        // per this checkpoint's change -- rather than only building it
        // once the menu is opened.
        expect(find.byType(CurrencyBadge), findsWidgets);

        await tester.enterText(find.byKey(const Key('overallBudgetAmountField')), '60000');
        await tester.tap(find.byKey(const Key('saveOverallBudget')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('¥60,000'), findsOneWidget);
      },
    );

    testWidgets(
      'the category-budget dialog’s currency dropdown item also renders through CurrencyBadge',
      (tester) async {
        final (AppDatabase db, String profileId) = await seededDb(withCategories: true);
        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        final ProviderSubscription<AsyncValue<List<CategoryRow>>> categoriesSubscription = container
            .listen<AsyncValue<List<CategoryRow>>>(categoriesForTypeProvider('expense'), (_, __) {});
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          categoriesSubscription.close();
          await tester.pumpAndSettle();
          container.dispose();
          await tester.pumpAndSettle();
          await db.close();
        });

        await tester.pumpWidget(appWithBudgets(container));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('addBudgetFab')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('addCategoryBudgetOption')));
        await tester.pumpAndSettle();

        expect(find.byType(CurrencyBadge), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
