import 'fx_rate.dart';
import 'reference_fx_rate.dart';
import 'reference_fx_rate_formatter.dart';
import 'reference_rate_result.dart';

/// Which of [ReferenceRateResult]'s four outcomes a [ReferenceRateView]
/// wraps -- mirrors that sealed class's cases one-to-one. Checkpoint 9.5
/// Task C deliberately adapts [ReferenceRateResult]'s existing semantics
/// rather than re-deriving fresh/stale/unavailable logic here.
enum ReferenceRateViewKind { identity, fresh, stale, unavailable }

/// The smallest presentation-only view over a [ReferenceRateResult] that
/// the Reference Rate settings UI (Task D) and the Home/Living
/// equivalent (Task F) both need.
///
/// # What this deliberately does NOT do
///
/// This is a pure, synchronous mapping -- [ReferenceRateView.from] does
/// no I/O, no clock read, and carries no localized text of its own
/// (callers resolve every user-facing string through `AppLocalizations`;
/// this class only ever exposes locale-neutral data: currency codes, a
/// pre-formatted numeric rate string, a provider source id, and a UTC
/// timestamp). It never exposes [ReferenceRateUnavailable]'s raw
/// `message` field (a vendor-facing, exception-adjacent string) -- see
/// Task H's "never expose raw exceptions/HTTP internals/provider JSON"
/// rule; [unavailableReason] is the only unavailable-case detail a
/// caller gets, and it is itself just an enum, safe to key a localized
/// message off of.
///
/// [rate] (the underlying, exact [FxRate]) IS exposed for the fresh/stale
/// cases -- unlike the raw unavailable `message`, an [FxRate] is a clean,
/// already-validated domain value, and Task F's Home/Living equivalent
/// needs the exact rate object itself (not just its display string) to
/// drive [FxConverter.convert]. [formattedRate] is the display-ready
/// string ([ReferenceFxRateFormatter.format]) for the settings card,
/// which never needs to touch [FxConverter] at all.
class ReferenceRateView {
  const ReferenceRateView._({
    required this.kind,
    required this.baseCurrencyCode,
    required this.quoteCurrencyCode,
    this.rate,
    this.formattedRate,
    this.source,
    this.fetchedAt,
    this.unavailableReason,
  });

  /// Builds a view for a [result] that was requested for exactly
  /// [baseCurrencyCode] -> [quoteCurrencyCode] (the caller always knows
  /// this -- it's what it asked
  /// [ReferenceFxRateService.referenceRate]/`referenceRateProvider` for
  /// -- and [ReferenceRateUnavailable] itself carries no currency codes
  /// to recover them from). For [ReferenceRateFresh]/[ReferenceRateStale]
  /// /[ReferenceRateIdentity], the embedded rate's own codes are always
  /// consistent with the requested pair (the service never returns a
  /// mismatched pair -- see its own "never silently use a mismatched
  /// quote" contract), so this never needs to reconcile a disagreement.
  factory ReferenceRateView.from(
    ReferenceRateResult result, {
    required String baseCurrencyCode,
    required String quoteCurrencyCode,
    ReferenceFxRateFormatter formatter = const ReferenceFxRateFormatter(),
  }) {
    switch (result) {
      case ReferenceRateIdentity():
        return ReferenceRateView._(
          kind: ReferenceRateViewKind.identity,
          baseCurrencyCode: baseCurrencyCode,
          quoteCurrencyCode: quoteCurrencyCode,
        );
      case ReferenceRateFresh(rate: final ReferenceFxRate referenceRate):
        return ReferenceRateView._(
          kind: ReferenceRateViewKind.fresh,
          baseCurrencyCode: baseCurrencyCode,
          quoteCurrencyCode: quoteCurrencyCode,
          rate: referenceRate.rate,
          formattedRate: formatter.format(referenceRate.rate),
          source: referenceRate.source,
          fetchedAt: referenceRate.fetchedAt,
        );
      case ReferenceRateStale(rate: final ReferenceFxRate referenceRate):
        return ReferenceRateView._(
          kind: ReferenceRateViewKind.stale,
          baseCurrencyCode: baseCurrencyCode,
          quoteCurrencyCode: quoteCurrencyCode,
          rate: referenceRate.rate,
          formattedRate: formatter.format(referenceRate.rate),
          source: referenceRate.source,
          fetchedAt: referenceRate.fetchedAt,
        );
      case ReferenceRateUnavailable(reason: final ReferenceRateUnavailableReason reason):
        return ReferenceRateView._(
          kind: ReferenceRateViewKind.unavailable,
          baseCurrencyCode: baseCurrencyCode,
          quoteCurrencyCode: quoteCurrencyCode,
          unavailableReason: reason,
        );
    }
  }

  final ReferenceRateViewKind kind;
  final String baseCurrencyCode;
  final String quoteCurrencyCode;

  /// The exact, directional rate -- present only for [fresh]/[stale].
  /// Safe to feed directly into [FxConverter.convert] (its
  /// base/quoteCurrencyCode always match [baseCurrencyCode]/
  /// [quoteCurrencyCode] above).
  final FxRate? rate;

  /// Display-ready numeric rate string ([ReferenceFxRateFormatter]) --
  /// present only for [fresh]/[stale]. Never a raw [Decimal]/`double`.
  final String? formattedRate;

  /// The provider's own free-text source id (e.g.
  /// `"exchangerate-api.com"`) -- present only for [fresh]/[stale].
  final String? source;

  /// When this rate was fetched (always UTC) -- present only for
  /// [fresh]/[stale]. Callers format this for display themselves (e.g.
  /// via `intl`'s `DateFormat`, converted to the user's local time zone)
  /// -- this class does no formatting of dates, only of the rate number.
  final DateTime? fetchedAt;

  /// Why no rate could be produced -- present only for [unavailable].
  final ReferenceRateUnavailableReason? unavailableReason;

  bool get isIdentity => kind == ReferenceRateViewKind.identity;

  bool get isStale => kind == ReferenceRateViewKind.stale;

  bool get isUnavailable => kind == ReferenceRateViewKind.unavailable;

  /// True for [fresh]/[stale] -- i.e. whenever [rate] is non-null and
  /// safe to convert with.
  bool get hasUsableRate => rate != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReferenceRateView &&
          other.kind == kind &&
          other.baseCurrencyCode == baseCurrencyCode &&
          other.quoteCurrencyCode == quoteCurrencyCode &&
          other.rate == rate &&
          other.formattedRate == formattedRate &&
          other.source == source &&
          (other.fetchedAt == null) == (fetchedAt == null) &&
          (other.fetchedAt == null || other.fetchedAt!.isAtSameMomentAs(fetchedAt!)) &&
          other.unavailableReason == unavailableReason);

  @override
  int get hashCode => Object.hash(
        kind,
        baseCurrencyCode,
        quoteCurrencyCode,
        rate,
        formattedRate,
        source,
        fetchedAt,
        unavailableReason,
      );

  @override
  String toString() =>
      'ReferenceRateView($baseCurrencyCode -> $quoteCurrencyCode, kind: $kind, '
      'formattedRate: $formattedRate)';
}
