import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/finance/finance_engine.dart';
import '../../../core/finance/ledger_models.dart';
import '../../onboarding/presentation/profile_providers.dart';
import '../../transactions/presentation/transaction_providers.dart';

/// Income/expense totals for the current calendar month, in the current
/// profile's living currency — what the Home dashboard shows. Beta 0
/// deliberately scopes to a single month and a single currency (the
/// living currency) rather than a general date-range/currency query;
/// see `FinanceEngine.incomeExpenseTotals` for the general primitive this
/// builds on, which a future Beta 1 analytics screen can call with
/// different bounds.
final Provider<AsyncValue<MoneyTotals>> currentMonthTotalsProvider =
    Provider<AsyncValue<MoneyTotals>>((ref) {
  final AsyncValue<ProfileRow?> profileAsync = ref.watch(activeProfileProvider);
  final AsyncValue<List<LedgerTransaction>> ledgerAsync = ref.watch(ledgerProvider);

  if (profileAsync.isLoading || ledgerAsync.isLoading) {
    return const AsyncValue<MoneyTotals>.loading();
  }
  if (profileAsync.hasError) {
    return AsyncValue<MoneyTotals>.error(profileAsync.error!, profileAsync.stackTrace!);
  }
  if (ledgerAsync.hasError) {
    return AsyncValue<MoneyTotals>.error(ledgerAsync.error!, ledgerAsync.stackTrace!);
  }

  final ProfileRow? profile = profileAsync.requireValue;
  if (profile == null) {
    return const AsyncValue<MoneyTotals>.loading(); // pre-onboarding; router keeps this off-screen
  }

  final DateTime now = DateTime.now().toUtc();
  final DateTime monthStart = DateTime.utc(now.year, now.month);
  final DateTime monthEnd = DateTime.utc(now.year, now.month + 1)
      .subtract(const Duration(microseconds: 1));

  final MoneyTotals totals = FinanceEngine.incomeExpenseTotals(
    ledgerAsync.requireValue,
    currencyCode: profile.livingCurrency,
    fromUtc: monthStart,
    toUtc: monthEnd,
  );
  return AsyncValue<MoneyTotals>.data(totals);
});
