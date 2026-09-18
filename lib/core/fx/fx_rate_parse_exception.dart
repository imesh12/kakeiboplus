/// Thrown by [FxRate]'s constructor when a rate string cannot become a
/// valid [FxRate] -- empty, not a valid plain-decimal number, zero,
/// negative, or too many fractional digits.
///
/// [message] is written to be shown directly to the user (a form
/// validation error) once a rate-entry UI exists -- not just logged. See
/// `MoneyParseException` for the identical convention this mirrors.
class FxRateParseException implements Exception {
  FxRateParseException(this.message);

  final String message;

  @override
  String toString() => 'FxRateParseException: $message';
}
