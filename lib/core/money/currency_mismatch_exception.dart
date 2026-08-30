/// Thrown when an operation would combine [Money] values (or a [Money]
/// with an account/transaction) of two different currencies without an
/// explicit, recorded conversion.
///
/// This exception existing — and every arithmetic operator on [Money]
/// throwing it rather than silently coercing — is what makes "mismatched
/// currency arithmetic is rejected" (a Beta 0 release gate) true by
/// construction rather than by convention.
class CurrencyMismatchException implements Exception {
  CurrencyMismatchException(this.currencyCodeA, this.currencyCodeB);

  final String currencyCodeA;
  final String currencyCodeB;

  @override
  String toString() =>
      'CurrencyMismatchException: cannot combine $currencyCodeA and '
      '$currencyCodeB without an explicit currency conversion';
}
