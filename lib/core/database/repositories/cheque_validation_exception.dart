/// Thrown by `ChequeBookRepository.createChequeBook` or
/// `ChequeRepository.recordIssued`/`recordReceived` for a relational/
/// domain validation failure -- mirrors `DepositValidationException`'s/
/// `CreditFacilityValidationException`'s identical role for their own
/// tables. Covers: wrong `balanceClass`/`subtype` (the linked account
/// must be an eligible asset -- `bank` or `savings`), an inactive/
/// deleted account, account/profile ownership mismatch, a closed/
/// wrong-account chequebook, a blank cheque number, and a duplicate
/// issued cheque number within the same chequebook. Currency mismatches
/// use the shared `CurrencyMismatchException`, not this type -- matching
/// `CreditFacilityRepository`/`DepositRepository`'s identical split.
class ChequeValidationException implements Exception {
  const ChequeValidationException(this.message);

  final String message;

  @override
  String toString() => 'ChequeValidationException: $message';
}
