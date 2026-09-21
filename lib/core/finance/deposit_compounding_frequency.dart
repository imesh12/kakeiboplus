/// `DepositDetails.compoundingFrequency` -- docs/20 §12.8's frozen
/// mapping: [monthly] = 12 periods/year, [quarterly] = 4, [semiannual] =
/// 2, [annual] = 1, [atMaturity] = 1 "treated as one compounding period
/// over the whole term -- equivalent to simple interest for that case."
/// Meaningful only when `interestMethod == compound`
/// (`DepositRepository.createDetails` rejects it being set for `simple`,
/// and requires it for `compound`).
///
/// [periodsPerYear] is `n` in docs/20 §12.8's
/// `maturityValue = principal × (1 + rate/n)^(n×t)` formula for every
/// value EXCEPT [atMaturity] -- every [DepositCompoundingFrequency],
/// including [atMaturity], requires `termUnit: months` or
/// `termUnit: years` so the term can be expressed as a whole number of
/// calendar months (see `AmbiguousCompoundPeriodException`).
/// [atMaturity] is always exactly 1 period, but
/// `DepositCalculator._resolveCompoundingPlan` scales that one period's
/// rate by the term's exact fraction of a year (`totalMonths / 12`)
/// rather than dividing by [periodsPerYear] -- see that method's own doc
/// for why a flat, un-scaled annual rate would silently misstate
/// interest for any [atMaturity] term that isn't exactly one year.
///
/// [fromStorageValue] throws rather than falls back -- see
/// [DepositType]'s doc for why (this value is `n` in an arithmetic
/// formula; a wrong silent fallback would silently misstate the
/// computed interest).
enum DepositCompoundingFrequency {
  monthly('monthly', 12),
  quarterly('quarterly', 4),
  semiannual('semiannual', 2),
  annual('annual', 1),
  atMaturity('atMaturity', 1);

  const DepositCompoundingFrequency(this.storageValue, this.periodsPerYear);

  final String storageValue;

  /// `n` in docs/20 §12.8's compound-interest formula.
  final int periodsPerYear;

  static DepositCompoundingFrequency fromStorageValue(String value) {
    return DepositCompoundingFrequency.values.firstWhere(
      (DepositCompoundingFrequency frequency) => frequency.storageValue == value,
      orElse: () =>
          throw FormatException('Unrecognized DepositCompoundingFrequency storage value: $value'),
    );
  }
}
