/// Thrown by [CreditFacilityRepository] when a lookup requiring an
/// active `CreditFacilityDetails` row finds none for the given account
/// -- either no facility was ever created for it, or it exists but is
/// soft-deleted -- the same discipline `AccountNotFoundException`/
/// `PaymentInstrumentNotFoundException` already apply to their own
/// repositories.
class CreditFacilityNotFoundException implements Exception {
  const CreditFacilityNotFoundException(this.accountId);

  final String accountId;

  @override
  String toString() =>
      'CreditFacilityNotFoundException: no active credit facility for account $accountId';
}
