/// Thrown by `ChequeBookRepository.requireActive`/`ChequeRepository
/// .recordIssued` when a named `ChequeBooks` id does not exist, or
/// exists but is closed (`deletedAt != null`) -- a closed chequebook can
/// never be the target of a NEW issued cheque, matching
/// `PaymentInstrumentRepository`'s identical "archived instrument is
/// not selectable for a new attribution" precedent.
class ChequeBookNotFoundException implements Exception {
  const ChequeBookNotFoundException(this.chequeBookId);

  final String chequeBookId;

  @override
  String toString() => 'ChequeBookNotFoundException: no active cheque book $chequeBookId';
}
