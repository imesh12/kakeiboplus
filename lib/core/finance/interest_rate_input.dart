import 'package:decimal/decimal.dart';

/// Thrown by [InterestRateInput.parseAnnualRatePercentToBasisPoints] for
/// any user-input shape it rejects. Mirrors [MoneyParseException]'s own
/// role for [MoneyParser] -- a plain, message-carrying exception a form
/// field's validator can surface directly.
class InterestRateInputException implements Exception {
  const InterestRateInputException(this.message);

  final String message;

  @override
  String toString() => 'InterestRateInputException: $message';
}

/// Parses a user-typed annual interest rate *percentage* (e.g. `"5.5"`
/// for 5.5%) into the whole basis-point integer
/// `DepositRepository.createDetails`'s `interestRateBasisPoints`
/// parameter requires (docs/20 §12.8: `550` = 5.50%).
///
/// Exact [Decimal] parsing throughout, never `double` -- the same "never
/// parse a financial input through `double`" rule `MoneyParser` already
/// enforces for amounts (ADR-017/`CLAUDE_PROJECT_INSTRUCTIONS.md`), now
/// applied to a rate instead of a currency amount. This class has no
/// currency/minor-unit concept of its own (a rate is not money) -- it is
/// a deliberately small, independent parser, not a repurposing of
/// [MoneyParser].
///
/// A basis point is exactly 1/100 of a percent, so a percentage input
/// can carry at most 2 fractional digits and still convert to a whole
/// basis-point count exactly. A 3rd fractional digit (e.g. `"5.555"`)
/// is rejected outright rather than silently rounded or truncated --
/// this class invents no rounding rule Checkpoint G was never asked to
/// define; `DepositCalculator`'s own HALF-UP policy governs calculation
/// results, not this input boundary.
class InterestRateInput {
  InterestRateInput._();

  /// Throws [InterestRateInputException] if [input] is empty, not a
  /// valid number, negative, uses exponent notation, or carries more
  /// than 2 fractional digits.
  static int parseAnnualRatePercentToBasisPoints(String input) {
    final String trimmed = input.trim();
    if (trimmed.isEmpty) {
      throw const InterestRateInputException('Enter an annual interest rate.');
    }
    // Same exponent-notation rejection as `MoneyParser.parse` -- see that
    // method's own doc for why `Decimal.tryParse`'s grammar can't be
    // trusted to reject this on its own.
    if (trimmed.contains('e') || trimmed.contains('E')) {
      throw InterestRateInputException(
        '"$input" uses exponent notation, which is not supported for a rate.',
      );
    }
    final Decimal? decimalValue = Decimal.tryParse(trimmed);
    if (decimalValue == null) {
      throw InterestRateInputException('"$input" is not a valid interest rate.');
    }
    if (decimalValue.compareTo(Decimal.zero) < 0) {
      throw const InterestRateInputException('Interest rate cannot be negative.');
    }

    final int dotIndex = trimmed.indexOf('.');
    final int typedFractionDigits = dotIndex == -1 ? 0 : trimmed.length - dotIndex - 1;
    if (typedFractionDigits > 2) {
      throw const InterestRateInputException(
        'Interest rate allows at most 2 decimal digits.',
      );
    }

    final Decimal scaled = decimalValue * Decimal.fromInt(100);
    if (!scaled.isInteger) {
      // Unreachable given the digit-count check above; guards against any
      // Decimal-representation edge case rather than ever silently
      // rounding -- mirrors `MoneyParser.parse`'s identical defensive
      // check.
      throw const InterestRateInputException(
        'Interest rate has more precision than supported.',
      );
    }

    final BigInt basisPoints = scaled.toBigInt();
    if (basisPoints.bitLength > 31) {
      throw const InterestRateInputException('Interest rate is too large.');
    }
    return basisPoints.toInt();
  }
}
