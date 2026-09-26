import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/providers.dart';
import 'package:ai_financial_coach/core/database/repositories/account_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/cheque_book_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/cheque_not_found_exception.dart';
import 'package:ai_financial_coach/core/database/repositories/cheque_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/transaction_repository.dart';
import 'package:ai_financial_coach/core/money/money.dart';
import 'package:ai_financial_coach/core/routing/app_routes.dart';
import 'package:ai_financial_coach/features/cheques/presentation/cheque_detail_screen.dart';
import 'package:ai_financial_coach/features/cheques/presentation/cheque_providers.dart';
import 'package:ai_financial_coach/l10n/generated/app_localizations.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// NOTE: exercises generated Drift code -- see CLAUDE_FIRST_CODING_PROMPT.md.
//
// Checkpoint N: ChequeDetailScreen -- status-appropriate lifecycle
// action buttons (Clear / Mark bounced / Stop / Cancel / Delete), each
// gated by `ChequeStatus`. See `ChequeRepository`'s own doc for the
// exact transition table this screen must never bypass.
void main() {
  Future<
      (AppDatabase db, AccountRepository accountRepo, ChequeBookRepository bookRepo,
          ChequeRepository chequeRepo, String profileId, String accountId)> seeded() async {
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
    final ChequeBookRepository bookRepo = ChequeBookRepository(db, accountRepo);
    final ChequeRepository chequeRepo =
        ChequeRepository(db, accountRepo, bookRepo, TransactionRepository(db, accountRepo));
    return (db, accountRepo, bookRepo, chequeRepo, profileId, accountId);
  }

  GoRouter buildRouter({required bool startAtListFirst, required String chequeId}) {
    return GoRouter(
      initialLocation: startAtListFirst ? AppRoutes.cheques : AppRoutes.chequeDetail(chequeId),
      routes: <RouteBase>[
        GoRoute(
          path: AppRoutes.cheques,
          builder: (context, state) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => context.push(AppRoutes.chequeDetail(chequeId)),
                child: const Text('Cheques list'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.chequeDetailPath,
          builder: (context, state) => ChequeDetailScreen(chequeId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: AppRoutes.transactionDetailPath,
          builder: (context, state) => const Scaffold(body: Text('Transaction detail')),
        ),
      ],
    );
  }

  Widget appWithRouter(ProviderContainer container, GoRouter router) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
  }

  Widget appWithChequeDetail(ProviderContainer container, String chequeId) {
    return appWithRouter(container, buildRouter(startAtListFirst: false, chequeId: chequeId));
  }

  /// Same deterministic shutdown sequence as
  /// `home_screen_test.dart`/`add_transaction_screen_test.dart`'s
  /// `disposeInOrder`: unmount, then dispose, then one `pumpAndSettle()`
  /// so Drift's `StreamQueryStore.markAsClosed` `Timer.zero` fires
  /// before `db.close()`. Sufficient for every test in this file except
  /// test 5 below, which has its own bespoke teardown -- see that
  /// test's doc comment for why the shared pattern here doesn't apply
  /// to it.
  Future<void> disposeInOrder(WidgetTester tester, ProviderContainer container, AppDatabase db) async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pumpAndSettle();
    await db.close();
  }

  testWidgets(
    '1. a pending ISSUED cheque shows Clear/Bounce/Stop/Cancel/Delete, all gated by status',
    (tester) async {
      final (db, accountRepo, bookRepo, chequeRepo, profileId, accountId) = await seeded();
      final String bookId =
          await bookRepo.createChequeBook(profileId: profileId, accountId: accountId, label: 'Book');
      final String chequeId = await chequeRepo.recordIssued(
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

      await tester.pumpWidget(appWithChequeDetail(container, chequeId));
      await tester.pumpAndSettle();

      expect(find.text('Landlord'), findsOneWidget);
      expect(find.byKey(const Key('markChequeCleared')), findsOneWidget);
      expect(find.byKey(const Key('markChequeBounced')), findsOneWidget);
      expect(find.byKey(const Key('markChequeStopped')), findsOneWidget);
      expect(find.byKey(const Key('markChequeCancelled')), findsOneWidget);
      expect(find.byKey(const Key('deletePendingCheque')), findsOneWidget);
      expect(find.byKey(const Key('viewPostedTransaction')), findsNothing);
    },
  );

  testWidgets('2. a pending RECEIVED cheque shows Clear/Bounce/Cancel but NEVER Stop', (tester) async {
    final (db, accountRepo, bookRepo, chequeRepo, profileId, accountId) = await seeded();
    final String chequeId = await chequeRepo.recordReceived(
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

    await tester.pumpWidget(appWithChequeDetail(container, chequeId));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('markChequeCleared')), findsOneWidget);
    expect(find.byKey(const Key('markChequeBounced')), findsOneWidget);
    expect(find.byKey(const Key('markChequeCancelled')), findsOneWidget);
    expect(find.byKey(const Key('markChequeStopped')), findsNothing);
  });

  testWidgets(
    '3. confirming "Mark as cleared" transitions the cheque to Cleared, hides the pending '
    'actions, and reveals "View posted transaction"',
    (tester) async {
      final (db, accountRepo, bookRepo, chequeRepo, profileId, accountId) = await seeded();
      final String bookId =
          await bookRepo.createChequeBook(profileId: profileId, accountId: accountId, label: 'Book');
      final String chequeId = await chequeRepo.recordIssued(
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

      await tester.pumpWidget(appWithChequeDetail(container, chequeId));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('markChequeCleared')));
      await tester.pumpAndSettle();
      // Confirmation dialog -- tap "Confirm".
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(find.text('Cleared'), findsOneWidget);
      expect(find.byKey(const Key('markChequeCleared')), findsNothing);
      expect(find.byKey(const Key('markChequeBounced')), findsNothing);
      expect(find.byKey(const Key('viewPostedTransaction')), findsOneWidget);
    },
  );

  testWidgets(
    '4. tapping "View posted transaction" on a cleared cheque navigates to the real '
    'transaction detail route',
    (tester) async {
      final (db, accountRepo, bookRepo, chequeRepo, profileId, accountId) = await seeded();
      final String bookId =
          await bookRepo.createChequeBook(profileId: profileId, accountId: accountId, label: 'Book');
      final String chequeId = await chequeRepo.recordIssued(
        profileId: profileId,
        accountId: accountId,
        chequeBookId: bookId,
        chequeNumber: '000101',
        amount: Money.fromMinorUnits(15000, 'USD'),
        payeeName: 'Landlord',
        issueDateUtc: DateTime.utc(2026, 9, 1),
      );
      await chequeRepo.markCleared(chequeId: chequeId, clearedDateUtc: DateTime.utc(2026, 9, 5));

      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithChequeDetail(container, chequeId));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('viewPostedTransaction')));
      await tester.pumpAndSettle();

      expect(find.text('Transaction detail'), findsOneWidget);
    },
  );

  testWidgets(
    '5. deleting a pending cheque leaves it unresolvable (chequeByIdProvider now yields null)',
    (tester) async {
      final (db, accountRepo, bookRepo, chequeRepo, profileId, accountId) = await seeded();
      final String bookId =
          await bookRepo.createChequeBook(profileId: profileId, accountId: accountId, label: 'Book');
      final String chequeId = await chequeRepo.recordIssued(
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

      // Root cause (confirmed against real Windows `flutter test` runs):
      // `ChequeDetailScreen` watches `chequeByIdProvider(chequeId)` --
      // an `autoDispose` family `StreamProvider` (see
      // `cheque_providers.dart`). This test's own delete action pops
      // the screen mid-test (`_confirmDelete`: `deletePendingCheque` ->
      // `context.pop()`), which drops that provider's LAST listener
      // right there, not at this test's shared teardown. Riverpod tears
      // the provider down immediately at that uncontrolled point, which
      // cancels its underlying Drift query and schedules Drift's
      // `StreamQueryStore.markAsClosed` `Timer.zero` as a side effect of
      // whatever `pumpAndSettle()` happens to be running at that exact
      // moment inside the test body -- not the shared `disposeInOrder`
      // that runs afterwards. Adding more pumps to `disposeInOrder`
      // cannot catch a timer that was scheduled (or not yet scheduled)
      // before that helper even starts; `budgets_screen_test.dart`'s
      // "creating a category budget..." test hit this exact class of
      // bug first and documents the same conclusion.
      //
      // Fix, matching that established precedent exactly: hold our own
      // `container.listen` subscription on the same `chequeByIdProvider
      // (chequeId)` instance for the rest of this test, so popping the
      // detail screen does NOT drop its last listener -- the provider
      // stays alive, watched, right through the delete. Disposal then
      // happens exactly once, at the single point this test's own
      // teardown closes `chequeByIdSubscription`, which can be settled
      // deterministically before disposing the container. This is a
      // test-only keep-alive -- `chequeByIdProvider` itself stays
      // `autoDispose` in production; nothing here changes what the app
      // ships.
      final ProviderSubscription<AsyncValue<ChequeRow?>> chequeByIdSubscription = container
          .listen<AsyncValue<ChequeRow?>>(chequeByIdProvider(chequeId), (_, __) {});

      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        // Closing this ourselves, before `container.dispose()`, is what
        // makes the resulting Drift cancellation happen at a moment
        // this test controls -- the same settled point every other
        // test's shared `disposeInOrder` relies on -- rather than
        // mid-test.
        chequeByIdSubscription.close();
        await tester.pumpAndSettle();
        container.dispose();
        await tester.pumpAndSettle();
        await db.close();
      });

      // Start at the (stub) Cheques list and PUSH into the detail
      // screen -- so there is a real route on the stack for `context
      // .pop()` (called by the detail screen after a successful
      // delete) to return to, exactly like production navigation from
      // the real ChequesScreen.
      await tester.pumpWidget(
        appWithRouter(container, buildRouter(startAtListFirst: true, chequeId: chequeId)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cheques list'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('deletePendingCheque')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete cheque').last);
      await tester.pumpAndSettle();

      // Popped back to the list after a successful delete, and the
      // cheque no longer resolves at all. Explicitly awaited (rather
      // than the usual unawaited `expect(() => ..., throwsA(...))`
      // shorthand this repository's other tests use) so this async
      // repository call has fully settled before this test's own
      // teardown starts closing the keep-alive subscription/container/
      // database above.
      expect(find.text('Cheques list'), findsOneWidget);
      await expectLater(
        chequeRepo.requireById(chequeId),
        throwsA(isA<ChequeNotFoundException>()),
      );
    },
  );
}
