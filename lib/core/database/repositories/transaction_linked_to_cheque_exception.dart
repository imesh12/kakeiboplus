/// Thrown by [TransactionRepository]'s mutation methods --
/// `updateExpense`/`updateIncome`/`updateTransfer`/`softDelete` -- when
/// [transactionId] is the linked posting of a CLEARED cheque (see
/// `Cheques.transactionId`'s own doc). Checkpoint N's integrity repair:
/// `ChequeRepository.markCleared` posts exactly one ordinary
/// [Transactions] row and stores its id as the cleared cheque's
/// permanent record of what it posted; ordinary transaction
/// edit/transfer/delete APIs must never be allowed to silently change
/// or remove that row while the cheque still claims
/// `ChequeStatus.cleared` -- a cleared cheque's own status is only
/// true for as long as its linked transaction is exactly what was
/// posted.
///
/// Checked directly against `cheques` (querying the table, not going
/// through a `ChequeRepository` instance) -- the same
/// "no repository-to-repository constructor dependency for a
/// read-only guard" convention
/// `TransactionRepository._validatePaymentInstrumentAttribution`
/// already established for `payment_instruments`; it also avoids an
/// actual circular dependency, since `ChequeRepository` itself depends
/// on `TransactionRepository` (`markCleared` calls
/// `recordExpense`/`recordIncome`).
///
/// Deliberately keys off [ChequeStatus.cleared] alone, never
/// `Cheques.deletedAt` -- see
/// `TransactionRepository._requireNotChequeLinked`'s own doc for why a
/// (currently unreachable in V1) soft-deleted-but-cleared cheque row
/// should still protect its linked transaction rather than silently
/// stop.
///
/// There is deliberately no "unlink"/"unclear" operation on
/// `ChequeRepository` in V1 (see `ChequeStatus`'s own doc for the
/// frozen transition table) -- a cleared cheque's transaction is not
/// editable through either side of the link.
class TransactionLinkedToChequeException implements Exception {
  const TransactionLinkedToChequeException({required this.transactionId, required this.chequeId});

  /// The transaction the caller tried to edit, transfer-update, or
  /// soft-delete.
  final String transactionId;

  /// The cleared `Cheques` row whose [Cheques.transactionId] names
  /// [transactionId].
  final String chequeId;

  @override
  String toString() =>
      'TransactionLinkedToChequeException: transaction $transactionId is the posted '
      'transaction for cleared cheque $chequeId and cannot be edited, transferred, or '
      'deleted directly';
}
