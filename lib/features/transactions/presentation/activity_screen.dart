import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/finance/transaction_type.dart';
import '../../../core/money/money.dart';
import '../../../core/money/money_formatter.dart';
import '../../../core/routing/app_routes.dart';
import '../../accounts/presentation/account_providers.dart';
import '../../categories/presentation/category_providers.dart';
import '../domain/activity_date_group.dart';
import '../domain/activity_filter.dart';
import 'activity_filter_provider.dart';
import 'transaction_icon_badge.dart';
import 'transaction_providers.dart';

const MoneyFormatter _formatter = MoneyFormatter();

/// Transaction history — the Beta 0 "Activity" tab. Shows every active
/// (non-deleted) transaction for the current profile, newest first,
/// grouped by date -- Beta 1 Transaction UX Phase B, Checkpoint 2
/// (`docs/14_DECISION_LOG.md` ADR-025/026). Checkpoint 3 adds
/// deterministic local search and transaction-type filters on top of
/// that grouped list.
///
/// Still derives its list from [activeTransactionsProvider] only -- no
/// new Drift query. Grouping/date-labeling logic lives in
/// `activity_date_group.dart` (Checkpoint 1); search/filter matching
/// logic lives in `activity_filter.dart` (Checkpoint 1) via
/// [activityFilterProvider]'s screen-local state -- this screen only
/// resolves account/category names and hands already-resolved values to
/// those pure helpers, it never reimplements matching rules itself.
class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  // Owned directly by this State (rather than synced from provider state
  // during build) so Clear search/Clear filters can mutate the visible
  // field synchronously inside their own button handlers -- see
  // `activity_filter_provider.dart`'s doc comment for why a plain
  // `StateProvider.autoDispose` is enough for the state itself.
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _updateQuery(String value) {
    ref.read(activityFilterProvider.notifier).update((ActivityFilterState s) => s.copyWith(query: value));
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(activityFilterProvider.notifier).update((ActivityFilterState s) => s.copyWith(query: ''));
  }

  void _clearFilters() {
    _searchController.clear();
    ref.read(activityFilterProvider.notifier).state = ActivityFilterState.initial;
  }

  void _toggleType(TransactionType type, bool selected) {
    final ActivityFilterState current = ref.read(activityFilterProvider);
    final Set<TransactionType> updated = Set<TransactionType>.of(current.types);
    if (selected) {
      updated.add(type);
    } else {
      updated.remove(type);
    }
    ref.read(activityFilterProvider.notifier).state = current.copyWith(types: updated);
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Transaction>> transactionsAsync = ref.watch(activeTransactionsProvider);
    final AsyncValue<List<AccountRow>> accountsAsync = ref.watch(accountsProvider);
    final AsyncValue<List<CategoryRow>> expenseCategoriesAsync =
        ref.watch(categoriesForTypeProvider('expense'));
    final AsyncValue<List<CategoryRow>> incomeCategoriesAsync =
        ref.watch(categoriesForTypeProvider('income'));
    final ActivityFilterState filter = ref.watch(activityFilterProvider);

    final Map<String, String> accountNames = <String, String>{
      for (final AccountRow a in accountsAsync.valueOrNull ?? const <AccountRow>[]) a.id: a.name,
    };
    // Keyed by id -> the full row (not just the name) so the icon badge
    // can also read `CategoryRow.icon` -- still derived entirely from
    // the same two existing providers Activity already watched before
    // Checkpoint 2; no new provider, no new query.
    final Map<String, CategoryRow> categoriesById = <String, CategoryRow>{
      for (final CategoryRow c in expenseCategoriesAsync.valueOrNull ?? const <CategoryRow>[]) c.id: c,
      for (final CategoryRow c in incomeCategoriesAsync.valueOrNull ?? const <CategoryRow>[]) c.id: c,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Activity')),
      body: transactionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace st) => Center(child: Text('Could not load transactions: $e')),
        data: (List<Transaction> transactions) {
          if (transactions.isEmpty) {
            // Activity's true empty state (zero transactions ever) --
            // unchanged from Checkpoint 2, with no search/filter UI at
            // all: search is meaningless when there's nothing to search,
            // and this keeps that state byte-for-byte what it was before
            // Checkpoint 3.
            return const Center(child: Text('No transactions yet. Tap Add to record one.'));
          }

          // Resolve each transaction into Checkpoint 1's
          // `ActivitySearchable` -- exactly the five documented fields
          // (category name, source account name, destination account
          // name, note, formatted amount), using the SAME `_formatter`
          // instance/convention the rows below render with, and
          // deliberately without the sign prefix (matches
          // `ActivitySearchable.formattedAmount`'s own contract).
          final List<ActivitySearchable<Transaction>> searchable = <ActivitySearchable<Transaction>>[
            for (final Transaction tx in transactions)
              ActivitySearchable<Transaction>(
                item: tx,
                type: TransactionType.values.byName(tx.type),
                accountName: accountNames[tx.accountId] ?? '—',
                formattedAmount:
                    _formatter.format(Money.fromMinorUnits(tx.amountMinorUnits, tx.currencyCode)),
                categoryName: tx.categoryId == null ? null : categoriesById[tx.categoryId]?.name,
                destinationAccountName:
                    tx.destinationAccountId == null ? null : accountNames[tx.destinationAccountId],
                note: tx.note,
              ),
          ];
          // `filterActivity` preserves order and is a no-op copy when
          // `filter` isn't active -- no new sort/ranking is introduced.
          final List<ActivitySearchable<Transaction>> filtered = filterActivity(searchable, filter);

          return Column(
            children: <Widget>[
              _SearchAndFilterBar(
                controller: _searchController,
                filter: filter,
                onQueryChanged: _updateQuery,
                onClearSearch: _clearSearch,
                onClearFilters: _clearFilters,
                onToggleType: _toggleType,
              ),
              Expanded(
                child: filtered.isEmpty
                    ? _NoMatchingTransactions(onClearFilters: _clearFilters)
                    : _GroupedTransactionList(
                        transactions: <Transaction>[
                          for (final ActivitySearchable<Transaction> row in filtered) row.item,
                        ],
                        accountNames: accountNames,
                        categoriesById: categoriesById,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The search field + Expense/Income/Transfer filter chips + (when a
/// filter is active) "Clear filters" row, shown below the Activity
/// AppBar whenever there's at least one transaction. Purely
/// presentational -- all state lives in [ActivityScreen]'s
/// [activityFilterProvider] watch and the callbacks passed in here.
class _SearchAndFilterBar extends StatelessWidget {
  const _SearchAndFilterBar({
    required this.controller,
    required this.filter,
    required this.onQueryChanged,
    required this.onClearSearch,
    required this.onClearFilters,
    required this.onToggleType,
  });

  final TextEditingController controller;
  final ActivityFilterState filter;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearSearch;
  final VoidCallback onClearFilters;
  final void Function(TransactionType type, bool selected) onToggleType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
            controller: controller,
            onChanged: onQueryChanged,
            decoration: InputDecoration(
              labelText: 'Search transactions',
              hintText: 'Search by category, account, note, or amount',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: filter.query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: 'Clear search',
                      onPressed: onClearSearch,
                    )
                  : null,
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              _TypeFilterChip(
                label: 'Expense',
                type: TransactionType.expense,
                selected: filter.types.contains(TransactionType.expense),
                onSelected: onToggleType,
              ),
              _TypeFilterChip(
                label: 'Income',
                type: TransactionType.income,
                selected: filter.types.contains(TransactionType.income),
                onSelected: onToggleType,
              ),
              _TypeFilterChip(
                label: 'Transfer',
                type: TransactionType.transfer,
                selected: filter.types.contains(TransactionType.transfer),
                onSelected: onToggleType,
              ),
              if (filter.isActive)
                TextButton(
                  onPressed: onClearFilters,
                  child: const Text('Clear filters'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One Expense/Income/Transfer selectable filter chip. Wraps the
/// built-in [FilterChip] rather than a custom widget -- it already
/// renders a checkmark on its selected state (a non-color signal) and
/// already exposes `Semantics(selected: ...)`, so this satisfies "color
/// is not the only selected-state signal" and "each filter chip exposes
/// selected state" without reinventing either.
class _TypeFilterChip extends StatelessWidget {
  const _TypeFilterChip({
    required this.label,
    required this.type,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final TransactionType type;
  final bool selected;
  final void Function(TransactionType type, bool selected) onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (bool value) => onSelected(type, value),
    );
  }
}

/// Shown when there's at least one active transaction but the current
/// search/filter narrows the list to zero -- distinct from
/// [ActivityScreen]'s true empty state, which is for zero transactions
/// overall.
class _NoMatchingTransactions extends StatelessWidget {
  const _NoMatchingTransactions({required this.onClearFilters});

  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.search_off, size: 40, color: colors.onSurfaceVariant),
          const SizedBox(height: 12),
          const Text('No matching transactions'),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onClearFilters,
            child: const Text('Clear filters'),
          ),
        ],
      ),
    );
  }
}

/// The date-grouped, scrollable transaction list -- identical grouping
/// and row rendering to Checkpoint 2, just fed [transactions] that have
/// already passed the current search/filter rather than the raw
/// unfiltered list.
class _GroupedTransactionList extends StatelessWidget {
  const _GroupedTransactionList({
    required this.transactions,
    required this.accountNames,
    required this.categoriesById,
  });

  final List<Transaction> transactions;
  final Map<String, String> accountNames;
  final Map<String, CategoryRow> categoriesById;

  @override
  Widget build(BuildContext context) {
    // `transactions` is already newest-first
    // (`TransactionRepository.watchActiveForProfile`'s own ORDER BY,
    // preserved through `filterActivity`'s order-preserving filtering) --
    // grouping preserves that order, it never re-sorts.
    final List<ActivityDateSection<Transaction>> sections = groupByActivityDate<Transaction>(
      items: transactions,
      occurredAtLocalOf: (Transaction tx) => tx.occurredAt.toLocal(),
      now: DateTime.now(),
    );

    // Flattened once per build into header/row entries so the
    // `ListView.builder` below stays a single simple linear list (no
    // index-math per section) -- cheap at Beta-scale list sizes and easy
    // to reason about/test.
    final List<Object> flatItems = <Object>[
      for (final ActivityDateSection<Transaction> section in sections) ...<Object>[
        section.group,
        ...section.items,
      ],
    ];

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: flatItems.length,
      itemBuilder: (BuildContext context, int index) {
        final Object entry = flatItems[index];
        if (entry is ActivityDateGroup) {
          return _DateSectionHeader(group: entry);
        }
        final Transaction tx = entry as Transaction;
        return _TransactionRow(
          tx: tx,
          accountName: accountNames[tx.accountId] ?? '—',
          destinationAccountName:
              tx.destinationAccountId == null ? null : accountNames[tx.destinationAccountId],
          category: tx.categoryId == null ? null : categoriesById[tx.categoryId],
        );
      },
    );
  }
}

class _DateSectionHeader extends StatelessWidget {
  const _DateSectionHeader({required this.group});

  final ActivityDateGroup group;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Semantics(
        header: true,
        excludeSemantics: true,
        label: '${group.label} transactions',
        child: Text(
          group.label.toUpperCase(),
          style: text.labelSmall?.copyWith(
            color: colors.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({
    required this.tx,
    required this.accountName,
    required this.destinationAccountName,
    required this.category,
  });

  final Transaction tx;
  final String accountName;
  final String? destinationAccountName;
  final CategoryRow? category;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final Money amount = Money.fromMinorUnits(tx.amountMinorUnits, tx.currencyCode);
    final bool isTransfer = tx.type == 'transfer';

    // Amount sign convention is unchanged from before this checkpoint --
    // '+' income, '' transfer, '-' expense.
    final String amountPrefix = switch (tx.type) {
      'income' => '+',
      'transfer' => '',
      _ => '-',
    };
    // ColorScheme-driven, not a hardcoded `Colors.*` constant -- three
    // distinct roles so expense/income/transfer each read differently
    // even before considering the icon or sign prefix below.
    final Color amountColor = switch (tx.type) {
      'income' => colors.primary,
      'transfer' => colors.onSurfaceVariant,
      _ => colors.error,
    };
    final String typeWord = switch (tx.type) {
      'income' => 'Income',
      'transfer' => 'Transfer',
      _ => 'Expense',
    };

    final String title = switch (tx.type) {
      'transfer' => '$accountName → ${destinationAccountName ?? '—'}',
      _ => category?.name ?? typeWord,
    };
    // Date is intentionally NOT repeated here -- it's now conveyed by
    // the section header above this row.
    final String subtitle = <String?>[
      if (!isTransfer) accountName,
      if (tx.note != null && tx.note!.isNotEmpty) tx.note,
    ].nonNulls.join(' · ');

    final String formattedAmount = _formatter.format(amount);
    // Spoken sign, independent of the visual '+'/'-'/none prefix and of
    // amountColor -- part of "don't rely on color alone".
    final String spokenAmount = switch (tx.type) {
      'income' => 'plus $formattedAmount',
      'transfer' => formattedAmount,
      _ => 'minus $formattedAmount',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ListTile(
          onTap: () => context.push(AppRoutes.transactionDetail(tx.id)),
          leading: Semantics(
            label: typeWord,
            child: TransactionIconBadge(
              type: tx.type,
              color: amountColor,
              categoryIconName: isTransfer ? null : category?.icon,
            ),
          ),
          title: Text(title, style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
          subtitle: subtitle.isEmpty
              ? null
              : Text(subtitle, style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
          trailing: Semantics(
            label: spokenAmount,
            excludeSemantics: true,
            child: Text(
              '$amountPrefix$formattedAmount',
              style: text.bodyLarge?.copyWith(color: amountColor, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}
