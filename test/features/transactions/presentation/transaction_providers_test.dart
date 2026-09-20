import 'dart:async';

import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/providers.dart';
import 'package:ai_financial_coach/core/database/repositories/account_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/transaction_repository.dart';
import 'package:ai_financial_coach/core/finance/balance_class.dart';
import 'package:ai_financial_coach/core/finance/finance_engine.dart';
import 'package:ai_financial_coach/core/finance/ledger_models.dart';
import 'package:ai_financial_coach/core/money/money.dart';
import 'package:ai_financial_coach/features/transactions/presentation/transaction_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// NOTE: exercises generated Drift code -- see CLAUDE_FIRST_CODING_PROMPT.md.
//
// Beta 1 Transaction UX (`docs/14_DECISION_LOG.md` ADR-025), Phase A.
// Proves the specific thing the audit for this task was asked to check:
// that editing/deleting a transaction through the repository propagates
// to `ledgerProvider`/`activeTransactionsProvider`/`transactionByIdProvider`
// -- and therefore to Activity, Home, and every `FinanceEngine`-derived
// value -- through their existing `async* { yield* repo.watchX(...) }`
// wiring, with no manual invalidation anywhere. This is deliberately a
// provider-level test (no widgets): the earlier audit found these
// providers already use a real Drift `.watch()` stream end to end, NOT
// the `ref.watch(x.stream).asyncExpand(...)` antipattern that caused a
// previous recurring-money bug (see `recurring_providers.dart`'s doc
// comment) -- so this locks that in as a regression test, at the layer
// where that bug actually lives.

/// Attaches a listener BEFORE the mutating write it's waiting on, then
/// resolves the first NON-NULL emission satisfying [predicate] --
/// attaching after the write risks missing the exact transition, since a
/// non-autoDispose provider can go directly `AsyncData(old)` ->
/// `AsyncData(new)` without re-entering `isLoading`. Same fix as
/// `recurring_providers_test.dart`'s `_waitFor`. Use [_waitForNullable]
/// instead when the value being waited for is itself allowed to be
/// `null` (e.g. "this id no longer resolves to a row").
Future<T> _waitFor<T>(
  ProviderContainer container,
  ProviderListenable<AsyncValue<T>> provider,
  bool Function(T) predicate,
) {
  final Completer<T> completer = Completer<T>();
  late final ProviderSubscription<AsyncValue<T>> sub;
  sub = container.listen(provider, (AsyncValue<T>? previous, AsyncValue<T> next) {
    final T? data = next.valueOrNull;
    if (data != null && predicate(data) && !completer.isCompleted) {
      completer.complete(data);
    }
  }, fireImmediately: true);
  return completer.future.whenComplete(sub.close);
}

/// Like [_waitFor], but keyed off [AsyncValue.hasValue] rather than a
/// non-null check, so a legitimately-`null` emission (e.g.
/// `transactionByIdProvider` after its row is soft-deleted) can satisfy
/// [predicate] too.
Future<T> _waitForNullable<T>(
  ProviderContainer container,
  ProviderListenable<AsyncValue<T>> provider,
  bool Function(T) predicate,
) {
  final Completer<T> completer = Completer<T>();
  late final ProviderSubscription<AsyncValue<T>> sub;
  sub = container.listen(provider, (AsyncValue<T>? previous, AsyncValue<T> next) {
    if (next.hasValue) {
      final T data = next.value as T;
      if (predicate(data) && !completer.isCompleted) {
        completer.complete(data);
      }
    }
  }, fireImmediately: true);
  return completer.future.whenComplete(sub.close);
}

void main() {
  late AppDatabase db;
  late ProfileRepository profileRepo;
  late AccountRepository accountRepo;
  late TransactionRepository transactionRepo;
  late String profileId;
  late String accountId;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    profileRepo = ProfileRepository(db);
    accountRepo = AccountRepository(db);
    transactionRepo = TransactionRepository(db, accountRepo);

    profileId = await profileRepo.createProfile(
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
    accountId = await accountRepo.createAccount(
      profileId: profileId,
      name: 'Wallet',
      type: 'cash',
      currencyCode: 'JPY',
    );

    container = ProviderContainer(overrides: <Override>[appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
  });

  test(
      "editing an expense's amount is reflected by activeTransactionsProvider and by "
      "FinanceEngine's derived account balance via ledgerProvider, with no manual refresh",
      () async {
    final String txId = await transactionRepo.recordExpense(
      profileId: profileId,
      accountId: accountId,
      amount: Money.fromMinorUnits(500, 'JPY'),
      occurredAtUtc: DateTime.utc(2026, 1, 1),
    );

    await _waitFor(
      container,
      activeTransactionsProvider,
      (List<Transaction> rows) => rows.length == 1 && rows.single.amountMinorUnits == 500,
    );

    final LedgerAccount account =
        LedgerAccount(id: accountId, currencyCode: 'JPY', openingBalance: Money.zero('JPY'), balanceClass: BalanceClass.asset);
    final List<LedgerTransaction> ledgerBefore = await container.read(ledgerProvider.future);
    expect(FinanceEngine.accountBalance(account, ledgerBefore), Money.fromMinorUnits(-500, 'JPY'));

    await transactionRepo.updateExpense(
      id: txId,
      accountId: accountId,
      amount: Money.fromMinorUnits(800, 'JPY'),
      occurredAtUtc: DateTime.utc(2026, 1, 1),
    );

    final List<Transaction> updatedActive = await _waitFor(
      container,
      activeTransactionsProvider,
      (List<Transaction> rows) => rows.length == 1 && rows.single.amountMinorUnits == 800,
    );
    expect(updatedActive.single.id, txId);

    final List<LedgerTransaction> ledgerAfter = await _waitFor(
      container,
      ledgerProvider,
      (List<LedgerTransaction> rows) => rows.single.amount == Money.fromMinorUnits(800, 'JPY'),
    );
    expect(FinanceEngine.accountBalance(account, ledgerAfter), Money.fromMinorUnits(-800, 'JPY'));
  });

  test(
      'soft-deleting a transaction drops it from activeTransactionsProvider and from its '
      "account's FinanceEngine balance via ledgerProvider, without a manual refresh", () async {
    final String txId = await transactionRepo.recordExpense(
      profileId: profileId,
      accountId: accountId,
      amount: Money.fromMinorUnits(500, 'JPY'),
      occurredAtUtc: DateTime.utc(2026, 1, 1),
    );
    await _waitFor(
      container,
      activeTransactionsProvider,
      (List<Transaction> rows) => rows.length == 1,
    );

    await transactionRepo.softDelete(txId);

    final List<Transaction> activeAfterDelete = await _waitFor(
      container,
      activeTransactionsProvider,
      (List<Transaction> rows) => rows.isEmpty,
    );
    expect(activeAfterDelete, isEmpty);

    final LedgerAccount account =
        LedgerAccount(id: accountId, currencyCode: 'JPY', openingBalance: Money.zero('JPY'), balanceClass: BalanceClass.asset);
    final List<LedgerTransaction> ledgerAfterDelete = await _waitFor(
      container,
      ledgerProvider,
      (List<LedgerTransaction> rows) => rows.single.isDeleted,
    );
    // The soft-deleted row is still present in the ledger stream (Beta 0's
    // convention -- see `TransactionRepository.watchLedgerForProfile`'s doc
    // comment), but `FinanceEngine` excludes anything with `isDeleted` from
    // the balance it derives.
    expect(FinanceEngine.accountBalance(account, ledgerAfterDelete), Money.zero('JPY'));
  });

  test(
      'transactionByIdProvider reflects an edit reactively, then emits null once the '
      'transaction is soft-deleted', () async {
    final String txId = await transactionRepo.recordExpense(
      profileId: profileId,
      accountId: accountId,
      amount: Money.fromMinorUnits(500, 'JPY'),
      note: 'Original note',
      occurredAtUtc: DateTime.utc(2026, 1, 1),
    );

    await _waitForNullable<Transaction?>(
      container,
      transactionByIdProvider(txId),
      (Transaction? tx) => tx?.note == 'Original note',
    );

    await transactionRepo.updateExpense(
      id: txId,
      accountId: accountId,
      amount: Money.fromMinorUnits(500, 'JPY'),
      note: 'Edited note',
      occurredAtUtc: DateTime.utc(2026, 1, 1),
    );
    await _waitForNullable<Transaction?>(
      container,
      transactionByIdProvider(txId),
      (Transaction? tx) => tx?.note == 'Edited note',
    );

    await transactionRepo.softDelete(txId);
    final Transaction? afterDelete = await _waitForNullable<Transaction?>(
      container,
      transactionByIdProvider(txId),
      (Transaction? tx) => tx == null,
    );
    expect(afterDelete, isNull);
  });
}
