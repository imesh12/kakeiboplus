import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/providers.dart';
import 'package:ai_financial_coach/core/database/repositories/account_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/deposit_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/finance/account_creation_kind.dart';
import 'package:ai_financial_coach/core/finance/balance_class.dart';
import 'package:ai_financial_coach/core/finance/calendar_month_math.dart';
import 'package:ai_financial_coach/core/finance/card_network.dart';
import 'package:ai_financial_coach/core/finance/deposit_calculator.dart';
import 'package:ai_financial_coach/core/finance/deposit_compounding_frequency.dart';
import 'package:ai_financial_coach/core/finance/deposit_interest_method.dart';
import 'package:ai_financial_coach/core/finance/financial_account_subtype.dart';
import 'package:ai_financial_coach/core/finance/interest_rate_input.dart';
import 'package:ai_financial_coach/core/money/money.dart';
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
// Checkpoint G follow-up verification/coverage increment, Task 2 (sections
// B-F) and Task 3: focused widget coverage for `AddAccountFormScreen` --
// the adaptive second step of the Add Account flow -- plus the explicit
// cross-screen navigation regression test Task 2F calls for, and
// large-text/dark/Japanese/RTL resilience smoke coverage. Behavior over
// screenshots throughout, per the brief. `add_account_type_screen_test.dart`
// covers the type chooser itself (Task 2A) and its own resilience smoke.
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

  // Same stub-root-plus-real-flow harness as `add_account_type_screen_test
  // .dart`'s own `appWithRouter` -- every test below reaches the form the
  // same way a real user does (Accounts -> chooser -> form, two pushes
  // deep), so a successful creation's real double-`pop()` lands exactly
  // where Task 2F's regression test needs to observe it landing.
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

  /// Drives the real two-push path (stub -> chooser -> form) down to the
  /// form for [rowTitle] (the chooser row's English title).
  Future<void> openFormFor(WidgetTester tester, String rowTitle) async {
    await tester.tap(find.text('open add account'));
    await tester.pumpAndSettle();
    final Finder row = find.descendant(
      of: find.byType(AddAccountTypeScreen),
      matching: find.text(rowTitle),
    );
    final Finder chooserScrollable = find.descendant(
      of: find.byType(AddAccountTypeScreen),
      matching: find.byType(Scrollable),
    );
    // Fail with a clear "0 vs 1 Scrollable" message here rather than a
    // cryptic StateError from inside scrollUntilVisible/drag if this ever
    // stops resolving to exactly the chooser's own list.
    expect(chooserScrollable, findsOneWidget);
    await tester.scrollUntilVisible(row, 200, scrollable: chooserScrollable, maxScrolls: 100);
    await tester.pumpAndSettle();
    expect(row.hitTestable(), findsOneWidget);
    await tester.tap(row);
    await tester.pumpAndSettle();
  }

  /// The form's own vertical scrolling container -- the `Scrollable`
  /// `SingleChildScrollView` builds around the whole field `Column` (see
  /// `add_account_form_screen.dart`, one per screen). Deliberately NOT
  /// `find.byType(Scrollable)`/`find.descendant(..., matching:
  /// find.byType(Scrollable))` scoped to `AddAccountFormScreen` alone --
  /// every `TextFormField` on this form (name/amount/rate/term/...) is
  /// single-line, and single-line `EditableText` builds its OWN internal
  /// `Scrollable` too (horizontal, for cursor scrolling within the field --
  /// nothing to do with the page). Once several fields are on screen, that
  /// is one vertical `Scrollable` plus one horizontal `Scrollable` PER
  /// text field -- a bare "descendant Scrollable of the screen" finder
  /// matches all of them (this repair's own regression: 6 matches --
  /// `axisDirection: down` from the form, `axisDirection: right` from
  /// each `EditableText`), not the exactly-one a scroll/drag call needs.
  /// Filtering by `axisDirection == AxisDirection.down` instead picks
  /// only the page's own top-to-bottom scroll container: every
  /// `EditableText` on this screen scrolls horizontally, so none of them
  /// can ever match this predicate, regardless of how many text fields
  /// are focused/filled -- this depends only on scroll axis, never on
  /// tree-traversal order (`.first`/`.last`), so it holds regardless of
  /// how the widget tree happens to be ordered. If a future field ever
  /// becomes multi-line (a vertically-scrolling `EditableText`), this
  /// resolves to more than one match and `findsOneWidget` below fails
  /// loudly with a clear cause, rather than silently scrolling/tapping
  /// the wrong container.
  Finder formVerticalScrollable() {
    final Finder finder = find.descendant(
      of: find.byType(AddAccountFormScreen),
      matching: find.byWidgetPredicate(
        (Widget widget) => widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    );
    expect(finder, findsOneWidget);
    return finder;
  }

  Future<void> tapCreate(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.widgetWithText(FilledButton, 'Create account'),
      300,
      scrollable: formVerticalScrollable(),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();
  }

  /// Opens the Material date picker from the deposit form's start-date
  /// `ListTile` and accepts its `initialDate` (today, UTC midnight) by
  /// tapping OK without touching the calendar grid -- mirrors
  /// `_pickStartDate`'s own `initialDate` default exactly.
  Future<void> pickTodayAsStartDate(WidgetTester tester) async {
    // Let any focused-field scrolling/keyboard animation settle before
    // locating the date row.
    await tester.pumpAndSettle();
    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(AddAccountFormScreen)),
    );
    final Finder startDate = find.widgetWithText(ListTile, l10n.addAccountStartDateLabel);
    expect(startDate, findsOneWidget);

    // The form is a single SingleChildScrollView -- drag it like a real
    // user would, rather than relying solely on Scrollable.ensureVisible
    // (which can jump the row into position without the ListTile's
    // InkWell ever having received a settled, on-screen hit-test point).
    await tester.scrollUntilVisible(
      startDate,
      200,
      scrollable: formVerticalScrollable(),
      maxScrolls: 100,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(startDate);
    await tester.pumpAndSettle();
    expect(startDate.hitTestable(), findsOneWidget, reason: 'start-date row must be reachable');

    await tester.tap(startDate);
    await tester.pumpAndSettle();
    final Finder picker = find.byType(DatePickerDialog);
    expect(picker, findsOneWidget, reason: 'tapping the start-date row must open the date picker');
    final String okLabel = MaterialLocalizations.of(tester.element(picker)).okButtonLabel;
    await tester.tap(find.descendant(of: picker, matching: find.text(okLabel)));
    await tester.pumpAndSettle();
    expect(picker, findsNothing);
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

  group('Task 2B: common form fields', () {
    testWidgets('account name is required -- empty name blocks submission and creates nothing',
        (tester) async {
      final AppDatabase db = await seededDb();
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container));
      await openFormFor(tester, 'Bank account');

      // Name (0) left blank; amount (1) filled -- isolates the name
      // validator specifically.
      await tester.enterText(find.byType(TextFormField).at(1), '1000');
      await tapCreate(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Enter a name.'), findsOneWidget);
      expect(find.text('Create account'), findsOneWidget); // still on the form
      final List<AccountRow> accounts = await db.select(db.accounts).get();
      expect(accounts, isEmpty);
    });

    testWidgets(
      'currency selection works: switching from JPY to USD is reflected in the amount '
      'field prefix and in the created account currency',
      (tester) async {
        final AppDatabase db = await seededDb();
        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
        );
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRouter(container));
        await openFormFor(tester, 'Bank account');

        expect(find.text('JPY '), findsOneWidget); // MoneyTextField prefixText

        final Finder currency = find.widgetWithText(DropdownButtonFormField<String>, 'Currency');
        expect(currency, findsOneWidget);
        await tester.ensureVisible(currency);
        await tester.pumpAndSettle();
        await tester.tap(currency);
        await tester.pumpAndSettle();

        // The open dropdown menu renders its own ListView inside an
        // Overlay, on top of the form's own SingleChildScrollView -- it is
        // always the most-recently-mounted Scrollable, so anchor on that
        // rather than assuming it is the only ListView in the tree.
        final Finder menuScrollable = find.byType(Scrollable).last;
        expect(menuScrollable, findsOneWidget);
        // USD is the final option, beyond the dropdown menu's initial viewport.
        final Finder usd = find.text('USD');
        await tester.scrollUntilVisible(usd, 200, scrollable: menuScrollable, maxScrolls: 100);
        await tester.pumpAndSettle();
        expect(usd.hitTestable(), findsOneWidget);
        await tester.tap(usd);
        await tester.pumpAndSettle();

        expect(find.text('USD '), findsOneWidget);
        expect(find.text('JPY '), findsNothing);

        await tester.enterText(find.byType(TextFormField).at(0), 'USD checking');
        await tester.enterText(find.byType(TextFormField).at(1), '12.34');
        await tapCreate(tester);

        expect(tester.takeException(), isNull);
        final List<AccountRow> accounts = await db.select(db.accounts).get();
        expect(accounts, hasLength(1));
        expect(accounts.single.currencyCode, 'USD');
        expect(accounts.single.openingBalanceMinorUnits, 1234);
      },
    );

    testWidgets(
      'an invalid amount (a fractional yen amount, since JPY allows 0 decimal digits) is '
      'rejected cleanly and creates nothing',
      (tester) async {
        final AppDatabase db = await seededDb();
        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
        );
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRouter(container));
        await openFormFor(tester, 'Bank account');

        await tester.enterText(find.byType(TextFormField).at(0), 'Bad amount test');
        await tester.enterText(find.byType(TextFormField).at(1), '12.5');
        await tapCreate(tester);

        expect(tester.takeException(), isNull);
        expect(find.text('JPY allows at most 0 decimal digits.'), findsOneWidget);
        final List<AccountRow> accounts = await db.select(db.accounts).get();
        expect(accounts, isEmpty);
      },
    );

    testWidgets(
      'cancel/back from the form creates no account and returns to the chooser',
      (tester) async {
        final AppDatabase db = await seededDb();
        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
        );
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRouter(container));
        await openFormFor(tester, 'Bank account');

        // Fill in fields but never tap Create -- proves cancellation
        // discards them rather than something being created as a
        // side-effect of merely typing.
        await tester.enterText(find.byType(TextFormField).at(0), 'Should not be created');
        await tester.enterText(find.byType(TextFormField).at(1), '1000');

        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Bank account'), findsOneWidget); // back on the chooser row
        expect(find.text('open add account'), findsNothing); // not all the way back
        final List<AccountRow> accounts = await db.select(db.accounts).get();
        expect(accounts, isEmpty);
      },
    );
  });

  group('Task 2C: cash / bank / savings / wallet', () {
    for (final (String rowTitle, AccountCreationKind kind) in <(String, AccountCreationKind)>[
      ('Cash', AccountCreationKind.cash),
      ('Bank account', AccountCreationKind.bank),
      ('Savings account', AccountCreationKind.savings),
      ('E-money / Wallet', AccountCreationKind.wallet),
    ]) {
      testWidgets(
        '$rowTitle: successful submit reaches AccountCreationService.createSimpleAccount and '
        'creates exactly one account with the correct AccountCreationKind mapping',
        (tester) async {
          final AppDatabase db = await seededDb();
          final ProviderContainer container = ProviderContainer(
            overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
          );
          addTearDown(() => disposeInOrder(tester, container, db));

          await tester.pumpWidget(appWithRouter(container));
          await openFormFor(tester, rowTitle);

          // Cash never shows an institution field at all -- proves cash
          // never forces one, without needing a separate no-op test.
          expect(
            find.text('Institution (optional)'),
            kind.allowsInstitution ? findsOneWidget : findsNothing,
          );

          await tester.enterText(find.byType(TextFormField).at(0), '$rowTitle account');
          await tester.enterText(find.byType(TextFormField).at(1), '5000');
          await tapCreate(tester);

          expect(tester.takeException(), isNull);
          final List<AccountRow> accounts = await db.select(db.accounts).get();
          expect(accounts, hasLength(1));
          expect(accounts.single.balanceClassValue, kind.balanceClass);
          expect(accounts.single.subtypeValue, kind.subtype);
          expect(accounts.single.type, kind.legacyTypeLabel);
          expect(accounts.single.openingBalanceMinorUnits, 5000);
          // Landed all the way back at the stub root -- not the chooser --
          // confirming `createSimpleAccount` (not some other path) is
          // what this submit actually reached.
          expect(find.text('open add account'), findsOneWidget);
        },
      );
    }
  });

  group('Task 2D: credit card', () {
    testWidgets(
      'credit-card-specific fields appear, and no field exists for a full card number, '
      'CVV, CVC, or PIN',
      (tester) async {
        final AppDatabase db = await seededDb();
        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
        );
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRouter(container));
        await openFormFor(tester, 'Credit card');

        expect(find.text('Credit limit'), findsOneWidget);
        expect(find.text('Card network (optional)'), findsOneWidget);
        expect(find.text('Last 4 digits (optional)'), findsOneWidget);
        expect(find.text('Expiry month (optional)'), findsOneWidget);
        expect(find.text('Expiry year (optional)'), findsOneWidget);
        expect(find.text('Statement closing day (optional)'), findsOneWidget);
        expect(find.text('Payment due day (optional)'), findsOneWidget);

        for (final String forbidden in <String>[
          'Card number',
          'CVV',
          'CVC',
          'PIN',
          'Security code',
        ]) {
          expect(
            find.textContaining(forbidden),
            findsNothing,
            reason: '"$forbidden" must never be collected for a credit card',
          );
        }
      },
    );

    testWidgets(
      'a missing credit limit is surfaced as a validation error (the field\'s own '
      'MoneyTextField validator), and creates nothing',
      (tester) async {
        final AppDatabase db = await seededDb();
        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
        );
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRouter(container));
        await openFormFor(tester, 'Credit card');

        // Name (0), amount owed (1) filled; institution (2) skipped;
        // credit limit (3) deliberately left blank.
        await tester.enterText(find.byType(TextFormField).at(0), 'No limit card');
        await tester.enterText(find.byType(TextFormField).at(1), '0');
        await tapCreate(tester);

        expect(tester.takeException(), isNull);
        expect(find.text('Enter an amount.'), findsOneWidget);
        expect(find.text('Create account'), findsOneWidget); // still on the form
        final List<AccountRow> accounts = await db.select(db.accounts).get();
        expect(accounts, isEmpty);
      },
    );

    testWidgets(
      'optional fields (network, last4, expiry, statement/due day) behave, and a fully '
      'filled-in card succeeds, returning to Accounts rather than the chooser, with the '
      'correct three rows created',
      (tester) async {
        final AppDatabase db = await seededDb();
        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
        );
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRouter(container));
        await openFormFor(tester, 'Credit card');

        await tester.enterText(find.byType(TextFormField).at(0), 'Everyday Visa');
        await tester.enterText(find.byType(TextFormField).at(1), '15000');
        await tester.enterText(find.byType(TextFormField).at(3), '500000'); // credit limit

        await tester.tap(
          find.widgetWithText(DropdownButtonFormField<CardNetwork?>, 'Not specified'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Visa').last);
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField).at(4), '1234'); // last4
        await tester.enterText(find.byType(TextFormField).at(5), '6'); // expiry month
        await tester.enterText(find.byType(TextFormField).at(6), '2030'); // expiry year
        await tester.enterText(find.byType(TextFormField).at(7), '5'); // statement closing day
        await tester.enterText(find.byType(TextFormField).at(8), '20'); // due day

        await tapCreate(tester);

        expect(tester.takeException(), isNull);
        expect(find.text('open add account'), findsOneWidget);
        expect(find.text('Credit card'), findsNothing); // not back on the chooser

        final List<AccountRow> accounts = await db.select(db.accounts).get();
        expect(accounts, hasLength(1));
        expect(accounts.single.balanceClassValue, BalanceClass.liability);
        expect(accounts.single.subtypeValue, FinancialAccountSubtype.creditCard);
        final List<CreditFacilityDetailsRow> facilities =
            await db.select(db.creditFacilityDetails).get();
        expect(facilities, hasLength(1));
        expect(facilities.single.creditLimitMinorUnits, 500000);
        final List<PaymentInstrumentRow> instruments =
            await db.select(db.paymentInstruments).get();
        expect(instruments, hasLength(1));
        expect(instruments.single.last4, '1234');
      },
    );

    testWidgets(
      'creation failure (an existing repository-level rule the form does not itself '
      're-validate -- expiry month supplied without expiry year) leaves the user on the '
      'form with an error, and does not falsely report success',
      (tester) async {
        final AppDatabase db = await seededDb();
        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
        );
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRouter(container));
        await openFormFor(tester, 'Credit card');

        await tester.enterText(find.byType(TextFormField).at(0), 'Should not exist');
        await tester.enterText(find.byType(TextFormField).at(1), '0');
        await tester.enterText(find.byType(TextFormField).at(3), '100000');
        // Expiry month filled, expiry year deliberately left blank --
        // `PaymentInstrumentRepository._validateExpiry` requires both or
        // neither, but this form has no cross-field client-side check for
        // that (only expiry MONTH gets its own 1-12 range validator), so
        // this reaches the service and rolls back there instead.
        await tester.enterText(find.byType(TextFormField).at(5), '6');

        await tapCreate(tester);

        expect(tester.takeException(), isNull);
        // Still on the form -- no navigation happened.
        expect(find.text('Create account'), findsOneWidget);
        expect(find.textContaining('Could not create the account'), findsOneWidget);
        final List<AccountRow> accounts = await db.select(db.accounts).get();
        expect(accounts, isEmpty);
        final List<PaymentInstrumentRow> instruments =
            await db.select(db.paymentInstruments).get();
        expect(instruments, isEmpty);
      },
    );
  });

  group('Task 2E: deposit', () {
    testWidgets('deposit-specific fields appear', (tester) async {
      final AppDatabase db = await seededDb();
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container));
      await openFormFor(tester, 'Deposit');

      expect(find.text('Deposit type'), findsOneWidget);
      expect(find.text('Start date'), findsOneWidget);
      expect(find.text('Annual interest rate (%)'), findsOneWidget);
      expect(find.text('Interest method'), findsOneWidget);
      expect(find.text('Term length'), findsOneWidget);
      expect(find.text('Term unit'), findsOneWidget);
      expect(find.text('Renew automatically at maturity'), findsOneWidget);
      // Compounding frequency is conditional -- simple is the default.
      expect(find.text('Compounding frequency'), findsNothing);
    });

    testWidgets(
      'simple-interest configuration works end to end: the estimate appears once inputs are '
      'sufficient, matches DepositCalculator.calculateSimpleInterest exactly, and a valid '
      'submit creates the deposit account and DepositDetails row',
      (tester) async {
        final AppDatabase db = await seededDb();
        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
        );
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRouter(container));
        await openFormFor(tester, 'Deposit');

        await tester.enterText(find.byType(TextFormField).at(0), 'One-year fixed');
        await tester.enterText(find.byType(TextFormField).at(1), '100000');
        await tester.enterText(find.byType(TextFormField).at(3), '5.00'); // rate
        await tester.enterText(find.byType(TextFormField).at(4), '12'); // term number
        await tester.pump();

        final DateTime now = DateTime.now();
        final DateTime expectedStart = DateTime.utc(now.year, now.month, now.day);
        await pickTodayAsStartDate(tester);

        final int expectedBasisPoints =
            InterestRateInput.parseAnnualRatePercentToBasisPoints('5.00');
        final DateTime expectedMaturity = addWholeCalendarMonths(expectedStart, 12);
        final DepositEstimate expectedEstimate = DepositCalculator.calculateSimpleInterest(
          principal: Money.fromMinorUnits(100000, 'JPY'),
          interestRateBasisPoints: expectedBasisPoints,
          startDateUtc: expectedStart,
          maturityDateUtc: expectedMaturity,
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Estimated interest'), findsOneWidget);
        expect(
          find.text(expectedEstimate.estimatedInterest.toMajorUnitsString()),
          findsOneWidget,
        );
        expect(find.text('Estimated maturity value'), findsOneWidget);
        expect(
          find.text(expectedEstimate.estimatedMaturityValue.toMajorUnitsString()),
          findsOneWidget,
        );

        await tapCreate(tester);

        expect(tester.takeException(), isNull);
        expect(find.text('open add account'), findsOneWidget);
        final List<AccountRow> accounts = await db.select(db.accounts).get();
        expect(accounts, hasLength(1));
        expect(accounts.single.subtypeValue, FinancialAccountSubtype.deposit);
        final List<DepositDetailsRow> details = await db.select(db.depositDetails).get();
        expect(details, hasLength(1));
        expect(details.single.interestRateBasisPoints, expectedBasisPoints);
        expect(details.single.interestMethodValue, DepositInterestMethod.simple);
      },
    );

    testWidgets(
      'choosing Compound reveals the compounding-frequency field and hides the (now '
      'stale) estimate; submitting compound without one surfaces validation and does not '
      'navigate away; choosing one then succeeds',
      (tester) async {
        final AppDatabase db = await seededDb();
        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
        );
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRouter(container));
        await openFormFor(tester, 'Deposit');

        await tester.enterText(find.byType(TextFormField).at(0), 'Compound test');
        await tester.enterText(find.byType(TextFormField).at(1), '100000');
        await tester.enterText(find.byType(TextFormField).at(3), '5.00');
        await tester.enterText(find.byType(TextFormField).at(4), '12');
        await pickTodayAsStartDate(tester);

        expect(find.text('Estimated interest'), findsOneWidget); // simple estimate, pre-switch

        final Finder interestMethod =
            find.widgetWithText(DropdownButtonFormField<DepositInterestMethod>, 'Interest method');
        await tester.ensureVisible(interestMethod);
        await tester.pumpAndSettle();
        await tester.tap(interestMethod);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Compound').last);
        await tester.pumpAndSettle();

        expect(find.text('Compounding frequency'), findsOneWidget);
        expect(find.text('Estimated interest'), findsNothing);

        await tapCreate(tester);

        expect(tester.takeException(), isNull);
        expect(find.text('Choose a compounding frequency.'), findsOneWidget);
        expect(find.text('Create account'), findsOneWidget); // still on the form
        List<AccountRow> accounts = await db.select(db.accounts).get();
        expect(accounts, isEmpty);

        final Finder compoundingFrequency = find.widgetWithText(
          DropdownButtonFormField<DepositCompoundingFrequency>,
          'Compounding frequency',
        );
        await tester.ensureVisible(compoundingFrequency);
        await tester.pumpAndSettle();
        await tester.tap(compoundingFrequency);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Monthly').last);
        await tester.pumpAndSettle();

        await tapCreate(tester);

        expect(tester.takeException(), isNull);
        expect(find.text('open add account'), findsOneWidget);
        accounts = await db.select(db.accounts).get();
        expect(accounts, hasLength(1));
        final List<DepositDetailsRow> details = await db.select(db.depositDetails).get();
        expect(details, hasLength(1));
        expect(details.single.interestMethodValue, DepositInterestMethod.compound);
      },
    );
  });

  group('Task 2F: navigation regression', () {
    testWidgets(
      'the double-pop fix holds: Accounts -> chooser -> form -> successful create lands '
      'back on Accounts, NOT the chooser',
      (tester) async {
        final AppDatabase db = await seededDb();
        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
        );
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRouter(container));
        await openFormFor(tester, 'Cash');

        await tester.enterText(find.byType(TextFormField).at(0), 'Regression wallet');
        await tester.enterText(find.byType(TextFormField).at(1), '1000');
        await tapCreate(tester);

        expect(tester.takeException(), isNull);
        expect(find.text('open add account'), findsOneWidget); // back at the stub root
        expect(find.text('Cash'), findsNothing); // NOT the chooser
        expect(find.text('Create account'), findsNothing); // NOT the form
        final List<AccountRow> accounts = await db.select(db.accounts).get();
        expect(accounts, hasLength(1));
      },
    );

    testWidgets('form back (single pop) returns to the chooser, not all the way to Accounts',
        (tester) async {
      final AppDatabase db = await seededDb();
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container));
      await openFormFor(tester, 'Cash');

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Cash'), findsOneWidget); // the chooser row, still pushed
      expect(find.text('open add account'), findsNothing); // not the stub root
      final List<AccountRow> accounts = await db.select(db.accounts).get();
      expect(accounts, isEmpty);
    });
  });

  group('Task 3: resilience smoke coverage', () {
    testWidgets(
      'the bank-account form renders without exceptions at a 1.6x text scale, and the '
      'name field and Create button remain reachable',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 1.6;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        final AppDatabase db = await seededDb();
        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
        );
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRouter(container));
        await openFormFor(tester, 'Bank account');

        expect(tester.takeException(), isNull);
        await tester.enterText(find.byType(TextFormField).at(0), 'Scaled');
        await tester.enterText(find.byType(TextFormField).at(1), '1000');
        await tapCreate(tester);

        expect(tester.takeException(), isNull);
        final List<AccountRow> accounts = await db.select(db.accounts).get();
        expect(accounts, hasLength(1));
      },
    );

    testWidgets(
      'the deposit form (the most field-dense of the six) renders without exceptions at a '
      '2.0x text scale',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        final AppDatabase db = await seededDb();
        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
        );
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRouter(container));
        await openFormFor(tester, 'Deposit');

        expect(tester.takeException(), isNull);
        expect(find.text('Term length'), findsOneWidget);
        // The dense form must remain reachable by scrolling at the same 2.0x scale.
        for (final String label in <String>[
          'Currency',
          'Start date',
          'Annual interest rate (%)',
          'Interest method',
          'Term length',
          'Term unit',
          'Renew automatically at maturity',
          'Create account',
        ]) {
          // InputDecorator labels can ignore pointer events; test the actual
          // field/tile/button containing the label, not the decorative text.
          final Finder control = find.ancestor(
            of: find.text(label),
            matching: find.byWidgetPredicate(
              (widget) => widget is FormField || widget is ListTile || widget is FilledButton,
            ),
          );
          expect(control, findsOneWidget);
          await tester.ensureVisible(control);
          await tester.pumpAndSettle();
          expect(control.hitTestable(), findsOneWidget, reason: '$label must be reachable');
          expect(tester.takeException(), isNull);
        }
      },
    );

    testWidgets('the credit card form renders without exceptions under a dark theme',
        (tester) async {
      final AppDatabase db = await seededDb();
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(
        appWithRouter(container, theme: ThemeData.dark(useMaterial3: true)),
      );
      await openFormFor(tester, 'Credit card');

      expect(tester.takeException(), isNull);
      expect(find.text('Credit limit'), findsOneWidget);
    });

    testWidgets(
      'the bank-account form renders without exceptions under the Japanese locale, with '
      'localized labels, and still creates a real account',
      (tester) async {
        final AppDatabase db = await seededDb();
        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
        );
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithRouter(container, locale: const Locale('ja')));
        await tester.tap(find.text('open add account'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('銀行口座').first); // "Bank account"
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('名前'), findsOneWidget); // Name
        expect(find.text('通貨'), findsOneWidget); // Currency

        await tester.enterText(find.byType(TextFormField).at(0), '日本の銀行');
        await tester.enterText(find.byType(TextFormField).at(1), '1000');
        await tester.tap(find.widgetWithText(FilledButton, '口座を作成'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final List<AccountRow> accounts = await db.select(db.accounts).get();
        expect(accounts, hasLength(1));
      },
    );

    testWidgets('the deposit form renders without exceptions under a forced RTL layout',
        (tester) async {
      final AppDatabase db = await seededDb();
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithRouter(container, rtl: true));
      await openFormFor(tester, 'Deposit');

      expect(tester.takeException(), isNull);
      expect(find.text('Term length'), findsOneWidget);
    });
  });
}
