import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/providers.dart';
import '../../../core/database/repositories/cheque_lifecycle_exception.dart';
import '../../../core/database/repositories/cheque_not_found_exception.dart';
import '../../../core/database/repositories/cheque_repository.dart' show ChequeRowX;
import '../../../core/finance/cheque_direction.dart';
import '../../../core/finance/cheque_status.dart';
import '../../../core/money/money_formatter.dart';
import '../../../core/routing/app_routes.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_card.dart';
import '../../accounts/presentation/account_providers.dart';
import 'cheque_providers.dart';
import 'cheques_screen.dart' show chequeStatusColor, chequeStatusLabel;

const MoneyFormatter _formatter = MoneyFormatter();

/// Checkpoint N: one cheque's read-only detail, plus its
/// status-appropriate lifecycle action buttons (Clear / Mark bounced /
/// Stop or Cancel / Delete) -- see `ChequeStatus`'s own doc for exactly
/// which actions are valid from which status. A pushed screen with no
/// bottom nav of its own, same "list is a shell destination, detail is
/// not" pattern `AccountDetailScreen`/`GoalDetailScreen` already use.
class ChequeDetailScreen extends ConsumerWidget {
  const ChequeDetailScreen({required this.chequeId, super.key});

  final String chequeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<ChequeRow?> chequeAsync = ref.watch(chequeByIdProvider(chequeId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.chequeDetailTitle)),
      body: chequeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace st) => Center(child: Text(e.toString())),
        data: (ChequeRow? cheque) {
          if (cheque == null) {
            return Center(child: Text(l10n.chequeNoLongerAvailableMessage));
          }
          return _ChequeDetailBody(cheque: cheque);
        },
      ),
    );
  }
}

class _ChequeDetailBody extends ConsumerWidget {
  const _ChequeDetailBody({required this.cheque});

  final ChequeRow cheque;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme colors = Theme.of(context).colorScheme;
    final ChequeDirection direction = cheque.directionValue;
    final ChequeStatus status = cheque.statusValue;

    final List<AccountRow> accounts = ref.watch(allAccountsProvider).valueOrNull ?? const <AccountRow>[];
    String accountName = l10n.unknownAccountLabel;
    for (final AccountRow a in accounts) {
      if (a.id == cheque.accountId) {
        accountName = a.name;
        break;
      }
    }

    String? chequeBookLabel;
    if (cheque.chequeBookId != null) {
      final List<ChequeBookRow> books = ref.watch(allChequeBooksProvider).valueOrNull ?? const <ChequeBookRow>[];
      for (final ChequeBookRow book in books) {
        if (book.id == cheque.chequeBookId) {
          chequeBookLabel = book.label;
          break;
        }
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        AppCard(
          bordered: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                _formatter.format(cheque.amount),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text(
                chequeStatusLabel(l10n, status),
                style: TextStyle(color: chequeStatusColor(colors, status), fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _DetailRow(
                label: direction == ChequeDirection.issued ? l10n.payeeFieldLabel : l10n.payerFieldLabel,
                value: cheque.counterpartyName,
              ),
              _DetailRow(label: l10n.chequeNumberFieldLabel, value: cheque.chequeNumber),
              _DetailRow(label: l10n.accountLabel, value: accountName),
              if (chequeBookLabel != null)
                _DetailRow(label: l10n.chequeBookLabelField, value: chequeBookLabel),
              _DetailRow(label: l10n.issueDateLabel, value: DateFormat.yMMMd().format(cheque.issueDate)),
              if (cheque.receivedDate != null)
                _DetailRow(
                  label: l10n.receivedDateLabel,
                  value: DateFormat.yMMMd().format(cheque.receivedDate!),
                ),
              if (cheque.clearedDate != null)
                _DetailRow(
                  label: l10n.clearedDateLabel,
                  value: DateFormat.yMMMd().format(cheque.clearedDate!),
                ),
              if (cheque.bouncedDate != null)
                _DetailRow(
                  label: l10n.bouncedDateLabel,
                  value: DateFormat.yMMMd().format(cheque.bouncedDate!),
                ),
              if (cheque.stoppedOrCancelledDate != null)
                _DetailRow(
                  label: status == ChequeStatus.stopped ? l10n.stoppedDateLabel : l10n.cancelledDateLabel,
                  value: DateFormat.yMMMd().format(cheque.stoppedOrCancelledDate!),
                ),
              if (cheque.memo != null && cheque.memo!.trim().isNotEmpty)
                _DetailRow(label: l10n.memoOptionalFieldLabel, value: cheque.memo!),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (status == ChequeStatus.cleared && cheque.transactionId != null)
          FilledButton.tonal(
            key: const Key('viewPostedTransaction'),
            onPressed: () => context.push(AppRoutes.transactionDetail(cheque.transactionId!)),
            child: Text(l10n.viewPostedTransactionButton),
          ),
        if (status == ChequeStatus.pending) ..._pendingActions(context, ref, l10n, direction),
      ],
    );
  }

  List<Widget> _pendingActions(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    ChequeDirection direction,
  ) {
    return <Widget>[
      FilledButton(
        key: const Key('markChequeCleared'),
        onPressed: () => _confirmAndRun(
          context: context,
          ref: ref,
          title: l10n.markAsClearedButton,
          onConfirm: (DateTime date) =>
              ref.read(chequeRepositoryProvider).markCleared(chequeId: cheque.id, clearedDateUtc: date.toUtc()),
        ),
        child: Text(l10n.markAsClearedButton),
      ),
      const SizedBox(height: 8),
      OutlinedButton(
        key: const Key('markChequeBounced'),
        onPressed: () => _confirmAndRun(
          context: context,
          ref: ref,
          title: l10n.markAsBouncedButton,
          onConfirm: (DateTime date) =>
              ref.read(chequeRepositoryProvider).markBounced(chequeId: cheque.id, bouncedDateUtc: date.toUtc()),
        ),
        child: Text(l10n.markAsBouncedButton),
      ),
      if (direction == ChequeDirection.issued) ...<Widget>[
        const SizedBox(height: 8),
        OutlinedButton(
          key: const Key('markChequeStopped'),
          onPressed: () => _confirmAndRun(
            context: context,
            ref: ref,
            title: l10n.stopChequeButton,
            onConfirm: (DateTime date) =>
                ref.read(chequeRepositoryProvider).markStopped(chequeId: cheque.id, stoppedDateUtc: date.toUtc()),
          ),
          child: Text(l10n.stopChequeButton),
        ),
      ],
      const SizedBox(height: 8),
      OutlinedButton(
        key: const Key('markChequeCancelled'),
        onPressed: () => _confirmAndRun(
          context: context,
          ref: ref,
          title: l10n.cancelChequeButton,
          onConfirm: (DateTime date) => ref
              .read(chequeRepositoryProvider)
              .markCancelled(chequeId: cheque.id, cancelledDateUtc: date.toUtc()),
        ),
        child: Text(l10n.cancelChequeButton),
      ),
      const SizedBox(height: 8),
      TextButton(
        key: const Key('deletePendingCheque'),
        onPressed: () => _confirmDelete(context, ref, l10n),
        style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
        child: Text(l10n.deleteChequeButton),
      ),
    ];
  }

  Future<void> _confirmAndRun({
    required BuildContext context,
    required WidgetRef ref,
    required String title,
    required Future<void> Function(DateTime date) onConfirm,
  }) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    DateTime pickedDate = DateTime.now();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext innerContext, StateSetter setState) {
          return AlertDialog(
            title: Text(title),
            content: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${l10n.dateLabel}: ${DateFormat.yMMMd().format(pickedDate)}'),
              trailing: TextButton(
                onPressed: () async {
                  final DateTime now = DateTime.now();
                  final DateTime? picked = await showDatePicker(
                    context: innerContext,
                    initialDate: pickedDate,
                    firstDate: DateTime(now.year - 20),
                    lastDate: DateTime(now.year + 5),
                  );
                  if (picked != null) setState(() => pickedDate = picked);
                },
                child: Text(l10n.chooseButton),
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.confirmButton),
              ),
            ],
          );
        },
      ),
    );
    if (confirmed != true) return;
    try {
      await onConfirm(pickedDate);
    } on ChequeLifecycleException catch (e) {
      if (context.mounted) _showError(context, e.message);
    } on ChequeNotFoundException catch (e) {
      if (context.mounted) _showError(context, e.toString());
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, AppLocalizations l10n) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(l10n.deleteChequeButton),
        content: Text(l10n.deleteChequeConfirmationMessage),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.deleteChequeButton),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(chequeRepositoryProvider).deletePending(cheque.id);
      if (context.mounted) context.pop();
    } on ChequeLifecycleException catch (e) {
      if (context.mounted) _showError(context, e.message);
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            flex: 2,
            child: Text(value, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}
