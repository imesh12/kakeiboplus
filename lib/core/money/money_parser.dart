import 'package:decimal/decimal.dart';

import '../currency/currency.dart';
import '../currency/currency_registry.dart';
import 'money.dart';
import 'money_parse_exception.dart';

/// Parses user-entered decimal text into [Money], safely and precisely.
///
/// This is the ONLY sanctioned entry point for turning a typed amount
/// (e.g. from a text field) into [Money]. It never routes through
/// `double` — it parses with [Decimal] end to end (see
/// `docs/14_DECISION_LOG.md` ADR-017, and the project's core money rule:
/// "Do not parse user-entered money through double.") — and it enforces
/// that the input has no more fractional digits than the target
/// currency's [Currency.minorUnits] allows, rather than silently
/// truncating or rounding excess precision away.
class MoneyParser {
  MoneyParser._();

  /// Parses [input] (e.g. `"12.34"`, `"1200"`, `"1.234"`) as an amount in
  /// [currencyCode].
  ///
  /// Throws [MoneyParseException] if [input] is empty, not a valid
  /// number, negative, or has more fractional digits than
  /// `Currency.minorUnits` allows for [currencyCode]. Throws
  /// [ArgumentError] (via [CurrencyRegistry.require]) if [currencyCode]
  /// isn't a known currency.
  static Money parse(String input, String currencyCode) {
    final Currency currency = CurrencyRegistry.require(currencyCode);
    final String trimmed = input.trim();
    if (trimmed.isEmpty) {
      throw MoneyParseException('Enter an amount.');
    }

    // `Decimal.tryParse`'s own grammar (`([+-]?\d*)(\.\d*)?([eE][+-]?\d+)?`)
    // DOES accept scientific/exponent notation (e.g. "1e2", "1E2",
    // "1e+2", "1e-2", "-1e2"), so it is rejected explicitly here before
    // ever reaching `tryParse` -- mirrors the identical, already-shipped
    // check in `FxRate`'s factory (see that class's "Precision contract"
    // doc for the full reasoning). A user-typed amount meaning "1e2" for
    // 100 would be exactly the kind of notational ambiguity this input
    // boundary exists to prevent; every valid plain-decimal input (any
    // sign, any digit count, with or without a decimal point) is
    // unaffected by this check.
    if (trimmed.contains('e') || trimmed.contains('E')) {
      throw MoneyParseException(
        '"$input" uses exponent notation, which is not supported for amounts.',
      );
    }

    final Decimal? decimalValue = Decimal.tryParse(trimmed);
    if (decimalValue == null) {
      throw MoneyParseException('"$input" is not a valid amount.');
    }
    if (decimalValue.compareTo(Decimal.zero) < 0) {
      throw MoneyParseException('Amount cannot be negative.');
    }

    final int dotIndex = trimmed.indexOf('.');
    final int typedFractionDigits = dotIndex == -1 ? 0 : trimmed.length - dotIndex - 1;
    if (typedFractionDigits > currency.minorUnits) {
      final String plural = currency.minorUnits == 1 ? '' : 's';
      throw MoneyParseException(
        '${currency.code} allows at most ${currency.minorUnits} decimal digit$plural.',
      );
    }

    final Decimal scaled = decimalValue * Decimal.fromInt(currency.minorUnitScale);
    if (!scaled.isInteger) {
      // Should be unreachable given the digit-count check above; guards
      // against any Decimal-representation edge case rather than ever
      // silently rounding.
      throw MoneyParseException(
        'Amount has more precision than ${currency.code} supports.',
      );
    }

    final BigInt minorUnitsBig = scaled.toBigInt();
    // Signed 64-bit int range check (ADR-017) — reject rather than wrap.
    if (minorUnitsBig.bitLength > 62) {
      throw MoneyParseException('Amount is too large.');
    }

    return Money.fromMinorUnits(minorUnitsBig.toInt(), currency.code);
  }
}
