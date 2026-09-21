/// Thrown by `DepositRepository.requireActiveForAccount` when [accountId]
/// has no active `DepositDetails` row -- mirrors
/// `CreditFacilityNotFoundException`'s identical role for
/// `CreditFacilityDetails`.
class DepositNotFoundException implements Exception {
  const DepositNotFoundException(this.accountId);

  final String accountId;

  @override
  String toString() => 'DepositNotFoundException: no active deposit details for account $accountId';
}
