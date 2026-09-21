/// Thrown by [PaymentInstrumentRepository] when [instrumentId] either
/// doesn't exist, is soft-deleted, or (in an unreachable-in-practice
/// race) no longer matches what the caller expected at write time --
/// the same discipline `AccountNotFoundException`/
/// `TransactionNotFoundException` already apply to their own
/// repositories' edits.
///
/// Never thrown for a *historical* lookup of an archived instrument --
/// see `PaymentInstrumentRepository.findByIdIncludingDeleted` (an
/// archived instrument must remain resolvable for historical
/// transaction attribution, per the Checkpoint D brief's lifecycle
/// section). This is thrown only for operations that require an
/// *active* instrument: new-instrument metadata updates, soft-delete,
/// and new-transaction attribution.
class PaymentInstrumentNotFoundException implements Exception {
  const PaymentInstrumentNotFoundException(this.instrumentId);

  final String instrumentId;

  @override
  String toString() =>
      'PaymentInstrumentNotFoundException: no active payment instrument with id $instrumentId';
}
