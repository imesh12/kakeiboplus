import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/repositories/account_repository.dart';
import '../../../core/finance/finance_engine.dart';
import '../../../core/finance/ledger_models.dart';
import '../../../core/money/money.dart';
import '../../accounts/presentation/account_providers.dart';
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
    required this.balance,
    required this.income,
    required this.expense,
    required this.dailyPace,
  });

  final String currencyCode;

  /// Sum of every active account's derived balance in this currency
  /// (`FinanceEngine.accountBalance`, summed — never a raw stored
  /// balance column).
  final Money balance;

  /// This calendar month's income in this currency, transfers excluded.
  final Money income;

  /// This calendar month's spending in this currency, transfers
  /// excluded.
  final Money expense;

  /// This calendar month's deterministic daily spending pace in this
  /// currency — see `FinanceEngine.dailySpendingPace` for the exact
  /// definition (period, today-inclusion, zero handling, rounding).
  final Money dailyPace;
}

/// Placeholder result for the "Remaining monthly budget" dashboard tile.
///
/// Beta 0's schema has no `budgets` table at all (see
/// `lib/features/budgets/README.md`) — Beta 1's budgets feature owns
/// building that. [remaining] is `null` until that feature exists; a
/// real implementation of [monthlyBudgetSummaryProvider] can start
/// returning a non-null value later without `HomeScreen` needing to
/// change, since it already renders both states.
@immutable
class MonthlyBudgetSummary {
  const MonthlyBudgetSummary.notConfigured() : remaining = null;

  /// `null` means "no budget configured for this month" — the dashboard
  /// must show an explicit "set a budget" empty state rather than
  /// inventing a number (see the Beta 1 Task 1 spec's ban on fake
  /// financial values).
  final Money? remaining;
}

/// One upcoming recurring bill/income the "Upcoming commitments" tile
/// would show. Nothing constructs this yet — see
/// [upcomingCommitmentsProvider] — but the shape exists so the recurring
/// feature has a target to populate rather than needing to invent one
/// alongside its first UI change.
@immutable
class UpcomingCommitmentSummary {
  const UpcomingCommitmentSummary({
    required this.label,
    required this.dueDateUtc,
    required this.amount,
  });

  final String label;
  final DateTime dueDateUtc;
  final Money amount;
}

/// Always "not configured": Beta 0's schema has no `budgets` table (see
/// `lib/features/budgets/README.md`), so there is nothing to compute a
/// remaining amount from. A plain (non-autoDispose) `Provider`, like
/// every other dashboard provider here, so Beta 1's budgets feature can
/// later replace this one definition with a real Drift-backed query —
/// `HomeScreen` only ever reads `.remaining`, so the swap is invisible to
/// it.
final Provider<MonthlyBudgetSummary> monthlyBudgetSummaryProvider =
    Provider<MonthlyBudgetSummary>((ref) => const MonthlyBudgetSummary.notConfigured());

/// Always empty: Beta 0's schema has no `recurring_transactions` table
/// and no `transactions.recurring_transaction_id` column (see
/// `lib/features/recurring/README.md`), so there is no data source for
/// "upcoming commitments" yet. Same forward-compatibility reasoning as
/// [monthlyBudgetSummaryProvider].
final Provider<List<UpcomingCommitmentSummary>> upcomingCommitmentsProvider =
    Provider<List<UpcomingCommitmentSummary>>((ref) => const <UpcomingCommitmentSummary>[]);

/// The Home dashboard's core financial summary: one
/// [CurrencyDashboardSummary] per currency the profile actually holds
/// money in (i.e. has at least one active account in), ordered with the
/// profile's living currency first, then its home currency (if
/// different), then any others alphabetically — purely a display
/// ordering choice, not a financial calculation.
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
/// profile but zero accounts, which the UI renders as its own empty
/// state rather than a spinner.
final Provider<AsyncValue<List<CurrencyDashboardSummary>>> dashboardCurrencySummariesProvider =
    Provider<AsyncValue<List<CurrencyDashboardSummary>>>((ref) {
  final AsyncValue<ProfileRow?> profileAsync = ref.watch(activeProfileProvider);
  final AsyncValue<List<AccountRow>> accountsAsync = ref.watch(accountsProvider);
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
  Money balance = Money.zero(currencyCode);
  for (final AccountRow account in accounts) {
    if (account.currencyCode != currencyCode) continue;
    balance = balance + FinanceEngine.accountBalance(account.toLedgerAccount(), ledger);
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
    balance: balance,
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
