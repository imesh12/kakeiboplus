import 'package:ai_financial_coach/core/finance/transaction_type.dart';
import 'package:ai_financial_coach/features/transactions/domain/activity_filter.dart';
import 'package:flutter_test/flutter_test.dart';

// Beta 1 Transaction UX Phase B, Checkpoint 1 (`docs/14_DECISION_LOG.md`
// ADR-025/026). Locked product decisions this file proves: an empty
// `types` set means "show all types" (never "show none"); search is
// case-insensitive deterministic substring matching over exactly five
// fields (category name, source account name, destination account name,
// note, formatted amount); no fuzzy matching; no ranking/reordering.

void main() {
  const ActivitySearchable<int> groceriesExpense = ActivitySearchable<int>(
    item: 1,
    type: TransactionType.expense,
    accountName: 'JPY Wallet',
    formattedAmount: '¥1,200',
    categoryName: 'Groceries',
    note: 'Weekly shop',
  );
  const ActivitySearchable<int> salaryIncome = ActivitySearchable<int>(
    item: 2,
    type: TransactionType.income,
    accountName: 'JPY Wallet',
    formattedAmount: '¥500,000',
    categoryName: 'Salary',
  );
  const ActivitySearchable<int> transfer = ActivitySearchable<int>(
    item: 3,
    type: TransactionType.transfer,
    accountName: 'JPY Wallet',
    destinationAccountName: 'LKR Savings',
    formattedAmount: '¥10,000',
    // Transfers carry no category -- ADR-025 Correction 2.
  );
  final List<ActivitySearchable<int>> all = <ActivitySearchable<int>>[
    groceriesExpense,
    salaryIncome,
    transfer,
  ];

  group('ActivityFilterState', () {
    test('initial state is inactive -- no query, no type filter', () {
      expect(ActivityFilterState.initial.isActive, isFalse);
      expect(ActivityFilterState.initial.query, '');
      expect(ActivityFilterState.initial.types, isEmpty);
    });

    test('an empty types set means "show all types", not "show none"', () {
      const ActivityFilterState state = ActivityFilterState(types: <TransactionType>{});
      expect(state.types, isEmpty);
      // isActive only reflects whether a query is set, since the empty
      // set is the neutral/all-types state, not itself a narrowing filter.
      expect(state.isActive, isFalse);
    });

    test('a whitespace-only query is not considered active', () {
      const ActivityFilterState state = ActivityFilterState(query: '   ');
      expect(state.isActive, isFalse);
    });

    test('copyWith replaces only the given field', () {
      const ActivityFilterState state = ActivityFilterState(
        query: 'lunch',
        types: <TransactionType>{TransactionType.expense},
      );
      final ActivityFilterState queryChanged = state.copyWith(query: 'dinner');
      expect(queryChanged.query, 'dinner');
      expect(queryChanged.types, <TransactionType>{TransactionType.expense});

      final ActivityFilterState typesChanged = state.copyWith(types: <TransactionType>{});
      expect(typesChanged.query, 'lunch');
      expect(typesChanged.types, isEmpty);
    });

    test('equality is by value, not identity', () {
      const ActivityFilterState a = ActivityFilterState(
        query: 'x',
        types: <TransactionType>{TransactionType.income, TransactionType.expense},
      );
      const ActivityFilterState b = ActivityFilterState(
        query: 'x',
        types: <TransactionType>{TransactionType.expense, TransactionType.income},
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('filterActivity / matchesActivityFilter', () {
    test('an inactive filter returns every row, unchanged order', () {
      expect(filterActivity(all, ActivityFilterState.initial), all);
    });

    test('empty types set shows every type', () {
      final List<ActivitySearchable<int>> result = filterActivity(
        all,
        const ActivityFilterState(),
      );
      expect(result, all);
    });

    test('a single selected type narrows to just that type', () {
      final List<ActivitySearchable<int>> result = filterActivity(
        all,
        const ActivityFilterState(types: <TransactionType>{TransactionType.transfer}),
      );
      expect(result, <ActivitySearchable<int>>[transfer]);
    });

    test('multiple selected types are OR-ed together', () {
      final List<ActivitySearchable<int>> result = filterActivity(
        all,
        const ActivityFilterState(
          types: <TransactionType>{TransactionType.expense, TransactionType.income},
        ),
      );
      expect(result, <ActivitySearchable<int>>[groceriesExpense, salaryIncome]);
    });

    test('search matches category name, case-insensitively', () {
      final List<ActivitySearchable<int>> result = filterActivity(
        all,
        const ActivityFilterState(query: 'GROCER'),
      );
      expect(result, <ActivitySearchable<int>>[groceriesExpense]);
    });

    test('search matches the source account name', () {
      final List<ActivitySearchable<int>> result = filterActivity(
        all,
        const ActivityFilterState(query: 'jpy wallet'),
      );
      expect(result, all); // every fixture shares this account name
    });

    test('search matches the destination account name (transfers only)', () {
      final List<ActivitySearchable<int>> result = filterActivity(
        all,
        const ActivityFilterState(query: 'lkr'),
      );
      expect(result, <ActivitySearchable<int>>[transfer]);
    });

    test('search matches the note', () {
      final List<ActivitySearchable<int>> result = filterActivity(
        all,
        const ActivityFilterState(query: 'weekly'),
      );
      expect(result, <ActivitySearchable<int>>[groceriesExpense]);
    });

    test('search matches the formatted amount', () {
      final List<ActivitySearchable<int>> result = filterActivity(
        all,
        const ActivityFilterState(query: '500,000'),
      );
      expect(result, <ActivitySearchable<int>>[salaryIncome]);
    });

    test('a null category/note/destination never matches as a substring of "null"', () {
      // salaryIncome and transfer both have at least one null searchable
      // field -- confirms the matcher skips nulls rather than stringifying
      // them (which would make every row match a search for "null").
      final List<ActivitySearchable<int>> result = filterActivity(
        all,
        const ActivityFilterState(query: 'null'),
      );
      expect(result, isEmpty);
    });

    test('type filter and search combine with AND, not OR', () {
      final List<ActivitySearchable<int>> result = filterActivity(
        all,
        const ActivityFilterState(
          query: 'jpy wallet', // matches all three
          types: <TransactionType>{TransactionType.income},
        ),
      );
      expect(result, <ActivitySearchable<int>>[salaryIncome]);
    });

    test('no match returns an empty, not null, result', () {
      final List<ActivitySearchable<int>> result = filterActivity(
        all,
        const ActivityFilterState(query: 'nonexistent'),
      );
      expect(result, isEmpty);
    });

    test('result order is preserved -- no ranking/reordering', () {
      final List<ActivitySearchable<int>> result = filterActivity(
        all,
        const ActivityFilterState(query: 'jpy'),
      );
      expect(result, all); // same order as the input, not re-sorted by relevance
    });

    test('the returned list is unmodifiable', () {
      final List<ActivitySearchable<int>> result = filterActivity(all, ActivityFilterState.initial);
      expect(() => result.add(transfer), throwsUnsupportedError);
    });
  });
}
