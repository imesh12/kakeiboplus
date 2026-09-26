import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/providers.dart';
import '../../../core/database/repositories/account_repository.dart' show AccountRowX;
import '../../../core/database/repositories/cheque_book_repository.dart';
import '../../accounts/presentation/account_providers.dart';
import '../../onboarding/presentation/profile_providers.dart';

/// Checkpoint N: every active (non-deleted) cheque for the current
/// profile, reactively -- the Cheques list screen's own data source.
/// Empty (never "loading forever") before onboarding, the same
/// convention [accountsProvider]/`_activeGoalRowsProvider` already use.
final StreamProvider<List<ChequeRow>> activeChequesProvider = StreamProvider<List<ChequeRow>>((
  ref,
) async* {
  final ProfileRow? profile = await ref.watch(activeProfileProvider.future);
  if (profile == null) {
    yield const <ChequeRow>[];
    return;
  }
  yield* ref.watch(chequeRepositoryProvider).watchActiveForProfile(profile.id);
});

/// Every chequebook for the current profile, ACTIVE OR CLOSED,
/// reactively -- the Cheques list screen needs to resolve a closed
/// book's label for a historical issued cheque too, matching
/// `allAccountsProvider`'s identical "closed rows must still resolve for
/// display" rationale.
final StreamProvider<List<ChequeBookRow>> allChequeBooksProvider =
    StreamProvider<List<ChequeBookRow>>((ref) async* {
  final ProfileRow? profile = await ref.watch(activeProfileProvider.future);
  if (profile == null) {
    yield const <ChequeBookRow>[];
    return;
  }
  yield* ref.watch(chequeBookRepositoryProvider).watchAllForProfile(profile.id);
});

/// One cheque's live state, reactively -- `null` if it doesn't exist, or
/// no longer does -- the Cheque Detail screen's own data source, same
/// "unavailable below the UI layer" convention `accountByIdProvider`/
/// `goalSummaryProvider` already use.
final AutoDisposeStreamProviderFamily<ChequeRow?, String> chequeByIdProvider =
    StreamProvider.autoDispose.family<ChequeRow?, String>((ref, chequeId) {
  return ref.watch(chequeRepositoryProvider).watchById(chequeId);
});

/// Active (non-closed) chequebooks for one account, reactively -- the
/// "which chequebook is this from" picker in the Record Issued Cheque
/// dialog.
final AutoDisposeStreamProviderFamily<List<ChequeBookRow>, String> activeChequeBooksForAccountProvider =
    StreamProvider.autoDispose.family<List<ChequeBookRow>, String>((ref, accountId) {
  return ref.watch(chequeBookRepositoryProvider).watchActiveForAccount(accountId);
});

/// Active accounts eligible to carry a chequebook / receive a cheque
/// (`balanceClass: asset`, `subtype` in [chequeEligibleAccountSubtypes])
/// for the current profile -- the account picker shared by both the
/// Record Issued Cheque and Record Received Cheque dialogs, and the
/// Create Chequebook dialog. Derived from [accountsProvider] (already
/// active-only) rather than a fresh query, so this list can never
/// disagree with the ordinary Accounts screen about which accounts are
/// active.
final Provider<AsyncValue<List<AccountRow>>> chequeEligibleAccountsProvider =
    Provider<AsyncValue<List<AccountRow>>>((ref) {
  return ref.watch(accountsProvider).whenData(
        (accounts) => accounts
            .where(
              (account) =>
                  account.isAsset && chequeEligibleAccountSubtypes.contains(account.subtypeValue),
            )
            .toList(growable: false),
      );
});
