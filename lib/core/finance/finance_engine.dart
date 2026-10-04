import '../money/money.dart';
import 'balance_class.dart';
import 'invalid_liability_operation_exception.dart';
import 'ledger_models.dart';
import 'liability_overpayment_exception.dart';
import 'transaction_type.dart';

/// The deterministic financial engine: pure functions over
/// [LedgerAccount]/[LedgerTransaction] with no floating point and no
/// hidden mutable "current balance" treated as ground truth.
///
/// This is the ONLY place in the app that computes a balance, an
/// income/expense total, or a category total — see
/// `docs/03_DATABASE_SCHEMA.md` ("Current balance should be
/// derived/reconciled from deterministic transaction data rather than
/// treated as an unverified independent truth") and
/// `CLAUDE_PROJECT_INSTRUCTIONS.md` ("Avoid: duplicated financial
/// calculations"). Every provider/screen that shows a balance or a total
/// calls into this class rather than re-deriving the arithmetic.
///
/// Deliberately has **no** dependency on Drift or Flutter, so its rules
/// can be exercised with plain in-memory lists in unit tests — see
/// `test/core/finance/finance_engine_test.dart`.
class FinanceEngine {
  FinanceEngine._();

  /// Computes [account]'s derived balance from its opening balance plus
  /// every non-deleted transaction that touches it, in either direction,
  /// using the effect table appropriate to [account.balanceClass] —
  /// see `docs/20_ACCOUNTS_ASSETS_HOUSEHOLD_ARCHITECTURE.md` §12.3 and
  /// ADR-035.
  ///
  /// [transactions] may contain transactions for other accounts too —
  /// only ones referencing [account.id] (as source or, for a transfer,
  /// destination) affect the result.
  ///
  /// **Checkpoint C effect table (frozen):**
  ///
  /// | Role                          | [BalanceClass.asset]   | [BalanceClass.liability]      |
  /// |--------------------------------|-------------------------|--------------------------------|
  /// | opening position               | +opening                | +opening (amount owed)         |
  /// | income, this account source    | +amount                 | invalid — throws            |
  /// | expense, this account source   | -amount                 | +amount (owed increases)       |
  /// | transfer, this account source  | -amount                 | invalid — throws            |
  /// | transfer, this account dest.   | +amount                 | -amount (payment reduces owed) |
  ///
  /// [TransactionType.refund]/[TransactionType.adjustment] are unchanged
  /// from before Checkpoint C — Beta 0 does not construct either, on
  /// any account class, so both still throw [UnsupportedError]
  /// regardless of [account.balanceClass].
  ///
  /// Throws [InvalidLiabilityOperationException] the moment a
  /// transaction attempts one of the two roles V1 never defines for a
  /// liability (income targeting it, or it being a transfer source) —
  /// see that exception's own doc. Throws [LiabilityOverpaymentException]
  /// if, after folding every transaction, a liability account's derived
  /// balance would be negative — V1 does not clamp an overpaid
  /// liability to zero or represent a "credit balance" (see that
  /// exception's own doc). Neither exception can be thrown for an asset
  /// account: every asset row of the table above is unchanged from
  /// before Checkpoint C, so every result this function ever returned
  /// for an asset account is byte-identical to before.
  static Money accountBalance(
    LedgerAccount account,
    List<LedgerTransaction> transactions,
  ) {
    Money balance = account.openingBalance;
    for (final LedgerTransaction tx in transactions) {
      if (tx.isDeleted) continue;

      if (tx.accountId == account.id) {
        balance = balance + _signedEffectOnSourceAccount(account, tx);
      }
      if (tx.type == TransactionType.transfer && tx.destinationAccountId == account.id) {
        balance = balance + _signedEffectOnDestinationAccount(account, tx);
      }
    }

    if (account.isLiability && balance.isNegative) {
      throw LiabilityOverpaymentException(accountId: account.id, resultingBalance: balance);
    }
    return balance;
  }

  /// The signed effect of [tx] on the account named by [tx.accountId]
  /// (the *source* account for a transfer; the only account for anything
  /// else). Positive = increases the balance, negative = decreases it.
  /// Branches on [account.balanceClass] to apply the correct row of the
  /// effect table documented on [accountBalance].
  static Money _signedEffectOnSourceAccount(LedgerAccount account, LedgerTransaction tx) {
    switch (account.balanceClass) {
      case BalanceClass.asset:
        switch (tx.type) {
          case TransactionType.expense:
            return -tx.amount;
          case TransactionType.income:
            return tx.amount;
          case TransactionType.transfer:
            return -tx.amount; // leaving the source account
          case TransactionType.refund:
          case TransactionType.adjustment:
            throw _unsupportedTransactionType(tx.type);
        }
      case BalanceClass.liability:
        switch (tx.type) {
          case TransactionType.expense:
            return tx.amount; // a purchase on credit increases what's owed
          case TransactionType.income:
            throw InvalidLiabilityOperationException(
              accountId: account.id,
              transactionId: tx.id,
              transactionType: tx.type,
              reason:
                  'income cannot target a liability account — V1 has no '
                  'concept of income paid onto a debt',
            );
          case TransactionType.transfer:
            throw InvalidLiabilityOperationException(
              accountId: account.id,
              transactionId: tx.id,
              transactionType: tx.type,
              reason:
                  'a liability account cannot be the source of a transfer — '
                  'it can only be a transfer destination (a payment)',
            );
          case TransactionType.refund:
          case TransactionType.adjustment:
            throw _unsupportedTransactionType(tx.type);
        }
    }
  }

  /// The signed effect of a [TransactionType.transfer] on the account
  /// named by [tx.destinationAccountId]. Only ever invoked for transfers
  /// (see [accountBalance]), so [tx.type] is not re-checked here.
  /// Branches on [account.balanceClass] to apply the correct row of the
  /// effect table documented on [accountBalance].
  static Money _signedEffectOnDestinationAccount(LedgerAccount account, LedgerTransaction tx) {
    switch (account.balanceClass) {
      case BalanceClass.asset:
        return tx.amount; // money arriving in the destination account
      case BalanceClass.liability:
        return -tx.amount; // a payment reduces what's owed
    }
  }

  /// Beta 0 does not construct [TransactionType.refund] or
  /// [TransactionType.adjustment] on any account class — no repository
  /// or UI path creates either (see `docs/14_DECISION_LOG.md` and
  /// `CLAUDE_FIRST_CODING_PROMPT.md`). Their signed effect on a balance
  /// is not yet defined by any approved product decision. Throwing here
  /// — rather than guessing a sign — means a stray row of this type
  /// surfaces as a loud bug instead of a silently wrong balance. Shared
  /// by both [BalanceClass] branches of [_signedEffectOnSourceAccount]
  /// since this is unchanged by Checkpoint C.
  static UnsupportedError _unsupportedTransactionType(TransactionType type) {
    return UnsupportedError(
      'TransactionType.${type.name} has no defined balance effect yet '
      '(Beta 0 does not create these; see docs/14_DECISION_LOG.md).',
    );
  }

  /// Income and expense totals over [transactions], scoped to a single
  /// [currencyCode] and optionally to `[fromUtc, toUtc]` (inclusive).
  ///
  /// **Release gate:** a transfer must never appear in either total —
  /// see `docs/14_DECISION_LOG.md` ADR (transfers never count as income
  /// or expense) and `docs/09_TESTING_STRATEGY.md`.
  ///
  /// Transactions in a currency other than [currencyCode] are excluded
  /// (Beta 0 does not sum across currencies — see
  /// `STAGE1_BETA0_IMPLEMENTATION_PLAN.md` §10).
  static MoneyTotals incomeExpenseTotals(
    List<LedgerTransaction> transactions, {
    required String currencyCode,
    DateTime? fromUtc,
    DateTime? toUtc,
  }) {
    Money income = Money.zero(currencyCode);
    Money expense = Money.zero(currencyCode);

    for (final LedgerTransaction tx in _relevant(transactions, currencyCode, fromUtc, toUtc)) {
      switch (tx.type) {
        case TransactionType.income:
          income = income + tx.amount;
        case TransactionType.expense:
          expense = expense + tx.amount;
        case TransactionType.transfer:
          break; // excluded by design — the release gate this enforces
        case TransactionType.refund:
        case TransactionType.adjustment:
          throw UnsupportedError(
            'TransactionType.${tx.type.name} has no defined income/expense '
            'effect yet (Beta 0 does not create these).',
          );
      }
    }
    return MoneyTotals(income: income, expense: expense);
  }

  /// Per-category expense+income totals over [transactions] (transfers
  /// are excluded — they never carry a category by construction).
  ///
  /// Returns a map from `categoryId` (nullable — uncategorized
  /// transactions group under the `null` key) to the net total for that
  /// category: income adds, expense subtracts, so a positive value in
  /// the result means net inflow and a negative value means net
  /// spending for that category.
  static Map<String?, Money> categoryTotals(
    List<LedgerTransaction> transactions, {
    required String currencyCode,
    DateTime? fromUtc,
    DateTime? toUtc,
  }) {
    final Map<String?, Money> totals = <String?, Money>{};

    for (final LedgerTransaction tx in _relevant(transactions, currencyCode, fromUtc, toUtc)) {
      if (tx.type == TransactionType.transfer) continue;
      if (tx.type == TransactionType.refund || tx.type == TransactionType.adjustment) {
        throw UnsupportedError(
          'TransactionType.${tx.type.name} has no defined category-total '
          'effect yet (Beta 0 does not create these).',
        );
      }
      final Money signedAmount = tx.type == TransactionType.income ? tx.amount : -tx.amount;
      final Money running = totals[tx.categoryId] ?? Money.zero(currencyCode);
      totals[tx.categoryId] = running + signedAmount;
    }
    return totals;
  }

  /// Deterministic average daily spend for the current calendar month —
  /// the Beta 1 Home dashboard "daily spending pace" metric.
  ///
  /// This function does **not** know what "today" is or query any clock
  /// itself — [daysElapsedInclusive] is supplied by the caller (see
  /// `dashboard_providers.dart`) precisely so this stays a pure,
  /// unit-testable function of its inputs, with no hidden dependency on
  /// `DateTime.now()`.
  ///
  /// Definition (all three points are part of the release gate for this
  /// metric — see `docs/14_DECISION_LOG.md` and the Beta 1 Task 1 spec):
  ///
  /// - **Period:** the calendar month [monthToDateExpense] was already
  ///   computed over (by [incomeExpenseTotals] with that month's UTC
  ///   `fromUtc`/`toUtc` bounds) — this function just divides by however
  ///   many days of it have elapsed.
  /// - **Today is included.** [daysElapsedInclusive] counts the current
  ///   day as a full elapsed day, so on the 1st of the month the divisor
  ///   is 1, never 0 — there is no calendar day on which zero days of
  ///   its own month have elapsed. Passing `0` or a negative value is a
  ///   caller bug and throws [ArgumentError] rather than dividing by
  ///   zero or silently producing a meaningless negative pace.
  /// - **Zero spending is a real, displayable value.** If
  ///   [monthToDateExpense] is zero, the result is `Money.zero` in the
  ///   same currency — not `null` and not an error. "Nothing spent yet"
  ///   is exactly what a pace of zero communicates.
  /// - **Rounding:** plain truncating integer division (Dart's `~/`) of
  ///   [monthToDateExpense]'s minor units by [daysElapsedInclusive].
  ///   Expense magnitudes are never negative (see [incomeExpenseTotals])
  ///   and the divisor is always >= 1, so truncation here is exactly
  ///   floor division — deterministic and reproducible, with no
  ///   floating point at any step. This is a distinct, simpler rule from
  ///   the ROUND HALF UP policy in `money_rounding.dart`, which governs
  ///   FX conversion results specifically, not this metric.
  ///
  /// No AI, forecasting, or projection is involved — this is arithmetic
  /// over transactions that have already happened.
  static Money dailySpendingPace({
    required Money monthToDateExpense,
    required int daysElapsedInclusive,
  }) {
    if (daysElapsedInclusive < 1) {
      throw ArgumentError.value(
        daysElapsedInclusive,
        'daysElapsedInclusive',
        'must be at least 1 -- today always counts as an elapsed day '
            'within its own month.',
      );
    }
    return Money.fromMinorUnits(
      monthToDateExpense.minorUnits ~/ daysElapsedInclusive,
      monthToDateExpense.currencyCode,
    );
  }

  /// Total expense-only spending for a single [categoryId], scoped to
  /// [currencyCode] and optionally `[fromUtc, toUtc]` (inclusive) -- the
  /// primitive a category budget's "spent" figure is computed from.
  ///
  /// Unlike [categoryTotals] (which nets income against expense per
  /// category, for a general "category breakdown" view), this only sums
  /// [TransactionType.expense] transactions and only for the one
  /// [categoryId] given -- income and transfers are excluded entirely,
  /// per the budgets release gate (a category budget must never be
  /// reduced by income landing in the same category, and must never
  /// count a transfer). Matching is exact-category-only: Beta 1 has no
  /// subcategory UI (`Categories.parentId` is unpopulated and unused
  /// throughout the app), so a transaction filed under a different
  /// category id -- even one that might conceptually be a "child" of
  /// [categoryId] one day -- is never included. See
  /// `docs/14_DECISION_LOG.md` ADR-021.
  static Money categoryExpenseTotal(
    List<LedgerTransaction> transactions, {
    required String currencyCode,
    required String categoryId,
    DateTime? fromUtc,
    DateTime? toUtc,
  }) {
    Money total = Money.zero(currencyCode);
    for (final LedgerTransaction tx in _relevant(transactions, currencyCode, fromUtc, toUtc)) {
      if (tx.type != TransactionType.expense) continue;
      if (tx.categoryId != categoryId) continue;
      total = total + tx.amount;
    }
    return total;
  }

  /// Bulk, expense-only sibling of [categoryExpenseTotal] -- Dashboard
  /// V1 Finalization checkpoint's "Spending this month" breakdown. One
  /// pass over [transactions] produces every category's expense total
  /// at once (map key: `categoryId`, nullable -- uncategorized expense
  /// transactions group under the `null` key, exactly like
  /// [categoryTotals]) instead of re-scanning the full list once per
  /// category.
  ///
  /// Same exclusions as [categoryExpenseTotal]: only
  /// [TransactionType.expense] contributes -- never income (even income
  /// filed under the same category id) and never a transfer, matching
  /// the budgets release gate this shares its filtering rule with.
  /// Unlike [categoryTotals] (which nets income against expense per
  /// category for a general breakdown view), every value here is a
  /// plain non-negative expense magnitude, ready for a "how is my
  /// spending distributed" presentation without the caller needing to
  /// know which categories happen to also receive income.
  static Map<String?, Money> categoryExpenseTotals(
    List<LedgerTransaction> transactions, {
    required String currencyCode,
    DateTime? fromUtc,
    DateTime? toUtc,
  }) {
    final Map<String?, Money> totals = <String?, Money>{};
    for (final LedgerTransaction tx in _relevant(transactions, currencyCode, fromUtc, toUtc)) {
      if (tx.type != TransactionType.expense) continue;
      final Money running = totals[tx.categoryId] ?? Money.zero(currencyCode);
      totals[tx.categoryId] = running + tx.amount;
    }
    return totals;
  }

  /// Deterministic recommended daily spend for the rest of a budget
  /// period -- the Beta 1 budgets feature's "how much can I spend per day
  /// for the rest of the month" metric. See `docs/14_DECISION_LOG.md`
  /// ADR-021.
  ///
  /// - If [remaining] is zero or negative, the result is always
  ///   `Money.zero` in the same currency -- there is never a negative
  ///   "allowed" daily spend; an overspent budget recommends spending
  ///   nothing further, it does not recommend clawing money back.
  /// - Otherwise: [remaining] split evenly across
  ///   [remainingDaysInclusive] (today counts as one of the remaining
  ///   days -- the same "today is included" convention
  ///   [dailySpendingPace] uses), truncating via Dart's `~/` --
  ///   deterministic, no floating point, matching [dailySpendingPace]'s
  ///   own rounding rule.
  /// - [remainingDaysInclusive] must be at least 1; passing `0` or a
  ///   negative value is a caller bug (see `BudgetCalculator`, the only
  ///   caller, which only invokes this for a month with at least one
  ///   elapsed day) and throws [ArgumentError] rather than dividing by
  ///   zero.
  static Money recommendedDailySpend({
    required Money remaining,
    required int remainingDaysInclusive,
  }) {
    if (remaining.isZero || remaining.isNegative) {
      return Money.zero(remaining.currencyCode);
    }
    if (remainingDaysInclusive < 1) {
      throw ArgumentError.value(
        remainingDaysInclusive,
        'remainingDaysInclusive',
        'must be at least 1 -- today always counts as one of the '
            'remaining days.',
      );
    }
    return Money.fromMinorUnits(
      remaining.minorUnits ~/ remainingDaysInclusive,
      remaining.currencyCode,
    );
  }

  /// The largest magnitude [projectedMonthEndSpend] can multiply by
  /// [totalDaysInMonth] without risking silent signed 64-bit overflow --
  /// `2^63 - 1`, the same range [Money.minorUnits] is documented to live
  /// in (ADR-017).
  static const int _maxSafeMinorUnits = 9223372036854775807;

  /// Deterministic projected month-end spend: what [spent] would total by
  /// the end of the month if the average daily rate seen over
  /// [daysElapsedInclusive] continued for the rest of
  /// [totalDaysInMonth] -- an advisory, derived-only figure. It is never
  /// persisted and never mutates financial truth; it is recomputed fresh
  /// from the actual ledger every time it's read. See
  /// `docs/14_DECISION_LOG.md` ADR-021.
  ///
  /// Formula -- **one truncation at the end**, not one per intermediate
  /// step:
  ///
  /// ```
  /// projected = spent.minorUnits * totalDaysInMonth ~/ daysElapsedInclusive
  /// ```
  ///
  /// Computing the daily average first (`spent ~/ daysElapsedInclusive`)
  /// and then multiplying by [totalDaysInMonth] would truncate twice and
  /// can materially understate the projection for a small number of
  /// elapsed days (e.g. 100 minor units spent over 3 days of a 30-day
  /// month: `100 ~/ 3 * 30 == 990`, but `100 * 30 ~/ 3 == 1000` -- the
  /// correct answer). This function always performs the multiplication
  /// first.
  ///
  /// Not defined for a month with zero elapsed days (a future month) --
  /// [daysElapsedInclusive] must be at least 1, or this throws
  /// [ArgumentError]. `BudgetCalculator.evaluate`, the only caller, never
  /// invokes this for a future month; it represents that case as `null`
  /// ("not applicable") rather than fabricating a projection.
  ///
  /// A historical (fully elapsed) month naturally has
  /// `daysElapsedInclusive == totalDaysInMonth`, so the formula reduces
  /// to `spent * totalDaysInMonth ~/ totalDaysInMonth == spent` -- the
  /// projection equals the actual total, the only sensible answer once a
  /// month is over.
  ///
  /// Guards against silent 64-bit overflow in the multiplication by
  /// checking the operands fit before multiplying, and throws
  /// [StateError] rather than returning a wrapped/garbage result in the
  /// (practically unreachable, for any real personal-finance amount)
  /// case that they don't.
  static Money projectedMonthEndSpend({
    required Money spent,
    required int daysElapsedInclusive,
    required int totalDaysInMonth,
  }) {
    if (daysElapsedInclusive < 1) {
      throw ArgumentError.value(
        daysElapsedInclusive,
        'daysElapsedInclusive',
        'must be at least 1 -- this function is not defined for a month '
            'with zero elapsed days; callers must not invoke it for a '
            'future month.',
      );
    }
    if (totalDaysInMonth < daysElapsedInclusive) {
      throw ArgumentError.value(
        totalDaysInMonth,
        'totalDaysInMonth',
        'must be at least daysElapsedInclusive ($daysElapsedInclusive).',
      );
    }

    final int magnitude = spent.minorUnits.abs();
    if (magnitude > _maxSafeMinorUnits ~/ totalDaysInMonth) {
      throw StateError(
        'projectedMonthEndSpend: spent.minorUnits ($magnitude) * '
        'totalDaysInMonth ($totalDaysInMonth) would overflow the signed '
        '64-bit integer range that backs Money -- refusing to silently '
        'wrap.',
      );
    }

    return Money.fromMinorUnits(
      spent.minorUnits * totalDaysInMonth ~/ daysElapsedInclusive,
      spent.currencyCode,
    );
  }

  /// The minimum daily contribution that, saved every remaining day
  /// (including today), reaches [remaining] by a savings goal's
  /// deadline -- **ceiling**, not floor, division. Deliberately the
  /// opposite rounding direction from [recommendedDailySpend]: a
  /// spending allowance should never accidentally invite overspend, so
  /// it floors; a savings pace that floors can systematically fall
  /// short by the deadline (e.g. 100 minor units remaining over 3 days:
  /// flooring gives 33/day, and `33 * 3 == 99 < 100` -- the goal is
  /// missed even if followed exactly), so this ceils instead. See
  /// `docs/14_DECISION_LOG.md` ADR-022.
  ///
  /// Computed via quotient/remainder rather than the more common
  /// `(remaining + remainingDaysInclusive - 1) ~/ remainingDaysInclusive`
  /// idiom, which can silently overflow for [remaining] near the signed
  /// 64-bit boundary before the division ever runs:
  ///
  /// ```
  /// q = remaining.minorUnits ~/ remainingDaysInclusive
  /// r = remaining.minorUnits % remainingDaysInclusive
  /// recommended = q + (r == 0 ? 0 : 1)
  /// ```
  ///
  /// [remaining] that is zero or negative recommends zero -- there is
  /// nothing left to save. [remainingDaysInclusive] must be at least 1
  /// (today always counts as one of the remaining days -- a deadline of
  /// today itself is exactly 1 remaining day, not 0), or this throws
  /// [ArgumentError]; callers must not invoke this for a passed
  /// deadline.
  static Money recommendedDailyContribution({
    required Money remaining,
    required int remainingDaysInclusive,
  }) {
    if (remainingDaysInclusive < 1) {
      throw ArgumentError.value(
        remainingDaysInclusive,
        'remainingDaysInclusive',
        'must be at least 1 -- today always counts as one of the '
            'remaining days.',
      );
    }
    if (!remaining.isPositive) {
      return Money.zero(remaining.currencyCode);
    }
    final int q = remaining.minorUnits ~/ remainingDaysInclusive;
    final int r = remaining.minorUnits % remainingDaysInclusive;
    return Money.fromMinorUnits(q + (r == 0 ? 0 : 1), remaining.currencyCode);
  }

  static Iterable<LedgerTransaction> _relevant(
    List<LedgerTransaction> transactions,
    String currencyCode,
    DateTime? fromUtc,
    DateTime? toUtc,
  ) sync* {
    for (final LedgerTransaction tx in transactions) {
      if (tx.isDeleted) continue;
      if (tx.amount.currencyCode != currencyCode) continue;
      if (fromUtc != null && tx.occurredAtUtc.isBefore(fromUtc)) continue;
      if (toUtc != null && tx.occurredAtUtc.isAfter(toUtc)) continue;
      yield tx;
    }
  }
}
