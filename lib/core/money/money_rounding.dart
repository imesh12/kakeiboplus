import 'package:decimal/decimal.dart';

/// The project's monetary rounding policy: **ROUND HALF UP** (half away
/// from zero), applied only when producing a monetary *result* in a
/// target currency's minor units — never applied to a stored exchange
/// rate itself. See `docs/14_DECISION_LOG.md` ADR-018.
///
/// Examples (rounding an exact decimal amount into minor units):
///   JPY 123.5   -> 124   (0 minor units)
///   USD 12.345  -> 1235  (2 minor units: 12.35)
///   KWD 1.2345  -> 1235  (3 minor units: 1.235)
///
/// Beta 0 performs no currency conversion, so nothing in the Beta 0
/// production code path calls this yet — it exists now, with its own
/// tests, so Stage 3 (FX) has a settled rounding rule to build on rather
/// than inventing one under time pressure. Exchange rates themselves must
/// always be stored at full provider precision and never passed through
/// this rounding — only the converted *money* amount is rounded.
class MoneyRounding {
  MoneyRounding._();

  /// Rounds an exact (unrounded) count of minor units — e.g. the result
  /// of `amount * exchangeRate * 10^minorUnits` computed at full decimal
  /// precision — to the nearest whole minor unit, half rounding away
  /// from zero.
  static int roundHalfUpToMinorUnits(Decimal exactMinorUnits) {
    if (exactMinorUnits.compareTo(Decimal.zero) < 0) {
      return -roundHalfUpToMinorUnits(-exactMinorUnits);
    }
    final Decimal floor = exactMinorUnits.floor();
    final Decimal remainder = exactMinorUnits - floor;
    final Decimal half = Decimal.parse('0.5');
    final Decimal rounded = remainder >= half ? floor + Decimal.one : floor;
    return rounded.toBigInt().toInt();
  }
}
