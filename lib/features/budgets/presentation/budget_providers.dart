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
import '../domain/budget_month_summary.dart';

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

/// Checkpoint Q (Monthly Budget Progress & Month Navigation): the
/// Budgets screen's single, user-navigable selected month -- distinct
/// from [currentBudgetMonthProvider], which always tracks the real
/// calendar "now" and continues to back the Home dashboard's budget
/// card unchanged (see that provider's own doc comment). Navigating the
/// Budgets screen must never move the dashboard's month, and the
/// dashboard's own passage of time must never move the Budgets screen
/// out from under a user who has navigated away from the current month
/// -- two genuinely different concepts that happen to share the same
/// starting value.
///
/// A [StateProvider] rather than a plain [Provider]: unlike
/// [currentBudgetMonthProvider] (recomputed from the clock on every
/// rebuild), this value must persist exactly as the user last set it
/// until they navigate again -- there is nothing to "recompute" here at
/// all. Initialized once, at first read, to the calendar month
/// containing `DateTime.now().toUtc()` -- the same convention every
/// other month-boundary provider in this app uses.
///
/// The Budgets screen (`budgets_screen.dart`) is the only reader of
/// this provider and everything derived from it below; nothing outside
/// the budgets feature depends on it.
final StateProvider<BudgetMonth> selectedBudgetMonthProvider = StateProvider<BudgetMonth>((ref) {
  return BudgetMonth.fromUtc(DateTime.now().toUtc());
});

/// All active budgets (overall + category, every currency) for
/// [selectedBudgetMonthProvider]'s month -- the navigable counterpart of
/// [currentMonthBudgetsProvider], which the Budgets screen now reads
/// instead. [currentMonthBudgetsProvider] itself is left completely
/// unchanged and unused by the screen from this checkpoint forward, so
/// nothing else that might depend on "the real current month's budgets"
/// (there is no other reader today, but none is invented here either)
/// is affected.
final StreamProvider<List<BudgetRow>> budgetsForSelectedMonthProvider =
    StreamProvider<List<BudgetRow>>((ref) async* {
  final ProfileRow? profile = await ref.watch(activeProfileProvider.future);
  if (profile == null) {
    yield const <BudgetRow>[];
    return;
  }
  final BudgetMonth month = ref.watch(selectedBudgetMonthProvider);
  yield* ref
      .watch(budgetRepositoryProvider)
      .watchActiveForMonth(profileId: profile.id, month: month);
});

/// One [BudgetMonthSummary] per currency that has at least one active
/// category budget for [selectedBudgetMonthProvider]'s month --
/// Checkpoint Q's Month Summary / Category Budget Progress data source.
/// Deliberately excludes the overall budget entirely (see
/// [BudgetMonthSummary]'s own doc and `docs/14_DECISION_LOG.md`
/// ADR-021 point 6/13 plus the new ADR this checkpoint adds) -- summing
/// it in would double-count capacity that was never meant to stack with
/// category budgets.
///
/// Follows the exact same "watch profile + ledger, branch on
/// loading/error, compute once both are ready" shape
/// [livingCurrencyOverallBudgetProvider] already established -- the only
/// difference is this evaluates every active category budget for the
/// month (grouped by currency) instead of a single living-currency
/// overall budget.
final Provider<AsyncValue<List<BudgetMonthSummary>>> budgetMonthSummariesProvider =
    Provider<AsyncValue<List<BudgetMonthSummary>>>((ref) {
  final AsyncValue<ProfileRow?> profileAsync = ref.watch(activeProfileProvider);
  final AsyncValue<List<LedgerTransaction>> ledgerAsync = ref.watch(ledgerProvider);
  final AsyncValue<List<BudgetRow>> budgetsAsync = ref.watch(budgetsForSelectedMonthProvider);
  final BudgetMonth month = ref.watch(selectedBudgetMonthProvider);

  if (profileAsync.isLoading || ledgerAsync.isLoading || budgetsAsync.isLoading) {
    return const AsyncValue<List<BudgetMonthSummary>>.loading();
  }
  if (profileAsync.hasError) {
    return AsyncValue<List<BudgetMonthSummary>>.error(
      profileAsync.error!,
      profileAsync.stackTrace!,
    );
  }
  if (ledgerAsync.hasError) {
    return AsyncValue<List<BudgetMonthSummary>>.error(ledgerAsync.error!, ledgerAsync.stackTrace!);
  }
  if (budgetsAsync.hasError) {
    return AsyncValue<List<BudgetMonthSummary>>.error(
      budgetsAsync.error!,
      budgetsAsync.stackTrace!,
    );
  }

  final ProfileRow? profile = profileAsync.requireValue;
  if (profile == null) {
    return const AsyncValue<List<BudgetMonthSummary>>.loading(); // pre-onboarding; router keeps this off-screen
  }

  final List<LedgerTransaction> ledger = ledgerAsync.requireValue;

  // Exact-category matching only, per budget row -- no subcategory
  // rollup (ADR-021 point 5, unchanged). Grouped by currency so amounts
  // are never summed across currencies (Section O / ADR-021 point 13).
  final Map<String, List<BudgetRow>> categoryBudgetsByCurrency = <String, List<BudgetRow>>{};
  for (final BudgetRow row in budgetsAsync.requireValue) {
    if (row.categoryId == null) continue; // the separate overall budget -- never included here
    categoryBudgetsByCurrency.putIfAbsent(row.currencyCode, () => <BudgetRow>[]).add(row);
  }

  final DateTime todayUtc = DateTime.now().toUtc();
  final List<BudgetMonthSummary> summaries = <BudgetMonthSummary>[];
  for (final MapEntry<String, List<BudgetRow>> entry in categoryBudgetsByCurrency.entries) {
    final String currencyCode = entry.key;
    Money totalBudget = Money.zero(currencyCode);
    Money totalSpent = Money.zero(currencyCode);
    final List<CategoryBudgetProgress> categoryProgress = <CategoryBudgetProgress>[];

    for (final BudgetRow row in entry.value) {
      final Money budgeted = Money.fromMinorUnits(row.amountMinorUnits, currencyCode);
      // The half-open [month.startUtc, next month) interval is expressed
      // as `[startUtc, endUtcInclusive]` here because `_relevant` (this
      // primitive's internal filter) compares with `isBefore`/`isAfter`,
      // i.e. an INCLUSIVE bound -- `endUtcInclusive` is exactly one
      // microsecond before the next month starts, so this is the same
      // boundary either way expressed as inclusive rather than exclusive.
      // See `budget_month.dart`'s own doc comment and
      // `dashboard_providers.dart`'s established precedent.
      final Money categorySpent = FinanceEngine.categoryExpenseTotal(
        ledger,
        currencyCode: currencyCode,
        categoryId: row.categoryId!,
        fromUtc: month.startUtc,
        toUtc: month.endUtcInclusive,
      );
      final BudgetCalculation calculation = BudgetCalculator.evaluate(
        month: month,
        todayUtc: todayUtc,
        budgeted: budgeted,
        spent: categorySpent,
      );
      categoryProgress.add(
        CategoryBudgetProgress(
          budgetId: row.id,
          categoryId: row.categoryId!,
          calculation: calculation,
        ),
      );
      totalBudget = totalBudget + budgeted;
      totalSpent = totalSpent + categorySpent;
    }

    summaries.add(
      BudgetMonthSummary(
        month: month,
        currencyCode: currencyCode,
        totalBudget: totalBudget,
        spent: totalSpent,
        remaining: totalBudget - totalSpent,
        categoryProgress: categoryProgress,
      ),
    );
  }
  summaries.sort((BudgetMonthSummary a, BudgetMonthSummary b) => a.currencyCode.compareTo(b.currencyCode));
  return AsyncValue<List<BudgetMonthSummary>>.data(summaries);
});
