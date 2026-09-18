import 'reference_fx_rate.dart';

/// A vendor-neutral source of current [ReferenceFxRate] quotes.
///
/// This is an abstraction only -- CP9.2 defines the interface and a
/// hand-written fake for tests; it deliberately ships **no** concrete
/// implementation that talks to a real vendor (no API key, no HTTP
/// client, no URL, no network access of any kind). Wiring a real
/// provider is out-of-scope future work -- see the CP9.2 report's
/// "DEFERRED CP9.x WORK" section.
///
/// # Why batch-shaped
///
/// [fetchRates] asks for one [baseCurrencyCode] against a *set* of
/// [quoteCurrencyCodes] rather than a single pair at a time. A real FX
/// vendor API call has fixed latency/rate-limit cost per request
/// regardless of how many quote currencies are requested against one
/// base, so a provider that only supported one pair per call would
/// force `n` round-trips for `n` currencies against the same base
/// (e.g. a user's home currency against every balance/favorite
/// currency) -- pure waste against the exact use case CP9.2's checkpoint
/// calls out. [ReferenceFxRateService.referenceRate] -- the actual
/// single-pair public surface CP9.2 exposes -- simply calls this with a
/// one-element [quoteCurrencyCodes] set, so nothing about the single-pair
/// call site becomes more complex for it.
///
/// # Contract
///
/// A conforming implementation:
/// - Never returns a raw vendor/network exception to its caller -- any
///   failure (network, parsing, vendor error response, ...) is reported
///   as an [FxRateProviderFailure], never thrown.
/// - Returns each successfully-quoted pair as an already-validated
///   [ReferenceFxRate] (so [ReferenceFxRate]'s own construction-time
///   invariants -- non-empty source, valid positive exact rate, known
///   currency codes -- are already satisfied by the time
///   [ReferenceFxRateService] sees it).
/// - Does not need to return every requested quote currency (a partial
///   response listing only the pairs it could quote is valid); it is
///   the caller's job to check whether the pair it actually needed came
///   back, and never to assume order or list length.
/// - Does not attempt to invert, substitute, or relabel a pair. A quote
///   for `EUR -> USD` is never used to answer a `USD -> EUR` request.
abstract class FxRateProvider {
  /// Fetches current rates from [baseCurrencyCode] to each currency in
  /// [quoteCurrencyCodes].
  ///
  /// Returns an [FxRateProviderResult] -- never throws for an ordinary
  /// provider-side failure (see class doc); an [ArgumentError] from
  /// [CurrencyRegistry.require]-style validation of malformed *inputs*
  /// (an unknown currency code passed in by the caller) is a
  /// programmer-error case and is not required to be caught here.
  Future<FxRateProviderResult> fetchRates({
    required String baseCurrencyCode,
    required Set<String> quoteCurrencyCodes,
  });
}

/// The result of [FxRateProvider.fetchRates] -- exactly one of
/// [FxRateProviderSuccess] or [FxRateProviderFailure]. Modeled as a
/// sealed class (Dart 3 pattern matching, already used elsewhere in this
/// codebase, e.g. `FxConverter._decompose`'s record return) rather than a
/// nullable/exception-based API, so callers are forced to handle both
/// outcomes explicitly.
sealed class FxRateProviderResult {
  const FxRateProviderResult();
}

/// The provider successfully returned zero or more quotes.
///
/// An empty [rates] list is a valid (if unhelpful) success -- it means
/// the provider was reachable and responded but had nothing to quote
/// for any of the requested currencies; it is still the caller's job to
/// check whether the specific pair it needed is present, exactly as it
/// would for a partial response.
final class FxRateProviderSuccess extends FxRateProviderResult {
  const FxRateProviderSuccess(this.rates);

  /// The quotes the provider was able to return. Each entry is already a
  /// fully-validated [ReferenceFxRate] -- see [FxRateProvider]'s class
  /// doc.
  final List<ReferenceFxRate> rates;
}

/// The provider could not return rates at all (vendor error, network
/// failure, malformed response, ...), reduced to a domain-level failure
/// with no raw exception/vendor detail leaking through.
final class FxRateProviderFailure extends FxRateProviderResult {
  const FxRateProviderFailure(this.message);

  /// A short, non-vendor-specific description of what went wrong.
  final String message;
}
