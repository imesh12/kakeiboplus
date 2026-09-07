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
import 'transaction_icon_badge.dart';
import 'transaction_providers.dart';

const MoneyFormatter _formatter = MoneyFormatter();

/// Read-only detail for one transaction, with edit and delete entry
/// points — Beta 1 Transaction UX (`docs/14_DECISION_LOG.md` ADR-025).
/// Checkpoint 4 (Phase B) modernizes this screen's visual presentation
/// only -- a header block (icon badge + type + category + the amount as
/// the primary visual element) above a restyled metadata section. Every
/// read path, the edit/delete actions, and the unavailable state are
/// unchanged from Phase A/Checkpoint 3.
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
    final ColorScheme colors = Theme.of(context).colorScheme;
    final AsyncValue<List<AccountRow>> accountsAsync = ref.watch(accountsProvider);

    final bool isTransfer = tx.type == 'transfer';

    // A transfer never carries a category (ADR-025 Correction 2), so
    // there is nothing for it to resolve here -- watching
    // `categoriesForTypeProvider('transfer')` for a transfer would just
    // be an unused subscription (confirmed unnecessary by the
    // Checkpoint 4 audit). `ref.watch` calls aren't order-sensitive the
    // way React hooks are, so branching on `isTransfer` (stable for the
    // lifetime of this widget, since it's derived from `tx.type`, which
    // never changes on an existing row) is safe here.
    final AsyncValue<List<CategoryRow>>? categoriesAsync =
        isTransfer ? null : ref.watch(categoriesForTypeProvider(tx.type));

    final Map<String, String> accountNames = <String, String>{
      for (final AccountRow a in accountsAsync.valueOrNull ?? const <AccountRow>[]) a.id: a.name,
    };
    // Keyed by id -> the full row (not just the name), so the header can
    // also read `CategoryRow.icon` for `TransactionIconBadge` -- still
    // derived entirely from the same `categoriesForTypeProvider` watch
    // this screen already had; no new provider, no new query.
    final Map<String, CategoryRow> categoriesById = <String, CategoryRow>{
      for (final CategoryRow c in categoriesAsync?.valueOrNull ?? const <CategoryRow>[]) c.id: c,
    };
    final CategoryRow? category =
        (isTransfer || tx.categoryId == null) ? null : categoriesById[tx.categoryId];

    final Money amount = Money.fromMinorUnits(tx.amountMinorUnits, tx.currencyCode);
    // Sign/formatting convention is byte-for-byte unchanged from before
    // Checkpoint 4 -- '+' income, '' transfer, '-' expense; Money is
    // still built only from `tx.amountMinorUnits`/`tx.currencyCode`, no
    // conversion, no relabeling.
    final String amountPrefix = switch (tx.type) {
      'income' => '+',
      'transfer' => '',
      _ => '-',
    };
    // ColorScheme-driven for every type, including income -- Checkpoint
    // 4 replaces the previous hardcoded `Colors.green` with
    // `colors.primary`, matching the convention Activity (Checkpoint 2)
    // already established.
    final Color amountColor = switch (tx.type) {
      'income' => colors.primary,
      'transfer' => colors.onSurfaceVariant,
      _ => colors.error,
    };
    final String typeLabel = switch (tx.type) {
      'income' => 'Income',
      'transfer' => 'Transfer',
      _ => 'Expense',
    };
    // Preserves the exact existing fallback text: no categoryId at all
    // -> 'None'; a categoryId that doesn't resolve (deleted/unrecognized)
    // -> '—'; otherwise the resolved name.
    final String categoryDisplayValue =
        tx.categoryId == null ? 'None' : (category?.name ?? '—');

    final String formattedAmount = _formatter.format(amount);
    // Spoken sign, independent of the visual '+'/'-'/none prefix and of
    // amountColor -- "don't rely on color alone" extends to the amount
    // too, matching Activity's row convention.
    final String spokenAmount = switch (tx.type) {
      'income' => 'plus $formattedAmount',
      'transfer' => formattedAmount,
      _ => 'minus $formattedAmount',
    };

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _DetailHeader(
          type: tx.type,
          typeLabel: typeLabel,
          // Only shown in the header when it's an actual resolved
          // category -- unlike the metadata row below, the header omits
          // the line entirely rather than showing 'None'/'—', since it's
          // meant to read as "category, when there is one" up front.
          categoryName: isTransfer ? null : category?.name,
          categoryIconName: isTransfer ? null : category?.icon,
          amountColor: amountColor,
          amountPrefix: amountPrefix,
          formattedAmount: formattedAmount,
          spokenAmount: spokenAmount,
        ),
        const SizedBox(height: 24),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colors.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: <Widget>[
                if (isTransfer) ...<Widget>[
                  _DetailRow(label: 'From', value: accountNames[tx.accountId] ?? '—'),
                  const Divider(height: 1),
                  _DetailRow(
                    label: 'To',
                    value: tx.destinationAccountId == null
                        ? '—'
                        : (accountNames[tx.destinationAccountId] ?? '—'),
                  ),
                  const Divider(height: 1),
                ] else ...<Widget>[
                  _DetailRow(label: 'Account', value: accountNames[tx.accountId] ?? '—'),
                  const Divider(height: 1),
                  _DetailRow(label: 'Category', value: categoryDisplayValue),
                  const Divider(height: 1),
                ],
                _DetailRow(
                  label: 'Date',
                  value: DateFormat.yMMMd().add_jm().format(tx.occurredAt.toLocal()),
                ),
                if (tx.note != null && tx.note!.isNotEmpty) ...<Widget>[
                  const Divider(height: 1),
                  _DetailRow(label: 'Note', value: tx.note!),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The header block above the metadata card: [TransactionIconBadge] +
/// type label + (expense/income only) category name, with the amount as
/// the largest, most visually prominent element -- Checkpoint 4's
/// "make amount the primary visual element" requirement.
///
/// Purely presentational -- every value it renders is already resolved
/// by [_TransactionDetailBody]; this widget makes no provider/repository
/// calls of its own.
class _DetailHeader extends StatelessWidget {
  const _DetailHeader({
    required this.type,
    required this.typeLabel,
    required this.categoryName,
    required this.categoryIconName,
    required this.amountColor,
    required this.amountPrefix,
    required this.formattedAmount,
    required this.spokenAmount,
  });

  /// `'expense'` | `'income'` | `'transfer'` -- `Transaction.type`,
  /// forwarded to [TransactionIconBadge] unchanged.
  final String type;
  final String typeLabel;

  /// Null for a transfer (a transfer is never categorized) or an
  /// expense/income with no resolved category -- the header shows the
  /// category line only when there's an actual name to show.
  final String? categoryName;

  /// Null for a transfer, or for an expense/income with no category
  /// (or an unresolved one) -- forwarded to [TransactionIconBadge],
  /// which already falls back safely (via `categoryIconFor`, or to the
  /// plain type icon when this is null).
  final String? categoryIconName;
  final Color amountColor;
  final String amountPrefix;
  final String formattedAmount;
  final String spokenAmount;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        // The icon/color pairing is never the only signal for
        // transaction type -- `typeLabel` below is always visible text,
        // and this Semantics label makes the same information available
        // non-visually, matching Activity's established
        // "don't rely on color alone" pattern for its own row icons.
        Semantics(
          label: typeLabel,
          child: TransactionIconBadge(
            type: type,
            color: amountColor,
            categoryIconName: categoryIconName,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          typeLabel,
          style: text.labelLarge?.copyWith(
            color: colors.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        if (categoryName != null) ...<Widget>[
          const SizedBox(height: 2),
          Text(
            categoryName!,
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
        const SizedBox(height: 8),
        // `excludeSemantics: true` so the spoken sign ("plus"/"minus")
        // replaces the visual '+'/'-' glyph for a screen reader rather
        // than both being announced -- avoids the noisy/duplicate
        // semantics Checkpoint 4 explicitly asks to avoid.
        Semantics(
          label: spokenAmount,
          excludeSemantics: true,
          child: Text(
            '$amountPrefix$formattedAmount',
            key: const Key('transactionDetailAmount'),
            style: text.headlineLarge?.copyWith(color: amountColor, fontWeight: FontWeight.bold),
          ),
        ),
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
      padding: const EdgeInsets.symmetric(vertical: 12),
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
