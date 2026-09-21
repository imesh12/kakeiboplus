/// Thrown by [CreditFacilityRepository.createFacility] when the
/// requested facility would violate one of docs/20 §12.1's relational
/// invariants -- see that method's own doc for the full validation
/// list.
///
/// Covers exactly four cases (each given as [reason]):
///
/// - the linked account's `balanceClass` is not [BalanceClass.liability];
/// - the linked account's `subtype` is not
///   [FinancialAccountSubtype.creditCard];
/// - the linked account does not belong to the same profile as the
///   facility being created;
/// - a `CreditFacilityDetails` row already exists for that account (the
///   one-facility-per-account invariant, docs/20 §12.1) -- the database
///   also enforces this via `CreditFacilityDetails.accountId`'s
///   `unique()` constraint, but this exception is what a caller actually
///   sees, thrown by this repository's own pre-check;
/// - an optional `linkedPaymentAccountId` does not exist or does not
///   belong to the same profile.
///
/// A negative credit limit, or an out-of-range `statementClosingDay`/
/// `dueDay`, is deliberately NOT represented here -- those throw a plain
/// [ArgumentError], matching this codebase's existing convention for
/// isolated argument-shape checks (e.g.
/// `PaymentInstrumentRepository._validateLast4`). A currency mismatch
/// between the supplied credit limit and the linked account throws the
/// shared `CurrencyMismatchException` instead, matching
/// `AccountRepository.createAccount`'s own precedent for a mismatched
/// `Money` argument. This exception is reserved for the four relational/
/// domain checks above.
class CreditFacilityValidationException implements Exception {
  const CreditFacilityValidationException(this.reason);

  final String reason;

  @override
  String toString() => 'CreditFacilityValidationException: $reason';
}
