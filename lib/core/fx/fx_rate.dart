import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import '../currency/currency.dart';
import '../currency/currency_registry.dart';
import 'fx_rate_parse_exception.dart';

/// An exact, directional exchange rate: `1 [baseCurrencyCode] =
/// [rate] [quoteCurrencyCode]`.
///
/// # Why not `double`
///
/// Same reasoning as [Money] (see that class's doc and
/// `docs/14_DECISION_LOG.md` ADR-017): `double` cannot exactly represent
/// most decimal fractions, and a rate silently perturbed by binary
/// floating-point error would make every conversion built on it
/// untrustworthy. [rate] is a [Decimal] -- exact, arbitrary-precision,
/// parsed once at construction and never touched by `double` at any
/// point in its lifetime.
///
/// # Precision contract
///
/// [rate] must be a plain decimal string with no scientific/exponent
/// notation. `Decimal.tryParse`'s own grammar (`([+-]?\d*)(\.\d*)?
/// ([eE][+-]?\d+)?`) actually DOES accept exponent notation, so this is
/// NOT rejected by construction -- the factory below rejects it with an
/// explicit `contains('e')`/`contains('E')` check before ever calling
/// `Decimal.tryParse`. [rate] must also have at most
/// [maxFractionDigits] digits after the decimal point. That bound exists
/// purely as an input-sanity guard against garbage/malformed provider
/// data -- the arithmetic in `FxConverter` is BigInt-based and has no
/// precision ceiling of its own. 12 digits comfortably covers every
/// realistic FX-provider precision (typically 4-8 significant digits)
/// with headroom to spare.
///
/// # Serialization
///
/// [rateAsString] (`rate.toString()`) is what gets persisted to the
/// `transaction_exchange_rates.rate` TEXT column (see
/// `TransactionExchangeRateRepository`). `Decimal.toString()` always
/// renders plain decimal notation and is stable/round-trip-safe:
/// `Decimal.parse(x.toString())` is always exactly `x` again.
///
/// # Direction
///
/// A rate is directional and is never silently inverted. `FxRate(base:
/// 'USD', quote: 'JPY', rate: '150.25')` means "1 USD = 150.25 JPY" and
/// must only ever be used to convert USD -> JPY. Converting JPY -> USD
/// requires a *separate*, explicitly-quoted JPY -> USD rate --
/// `FxConverter.convert` rejects a pair mismatch rather than guessing an
/// inversion (see `FxRatePairMismatchException`).
@immutable
class FxRate {
  const FxRate._(this.baseCurrencyCode, this.quoteCurrencyCode, this.rate);

  /// Parses [rate] (e.g. `"150.25"`, `"1"`, `"0.0000001"`) as the
  /// exchange rate from [baseCurrencyCode] to [quoteCurrencyCode].
  ///
  /// Throws [ArgumentError] (via [CurrencyRegistry.require]) if either
  /// currency code is unknown. Throws [FxRateParseException] if [rate]
  /// is empty/whitespace, not a valid plain decimal number, zero,
  /// negative, or has more than [maxFractionDigits] fractional digits.
  factory FxRate({
    required String baseCurrencyCode,
    required String quoteCurrencyCode,
    required String rate,
  }) {
    final Currency base = CurrencyRegistry.require(baseCurrencyCode);
    final Currency quote = CurrencyRegistry.require(quoteCurrencyCode);

    final String trimmed = rate.trim();
    if (trimmed.isEmpty) {
      throw FxRateParseException('Enter an exchange rate.');
    }

    // `Decimal.tryParse`'s grammar is `([+-]?\d*)(\.\d*)?([eE][+-]?\d+)?`
    // -- it DOES accept scientific/exponent notation (verified against
    // the `decimal` package's own parsing regex), so exponent notation
    // is rejected explicitly here rather than relying on `tryParse` to
    // reject it. Exponent notation is deliberately not part of this
    // checkpoint's contract ("no exponent ambiguity unless explicitly
    // and safely supported") -- every downstream consumer (in
    // particular `FxConverter._decompose`, which reads
    // `Decimal.toString()` and assumes plain notation) is written
    // against plain-decimal `Decimal`s only, and a rate silently
    // accepted as "1e2" meaning 100 would be exactly the kind of
    // ambiguity this rule exists to prevent.
    if (trimmed.contains('e') || trimmed.contains('E')) {
      throw FxRateParseException(
        '"$rate" uses exponent notation, which is not supported for exchange rates.',
      );
    }

    // "NaN"/"Infinity"/whitespace-only/malformed text all fail to parse
    // as a plain decimal and are rejected here.
    final Decimal? parsed = Decimal.tryParse(trimmed);
    if (parsed == null) {
      throw FxRateParseException('"$rate" is not a valid exchange rate.');
    }
    if (parsed <= Decimal.zero) {
      throw FxRateParseException('Exchange rate must be greater than zero.');
    }

    final int dotIndex = trimmed.indexOf('.');
    final int fractionDigits = dotIndex == -1 ? 0 : trimmed.length - dotIndex - 1;
    if (fractionDigits > maxFractionDigits) {
      throw FxRateParseException(
        'Exchange rate has more than $maxFractionDigits fractional digits.',
      );
    }

    return FxRate._(base.code, quote.code, parsed);
  }

  /// Input-sanity bound on how many fractional digits a parsed rate may
  /// have -- see the class doc's "Precision contract" section.
  static const int maxFractionDigits = 12;

  /// ISO 4217 code of the currency `1` of which [rate] is quoted in
  /// terms of [quoteCurrencyCode]. Always canonical upper-case (via
  /// [CurrencyRegistry]).
  final String baseCurrencyCode;

  /// ISO 4217 code of the currency [rate] is denominated in. Always
  /// canonical upper-case (via [CurrencyRegistry]).
  final String quoteCurrencyCode;

  /// The exact rate: `1 [baseCurrencyCode] = [rate] [quoteCurrencyCode]`.
  /// Always strictly positive.
  final Decimal rate;

  /// The canonical, round-trip-stable decimal-string form of [rate] --
  /// what gets persisted to `transaction_exchange_rates.rate`.
  String get rateAsString => rate.toString();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FxRate &&
          other.baseCurrencyCode == baseCurrencyCode &&
          other.quoteCurrencyCode == quoteCurrencyCode &&
          other.rate == rate);

  @override
  int get hashCode => Object.hash(baseCurrencyCode, quoteCurrencyCode, rate);

  @override
  String toString() => 'FxRate($baseCurrencyCode -> $quoteCurrencyCode @ $rateAsString)';
}
