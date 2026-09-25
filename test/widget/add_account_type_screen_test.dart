import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/providers.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/finance/account_creation_kind.dart';
import 'package:ai_financial_coach/core/routing/app_routes.dart';
import 'package:ai_financial_coach/features/accounts/presentation/add_account_form_screen.dart';
import 'package:ai_financial_coach/features/accounts/presentation/add_account_type_screen.dart';
import 'package:ai_financial_coach/l10n/generated/app_localizations.dart';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../support/rtl_harness.dart';

// NOTE: exercises generated Drift code -- see CLAUDE_FIRST_CODING_PROMPT.md.
//
// Checkpoint G follow-up verification/coverage increment, Task 2A: focused
// widget coverage for `AddAccountTypeScreen` -- the icon-led type chooser
// that is the FIRST step of the new Add Account flow. This file only
// exercises the chooser itself; `add_account_form_screen_test.dart` covers
// the adaptive second-step form and the cross-screen navigation
// regression (Task 2F).
void main() {
  Future<AppDatabase> seededDb() async {
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    final ProfileRepository profileRepo = ProfileRepository(db);
    await profileRepo.createProfile(
      displayName: 'Test User',
      homeCountry: 'US',
      currentCountry: 'US',
      homeCurrency: 'USD',
      livingCurrency: 'USD',
      preferredLanguage: 'en',
      timezone: 'America/New_York',
      dateFormat: 'yyyy-MM-dd',
      numberFormat: '#,##0.##',
    );
    return db;
  }

  // Mirrors `account_detail_screen_test.dart`'s own `appWithRouter` --a
  // stub root screen with a button that pushes into the real flow, so
  // popping back off the chooser has somewhere real to land (rather than
  // the chooser being the initial/only route, which would make a "back"
  // test meaningless).
  Widget appWithRouter(
    ProviderContainer container, {
    bool rtl = false,
    Locale locale = const Locale('en'),
    ThemeData? theme,
  }) {
    final GoRouter router = GoRouter(
      initialLocation: '/accounts-stub',
      routes: <RouteBase>[
        GoRoute(
          path: '/accounts-stub',
          builder: (context, state) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => context.push(AppRoutes.addAccount),
                child: const Text('open add account'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.addAccount,
          builder: (context, state) => const AddAccountTypeScreen(),
        ),
        GoRoute(
          path: AppRoutes.addAccountFormPath,
          builder: (context, state) => AddAccountFormScreen(
            kind: AccountCreationKind.values.byName(state.pathParameters['kind']!),
          ),
        ),
      ],
    );
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: theme,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
        builder: rtl ? rtlAppBuilder : null,
      ),
    );
  }

  Future<void> openChooser(WidgetTester tester) async {
    await tester.tap(find.text('open add account'));
    await tester.pumpAndSettle();
  }

  Future<void> disposeInOrder(
    WidgetTester tester,
    ProviderContainer container,
    AppDatabase db,
  ) async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pumpAndSettle();
    await db.close();
  }

  group('Task 2A: type chooser', () {
    testWidgets(
      'displays all 6 supported types, with no internal terms (balanceClass/liability/'
      'legacyCardNeedsReview/asset) ever shown',
      (tester) async {
        final AppDatabase db = await seededDb();
        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
        );
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRouter(container));
        await openChooser(tester);

        expect(tester.takeException(), isNull);
        expect(find.text('Cash'), findsOneWidget);
        expect(find.text('Bank account'), findsOneWidget);
        expect(find.text('Savings account'), findsOneWidget);
        expect(find.text('E-money / Wallet'), findsOneWidget);
        expect(find.text('Deposit'), findsOneWidget);
        expect(find.text('Credit card'), findsOneWidget);

        // Never expose the technical vocabulary this checkpoint's own
        // brief prohibits -- checked as substrings so a partial/renamed
        // occurrence would still be caught.
        for (final String forbidden in <String>[
          'balanceClass',
          'liability',
          'legacyCardNeedsReview',
          'legacyUnknownNeedsReview',
          'FinancialAccountSubtype',
          'BalanceClass.',
        ]) {
          expect(
            find.textContaining(forbidden),
            findsNothing,
            reason: '"$forbidden" must never render on the type chooser',
          );
        }
      },
    );

    // (row title, expected form AppBar title) -- the form reuses
    // `accountCreationKindTitle` for its own AppBar, so the user sees the
    // same name on both screens (see that presentation file's own doc) --
    // this table locks in that every one of the 6 rows routes to the FORM
    // carrying its own matching title, not some other kind's.
    //
    // Each case gets its OWN `testWidgets` (fresh `pumpWidget`/router per
    // kind) rather than looping inside a single test and popping back to
    // the stub root between iterations. The previous shared-state loop
    // relied on two `pageBack()` calls per iteration leaving navigation in
    // exactly the right place before the next iteration's `openChooser()`
    // -- fragile, and not how a real user would exercise six independent
    // choices. Fresh state per kind removes that whole class of
    // cross-iteration navigation assumptions; every case below still
    // asserts exactly what the original test asserted (no exception, the
    // correctly-titled form's AppBar, and its "Create account" button).
    const List<(String, String)> routeToFormCases = <(String, String)>[
      ('Cash', 'Cash'),
      ('Bank account', 'Bank account'),
      ('Savings account', 'Savings account'),
      ('E-money / Wallet', 'E-money / Wallet'),
      ('Deposit', 'Deposit'),
      ('Credit card', 'Credit card'),
    ];
    for (final (String rowTitle, String formTitle) in routeToFormCases) {
      testWidgets(
        'selecting $rowTitle routes to the correspondingly-titled adaptive form',
        (tester) async {
          final AppDatabase db = await seededDb();
          final ProviderContainer container = ProviderContainer(
            overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
          );
          addTearDown(() => disposeInOrder(tester, container, db));

          await tester.pumpWidget(appWithRouter(container));
          await openChooser(tester);

          final Finder row = find.descendant(
            of: find.byType(AddAccountTypeScreen),
            matching: find.text(rowTitle),
          );
          final Finder chooserScrollable = find.descendant(
            of: find.byType(AddAccountTypeScreen),
            matching: find.byType(Scrollable),
          );
          expect(chooserScrollable, findsOneWidget);
          await tester.scrollUntilVisible(row, 200, scrollable: chooserScrollable);
          await tester.pumpAndSettle();
          expect(row.hitTestable(), findsOneWidget);

          await tester.tap(row);
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          // The AppBar title is the only `formTitle` occurrence on this
          // screen for every kind except `creditCard`/`deposit`, whose
          // AppBar title also happens to equal one of their own field
          // section labels in some locales -- scoping to `AppBar` keeps
          // this assertion correct for all 6 cases uniformly.
          expect(
            find.descendant(of: find.byType(AppBar), matching: find.text(formTitle)),
            findsOneWidget,
          );
          // "Create account" button confirms this really is the form,
          // not still the chooser or some blank route.
          expect(find.text('Create account'), findsOneWidget);
        },
      );
    }

    testWidgets(
      'cash routes to a form with no institution field, since cash never allows one',
      (tester) async {
        final AppDatabase db = await seededDb();
        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
        );
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRouter(container));
        await openChooser(tester);
        await tester.tap(find.text('Cash').first);
        await tester.pumpAndSettle();

        expect(find.text('Institution (optional)'), findsNothing);
      },
    );

    testWidgets(
      'bank routes to a form that DOES offer the optional institution field',
      (tester) async {
        final AppDatabase db = await seededDb();
        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
        );
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRouter(container));
        await openChooser(tester);
        await tester.tap(find.text('Bank account').first);
        await tester.pumpAndSettle();

        expect(find.text('Institution (optional)'), findsOneWidget);
      },
    );

    testWidgets(
      'navigation: chooser back returns to Accounts without creating anything',
      (tester) async {
        final AppDatabase db = await seededDb();
        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
        );
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRouter(container));
        await openChooser(tester);
        expect(find.text('Cash'), findsOneWidget);

        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('open add account'), findsOneWidget);
        expect(find.text('Cash'), findsNothing);
        final List<AccountRow> accounts = await db.select(db.accounts).get();
        expect(accounts, isEmpty);
      },
    );

    testWidgets(
      'resilience: renders without exceptions at a 1.6x text scale',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 1.6;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        final AppDatabase db = await seededDb();
        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
        );
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRouter(container));
        await openChooser(tester);

        expect(tester.takeException(), isNull);
        expect(find.text('Cash'), findsOneWidget);

        // Scope both the target and the scrollable to the chooser screen
        // itself, and confirm the scrollable resolves unambiguously,
        // before asking the framework to scroll to an item that may be
        // below the viewport at this larger text scale.
        final Finder creditCardRow = find.descendant(
          of: find.byType(AddAccountTypeScreen),
          matching: find.text('Credit card'),
        );
        final Finder chooserScrollable = find.descendant(
          of: find.byType(AddAccountTypeScreen),
          matching: find.byType(Scrollable),
        );
        expect(chooserScrollable, findsOneWidget);
        await tester.scrollUntilVisible(
          creditCardRow,
          200,
          scrollable: chooserScrollable,
          maxScrolls: 100,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(creditCardRow, findsOneWidget);
        expect(creditCardRow.hitTestable(), findsOneWidget);

        await tester.tap(creditCardRow);
        await tester.pumpAndSettle();
        expect(find.byType(AddAccountFormScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'resilience: renders without exceptions under a dark theme',
      (tester) async {
        final AppDatabase db = await seededDb();
        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
        );
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(
          appWithRouter(container, theme: ThemeData.dark(useMaterial3: true)),
        );
        await openChooser(tester);

        expect(tester.takeException(), isNull);
        expect(find.text('Cash'), findsOneWidget);
      },
    );

    testWidgets(
      'resilience: renders without exceptions under the Japanese locale, with localized '
      'row titles',
      (tester) async {
        final AppDatabase db = await seededDb();
        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
        );
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRouter(container, locale: const Locale('ja')));
        await openChooser(tester);

        expect(tester.takeException(), isNull);
        expect(find.text('口座を追加'), findsOneWidget); // chooser title
        expect(find.text('現金'), findsOneWidget); // "Cash"
        expect(find.text('クレジットカード'), findsOneWidget); // "Credit card"
      },
    );

    testWidgets(
      'resilience: renders without exceptions under a forced RTL layout direction',
      (tester) async {
        final AppDatabase db = await seededDb();
        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
        );
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRouter(container, rtl: true));
        await openChooser(tester);

        expect(tester.takeException(), isNull);
        expect(find.text('Cash'), findsOneWidget);
      },
    );
  });
}
