/// `DepositDetails.termUnit` -- docs/20 §12.1/§12.7. Selects how
/// `DepositRepository`'s maturity-date computation advances from
/// `startDate`: [days] is plain calendar-day addition; [months]/[years]
/// use `calendar_month_math.dart`'s anchor-based, leap-year-aware
/// arithmetic (never "30 days == 1 month" / "365 days == 1 year" -- see
/// that file's doc). Also gates `DepositCalculator`'s compound-interest
/// period resolution: a month-based `compoundingFrequency` (monthly/
/// quarterly/semiannual/annual) requires [months] or [years] here --
/// [days] has no unambiguous calendar-month period boundary to compound
/// against, so that combination is rejected rather than guessed (see
/// `AmbiguousCompoundPeriodException`).
///
/// [fromStorageValue] throws rather than falls back -- see
/// [DepositType]'s doc for why (this value directly selects which
/// calendar-arithmetic path runs).
enum DepositTermUnit {
  days('days'),
  months('months'),
  years('years');

  const DepositTermUnit(this.storageValue);

  final String storageValue;

  static DepositTermUnit fromStorageValue(String value) {
    return DepositTermUnit.values.firstWhere(
      (DepositTermUnit unit) => unit.storageValue == value,
      orElse: () => throw FormatException('Unrecognized DepositTermUnit storage value: $value'),
    );
  }
}
