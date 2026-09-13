import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/providers.dart';
import 'package:ai_financial_coach/core/database/repositories/account_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/category_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/transaction_repository.dart';
import 'package:ai_financial_coach/core/money/money.dart';
import 'package:ai_financial_coach/core/routing/app_routes.dart';
import 'package:ai_financial_coach/l10n/generated/app_localizations.dart';
import 'package:ai_financial_coach/features/transactions/presentation/edit_transaction_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// NOTE: exercises generated Drift code -- see CLAUDE_FIRST_CODING_PROMPT.md.
//
// CP6.9 (Localization Phase 1, Japanese End-to-End QA + Localization
// Hardening) adds this file: `EditTransactionScreen` previously had zero
// dedicated tests, and the CP6.9 app-wide inventory found it entirely
// unlocalized (three `const Text('Edit transaction')` AppBar titles, a raw
// exception passthrough, and the shared "no longer available" message).
// This is a thin id-to-row resolver on top of `AddTransactionScreen` (see
// that class's own doc comment) -- these tests cover only what belongs to
// THIS screen: its loading/error/unavailable states and its title, plus
// one real navigate-to-the-actual-edit-form smoke test under the Japanese
// locale. `AddTransactionScreen`'s own form behavior already has its own
// dedicated test file and is not re-tested here.
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

  /// A minimal real `GoRouter`: an entry stub with a button that pushes to
  /// the real edit route, plus the real edit route itself -- same pattern
  /// `transaction_detail_screen_test.dart`'s `appWithRouter` uses, trimmed
  /// to only what `EditTransactionScreen` itself needs.
  Widget appWithRouter(
    ProviderContainer container,
    String transactionId, {
    Locale locale = const Locale('en'),
  }) {
    final GoRouter router = GoRouter(
      initialLocation: '/start',
      routes: <RouteBase>[
        GoRoute(
          path: '/start',
          builder: (context, state) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => context.push(AppRoutes.editTransaction(transactionId)),
                child: const Text('open edit'),
              ),
            ),
          ),
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

  testWidgets('English: a soft-deleted transaction shows the unavailable state under the '
      'generic "Edit transaction" title', (tester) async {
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
    await tester.tap(find.text('open edit'));
    await tester.pumpAndSettle();

    expect(find.text('Edit transaction'), findsOneWidget); // editTransactionGenericTitle
    expect(
      find.text('This transaction is no longer available -- it may have been deleted elsewhere.'),
      findsOneWidget,
    );
  });

  testWidgets(
      'Japanese: a nonexistent transaction id shows the unavailable state under the Japanese '
      'generic edit title', (tester) async {
    final (AppDatabase db, String _, String _) = await seededDb();
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithRouter(container, 'does-not-exist', locale: const Locale('ja')));
    await tester.tap(find.text('open edit'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(find.text('取引を編集'), findsOneWidget); // editTransactionGenericTitle
    expect(
      find.text('この取引は利用できません。他の場所で削除された可能性があります。'),
      findsOneWidget,
    ); // transactionNoLongerAvailable
  });

  testWidgets(
      'Japanese: an existing expense navigates through to the real AddTransactionScreen edit '
      'form, prefilled with the existing values', (tester) async {
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

    await tester.pumpWidget(appWithRouter(container, txId, locale: const Locale('ja')));
    await tester.tap(find.text('open edit'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // `EditTransactionScreen` itself renders nothing further once it hands
    // off to `AddTransactionScreen` -- this confirms the handoff actually
    // happened (real edit form, real prefilled values), not a re-test of
    // `AddTransactionScreen`'s own form behavior.
    expect(find.text('支出を編集'), findsOneWidget); // editExpenseTitle
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField).first).controller!.text,
      '1200',
    );
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField).last).initialValue,
      'Lunch',
    );
  });
}
