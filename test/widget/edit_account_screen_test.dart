import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/providers.dart';
import 'package:ai_financial_coach/core/database/repositories/account_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/transaction_repository.dart';
import 'package:ai_financial_coach/core/money/money.dart';
import 'package:ai_financial_coach/core/routing/app_routes.dart';
import 'package:ai_financial_coach/features/accounts/presentation/account_detail_screen.dart';
import 'package:ai_financial_coach/features/accounts/presentation/edit_account_screen.dart';
import 'package:ai_financial_coach/l10n/generated/app_localizations.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// NOTE: exercises generated Drift code -- see CLAUDE_FIRST_CODING_PROMPT.md.
//
// V1 Accounts Detail + Edit Checkpoint. `EditAccountScreen` is its own
// small screen (unlike `EditTransactionScreen`, which hands off entirely
// to `AddTransactionScreen` -- see its own doc comment for why), so this
// file exercises its actual form behavior directly rather than only its
// id-to-row resolution. Same real-`GoRouter` requirement as
// `account_detail_screen_test.dart` -- both `context.push` (from
// `AccountDetailScreen`) and `context.pop` (this screen's own save) need
// a `GoRouter` ancestor.

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

  /// The real Detail -> Edit chain, plus a "start" stub that pushes
  /// straight to Detail -- close enough to the real
  /// Accounts -> Detail -> Edit flow (`AccountsScreen` itself is
  /// deliberately not included; that's `accounts_screen_test.dart`'s
  /// job) to exercise "Edit save returns to a refreshed Detail" for
  /// real, not against a stub.
  Widget appWithRouter(
    ProviderContainer container,
    String accountId, {
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
                onPressed: () => context.push(AppRoutes.accountDetail(accountId)),
                child: const Text('open detail'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.accountDetailPath,
          builder: (context, state) =>
              AccountDetailScreen(accountId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: AppRoutes.editAccountPath,
          builder: (context, state) => EditAccountScreen(accountId: state.pathParameters['id']!),
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

  /// Detail -> tap Edit -- lands on the real `EditAccountScreen`.
  Future<void> openEdit(WidgetTester tester) async {
    await tester.tap(find.text('open detail'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('editAccount')));
    await tester.pumpAndSettle();
  }

  testWidgets('loads the existing name and type into the form, and shows currency read-only',
      (tester) async {
    final (AppDatabase db, String profileId) = await seededDb();
    final AccountRepository accountRepo = AccountRepository(db);
    final String accountId = await accountRepo.createAccount(
      profileId: profileId,
      name: 'Main Wallet',
      type: 'bank',
      currencyCode: 'JPY',
    );
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithRouter(container, accountId));
    await openEdit(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Edit account'), findsOneWidget);
    final Finder nameField = find.byType(TextFormField).first;
    final Finder currencyField = find.byType(TextFormField).last;
    expect(tester.widget<TextFormField>(nameField).controller!.text, 'Main Wallet');
    // Type is a dropdown, not a text field -- its current selection is
    // asserted via the visible label rather than a controller.
    expect(find.text('bank'), findsOneWidget);
    // Currency: disabled `TextFormField`, pre-filled from the account,
    // never a picker.
    final TextFormField currency = tester.widget<TextFormField>(currencyField);
    expect(currency.initialValue, 'JPY');
    expect(currency.enabled, isFalse);
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget); // type only
    expect(
      find.text("Currency can't be changed after an account is created."),
      findsOneWidget,
    ); // accountCurrencyLockedMessage
  });

  testWidgets(
    'a valid edit persists via updateAccount and returning to Detail reflects it immediately',
    (tester) async {
      final (AppDatabase db, String profileId) = await seededDb();
      final AccountRepository accountRepo = AccountRepository(db);
      final String accountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Main Wallet',
        type: 'cash',
        currencyCode: 'JPY',
      );
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container, accountId));
      await openEdit(tester);

      await tester.enterText(find.byType(TextFormField).first, 'Renamed Wallet');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Back on Detail (not still on Edit) -- `Navigator.pop()` fired,
      // and Detail is watching `accountByIdProvider` live so it reflects
      // the edit without any separate reload step.
      expect(find.text('Edit account'), findsNothing);
      expect(find.text('Renamed Wallet'), findsWidgets); // app bar title + identity row
      expect(find.text('cash · JPY'), findsOneWidget); // type untouched by this edit

      final AccountRow row = await accountRepo.requireById(accountId);
      expect(row.name, 'Renamed Wallet');
      expect(row.type, 'cash');
    },
  );

  testWidgets('an empty name fails validation and does not save or navigate away',
      (tester) async {
    final (AppDatabase db, String profileId) = await seededDb();
    final AccountRepository accountRepo = AccountRepository(db);
    final String accountId = await accountRepo.createAccount(
      profileId: profileId,
      name: 'Main Wallet',
      type: 'cash',
      currencyCode: 'JPY',
    );
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithRouter(container, accountId));
    await openEdit(tester);

    await tester.enterText(find.byType(TextFormField).first, '');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Still on Edit -- the save never went through.
    expect(find.text('Edit account'), findsOneWidget);
    expect(find.text('Enter a name.'), findsOneWidget); // enterAccountNameMessage

    final AccountRow row = await accountRepo.requireById(accountId);
    expect(row.name, 'Main Wallet'); // untouched
  });

  testWidgets(
    'pressing back without saving leaves the account completely untouched, including a typed '
    'but unsaved edit',
    (tester) async {
      final (AppDatabase db, String profileId) = await seededDb();
      final AccountRepository accountRepo = AccountRepository(db);
      final String accountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Main Wallet',
        type: 'cash',
        currencyCode: 'JPY',
      );
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container, accountId));
      await openEdit(tester);

      await tester.enterText(find.byType(TextFormField).first, 'Never Saved');

      // Android-style back -- the AppBar's implicit back button, not
      // the Save action.
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Edit account'), findsNothing);
      // Back on Detail, still showing the ORIGINAL name -- the typed
      // edit was never persisted.
      expect(find.text('Main Wallet'), findsWidgets);
      expect(find.text('Never Saved'), findsNothing);

      final AccountRow row = await accountRepo.requireById(accountId);
      expect(row.name, 'Main Wallet');
    },
  );

  testWidgets(
    "editing name/type never rewrites the account's currency, opening balance, or calculated "
    'balance, even with existing transaction history',
    (tester) async {
      final (AppDatabase db, String profileId) = await seededDb();
      final AccountRepository accountRepo = AccountRepository(db);
      final TransactionRepository txRepo = TransactionRepository(db, accountRepo);
      final String accountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Main Wallet',
        type: 'cash',
        currencyCode: 'JPY',
        openingBalance: Money.fromMinorUnits(50000, 'JPY'),
      );
      await txRepo.recordExpense(
        profileId: profileId,
        accountId: accountId,
        amount: Money.fromMinorUnits(2000, 'JPY'),
        occurredAtUtc: DateTime.utc(2026, 1, 1),
      );
      final AccountRow before = await accountRepo.requireById(accountId);

      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container, accountId));
      await openEdit(tester);

      await tester.enterText(find.byType(TextFormField).first, 'Renamed Wallet');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // The balance shown back on Detail is exactly what it was before
      // this edit -- ¥50,000 opening minus the ¥2,000 expense -- not
      // reset, not recomputed under a different currency.
      expect(find.text('¥48,000'), findsOneWidget);

      final AccountRow after = await accountRepo.requireById(accountId);
      expect(after.name, 'Renamed Wallet'); // the only thing that changed
      expect(after.currencyCode, before.currencyCode);
      expect(after.openingBalanceMinorUnits, before.openingBalanceMinorUnits);
      expect(after.id, before.id);
      expect(after.profileId, before.profileId);
      expect(after.createdAt, before.createdAt);
    },
  );

  group('Japanese localization', () {
    testWidgets('renders a fully localized form and persists an edit correctly', (tester) async {
      final (AppDatabase db, String profileId) = await seededDb();
      final AccountRepository accountRepo = AccountRepository(db);
      final String accountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Main Wallet',
        type: 'cash',
        currencyCode: 'JPY',
      );
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container, accountId, locale: const Locale('ja')));
      await openEdit(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('口座を編集'), findsOneWidget); // editAccountTitle
      expect(
        find.text('口座を作成した後は通貨を変更できません。'),
        findsOneWidget,
      ); // accountCurrencyLockedMessage

      await tester.tap(find.widgetWithText(FilledButton, '保存')); // save
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('口座を編集'), findsNothing); // popped back to Detail
      final AccountRow row = await accountRepo.requireById(accountId);
      expect(row.name, 'Main Wallet'); // unchanged -- no edit was made, just saved as-is
    });
  });
}
