/// Thrown by [TransactionExchangeRateRepository.attach] when
/// [transactionId] already has a historical FX snapshot attached.
///
/// A newer market rate becoming available must never rewrite an existing
/// transaction's historical conversion (`docs/14_DECISION_LOG.md`
/// ADR-010) -- this exception is what makes that true by construction:
/// there is no update/replace path on the repository at all, only
/// [TransactionExchangeRateRepository.attach], which refuses a second
/// attach rather than overwriting the first.
class FxSnapshotAlreadyExistsException implements Exception {
  const FxSnapshotAlreadyExistsException(this.transactionId);

  final String transactionId;

  @override
  String toString() =>
      'FxSnapshotAlreadyExistsException: transaction $transactionId already has a '
      'historical FX snapshot -- it is immutable and is never replaced (ADR-010).';
}
