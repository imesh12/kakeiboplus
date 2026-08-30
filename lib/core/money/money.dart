import 'package:meta/meta.dart';

import '../currency/currency.dart';
import '../currency/currency_registry.dart';
import 'currency_mismatch_exception.dart';

/// A monetary amount: an exact integer count of a currency's minor units,
/// plus the currency it's denominated in.
///
/// # Why not `double`
///
/// `double` (binary floating point) cannot exactly represent most decimal
/// fractions (0.1 has no exact binary representation), which makes it
/// unsafe for money. `Money` is forbidden from ever wrapping a `double` —
/// see `docs/14_DECISION_LOG.md` ADR-017 and the project's core money
/// rule in `CLAUDE_PROJECT_INSTRUCTIONS.md`.
///
/// # Why `int`, not `BigInt`
///
/// [minorUnits] is a native Dart `int` — signed 64-bit on every platform
/// Flutter targets. SQLite's `INTEGER` column affinity is also signed
/// 64-bit, so this maps onto Drift storage with no conversion, and stays
/// cheap for `SUM`/`ORDER BY`/indexing. Personal-finance amounts and
/// multi-year aggregate sums stay comfortably inside that range. See
/// ADR-017 for the full reasoning and the escape hatch (a future ADR) if
/// that ever stops being true.
///
/// # What the integer means
///
/// The integer alone does not encode decimal placement — its meaning is
/// entirely determined by looking up [Currency.minorUnits] for
/// [currencyCode]. `Money.fromMinorUnits(1200, 'JPY')` is ¥1,200 (JPY has
/// 0 minor units); `Money.fromMinorUnits(1200, 'USD')` is $12.00 (USD has
/// 2). Never assume 2 decimal places.
///
/// # Arithmetic
///
/// Only same-currency arithmetic is permitted. Any attempt to add,
/// subtract, or compare [Money] values of different currencies throws
/// [CurrencyMismatchException] rather than silently coercing — a
/// converted amount must always be produced explicitly, alongside a
/// recorded exchange-rate snapshot (see `transaction_exchange_rates` in
/// `docs/03_DATABASE_SCHEMA.md`), never implicitly.
@immutable
class Money implements Comparable<Money> {
  const Money.fromMinorUnits(this.minorUnits, this.currencyCode);

  factory Money.zero(String currencyCode) => Money.fromMinorUnits(0, currencyCode);

  /// Integer count of minor units. See the class doc for what this means
  /// for a given currency.
  final int minorUnits;

  /// ISO 4217 currency code this amount is denominated in.
  final String currencyCode;

  /// The [Currency] metadata for [currencyCode]. Throws [ArgumentError]
  /// if the code isn't in [CurrencyRegistry] — that indicates corrupt
  /// data, not a normal recoverable condition.
  Currency get currency => CurrencyRegistry.require(currencyCode);

  bool get isNegative => minorUnits < 0;
  bool get isZero => minorUnits == 0;
  bool get isPositive => minorUnits > 0;

  void _requireSameCurrency(Money other) {
    if (other.currencyCode != currencyCode) {
      throw CurrencyMismatchException(currencyCode, other.currencyCode);
    }
  }

  Money operator +(Money other) {
    _requireSameCurrency(other);
    return Money.fromMinorUnits(minorUnits + other.minorUnits, currencyCode);
  }

  Money operator -(Money other) {
    _requireSameCurrency(other);
    return Money.fromMinorUnits(minorUnits - other.minorUnits, currencyCode);
  }

  Money operator -() => Money.fromMinorUnits(-minorUnits, currencyCode);

  Money abs() => isNegative ? -this : this;

  @override
  int compareTo(Money other) {
    _requireSameCurrency(other);
    return minorUnits.compareTo(other.minorUnits);
  }

  bool operator <(Money other) => compareTo(other) < 0;
  bool operator <=(Money other) => compareTo(other) <= 0;
  bool operator >(Money other) => compareTo(other) > 0;
  bool operator >=(Money other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Money && other.currencyCode == currencyCode && other.minorUnits == minorUnits);

  @override
  int get hashCode => Object.hash(minorUnits, currencyCode);

  @override
  String toString() => '$currencyCode ${toMajorUnitsString()}';

  /// Renders this amount as a plain decimal string in major units, e.g.
  /// `"12.34"` (USD), `"1200"` (JPY, 0 minor units), `"1.234"` (KWD).
  ///
  /// This is the sanctioned way to turn stored minor units back into a
  /// human-readable decimal string using only integer arithmetic — never
  /// via `double`. UI display should generally go through
  /// `MoneyFormatter` (`lib/core/money/money_formatter.dart`) instead,
  /// which adds locale-aware grouping and the currency symbol; this
  /// method is the primitive that formatter builds on, and is also handy
  /// directly in tests and logs.
  String toMajorUnitsString() {
    final Currency c = currency;
    if (c.minorUnits == 0) {
      return minorUnits.toString();
    }
    final int scale = c.minorUnitScale;
    final bool negative = minorUnits < 0;
    final int magnitude = minorUnits.abs();
    final int whole = magnitude ~/ scale;
    final int fraction = magnitude % scale;
    final String fractionStr = fraction.toString().padLeft(c.minorUnits, '0');
    return '${negative ? '-' : ''}$whole.$fractionStr';
  }
}
