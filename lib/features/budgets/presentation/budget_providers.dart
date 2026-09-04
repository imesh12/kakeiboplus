import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/providers.dart';
import '../../../core/finance/finance_engine.dart';
import '../../../core/finance/ledger_models.dart';
import '../../../core/money/money.dart';
import '../../onboarding/presentation/profile_providers.dart';
import '../../transactions/presentation/transaction_providers.dart';
import '../domain/budget_calculation.dart';
import '../domain/budget_month.dart';

/// The calendar month "now" belongs to, in UTC -- the same convention
/// every other month-boundary calculation in the app uses (see
/// `lib/features/dashboard/presentation/dashboard_providers.dart`). A
/// plain `Provider`, re-evaluated whenever a listener rebuilds; like the
/// rest of Beta 0/1, "now" is read once per rebuild rather than
/// continuously ticked by a timer.
final Provider<BudgetMonth> currentBudgetMonthProvider = Provider<BudgetMonth>((ref) {
  return BudgetMonth.fromUtc(DateTime.now().toUtc());
});

/// All active budgets (the overall budget plus any category budgets,
/// across every currency the profile has configured) for the current
/// profile and [currentBudgetMonthProvider]'s month -- what the budget
/// management screen lists.
final StreamProvider<List<BudgetRow>> currentMonthBudgetsProvider =
    StreamProvider<List<BudgetRow>>((ref) async* {
  final ProfileRow? profile = await ref.watch(activeProfileProvider.future);
  if (profile == null) {
    yield const <BudgetRow>[];
    return;
  }
  final BudgetMonth month = ref.watch(currentBudgetMonthProvider);
  yield* ref
      .watch(budgetRepositoryProvider)
      .watchActiveForMonth(profileId: profile.id, month: month);
});

/// The raw active overall-budget row for one currency/month, reactively.
/// Internal plumbing for [livingCurrencyOverallBudgetProvider] --
/// `.family` keyed by a `(currencyCode, month)` record so it can be
/// watched for whichever currency the profile is currently living in
/// without hard-coding that currency into the provider itself.
final AutoDisposeStreamProviderFamily<BudgetRow?, ({String currencyCode, BudgetMonth month})>
    _overallBudgetRowProvider = StreamProvider.autoDispose
        .family<BudgetRow?, ({String currencyCode, BudgetMonth month})>((ref, params) async* {
  final ProfileRow? profile = await ref.watch(activeProfileProvider.future);
  if (profile == null) {
    yield null;
    return;
  }
  yield* ref.watch(budgetRepositoryProvider).watchActiveOverallBudget(
        profileId: profile.id,
        currencyCode: params.currencyCode,
        month: params.month,
      );
});

/// The evaluated overall budget for the profile's **living currency**,
/// for the current month -- `null` means "not configured" (an honest
/// empty state; never a fabricated zero budget). This is the single
/// provider the Home dashboard's budget card reads. A budget configured
/// in a different currency never appears here -- a budget belongs to
/// exactly one currency, and Beta 1 does no FX conversion (see
/// `docs/14_DECISION_LOG.md` ADR-021).
final Provider<AsyncValue<BudgetCalculation?>> livingCurrencyOverallBudgetProvider =
    Provider<AsyncValue<BudgetCalculation?>>((ref) {
  final AsyncValue<ProfileRow?> profileAsync = ref.watch(activeProfileProvider);
  final AsyncValue<List<LedgerTransaction>> ledgerAsync = ref.watch(ledgerProvider);
  final BudgetMonth month = ref.watch(currentBudgetMonthProvider);

  if (profileAsync.isLoading || ledgerAsync.isLoading) {
    return const AsyncValue<BudgetCalculation?>.loading();
  }
  if (profileAsync.hasError) {
    return AsyncValue<BudgetCalculation?>.error(profileAsync.error!, profileAsync.stackTrace!);
  }
  if (ledgerAsync.hasError) {
    return AsyncValue<BudgetCalculation?>.error(ledgerAsync.error!, ledgerAsync.stackTrace!);
  }

  final ProfileRow? profile = profileAsync.requireValue;
  if (profile == null) {
    return const AsyncValue<BudgetCalculation?>.loading(); // pre-onboarding; router keeps this off-screen
  }

  final AsyncValue<BudgetRow?> budgetRowAsync = ref.watch(
    _overallBudgetRowProvider((currencyCode: profile.livingCurrency, month: month)),
  );
  if (budgetRowAsync.isLoading) {
    return const AsyncValue<BudgetCalculation?>.loading();
  }
  if (budgetRowAsync.hasError) {
    return AsyncValue<BudgetCalculation?>.error(budgetRowAsync.error!, budgetRowAsync.stackTrace!);
  }

  final BudgetRow? budgetRow = budgetRowAsync.requireValue;
  if (budgetRow == null) {
    return const AsyncValue<BudgetCalculation?>.data(null);
  }

  final Money spent = FinanceEngine.incomeExpenseTotals(
    ledgerAsync.requireValue,
    currencyCode: profile.livingCurrency,
    fromUtc: month.startUtc,
    toUtc: month.endUtcInclusive,
  ).expense;

  final BudgetCalculation calculation = BudgetCalculator.evaluate(
    month: month,
    todayUtc: DateTime.now().toUtc(),
    budgeted: Money.fromMinorUnits(budgetRow.amountMinorUnits, budgetRow.currencyCode),
    spent: spent,
  );
  return AsyncValue<BudgetCalculation?>.data(calculation);
});
