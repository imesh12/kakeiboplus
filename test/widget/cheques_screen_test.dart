import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/providers.dart';
import 'package:ai_financial_coach/core/database/repositories/account_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/cheque_book_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/cheque_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/transaction_repository.dart';
import 'package:ai_financial_coach/core/money/money.dart';
import 'package:ai_financial_coach/features/cheques/presentation/cheque_providers.dart';
import 'package:ai_financial_coach/features/cheques/presentation/cheques_screen.dart';
import 'package:ai_financial_coach/l10n/generated/app_localizations.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// NOTE: exercises generated Drift code -- see CLAUDE_FIRST_CODING_PROMPT.md.
//
// Checkpoint N: ChequesScreen -- the Cheques/Checks list, and its
// FAB-driven Record Issued/Record Received/Create Chequebook flows.
void main() {
  Future<(AppDatabase, String, String)> seededDbWithBankAccount() async {
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    final ProfileRepository profileRepo = ProfileRepository(db);
    final String profileId = await profileRepo.createProfile(
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
    final AccountRepository accountRepo = AccountRepository(db);
    final String accountId = await accountRepo.createAccount(
      profileId: profileId,
      name: 'Everyday Chequing',
      type: 'bank',
      currencyCode: 'USD',
      openingBalance: Money.fromMinorUnits(500000, 'USD'),
    );
    return (db, profileId, accountId);
  }

  Widget appWithCheques(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ChequesScreen(),
      ),
    );
  }

  Future<void> disposeInOrder(WidgetTester tester, ProviderContainer container, AppDatabase db) async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pumpAndSettle();
    await db.close();
  }

  testWidgets('1. an empty profile shows the "no cheques yet" message', (tester) async {
    final (AppDatabase db, _, _) = await seededDbWithBankAccount();
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithCheques(container));
    await tester.pumpAndSettle();

    expect(find.textContaining('No cheques yet'), findsOneWidget);
  });

  testWidgets('2. tapping the FAB shows both the issued and received options', (tester) async {
    final (AppDatabase db, _, _) = await seededDbWithBankAccount();
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithCheques(container));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('addChequeFab')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('recordIssuedChequeOption')), findsOneWidget);
    expect(find.byKey(const Key('recordReceivedChequeOption')), findsOneWidget);
  });

  testWidgets(
    '3. a pre-existing pending issued cheque shows in the list with a signed amount and the '
    'status word "Pending" as TEXT, never color-only',
    (tester) async {
      final (AppDatabase db, String profileId, String accountId) = await seededDbWithBankAccount();
      final AccountRepository accountRepo = AccountRepository(db);
      final ChequeBookRepository bookRepo = ChequeBookRepository(db, accountRepo);
      final ChequeRepository chequeRepo =
          ChequeRepository(db, accountRepo, bookRepo, TransactionRepository(db, accountRepo));
      final String bookId = await bookRepo.createChequeBook(
        profileId: profileId,
        accountId: accountId,
        label: 'Book',
      );
      await chequeRepo.recordIssued(
        profileId: profileId,
        accountId: accountId,
        chequeBookId: bookId,
        chequeNumber: '000101',
        amount: Money.fromMinorUnits(15000, 'USD'),
        payeeName: 'Landlord',
        issueDateUtc: DateTime.utc(2026, 9, 1),
      );

      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithCheques(container));
      await tester.pumpAndSettle();

      expect(find.text('Landlord'), findsOneWidget);
      expect(find.textContaining('-\$150.00'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
    },
  );

  testWidgets('4. a pre-existing pending received cheque shows a "+" signed amount', (tester) async {
    final (AppDatabase db, String profileId, String accountId) = await seededDbWithBankAccount();
    final AccountRepository accountRepo = AccountRepository(db);
    final ChequeBookRepository bookRepo = ChequeBookRepository(db, accountRepo);
    final ChequeRepository chequeRepo =
        ChequeRepository(db, accountRepo, bookRepo, TransactionRepository(db, accountRepo));
    await chequeRepo.recordReceived(
      profileId: profileId,
      accountId: accountId,
      chequeNumber: '5551',
      amount: Money.fromMinorUnits(9900, 'USD'),
      payerName: 'Client Co',
      issueDateUtc: DateTime.utc(2026, 9, 1),
      receivedDateUtc: DateTime.utc(2026, 9, 2),
    );

    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithCheques(container));
    await tester.pumpAndSettle();

    expect(find.text('Client Co'), findsOneWidget);
    expect(find.textContaining('+\$99.00'), findsOneWidget);
  });

  testWidgets(
    '5. recording an issued cheque end-to-end via the FAB dialog, including creating a '
    'chequebook inline, shows the new pending cheque in the list',
    (tester) async {
      final (AppDatabase db, _, String accountId) = await seededDbWithBankAccount();
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);

      // Root cause (confirmed against real Windows `flutter test` runs):
      // once an account is selected below, `_RecordIssuedChequeDialog`
      // watches `activeChequeBooksForAccountProvider(accountId)` -- an
      // `autoDispose` family `StreamProvider` (see
      // `cheque_providers.dart`) -- to populate its chequebook picker.
      // That watch is this provider instance's ONLY listener, so
      // `_submit()`'s `Navigator.of(context).pop()` at the very end of
      // this test (after `saveIssuedCheque`) drops its last listener
      // right there, mid-test, not at this test's shared teardown.
      // Riverpod tears the provider down immediately at that
      // uncontrolled point, cancelling its underlying Drift query and
      // scheduling Drift's `StreamQueryStore.markAsClosed` `Timer.zero`
      // as a side effect of whatever `pumpAndSettle()` happens to be
      // running at that exact moment inside the test body -- not the
      // shared `disposeInOrder` that runs afterwards. Adding more pumps
      // to `disposeInOrder` cannot catch a timer that was scheduled (or
      // not yet scheduled) before that helper even starts; the
      // "creating a category budget..." test in
      // `budgets_screen_test.dart` hit this exact class of bug first
      // and documents the same conclusion.
      //
      // Fix, matching that established precedent exactly: hold our own
      // `container.listen` subscription on the same
      // `activeChequeBooksForAccountProvider(accountId)` instance for
      // the rest of this test, so the dialog closing does NOT drop its
      // last listener -- the provider stays alive, watched, right
      // through Save. Disposal then happens exactly once, at the
      // single point this test's own teardown closes
      // `chequeBooksSubscription`, which can be settled deterministically
      // before disposing the container. This is a test-only keep-alive
      // -- `activeChequeBooksForAccountProvider` itself stays
      // `autoDispose` in production; nothing here changes what the app
      // ships.
      final ProviderSubscription<AsyncValue<List<ChequeBookRow>>> chequeBooksSubscription = container
          .listen<AsyncValue<List<ChequeBookRow>>>(
        activeChequeBooksForAccountProvider(accountId),
        (_, __) {},
      );

      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        // Closing this ourselves, before `container.dispose()`, is what
        // makes the resulting Drift cancellation happen at a moment
        // this test controls -- the same settled point every other
        // test's shared `disposeInOrder` relies on -- rather than
        // mid-test.
        chequeBooksSubscription.close();
        await tester.pumpAndSettle();
        container.dispose();
        await tester.pumpAndSettle();
        await db.close();
      });

      await tester.pumpWidget(appWithCheques(container));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('addChequeFab')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('recordIssuedChequeOption')));
      await tester.pumpAndSettle();

      // Select the seeded bank account.
      await tester.tap(find.byKey(const Key('chequeAccountDropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Everyday Chequing').last);
      await tester.pumpAndSettle();

      // No chequebook exists yet -- create one inline. This opens
      // `_CreateChequeBookDialog` ON TOP of the still-mounted "Record
      // issued cheque" dialog, whose own inline button
      // (`createChequeBookInline`) reuses the identical
      // `newChequeBookDialogTitle` string as its label -- a legitimate
      // production pair (one dialog's title, another dialog's launch
      // button), not unintended duplication, so `find.text('New
      // chequebook')` alone now matches both and is ambiguous. Scope
      // to the specific `AlertDialog` that also contains
      // `chequeBookLabelField` (unique to the create-chequebook
      // dialog) to target its title specifically, the same
      // ancestor/descendant-finder convention this suite's sibling
      // widget tests already use to disambiguate repeated text.
      await tester.tap(find.byKey(const Key('createChequeBookInline')));
      await tester.pumpAndSettle();
      final Finder createChequeBookDialog = find.ancestor(
        of: find.byKey(const Key('chequeBookLabelField')),
        matching: find.byType(AlertDialog),
      );
      expect(
        find.descendant(of: createChequeBookDialog, matching: find.text('New chequebook')),
        findsOneWidget,
      );
      await tester.enterText(find.byKey(const Key('chequeBookLabelField')), 'Primary Book');
      await tester.tap(find.byKey(const Key('saveChequeBook')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('chequeNumberField')), '000202');
      await tester.enterText(find.byKey(const Key('chequeAmountField')), '250.00');
      await tester.enterText(find.byKey(const Key('payeeField')), 'Utility Co');
      await tester.tap(find.byKey(const Key('saveIssuedCheque')));
      await tester.pumpAndSettle();

      expect(find.text('Record issued cheque'), findsNothing); // dialog closed
      expect(find.text('Utility Co'), findsOneWidget);
      expect(find.textContaining('-\$250.00'), findsOneWidget);
    },
  );

  testWidgets('6. recording a received cheque end-to-end via the FAB dialog', (tester) async {
    final (AppDatabase db, _, _) = await seededDbWithBankAccount();
    final ProviderContainer container =
        ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() => disposeInOrder(tester, container, db));

    await tester.pumpWidget(appWithCheques(container));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('addChequeFab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('recordReceivedChequeOption')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('chequeAccountDropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Everyday Chequing').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('receivedChequeNumberField')), '9001');
    await tester.enterText(find.byKey(const Key('receivedChequeAmountField')), '500.00');
    await tester.enterText(find.byKey(const Key('payerField')), 'Freelance Client');
    await tester.tap(find.byKey(const Key('saveReceivedCheque')));
    await tester.pumpAndSettle();

    expect(find.text('Record received cheque'), findsNothing);
    expect(find.text('Freelance Client'), findsOneWidget);
    expect(find.textContaining('+\$500.00'), findsOneWidget);
  });

  testWidgets(
    '7. the Cheques list lays out without overflow on a narrow (320px) screen at a 1.6x text '
    'scale, with a long counterparty name',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final (AppDatabase db, String profileId, String accountId) = await seededDbWithBankAccount();
      final AccountRepository accountRepo = AccountRepository(db);
      final ChequeBookRepository bookRepo = ChequeBookRepository(db, accountRepo);
      final ChequeRepository chequeRepo =
          ChequeRepository(db, accountRepo, bookRepo, TransactionRepository(db, accountRepo));
      final String bookId = await bookRepo.createChequeBook(
        profileId: profileId,
        accountId: accountId,
        label: 'Book',
      );
      await chequeRepo.recordIssued(
        profileId: profileId,
        accountId: accountId,
        chequeBookId: bookId,
        chequeNumber: '000303',
        amount: Money.fromMinorUnits(999999, 'USD'),
        payeeName: 'A Very Long Business Name That Could Wrap Awkwardly LLC',
        issueDateUtc: DateTime.utc(2026, 9, 1),
      );

      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithCheques(container));
      await tester.pumpAndSettle();

      final Object? overflowException = tester.takeException();
      if (overflowException != null) {
        fail('Narrow-screen (320px) Cheques list layout threw an exception:\n\n$overflowException');
      }
    },
  );
}
