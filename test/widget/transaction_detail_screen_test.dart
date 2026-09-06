import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/providers.dart';
import 'package:ai_financial_coach/core/database/repositories/account_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/category_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/transaction_repository.dart';
import 'package:ai_financial_coach/core/money/money.dart';
import 'package:ai_financial_coach/core/routing/app_routes.dart';
import 'package:ai_financial_coach/features/transactions/presentation/edit_transaction_screen.dart';
import 'package:ai_financial_coach/features/transactions/presentation/transaction_detail_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// NOTE: exercises generated Drift code -- see CLAUDE_FIRST_CODING_PROMPT.md.
//
// Beta 1 Transaction UX (`docs/14_DECISION_LOG.md` ADR-025), Phase A.
// Uses a real (minimal) `GoRouter` ancestor -- same pattern as
// `test/widget/home_screen_test.dart`'s `appWithRouter` -- because
// `TransactionDetailScreen`'s edit button and delete confirmation both
// navigate via `context.push`/`context.pop`, which throw without a
// `GoRouter` in the tree (see `test/widget/goal_detail_screen_test.dart`'s
// note on why ITS delete flow is deliberately NOT exercised the same way
// there). Real `EditTransactionScreen` is registered at the real edit
// route so the edit button's navigation can be verified end to end.

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
  Widget appWithRouter(ProviderContainer container, String transactionId) {
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
      child: MaterialApp.router(routerConfig: router),
    );
  }

  Future<void> disposeInOrder(WidgetTester tester, ProviderContainer container, AppDatabase db) async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pumpAndSettle();
    await db.close();
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
    expect(find.text('Dining Out'), findsOneWidget);
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

    expect(find.text('This transaction is no longer available.'), findsOneWidget);
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

    expect(find.text('This transaction is no longer available.'), findsOneWidget);
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
}
