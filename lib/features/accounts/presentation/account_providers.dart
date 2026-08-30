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

/// The derived balance of one account, keyed by `accountId` — see
/// `FinanceEngine.accountBalance` for why this is always computed, never
/// read from a stored column. `.family` is used with a plain [String]
/// key (trivially safe under Riverpod's identity-based provider caching,
/// unlike a composite/record key) so widgets watching the same account
/// share one cached computation rather than each triggering their own.
///
/// `AsyncValue` because it depends on two async sources (the account list
/// and the full ledger); a `StateError` inside the `AsyncValue.error`
/// case means `accountId` doesn't exist in the current account list.
final AutoDisposeProviderFamily<AsyncValue<Money>, String> accountBalanceProvider =
    Provider.autoDispose.family<AsyncValue<Money>, String>((ref, accountId) {
  final AsyncValue<List<AccountRow>> accountsAsync = ref.watch(accountsProvider);
  final AsyncValue<List<LedgerTransaction>> ledgerAsync = ref.watch(ledgerProvider);

  if (accountsAsync.isLoading || ledgerAsync.isLoading) {
    return const AsyncValue<Money>.loading();
  }
  if (accountsAsync.hasError) {
    return AsyncValue<Money>.error(accountsAsync.error!, accountsAsync.stackTrace!);
  }
  if (ledgerAsync.hasError) {
    return AsyncValue<Money>.error(ledgerAsync.error!, ledgerAsync.stackTrace!);
  }

  AccountRow? account;
  for (final AccountRow candidate in accountsAsync.requireValue) {
    if (candidate.id == accountId) {
      account = candidate;
      break;
    }
  }
  if (account == null) {
    return AsyncValue<Money>.error(
      StateError('Unknown account: $accountId'),
      StackTrace.current,
    );
  }

  final Money balance = FinanceEngine.accountBalance(
    account.toLedgerAccount(),
    ledgerAsync.requireValue,
  );
  return AsyncValue<Money>.data(balance);
});
