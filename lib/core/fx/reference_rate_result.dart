import 'reference_fx_rate.dart';

/// Why [ReferenceFxRateService.referenceRate] could not return a
/// [ReferenceRateFresh]/[ReferenceRateStale] result.
enum ReferenceRateUnavailableReason {
  /// The provider call itself failed (vendor error, network failure,
  /// ...) and there was no cached rate to fall back to.
  providerFailed,

  /// The provider returned successfully, but not for the pair that was
  /// actually requested (e.g. it quoted `EUR -> GBP` when `EUR -> USD`
  /// was asked for) -- never silently relabeled as the requested pair.
  pairMismatch,

  /// The provider returned a quote for the correct pair, but the quote
  /// itself is not usable as given -- currently: its observed timestamp
  /// is in the future relative to this service's clock, so it cannot be
  /// a genuinely-already-observed market rate.
  invalidProviderData,
}

/// The outcome of [ReferenceFxRateService.referenceRate] -- exactly one
/// of [ReferenceRateFresh], [ReferenceRateStale], [ReferenceRateIdentity],
/// or [ReferenceRateUnavailable]. A sealed class so every call site is
/// forced to handle all four outcomes explicitly (Dart 3 pattern
/// matching, already used elsewhere in this codebase) -- there is no
/// "just give me a rate or null" shortcut that would let a caller
/// silently treat stale data as current, or an unavailable rate as zero.
sealed class ReferenceRateResult {
  const ReferenceRateResult();
}

/// A rate was available and within the freshness window -- served
/// straight from cache, or just fetched from the provider.
final class ReferenceRateFresh extends ReferenceRateResult {
  const ReferenceRateFresh(this.rate);

  /// The fresh reference rate. Never presented as current data without
  /// this wrapper -- see [ReferenceFxRateService]'s freshness contract.
  final ReferenceFxRate rate;
}

/// A rate was available but is past the freshness window, and either no
/// provider refresh was attempted or the refresh did not succeed with a
/// usable quote for this pair. [rate] must still be surfaced (with its
/// own true age, via [ReferenceFxRate.fetchedAt]) -- never silently
/// relabeled as [ReferenceRateFresh].
final class ReferenceRateStale extends ReferenceRateResult {
  const ReferenceRateStale(this.rate);

  /// The stale reference rate, unchanged from what was last cached.
  final ReferenceFxRate rate;
}

/// The requested base and quote currency are the same currency -- no
/// external rate is meaningful, no provider or cache was consulted, and
/// the "rate" is definitionally 1:1 by relabeling, not by market quote.
final class ReferenceRateIdentity extends ReferenceRateResult {
  const ReferenceRateIdentity(this.currencyCode);

  /// The shared currency code (canonical/upper-case).
  final String currencyCode;
}

/// No usable rate could be produced at all: no cached rate existed and
/// the provider could not supply one (or supplied one that couldn't be
/// used) -- see [reason] for which.
final class ReferenceRateUnavailable extends ReferenceRateResult {
  const ReferenceRateUnavailable({
    required this.reason,
    required this.message,
  });

  final ReferenceRateUnavailableReason reason;

  /// A short, user/log-displayable description of what went wrong.
  final String message;
}
