/// Thrown by [TransactionRepository] when a caller supplies a
/// `paymentInstrumentId` that cannot validly attribute the transaction
/// being recorded -- see the Checkpoint D brief's "transaction /
/// instrument consistency" section.
///
/// Covers exactly three cases (each given as [reason]):
///
/// - the instrument's linked `accountId` does not match the
///   transaction's own `accountId` (V1 source-attribution rule: for a
///   transfer, `paymentInstrumentId` represents the SOURCE instrument,
///   so it must link to the same account the transfer draws from --
///   there is no separate destination-instrument concept in V1);
/// - the instrument does not belong to the same profile as the
///   transaction;
/// - the instrument is soft-deleted -- a caller may not attribute a
///   *new* transaction to an already-archived instrument, even though a
///   transaction attributed to it *before* it was archived remains
///   valid (see `PaymentInstrumentRepository`'s own lifecycle doc).
///
/// This exception has zero effect on accounting: `paymentInstrumentId`
/// is metadata `FinanceEngine`/`LedgerTransaction` never see (see the
/// Checkpoint D brief's "validation boundary" section) -- rejecting an
/// invalid attribution here only ever prevents a transaction row from
/// being *written* with bad metadata; it never changes a balance, an
/// income/expense total, or a transfer's arithmetic.
class InvalidPaymentInstrumentAttributionException implements Exception {
  const InvalidPaymentInstrumentAttributionException(this.instrumentId, this.reason);

  final String instrumentId;
  final String reason;

  @override
  String toString() =>
      'InvalidPaymentInstrumentAttributionException: payment instrument '
      '$instrumentId cannot attribute this transaction -- $reason';
}
