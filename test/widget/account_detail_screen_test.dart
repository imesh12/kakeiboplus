import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/providers.dart';
import 'package:ai_financial_coach/core/database/repositories/account_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/deposit_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/credit_facility_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/financial_institution_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/recurring_rule_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/transaction_repository.dart';
import 'package:ai_financial_coach/core/finance/balance_class.dart';
import 'package:ai_financial_coach/core/finance/deposit_interest_method.dart';
import 'package:ai_financial_coach/core/finance/deposit_term_unit.dart';
import 'package:ai_financial_coach/core/finance/deposit_type.dart';
import 'package:ai_financial_coach/core/finance/financial_account_subtype.dart';
import 'package:ai_financial_coach/core/money/money.dart';
import 'package:ai_financial_coach/features/recurring/domain/recurrence_frequency.dart';
import 'package:ai_financial_coach/features/recurring/domain/recurring_rule_kind.dart';
import 'package:ai_financial_coach/core/routing/app_routes.dart';
import 'package:ai_financial_coach/features/accounts/presentation/account_detail_screen.dart';
import 'package:ai_financial_coach/features/accounts/presentation/edit_account_screen.dart';
import 'package:ai_financial_coach/l10n/generated/app_localizations.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../support/rtl_harness.dart';

// NOTE: exercises generated Drift code -- see CLAUDE_FIRST_CODING_PROMPT.md.
//
// V1 Accounts Detail + Edit Checkpoint. Mirrors
// `transaction_detail_screen_test.dart`'s own real-`GoRouter` harness --
// `AccountDetailScreen`'s Edit action calls `context.push`, which throws
// without a `GoRouter` ancestor, so a plain `MaterialApp(home: ...)`
// harness (as `goal_detail_screen_test.dart` uses, which has no
// cross-screen navigation to exercise) isn't enough here.

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

  /// A minimal real `GoRouter`: an "activity"-shaped stub with a button
  /// that pushes to the real detail route, the real detail route, and
  /// the real edit route -- enough for `AccountDetailScreen`'s own
  /// `context.push` (Edit action) to have somewhere to go, without
  /// pulling in the real `AccountsScreen` (which isn't what these tests
  /// are about -- that's `accounts_screen_test.dart`'s job).
  Widget appWithRouter(
    ProviderContainer container,
    String accountId, {
    bool rtl = false,
    Locale locale = const Locale('en'),
  }) {
    final GoRouter router = GoRouter(
      initialLocation: '/accounts-stub',
      routes: <RouteBase>[
        GoRoute(
          path: '/accounts-stub',
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
        builder: rtl ? rtlAppBuilder : null,
      ),
    );
  }

  Future<void> disposeInOrder(WidgetTester tester, ProviderContainer container, AppDatabase db) async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pumpAndSettle();
    await db.close();
  }

  Future<void> openDetail(WidgetTester tester) async {
    await tester.tap(find.text('open detail'));
    await tester.pumpAndSettle();
  }

  /// Scopes a balance-string finder to the current/calculated balance
  /// widget specifically (`Key('accountCurrentBalance')` on the hero
  /// `AppMoneyText` in `account_detail_screen.dart`) rather than a bare
  /// `find.text(...)`, which -- when an account has no transactions yet
  /// -- legitimately matches the opening-balance metadata row too (same
  /// formatted string, two different widgets: the hero balance vs. the
  /// metadata row's value). That's two pieces of correct UI that happen
  /// to show the same number when balance == opening balance, not a
  /// rendering bug -- this finder lets tests assert on the hero
  /// specifically instead of a false global-uniqueness assumption.
  Finder currentBalanceText(String formatted) => find.descendant(
        of: find.byKey(const Key('accountCurrentBalance')),
        matching: find.text(formatted),
      );

  /// Checkpoint L: `Key('accountBalanceLabel')` is attached directly to
  /// the label `Text` widget itself (see `account_detail_screen.dart`),
  /// not to a wrapping container the way `Key('accountInstitutionRow')`
  /// wraps a `_DetailRow`. `find.descendant(of: find.byKey(...), ...)`
  /// searches strictly *below* the keyed widget in the tree -- for a
  /// leaf `Text` widget that is never where its own `data` lives, so
  /// that pattern would always find zero matches here regardless of
  /// what the label actually says. This finder instead matches the
  /// keyed `Text` widget itself by predicate: still exactly as
  /// structural/specific as `currentBalanceText` above, just correct
  /// for a key that sits on a leaf rather than a composite.
  Finder balanceLabelText(String expected) => find.byWidgetPredicate(
        (Widget widget) =>
            widget is Text &&
            widget.key == const Key('accountBalanceLabel') &&
            widget.data == expected,
      );

  testWidgets(
    'shows account identity (name, type, currency) and the calculated balance',
    (tester) async {
      final (AppDatabase db, String profileId) = await seededDb();
      final AccountRepository accountRepo = AccountRepository(db);
      final String accountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Main Wallet',
        type: 'bank',
        currencyCode: 'JPY',
        openingBalance: Money.fromMinorUnits(50000, 'JPY'), // ¥50,000
      );
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container, accountId));
      await openDetail(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Main Wallet'), findsWidgets); // app bar title + identity row
      expect(find.text('bank · JPY'), findsOneWidget);
      // No transactions yet, so the calculated balance equals the stored
      // opening balance -- both legitimately render the same formatted
      // string (the hero balance and the opening-balance metadata row).
      // Assert the hero specifically, then confirm the string appears in
      // exactly the two places that's expected to happen, rather than
      // asserting (falsely) that the formatted amount occurs only once.
      expect(currentBalanceText('¥50,000'), findsOneWidget);
      expect(find.text('¥50,000'), findsNWidgets(2)); // hero balance + opening-balance metadata
    },
  );

  testWidgets(
    'the calculated balance reflects recorded transactions, not just the stored opening balance',
    (tester) async {
      final (AppDatabase db, String profileId) = await seededDb();
      final AccountRepository accountRepo = AccountRepository(db);
      final TransactionRepository txRepo = TransactionRepository(db, accountRepo);
      final String accountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Wallet',
        type: 'cash',
        currencyCode: 'USD',
        openingBalance: Money.fromMinorUnits(10000, 'USD'), // $100.00
      );
      await txRepo.recordExpense(
        profileId: profileId,
        accountId: accountId,
        amount: Money.fromMinorUnits(2500, 'USD'), // $25.00
        occurredAtUtc: DateTime.utc(2026, 1, 1),
      );
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container, accountId));
      await openDetail(tester);

      expect(tester.takeException(), isNull);
      // $100.00 opening - $25.00 expense = $75.00, computed by
      // `FinanceEngine`/`accountBalanceProvider` -- this screen never
      // does its own arithmetic. Scoped to the hero balance specifically
      // (not a bare `find.text`) so this keeps proving the *current*
      // balance is what renders there, not merely that the string
      // exists somewhere on screen.
      expect(currentBalanceText('\$75.00'), findsOneWidget);
      // The stored opening balance keeps rendering, unchanged, in its
      // own metadata row -- proving the two concepts (calculated balance
      // vs. stored opening balance) are displayed separately rather than
      // one silently overwriting the other. Unlike the balance above,
      // this value never coincides with the hero balance in this test,
      // so a bare `find.text` is unambiguous here.
      expect(find.text('\$100.00'), findsOneWidget);
    },
  );

  testWidgets('tapping edit navigates to the edit screen, prefilled with the existing values',
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
    await openDetail(tester);

    await tester.tap(find.byKey(const Key('editAccount')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Edit account'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField).first).controller!.text,
      'Main Wallet',
    );
    // Currency renders read-only, never as a picker -- see
    // `edit_account_screen_test.dart` for dedicated coverage of that
    // guarantee; this test only confirms Edit was reached with the
    // right account's data. It's a disabled `TextFormField`, not a
    // plain `Text`, so its content is asserted via `initialValue`
    // rather than `find.text` (which can't see inside an
    // `EditableText`).
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField).last).initialValue,
      'JPY',
    );
  });

  testWidgets(
    'an account id that no longer exists shows a graceful unavailable state, not a crash or a '
    'stale/empty screen',
    (tester) async {
      final (AppDatabase db, String _) = await seededDb();
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container, 'does-not-exist'));
      await openDetail(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('This account is no longer available.'), findsOneWidget);
      // No Edit action for an account that isn't there to edit.
      expect(find.byKey(const Key('editAccount')), findsNothing);
    },
  );

  testWidgets(
    'Account Lifecycle Checkpoint: a closed (soft-deleted) account resolves as CLOSED/'
    'reactivatable, NOT the "no longer available" state -- this supersedes the old '
    'pre-checkpoint assumption that a soft-deleted account was indistinguishable from a '
    'genuinely missing one; see the sibling test above (an id that never existed at all), which '
    'is unchanged and still shows the true unavailable state',
    (tester) async {
      final (AppDatabase db, String profileId) = await seededDb();
      final AccountRepository accountRepo = AccountRepository(db);
      final String accountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Closed Account',
        type: 'cash',
        currencyCode: 'USD',
      );
      await accountRepo.softDelete(accountId);
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container, accountId));
      await openDetail(tester);

      expect(tester.takeException(), isNull);
      // NOT the "gone" state -- a closed account is fully resolvable: its
      // name and closed badge render, and a Reactivate action is offered.
      expect(find.text('This account is no longer available.'), findsNothing);
      // `find.text('Closed Account')` now legitimately matches twice --
      // once in the AppBar title (driven by `accountByIdProvider` via
      // `headerAccount`) and once in the body's own identity header
      // (driven by the separate `data:` account passed to
      // `_AccountDetailBody`) -- so a plain `findsOneWidget` on the name
      // alone is no longer a valid assertion. What this test actually
      // needs to prove is that the AppBar header -- the thing that also
      // drives `isClosed`, the Edit-icon visibility, and the Reactivate
      // action above -- resolved to the account's real name rather than
      // falling back to `accountFallbackTitle` (which is what a
      // genuinely unresolved id would show instead). Anchoring on the
      // `AppBar` ancestor is what makes this assertion mean that,
      // structurally, rather than merely "the name is on screen
      // somewhere."
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('Closed Account')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('accountClosedBadge')), findsOneWidget);
      expect(find.byKey(const Key('closeOrReactivateAccount')), findsOneWidget);
      // No Edit action for a closed account -- must Reactivate first.
      expect(find.byKey(const Key('editAccount')), findsNothing);
    },
  );

  testWidgets(
    'account-scoped recent activity includes only expenses/income/transfers involving this '
    'account, signs a transfer by direction, and excludes soft-deleted transactions',
    (tester) async {
      final (AppDatabase db, String profileId) = await seededDb();
      final AccountRepository accountRepo = AccountRepository(db);
      final TransactionRepository txRepo = TransactionRepository(db, accountRepo);
      final String wallet = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Wallet',
        type: 'cash',
        currencyCode: 'USD',
      );
      final String bank = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Bank',
        type: 'bank',
        currencyCode: 'USD',
      );
      final String other = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Unrelated',
        type: 'cash',
        currencyCode: 'USD',
      );

      // Involves `wallet` directly -- must appear.
      await txRepo.recordExpense(
        profileId: profileId,
        accountId: wallet,
        amount: Money.fromMinorUnits(500, 'USD'),
        occurredAtUtc: DateTime.utc(2026, 1, 3),
      );
      // A transfer FROM wallet TO bank -- must appear for both accounts,
      // signed as outgoing ('-') on wallet's own activity.
      await txRepo.recordTransfer(
        profileId: profileId,
        sourceAccountId: wallet,
        destinationAccountId: bank,
        amount: Money.fromMinorUnits(1000, 'USD'),
        occurredAtUtc: DateTime.utc(2026, 1, 2),
      );
      // Involves only `other` -- must NOT appear on wallet's activity.
      final String unrelatedExpenseId = await txRepo.recordExpense(
        profileId: profileId,
        accountId: other,
        amount: Money.fromMinorUnits(999, 'USD'),
        occurredAtUtc: DateTime.utc(2026, 1, 1),
      );
      // Involves `wallet` but is soft-deleted -- must NOT appear.
      final String deletedExpenseId = await txRepo.recordExpense(
        profileId: profileId,
        accountId: wallet,
        amount: Money.fromMinorUnits(4242, 'USD'),
        occurredAtUtc: DateTime.utc(2026, 1, 4),
      );
      await txRepo.softDelete(deletedExpenseId);

      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container, wallet));
      await openDetail(tester);

      expect(tester.takeException(), isNull);
      // The direct expense and the transfer both show, signed correctly.
      expect(find.text('-\$5.00'), findsOneWidget); // the direct expense
      expect(find.text('-\$10.00'), findsOneWidget); // outgoing transfer, from wallet's own side
      // Neither the unrelated account's expense nor the soft-deleted one
      // ever renders, by amount (each is a distinct, otherwise-unused
      // figure so this can't coincidentally match the two above).
      expect(find.text('-\$9.99'), findsNothing);
      expect(find.text('-\$42.42'), findsNothing);
      expect(unrelatedExpenseId, isNotEmpty); // ids created only to be excluded, not asserted on
      expect(deletedExpenseId, isNotEmpty);
    },
  );

  testWidgets(
    'account-scoped recent activity signs the same transfer as incoming ("+") when viewed from '
    "the destination account's own detail screen",
    (tester) async {
      final (AppDatabase db, String profileId) = await seededDb();
      final AccountRepository accountRepo = AccountRepository(db);
      final TransactionRepository txRepo = TransactionRepository(db, accountRepo);
      final String wallet = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Wallet',
        type: 'cash',
        currencyCode: 'USD',
      );
      final String bank = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Bank',
        type: 'bank',
        currencyCode: 'USD',
      );
      await txRepo.recordTransfer(
        profileId: profileId,
        sourceAccountId: wallet,
        destinationAccountId: bank,
        amount: Money.fromMinorUnits(1000, 'USD'),
        occurredAtUtc: DateTime.utc(2026, 1, 2),
      );

      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container, bank));
      await openDetail(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('+\$10.00'), findsOneWidget);
    },
  );

  testWidgets('shows the localized empty state when an account has no recent activity',
      (tester) async {
    final (AppDatabase db, String profileId) = await seededDb();
    final AccountRepository accountRepo = AccountRepository(db);
    final String accountId = await accountRepo.createAccount(
      profileId: profileId,
      name: 'Wallet',
      type: 'cash',
      currencyCode: 'USD',
    );
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithRouter(container, accountId));
    await openDetail(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('No recent activity for this account.'), findsOneWidget);
  });

  testWidgets(
    'renders correctly at 320px width and a 2.0x text scale with no clipped balance or thrown '
    'exception',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final (AppDatabase db, String profileId) = await seededDb();
      final AccountRepository accountRepo = AccountRepository(db);
      final String accountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'A rather long account name to stress narrow-width layout',
        type: 'bank',
        currencyCode: 'VND',
        openingBalance: Money.fromMinorUnits(999999999, 'VND'), // ₫999,999,999
      );
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container, accountId));
      await openDetail(tester);

      expect(tester.takeException(), isNull);
      expect(find.textContaining('999,999,999'), findsWidgets);
    },
  );

  testWidgets('renders correctly under RTL with no thrown exception', (tester) async {
    final (AppDatabase db, String profileId) = await seededDb();
    final AccountRepository accountRepo = AccountRepository(db);
    final String accountId = await accountRepo.createAccount(
      profileId: profileId,
      name: 'Wallet',
      type: 'cash',
      currencyCode: 'USD',
      openingBalance: Money.fromMinorUnits(5000, 'USD'),
    );
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithRouter(container, accountId, rtl: true));
    await openDetail(tester);

    expect(tester.takeException(), isNull);
    // No transactions recorded, so balance == opening balance -- both
    // legitimately render '\$50.00' (see `currentBalanceText` above).
    // This test's intent is "the current balance renders correctly under
    // RTL, no exception," so it scopes to the hero balance specifically
    // rather than asserting global string uniqueness.
    expect(currentBalanceText('\$50.00'), findsOneWidget);
  });

  // Checkpoint L: Account Detail becomes type-aware for balance wording
  // (driven purely by the persisted `BalanceClass`, never by name/
  // subtype text) and gains a read-only Institution row, shown only
  // when one is actually persisted. `Key('accountBalanceLabel')` scopes
  // the new label the same way `currentBalanceText` already scopes the
  // hero number, since "Balance" can legitimately also appear as plain
  // prose elsewhere on a future screen -- never asserted as a bare
  // `find.text` here.
  group('Checkpoint L -- type-aware balance label & institution', () {
    testWidgets('an ordinary asset account (bank) shows the "Balance" label', (tester) async {
      final (AppDatabase db, String profileId) = await seededDb();
      final AccountRepository accountRepo = AccountRepository(db);
      final String accountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Checking',
        type: 'bank',
        currencyCode: 'USD',
        openingBalance: Money.fromMinorUnits(5000, 'USD'),
      );
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container, accountId));
      await openDetail(tester);

      expect(tester.takeException(), isNull);
      expect(balanceLabelText('Balance'), findsOneWidget);
      expect(currentBalanceText('\$50.00'), findsOneWidget);
      // Never the liability wording for an asset.
      expect(find.text('Amount you currently owe'), findsNothing);
    });

    testWidgets(
        'a credit-card/liability account shows "Amount you currently owe", never the plain '
        'asset "Balance" label, and its non-negative amount-owed magnitude is unchanged',
        (tester) async {
      final (AppDatabase db, String profileId) = await seededDb();
      final AccountRepository accountRepo = AccountRepository(db);
      final String accountId = await accountRepo.createClassifiedAccount(
        profileId: profileId,
        name: 'Credit Card',
        type: 'creditCard',
        balanceClass: BalanceClass.liability,
        subtype: FinancialAccountSubtype.creditCard,
        currencyCode: 'USD',
        openingBalance: Money.fromMinorUnits(12000, 'USD'), // $120.00 owed
      );
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container, accountId));
      await openDetail(tester);

      expect(tester.takeException(), isNull);
      expect(balanceLabelText('Amount you currently owe'), findsOneWidget);
      expect(find.text('Balance'), findsNothing);
      // Still the plain non-negative magnitude -- no sign flip, no
      // "-\$120.00", exactly `FinanceEngine.accountBalance`'s existing
      // liability convention, only now with a clarifying label above it.
      expect(currentBalanceText('\$120.00'), findsOneWidget);
      // No deposit-only section leaks onto a credit-card account.
      expect(find.byKey(const Key('depositDetailsCard')), findsNothing);
    });

    testWidgets(
        'a deposit account still shows the plain asset "Balance" label -- its hero number is '
        'a ledger balance, not a specially labeled principal figure', (tester) async {
      final (AppDatabase db, String profileId) = await seededDb();
      final AccountRepository accountRepo = AccountRepository(db);
      final DepositRepository depositRepo = DepositRepository(db, accountRepo);
      final String accountId = await accountRepo.createClassifiedAccount(
        profileId: profileId,
        name: 'Fixed Deposit',
        type: 'deposit',
        balanceClass: BalanceClass.asset,
        subtype: FinancialAccountSubtype.deposit,
        currencyCode: 'JPY',
        openingBalance: Money.fromMinorUnits(100000, 'JPY'),
      );
      await depositRepo.createDetails(
        profileId: profileId,
        accountId: accountId,
        depositType: DepositType.fixed,
        termNumber: 12,
        termUnit: DepositTermUnit.months,
        startDateUtc: DateTime.utc(2026, 1, 1),
        interestRateBasisPoints: 250,
        interestMethod: DepositInterestMethod.simple,
      );
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container, accountId));
      await openDetail(tester);

      expect(tester.takeException(), isNull);
      expect(balanceLabelText('Balance'), findsOneWidget);
      expect(find.byKey(const Key('depositDetailsCard')), findsOneWidget);
    });

    testWidgets('a Savings account (its own persisted subtype since Checkpoint K) displays as '
        'Savings, shows the "Balance" label, and no deposit/liability field leaks onto it',
        (tester) async {
      final (AppDatabase db, String profileId) = await seededDb();
      final AccountRepository accountRepo = AccountRepository(db);
      final String accountId = await accountRepo.createClassifiedAccount(
        profileId: profileId,
        name: 'Nest egg',
        type: 'savings',
        balanceClass: BalanceClass.asset,
        subtype: FinancialAccountSubtype.savings,
        currencyCode: 'USD',
        openingBalance: Money.fromMinorUnits(5000, 'USD'),
      );
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container, accountId));
      await openDetail(tester);

      expect(tester.takeException(), isNull);
      // Displays as Savings, not Bank -- the exact identity this
      // checkpoint's brief requires be preserved.
      expect(find.text('Savings account · USD'), findsOneWidget);
      expect(balanceLabelText('Balance'), findsOneWidget);
      expect(find.byKey(const Key('depositDetailsCard')), findsNothing);

      final AccountRow row = await accountRepo.requireById(accountId);
      expect(row.subtypeValue, FinancialAccountSubtype.savings);
    });

    testWidgets(
        'opening a Savings account in Edit and saving it unchanged preserves its persisted '
        'savings subtype -- it is never silently converted to Bank', (tester) async {
      final (AppDatabase db, String profileId) = await seededDb();
      final AccountRepository accountRepo = AccountRepository(db);
      final String accountId = await accountRepo.createClassifiedAccount(
        profileId: profileId,
        name: 'Nest egg',
        type: 'savings',
        balanceClass: BalanceClass.asset,
        subtype: FinancialAccountSubtype.savings,
        currencyCode: 'USD',
      );
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container, accountId));
      await openDetail(tester);

      await tester.tap(find.byKey(const Key('editAccount')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final AccountRow row = await accountRepo.requireById(accountId);
      expect(row.subtypeValue, FinancialAccountSubtype.savings);
      expect(row.balanceClassValue, BalanceClass.asset);
      expect(row.type, 'savings');
    });

    testWidgets('a wallet account shows the "Balance" label and no deposit/liability fields',
        (tester) async {
      final (AppDatabase db, String profileId) = await seededDb();
      final AccountRepository accountRepo = AccountRepository(db);
      final String accountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'E-money',
        type: 'wallet',
        currencyCode: 'USD',
        openingBalance: Money.fromMinorUnits(3000, 'USD'),
      );
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container, accountId));
      await openDetail(tester);

      expect(tester.takeException(), isNull);
      expect(balanceLabelText('Balance'), findsOneWidget);
      expect(find.byKey(const Key('depositDetailsCard')), findsNothing);
    });

    testWidgets('a cash account shows the "Balance" label and no deposit/liability fields',
        (tester) async {
      final (AppDatabase db, String profileId) = await seededDb();
      final AccountRepository accountRepo = AccountRepository(db);
      final String accountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Wallet cash',
        type: 'cash',
        currencyCode: 'USD',
        openingBalance: Money.fromMinorUnits(1000, 'USD'),
      );
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container, accountId));
      await openDetail(tester);

      expect(tester.takeException(), isNull);
      expect(balanceLabelText('Balance'), findsOneWidget);
      expect(find.byKey(const Key('depositDetailsCard')), findsNothing);
      // No institution row -- this account never had one.
      expect(find.byKey(const Key('accountInstitutionRow')), findsNothing);
    });

    testWidgets('shows the persisted institution name when the account actually has one',
        (tester) async {
      final (AppDatabase db, String profileId) = await seededDb();
      final AccountRepository accountRepo = AccountRepository(db);
      final FinancialInstitutionRepository institutionRepo = FinancialInstitutionRepository(db);
      final String institutionId =
          await institutionRepo.findOrCreate(profileId: profileId, name: 'Chase');
      final String accountId = await accountRepo.createClassifiedAccount(
        profileId: profileId,
        name: 'Checking',
        type: 'bank',
        balanceClass: BalanceClass.asset,
        subtype: FinancialAccountSubtype.bank,
        currencyCode: 'USD',
        institutionId: institutionId,
      );
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container, accountId));
      await openDetail(tester);

      expect(tester.takeException(), isNull);
      expect(
        find.descendant(of: find.byKey(const Key('accountInstitutionRow')), matching: find.text('Chase')),
        findsOneWidget,
      );
    });

    testWidgets('never fabricates an institution row for an account with no institutionId',
        (tester) async {
      final (AppDatabase db, String profileId) = await seededDb();
      final AccountRepository accountRepo = AccountRepository(db);
      final String accountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Checking',
        type: 'bank',
        currencyCode: 'USD',
      );
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container, accountId));
      await openDetail(tester);

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('accountInstitutionRow')), findsNothing);
    });

    testWidgets(
        'Privacy: Account Detail never shows an aggregate Net Worth figure, even with a mixed '
        'asset/liability portfolio', (tester) async {
      final (AppDatabase db, String profileId) = await seededDb();
      final AccountRepository accountRepo = AccountRepository(db);
      final String accountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Checking',
        type: 'bank',
        currencyCode: 'USD',
        openingBalance: Money.fromMinorUnits(5000, 'USD'),
      );
      await accountRepo.createClassifiedAccount(
        profileId: profileId,
        name: 'Credit Card',
        type: 'creditCard',
        balanceClass: BalanceClass.liability,
        subtype: FinancialAccountSubtype.creditCard,
        currencyCode: 'USD',
        openingBalance: Money.fromMinorUnits(2000, 'USD'),
      );
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container, accountId));
      await openDetail(tester);

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Net worth'), findsNothing);
      expect(find.textContaining('Net Worth'), findsNothing);
    });

    testWidgets(
        'a long institution name at a narrow 320px width and 1.6x text scale renders without '
        'an overflow exception', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final (AppDatabase db, String profileId) = await seededDb();
      final AccountRepository accountRepo = AccountRepository(db);
      final FinancialInstitutionRepository institutionRepo = FinancialInstitutionRepository(db);
      final String institutionId = await institutionRepo.findOrCreate(
        profileId: profileId,
        name: 'The Really Very Long International Community Bank & Trust Co.',
      );
      final String accountId = await accountRepo.createClassifiedAccount(
        profileId: profileId,
        name: 'Credit Card',
        type: 'creditCard',
        balanceClass: BalanceClass.liability,
        subtype: FinancialAccountSubtype.creditCard,
        currencyCode: 'USD',
        openingBalance: Money.fromMinorUnits(999999, 'USD'),
        institutionId: institutionId,
      );
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container, accountId));
      await openDetail(tester);

      final Object? overflowException = tester.takeException();
      if (overflowException != null) {
        fail(
          'Narrow-screen (320px) + 1.6x text scale Account Detail (balance label + '
          'institution row) threw an exception:\n\n$overflowException',
        );
      }
      expect(find.byKey(const Key('accountBalanceLabel')), findsOneWidget);
      expect(find.byKey(const Key('accountInstitutionRow')), findsOneWidget);
    });
  });

  group('Japanese localization', () {
    testWidgets(
      'shows a localized type label, a localized Edit tooltip, and the untouched account name',
      (tester) async {
        final (AppDatabase db, String profileId) = await seededDb();
        final AccountRepository accountRepo = AccountRepository(db);
        final String accountId = await accountRepo.createAccount(
          profileId: profileId,
          name: 'Main Wallet',
          type: 'bank',
          currencyCode: 'JPY',
          openingBalance: Money.fromMinorUnits(50000, 'JPY'),
        );
        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(
          appWithRouter(container, accountId, locale: const Locale('ja')),
        );
        await openDetail(tester);

        expect(tester.takeException(), isNull);
        // Account name is user data -- never translated.
        expect(find.text('Main Wallet'), findsWidgets);
        expect(find.text('銀行 · JPY'), findsOneWidget);
        // No transactions recorded, so balance == opening balance -- both
        // legitimately render '¥50,000' (see `currentBalanceText` above).
        // This test's intent is localizing the type label/tooltip while
        // leaving the account name untranslated, so it scopes the balance
        // check to the hero balance specifically rather than asserting
        // global string uniqueness.
        expect(currentBalanceText('¥50,000'), findsOneWidget);
      },
    );

    testWidgets('shows the localized fallback title and unavailable message for a missing id',
        (tester) async {
      final (AppDatabase db, String _) = await seededDb();
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(
        appWithRouter(container, 'does-not-exist', locale: const Locale('ja')),
      );
      await openDetail(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('口座'), findsOneWidget); // accountFallbackTitle
      expect(find.text('この口座は利用できません。'), findsOneWidget); // accountNoLongerAvailableMessage
    });

    testWidgets(
        'Checkpoint L: shows the localized "Balance"/"Institution" labels for an ordinary '
        'asset account with a persisted institution', (tester) async {
      final (AppDatabase db, String profileId) = await seededDb();
      final AccountRepository accountRepo = AccountRepository(db);
      final FinancialInstitutionRepository institutionRepo = FinancialInstitutionRepository(db);
      final String institutionId =
          await institutionRepo.findOrCreate(profileId: profileId, name: 'Chase');
      final String accountId = await accountRepo.createClassifiedAccount(
        profileId: profileId,
        name: 'Checking',
        type: 'bank',
        balanceClass: BalanceClass.asset,
        subtype: FinancialAccountSubtype.bank,
        currencyCode: 'JPY',
        openingBalance: Money.fromMinorUnits(50000, 'JPY'),
        institutionId: institutionId,
      );
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(
        appWithRouter(container, accountId, locale: const Locale('ja')),
      );
      await openDetail(tester);

      expect(tester.takeException(), isNull);
      expect(balanceLabelText('残高'), findsOneWidget);
      expect(
        find.descendant(of: find.byKey(const Key('accountInstitutionRow')), matching: find.text('金融機関')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byKey(const Key('accountInstitutionRow')), matching: find.text('Chase')),
        findsOneWidget,
      );
    });

    testWidgets(
        'Checkpoint L: a liability account shows the localized "amount you currently owe" '
        'label in Japanese, never the plain asset balance label', (tester) async {
      final (AppDatabase db, String profileId) = await seededDb();
      final AccountRepository accountRepo = AccountRepository(db);
      final String accountId = await accountRepo.createClassifiedAccount(
        profileId: profileId,
        name: 'Credit Card',
        type: 'creditCard',
        balanceClass: BalanceClass.liability,
        subtype: FinancialAccountSubtype.creditCard,
        currencyCode: 'JPY',
        openingBalance: Money.fromMinorUnits(12000, 'JPY'),
      );
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(
        appWithRouter(container, accountId, locale: const Locale('ja')),
      );
      await openDetail(tester);

      expect(tester.takeException(), isNull);
      expect(balanceLabelText('現在の未払い残高'), findsOneWidget);
      expect(balanceLabelText('残高'), findsNothing);
    });
  });

  // Account Lifecycle Checkpoint: close/reactivate reachable from Account
  // Detail, the "closed" visual state, the Edit icon hidden while closed,
  // and the blocking-recurring-rule error surfacing as a clear message.
  group('Account Lifecycle Checkpoint: close/reactivate', () {
    testWidgets(
      'closing shows the Closed badge, hides Edit, and reactivating restores it -- no data loss',
      (tester) async {
        final (AppDatabase db, String profileId) = await seededDb();
        final AccountRepository accountRepo = AccountRepository(db);
        final TransactionRepository txRepo = TransactionRepository(db, accountRepo);
        final String accountId = await accountRepo.createAccount(
          profileId: profileId,
          name: 'Old Wallet',
          type: 'cash',
          currencyCode: 'USD',
          openingBalance: Money.fromMinorUnits(10000, 'USD'),
        );
        await txRepo.recordExpense(
          profileId: profileId,
          accountId: accountId,
          amount: Money.fromMinorUnits(2500, 'USD'),
          occurredAtUtc: DateTime.utc(2026, 1, 1),
        );
        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRouter(container, accountId));
        await openDetail(tester);

        // Active: Edit is shown, no Closed badge, close action present.
        expect(find.byKey(const Key('editAccount')), findsOneWidget);
        expect(find.byKey(const Key('accountClosedBadge')), findsNothing);
        expect(find.byKey(const Key('closeOrReactivateAccount')), findsOneWidget);
        // The balance before closing, to confirm it survives untouched.
        expect(currentBalanceText('\$75.00'), findsOneWidget);

        await tester.tap(find.byKey(const Key('closeOrReactivateAccount')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('confirmCloseAccount')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        // Closed: no Edit icon, a Closed badge, the action now offers
        // Reactivate, and the account/balance are still shown correctly --
        // never a "no longer available" state, never a reset balance.
        expect(find.byKey(const Key('editAccount')), findsNothing);
        expect(find.byKey(const Key('accountClosedBadge')), findsOneWidget);
        expect(find.text('Old Wallet'), findsWidgets);
        expect(currentBalanceText('\$75.00'), findsOneWidget);

        final AccountRow closed = await accountRepo.requireById(accountId);
        expect(closed.isActive, isFalse);
        expect(closed.deletedAt, isNotNull);

        await tester.tap(find.byKey(const Key('closeOrReactivateAccount')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('confirmReactivateAccount')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        // Reactivated: Edit is back, the badge is gone, balance unchanged.
        expect(find.byKey(const Key('editAccount')), findsOneWidget);
        expect(find.byKey(const Key('accountClosedBadge')), findsNothing);
        expect(currentBalanceText('\$75.00'), findsOneWidget);

        final AccountRow reactivated = await accountRepo.requireById(accountId);
        expect(reactivated.isActive, isTrue);
        expect(reactivated.deletedAt, isNull);
        expect(reactivated.id, accountId); // never a replacement account
      },
    );

    testWidgets('canceling the close confirmation dialog leaves the account untouched and active',
        (tester) async {
      final (AppDatabase db, String profileId) = await seededDb();
      final AccountRepository accountRepo = AccountRepository(db);
      final String accountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Wallet',
        type: 'cash',
        currencyCode: 'USD',
      );
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container, accountId));
      await openDetail(tester);

      await tester.tap(find.byKey(const Key('closeOrReactivateAccount')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('editAccount')), findsOneWidget);
      expect(find.byKey(const Key('accountClosedBadge')), findsNothing);
      final AccountRow stillActive = await accountRepo.requireById(accountId);
      expect(stillActive.isActive, isTrue);
      expect(stillActive.deletedAt, isNull);
    });

    testWidgets(
      'closing an account a recurring rule still references shows a clear blocking message, not an exception',
      (tester) async {
        final (AppDatabase db, String profileId) = await seededDb();
        final AccountRepository accountRepo = AccountRepository(db);
        final RecurringRuleRepository ruleRepo = RecurringRuleRepository(db, accountRepo);
        final String accountId = await accountRepo.createAccount(
          profileId: profileId,
          name: 'Checking',
          type: 'bank',
          currencyCode: 'USD',
          openingBalance: Money.fromMinorUnits(100000, 'USD'),
        );
        await ruleRepo.createRule(
          profileId: profileId,
          kind: RecurringRuleKind.expense,
          name: 'Rent',
          amount: Money.fromMinorUnits(50000, 'USD'),
          accountId: accountId,
          frequency: RecurrenceFrequency.monthly,
          interval: 1,
          startDate: DateTime.utc(2026, 1, 1),
        );
        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRouter(container, accountId));
        await openDetail(tester);

        await tester.tap(find.byKey(const Key('closeOrReactivateAccount')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('confirmCloseAccount')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        // Blocked -- still active, Edit still shown, no Closed badge, and
        // a clear message shown instead of a raw exception (never
        // exposing internal terms like "deletedAt"/"RecurringRule").
        expect(find.byKey(const Key('editAccount')), findsOneWidget);
        expect(find.byKey(const Key('accountClosedBadge')), findsNothing);
        expect(
          find.text(
            'This account is still used by one or more recurring rules. Change or delete '
            'them first, then try closing this account again.',
          ),
          findsOneWidget,
        );
        final AccountRow stillActive = await accountRepo.requireById(accountId);
        expect(stillActive.isActive, isTrue);
        expect(stillActive.deletedAt, isNull);
      },
    );
  });

  // -- Checkpoint J (docs/20 §13.14): deposit Account Detail upgrade.
  // Uses `AccountRepository.createClassifiedAccount` +
  // `DepositRepository.createDetails` directly to seed a real
  // `subtype: deposit` account with a `DepositDetails` row -- the same
  // precedent `deposit_repository_test.dart` and
  // `dashboard_providers_test.dart` already established, since
  // production Add Account still cannot create a deposit account
  // through the app in V1.
  group('Checkpoint J -- Deposit details', () {
    testWidgets(
      'a deposit account shows interest rate, start date, maturity date, term, and an '
      'Active status when maturity is in the future',
      (tester) async {
        final (AppDatabase db, String profileId) = await seededDb();
        final AccountRepository accountRepo = AccountRepository(db);
        final DepositRepository depositRepo = DepositRepository(db, accountRepo);
        final String accountId = await accountRepo.createClassifiedAccount(
          profileId: profileId,
          name: 'Fixed Deposit',
          type: 'deposit',
          balanceClass: BalanceClass.asset,
          subtype: FinancialAccountSubtype.deposit,
          currencyCode: 'JPY',
          openingBalance: Money.fromMinorUnits(100000, 'JPY'),
        );
        // Maturity well in the future relative to "today" in this repo's
        // Checkpoint J working period -- see `deposit_status_test.dart`
        // for the pure boundary coverage of the active/matured cutoff
        // itself; this test only needs "clearly still active".
        await depositRepo.createDetails(
          profileId: profileId,
          accountId: accountId,
          depositType: DepositType.fixed,
          termNumber: 12,
          termUnit: DepositTermUnit.months,
          startDateUtc: DateTime.utc(2026, 1, 1),
          interestRateBasisPoints: 250,
          interestMethod: DepositInterestMethod.simple,
        );
        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRouter(container, accountId));
        await openDetail(tester);

        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('depositDetailsCard')), findsOneWidget);
        expect(find.text('Deposit details'), findsOneWidget);
        expect(find.text('2.50%'), findsOneWidget);
        expect(find.text('Jan 1, 2026'), findsOneWidget);
        expect(find.text('Jan 1, 2027'), findsOneWidget);
        expect(find.text('12 months'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key('depositStatusBadge')),
            matching: find.text('Active'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('a deposit account past its maturity date shows a Matured status', (
      tester,
    ) async {
      final (AppDatabase db, String profileId) = await seededDb();
      final AccountRepository accountRepo = AccountRepository(db);
      final DepositRepository depositRepo = DepositRepository(db, accountRepo);
      final String accountId = await accountRepo.createClassifiedAccount(
        profileId: profileId,
        name: 'Old Deposit',
        type: 'deposit',
        balanceClass: BalanceClass.asset,
        subtype: FinancialAccountSubtype.deposit,
        currencyCode: 'JPY',
        openingBalance: Money.fromMinorUnits(50000, 'JPY'),
      );
      // A one-year term starting in 2020 has long since matured.
      await depositRepo.createDetails(
        profileId: profileId,
        accountId: accountId,
        depositType: DepositType.fixed,
        termNumber: 1,
        termUnit: DepositTermUnit.years,
        startDateUtc: DateTime.utc(2020, 1, 1),
        interestRateBasisPoints: 100,
        interestMethod: DepositInterestMethod.simple,
      );
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container, accountId));
      await openDetail(tester);

      expect(tester.takeException(), isNull);
      expect(
        find.descendant(
          of: find.byKey(const Key('depositStatusBadge')),
          matching: find.text('Matured'),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'a non-deposit account never shows the deposit details card at all',
      (tester) async {
        final (AppDatabase db, String profileId) = await seededDb();
        final AccountRepository accountRepo = AccountRepository(db);
        final String accountId = await accountRepo.createAccount(
          profileId: profileId,
          name: 'Ordinary Wallet',
          type: 'cash',
          currencyCode: 'JPY',
        );
        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRouter(container, accountId));
        await openDetail(tester);

        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('depositDetailsCard')), findsNothing);
      },
    );

    testWidgets(
      'closing a deposit account leaves its deposit status unaffected -- Deposit Status and '
      'Account Lifecycle status remain independent concepts, both shown, neither masking the '
      'other',
      (tester) async {
        final (AppDatabase db, String profileId) = await seededDb();
        final AccountRepository accountRepo = AccountRepository(db);
        final DepositRepository depositRepo = DepositRepository(db, accountRepo);
        final String accountId = await accountRepo.createClassifiedAccount(
          profileId: profileId,
          name: 'Fixed Deposit',
          type: 'deposit',
          balanceClass: BalanceClass.asset,
          subtype: FinancialAccountSubtype.deposit,
          currencyCode: 'JPY',
          openingBalance: Money.fromMinorUnits(100000, 'JPY'),
        );
        // Details must be attached while the account is still active --
        // `DepositRepository.createDetails` rejects an inactive account
        // -- so close the account only AFTER creating its details.
        await depositRepo.createDetails(
          profileId: profileId,
          accountId: accountId,
          depositType: DepositType.fixed,
          termNumber: 12,
          termUnit: DepositTermUnit.months,
          startDateUtc: DateTime.utc(2026, 1, 1),
          interestRateBasisPoints: 250,
          interestMethod: DepositInterestMethod.simple,
        );
        await accountRepo.softDelete(accountId);
        final ProviderContainer container =
            ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRouter(container, accountId));
        await openDetail(tester);

        expect(tester.takeException(), isNull);
        // Account Lifecycle's own Closed badge still renders.
        expect(find.byKey(const Key('accountClosedBadge')), findsOneWidget);
        // The deposit details card, and its Active/Matured status, are
        // entirely unaffected by the account being closed.
        expect(find.byKey(const Key('depositDetailsCard')), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key('depositStatusBadge')),
            matching: find.text('Active'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
        'Checkpoint L: reactivating a closed, already-MATURED deposit does not reset its '
        'maturity status back to Active -- lifecycle and deposit-maturity stay independent '
        'through a full close+reactivate cycle, not just while closed',
        (tester) async {
      final (AppDatabase db, String profileId) = await seededDb();
      final AccountRepository accountRepo = AccountRepository(db);
      final DepositRepository depositRepo = DepositRepository(db, accountRepo);
      final String accountId = await accountRepo.createClassifiedAccount(
        profileId: profileId,
        name: 'Old Deposit',
        type: 'deposit',
        balanceClass: BalanceClass.asset,
        subtype: FinancialAccountSubtype.deposit,
        currencyCode: 'JPY',
        openingBalance: Money.fromMinorUnits(50000, 'JPY'),
      );
      // A one-year term starting in 2020 has long since matured.
      await depositRepo.createDetails(
        profileId: profileId,
        accountId: accountId,
        depositType: DepositType.fixed,
        termNumber: 1,
        termUnit: DepositTermUnit.years,
        startDateUtc: DateTime.utc(2020, 1, 1),
        interestRateBasisPoints: 100,
        interestMethod: DepositInterestMethod.simple,
      );
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container, accountId));
      await openDetail(tester);

      // Matured while still active, before touching lifecycle at all.
      expect(
        find.descendant(
          of: find.byKey(const Key('depositStatusBadge')),
          matching: find.text('Matured'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('closeOrReactivateAccount')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirmCloseAccount')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('accountClosedBadge')), findsOneWidget);
      // Still Matured while closed -- closing never matures/unmatures a
      // deposit (Checkpoint J's own rule, reconfirmed here).
      expect(
        find.descendant(
          of: find.byKey(const Key('depositStatusBadge')),
          matching: find.text('Matured'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('closeOrReactivateAccount')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirmReactivateAccount')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('accountClosedBadge')), findsNothing);
      // The precise regression this test exists for: reactivating the
      // account must not reset deposit maturity back to Active just
      // because the account itself is active again -- maturity is
      // derived purely from `DepositDetails.maturityDate`, never from
      // `AccountRow.isActive`/`deletedAt`.
      expect(
        find.descendant(
          of: find.byKey(const Key('depositStatusBadge')),
          matching: find.text('Matured'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the deposit details card survives a narrow 320px width at a 1.6x text scale',
        (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final (AppDatabase db, String profileId) = await seededDb();
      final AccountRepository accountRepo = AccountRepository(db);
      final DepositRepository depositRepo = DepositRepository(db, accountRepo);
      final String accountId = await accountRepo.createClassifiedAccount(
        profileId: profileId,
        name: 'Fixed Deposit',
        type: 'deposit',
        balanceClass: BalanceClass.asset,
        subtype: FinancialAccountSubtype.deposit,
        currencyCode: 'JPY',
        openingBalance: Money.fromMinorUnits(100000, 'JPY'),
      );
      await depositRepo.createDetails(
        profileId: profileId,
        accountId: accountId,
        depositType: DepositType.fixed,
        termNumber: 12,
        termUnit: DepositTermUnit.months,
        startDateUtc: DateTime.utc(2026, 1, 1),
        interestRateBasisPoints: 250,
        interestMethod: DepositInterestMethod.simple,
      );
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container, accountId));
      await openDetail(tester);

      final Object? overflowException = tester.takeException();
      if (overflowException != null) {
        fail(
          'Narrow-screen (320px) + 1.6x text scale deposit details card threw an '
          'exception:\n\n$overflowException',
        );
      }
      expect(find.byKey(const Key('depositDetailsCard')), findsOneWidget);
    });
  });

  group('Checkpoint O -- Credit facility details', () {
    Future<String> seedCreditCard(
      AppDatabase db,
      String profileId, {
      required int owedMinorUnits,
      required int creditLimitMinorUnits,
      String currencyCode = 'JPY',
    }) async {
      final AccountRepository accountRepo = AccountRepository(db);
      final CreditFacilityRepository facilityRepo = CreditFacilityRepository(db, accountRepo);
      final String accountId = await accountRepo.createClassifiedAccount(
        profileId: profileId,
        name: 'Test Card',
        type: 'creditCard',
        balanceClass: BalanceClass.liability,
        subtype: FinancialAccountSubtype.creditCard,
        currencyCode: currencyCode,
        openingBalance: Money.fromMinorUnits(owedMinorUnits, currencyCode),
      );
      await facilityRepo.createFacility(
        profileId: profileId,
        accountId: accountId,
        creditLimit: Money.fromMinorUnits(creditLimitMinorUnits, currencyCode),
      );
      return accountId;
    }

    testWidgets(
        'H/I/M. normal case: shows Credit limit / Available credit / Credit utilization rows',
        (tester) async {
      final (AppDatabase db, String profileId) = await seededDb();
      final String accountId = await seedCreditCard(
        db,
        profileId,
        owedMinorUnits: 80000,
        creditLimitMinorUnits: 500000,
      );
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container, accountId));
      await openDetail(tester);

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('creditFacilityDetailsCard')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('creditLimitRow')),
          matching: find.text('¥500,000'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('availableCreditRow')),
          matching: find.text('¥420,000'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('creditUtilizationRow')),
          matching: find.text('16.00%'),
        ),
        findsOneWidget,
      );
      // Never duplicates the hero -- "Amount you currently owe" remains
      // the one primary debt figure.
      expect(balanceLabelText('Amount you currently owe'), findsOneWidget);
      expect(currentBalanceText('¥80,000'), findsOneWidget);
    });

    testWidgets('L/N. over-limit: available credit clamped to zero, utilization shown past 100%',
        (tester) async {
      final (AppDatabase db, String profileId) = await seededDb();
      final String accountId = await seedCreditCard(
        db,
        profileId,
        owedMinorUnits: 550000,
        creditLimitMinorUnits: 500000,
      );
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container, accountId));
      await openDetail(tester);

      expect(tester.takeException(), isNull);
      expect(
        find.descendant(
          of: find.byKey(const Key('availableCreditRow')),
          matching: find.text('¥0'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('creditUtilizationRow')),
          matching: find.text('110.00%'),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
        'O. missing limit: a zero (never-assigned) credit limit shows "Not set" for all three '
        'rows rather than a fabricated 0%/full-available-credit figure', (tester) async {
      final (AppDatabase db, String profileId) = await seededDb();
      final String accountId = await seedCreditCard(
        db,
        profileId,
        owedMinorUnits: 12000,
        creditLimitMinorUnits: 0,
      );
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container, accountId));
      await openDetail(tester);

      expect(tester.takeException(), isNull);
      expect(
        find.descendant(
          of: find.byKey(const Key('creditLimitRow')),
          matching: find.text('Not set'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('availableCreditRow')),
          matching: find.text('Not set'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('creditUtilizationRow')),
          matching: find.text('Not set'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('never leaks onto a non-credit-card account', (tester) async {
      final (AppDatabase db, String profileId) = await seededDb();
      final AccountRepository accountRepo = AccountRepository(db);
      final String accountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Everyday Bank',
        type: 'bank',
        currencyCode: 'JPY',
        openingBalance: Money.fromMinorUnits(50000, 'JPY'),
      );
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container, accountId));
      await openDetail(tester);

      expect(find.byKey(const Key('creditFacilityDetailsCard')), findsNothing);
    });

    testWidgets('AC. no Net Worth figure/label leaks onto Account Detail for a credit card',
        (tester) async {
      final (AppDatabase db, String profileId) = await seededDb();
      final String accountId = await seedCreditCard(
        db,
        profileId,
        owedMinorUnits: 80000,
        creditLimitMinorUnits: 500000,
      );
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container, accountId));
      await openDetail(tester);

      expect(find.text('Net Worth'), findsNothing);
      expect(find.text('Net worth'), findsNothing);
    });

    testWidgets('AA. Japanese localization: Credit details section and its three rows',
        (tester) async {
      final (AppDatabase db, String profileId) = await seededDb();
      final String accountId = await seedCreditCard(
        db,
        profileId,
        owedMinorUnits: 80000,
        creditLimitMinorUnits: 500000,
      );
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(
        appWithRouter(container, accountId, locale: const Locale('ja')),
      );
      await openDetail(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('クレジットカードの詳細'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('creditLimitRow')),
          matching: find.text('利用限度額'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('availableCreditRow')),
          matching: find.text('利用可能額'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('creditUtilizationRow')),
          matching: find.text('利用率'),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
        'AB. the credit facility details card survives a narrow 320px width at a 1.6x text scale',
        (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final (AppDatabase db, String profileId) = await seededDb();
      final String accountId = await seedCreditCard(
        db,
        profileId,
        owedMinorUnits: 8000000,
        creditLimitMinorUnits: 50000000,
        currencyCode: 'JPY',
      );
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container, accountId));
      await openDetail(tester);

      final Object? overflowException = tester.takeException();
      if (overflowException != null) {
        fail(
          'Narrow-screen (320px) + 1.6x text scale credit facility details card threw an '
          'exception:\n\n$overflowException',
        );
      }
      expect(find.byKey(const Key('creditFacilityDetailsCard')), findsOneWidget);
    });
  });
}
