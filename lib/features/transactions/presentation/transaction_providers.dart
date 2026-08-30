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
