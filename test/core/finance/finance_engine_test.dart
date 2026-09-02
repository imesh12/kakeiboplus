import 'package:ai_financial_coach/core/finance/finance_engine.dart';
import 'package:ai_financial_coach/core/finance/ledger_models.dart';
import 'package:ai_financial_coach/core/finance/transaction_type.dart';
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
      );
      expect(FinanceEngine.accountBalance(account, []), Money.fromMinorUnits(10000, 'USD'));
    });

    test('expense decreases balance, income increases it', () {
      final LedgerAccount account = LedgerAccount(
        id: 'a1',
        currencyCode: 'USD',
        openingBalance: Money.fromMinorUnits(10000, 'USD'),
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
      );
      final LedgerAccount destination = LedgerAccount(
        id: 'dst',
        currencyCode: 'USD',
        openingBalance: Money.fromMinorUnits(0, 'USD'),
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
      );
      final List<LedgerTransaction> txs = <LedgerTransaction>[
        _tx(id: 't1', accountId: 'other', type: TransactionType.expense, minorUnits: 999999),
      ];
      expect(FinanceEngine.accountBalance(account, txs), Money.fromMinorUnits(10000, 'USD'));
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
}
