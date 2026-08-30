import '../money/money.dart';
import 'ledger_models.dart';
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
  /// every non-deleted transaction that touches it, in either direction.
  ///
  /// [transactions] may contain transactions for other accounts too —
  /// only ones referencing [account.id] (as source or, for a transfer,
  /// destination) affect the result.
  static Money accountBalance(
    LedgerAccount account,
    List<LedgerTransaction> transactions,
  ) {
    Money balance = account.openingBalance;
    for (final LedgerTransaction tx in transactions) {
      if (tx.isDeleted) continue;

      if (tx.accountId == account.id) {
        balance = balance + _signedEffectOnSourceAccount(tx);
      }
      if (tx.type == TransactionType.transfer && tx.destinationAccountId == account.id) {
        balance = balance + tx.amount; // destination side of a transfer
      }
    }
    return balance;
  }

  /// The signed effect of [tx] on the account named by [tx.accountId]
  /// (the *source* account for a transfer; the only account for anything
  /// else). Positive = increases the balance, negative = decreases it.
  static Money _signedEffectOnSourceAccount(LedgerTransaction tx) {
    switch (tx.type) {
      case TransactionType.expense:
        return -tx.amount;
      case TransactionType.income:
        return tx.amount;
      case TransactionType.transfer:
        return -tx.amount; // leaving the source account
      case TransactionType.refund:
      case TransactionType.adjustment:
        // Beta 0 does not construct these — no repository or UI path
        // creates a refund/adjustment transaction (see
        // docs/14_DECISION_LOG.md and CLAUDE_FIRST_CODING_PROMPT.md).
        // Their signed effect on a balance is not yet defined by any
        // approved product decision. Throwing here — rather than
        // guessing a sign — means a stray row of this type surfaces as a
        // loud bug instead of a silently wrong balance.
        throw UnsupportedError(
          'TransactionType.${tx.type.name} has no defined balance effect yet '
          '(Beta 0 does not create these; see docs/14_DECISION_LOG.md).',
        );
    }
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
