/// Thrown by [MoneyParser.parse] when user-entered text cannot become a
/// valid [Money] for the target currency — not a valid number, negative,
/// or more precise than the currency's minor units allow.
///
/// [message] is written to be shown directly to the user (a form
/// validation error), not just logged.
class MoneyParseException implements Exception {
  MoneyParseException(this.message);

  final String message;

  @override
  String toString() => 'MoneyParseException: $message';
}
