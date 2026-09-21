/// `DepositDetails.interestMethod` -- docs/20 §12.1/§12.8. Directly
/// selects which of `DepositCalculator`'s two formulas applies, and
/// gates whether `compoundingFrequency` is required ([compound]) or must
/// be absent ([simple]) -- see `DepositRepository.createDetails`.
///
/// [fromStorageValue] throws rather than falls back on an unrecognized
/// value -- see [DepositType]'s doc for why: this brand-new table has no
/// legacy data to tolerate, and this value directly selects which
/// interest formula runs, where a silently-wrong fallback would silently
/// misstate a financial calculation.
enum DepositInterestMethod {
  simple('simple'),
  compound('compound');

  const DepositInterestMethod(this.storageValue);

  final String storageValue;

  static DepositInterestMethod fromStorageValue(String value) {
    return DepositInterestMethod.values.firstWhere(
      (DepositInterestMethod method) => method.storageValue == value,
      orElse: () =>
          throw FormatException('Unrecognized DepositInterestMethod storage value: $value'),
    );
  }
}
