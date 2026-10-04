import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/repositories/account_repository.dart';
import '../../../core/finance/finance_engine.dart';
import '../../../core/finance/financial_account_subtype.dart';
import '../../../core/finance/ledger_models.dart';
import '../../../core/money/money.dart';
import '../../accounts/presentation/account_providers.dart';
import '../../categories/presentation/category_providers.dart';
import '../../budgets/domain/budget_calculation.dart';
import '../../budgets/presentation/budget_providers.dart';
import '../../onboarding/presentation/profile_providers.dart';
import '../../transactions/presentation/transaction_providers.dart';

/// One currency's worth of the Home dashboard: balance, this month's
/// income/expense, and this month's daily spending pace, all in the same
/// [currencyCode] and all derived from [FinanceEngine] — this class only
/// packages that output for the UI, it never computes anything itself.
///
/// See [dashboardCurrencySummariesProvider] for why the dashboard is a
/// *list* of these (one per currency the user actually holds money in)
/// rather than a single summary: Beta 0/1 has no FX conversion layer, so
/// there is no correct single number to add JPY and USD balances into.
@immutable
class CurrencyDashboardSummary {
  const CurrencyDashboardSummary({
    required this.currencyCode,
    required this.availableBalance,
    required this.netWorth,
    required this.income,
    required this.expense,
    required this.dailyPace,
  });

  final String currencyCode;

  /// Checkpoint I (docs/20 §13.4 checkpoint I): immediately available/
  /// liquid money in this currency — the sum of `FinanceEngine.
  /// accountBalance` over every ACTIVE (`AccountRow.isActive`), ASSET
  /// (`AccountRowX.isAsset`), NON-DEPOSIT (`subtypeValue !=
  /// FinancialAccountSubtype.deposit`) account. Deliberately excludes:
  /// a deposit's principal (locked, not currently spendable — docs/20
  /// §5's "vault/lock icon, reinforcing that the money is not currently
  /// spendable"); every liability account (a credit card's owed balance
  /// is debt, never available cash, and its available *credit* is a
  /// borrowing capacity, not money already owned); and a closed
  /// account's balance (Account Lifecycle: a closed account cannot be
  /// selected for a new transaction, so its balance is not usable
  /// today even though it is still owned — see [netWorth]).
  ///
  /// This is the dashboard's primary, most prominent figure — "how much
  /// can I actually spend right now."
  final Money availableBalance;

  /// Checkpoint I: net worth in this currency, matching this
  /// document's frozen §4 definition ("Net worth = Assets −
  /// Liabilities"): every account in this currency, active OR closed —
  /// an asset's `accountBalance` added, a liability's `accountBalance`
  /// (`FinanceEngine`'s non-negative "amount owed" magnitude, see that
  /// class's own doc) subtracted. Includes deposit principal (still an
  /// owned asset, just not liquid — see [availableBalance]) and a
  /// closed account's balance (Account Lifecycle Checkpoint's
  /// conservative policy: closing an account must not silently destroy
  /// financial value or history — money owned, or owed, does not
  /// disappear merely because an account became inactive; only its
  /// *selectability* for new transactions changes). This is a total
  /// *position*, never itself presented as spendable cash.
  final Money netWorth;

  /// This calendar month's income in this currency, transfers excluded.
  final Money income;

  /// This calendar month's spending in this currency, transfers
  /// excluded.
  final Money expense;

  /// This calendar month's deterministic daily spending pace in this
  /// currency — see `FinanceEngine.dailySpendingPace` for the exact
  /// definition (period, today-inclusion, zero handling, rounding).
  final Money dailyPace;

  /// Checkpoint U3 (docs/23_DASHBOARD_HEADER_BRAND_SPEC.md §5.2): "how
  /// much of this month's money is left" -- `income - expense`, both
  /// already this calendar month's deterministic, transfer-excluded
  /// totals (see [income]/[expense] above, both produced by the SAME
  /// `FinanceEngine.incomeExpenseTotals` call this class has always
  /// used). This is purely a composition of two already-authoritative,
  /// already-tested figures -- it introduces no new financial
  /// calculation of its own, and [Money.operator-] throws on a
  /// currency mismatch exactly like [Money.operator+] does, but
  /// [income] and [expense] are always the same [currencyCode] by
  /// construction (see `_summaryForCurrency`), so that can never
  /// actually happen here.
  ///
  /// Deliberately NOT [netWorth] or [availableBalance] -- docs/23 §5.1
  /// is explicit that the Dashboard hero must never expose Net Worth or
  /// a disguised equivalent, and this is a distinct, narrower monthly
  /// figure from the liquid balance [availableBalance] already
  /// represents.
  Money get remainingThisMonth => income - expense;
}

/// The "Remaining monthly budget" dashboard tile's data -- a thin
/// wrapper around [BudgetCalculation] (the budgets feature's domain
/// result type) so `HomeScreen` can keep reading a small, dashboard-
/// shaped type without needing to know about the budgets feature's
/// full domain layer.
///
/// `null` [calculation] means "no budget configured for this month" —
/// the dashboard must show an explicit "set a budget" empty state
/// rather than inventing a number (see the Beta 1 Task 1 spec's ban on
/// fake financial values). Once Beta 1 Task 2's budgets feature finds an
/// active *overall* budget in the profile's **living currency** for the
/// current month, [calculation] wraps the real, [FinanceEngine]-derived
/// result -- a budget configured in a different currency never appears
/// here (see `docs/14_DECISION_LOG.md` ADR-021).
@immutable
class MonthlyBudgetSummary {
  const MonthlyBudgetSummary(this.calculation);

  const MonthlyBudgetSummary.notConfigured() : calculation = null;

  final BudgetCalculation? calculation;

  /// Convenience accessor for the one field every caller (including
  /// pre-Task-2 tests written against the original "remaining-only"
  /// shape) needs most often.
  Money? get remaining => calculation?.remaining;
}



/// The Home dashboard's overall-budget tile, for the profile's living
/// currency and the current month — see
/// [livingCurrencyOverallBudgetProvider] for where the actual budget
/// lookup and [FinanceEngine] calculation happen; this provider only
/// adapts that result into the small [MonthlyBudgetSummary] shape
/// `HomeScreen` reads.
///
/// A plain (non-autoDispose, synchronous) `Provider`, matching every
/// other dashboard provider here and preserving `_RemainingBudgetTile`'s
/// existing synchronous read contract (U3 Final Polish Pass, item 2:
/// the former second reader, `_BudgetCard`, was removed along with the
/// Home Budget detail card it belonged to; this provider's own contract
/// is otherwise unaffected): `.valueOrNull` collapses a momentary
/// loading state to "not configured" rather than exposing a separate
/// loading state to the tile. This is an intentional, documented
/// simplification — the rest of the dashboard does not show a
/// budget-tile-specific loading spinner either, and a `null` here is
/// self-correcting the moment the underlying stream resolves.
final Provider<MonthlyBudgetSummary> monthlyBudgetSummaryProvider =
    Provider<MonthlyBudgetSummary>((ref) {
  final AsyncValue<BudgetCalculation?> budgetAsync = ref.watch(livingCurrencyOverallBudgetProvider);
  return MonthlyBudgetSummary(budgetAsync.valueOrNull);
});

/// The Home dashboard's core financial summary: one
/// [CurrencyDashboardSummary] per currency the profile holds money in —
/// including a currency whose only account(s) are now closed (Account
/// Lifecycle Checkpoint's conservative policy: closing an account must
/// not make its currency, or its financial history, silently vanish
/// from the dashboard) — ordered with the profile's living currency
/// first, then its home currency (if different), then any others
/// alphabetically — purely a display ordering choice, not a financial
/// calculation.
///
/// **Why a list instead of one number:** Beta 0/1 has no FX conversion
/// layer (`lib/features/fx/README.md` — that's Beta 2), and
/// `Money.operator+` throws on a currency mismatch by design (ADR-017).
/// Silently adding, say, a JPY balance and a USD balance would either
/// crash or (worse, if someone "fixed" the crash wrong) produce a
/// meaningless combined number presented as real money. Grouping by
/// currency is the only representation available today that is both
/// always computable and never wrong. For the common case of a user with
/// accounts in a single currency, this list simply has one entry and the
/// dashboard reads exactly like a single-currency summary.
///
/// Returns `AsyncValue.loading()` before the profile exists (mirrors the
/// pre-Beta-1 `currentMonthTotalsProvider` this replaces — the router
/// keeps `HomeScreen` off-screen until then anyway) and
/// `AsyncValue.data(<CurrencyDashboardSummary>[])` once there's a
/// profile but zero accounts (active or closed) ever existed, which the
/// UI renders as its own empty state rather than a spinner.
///
/// Checkpoint I (docs/20 §13.4 checkpoint I): reads [allAccountsProvider]
/// (active + closed), not [accountsProvider] (active-only) — every
/// account this profile has ever owned contributes to [_summaryForCurrency],
/// which is what lets [CurrencyDashboardSummary.netWorth] correctly
/// preserve a closed account's balance while
/// [CurrencyDashboardSummary.availableBalance] still correctly excludes
/// it (see that field's own doc). `HomeScreen`'s separate "Accounts"
/// list section is unaffected — it still reads [accountsProvider]
/// directly and unchanged, since that section's own job (what can I add
/// a transaction to today) is intentionally active-only.
final Provider<AsyncValue<List<CurrencyDashboardSummary>>> dashboardCurrencySummariesProvider =
    Provider<AsyncValue<List<CurrencyDashboardSummary>>>((ref) {
  final AsyncValue<ProfileRow?> profileAsync = ref.watch(activeProfileProvider);
  final AsyncValue<List<AccountRow>> accountsAsync = ref.watch(allAccountsProvider);
  final AsyncValue<List<LedgerTransaction>> ledgerAsync = ref.watch(ledgerProvider);

  if (profileAsync.isLoading || accountsAsync.isLoading || ledgerAsync.isLoading) {
    return const AsyncValue<List<CurrencyDashboardSummary>>.loading();
  }
  if (profileAsync.hasError) {
    return AsyncValue<List<CurrencyDashboardSummary>>.error(
      profileAsync.error!,
      profileAsync.stackTrace!,
    );
  }
  if (accountsAsync.hasError) {
    return AsyncValue<List<CurrencyDashboardSummary>>.error(
      accountsAsync.error!,
      accountsAsync.stackTrace!,
    );
  }
  if (ledgerAsync.hasError) {
    return AsyncValue<List<CurrencyDashboardSummary>>.error(
      ledgerAsync.error!,
      ledgerAsync.stackTrace!,
    );
  }

  final ProfileRow? profile = profileAsync.requireValue;
  if (profile == null) {
    return const AsyncValue<List<CurrencyDashboardSummary>>.loading(); // pre-onboarding; router keeps this off-screen
  }

  final List<AccountRow> accounts = accountsAsync.requireValue;
  if (accounts.isEmpty) {
    return const AsyncValue<List<CurrencyDashboardSummary>>.data(<CurrencyDashboardSummary>[]);
  }

  final List<LedgerTransaction> ledger = ledgerAsync.requireValue;

  // Calendar-month bounds and elapsed-day count, in UTC — the same
  // convention `currentMonthTotalsProvider` used in Beta 0, kept as-is
  // here rather than changed as part of this task (occurredAtUtc is
  // stored in UTC; see `ledger_models.dart`'s note on why aggregation
  // must not depend on device timezone at query time).
  final DateTime now = DateTime.now().toUtc();
  final DateTime monthStart = DateTime.utc(now.year, now.month);
  final DateTime monthEnd =
      DateTime.utc(now.year, now.month + 1).subtract(const Duration(microseconds: 1));
  // Today counts as a full elapsed day (see FinanceEngine.dailySpendingPace) --
  // on the 1st this is 1, never 0.
  final int daysElapsedInclusive = now.difference(monthStart).inDays + 1;

  final Set<String> currencyCodes = <String>{for (final AccountRow a in accounts) a.currencyCode};
  final List<String> orderedCurrencyCodes = _orderCurrencies(
    currencyCodes,
    livingCurrency: profile.livingCurrency,
    homeCurrency: profile.homeCurrency,
  );

  final List<CurrencyDashboardSummary> summaries = <CurrencyDashboardSummary>[
    for (final String currencyCode in orderedCurrencyCodes)
      _summaryForCurrency(
        currencyCode,
        accounts: accounts,
        ledger: ledger,
        monthStart: monthStart,
        monthEnd: monthEnd,
        daysElapsedInclusive: daysElapsedInclusive,
      ),
  ];

  return AsyncValue<List<CurrencyDashboardSummary>>.data(summaries);
});

CurrencyDashboardSummary _summaryForCurrency(
  String currencyCode, {
  required List<AccountRow> accounts,
  required List<LedgerTransaction> ledger,
  required DateTime monthStart,
  required DateTime monthEnd,
  required int daysElapsedInclusive,
}) {
  // Checkpoint I (docs/20 §13.4 checkpoint I / §4's frozen "Net worth =
  // Assets − Liabilities"): [accounts] here is every account this
  // profile has ever owned in [currencyCode], active or closed
  // (`allAccountsProvider` — see this provider's own doc). Two
  // independent totals fall out of the SAME loop, over the SAME
  // `FinanceEngine.accountBalance` call per account — never a second,
  // divergent calculation:
  //
  // - `availableBalance`: active + asset + non-deposit accounts only.
  // - `netWorth`: every account, asset added, liability subtracted.
  Money availableBalance = Money.zero(currencyCode);
  Money netWorth = Money.zero(currencyCode);
  for (final AccountRow account in accounts) {
    if (account.currencyCode != currencyCode) continue;
    final Money accountBalance = FinanceEngine.accountBalance(account.toLedgerAccount(), ledger);

    // `accountBalance` is always a non-negative, class-native magnitude
    // (owned for an asset, owed for a liability — see
    // `FinanceEngine.accountBalance`'s own doc) — never itself negative
    // for a liability, so a liability's contribution to net worth is
    // this magnitude SUBTRACTED, not a stored negative number added.
    netWorth = account.isLiability ? netWorth - accountBalance : netWorth + accountBalance;

    final bool isAvailable =
        account.isActive && account.isAsset && account.subtypeValue != FinancialAccountSubtype.deposit;
    if (isAvailable) {
      availableBalance = availableBalance + accountBalance;
    }
  }

  final MoneyTotals totals = FinanceEngine.incomeExpenseTotals(
    ledger,
    currencyCode: currencyCode,
    fromUtc: monthStart,
    toUtc: monthEnd,
  );

  final Money dailyPace = FinanceEngine.dailySpendingPace(
    monthToDateExpense: totals.expense,
    daysElapsedInclusive: daysElapsedInclusive,
  );

  return CurrencyDashboardSummary(
    currencyCode: currencyCode,
    availableBalance: availableBalance,
    netWorth: netWorth,
    income: totals.income,
    expense: totals.expense,
    dailyPace: dailyPace,
  );
}

/// Display order only (never affects any computed amount): living
/// currency first, then home currency if the profile holds accounts in
/// it and it differs from living currency, then every other currency the
/// profile holds accounts in, alphabetically. This surfaces the
/// currency the user transacts in day-to-day first without hiding any
/// other currency's real numbers -- every currency in [currencyCodes]
/// still appears exactly once.
List<String> _orderCurrencies(
  Set<String> currencyCodes, {
  required String livingCurrency,
  required String homeCurrency,
}) {
  final List<String> ordered = <String>[];
  if (currencyCodes.contains(livingCurrency)) {
    ordered.add(livingCurrency);
  }
  if (homeCurrency != livingCurrency && currencyCodes.contains(homeCurrency)) {
    ordered.add(homeCurrency);
  }
  final List<String> rest = currencyCodes.where((String c) => !ordered.contains(c)).toList()
    ..sort();
  ordered.addAll(rest);
  return ordered;
}

/// One category's slice of [homeCategorySpendingProvider]'s "Spending
/// this month" breakdown -- Dashboard V1 Finalization checkpoint.
/// [categoryId] is `null` for uncategorized expense transactions
/// (grouped together, exactly like [FinanceEngine.categoryExpenseTotals]
/// itself groups them); [categoryName]/[colorKey] are then also `null`
/// -- the widget layer supplies the localized "Other"/uncategorized
/// label and a neutral fallback color for that case, never this
/// provider (which stays presentation-agnostic, like every other
/// provider in this file).
@immutable
class HomeCategorySpendingSlice {
  const HomeCategorySpendingSlice({
    required this.categoryId,
    required this.categoryName,
    required this.colorKey,
    required this.amount,
  });

  final String? categoryId;
  final String? categoryName;

  /// Raw `Categories.colorKey` storage value (see
  /// `lib/features/categories/domain/category_color.dart`'s
  /// `CategoryColorKey.fromStorageValue`) -- not yet resolved to a
  /// [Color] here, so this class has no Flutter-widget dependency,
  /// matching every other provider-owned model in this file.
  final String? colorKey;

  /// Always a non-negative expense magnitude -- see
  /// [FinanceEngine.categoryExpenseTotals].
  final Money amount;
}

/// The Home dashboard's "Spending this month" category breakdown, for
/// the profile's living currency and the current calendar month --
/// Dashboard V1 Finalization checkpoint. Reuses
/// [FinanceEngine.categoryExpenseTotals] (the same deterministic,
/// expense-only, transfer-excluded aggregation the budgets feature's
/// per-category "spent" figure is built from) joined with each
/// category's own name/colorKey from [categoriesForTypeProvider] --
/// never a second, independently-derived total. Categories with zero
/// expense this month are dropped; the result is sorted by amount,
/// largest first, purely a display ordering choice.
///
/// Returns `AsyncValue.loading()` before the profile exists (mirrors
/// [dashboardCurrencySummariesProvider]'s own convention) and
/// `AsyncValue.data(<HomeCategorySpendingSlice>[])` once there's a
/// profile but no expense transactions this month -- the UI renders
/// that as its own "no spending yet" empty state, never a fabricated
/// chart.
final Provider<AsyncValue<List<HomeCategorySpendingSlice>>> homeCategorySpendingProvider =
    Provider<AsyncValue<List<HomeCategorySpendingSlice>>>((ref) {
  final AsyncValue<ProfileRow?> profileAsync = ref.watch(activeProfileProvider);
  final AsyncValue<List<LedgerTransaction>> ledgerAsync = ref.watch(ledgerProvider);
  final AsyncValue<List<CategoryRow>> categoriesAsync =
      ref.watch(categoriesForTypeProvider('expense'));

  if (profileAsync.isLoading || ledgerAsync.isLoading || categoriesAsync.isLoading) {
    return const AsyncValue<List<HomeCategorySpendingSlice>>.loading();
  }
  if (profileAsync.hasError) {
    return AsyncValue<List<HomeCategorySpendingSlice>>.error(
      profileAsync.error!,
      profileAsync.stackTrace!,
    );
  }
  if (ledgerAsync.hasError) {
    return AsyncValue<List<HomeCategorySpendingSlice>>.error(
      ledgerAsync.error!,
      ledgerAsync.stackTrace!,
    );
  }
  if (categoriesAsync.hasError) {
    return AsyncValue<List<HomeCategorySpendingSlice>>.error(
      categoriesAsync.error!,
      categoriesAsync.stackTrace!,
    );
  }

  final ProfileRow? profile = profileAsync.requireValue;
  if (profile == null) {
    return const AsyncValue<List<HomeCategorySpendingSlice>>.loading(); // pre-onboarding
  }

  final List<LedgerTransaction> ledger = ledgerAsync.requireValue;
  final List<CategoryRow> categories = categoriesAsync.requireValue;
  final Map<String, CategoryRow> categoryById = <String, CategoryRow>{
    for (final CategoryRow category in categories) category.id: category,
  };

  final DateTime now = DateTime.now().toUtc();
  final DateTime monthStart = DateTime.utc(now.year, now.month);
  final DateTime monthEnd =
      DateTime.utc(now.year, now.month + 1).subtract(const Duration(microseconds: 1));

  final Map<String?, Money> totals = FinanceEngine.categoryExpenseTotals(
    ledger,
    currencyCode: profile.livingCurrency,
    fromUtc: monthStart,
    toUtc: monthEnd,
  );

  final List<HomeCategorySpendingSlice> slices = <HomeCategorySpendingSlice>[
    for (final MapEntry<String?, Money> entry in totals.entries)
      if (entry.value.minorUnits > 0)
        HomeCategorySpendingSlice(
          categoryId: entry.key,
          categoryName: entry.key == null ? null : categoryById[entry.key]?.name,
          colorKey: entry.key == null ? null : categoryById[entry.key]?.colorKey,
          amount: entry.value,
        ),
  ]..sort((HomeCategorySpendingSlice a, HomeCategorySpendingSlice b) =>
      b.amount.minorUnits.compareTo(a.amount.minorUnits));

  return AsyncValue<List<HomeCategorySpendingSlice>>.data(slices);
});
