import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/providers.dart';
import 'package:ai_financial_coach/core/database/repositories/category_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/features/categories/presentation/categories_screen.dart';
import 'package:ai_financial_coach/l10n/generated/app_localizations.dart';
import 'package:ai_financial_coach/shared/theme/app_tokens.dart';
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
    // Also seeded so a custom category coexists with the system set at
    // this extreme scale; no longer used as a scroll target below (see
    // the comment ahead of the drag loop for why).
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
    // `PageView`'s own), so a page-wide `find.byType(Scrollable)` finder
    // would be ambiguous ("Too many elements") and can't tell which one
    // to drag.
    //
    // CP7.5 wrapped each row in a taller `AppCard`, which at this
    // 320px-wide/2.0x-scale extreme now pushes 'Dining Out' below the
    // initial viewport -- so it can no longer be assumed to already be
    // mounted, and an ancestor lookup from its own text can no longer be
    // used to *locate* the Expense `ListView` in the first place (that
    // lookup would itself find nothing until after scrolling -- the
    // exact chicken-and-egg this rewrite avoids). Instead, the Expense
    // `ListView` is located by its stable INDEX: it is always the first
    // of `TabBarView`'s two children, per `CategoriesScreen`'s own
    // `children: <Widget>[_CategoryList(type: 'expense'),
    // _CategoryList(type: 'income')]` -- true regardless of what has or
    // hasn't scrolled into view yet.
    final Finder expenseListView = find.byType(ListView).first;
    expect(expenseListView, findsOneWidget);

    // A manual, explicitly BOUNDED drag loop -- not `dragUntilVisible`/
    // `scrollUntilVisible`. Both of those helpers keep re-checking the
    // SAME target finder and assume that continuing to drag in one
    // direction will eventually reveal it, but that assumption doesn't
    // hold for every category in this list: `CategoryRepository`'s query
    // orders rows by `orderBy(sortOrder, name)` (see
    // `watchAvailableFor`), i.e. alphabetically once `sortOrder` ties,
    // so 'Another Custom Category' (A...) actually sorts BEFORE 'Dining
    // Out' (D...) -- it is never reachable by scrolling further down
    // past 'Dining Out', which is what made `dragUntilVisible` throw
    // "Bad state: No element" here even with its own 50-iteration
    // budget. 'Dining Out' is the one row CP7.5's taller `AppCard`
    // wrapping actually pushed below the initial viewport at this
    // narrow width / extreme text scale, so it is the one meaningful
    // "can the list still reach its offscreen content" checkpoint; a
    // small bounded number of upward drags is enough to reach it
    // without guessing an exact pixel distance, and if the list were
    // ever genuinely stuck (non-scrollable) or the row never rendered,
    // the loop would simply exhaust its bound and the assertion right
    // after it would fail loudly.
    const int maxDragAttempts = 15;
    for (int attempt = 0;
        attempt < maxDragAttempts && find.text('Dining Out').evaluate().isEmpty;
        attempt++) {
      await tester.drag(expenseListView, const Offset(0, -300));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Dining Out'), findsOneWidget);
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

    // ---------------------------------------------------------------------
    // Visual System Convergence Checkpoint 7.5: locks in each category
    // row's new bordered-card visual treatment (`AppCard(bordered: true)`)
    // via the same shape/side/color contract `app_card_test.dart`/
    // `accounts_screen_test.dart` already assert for `AppCard` -- never a
    // pixel value. `ListTile` remains the literal ancestor type this
    // file's other tests already rely on (`find.ancestor(..., matching:
    // find.byType(ListTile))`), with `AppCard` as an additional ancestor
    // around it, and the system-category indicator now renders as an
    // `AppStatusChip` pill rather than a bare `Text` -- so this also
    // confirms that pill still carries the exact same localized label.
    // ---------------------------------------------------------------------
    testWidgets(
        'CP7.5: a category row renders inside a bordered, near-white card matching the '
        'converged visual system, with ListTile still the direct ancestor of its name',
        (tester) async {
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

      // Still findable via the exact same ancestor-scoped pattern this
      // file's other tests use -- `ListTile` remains a literal ancestor,
      // `AppCard` is simply an additional one further up the tree.
      final Finder systemTile =
          find.ancestor(of: find.text('Dining Out'), matching: find.byType(ListTile));
      expect(systemTile, findsOneWidget);
      expect(find.descendant(of: systemTile, matching: find.text('System')), findsOneWidget);

      final Card cardWidget = tester.widget<Card>(
        find.ancestor(of: systemTile, matching: find.byType(Card)).first,
      );
      final BuildContext context = tester.element(systemTile);
      final ColorScheme colors = Theme.of(context).colorScheme;
      final AppTokens tokens = context.appTokens;

      expect(cardWidget.color, colors.surface);
      expect(cardWidget.elevation, 0);
      final RoundedRectangleBorder shape = cardWidget.shape! as RoundedRectangleBorder;
      expect(shape.side.color, tokens.colors.subtleBorder);
    });
  });
}
