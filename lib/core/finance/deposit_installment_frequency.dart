/// `DepositDetails.installmentFrequency` -- docs/20 §12.9, only
/// meaningful for `depositType: recurring`. Purely descriptive in V1:
/// this checkpoint stores a recurring deposit's declared installment
/// cadence but does NOT schedule, post, or project against it (docs/20
/// §12.9 / this checkpoint's own "RECURRING DEPOSIT SCOPE" -- no
/// automatic contributions, no missed-installment logic). Deliberately
/// a small, generic set rather than a bank-specific taxonomy -- exactly
/// the installment cadences a recurring/installment deposit product
/// commonly declares, nothing more invented for this V1 slice.
///
/// [fromStorageValue] throws rather than falls back -- see
/// [DepositType]'s doc for why.
enum DepositInstallmentFrequency {
  weekly('weekly'),
  monthly('monthly'),
  quarterly('quarterly'),
  yearly('yearly');

  const DepositInstallmentFrequency(this.storageValue);

  final String storageValue;

  static DepositInstallmentFrequency fromStorageValue(String value) {
    return DepositInstallmentFrequency.values.firstWhere(
      (DepositInstallmentFrequency frequency) => frequency.storageValue == value,
      orElse: () =>
          throw FormatException('Unrecognized DepositInstallmentFrequency storage value: $value'),
    );
  }
}
