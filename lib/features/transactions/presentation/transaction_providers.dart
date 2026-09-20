import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/providers.dart';
import '../../../core/finance/ledger_models.dart';
import '../../onboarding/presentation/profile_providers.dart';

/// The full transaction ledger for the current profile, mapped to
/// [LedgerTransaction] — the shape [FinanceEngine] consumes. This is what
/// every balance/total computation across the app watches; there is
/// deliberately no separate "cached balance" provider anywhere, per
/// `docs/03_DATABASE_SCHEMA.md`'s derived-balance rule.
final StreamProvider<List<LedgerTransaction>> ledgerProvider =
    StreamProvider<List<LedgerTransaction>>((ref) async* {
  final ProfileRow? profile = await ref.watch(activeProfileProvider.future);
  if (profile == null) {
    yield const <LedgerTransaction>[];
    return;
  }
  yield* ref.watch(transactionRepositoryProvider).watchLedgerForProfile(profile.id);
});

/// Active (non-deleted) transactions as raw rows, newest first — what the
/// Activity screen displays directly (it wants `note`, raw `type`, etc.,
/// not the finance-engine-shaped view).
final StreamProvider<List<Transaction>> activeTransactionsProvider =
    StreamProvider<List<Transaction>>((ref) async* {
  final ProfileRow? profile = await ref.watch(activeProfileProvider.future);
  if (profile == null) {
    yield const <Transaction>[];
    return;
  }
  yield* ref.watch(transactionRepositoryProvider).watchActiveForProfile(profile.id);
});

/// One transaction by id, reactively -- `null` once it's soft-deleted or
/// if it never existed, the same "unavailable below the UI layer"
/// convention `goalSummaryProvider` uses for goals. What the transaction
/// detail and edit screens watch.
final AutoDisposeStreamProviderFamily<Transaction?, String> transactionByIdProvider =
    StreamProvider.autoDispose.family<Transaction?, String>((ref, id) {
  return ref.watch(transactionRepositoryProvider).watchById(id);
});

/// Recent activity for one account -- V1 Accounts Detail + Edit
/// Checkpoint. Active (non-deleted) transactions where the account is
/// either the source (every type) or, for a transfer, the destination --
/// `TransactionRepository.watchActiveForAccount` already implements this
/// filter (pre-existing, unused before this checkpoint), so this is a
/// thin provider wrapper, not new repository logic. Newest first, same
/// as [activeTransactionsProvider].
final AutoDisposeStreamProviderFamily<List<Transaction>, String> accountRecentActivityProvider =
    StreamProvider.autoDispose.family<List<Transaction>, String>((ref, accountId) {
  return ref.watch(transactionRepositoryProvider).watchActiveForAccount(accountId);
});
