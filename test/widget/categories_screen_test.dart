import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/providers.dart';
import 'package:ai_financial_coach/core/database/repositories/category_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/features/categories/presentation/categories_screen.dart';
import 'package:ai_financial_coach/l10n/generated/app_localizations.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// NOTE: exercises generated Drift code — see CLAUDE_FIRST_CODING_PROMPT.md.
//
// CP5.4c: Categories was the only CP5.4-audited surface with no widget
// coverage. The audit found no demonstrated layout defect here -- no
// money is displayed, a long custom category name never competes with
// a trailing "System" label (only `category.isSystem` rows carry one),
// and `ListTile` already wraps a long title safely -- so this file is
// baseline coverage rather than a defect-driven hardening pass.

void main() {
  Future<(AppDatabase, String)> seededDb() async {
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
    return (db, profileId);
  }

  Widget appWithCategories(
    ProviderContainer container, {
    Locale locale = const Locale('en'),
  }) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const CategoriesScreen(),
      ),
    );
  }

  /// Same deterministic shutdown sequence every other widget test file in
  /// this project uses: unmount, then dispose, then one `pumpAndSettle()`
  /// so Drift's `StreamQueryStore.markAsClosed` `Timer.zero` fires before
  /// `db.close()`.
  Future<void> disposeInOrder(WidgetTester tester, ProviderContainer container, AppDatabase db) async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pumpAndSettle();
    await db.close();
  }

  testWidgets(
      'CP5.4c: a system category and a custom category both render, and only the system one '
      'shows the System indicator', (tester) async {
    final (AppDatabase db, String profileId) = await seededDb();
    await CategoryRepository(db).seedSystemCategoriesIfNeeded();
    await CategoryRepository(db).createCategory(
      profileId: profileId,
      name: 'My Custom Category',
      type: 'expense',
    );

    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithCategories(container));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // 'Dining Out' is one of the seeded system expense categories --
    // see `category_repository.dart`'s `_systemCategories`.
    expect(find.text('Dining Out'), findsOneWidget);
    expect(find.text('My Custom Category'), findsOneWidget);

    // Scoped to each category's own tile -- not a page-wide
    // find.text('System') -- since several system categories are
    // seeded and each independently shows its own "System" label.
    final Finder systemTile =
        find.ancestor(of: find.text('Dining Out'), matching: find.byType(ListTile));
    expect(systemTile, findsOneWidget);
    expect(find.descendant(of: systemTile, matching: find.text('System')), findsOneWidget);

    final Finder customTile =
        find.ancestor(of: find.text('My Custom Category'), matching: find.byType(ListTile));
    expect(customTile, findsOneWidget);
    expect(find.descendant(of: customTile, matching: find.text('System')), findsNothing);
  });

  testWidgets(
      'CP5.4c: a long custom category name is still represented in full by its Text widget at '
      'a narrow 320px width and a 1.6x text scale', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    const String longName = 'A rather long custom category name to stress narrow-width layout';
    final (AppDatabase db, String profileId) = await seededDb();
    await CategoryRepository(db).createCategory(
      profileId: profileId,
      name: longName,
      type: 'expense',
    );

    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithCategories(container));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // `find.text` matches a `Text` widget's `data` by exact equality --
    // finding it here already proves the widget holds the complete,
    // untruncated string, regardless of how many visual lines it wraps
    // onto (no `overflow`/`maxLines` is set on this Text in production,
    // so it wraps rather than clips -- per the CP5.4 audit). Wrapping
    // is acceptable and is deliberately not asserted against here.
    expect(find.text(longName), findsOneWidget);
    // A custom category never carries the "System" trailing label in
    // the first place (only `category.isSystem` rows do), so there is
    // nothing here that could compete with it for space -- this
    // confirms the wrap is clean, not incidentally masking a collision.
    final Finder tile = find.ancestor(of: find.text(longName), matching: find.byType(ListTile));
    expect(tile, findsOneWidget);
    expect(find.descendant(of: tile, matching: find.text('System')), findsNothing);
  });

  testWidgets(
      'CP5.4c: the categories screen remains renderable and its list stays scrollable at a '
      'narrow 320px width and an extreme 2.0x text scale', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final (AppDatabase db, String profileId) = await seededDb();
    await CategoryRepository(db).seedSystemCategoriesIfNeeded();
    await CategoryRepository(db).createCategory(
      profileId: profileId,
      name: 'Another Custom Category',
      type: 'expense',
    );

    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithCategories(container));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Categories'), findsOneWidget); // app bar title

    // `TabBarView` builds both tabs' `_CategoryList`s up front (a plain
    // `PageView(children: [...])`, not a lazy builder), and
    // `seedSystemCategoriesIfNeeded()` seeds system categories for both
    // types -- so the Income tab's own `ListView` (showing "Salary"
    // etc.) is *also* present in the tree, off-screen, right alongside
    // the visible Expense one. That means there is more than one
    // `Scrollable` on screen at once (each `ListView`'s own, plus the
    // `PageView`'s own), so `scrollUntilVisible`'s default page-wide
    // `find.byType(Scrollable)` finder is ambiguous ("Too many
    // elements") -- it can't tell which `Scrollable` to drag. Resolving
    // the visible Expense `ListView` specifically -- via its ancestry
    // from 'Dining Out', a system category only ever shown under
    // Expense -- and dragging exactly that widget sidesteps the
    // ambiguity rather than working around it with a looser finder.
    final Finder expenseListView =
        find.ancestor(of: find.text('Dining Out'), matching: find.byType(ListView));
    expect(expenseListView, findsOneWidget);

    // The custom category is seeded last (after every system category),
    // so reaching it confirms the list stays usable (still scrollable,
    // no exception) at this extreme scale rather than only checking
    // whatever already happens to be on screen without scrolling.
    // Bounded, incremental drags on that specific `ListView` -- rather
    // than a single guessed distance -- so this doesn't depend on
    // exactly how tall each row renders at 2.0x scale.
    for (int i = 0; i < 10 && find.text('Another Custom Category').evaluate().isEmpty; i++) {
      await tester.drag(expenseListView, const Offset(0, -300));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Another Custom Category'), findsOneWidget);
  });

  testWidgets(
      'CP5.4c: the Income tab shows its own system and custom categories with the same '
      'System-indicator distinction as Expense', (tester) async {
    final (AppDatabase db, String profileId) = await seededDb();
    await CategoryRepository(db).seedSystemCategoriesIfNeeded();
    await CategoryRepository(db).createCategory(
      profileId: profileId,
      name: 'Freelance Work',
      type: 'income',
    );

    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithCategories(container));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Income'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // 'Salary' is the seeded system income category -- see
    // `category_repository.dart`'s `_systemCategories`.
    expect(find.text('Salary'), findsOneWidget);
    expect(find.text('Freelance Work'), findsOneWidget);

    final Finder systemTile = find.ancestor(of: find.text('Salary'), matching: find.byType(ListTile));
    expect(systemTile, findsOneWidget);
    expect(find.descendant(of: systemTile, matching: find.text('System')), findsOneWidget);

    final Finder customTile =
        find.ancestor(of: find.text('Freelance Work'), matching: find.byType(ListTile));
    expect(customTile, findsOneWidget);
    expect(find.descendant(of: customTile, matching: find.text('System')), findsNothing);
  });

  group('CP6.7 Japanese localization', () {
    testWidgets(
        'CP6.7 (A): the categories screen renders in Japanese -- app bar, tabs, and the System '
        'indicator', (tester) async {
      final (AppDatabase db, String profileId) = await seededDb();
      await CategoryRepository(db).seedSystemCategoriesIfNeeded();
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithCategories(container, locale: const Locale('ja')));
      await tester.pumpAndSettle();

      expect(find.text('カテゴリ'), findsOneWidget); // AppBar title
      expect(find.text('支出'), findsOneWidget); // Expense tab
      expect(find.text('収入'), findsOneWidget); // Income tab

      final Finder systemTile =
          find.ancestor(of: find.text('Dining Out'), matching: find.byType(ListTile));
      expect(systemTile, findsOneWidget);
      expect(find.descendant(of: systemTile, matching: find.text('システム')), findsOneWidget);
    });

    testWidgets('CP6.7 (B): tapping the Income tab under the Japanese locale switches to the '
        'Income list', (tester) async {
      final (AppDatabase db, String profileId) = await seededDb();
      await CategoryRepository(db).seedSystemCategoriesIfNeeded();
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithCategories(container, locale: const Locale('ja')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('収入'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Salary'), findsOneWidget); // seeded system income category
    });

    testWidgets(
        'CP6.7 (C): a Japanese-language custom category name renders exactly as entered, and a '
        'system category name stays the untranslated English seed value', (tester) async {
      final (AppDatabase db, String profileId) = await seededDb();
      await CategoryRepository(db).seedSystemCategoriesIfNeeded();
      await CategoryRepository(db).createCategory(
        profileId: profileId,
        name: '推し活',
        type: 'expense',
      );
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithCategories(container, locale: const Locale('ja')));
      await tester.pumpAndSettle();

      expect(find.text('推し活'), findsOneWidget); // untouched user text, never translated
      expect(find.text('Dining Out'), findsOneWidget); // untouched system seed name, never translated

      final Finder customTile =
          find.ancestor(of: find.text('推し活'), matching: find.byType(ListTile));
      expect(find.descendant(of: customTile, matching: find.text('システム')), findsNothing);
    });

    testWidgets(
        'CP6.7 (D): creating an expense category and an income category both work end-to-end '
        'through the fully localized Japanese Add-category dialog', (tester) async {
      final (AppDatabase db, String profileId) = await seededDb();
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithCategories(container, locale: const Locale('ja')));
      await tester.pumpAndSettle();

      // Expense (the default tab).
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text('支出カテゴリを追加'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '交通費');
      await tester.tap(find.text('追加')); // Add
      await tester.pumpAndSettle();
      expect(find.text('交通費'), findsOneWidget);

      // Income.
      await tester.tap(find.text('収入'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text('収入カテゴリを追加'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '副業');
      await tester.tap(find.text('追加')); // Add
      await tester.pumpAndSettle();
      expect(find.text('副業'), findsOneWidget);

      final List<CategoryRow> categories = await db.select(db.categories).get();
      expect(categories.where((c) => c.name == '交通費' && c.type == 'expense'), hasLength(1));
      expect(categories.where((c) => c.name == '副業' && c.type == 'income'), hasLength(1));
    });

    testWidgets(
        'CP6.7 (E): the categories screen renders without overflow under the Japanese locale at '
        'a 1.6x text scale', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final (AppDatabase db, String profileId) = await seededDb();
      await CategoryRepository(db).seedSystemCategoriesIfNeeded();
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithCategories(container, locale: const Locale('ja')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('カテゴリ'), findsOneWidget);
    });

    testWidgets(
        'CP6.7 (F): the categories screen renders without overflow under the Japanese locale at '
        'an extreme 2.0x text scale', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final (AppDatabase db, String profileId) = await seededDb();
      await CategoryRepository(db).seedSystemCategoriesIfNeeded();
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithCategories(container, locale: const Locale('ja')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('カテゴリ'), findsOneWidget);
    });

    testWidgets(
        'CP6.7 (G): a long Japanese custom category name is still represented in full by its '
        'Text widget at a narrow 320px width and a 1.6x text scale', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      const String longName = '狭い画面のレイアウトを検証するための、かなり長いカテゴリの名前';
      final (AppDatabase db, String profileId) = await seededDb();
      await CategoryRepository(db).createCategory(
        profileId: profileId,
        name: longName,
        type: 'expense',
      );

      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithCategories(container, locale: const Locale('ja')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(longName), findsOneWidget);
    });
  });
}
