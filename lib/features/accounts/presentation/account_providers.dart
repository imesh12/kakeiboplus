import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/providers.dart';
import '../../../core/database/repositories/account_repository.dart' show AccountRowX;
import '../../../core/finance/finance_engine.dart';
import '../../../core/finance/ledger_models.dart';
import '../../../core/money/money.dart';
import '../../onboarding/presentation/profile_providers.dart';
import '../../transactions/presentation/transaction_providers.dart';

/// Active accounts for the current profile, empty before onboarding.
final StreamProvider<List<AccountRow>> accountsProvider = StreamProvider<List<AccountRow>>((
  ref,
) async* {
  final ProfileRow? profile = await ref.watch(activeProfileProvider.future);
  if (profile == null) {
    yield const <AccountRow>[];
    return;
  }
  yield* ref.watch(accountRepositoryProvider).watchActiveForProfile(profile.id);
});

/// Every account for the current profile regardless of active/closed
/// state -- Account Lifecycle Checkpoint. Used only where a closed
/// account must still be resolvable for display: the Accounts screen's
/// "closed accounts" section, and account-name lookups for historical
/// transactions (Activity, Transaction Detail). Never used to populate
/// an account-selector for a NEW transaction/transfer/recurring rule --
/// [accountsProvider] (active-only) remains the only source for that.
final StreamProvider<List<AccountRow>> allAccountsProvider = StreamProvider<List<AccountRow>>((
  ref,
) async* {
  final ProfileRow? profile = await ref.watch(activeProfileProvider.future);
  if (profile == null) {
    yield const <AccountRow>[];
    return;
  }
  yield* ref.watch(accountRepositoryProvider).watchAllForProfile(profile.id);
});

/// Reactively resolves one account by id, or `null` only if it never
/// existed at all -- V1 Account Detail/Edit Checkpoint, the same
/// "unavailable below the UI layer" convention
/// `transactionByIdProvider`/`goalSummaryProvider` already use for THEIR
/// ids. What `AccountDetailScreen`/`EditAccountScreen` watch.
///
/// Account Lifecycle Checkpoint: this no longer resolves to `null` for a
/// closed account -- see `AccountRepository.watchById`'s own doc for why
/// (a closed account must still be resolvable, so its closed state,
/// still-correct balance/history, and Reactivate action can be shown).
/// Only a stale/missing id resolves to `null` now.
final AutoDisposeStreamProviderFamily<AccountRow?, String> accountByIdProvider =
    StreamProvider.autoDispose.family<AccountRow?, String>((ref, accountId) {
  return ref.watch(accountRepositoryProvider).watchById(accountId);
});

/// The derived balance of one account, keyed by the [AccountRow] itself
/// -- see `FinanceEngine.accountBalance` for why this is always
/// computed, never read from a stored column. `.family` is keyed by the
/// row (not just its id) because every current call site
/// (`HomeScreen._AccountTile`, `AccountsScreen`, `AccountDetailScreen`'s
/// body) already holds the resolved [AccountRow] before it ever needs a
/// balance -- so this provider has no reason to re-resolve the account
/// from the database itself. [AccountRow] is Drift-generated
/// `DataClass`, so it already has value-based `==`/`hashCode`; two
/// widgets watching the same account (same field values) still share
/// one cached computation exactly as the previous id-keyed family did.
///
/// Account Lifecycle Checkpoint follow-up (repairing a Home-screen
/// regression this checkpoint introduced): an earlier version of this
/// provider took only the `accountId` and re-resolved the account via
/// [accountByIdProvider] internally, so it could show a closed
/// account's balance correctly even though [accountsProvider] alone
/// (active-only) couldn't have resolved one. That watch opened a
/// *second*, separate per-account Drift stream underneath every
/// consumer -- including `HomeScreen`, which only ever iterates
/// [accountsProvider]'s already-resolved active rows and never needed
/// closed-account resolution at all. That extra `StreamProvider.
/// autoDispose.family` stream is what caused
/// `test/widget/home_screen_test.dart`'s "CP5.1" test to fail
/// deterministically with a pending zero-duration Drift
/// `StreamQueryStore.markAsClosed` timer during `autoDispose` teardown
/// (see that test file's own note, and this repair's report, for the
/// full evidence trail). Taking the [AccountRow] directly removes that
/// redundant stream for every caller, not just Home: `AccountsScreen`
/// and `AccountDetailScreen`'s body already had the row in hand too.
/// Closed-account balances remain correct -- `AccountDetailScreen`
/// still resolves a closed account via its own, single
/// [accountByIdProvider] watch (for the header/isClosed/Reactivate
/// wiring) and passes that same resolved row down to the body, which
/// this provider then just uses; nothing about *what* balance is shown
/// for a closed account changes, only *how many* Drift streams it took
/// to get there.
final AutoDisposeProviderFamily<AsyncValue<Money>, AccountRow> accountBalanceProvider =
    Provider.autoDispose.family<AsyncValue<Money>, AccountRow>((ref, account) {
  final AsyncValue<List<LedgerTransaction>> ledgerAsync = ref.watch(ledgerProvider);

  if (ledgerAsync.isLoading) {
    return const AsyncValue<Money>.loading();
  }
  if (ledgerAsync.hasError) {
    return AsyncValue<Money>.error(ledgerAsync.error!, ledgerAsync.stackTrace!);
  }

  final Money balance = FinanceEngine.accountBalance(
    account.toLedgerAccount(),
    ledgerAsync.requireValue,
  );
  return AsyncValue<Money>.data(balance);
});
