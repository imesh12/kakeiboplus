import 'package:meta/meta.dart';

import '../../../core/money/money.dart';
import 'budget_calculation.dart';
import 'budget_month.dart';

/// One category budget's evaluated progress for a [BudgetMonthSummary]'s
/// month -- Checkpoint Q (Monthly Budget Progress & Month Navigation).
///
/// Deliberately wraps an existing [BudgetCalculation] rather than
/// re-deriving budgeted/spent/remaining/status itself -- the same
/// generic evaluation `livingCurrencyOverallBudgetProvider` already uses
/// for the overall budget (see `budget_providers.dart`) applies
/// unchanged to a single category budget; only the inputs
/// (`FinanceEngine.categoryExpenseTotal` instead of
/// `FinanceEngine.incomeExpenseTotals(...).expense`) differ. See
/// `docs/14_DECISION_LOG.md` ADR-021 point 6 and the new ADR this
/// checkpoint adds.
///
/// [usedRatio]/[isOverBudget] are presentation-only derived getters --
/// never persisted, never fed back into [calculation] -- kept here
/// rather than duplicated inside a widget's `build`, per the "financial
/// arithmetic outside widget build methods" convention. The formula
/// matches `_ConfiguredBudget` on `home_screen.dart` (the dashboard's
/// overall-budget card) exactly: uncapped in text, only a progress bar's
/// fill fraction clamps to 1.0.
@immutable
class CategoryBudgetProgress {
  const CategoryBudgetProgress({
    required this.budgetId,
    required this.categoryId,
    required this.calculation,
  });

  /// The `Budgets` row id this progress was computed from -- stable
  /// identity for widget keys, independent of the category's (possibly
  /// renamed) display name.
  final String budgetId;

  /// The `Categories.id` this budget targets -- never a category name.
  /// Renaming a category never changes this id, so historical spend
  /// attribution survives a rename unaffected (see
  /// `docs/14_DECISION_LOG.md` ADR-021 point 5, unchanged by this
  /// checkpoint).
  final String categoryId;

  final BudgetCalculation calculation;

  /// `spent / budgeted`, uncapped -- e.g. `1.25` for 125% used.
  /// [calculation.budgeted] is always strictly positive
  /// (`BudgetRepository` rejects a zero/negative amount before it is
  /// ever persisted), so this never divides by zero.
  double get usedRatio => calculation.spent.minorUnits / calculation.budgeted.minorUnits;

  bool get isOverBudget => calculation.spent > calculation.budgeted;
}

/// The Budgets screen's per-currency "Month Summary" for one
/// [BudgetMonth] -- Checkpoint Q. Built **only** from category budgets
/// (never the separate overall/whole-currency budget -- see this
/// class's own file-level doc and ADR-021's point 6/13): summing both
/// concepts together would double-count capacity that was never meant to
/// stack, since Beta 1 treats "overall budget" and "the set of category
/// budgets" as two independent, non-overlapping ways to budget the same
/// money, not a hierarchy.
///
/// One instance per currency that has at least one active category
/// budget for the month -- a currency with none simply has no summary
/// (see [BudgetMonthSummary]'s absence in that case, not a fabricated
/// zero-budget entry).
@immutable
class BudgetMonthSummary {
  const BudgetMonthSummary({
    required this.month,
    required this.currencyCode,
    required this.totalBudget,
    required this.spent,
    required this.remaining,
    required this.categoryProgress,
  });

  final BudgetMonth month;
  final String currencyCode;

  /// Sum of every active category budget's amount, this currency only --
  /// never mixed with another currency, and never includes the separate
  /// overall budget.
  final Money totalBudget;

  /// Sum of each budgeted category's expense-only spend for [month] --
  /// see `FinanceEngine.categoryExpenseTotal`. Income and transfers are
  /// never included (ADR-021 point 6); a category with no budget this
  /// month contributes nothing here even if it has real expense activity
  /// (Section L: unbudgeted spending is never silently treated as
  /// budgeted spending).
  final Money spent;

  /// `totalBudget - spent`. Can be negative -- an overspent month is
  /// represented as a true negative amount, never clamped to zero (same
  /// convention as [BudgetCalculation.remaining]).
  final Money remaining;

  final List<CategoryBudgetProgress> categoryProgress;

  /// `spent / totalBudget`, uncapped. Always present because a
  /// [BudgetMonthSummary] is only ever constructed for a currency with at
  /// least one category budget, so [totalBudget] (a sum of strictly
  /// positive amounts) can never be zero here.
  double get usedRatio => spent.minorUnits / totalBudget.minorUnits;

  bool get isOverBudget => spent > totalBudget;
}
