import '../currency/currency.dart';
import '../currency/currency_registry.dart';
import 'fx_rate_provider.dart';
import 'reference_fx_rate.dart';
import 'reference_fx_rate_cache.dart';
import 'reference_rate_result.dart';

/// Returns the current UTC instant. A plain `typedef` (this project has
/// no shared `Clock` abstraction anywhere -- every existing repository
/// calls `DateTime.now().toUtc()` inline at its own call sites) --
/// intentionally scoped to just this service rather than retrofitted
/// project-wide, per CP9.2's explicit instruction. Tests inject a fake
/// implementation to get deterministic freshness-boundary behavior;
/// production code can omit it entirely and get real wall-clock time
/// (see [ReferenceFxRateService]'s constructor).
typedef NowUtc = DateTime Function();

/// Resolves a current reference exchange rate for one currency pair,
/// deterministically combining a local [ReferenceFxRateCache] with an
/// [FxRateProvider] refresh.
///
/// # Control flow (per call to [referenceRate])
///
/// 1. Same currency? -> [ReferenceRateIdentity] immediately. No cache or
///    provider is touched at all.
/// 2. Cache has an entry for this exact pair, and it's still fresh
///    (within [freshnessWindow] of [ReferenceFxRate.fetchedAt], measured
///    against [nowUtc]) -> [ReferenceRateFresh] straight from cache. No
///    provider call.
/// 3. Otherwise, call the provider:
///    - Success, and it quoted the exact requested pair, and that
///      quote's [ReferenceFxRate.observedAt] is not in the future ->
///      cache it and return [ReferenceRateFresh].
///    - Success, but it didn't quote the requested pair -> fall back to
///      the stale cached entry if one exists ([ReferenceRateStale]),
///      else [ReferenceRateUnavailable] with
///      [ReferenceRateUnavailableReason.pairMismatch]. The mismatched
///      quote is never used for this pair.
///    - Success, quoted the right pair, but [ReferenceFxRate.observedAt]
///      is in the future relative to [nowUtc] -> same stale-or-unavailable
///      fallback, with [ReferenceRateUnavailableReason.invalidProviderData]
///      when there's nothing to fall back to.
///    - Failure -> same stale-or-unavailable fallback, with
///      [ReferenceRateUnavailableReason.providerFailed] when there's
///      nothing to fall back to.
///
/// A provider failure or bad response is never silently swallowed into
/// an empty/zero/default rate -- every outcome is one of
/// [ReferenceRateResult]'s four explicit cases.
///
/// # Freshness contract
///
/// Age is always measured as `nowUtc() - rate.fetchedAt` (never
/// `observedAt`, which is the provider's own, less-trustworthy clock),
/// entirely in UTC instants, with exactly one call to [nowUtc] per
/// [referenceRate] invocation (never scattered `DateTime.now()` calls
/// that could observe different instants mid-decision). The boundary is
/// inclusive: an age exactly equal to [freshnessWindow] still counts as
/// fresh; anything strictly greater is stale. [freshnessWindow] defaults
/// to one hour -- no freshness duration is documented anywhere in
/// `docs/14_DECISION_LOG.md` or the schema blueprint, so this follows
/// CP9.2's own suggested default exactly.
///
/// # Accounting safety
///
/// This service never attaches a rate to a transaction, never converts a
/// historical amount, and never touches any balance/budget/income-
/// expense/savings-goal figure. It answers exactly one question --
/// "what's the current reference rate for this pair" -- for future
/// display consumers to use however they choose.
class ReferenceFxRateService {
  ReferenceFxRateService({
    required FxRateProvider provider,
    required ReferenceFxRateCache cache,
    NowUtc? nowUtc,
    this.freshnessWindow = const Duration(hours: 1),
  })  : _provider = provider,
        _cache = cache,
        _nowUtc = nowUtc ?? DateTime.now;

  final FxRateProvider _provider;
  final ReferenceFxRateCache _cache;
  final NowUtc _nowUtc;

  /// How old a cached [ReferenceFxRate.fetchedAt] may be and still count
  /// as fresh. See the class doc's "Freshness contract" section for the
  /// exact (inclusive) boundary semantics.
  final Duration freshnessWindow;

  /// Resolves the current reference rate from [baseCurrencyCode] to
  /// [quoteCurrencyCode]. See the class doc for the full decision flow.
  ///
  /// Throws [ArgumentError] (via [CurrencyRegistry.require]) if either
  /// code isn't a known currency -- a caller passing an unknown currency
  /// code is a programmer error, not a recoverable runtime condition,
  /// exactly like every other `CurrencyRegistry.require` call site in
  /// this codebase.
  Future<ReferenceRateResult> referenceRate({
    required String baseCurrencyCode,
    required String quoteCurrencyCode,
  }) async {
    final Currency base = CurrencyRegistry.require(baseCurrencyCode);
    final Currency quote = CurrencyRegistry.require(quoteCurrencyCode);

    if (base.code == quote.code) {
      // Same currency: no external rate is meaningful, so neither the
      // cache nor the provider is consulted at all -- deterministic
      // identity behavior, regardless of which currency (0-decimal like
      // JPY, 3-decimal like KWD, or anything else).
      return ReferenceRateIdentity(base.code);
    }

    final ReferenceFxRate? cached = await _cache.get(
      baseCurrencyCode: base.code,
      quoteCurrencyCode: quote.code,
    );
    final DateTime now = _nowUtc().toUtc();

    if (cached != null && _isFresh(cached, now)) {
      return ReferenceRateFresh(cached);
    }

    final FxRateProviderResult providerResult = await _provider.fetchRates(
      baseCurrencyCode: base.code,
      quoteCurrencyCodes: <String>{quote.code},
    );

    switch (providerResult) {
      case FxRateProviderSuccess(rates: final List<ReferenceFxRate> rates):
        final ReferenceFxRate? match = _findExactPair(
          rates,
          baseCurrencyCode: base.code,
          quoteCurrencyCode: quote.code,
        );

        if (match == null) {
          return _staleOrUnavailable(
            cached,
            reason: ReferenceRateUnavailableReason.pairMismatch,
            message:
                'Provider did not return a $baseCurrencyCode -> $quoteCurrencyCode quote.',
          );
        }

        if (match.observedAt.isAfter(now)) {
          // A future-dated observation cannot be a genuinely-already-
          // observed market rate. Reject deliberately rather than
          // accept it or silently clamp it to "now".
          return _staleOrUnavailable(
            cached,
            reason: ReferenceRateUnavailableReason.invalidProviderData,
            message: 'Provider rate has an observedAt timestamp in the future.',
          );
        }

        await _cache.put(match);
        return ReferenceRateFresh(match);

      case FxRateProviderFailure(message: final String message):
        return _staleOrUnavailable(
          cached,
          reason: ReferenceRateUnavailableReason.providerFailed,
          message: message,
        );
    }
  }

  bool _isFresh(ReferenceFxRate rate, DateTime now) =>
      now.difference(rate.fetchedAt) <= freshnessWindow;

  ReferenceFxRate? _findExactPair(
    List<ReferenceFxRate> rates, {
    required String baseCurrencyCode,
    required String quoteCurrencyCode,
  }) {
    for (final ReferenceFxRate candidate in rates) {
      if (candidate.baseCurrencyCode == baseCurrencyCode &&
          candidate.quoteCurrencyCode == quoteCurrencyCode) {
        return candidate;
      }
    }
    return null;
  }

  /// Falls back to the stale cached rate if one exists, else reports
  /// [ReferenceRateUnavailable] with [reason]/[message]. Shared by every
  /// "the provider didn't give us a usable fresh quote" path so the
  /// fallback rule can't drift between them.
  ReferenceRateResult _staleOrUnavailable(
    ReferenceFxRate? cached, {
    required ReferenceRateUnavailableReason reason,
    required String message,
  }) {
    if (cached != null) {
      return ReferenceRateStale(cached);
    }
    return ReferenceRateUnavailable(reason: reason, message: message);
  }
}
