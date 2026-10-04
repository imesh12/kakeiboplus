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

/// Checkpoint J: the active `DepositDetails` row for one deposit
/// account, reactively -- `null` once none exists (not a deposit-
/// subtype account, or its details were somehow soft-deleted) or while
/// still loading/erroring is collapsed to `null` too, matching this
/// file's own `monthlyBudgetSummaryProvider`-style "momentary loading
/// collapses to the empty/absent state" convention rather than
/// exposing a separate loading flicker for what is, in practice, an
/// instantly-resolving local Drift query. Autodispose + family, the
/// same convention [accountByIdProvider] already established: only
/// `AccountDetailScreen`'s deposit-specific card watches this, for one
/// specific account, so there is no reason for this stream to outlive
/// that screen.
final AutoDisposeProviderFamily<DepositDetailsRow?, String> depositDetailsForAccountProvider =
    Provider.autoDispose.family<DepositDetailsRow?, String>((ref, accountId) {
  final AsyncValue<DepositDetailsRow?> detailsAsync = ref.watch(
    _depositDetailsStreamProvider(accountId),
  );
  return detailsAsync.valueOrNull;
});

final AutoDisposeStreamProviderFamily<DepositDetailsRow?, String> _depositDetailsStreamProvider =
    StreamProvider.autoDispose.family<DepositDetailsRow?, String>((ref, accountId) {
  return ref.watch(depositRepositoryProvider).watchForAccount(accountId);
});

/// Checkpoint O: the active `CreditFacilityDetails` row for one
/// credit-card account, reactively -- `null` once none exists (not a
/// creditCard-subtype account, or, defensively, one somehow created
/// without a facility -- unreachable through today's Add Account UX,
/// which always composes both atomically) or while still loading/
/// erroring is collapsed to `null` too, exactly
/// [depositDetailsForAccountProvider]'s own established convention and
/// rationale (a momentary loading flicker for what is, in practice, an
/// instantly-resolving local Drift query). Autodispose + family, same
/// reason: only `AccountDetailScreen`'s credit-facility-specific
/// section and `EditAccountScreen`'s credit-limit field watch this, for
/// one specific account, so neither stream needs to outlive its own
/// screen.
final AutoDisposeProviderFamily<CreditFacilityDetailsRow?, String> creditFacilityForAccountProvider =
    Provider.autoDispose.family<CreditFacilityDetailsRow?, String>((ref, accountId) {
  final AsyncValue<CreditFacilityDetailsRow?> facilityAsync = ref.watch(
    _creditFacilityStreamProvider(accountId),
  );
  return facilityAsync.valueOrNull;
});

final AutoDisposeStreamProviderFamily<CreditFacilityDetailsRow?, String> _creditFacilityStreamProvider =
    StreamProvider.autoDispose.family<CreditFacilityDetailsRow?, String>((ref, accountId) {
  return ref.watch(creditFacilityRepositoryProvider).watchForAccount(accountId);
});

/// Recurring UI Foundation Audit (Checkpoint 3): active (non-archived)
/// payment instruments linked to one account, reactively -- a thin
/// wrapper over [PaymentInstrumentRepository.watchActiveForAccount]
/// (already oldest-created-first), added so a reactive "which card
/// pays from this account" display (the redesigned Recurring row's
/// account segment, and any other list/detail screen that wants the
/// same thing) has one shared, tested provider to watch rather than
/// each screen opening its own ad-hoc stream. Collapses loading/error
/// to an empty list, matching [depositDetailsForAccountProvider]/
/// [creditFacilityForAccountProvider]'s own "momentary loading is not
/// worth a separate flicker state" convention on this same file.
/// Never fabricates an instrument -- an account with none simply
/// yields an empty list, exactly what [watchActiveForAccount] itself
/// returns.
final AutoDisposeProviderFamily<List<PaymentInstrumentRow>, String>
    paymentInstrumentsForAccountProvider =
    Provider.autoDispose.family<List<PaymentInstrumentRow>, String>((ref, accountId) {
  final AsyncValue<List<PaymentInstrumentRow>> instrumentsAsync = ref.watch(
    _paymentInstrumentsStreamProvider(accountId),
  );
  return instrumentsAsync.valueOrNull ?? const <PaymentInstrumentRow>[];
});

final AutoDisposeStreamProviderFamily<List<PaymentInstrumentRow>, String>
    _paymentInstrumentsStreamProvider =
    StreamProvider.autoDispose.family<List<PaymentInstrumentRow>, String>((ref, accountId) {
  return ref.watch(paymentInstrumentRepositoryProvider).watchActiveForAccount(accountId);
});

/// The single payment instrument a display surface should show for one
/// account, given [paymentInstrumentsForAccountProvider]'s list for
/// that account -- the oldest still-active instrument, matching
/// [PaymentInstrumentRepository.watchActiveForAccount]'s own
/// oldest-first ordering (see that method's own doc: "what a future
/// 'choose a card' picker would watch"). `null` for an account with
/// no active instrument at all -- an account need not have one (e.g.
/// a plain cash/bank account never gets a card), and this never
/// invents one. Pure and directly unit-testable without a
/// [ProviderContainer], the same precedent every other selector in
/// this codebase (e.g. `recurring_providers.dart`'s
/// `selectHomeRecurringItem`) already establishes -- added so a
/// presentation layer never has to decide for itself which
/// instrument is canonical when an account happens to have more than
/// one.
PaymentInstrumentRow? firstActivePaymentInstrumentFor(List<PaymentInstrumentRow> instruments) {
  return instruments.isEmpty ? null : instruments.first;
}

/// Every active financial institution for the current profile --
/// Checkpoint L. `FinancialInstitutionRepository` has no
/// single-institution `watchById` (it was only ever built to list a
/// profile's institutions for Add Account's dedup, see that
/// repository's own doc) -- `AccountDetailScreen`'s new Institution row
/// resolves one account's `institutionId` against this list itself,
/// mirroring `_RecentActivitySection`'s existing "watch the list, look
/// up the id locally" pattern for account names rather than adding a
/// new single-row repository method for one read-only display field.
final StreamProvider<List<FinancialInstitutionRow>> activeInstitutionsProvider =
    StreamProvider<List<FinancialInstitutionRow>>((ref) async* {
  final ProfileRow? profile = await ref.watch(activeProfileProvider.future);
  if (profile == null) {
    yield const <FinancialInstitutionRow>[];
    return;
  }
  yield* ref.watch(financialInstitutionRepositoryProvider).watchActiveForProfile(profile.id);
});
