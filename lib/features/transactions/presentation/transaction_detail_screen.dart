import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/providers.dart';
import '../../../core/money/money.dart';
import '../../../core/money/money_formatter.dart';
import '../../../core/routing/app_routes.dart';
import '../../accounts/presentation/account_providers.dart';
import '../../categories/presentation/category_providers.dart';
import 'transaction_providers.dart';

const MoneyFormatter _formatter = MoneyFormatter();

/// Read-only detail for one transaction, with edit and delete entry
/// points — Beta 1 Transaction UX (`docs/14_DECISION_LOG.md` ADR-025).
///
/// Mirrors `GoalDetailScreen`'s "no longer available" + confirm-delete
/// pattern (ADR-022) for the same reason: a soft-deleted or nonexistent
/// [transactionId] must resolve to an explicit unavailable state below
/// the UI layer, not stale data — `transactionByIdProvider` already
/// guarantees this; this screen just renders what it's given.
class TransactionDetailScreen extends ConsumerWidget {
  const TransactionDetailScreen({required this.transactionId, super.key});
  final String transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Transaction?> txAsync = ref.watch(transactionByIdProvider(transactionId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction'),
        actions: <Widget>[
          if (txAsync.valueOrNull != null) ...<Widget>[
            IconButton(
              key: const Key('editTransaction'),
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit',
              onPressed: () => context.push(AppRoutes.editTransaction(transactionId)),
            ),
            IconButton(
              key: const Key('deleteTransaction'),
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: () => _confirmDelete(context, ref),
            ),
          ],
        ],
      ),
      body: txAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace st) =>
            Center(child: Text('Could not load this transaction: $e')),
        data: (Transaction? tx) {
          if (tx == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'This transaction is no longer available.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return _TransactionDetailBody(tx: tx);
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Delete this transaction?'),
        content: const Text(
          'It will no longer count toward any balance, budget, or total.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirmDeleteTransaction'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(transactionRepositoryProvider).softDelete(transactionId);
      if (context.mounted) context.pop();
    }
  }
}

class _TransactionDetailBody extends ConsumerWidget {
  const _TransactionDetailBody({required this.tx});
  final Transaction tx;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final AsyncValue<List<AccountRow>> accountsAsync = ref.watch(accountsProvider);
    final AsyncValue<List<CategoryRow>> categoriesAsync =
        ref.watch(categoriesForTypeProvider(tx.type));

    final Map<String, String> accountNames = <String, String>{
      for (final AccountRow a in accountsAsync.valueOrNull ?? const <AccountRow>[]) a.id: a.name,
    };
    final Map<String, String> categoryNames = <String, String>{
      for (final CategoryRow c in categoriesAsync.valueOrNull ?? const <CategoryRow>[]) c.id: c.name,
    };

    final bool isTransfer = tx.type == 'transfer';
    final Money amount = Money.fromMinorUnits(tx.amountMinorUnits, tx.currencyCode);
    final String amountPrefix = switch (tx.type) {
      'income' => '+',
      'transfer' => '',
      _ => '-',
    };
    final Color amountColor = switch (tx.type) {
      'income' => Colors.green,
      'transfer' => colors.onSurfaceVariant,
      _ => colors.error,
    };
    final String typeLabel = switch (tx.type) {
      'income' => 'Income',
      'transfer' => 'Transfer',
      _ => 'Expense',
    };

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Text(
          '$amountPrefix${_formatter.format(amount)}',
          key: const Key('transactionDetailAmount'),
          style: text.headlineMedium?.copyWith(color: amountColor, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(typeLabel, style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant)),
        const SizedBox(height: 16),
        if (isTransfer) ...<Widget>[
          _DetailRow(label: 'From', value: accountNames[tx.accountId] ?? '—'),
          _DetailRow(
            label: 'To',
            value: tx.destinationAccountId == null
                ? '—'
                : (accountNames[tx.destinationAccountId] ?? '—'),
          ),
        ] else ...<Widget>[
          _DetailRow(label: 'Account', value: accountNames[tx.accountId] ?? '—'),
          _DetailRow(
            label: 'Category',
            value: tx.categoryId == null ? 'None' : (categoryNames[tx.categoryId] ?? '—'),
          ),
        ],
        _DetailRow(
          label: 'Date',
          value: DateFormat.yMMMd().add_jm().format(tx.occurredAt.toLocal()),
        ),
        if (tx.note != null && tx.note!.isNotEmpty) _DetailRow(label: 'Note', value: tx.note!),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(label, style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant)),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
