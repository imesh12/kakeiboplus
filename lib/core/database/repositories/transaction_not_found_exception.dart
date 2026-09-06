/// Thrown by [TransactionRepository]'s update methods when [transactionId]
/// either doesn't exist, is soft-deleted, or (in an unreachable-in-practice
/// race) no longer matches the type the caller expected at write time.
///
/// Never a silent no-op: an edit the UI believes succeeded must never be
/// one that changed nothing underneath it. See
/// `docs/14_DECISION_LOG.md` ADR-025.
class TransactionNotFoundException implements Exception {
  const TransactionNotFoundException(this.transactionId);

  final String transactionId;

  @override
  String toString() =>
      'TransactionNotFoundException: no active transaction with id $transactionId';
}
