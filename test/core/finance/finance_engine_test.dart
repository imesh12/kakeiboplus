import 'package:ai_financial_coach/core/finance/balance_class.dart';
import 'package:ai_financial_coach/core/finance/finance_engine.dart';
import 'package:ai_financial_coach/core/finance/invalid_liability_operation_exception.dart';
import 'package:ai_financial_coach/core/finance/ledger_models.dart';
import 'package:ai_financial_coach/core/finance/liability_overpayment_exception.dart';
import 'package:ai_financial_coach/core/finance/transaction_type.dart';
import 'package:ai_financial_coach/core/money/currency_mismatch_exception.dart';
import 'package:ai_financial_coach/core/money/money.dart';
import 'package:flutter_test/flutter_test.dart';

LedgerTransaction _tx({
  required String id,
  required String accountId,
  String? destinationAccountId,
  required TransactionType type,
  required int minorUnits,
  String currency = 'USD',
  String? categoryId,
  DateTime? occurredAtUtc,
  bool isDeleted = false,
}) {
  return LedgerTransaction(
    id: id,
    accountId: accountId,
    destinationAccountId: destinationAccountId,
    type: type,
    amount: Money.fromMinorUnits(minorUnits, currency),
    categoryId: categoryId,
    occurredAtUtc: occurredAtUtc ?? DateTime.utc(2026, 1, 1),
    isDeleted: isDeleted,
  );
}

void main() {
  group('FinanceEngine.accountBalance', () {
    test('opening balance with no transactions', () {
      final LedgerAccount account = LedgerAccount(
        id: 'a1',
        currencyCode: 'USD',
        openingBalance: Money.fromMinorUnits(10000, 'USD'),
        balanceClass: BalanceClass.asset,
      );
      expect(FinanceEngine.accountBalance(account, []), Money.fromMinorUnits(10000, 'USD'));
    });

    test('expense decreases balance, income increases it', () {
      final LedgerAccount account = LedgerAccount(
        id: 'a1',
        currencyCode: 'USD',
        openingBalance: Money.fromMinorUnits(10000, 'USD'),
        balanceClass: BalanceClass.asset,
      );
      final List<LedgerTransaction> txs = <LedgerTransaction>[
        _tx(id: 't1', accountId: 'a1', type: TransactionType.expense, minorUnits: 2500),
        _tx(id: 't2', accountId: 'a1', type: TransactionType.income, minorUnits: 5000),
      ];
      // 10000 - 2500 + 5000 = 12500
      expect(FinanceEngine.accountBalance(account, txs), Money.fromMinorUnits(12500, 'USD'));
    });

    test(
        'release gate: transfer decreases the SOURCE account balance and '
        'increases the DESTINATION account balance', () {
      final LedgerAccount source = LedgerAccount(
        id: 'src',
        currencyCode: 'USD',
        openingBalance: Money.fromMinorUnits(10000, 'USD'),
        balanceClass: BalanceClass.asset,
      );
      final LedgerAccount destination = LedgerAccount(
        id: 'dst',
        currencyCode: 'USD',
        openingBalance: Money.fromMinorUnits(0, 'USD'),
        balanceClass: BalanceClass.asset,
      );
      final List<LedgerTransaction> txs = <LedgerTransaction>[
        _tx(
          id: 't1',
          accountId: 'src',
          destinationAccountId: 'dst',
          type: TransactionType.transfer,
          minorUnits: 3000,
        ),
      ];
      expect(FinanceEngine.accountBalance(source, txs), Money.fromMinorUnits(7000, 'USD'));
      expect(FinanceEngine.accountBalance(destination, txs), Money.fromMinorUnits(3000, 'USD'));
    });

    test('release gate: a deleted transaction has no effect on balance', () {
      final LedgerAccount account = LedgerAccount(
        id: 'a1',
        currencyCode: 'USD',
        openingBalance: Money.fromMinorUnits(10000, 'USD'),
        balanceClass: BalanceClass.asset,
      );
      final List<LedgerTransaction> txs = <LedgerTransaction>[
        _tx(id: 't1', accountId: 'a1', type: TransactionType.expense, minorUnits: 2500, isDeleted: true),
      ];
      expect(FinanceEngine.accountBalance(account, txs), Money.fromMinorUnits(10000, 'USD'));
    });

    test('transactions on unrelated accounts are ignored', () {
      final LedgerAccount account = LedgerAccount(
        id: 'a1',
        currencyCode: 'USD',
        openingBalance: Money.fromMinorUnits(10000, 'USD'),
        balanceClass: BalanceClass.asset,
      );
      final List<LedgerTransaction> txs = <LedgerTransaction>[
        _tx(id: 't1', accountId: 'other', type: TransactionType.expense, minorUnits: 999999),
      ];
      expect(FinanceEngine.accountBalance(account, txs), Money.fromMinorUnits(10000, 'USD'));
    });

    // --- Checkpoint C additions below: close two gaps the pre-C test
    // suite left implicit (currency-mismatch and zero-value handling
    // were only ever proven at the Money level -- see
    // test/core/money/money_test.dart -- never directly against
    // accountBalance itself). Neither is new behavior: Money's own
    // arithmetic operators already threw/behaved this way before
    // Checkpoint C; these tests just pin that inherited behavior at the
    // FinanceEngine boundary per the Checkpoint C asset-regression
    // checklist ("same-currency validation", "mismatched-currency
    // rejection", "zero values if allowed").

    test(
        'Checkpoint C regression: a transaction whose currency does not match '
        "the account's currency throws CurrencyMismatchException rather than "
        'silently coercing', () {
      final LedgerAccount account = LedgerAccount(
        id: 'a1',
        currencyCode: 'USD',
        openingBalance: Money.fromMinorUnits(10000, 'USD'),
        balanceClass: BalanceClass.asset,
      );
      final List<LedgerTransaction> txs = <LedgerTransaction>[
        _tx(id: 't1', accountId: 'a1', type: TransactionType.expense, minorUnits: 500, currency: 'JPY'),
      ];
      expect(
        () => FinanceEngine.accountBalance(account, txs),
        throwsA(isA<CurrencyMismatchException>()),
      );
    });

    test(
        'Checkpoint C regression: a zero-amount transaction is a real, '
        'well-defined value that leaves the balance unchanged', () {
      final LedgerAccount account = LedgerAccount(
        id: 'a1',
        currencyCode: 'USD',
        openingBalance: Money.fromMinorUnits(10000, 'USD'),
        balanceClass: BalanceClass.asset,
      );
      final List<LedgerTransaction> txs = <LedgerTransaction>[
        _tx(id: 't1', accountId: 'a1', type: TransactionType.expense, minorUnits: 0),
      ];
      expect(FinanceEngine.accountBalance(account, txs), Money.fromMinorUnits(10000, 'USD'));
    });
  });

  group('FinanceEngine.accountBalance -- liability (Checkpoint C)', () {
    test('opening position is the positive amount owed, with no transactions', () {
      final LedgerAccount card = LedgerAccount(
        id: 'card1',
        currencyCode: 'USD',
        openingBalance: Money.fromMinorUnits(0, 'USD'),
        balanceClass: BalanceClass.liability,
      );
      expect(FinanceEngine.accountBalance(card, []), Money.zero('USD'));

      final LedgerAccount preExistingDebt = LedgerAccount(
        id: 'card2',
        currencyCode: 'USD',
        openingBalance: Money.fromMinorUnits(5000, 'USD'),
        balanceClass: BalanceClass.liability,
      );
      expect(FinanceEngine.accountBalance(preExistingDebt, []), Money.fromMinorUnits(5000, 'USD'));
    });

    test('an expense targeting a liability account increases the amount owed', () {
      final LedgerAccount card = LedgerAccount(
        id: 'card1',
        currencyCode: 'USD',
        openingBalance: Money.zero('USD'),
        balanceClass: BalanceClass.liability,
      );
      final List<LedgerTransaction> txs = <LedgerTransaction>[
        _tx(id: 't1', accountId: 'card1', type: TransactionType.expense, minorUnits: 3000),
      ];
      expect(FinanceEngine.accountBalance(card, txs), Money.fromMinorUnits(3000, 'USD'));
    });

    test('multiple liability expenses accumulate the amount owed', () {
      // Checkpoint C brief's own worked example: opening owed 0, expense
      // 3000 -> owed 3000, expense 2000 -> owed 5000.
      final LedgerAccount card = LedgerAccount(
        id: 'card1',
        currencyCode: 'USD',
        openingBalance: Money.zero('USD'),
        balanceClass: BalanceClass.liability,
      );
      final List<LedgerTransaction> txs = <LedgerTransaction>[
        _tx(id: 't1', accountId: 'card1', type: TransactionType.expense, minorUnits: 3000),
        _tx(id: 't2', accountId: 'card1', type: TransactionType.expense, minorUnits: 2000),
      ];
      expect(FinanceEngine.accountBalance(card, txs), Money.fromMinorUnits(5000, 'USD'));
    });

    test(
        'a checking-to-credit-card payment decreases the asset SOURCE balance '
        'and decreases the liability DESTINATION amount owed', () {
      // Checkpoint C brief's own worked example: checking 30000 -> 27000,
      // liability owed 5000 -> 2000.
      final LedgerAccount checking = LedgerAccount(
        id: 'checking',
        currencyCode: 'USD',
        openingBalance: Money.fromMinorUnits(30000, 'USD'),
        balanceClass: BalanceClass.asset,
      );
      final LedgerAccount card = LedgerAccount(
        id: 'card1',
        currencyCode: 'USD',
        openingBalance: Money.fromMinorUnits(5000, 'USD'),
        balanceClass: BalanceClass.liability,
      );
      final List<LedgerTransaction> txs = <LedgerTransaction>[
        _tx(
          id: 't1',
          accountId: 'checking',
          destinationAccountId: 'card1',
          type: TransactionType.transfer,
          minorUnits: 3000,
        ),
      ];
      expect(FinanceEngine.accountBalance(checking, txs), Money.fromMinorUnits(27000, 'USD'));
      expect(FinanceEngine.accountBalance(card, txs), Money.fromMinorUnits(2000, 'USD'));
    });

    test(
        'a credit-card payment is neither an expense nor an income by '
        "FinanceEngine's own type-based totals -- it is a transfer, "
        'excluded from both by construction', () {
      final List<LedgerTransaction> txs = <LedgerTransaction>[
        _tx(
          id: 't1',
          accountId: 'checking',
          destinationAccountId: 'card1',
          type: TransactionType.transfer,
          minorUnits: 3000,
        ),
      ];
      final MoneyTotals totals = FinanceEngine.incomeExpenseTotals(txs, currencyCode: 'USD');
      expect(totals.income, Money.zero('USD'));
      expect(totals.expense, Money.zero('USD'));
    });

    test(
        'income cannot target a liability account -- rejected with '
        'InvalidLiabilityOperationException rather than silently producing a '
        'balance', () {
      final LedgerAccount card = LedgerAccount(
        id: 'card1',
        currencyCode: 'USD',
        openingBalance: Money.zero('USD'),
        balanceClass: BalanceClass.liability,
      );
      final List<LedgerTransaction> txs = <LedgerTransaction>[
        _tx(id: 't1', accountId: 'card1', type: TransactionType.income, minorUnits: 1000),
      ];
      expect(
        () => FinanceEngine.accountBalance(card, txs),
        throwsA(isA<InvalidLiabilityOperationException>()),
      );
    });

    test(
        'a liability account cannot be the SOURCE of a transfer -- rejected '
        'with InvalidLiabilityOperationException', () {
      final LedgerAccount card = LedgerAccount(
        id: 'card1',
        currencyCode: 'USD',
        openingBalance: Money.fromMinorUnits(5000, 'USD'),
        balanceClass: BalanceClass.liability,
      );
      final List<LedgerTransaction> txs = <LedgerTransaction>[
        _tx(
          id: 't1',
          accountId: 'card1',
          destinationAccountId: 'checking',
          type: TransactionType.transfer,
          minorUnits: 1000,
        ),
      ];
      expect(
        () => FinanceEngine.accountBalance(card, txs),
        throwsA(isA<InvalidLiabilityOperationException>()),
      );
    });

    test(
        'liability overpayment: a payment larger than the amount owed is '
        'rejected with LiabilityOverpaymentException rather than going '
        'negative', () {
      // Checkpoint C brief's own worked example: owed 2000, payment 3000
      // would naively give -1000 -- must reject instead of silently
      // clamping to zero or allowing a negative "owed" balance.
      final LedgerAccount card = LedgerAccount(
        id: 'card1',
        currencyCode: 'USD',
        openingBalance: Money.fromMinorUnits(2000, 'USD'),
        balanceClass: BalanceClass.liability,
      );
      final List<LedgerTransaction> txs = <LedgerTransaction>[
        _tx(
          id: 't1',
          accountId: 'checking',
          destinationAccountId: 'card1',
          type: TransactionType.transfer,
          minorUnits: 3000,
        ),
      ];
      expect(
        () => FinanceEngine.accountBalance(card, txs),
        throwsA(isA<LiabilityOverpaymentException>()),
      );
    });

    test(
        'liability overpayment is not rejected when the payment exactly zeroes '
        'out the amount owed', () {
      final LedgerAccount card = LedgerAccount(
        id: 'card1',
        currencyCode: 'USD',
        openingBalance: Money.fromMinorUnits(2000, 'USD'),
        balanceClass: BalanceClass.liability,
      );
      final List<LedgerTransaction> txs = <LedgerTransaction>[
        _tx(
          id: 't1',
          accountId: 'checking',
          destinationAccountId: 'card1',
          type: TransactionType.transfer,
          minorUnits: 2000,
        ),
      ];
      expect(FinanceEngine.accountBalance(card, txs), Money.zero('USD'));
    });

    test('a deleted expense does not increase the amount owed', () {
      final LedgerAccount card = LedgerAccount(
        id: 'card1',
        currencyCode: 'USD',
        openingBalance: Money.zero('USD'),
        balanceClass: BalanceClass.liability,
      );
      final List<LedgerTransaction> txs = <LedgerTransaction>[
        _tx(id: 't1', accountId: 'card1', type: TransactionType.expense, minorUnits: 5000, isDeleted: true),
      ];
      expect(FinanceEngine.accountBalance(card, txs), Money.zero('USD'));
    });

    test(
        'a liability transaction in a mismatched currency still throws '
        'CurrencyMismatchException -- the liability effect table does not '
        'bypass currency invariants', () {
      final LedgerAccount card = LedgerAccount(
        id: 'card1',
        currencyCode: 'USD',
        openingBalance: Money.zero('USD'),
        balanceClass: BalanceClass.liability,
      );
      final List<LedgerTransaction> txs = <LedgerTransaction>[
        _tx(id: 't1', accountId: 'card1', type: TransactionType.expense, minorUnits: 500, currency: 'JPY'),
      ];
      expect(
        () => FinanceEngine.accountBalance(card, txs),
        throwsA(isA<CurrencyMismatchException>()),
      );
    });

    test(
        'existing asset behavior is unchanged by the liability effect table -- '
        'an asset account alongside a liability account in the same ledger '
        'still gets exactly its pre-Checkpoint-C balance', () {
      final LedgerAccount checking = LedgerAccount(
        id: 'checking',
        currencyCode: 'USD',
        openingBalance: Money.fromMinorUnits(10000, 'USD'),
        balanceClass: BalanceClass.asset,
      );
      final List<LedgerTransaction> txs = <LedgerTransaction>[
        _tx(id: 't1', accountId: 'checking', type: TransactionType.expense, minorUnits: 2500),
        _tx(id: 't2', accountId: 'checking', type: TransactionType.income, minorUnits: 5000),
      ];
      expect(FinanceEngine.accountBalance(checking, txs), Money.fromMinorUnits(12500, 'USD'));
    });
  });

  group('FinanceEngine.incomeExpenseTotals', () {
    test('release gate: a transfer is excluded from both income and expense totals', () {
      final List<LedgerTransaction> txs = <LedgerTransaction>[
        _tx(id: 't1', accountId: 'a1', type: TransactionType.income, minorUnits: 5000),
        _tx(id: 't2', accountId: 'a1', type: TransactionType.expense, minorUnits: 2000),
        _tx(
          id: 't3',
          accountId: 'a1',
          destinationAccountId: 'a2',
          type: TransactionType.transfer,
          minorUnits: 999999, // deliberately huge — must not leak into either total
        ),
      ];
      final MoneyTotals totals =
          FinanceEngine.incomeExpenseTotals(txs, currencyCode: 'USD');
      expect(totals.income, Money.fromMinorUnits(5000, 'USD'));
      expect(totals.expense, Money.fromMinorUnits(2000, 'USD'));
    });

    test('release gate: deleted transactions are excluded from totals', () {
      final List<LedgerTransaction> txs = <LedgerTransaction>[
        _tx(id: 't1', accountId: 'a1', type: TransactionType.expense, minorUnits: 2000, isDeleted: true),
      ];
      final MoneyTotals totals =
          FinanceEngine.incomeExpenseTotals(txs, currencyCode: 'USD');
      expect(totals.expense, Money.zero('USD'));
    });

    test('scoping to a currency excludes transactions in other currencies', () {
      final List<LedgerTransaction> txs = <LedgerTransaction>[
        _tx(id: 't1', accountId: 'a1', type: TransactionType.expense, minorUnits: 2000, currency: 'USD'),
        _tx(id: 't2', accountId: 'a1', type: TransactionType.expense, minorUnits: 999999, currency: 'JPY'),
      ];
      final MoneyTotals totals =
          FinanceEngine.incomeExpenseTotals(txs, currencyCode: 'USD');
      expect(totals.expense, Money.fromMinorUnits(2000, 'USD'));
    });

    test('date-range filtering is inclusive of the boundaries and UTC-based', () {
      final List<LedgerTransaction> txs = <LedgerTransaction>[
        _tx(
          id: 't1',
          accountId: 'a1',
          type: TransactionType.expense,
          minorUnits: 100,
          occurredAtUtc: DateTime.utc(2026, 1, 1),
        ),
        _tx(
          id: 't2',
          accountId: 'a1',
          type: TransactionType.expense,
          minorUnits: 200,
          occurredAtUtc: DateTime.utc(2026, 2, 1),
        ),
        _tx(
          id: 't3',
          accountId: 'a1',
          type: TransactionType.expense,
          minorUnits: 400,
          occurredAtUtc: DateTime.utc(2026, 3, 1),
        ),
      ];
      final MoneyTotals totals = FinanceEngine.incomeExpenseTotals(
        txs,
        currencyCode: 'USD',
        fromUtc: DateTime.utc(2026, 1, 1),
        toUtc: DateTime.utc(2026, 2, 1),
      );
      expect(totals.expense, Money.fromMinorUnits(300, 'USD'));
    });
  });

  group('FinanceEngine.categoryTotals', () {
    test('groups by category and excludes transfers', () {
      final List<LedgerTransaction> txs = <LedgerTransaction>[
        _tx(id: 't1', accountId: 'a1', type: TransactionType.expense, minorUnits: 1000, categoryId: 'food'),
        _tx(id: 't2', accountId: 'a1', type: TransactionType.expense, minorUnits: 500, categoryId: 'food'),
        _tx(id: 't3', accountId: 'a1', type: TransactionType.expense, minorUnits: 200, categoryId: 'transport'),
        _tx(
          id: 't4',
          accountId: 'a1',
          destinationAccountId: 'a2',
          type: TransactionType.transfer,
          minorUnits: 999999,
          categoryId: null,
        ),
      ];
      final Map<String?, Money> totals =
          FinanceEngine.categoryTotals(txs, currencyCode: 'USD');
      expect(totals['food'], Money.fromMinorUnits(-1500, 'USD'));
      expect(totals['transport'], Money.fromMinorUnits(-200, 'USD'));
      expect(totals.containsKey(null), isFalse);
    });

    test('uncategorized transactions group under the null key', () {
      final List<LedgerTransaction> txs = <LedgerTransaction>[
        _tx(id: 't1', accountId: 'a1', type: TransactionType.expense, minorUnits: 1000),
      ];
      final Map<String?, Money> totals =
          FinanceEngine.categoryTotals(txs, currencyCode: 'USD');
      expect(totals[null], Money.fromMinorUnits(-1000, 'USD'));
    });
  });

  group('FinanceEngine.dailySpendingPace', () {
    test('zero spend yields a zero pace in the same currency, not null or an error', () {
      final Money pace = FinanceEngine.dailySpendingPace(
        monthToDateExpense: Money.zero('USD'),
        daysElapsedInclusive: 15,
      );
      expect(pace, Money.zero('USD'));
      expect(pace.isZero, isTrue);
    });

    test('divides by the elapsed day count using truncating integer division', () {
      // 1000 minor units / 3 days = 333.33... -> truncates to 333, not
      // rounded to 333 or up to 334 -- deterministic floor division,
      // never floating point.
      final Money pace = FinanceEngine.dailySpendingPace(
        monthToDateExpense: Money.fromMinorUnits(1000, 'USD'),
        daysElapsedInclusive: 3,
      );
      expect(pace, Money.fromMinorUnits(333, 'USD'));
    });

    test('on the 1st of the month, 1 elapsed day means pace equals the full spend so far', () {
      final Money pace = FinanceEngine.dailySpendingPace(
        monthToDateExpense: Money.fromMinorUnits(5000, 'USD'),
        daysElapsedInclusive: 1,
      );
      expect(pace, Money.fromMinorUnits(5000, 'USD'));
    });

    test('works correctly for a zero-decimal currency (JPY)', () {
      final Money pace = FinanceEngine.dailySpendingPace(
        monthToDateExpense: Money.fromMinorUnits(100, 'JPY'),
        daysElapsedInclusive: 4,
      );
      expect(pace, Money.fromMinorUnits(25, 'JPY'));
      expect(pace.toMajorUnitsString(), '25'); // no decimal point for JPY
    });

    test('rejects daysElapsedInclusive < 1 rather than dividing by zero or going negative', () {
      expect(
        () => FinanceEngine.dailySpendingPace(
          monthToDateExpense: Money.fromMinorUnits(100, 'USD'),
          daysElapsedInclusive: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => FinanceEngine.dailySpendingPace(
          monthToDateExpense: Money.fromMinorUnits(100, 'USD'),
          daysElapsedInclusive: -1,
        ),
        throwsArgumentError,
      );
    });
  });

  group('FinanceEngine.categoryExpenseTotal', () {
    test('sums only expense transactions in the matching category', () {
      final List<LedgerTransaction> txs = <LedgerTransaction>[
        _tx(id: 't1', accountId: 'a1', type: TransactionType.expense, minorUnits: 2000, categoryId: 'dining'),
        _tx(id: 't2', accountId: 'a1', type: TransactionType.expense, minorUnits: 500, categoryId: 'dining'),
      ];
      final Money total = FinanceEngine.categoryExpenseTotal(
        txs,
        currencyCode: 'USD',
        categoryId: 'dining',
      );
      expect(total, Money.fromMinorUnits(2500, 'USD'));
    });

    test('excludes an unrelated category', () {
      final List<LedgerTransaction> txs = <LedgerTransaction>[
        _tx(id: 't1', accountId: 'a1', type: TransactionType.expense, minorUnits: 2000, categoryId: 'dining'),
        _tx(id: 't2', accountId: 'a1', type: TransactionType.expense, minorUnits: 9000, categoryId: 'groceries'),
      ];
      final Money total = FinanceEngine.categoryExpenseTotal(
        txs,
        currencyCode: 'USD',
        categoryId: 'dining',
      );
      expect(total, Money.fromMinorUnits(2000, 'USD'));
    });

    test('excludes a transfer even when it happens to carry a matching categoryId', () {
      final List<LedgerTransaction> txs = <LedgerTransaction>[
        _tx(
          id: 't1',
          accountId: 'a1',
          destinationAccountId: 'a2',
          type: TransactionType.transfer,
          minorUnits: 5000,
          categoryId: 'dining',
        ),
      ];
      final Money total = FinanceEngine.categoryExpenseTotal(
        txs,
        currencyCode: 'USD',
        categoryId: 'dining',
      );
      expect(total, Money.zero('USD'));
    });

    test('excludes income in the same category', () {
      final List<LedgerTransaction> txs = <LedgerTransaction>[
        _tx(id: 't1', accountId: 'a1', type: TransactionType.income, minorUnits: 5000, categoryId: 'dining'),
        _tx(id: 't2', accountId: 'a1', type: TransactionType.expense, minorUnits: 1200, categoryId: 'dining'),
      ];
      final Money total = FinanceEngine.categoryExpenseTotal(
        txs,
        currencyCode: 'USD',
        categoryId: 'dining',
      );
      expect(total, Money.fromMinorUnits(1200, 'USD'));
    });

    test('exact-category-only matching: a transaction filed under a different id is never included, '
        'even conceptually related categories', () {
      final List<LedgerTransaction> txs = <LedgerTransaction>[
        _tx(id: 't1', accountId: 'a1', type: TransactionType.expense, minorUnits: 700, categoryId: 'dining-fastfood'),
      ];
      final Money total = FinanceEngine.categoryExpenseTotal(
        txs,
        currencyCode: 'USD',
        categoryId: 'dining',
      );
      expect(total, Money.zero('USD'));
    });

    test('respects the currency scope, ignoring same-category spend in a different currency', () {
      final List<LedgerTransaction> txs = <LedgerTransaction>[
        _tx(id: 't1', accountId: 'a1', type: TransactionType.expense, minorUnits: 3000, currency: 'JPY', categoryId: 'dining'),
        _tx(id: 't2', accountId: 'a1', type: TransactionType.expense, minorUnits: 1000, currency: 'USD', categoryId: 'dining'),
      ];
      final Money total = FinanceEngine.categoryExpenseTotal(
        txs,
        currencyCode: 'USD',
        categoryId: 'dining',
      );
      expect(total, Money.fromMinorUnits(1000, 'USD'));
    });
  });

  group('FinanceEngine.categoryExpenseTotals', () {
    test('only expense transactions are included', () {
      final List<LedgerTransaction> txs = <LedgerTransaction>[
        _tx(id: 't1', accountId: 'a1', type: TransactionType.expense, minorUnits: 1500, categoryId: 'dining'),
        _tx(id: 't2', accountId: 'a1', type: TransactionType.income, minorUnits: 90000, categoryId: 'dining'),
      ];
      final Map<String?, Money> totals = FinanceEngine.categoryExpenseTotals(txs, currencyCode: 'USD');
      expect(totals['dining'], Money.fromMinorUnits(1500, 'USD'));
    });

    test('income is excluded -- a category with income but no expense never appears in the result', () {
      final List<LedgerTransaction> txs = <LedgerTransaction>[
        _tx(id: 't1', accountId: 'a1', type: TransactionType.income, minorUnits: 90000, categoryId: 'salary'),
      ];
      final Map<String?, Money> totals = FinanceEngine.categoryExpenseTotals(txs, currencyCode: 'USD');
      expect(totals.containsKey('salary'), isFalse);
      expect(totals, isEmpty);
    });

    test('transfers are excluded, even one carrying a categoryId', () {
      final List<LedgerTransaction> txs = <LedgerTransaction>[
        _tx(
          id: 't1',
          accountId: 'a1',
          destinationAccountId: 'a2',
          type: TransactionType.transfer,
          minorUnits: 5000,
          categoryId: 'dining',
        ),
      ];
      final Map<String?, Money> totals = FinanceEngine.categoryExpenseTotals(txs, currencyCode: 'USD');
      expect(totals, isEmpty);
    });

    test('totals are grouped by category correctly, keeping unrelated categories separate', () {
      final List<LedgerTransaction> txs = <LedgerTransaction>[
        _tx(id: 't1', accountId: 'a1', type: TransactionType.expense, minorUnits: 1000, categoryId: 'dining'),
        _tx(id: 't2', accountId: 'a1', type: TransactionType.expense, minorUnits: 2000, categoryId: 'groceries'),
      ];
      final Map<String?, Money> totals = FinanceEngine.categoryExpenseTotals(txs, currencyCode: 'USD');
      expect(totals['dining'], Money.fromMinorUnits(1000, 'USD'));
      expect(totals['groceries'], Money.fromMinorUnits(2000, 'USD'));
      expect(totals.length, 2);
    });

    test('uncategorized expense transactions group under the null key, matching categoryTotals\' own '
        'uncategorized-key convention', () {
      final List<LedgerTransaction> txs = <LedgerTransaction>[
        _tx(id: 't1', accountId: 'a1', type: TransactionType.expense, minorUnits: 800),
      ];
      final Map<String?, Money> totals = FinanceEngine.categoryExpenseTotals(txs, currencyCode: 'USD');
      expect(totals[null], Money.fromMinorUnits(800, 'USD'));
    });

    test('multiple transactions in the same category are summed, not overwritten', () {
      final List<LedgerTransaction> txs = <LedgerTransaction>[
        _tx(id: 't1', accountId: 'a1', type: TransactionType.expense, minorUnits: 500, categoryId: 'dining'),
        _tx(id: 't2', accountId: 'a1', type: TransactionType.expense, minorUnits: 700, categoryId: 'dining'),
        _tx(id: 't3', accountId: 'a1', type: TransactionType.expense, minorUnits: 300, categoryId: 'dining'),
      ];
      final Map<String?, Money> totals = FinanceEngine.categoryExpenseTotals(txs, currencyCode: 'USD');
      expect(totals['dining'], Money.fromMinorUnits(1500, 'USD'));
    });

    test('empty input returns an empty map, never null and never a fabricated entry', () {
      final Map<String?, Money> totals =
          FinanceEngine.categoryExpenseTotals(<LedgerTransaction>[], currencyCode: 'USD');
      expect(totals, isEmpty);
    });

    test('respects the currency scope -- same-category spend in a different currency is never mixed '
        'into the requested currency\'s total', () {
      final List<LedgerTransaction> txs = <LedgerTransaction>[
        _tx(id: 't1', accountId: 'a1', type: TransactionType.expense, minorUnits: 3000, currency: 'JPY', categoryId: 'dining'),
        _tx(id: 't2', accountId: 'a1', type: TransactionType.expense, minorUnits: 1000, currency: 'USD', categoryId: 'dining'),
      ];
      final Map<String?, Money> totals = FinanceEngine.categoryExpenseTotals(txs, currencyCode: 'USD');
      expect(totals['dining'], Money.fromMinorUnits(1000, 'USD'));
    });

    test('each entry is plain Money in the requested currency, and agrees exactly with the '
        'single-category categoryExpenseTotal -- never a second, diverging calculation', () {
      final List<LedgerTransaction> txs = <LedgerTransaction>[
        _tx(id: 't1', accountId: 'a1', type: TransactionType.expense, minorUnits: 2500, currency: 'JPY', categoryId: 'transport'),
        _tx(id: 't2', accountId: 'a1', type: TransactionType.expense, minorUnits: 1500, currency: 'JPY', categoryId: 'transport'),
      ];
      final Map<String?, Money> totals = FinanceEngine.categoryExpenseTotals(txs, currencyCode: 'JPY');
      final Money bulkTotal = totals['transport']!;
      final Money singleTotal = FinanceEngine.categoryExpenseTotal(
        txs,
        currencyCode: 'JPY',
        categoryId: 'transport',
      );
      expect(bulkTotal, singleTotal);
      expect(bulkTotal.currencyCode, 'JPY');
    });
  });

  group('FinanceEngine.recommendedDailySpend', () {
    test('splits a positive remaining evenly across the remaining days, truncating', () {
      final Money rec = FinanceEngine.recommendedDailySpend(
        remaining: Money.fromMinorUnits(1000, 'USD'),
        remainingDaysInclusive: 3,
      );
      expect(rec, Money.fromMinorUnits(333, 'USD'));
    });

    test('zero remaining recommends zero, never a negative or fabricated allowance', () {
      final Money rec = FinanceEngine.recommendedDailySpend(
        remaining: Money.zero('USD'),
        remainingDaysInclusive: 10,
      );
      expect(rec, Money.zero('USD'));
    });

    test('negative remaining (overspent) recommends zero, never a negative daily allowance', () {
      final Money rec = FinanceEngine.recommendedDailySpend(
        remaining: Money.fromMinorUnits(-500, 'USD'),
        remainingDaysInclusive: 10,
      );
      expect(rec, Money.zero('USD'));
    });

    test('on the last day of the month (1 remaining day), the whole remaining amount is recommended', () {
      final Money rec = FinanceEngine.recommendedDailySpend(
        remaining: Money.fromMinorUnits(4200, 'USD'),
        remainingDaysInclusive: 1,
      );
      expect(rec, Money.fromMinorUnits(4200, 'USD'));
    });

    test('rejects remainingDaysInclusive < 1 for a positive remaining rather than dividing by zero', () {
      expect(
        () => FinanceEngine.recommendedDailySpend(
          remaining: Money.fromMinorUnits(100, 'USD'),
          remainingDaysInclusive: 0,
        ),
        throwsArgumentError,
      );
    });

    test('a zero-decimal currency (JPY) truncates in whole yen', () {
      final Money rec = FinanceEngine.recommendedDailySpend(
        remaining: Money.fromMinorUnits(100, 'JPY'),
        remainingDaysInclusive: 3,
      );
      expect(rec, Money.fromMinorUnits(33, 'JPY'));
    });
  });

  group('FinanceEngine.projectedMonthEndSpend', () {
    test('multiplies before dividing, so a small elapsed-day count does not understate the projection', () {
      // 100 minor units over 3 of 30 days: (100 ~/ 3) * 30 == 990 would be
      // wrong; (100 * 30) ~/ 3 == 1000 is correct.
      final Money projected = FinanceEngine.projectedMonthEndSpend(
        spent: Money.fromMinorUnits(100, 'USD'),
        daysElapsedInclusive: 3,
        totalDaysInMonth: 30,
      );
      expect(projected, Money.fromMinorUnits(1000, 'USD'));
    });

    test('day 1 of the month: projection is spent * totalDays', () {
      final Money projected = FinanceEngine.projectedMonthEndSpend(
        spent: Money.fromMinorUnits(50, 'USD'),
        daysElapsedInclusive: 1,
        totalDaysInMonth: 31,
      );
      expect(projected, Money.fromMinorUnits(1550, 'USD'));
    });

    test('zero spending projects to zero', () {
      final Money projected = FinanceEngine.projectedMonthEndSpend(
        spent: Money.zero('USD'),
        daysElapsedInclusive: 15,
        totalDaysInMonth: 30,
      );
      expect(projected, Money.zero('USD'));
    });

    test('a fully elapsed (historical) month projects to exactly the actual spend', () {
      final Money projected = FinanceEngine.projectedMonthEndSpend(
        spent: Money.fromMinorUnits(12345, 'USD'),
        daysElapsedInclusive: 30,
        totalDaysInMonth: 30,
      );
      expect(projected, Money.fromMinorUnits(12345, 'USD'));
    });

    test('rejects zero elapsed days -- callers must not invoke this for a future month', () {
      expect(
        () => FinanceEngine.projectedMonthEndSpend(
          spent: Money.zero('USD'),
          daysElapsedInclusive: 0,
          totalDaysInMonth: 30,
        ),
        throwsArgumentError,
      );
    });

    test('refuses to silently overflow the signed 64-bit minor-units range', () {
      expect(
        () => FinanceEngine.projectedMonthEndSpend(
          spent: Money.fromMinorUnits(9223372036854775807, 'USD'),
          daysElapsedInclusive: 1,
          totalDaysInMonth: 31,
        ),
        throwsStateError,
      );
    });
  });

  group('FinanceEngine.recommendedDailyContribution', () {
    test('ceiling regression case: 100 remaining over 3 days -> 34, not floor\'s 33', () {
      final Money recommended = FinanceEngine.recommendedDailyContribution(
        remaining: Money.fromMinorUnits(100, 'USD'),
        remainingDaysInclusive: 3,
      );
      expect(recommended, Money.fromMinorUnits(34, 'USD'));
      // 33 * 3 == 99 would fall short of 100 -- floor is provably
      // insufficient for a savings-goal pace; 34 * 3 == 102 >= 100.
    });

    test('evenly divisible remaining needs no rounding up', () {
      final Money recommended = FinanceEngine.recommendedDailyContribution(
        remaining: Money.fromMinorUnits(300, 'USD'),
        remainingDaysInclusive: 3,
      );
      expect(recommended, Money.fromMinorUnits(100, 'USD'));
    });

    test('1 remaining day recommends the entire remaining amount', () {
      final Money recommended = FinanceEngine.recommendedDailyContribution(
        remaining: Money.fromMinorUnits(500, 'USD'),
        remainingDaysInclusive: 1,
      );
      expect(recommended, Money.fromMinorUnits(500, 'USD'));
    });

    test('zero remaining recommends zero', () {
      final Money recommended = FinanceEngine.recommendedDailyContribution(
        remaining: Money.zero('USD'),
        remainingDaysInclusive: 10,
      );
      expect(recommended, Money.zero('USD'));
    });

    test('negative remaining (defensive -- callers should already clamp) recommends zero, not a negative pace', () {
      final Money recommended = FinanceEngine.recommendedDailyContribution(
        remaining: Money.fromMinorUnits(-500, 'USD'),
        remainingDaysInclusive: 10,
      );
      expect(recommended, Money.zero('USD'));
    });

    test('rejects zero remaining days -- today always counts as at least 1', () {
      expect(
        () => FinanceEngine.recommendedDailyContribution(
          remaining: Money.fromMinorUnits(100, 'USD'),
          remainingDaysInclusive: 0,
        ),
        throwsArgumentError,
      );
    });

    test('does not overflow near the signed 64-bit boundary', () {
      final Money recommended = FinanceEngine.recommendedDailyContribution(
        remaining: Money.fromMinorUnits(9223372036854775807, 'USD'),
        remainingDaysInclusive: 2,
      );
      // ceil(9223372036854775807 / 2) = 4611686018427387904.
      expect(recommended, Money.fromMinorUnits(4611686018427387904, 'USD'));
    });
  });
}
