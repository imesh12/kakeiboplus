import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/providers.dart';
import 'package:ai_financial_coach/core/database/repositories/budget_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/category_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/money/money.dart';
import 'package:ai_financial_coach/features/budgets/domain/budget_month.dart';
import 'package:ai_financial_coach/features/budgets/presentation/budgets_screen.dart';
import 'package:ai_financial_coach/features/categories/presentation/category_providers.dart';
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

  Widget appWithBudgets(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: BudgetsScreen()),
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
}
