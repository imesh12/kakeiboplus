import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import 'add_transaction_screen.dart';
import 'transaction_providers.dart';

/// Resolves [transactionId] to a live [Transaction] row and hands it to
/// [AddTransactionScreen] in edit mode -- Beta 1 Transaction UX
/// (`docs/14_DECISION_LOG.md` ADR-025). A thin id-to-row lookup only:
/// all of the actual edit form/validation/save behavior lives in
/// [AddTransactionScreen], which this screen reuses rather than
/// duplicating (see that class's doc comment).
///
/// If [transactionId] no longer names an active transaction -- soft
/// deleted, or never existed -- resolves to an explicit "no longer
/// available" state rather than opening an edit form for nothing, the
/// same convention `GoalDetailScreen`/`TransactionDetailScreen` use.
class EditTransactionScreen extends ConsumerWidget {
  const EditTransactionScreen({required this.transactionId, super.key});
  final String transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Transaction?> txAsync = ref.watch(transactionByIdProvider(transactionId));

    return txAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Edit transaction')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (Object e, StackTrace st) => Scaffold(
        appBar: AppBar(title: const Text('Edit transaction')),
        body: Center(child: Text('Could not load this transaction: $e')),
      ),
      data: (Transaction? tx) {
        if (tx == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Edit transaction')),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'This transaction is no longer available.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        return AddTransactionScreen(existingTransaction: tx);
      },
    );
  }
}
