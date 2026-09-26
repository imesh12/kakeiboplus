/// Thrown by `ChequeRepository`'s lookup/lifecycle methods
/// (`requireById`/`markCleared`/`markBounced`/`markStopped`/
/// `markCancelled`/`deletePending`) when a named `Cheques` id does not
/// exist, or exists but is already soft-deleted.
class ChequeNotFoundException implements Exception {
  const ChequeNotFoundException(this.chequeId);

  final String chequeId;

  @override
  String toString() => 'ChequeNotFoundException: no active cheque $chequeId';
}
