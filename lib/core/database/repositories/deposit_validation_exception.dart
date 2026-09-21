/// Thrown by `DepositRepository.createDetails` for a relational/domain
/// validation failure -- mirrors `CreditFacilityValidationException`'s
/// identical role for `CreditFacilityDetails`. Covers: wrong
/// `balanceClass` (must be asset), wrong `subtype` (must be `deposit`),
/// an inactive/deleted account, account/profile ownership mismatch, a
/// deposit already existing for the account,
/// `interestDestinationAccountId` ownership/currency mismatch, an
/// explicit `maturityDate` that disagrees with the computed one, and
/// `compoundingFrequency`/installment-field gating mismatches
/// (`interestMethod`/`depositType` inconsistency). Argument-SHAPE errors
/// (a negative rate, a term number less than 1) throw a plain
/// [ArgumentError] instead, matching this codebase's existing convention
/// for isolated argument-shape checks (see `CreditFacilityRepository
/// .createFacility`'s identical split). Currency mismatches use the
/// shared `CurrencyMismatchException`, not this type.
class DepositValidationException implements Exception {
  const DepositValidationException(this.message);

  final String message;

  @override
  String toString() => 'DepositValidationException: $message';
}
