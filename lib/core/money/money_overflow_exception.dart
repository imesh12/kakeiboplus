/// Thrown when an exact monetary calculation's result does not fit in
/// [Money]'s signed 64-bit integer minor-units range (ADR-017): the
/// closed interval [-9223372036854775808, 9223372036854775807].
///
/// First introduced for `FxConverter.convert` (CP9.1) -- a conversion
/// whose exact result overflows fails deterministically with this
/// exception rather than wrapping, silently clamping, or truncating to a
/// corrupted (wrong) [Money] value. The check happens against the exact,
/// unrounded-to-`int` [BigInt] result, so an overflow is caught even
/// when the final rounding step would otherwise have been the only place
/// truncation happened.
class MoneyOverflowException implements Exception {
  const MoneyOverflowException({required this.currencyCode, required this.exactMinorUnits});

  /// The currency the overflowing amount would have been denominated in.
  final String currencyCode;

  /// The exact result, before any `int`-narrowing was attempted --
  /// deliberately a [BigInt] so this value itself is never corrupted by
  /// the overflow it's reporting.
  final BigInt exactMinorUnits;

  @override
  String toString() =>
      'MoneyOverflowException: $exactMinorUnits $currencyCode minor units does not fit '
      'in a signed 64-bit integer';
}
