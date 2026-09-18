import 'package:meta/meta.dart';

import 'fx_rate.dart';
import 'invalid_reference_fx_rate_exception.dart';

/// A current/live reference exchange rate, as observed from an
/// [FxRateProvider] -- the "current rate" counterpart to the historical
/// [FxSnapshot].
///
/// # `ReferenceFxRate` vs `FxSnapshot` -- do not confuse these
///
/// [FxSnapshot] is an immutable **historical fact** permanently attached
/// to one specific transaction the moment it was recorded (ADR-010) --
/// it is never replaced, even when a newer market rate becomes
/// available, and it carries a [convertedAmount] because it was actually
/// used to convert real money.
///
/// `ReferenceFxRate` is a **point-in-time market quote** with no
/// connection to any transaction. It exists only to answer "what does
/// the market say this pair is worth right now/recently" for reference
/// display (ADR-011: "FX rates are reference data") -- it never
/// participates in [FxConverter], never gets attached to a transaction,
/// and never changes any historical accounting fact. Two completely
/// separate lifecycles, deliberately: reusing `transaction_exchange_rates`
/// (or [FxSnapshot]) for this would conflate "what a transaction was
/// actually converted at, forever" with "what the market says right
/// now, which changes by the minute."
///
/// # UTC contract
///
/// [observedAt] and [fetchedAt] are always normalized to UTC at
/// construction -- same represented instant, `isUtc == true` -- mirroring
/// the established `_withUtcDateTimes`/`TransactionExchangeRateRepository`
/// pattern used elsewhere in this codebase. A locally-tagged `DateTime`
/// passed in is converted via `.toUtc()`, which only ever re-tags a
/// `DateTime`'s representation -- it never changes the instant in time
/// that `DateTime` represents. This is not a timezone special-case; it's
/// the same normalize-at-the-domain-boundary rule applied consistently.
///
/// # No `double`
///
/// [rate] is an [FxRate], whose own contract (exact [Decimal], never
/// `double`, directional, never silently inverted, exponent notation
/// rejected) is inherited unchanged -- see that class's doc.
@immutable
class ReferenceFxRate {
  /// Creates a reference rate.
  ///
  /// Throws [InvalidReferenceFxRateException] if [source] is empty or
  /// whitespace-only. Every other domain invariant that doesn't depend on
  /// request context (rate must be a valid, strictly-positive, exact
  /// decimal; currency codes must be known/canonical; no exponent
  /// notation) is already enforced by [rate]'s own construction --
  /// [ReferenceFxRate] does not re-validate what [FxRate] already
  /// guarantees.
  ReferenceFxRate({
    required this.rate,
    required String source,
    required DateTime observedAt,
    required DateTime fetchedAt,
  })  : source = _requireNonEmptySource(source),
        observedAt = observedAt.toUtc(),
        fetchedAt = fetchedAt.toUtc();

  /// The exact, directional rate this reference quote carries. See
  /// [FxRate]'s own doc for the full exact-decimal / no-double /
  /// never-silently-inverted contract.
  final FxRate rate;

  /// Free-text provenance -- the provider's name (e.g. `"fixer"`,
  /// `"fake-test-provider"`). Never empty (enforced by construction).
  final String source;

  /// When the provider says this rate was actually observed/quoted.
  /// Always UTC (same instant, `isUtc == true`) -- see class doc.
  final DateTime observedAt;

  /// When this process fetched [rate] from the provider. Always UTC
  /// (same instant, `isUtc == true`) -- see class doc. This is what
  /// [ReferenceFxRateService]'s freshness contract measures age against
  /// -- not [observedAt], which is the provider's own (untrusted) clock.
  final DateTime fetchedAt;

  /// Convenience accessor -- see [FxRate.baseCurrencyCode].
  String get baseCurrencyCode => rate.baseCurrencyCode;

  /// Convenience accessor -- see [FxRate.quoteCurrencyCode].
  String get quoteCurrencyCode => rate.quoteCurrencyCode;

  static String _requireNonEmptySource(String source) {
    final String trimmed = source.trim();
    if (trimmed.isEmpty) {
      throw InvalidReferenceFxRateException(
        'A reference rate must record a non-empty provider source.',
      );
    }
    return trimmed;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReferenceFxRate &&
          other.rate == rate &&
          other.source == source &&
          other.observedAt.isAtSameMomentAs(observedAt) &&
          other.fetchedAt.isAtSameMomentAs(fetchedAt));

  @override
  int get hashCode => Object.hash(rate, source, observedAt, fetchedAt);

  @override
  String toString() =>
      'ReferenceFxRate($baseCurrencyCode -> $quoteCurrencyCode @ ${rate.rateAsString}, '
      'source: $source, observedAt: $observedAt, fetchedAt: $fetchedAt)';
}
