import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/providers.dart';
import 'package:ai_financial_coach/core/database/repositories/account_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/category_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/transaction_repository.dart';
import 'package:ai_financial_coach/core/money/money.dart';
import 'package:ai_financial_coach/core/money/money_formatter.dart';
import 'package:ai_financial_coach/core/routing/app_routes.dart';
import 'package:ai_financial_coach/l10n/generated/app_localizations.dart';
import 'package:ai_financial_coach/features/transactions/presentation/edit_transaction_screen.dart';
import 'package:ai_financial_coach/features/transactions/presentation/transaction_detail_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// NOTE: exercises generated Drift code -- see CLAUDE_FIRST_CODING_PROMPT.md.
//
// Beta 1 Transaction UX (`docs/14_DECISION_LOG.md` ADR-025), Phase A &
// Phase B Checkpoint 4 (visual polish). Uses a real (minimal) `GoRouter`
// ancestor -- same pattern as `test/widget/home_screen_test.dart`'s
// `appWithRouter` -- because `TransactionDetailScreen`'s edit button and
// delete confirmation both navigate via `context.push`/`context.pop`,
// which throw without a `GoRouter` in the tree (see
// `test/widget/goal_detail_screen_test.dart`'s note on why ITS delete
// flow is deliberately NOT exercised the same way there). Real
// `EditTransactionScreen` is registered at the real edit route so the
// edit button's navigation can be verified end to end.
//
// Checkpoint 4 note on category-name duplication: the new header block
// clearly displays a resolved category name (per the checkpoint's own
// requirement), and the metadata section still exposes its own
// "Category" row with the same name (also required, unchanged from
// before) -- so a resolved category's name now legitimately renders
// twice in the tree. Where that matters below, assertions use
// `findsWidgets` (at least one) rather than `findsOneWidget` for that
// specific text; every other assertion is unaffected.

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

  /// A minimal real `GoRouter`: an "Activity" stub with a button that
  /// pushes to the real detail route, the real detail route, and the
  /// real edit route -- enough for `TransactionDetailScreen`'s own
  /// `context.push`/`context.pop` calls to have somewhere to go, without
  /// pulling in the real `ActivityScreen` (which isn't what these tests
  /// are about).
  Widget appWithRouter(
    ProviderContainer container,
    String transactionId, {
    Locale locale = const Locale('en'),
  }) {
    final GoRouter router = GoRouter(
      initialLocation: '/activity',
      routes: <RouteBase>[
        GoRoute(
          path: '/activity',
          builder: (context, state) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => context.push(AppRoutes.transactionDetail(transactionId)),
                child: const Text('open detail'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.transactionDetailPath,
          builder: (context, state) =>
              TransactionDetailScreen(transactionId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: AppRoutes.editTransactionPath,
          builder: (context, state) =>
              EditTransactionScreen(transactionId: state.pathParameters['id']!),
        ),
      ],
    );
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        // CP6.2 Follow-up: `AddTransactionScreen` (reached here via
        // `EditTransactionScreen`) now reads `AppLocalizations.of(context)`,
        // so this harness needs the same localization wiring
        // `add_transaction_screen_test.dart`'s `appWithPushedScreen()` and
        // `app_shell_test.dart`'s `buildApp()` already carry. Most tests in
        // this file expect English text (e.g. 'Edit expense') and rely on
        // the `locale` default of `const Locale('en')`; the CP6.9 Japanese
        // localization group below passes `locale: const Locale('ja')`
        // explicitly.
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
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
  /// setup and works regardless of whether the semantics tree is
  /// enabled. Same helper `activity_screen_test.dart` uses for the same
  /// reason -- deliberately not a fragile whole-semantics-tree snapshot.
  bool hasSemanticsLabel(WidgetTester tester, String label) {
    return tester
        .widgetList<Semantics>(find.byType(Semantics))
        .any((Semantics s) => s.properties.label == label);
  }

  testWidgets('shows account, category, amount, date, and note for an expense', (tester) async {
    final (AppDatabase db, String profileId, String accountId) = await seededDb();
    final TransactionRepository txRepo = TransactionRepository(db, AccountRepository(db));
    final String txId = await txRepo.recordExpense(
      profileId: profileId,
      accountId: accountId,
      amount: Money.fromMinorUnits(1200, 'JPY'),
      categoryId: 'sys-dining',
      note: 'Lunch',
      occurredAtUtc: DateTime.utc(2026, 3, 15, 8, 0),
    );

    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithRouter(container, txId));
    await tester.tap(find.text('open detail'));
    await tester.pumpAndSettle();

    expect(find.text('-¥1,200'), findsOneWidget); // expense: "-" prefix + formatted amount
    expect(find.text('Wallet'), findsOneWidget);
    // Checkpoint 4: the category name now renders in both the new
    // header and the (still-present) metadata "Category" row -- see the
    // file-level note above.
    expect(find.text('Dining Out'), findsWidgets);
    expect(find.text('Lunch'), findsOneWidget);
    expect(find.byKey(const Key('editTransaction')), findsOneWidget);
    expect(find.byKey(const Key('deleteTransaction')), findsOneWidget);
  });

  testWidgets('a soft-deleted transaction shows an unavailable state with no edit/delete actions',
      (tester) async {
    final (AppDatabase db, String profileId, String accountId) = await seededDb();
    final TransactionRepository txRepo = TransactionRepository(db, AccountRepository(db));
    final String txId = await txRepo.recordExpense(
      profileId: profileId,
      accountId: accountId,
      amount: Money.fromMinorUnits(500, 'JPY'),
      occurredAtUtc: DateTime.utc(2026, 1, 1),
    );
    await txRepo.softDelete(txId);

    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithRouter(container, txId));
    await tester.tap(find.text('open detail'));
    await tester.pumpAndSettle();

    expect(
      find.text('This transaction is no longer available -- it may have been deleted elsewhere.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('editTransaction')), findsNothing);
    expect(find.byKey(const Key('deleteTransaction')), findsNothing);
  });

  testWidgets(
      'a nonexistent transaction id shows the same unavailable state as a soft-deleted one',
      (tester) async {
    final (AppDatabase db, String _, String _) = await seededDb();
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithRouter(container, 'does-not-exist'));
    await tester.tap(find.text('open detail'));
    await tester.pumpAndSettle();

    expect(
      find.text('This transaction is no longer available -- it may have been deleted elsewhere.'),
      findsOneWidget,
    );
  });

  testWidgets('tapping edit navigates to the edit screen, prefilled with the existing values',
      (tester) async {
    final (AppDatabase db, String profileId, String accountId) = await seededDb();
    final TransactionRepository txRepo = TransactionRepository(db, AccountRepository(db));
    final String txId = await txRepo.recordExpense(
      profileId: profileId,
      accountId: accountId,
      amount: Money.fromMinorUnits(1200, 'JPY'),
      note: 'Lunch',
      occurredAtUtc: DateTime.utc(2026, 1, 1),
    );

    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithRouter(container, txId));
    await tester.tap(find.text('open detail'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('editTransaction')));
    await tester.pumpAndSettle();

    expect(find.text('Edit expense'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField).first).controller!.text,
      '1200',
    );
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField).last).initialValue,
      'Lunch',
    );
  });

  testWidgets('confirming delete calls softDelete and pops back to the previous screen',
      (tester) async {
    final (AppDatabase db, String profileId, String accountId) = await seededDb();
    final TransactionRepository txRepo = TransactionRepository(db, AccountRepository(db));
    final String txId = await txRepo.recordExpense(
      profileId: profileId,
      accountId: accountId,
      amount: Money.fromMinorUnits(500, 'JPY'),
      occurredAtUtc: DateTime.utc(2026, 1, 1),
    );

    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithRouter(container, txId));
    await tester.tap(find.text('open detail'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('deleteTransaction')));
    await tester.pumpAndSettle();
    expect(find.text('Delete this transaction?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirmDeleteTransaction')));
    await tester.pumpAndSettle();
    // One extra settle cycle: softDelete's own write is the LAST
    // emission on transactionByIdProvider(txId) (StreamProvider
    // .autoDispose.family) at almost the same moment context.pop()
    // drops its last listener -- that overlap needs a beat longer than
    // a single pumpAndSettle() to fully drain before disposeInOrder
    // forces an unmount.
    await tester.pumpAndSettle();

    expect(find.text('open detail'), findsOneWidget); // popped back
    final Transaction row =
        await (db.select(db.transactions)..where((tbl) => tbl.id.equals(txId))).getSingle();
    expect(row.deletedAt, isNotNull);
  });

  testWidgets('cancelling the delete confirmation leaves the transaction untouched',
      (tester) async {
    final (AppDatabase db, String profileId, String accountId) = await seededDb();
    final TransactionRepository txRepo = TransactionRepository(db, AccountRepository(db));
    final String txId = await txRepo.recordExpense(
      profileId: profileId,
      accountId: accountId,
      amount: Money.fromMinorUnits(500, 'JPY'),
      occurredAtUtc: DateTime.utc(2026, 1, 1),
    );

    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithRouter(container, txId));
    await tester.tap(find.text('open detail'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('deleteTransaction')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('open detail'), findsNothing); // still on the detail screen
    final Transaction row =
        await (db.select(db.transactions)..where((tbl) => tbl.id.equals(txId))).getSingle();
    expect(row.deletedAt, isNull);
  });

  // ---------------------------------------------------------------------
  // Checkpoint 4: visual hierarchy, category icon, and accessibility.
  // ---------------------------------------------------------------------

  testWidgets('expense detail shows the category icon and expense-type semantics', (tester) async {
    final (AppDatabase db, String profileId, String accountId) = await seededDb();
    final TransactionRepository txRepo = TransactionRepository(db, AccountRepository(db));
    final String txId = await txRepo.recordExpense(
      profileId: profileId,
      accountId: accountId,
      amount: Money.fromMinorUnits(1200, 'JPY'),
      categoryId: 'sys-dining',
      note: 'Lunch',
      occurredAtUtc: DateTime.utc(2026, 3, 15, 8, 0),
    );

    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithRouter(container, txId));
    await tester.tap(find.text('open detail'));
    await tester.pumpAndSettle();

    // sys-dining's seeded icon ('restaurant') is represented via
    // TransactionIconBadge/categoryIconFor.
    expect(find.byIcon(Icons.restaurant), findsOneWidget);
    expect(find.text('-¥1,200'), findsOneWidget);
    expect(hasSemanticsLabel(tester, 'Expense'), isTrue);
  });

  testWidgets(
      'income detail shows a "+" amount using colorScheme.primary (not a hardcoded color), '
      'the category, and income-type semantics', (tester) async {
    final (AppDatabase db, String profileId, String accountId) = await seededDb();
    final TransactionRepository txRepo = TransactionRepository(db, AccountRepository(db));
    final String txId = await txRepo.recordIncome(
      profileId: profileId,
      accountId: accountId,
      amount: Money.fromMinorUnits(500000, 'JPY'),
      categoryId: 'sys-salary',
      occurredAtUtc: DateTime.utc(2026, 3, 15, 8, 0),
    );

    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithRouter(container, txId));
    await tester.tap(find.text('open detail'));
    await tester.pumpAndSettle();

    expect(find.text('+¥500,000'), findsOneWidget);
    expect(find.byIcon(Icons.work), findsOneWidget); // sys-salary's seeded icon
    expect(find.text('Salary'), findsWidgets); // header + metadata row, see file-level note
    expect(hasSemanticsLabel(tester, 'Income'), isTrue);

    // Checkpoint 4: income's amount color must come from
    // `colorScheme.primary`, not a hardcoded `Colors.green` -- read the
    // *actual* theme colorScheme back out (rather than hardcoding an
    // expected color value in the test) so this stays correct even if
    // the app's theme changes.
    final Text amountText = tester.widget<Text>(find.byKey(const Key('transactionDetailAmount')));
    final ColorScheme colors =
        Theme.of(tester.element(find.byKey(const Key('transactionDetailAmount')))).colorScheme;
    expect(amountText.style?.color, colors.primary);
    expect(amountText.style?.color, isNot(equals(Colors.green)));
  });

  testWidgets(
      'transfer detail shows an unsigned amount, the correct From/To accounts, no Category '
      'row, and the transfer badge/semantics', (tester) async {
    final (AppDatabase db, String profileId, String accountId) = await seededDb();
    final AccountRepository accountRepo = AccountRepository(db);
    final String secondAccountId = await accountRepo.createAccount(
      profileId: profileId,
      name: 'Savings',
      type: 'cash',
      currencyCode: 'JPY',
    );
    final TransactionRepository txRepo = TransactionRepository(db, accountRepo);
    final String txId = await txRepo.recordTransfer(
      profileId: profileId,
      sourceAccountId: accountId,
      destinationAccountId: secondAccountId,
      amount: Money.fromMinorUnits(3000, 'JPY'),
      occurredAtUtc: DateTime.utc(2026, 3, 15, 8, 0),
    );

    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithRouter(container, txId));
    await tester.tap(find.text('open detail'));
    await tester.pumpAndSettle();

    expect(find.text('¥3,000'), findsOneWidget); // no '+'/'-' sign for a transfer
    expect(find.text('From'), findsOneWidget);
    expect(find.text('To'), findsOneWidget);
    expect(find.text('Wallet'), findsOneWidget); // From = tx.accountId (source)
    expect(find.text('Savings'), findsOneWidget); // To = tx.destinationAccountId
    expect(find.text('Category'), findsNothing); // a transfer never shows a Category row
    expect(find.byIcon(Icons.swap_horiz), findsOneWidget);
    expect(hasSemanticsLabel(tester, 'Transfer'), isTrue);
  });

  testWidgets(
      'an expense whose category has an unrecognized icon name falls back to the category '
      'fallback icon, not a crash', (tester) async {
    final (AppDatabase db, String profileId, String accountId) = await seededDb();
    final CategoryRepository categoryRepo = CategoryRepository(db);
    final TransactionRepository txRepo = TransactionRepository(db, AccountRepository(db));
    final String categoryId = await categoryRepo.createCategory(
      profileId: profileId,
      name: 'Mystery Category',
      type: 'expense',
      icon: 'some_future_icon_name_not_in_the_map',
    );
    final String txId = await txRepo.recordExpense(
      profileId: profileId,
      accountId: accountId,
      amount: Money.fromMinorUnits(300, 'JPY'),
      categoryId: categoryId,
      occurredAtUtc: DateTime.utc(2026, 3, 15, 8, 0),
    );

    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithRouter(container, txId));
    await tester.tap(find.text('open detail'));
    await tester.pumpAndSettle();

    // categoryIconFor's own safe fallback for an unrecognized (but
    // non-null) icon name.
    expect(find.byIcon(Icons.category), findsOneWidget);
  });

  testWidgets(
      'an expense with no category at all falls back to the plain expense icon, not the '
      'category fallback icon, and the metadata row still reads "None"', (tester) async {
    final (AppDatabase db, String profileId, String accountId) = await seededDb();
    final TransactionRepository txRepo = TransactionRepository(db, AccountRepository(db));
    final String txId = await txRepo.recordExpense(
      profileId: profileId,
      accountId: accountId,
      amount: Money.fromMinorUnits(400, 'JPY'),
      occurredAtUtc: DateTime.utc(2026, 3, 15, 8, 0),
    );

    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithRouter(container, txId));
    await tester.tap(find.text('open detail'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.remove), findsOneWidget); // TransactionIconBadge's plain fallback
    expect(find.byIcon(Icons.category), findsNothing); // NOT categoryIconFor's fallback
    expect(find.text('Category'), findsOneWidget);
    expect(find.text('None'), findsOneWidget); // existing fallback text, unchanged
  });

  testWidgets('accessibility: transaction type and amount both carry spoken semantic labels',
      (tester) async {
    final (AppDatabase db, String profileId, String accountId) = await seededDb();
    final TransactionRepository txRepo = TransactionRepository(db, AccountRepository(db));
    final String txId = await txRepo.recordExpense(
      profileId: profileId,
      accountId: accountId,
      amount: Money.fromMinorUnits(1200, 'JPY'),
      categoryId: 'sys-dining',
      occurredAtUtc: DateTime.utc(2026, 3, 15, 8, 0),
    );

    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithRouter(container, txId));
    await tester.tap(find.text('open detail'));
    await tester.pumpAndSettle();

    // Type is identifiable non-visually via a dedicated Semantics label
    // on the icon badge, independent of the icon's shape/color.
    expect(hasSemanticsLabel(tester, 'Expense'), isTrue);
    // The amount's spoken form says "minus", not just a '-' glyph, and
    // (via `excludeSemantics: true` on its wrapper) isn't also announced
    // as the raw visual text -- avoids duplicate/noisy semantics.
    expect(hasSemanticsLabel(tester, 'minus ¥1,200'), isTrue);
  });

  // ---------------------------------------------------------------------
  // CP6.9: Japanese End-to-End QA + Localization Hardening. Covers the
  // genuinely new/changed strings this checkpoint introduced on this
  // screen (title, tooltips, delete-confirm dialog, and the From/To/Note
  // detail-row labels), the full Japanese delete flow end to end, an
  // international money-format regression check under the Japanese
  // locale (a 3-decimal currency, since the existing English tests above
  // already cover JPY's 0-decimal case), and a narrow-width/large-text
  // sanity check -- deliberately NOT duplicating every English test
  // above in Japanese (per CP6.9 §16/§9's "aggregate gaps only"
  // instruction).
  // ---------------------------------------------------------------------

  testWidgets(
      'CP6.9 (A): a transfer detail screen renders its title, tooltips, and From/To labels in '
      'Japanese, and the Japanese delete-confirm dialog completes a real softDelete', (tester) async {
    final (AppDatabase db, String profileId, String accountId) = await seededDb();
    final AccountRepository accountRepo = AccountRepository(db);
    final String secondAccountId = await accountRepo.createAccount(
      profileId: profileId,
      name: 'Savings',
      type: 'cash',
      currencyCode: 'JPY',
    );
    final TransactionRepository txRepo = TransactionRepository(db, accountRepo);
    final String txId = await txRepo.recordTransfer(
      profileId: profileId,
      sourceAccountId: accountId,
      destinationAccountId: secondAccountId,
      amount: Money.fromMinorUnits(3000, 'JPY'),
      occurredAtUtc: DateTime.utc(2026, 3, 15, 8, 0),
    );

    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithRouter(container, txId, locale: const Locale('ja')));
    await tester.tap(find.text('open detail'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(find.text('取引'), findsOneWidget); // AppBar title (transactionDetailScreenTitle)
    expect(find.text('振替'), findsOneWidget); // header type label (transactionTypeTransfer)
    expect(find.text('振替元'), findsOneWidget); // transactionDetailFromLabel
    expect(find.text('振替先'), findsOneWidget); // transactionDetailToLabel
    expect(find.text('Wallet'), findsOneWidget); // account name -- user/seed content, never translated
    expect(find.text('Savings'), findsOneWidget);
    expect(find.text('日付'), findsOneWidget); // dateLabel (reused)
    expect(hasSemanticsLabel(tester, '振替'), isTrue); // transfer-type Semantics label

    // Tooltip text is a widget property, not rendered `Text` -- read it
    // directly off the IconButton rather than via `find.text`.
    expect(
      tester.widget<IconButton>(find.byKey(const Key('editTransaction'))).tooltip,
      '編集', // editTooltip
    );
    expect(
      tester.widget<IconButton>(find.byKey(const Key('deleteTransaction'))).tooltip,
      '削除', // deleteTooltip
    );

    await tester.tap(find.byKey(const Key('deleteTransaction')));
    await tester.pumpAndSettle();
    expect(find.text('この取引を削除しますか？'), findsOneWidget); // deleteTransactionConfirmTitle
    expect(
      find.text('残高・予算・合計のいずれにも反映されなくなります。'),
      findsOneWidget,
    ); // deleteTransactionConfirmMessage

    await tester.tap(find.byKey(const Key('confirmDeleteTransaction')));
    await tester.pumpAndSettle();
    // Same extra settle cycle as the English delete test above -- see
    // that test's comment for why one `pumpAndSettle()` isn't always
    // enough to drain the softDelete/context.pop() overlap.
    await tester.pumpAndSettle();

    expect(find.text('open detail'), findsOneWidget); // popped back
    final Transaction row =
        await (db.select(db.transactions)..where((tbl) => tbl.id.equals(txId))).getSingle();
    expect(row.deletedAt, isNotNull);
  });

  testWidgets(
      'CP6.9 (B): a 3-decimal-currency (KWD) expense renders its full unclipped precision under '
      'the Japanese locale, with no storage/minor-units corruption', (tester) async {
    final (AppDatabase db, String profileId, String _) = await seededDb();
    final AccountRepository accountRepo = AccountRepository(db);
    final String kwdAccountId = await accountRepo.createAccount(
      profileId: profileId,
      name: 'Kuwait Wallet',
      type: 'cash',
      currencyCode: 'KWD',
    );
    final TransactionRepository txRepo = TransactionRepository(db, accountRepo);
    // 1250.375 KWD -- exercises all 3 of KWD's minor-unit digits.
    final Money kwdAmount = Money.fromMinorUnits(1250375, 'KWD');
    final String txId = await txRepo.recordExpense(
      profileId: profileId,
      accountId: kwdAccountId,
      amount: kwdAmount,
      occurredAtUtc: DateTime.utc(2026, 3, 15, 8, 0),
    );

    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithRouter(container, txId, locale: const Locale('ja')));
    await tester.tap(find.text('open detail'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Built from the same production `MoneyFormatter` the screen itself
    // uses -- this test verifies the screen renders that authoritative
    // output unmodified under the Japanese locale, not a hand-transcribed
    // re-implementation of currency formatting rules.
    const MoneyFormatter formatter = MoneyFormatter();
    final String formattedAmount = formatter.format(kwdAmount);
    expect(find.text('-$formattedAmount'), findsOneWidget); // '-' expense prefix, no digits dropped
    expect(hasSemanticsLabel(tester, 'マイナス$formattedAmount'), isTrue); // spokenMinusAmount
    expect(find.text('なし'), findsOneWidget); // noneOptionLabel -- no category on this transaction

    // Storage invariant: the persisted minor-units value is untouched by
    // any of the above presentation-layer localization.
    final Transaction row =
        await (db.select(db.transactions)..where((tbl) => tbl.id.equals(txId))).getSingle();
    expect(row.amountMinorUnits, 1250375);
    expect(row.currencyCode, 'KWD');
  });

  testWidgets(
      'CP6.9 (C): the transaction detail screen renders without overflow under the Japanese '
      'locale at a narrow 320px width and an extreme 2.0x text scale', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final (AppDatabase db, String profileId, String accountId) = await seededDb();
    final TransactionRepository txRepo = TransactionRepository(db, AccountRepository(db));
    final String txId = await txRepo.recordIncome(
      profileId: profileId,
      accountId: accountId,
      amount: Money.fromMinorUnits(500000, 'JPY'),
      categoryId: 'sys-salary',
      note: 'ボーナス',
      occurredAtUtc: DateTime.utc(2026, 3, 15, 8, 0),
    );

    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithRouter(container, txId, locale: const Locale('ja')));
    await tester.tap(find.text('open detail'));
    await tester.pumpAndSettle();

    // The money value must never be the thing that yields under text
    // scaling/narrow width -- no overflow exception, and the amount is
    // still findable with every digit intact.
    expect(tester.takeException(), isNull);
    expect(find.text('+¥500,000'), findsOneWidget);
    expect(find.byKey(const Key('transactionDetailAmount')), findsOneWidget);
    expect(find.text('ボーナス'), findsOneWidget); // user-entered note, never translated
  });
}
