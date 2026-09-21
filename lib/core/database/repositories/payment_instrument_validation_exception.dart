/// Thrown by [PaymentInstrumentRepository.createInstrument] when the
/// requested instrument would violate one of the foundation's relational
/// invariants -- see that method's own doc for the full validation list.
///
/// Covers exactly three cases (each given as [reason]):
///
/// - the linked account's `BalanceClass` isn't one [instrumentType]
///   permits (e.g. a `creditCard` linked to an asset account, or a
///   `debitCard` linked to a liability account) -- see the Checkpoint D
///   brief's "account-class / type validation" section;
/// - the linked account does not belong to the same profile as the
///   instrument being created;
/// - the optional linked institution does not belong to the same
///   profile as the instrument being created.
///
/// Simple input-shape problems (`last4` not exactly 4 digits, an
/// incomplete or out-of-range expiry) are deliberately NOT represented
/// here -- they throw a plain [ArgumentError], matching this codebase's
/// existing convention for isolated argument-shape checks (e.g.
/// `TransactionRepository._insert`'s non-positive-amount check). This
/// exception is reserved for the relational/domain checks above.
class PaymentInstrumentValidationException implements Exception {
  const PaymentInstrumentValidationException(this.reason);

  final String reason;

  @override
  String toString() => 'PaymentInstrumentValidationException: $reason';
}
