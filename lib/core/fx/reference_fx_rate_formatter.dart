import 'fx_rate.dart';

/// Formats an [FxRate]'s numeric value for on-screen display --
/// Checkpoint 9.5's small, deterministic, exact-decimal FX-rate
/// formatter (see the Reference Rate checkpoint's "CRITICAL RATE
/// FORMATTING" rule).
///
/// # Why this is NOT `MoneyFormatter`
///
/// `MoneyFormatter` (`lib/core/money/money_formatter.dart`) formats a
/// `Money` value to exactly `Currency.minorUnits` fractional digits --
/// the correct rule for an authoritative money amount, but the WRONG
/// rule for an FX rate: "1 USD = 149.85 JPY" must never be rounded to
/// JPY's own 0 minor units and rendered as "1 USD = 150 JPY". An FX
/// rate's own precision (however many significant digits the provider
/// actually quoted, typically 4-8) is a completely separate concept from
/// the *target* currency's minor-unit precision, and the two must never
/// be conflated. This class formats [FxRate.rate] on its own terms,
/// never consulting [Currency.minorUnits] at all.
///
/// # No `double`, ever; no scientific notation; no invented zeros
///
/// [format] reads [FxRate.rate]'s own `Decimal.toString()` output --
/// already exact, always plain-decimal notation, never scientific (see
/// [FxRate]'s own construction contract, which rejects exponent notation
/// and only ever stores an already-validated, strictly-positive
/// [Decimal]) -- and performs pure string manipulation on it, mirroring
/// `MoneyFormatter._insertGroupSeparators`'s grouping approach for the
/// integer part. `double` is never touched at any point. No
/// trailing-zero padding is ever added: `Decimal.toString()` is already
/// canonical (e.g. `151.00` -> `"151"`, `2100.50` -> `"2100.5"`), and this
/// formatter never adds digits back on top of that.
class ReferenceFxRateFormatter {
  const ReferenceFxRateFormatter({this.groupSeparator = ','});

  final String groupSeparator;

  /// Formats [rate]'s numeric value alone (no currency codes attached --
  /// callers compose the full "1 BASE = `<this>` QUOTE" sentence
  /// themselves, typically via a localized message), e.g. `"149.85"`,
  /// `"1"`, `"1,234.5"`, `"0.0000001"`.
  String format(FxRate rate) {
    // FxRate.rate is always strictly positive (construction rejects
    // zero/negative), so there is never a sign to handle here.
    final String exact = rate.rate.toString();
    final int dotIndex = exact.indexOf('.');
    final String wholePart = dotIndex == -1 ? exact : exact.substring(0, dotIndex);
    final String fractionPart = dotIndex == -1 ? '' : exact.substring(dotIndex + 1);
    final String groupedWhole = _insertGroupSeparators(wholePart);
    return fractionPart.isEmpty ? groupedWhole : '$groupedWhole.$fractionPart';
  }

  /// Inserts [groupSeparator] every three digits from the right of
  /// [digits] (a non-negative whole-number digit string) -- identical in
  /// spirit to `MoneyFormatter._insertGroupSeparators`, duplicated rather
  /// than shared because that method is private to `MoneyFormatter` and
  /// this class must never depend on `MoneyFormatter`/`Money` (an FX rate
  /// is not a `Money` value and must not be coerced through that type).
  String _insertGroupSeparators(String digits) {
    if (digits.length <= 3) return digits;
    final StringBuffer buffer = StringBuffer();
    final int firstGroupLength = digits.length % 3 == 0 ? 3 : digits.length % 3;
    buffer.write(digits.substring(0, firstGroupLength));
    for (int i = firstGroupLength; i < digits.length; i += 3) {
      buffer
        ..write(groupSeparator)
        ..write(digits.substring(i, i + 3));
    }
    return buffer.toString();
  }
}
