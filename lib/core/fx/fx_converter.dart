import 'package:decimal/decimal.dart';

import '../currency/currency.dart';
import '../currency/currency_registry.dart';
import '../money/money.dart';
import '../money/money_overflow_exception.dart';
import 'fx_rate.dart';
import 'fx_rate_pair_mismatch_exception.dart';

/// Deterministic, exact-arithmetic currency conversion -- CP9.1's core
/// engine. See `docs/14_DECISION_LOG.md` ADR-009/ADR-017/ADR-018 and this
/// file's own comments for the full contract.
///
/// # The formula
///
/// Converting [source] (in `sourceCurrency`, with `sourceDigits` minor
/// units) to `targetCurrency` (`targetDigits` minor units) via a
/// `sourceCurrency -> targetCurrency` [FxRate]:
///
/// ```text
/// sourceMajor      = sourceMinorUnits / 10^sourceDigits
/// targetMajorExact  = sourceMajor * rate
/// targetMinorExact  = targetMajorExact * 10^targetDigits
/// targetMinorUnits  = ROUND_HALF_UP(targetMinorExact)
/// ```
///
/// # Why BigInt, not `Decimal` division, not `double`
///
/// `double` is never used anywhere in this file -- see [Money]'s and
/// [FxRate]'s own docs for why binary floating point is unsafe for
/// money.
///
/// The formula above is implemented with **pure `BigInt` multiplication
/// and one BigInt division-with-remainder** rather than `Decimal`
/// arithmetic, specifically:
///
/// ```text
/// targetMinorExact = sourceMinorUnits * rateSignificand * 10^targetDigits
///                     ---------------------------------------------------
///                              10^(rateScale + sourceDigits)
/// ```
///
/// where the rate's own [Decimal] value is decomposed once into an exact
/// `(significand, scale)` pair (`rateValue == significand / 10^scale`).
/// Both the numerator and denominator here are always exactly
/// representable (the denominator is always a power of ten), so this
/// never loses precision the way a general `Decimal / Decimal` division
/// risks (division of two arbitrary decimals does not always terminate).
/// [BigInt] is used purely as an *intermediate* exact-arithmetic
/// mechanism (explicitly sanctioned for this by CP9.1) -- the
/// authoritative [Money] this function returns still stores its
/// magnitude as a native `int`, exactly like every other [Money] in this
/// codebase (ADR-017).
///
/// This also means overflow can be checked against the *exact* BigInt
/// result before ever narrowing to `int` -- seed
/// `MoneyRounding.roundHalfUpToMinorUnits` (which this function
/// deliberately does *not* call) narrows a `Decimal` to `int` via
/// `BigInt.toInt()` with no range check, which is exactly the "silently
/// wrap" failure mode CP9.1's overflow-safety requirement forbids. This
/// function instead performs the identical ROUND HALF UP (half away from
/// zero) policy directly on the `BigInt` numerator/denominator pair (see
/// [_roundHalfUpAwayFromZero]) so the unrounded-to-`int` value stays
/// available for an explicit signed-64-bit range check
/// ([_requireFitsInInt64]) before [Money.fromMinorUnits] is ever called.
///
/// # Rate direction and same-currency identity
///
/// See [FxRate]'s class doc for the directional-rate contract. When
/// `source.currencyCode == targetCurrencyCode`, [convert] returns the
/// same minor-unit amount immediately -- no rate is required, and one
/// passed in is not consulted at all (relabeling never needs external
/// market data). Otherwise a rate is required and its pair must exactly
/// match `(source.currencyCode, targetCurrencyCode)` or
/// [FxRatePairMismatchException] is thrown -- never a silent inversion.
class FxConverter {
  FxConverter._();

  /// Converts [source] into `targetCurrencyCode`.
  ///
  /// [rate] is required whenever `source.currencyCode !=
  /// targetCurrencyCode` (an [ArgumentError] is thrown if it's omitted),
  /// and must be a rate *from* `source.currencyCode` *to*
  /// `targetCurrencyCode` exactly (see [FxRatePairMismatchException]).
  /// It is ignored entirely for a same-currency conversion.
  ///
  /// Throws [MoneyOverflowException] if the exact converted amount does
  /// not fit in [Money]'s signed 64-bit minor-units range.
  static Money convert({
    required Money source,
    required String targetCurrencyCode,
    FxRate? rate,
  }) {
    final Currency target = CurrencyRegistry.require(targetCurrencyCode);
    final Currency sourceCurrency = source.currency;

    if (sourceCurrency.code == target.code) {
      // Same-currency identity conversion -- no external rate needed or
      // consulted, even if one happens to be passed in. This never
      // bypasses account/transfer currency validation elsewhere; it only
      // ever relabels a Money's currencyCode to an identical code.
      return Money.fromMinorUnits(source.minorUnits, target.code);
    }

    if (rate == null) {
      throw ArgumentError(
        'Converting ${sourceCurrency.code} to ${target.code} requires an FxRate '
        '(they are different currencies).',
      );
    }
    if (rate.baseCurrencyCode != sourceCurrency.code || rate.quoteCurrencyCode != target.code) {
      throw FxRatePairMismatchException(
        requiredBaseCurrencyCode: sourceCurrency.code,
        requiredQuoteCurrencyCode: target.code,
        rate: rate,
      );
    }

    final ({BigInt significand, int scale}) decomposedRate = _decompose(rate.rate);

    final BigInt numerator = BigInt.from(source.minorUnits) *
        decomposedRate.significand *
        BigInt.from(10).pow(target.minorUnits);
    final BigInt denominator =
        BigInt.from(10).pow(decomposedRate.scale + sourceCurrency.minorUnits);

    final BigInt exactMinorUnits = _roundHalfUpAwayFromZero(numerator, denominator);
    _requireFitsInInt64(exactMinorUnits, target.code);

    return Money.fromMinorUnits(exactMinorUnits.toInt(), target.code);
  }

  /// Splits an already-validated, positive [Decimal] into an exact
  /// `(significand, scale)` pair such that `value == significand /
  /// 10^scale`. Reads [Decimal.toString], which always renders plain
  /// decimal notation (never scientific/exponent notation -- see
  /// [FxRate]'s parse contract, which only ever accepts plain-decimal
  /// input in the first place) -- this is a structural read of an
  /// already-validated value, not a re-parse of untrusted text.
  static ({BigInt significand, int scale}) _decompose(Decimal value) {
    final String text = value.toString();
    final int dotIndex = text.indexOf('.');
    if (dotIndex == -1) {
      return (significand: BigInt.parse(text), scale: 0);
    }
    final String digits = text.replaceFirst('.', '');
    final int scale = text.length - dotIndex - 1;
    return (significand: BigInt.parse(digits), scale: scale);
  }

  /// Rounds the exact fraction `numerator / denominator` to the nearest
  /// integer, **half away from zero** -- ADR-018's ROUND HALF UP policy,
  /// applied directly to a `BigInt` fraction. [denominator] must be
  /// strictly positive (it always is here: a power of ten). [numerator]
  /// may be any sign, since [Money] itself is not constrained to be
  /// positive (see "Round Half Up — Signed Values" in the CP9.1
  /// checkpoint; `+1.5 -> +2`, `-1.5 -> -2`).
  ///
  /// Equivalent in policy to `MoneyRounding.roundHalfUpToMinorUnits`
  /// (same ADR-018 rule, exhaustively verified against it for every
  /// boundary case in `test/core/fx/fx_converter_test.dart`) but
  /// implemented independently on a `BigInt` fraction rather than a
  /// `Decimal` — see the class doc for why that distinction matters for
  /// overflow safety.
  static BigInt _roundHalfUpAwayFromZero(BigInt numerator, BigInt denominator) {
    assert(denominator > BigInt.zero, 'denominator must be positive');
    final BigInt quotient = numerator ~/ denominator; // truncates toward zero
    final BigInt remainder = numerator - quotient * denominator; // sign of numerator, or zero
    final BigInt doubledAbsRemainder = remainder.abs() * BigInt.two;
    if (doubledAbsRemainder >= denominator) {
      return numerator.isNegative ? quotient - BigInt.one : quotient + BigInt.one;
    }
    return quotient;
  }

  /// The exact signed 64-bit range [Money.minorUnits] (a native Dart
  /// `int`) can represent -- see ADR-017.
  static final BigInt _minInt64 = BigInt.parse('-9223372036854775808');
  static final BigInt _maxInt64 = BigInt.parse('9223372036854775807');

  static void _requireFitsInInt64(BigInt exactMinorUnits, String currencyCode) {
    if (exactMinorUnits < _minInt64 || exactMinorUnits > _maxInt64) {
      throw MoneyOverflowException(currencyCode: currencyCode, exactMinorUnits: exactMinorUnits);
    }
  }
}
