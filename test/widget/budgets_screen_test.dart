import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/providers.dart';
import 'package:ai_financial_coach/core/database/repositories/budget_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/category_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/money/money.dart';
import 'package:ai_financial_coach/features/budgets/domain/budget_month.dart';
import 'package:ai_financial_coach/features/budgets/presentation/budgets_screen.dart';
import 'package:ai_financial_coach/features/categories/presentation/category_providers.dart';
import 'package:ai_financial_coach/l10n/generated/app_localizations.dart';
import 'package:drift/native.dart';
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
    expect(find.textContaining('¥20,000'), findsOneWidget);
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
    expect(
      find.descendant(
        of: find.byKey(Key('categoryBudgetTile_${categoryId}_KWD')),
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
        expect(find.textContaining('K9,999,999.99'), findsOneWidget);
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
}
