/// Thrown by `ChequeRepository.markCleared`/`markBounced`/`markStopped`/
/// `markCancelled`/`deletePending` when the requested transition is not
/// valid from the cheque's CURRENT status -- see `ChequeStatus`'s own
/// doc for the full, frozen transition table this enforces (every
/// terminal status is reachable only from `ChequeStatus.pending`;
/// `markStopped` additionally rejects a `ChequeDirection.received`
/// cheque). The check that throws this is re-run INSIDE the same
/// `AppDatabase.transaction` block that performs the transition -- see
/// that repository's own doc -- so calling `markCleared` (or any other
/// transition) twice on the same cheque always throws this on the
/// second call rather than posting a second `Transactions` row.
class ChequeLifecycleException implements Exception {
  const ChequeLifecycleException(this.message);

  final String message;

  @override
  String toString() => 'ChequeLifecycleException: $message';
}
