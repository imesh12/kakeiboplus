import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/money/money.dart';
import '../../../core/money/money_formatter.dart';
import '../../../core/routing/app_routes.dart';
import '../../accounts/presentation/account_providers.dart';
import '../../categories/presentation/category_providers.dart';
import 'transaction_providers.dart';

const MoneyFormatter _formatter = MoneyFormatter();

/// Transaction history — the Beta 0 "Activity" tab. Shows every active
/// (non-deleted) transaction for the current profile, newest first.
class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Transaction>> transactionsAsync = ref.watch(activeTransactionsProvider);
    final AsyncValue<List<AccountRow>> accountsAsync = ref.watch(accountsProvider);
    final AsyncValue<List<CategoryRow>> expenseCategoriesAsync =
        ref.watch(categoriesForTypeProvider('expense'));
    final AsyncValue<List<CategoryRow>> incomeCategoriesAsync =
        ref.watch(categoriesForTypeProvider('income'));

    final Map<String, String> accountNames = <String, String>{
      for (final AccountRow a in accountsAsync.valueOrNull ?? const <AccountRow>[]) a.id: a.name,
    };
    final Map<String, String> categoryNames = <String, String>{
      for (final CategoryRow c in expenseCategoriesAsync.valueOrNull ?? const <CategoryRow>[])
        c.id: c.name,
      for (final CategoryRow c in incomeCategoriesAsync.valueOrNull ?? const <CategoryRow>[])
        c.id: c.name,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Activity')),
      body: transactionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace st) => Center(child: Text('Could not load transactions: $e')),
        data: (List<Transaction> transactions) {
          if (transactions.isEmpty) {
            return const Center(child: Text('No transactions yet. Tap Add to record one.'));
          }
          return ListView.builder(
            itemCount: transactions.length,
            itemBuilder: (BuildContext context, int index) {
              final Transaction tx = transactions[index];
              return _TransactionTile(
                tx: tx,
                accountName: accountNames[tx.accountId] ?? '—',
                destinationAccountName:
                    tx.destinationAccountId == null ? null : accountNames[tx.destinationAccountId],
                categoryName: tx.categoryId == null ? null : categoryNames[tx.categoryId],
              );
            },
          );
        },
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.tx,
    required this.accountName,
    required this.destinationAccountName,
    required this.categoryName,
  });

  final Transaction tx;
  final String accountName;
  final String? destinationAccountName;
  final String? categoryName;

  @override
  Widget build(BuildContext context) {
    final Money amount = Money.fromMinorUnits(tx.amountMinorUnits, tx.currencyCode);
    final bool isTransfer = tx.type == 'transfer';
    final bool isIncome = tx.type == 'income';

    final String title = switch (tx.type) {
      'transfer' => '$accountName → ${destinationAccountName ?? '—'}',
      _ => categoryName ?? (isIncome ? 'Income' : 'Expense'),
    };
    final String subtitle = <String?>[
      if (!isTransfer) accountName,
      DateFormat.yMMMd().format(tx.occurredAt.toLocal()),
      if (tx.note != null && tx.note!.isNotEmpty) tx.note,
    ].nonNulls.join(' · ');

    final Color amountColor = switch (tx.type) {
      'income' => Colors.green,
      'transfer' => Theme.of(context).colorScheme.onSurfaceVariant,
      _ => Theme.of(context).colorScheme.error,
    };
    final String amountPrefix = switch (tx.type) {
      'income' => '+',
      'transfer' => '',
      _ => '-',
    };

    return ListTile(
      onTap: () => context.push(AppRoutes.transactionDetail(tx.id)),
      leading: Icon(isTransfer ? Icons.swap_horiz : (isIncome ? Icons.add : Icons.remove)),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Text(
        '$amountPrefix${_formatter.format(amount)}',
        style: TextStyle(color: amountColor, fontWeight: FontWeight.bold),
      ),
    );
  }
}
