import 'package:meta/meta.dart';

/// Metadata describing how a currency's minor units behave.
///
/// This is the single source of truth for currency precision throughout
/// the app. Formatting, parsing, and arithmetic code must always read
/// [minorUnits] from here — never hard-code a "currencies have two
/// decimal places" assumption. See `docs/14_DECISION_LOG.md` ADR-012.
@immutable
class Currency {
  const Currency({
    required this.code,
    required this.displayName,
    required this.symbol,
    required this.minorUnits,
    this.isActive = true,
  }) : assert(
          minorUnits >= 0 && minorUnits <= 4,
          'minor_units outside the sane ISO 4217 range (0-4)',
        );

  /// ISO 4217 alphabetic code, e.g. "JPY", "KWD". Always upper-case.
  final String code;

  final String displayName;

  final String symbol;

  /// Number of digits after the decimal point this currency's smallest
  /// unit represents.
  ///
  /// Examples: 0 for JPY/KRW/VND, 2 for most currencies (USD, EUR, LKR,
  /// NPR, INR, BDT, MMK, QAR, CAD), 3 for KWD.
  final int minorUnits;

  final bool isActive;

  /// 10^minorUnits — the scale factor between "major" units (e.g. dollars,
  /// yen) and "minor" units (e.g. cents) for this currency.
  int get minorUnitScale {
    var scale = 1;
    for (var i = 0; i < minorUnits; i++) {
      scale *= 10;
    }
    return scale;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Currency && other.code == code);

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => 'Currency($code, minorUnits: $minorUnits)';
}
