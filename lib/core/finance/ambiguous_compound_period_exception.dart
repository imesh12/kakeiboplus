/// Thrown by [DepositCalculator.calculateCompoundInterest] when the
/// supplied `termNumber`/`termUnit`/`compoundingFrequency` do not define
/// an unambiguous whole number of compounding periods.
///
/// This checkpoint's own instruction is explicit: "If the requested
/// metadata does not define an unambiguous whole-period compound
/// calculation, return/throw an explicit domain result/error rather than
/// guessing." Three situations reach this: (1) ANY `compoundingFrequency`
/// -- including `atMaturity` -- combined with `termUnit: days`: a day
/// count has no unambiguous calendar-month period boundary, and
/// `atMaturity` is not exempt, because its one period's rate must still
/// be scaled to the term's exact length in months (see
/// `DepositCalculator._resolveCompoundingPlan`'s doc); (2) a term (in
/// months) that is not an exact multiple of a month-based frequency's
/// (`monthly`/`quarterly`/`semiannual`/`annual`) period length (e.g. a
/// 4-month term compounded quarterly -- 4/3 is not a whole number of
/// quarters); `atMaturity` can never hit this second case -- it is
/// always exactly 1 period, whatever the (whole) month count.
class AmbiguousCompoundPeriodException implements Exception {
  const AmbiguousCompoundPeriodException(this.message);

  final String message;

  @override
  String toString() => 'AmbiguousCompoundPeriodException: $message';
}
