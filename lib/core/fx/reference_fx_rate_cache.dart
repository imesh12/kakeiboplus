import 'reference_fx_rate.dart';

/// A cache of current [ReferenceFxRate] quotes, keyed by the exact
/// `(baseCurrencyCode, quoteCurrencyCode)` pair.
///
/// This is an interface only. See [InMemoryReferenceFxRateCache] (in
/// -process, restart-volatile -- for tests and any context a database
/// isn't appropriate for) and `DriftReferenceFxRateCache`
/// (`lib/core/database/repositories/drift_reference_fx_rate_cache.dart`,
/// CP9.3 -- persistent, backed by the `reference_exchange_rates` table)
/// for the two implementations this codebase ships. Neither claims more
/// durability than it actually has.
///
/// # CP9.3 interface change: `Future`-based
///
/// CP9.2 originally declared `get`/`put`/`removeIfPresent` as
/// synchronous. CP9.3 makes all three `Future`-returning, because a
/// genuinely persistent cache is backed by Drift/SQLite, and Drift's
/// query API is `Future`-based end to end -- there is no synchronous way
/// to read or write a `NativeDatabase` connection. This is the only
/// change CP9.3 makes to this interface; the *shape* of each method
/// (parameters, meaning, pair-safety contract below) is unchanged, and so
/// is [ReferenceFxRateService]'s own contract (`referenceRate` was
/// already `Future`-returning, with the same four
/// `ReferenceRateResult` cases and the same decision flow -- see that
/// class's doc) -- only the plumbing between the service and its cache
/// collaborator became explicitly asynchronous, which it always
/// effectively needed to be for any real database-backed implementation.
/// [InMemoryReferenceFxRateCache] still completes every [Future]
/// synchronously (it never actually awaits I/O), so nothing about its
/// observable behavior changed either -- only its method signatures grew
/// an `async`/`Future<...>`.
///
/// # Pair safety
///
/// A cache entry's key is always the *ordered* pair -- `get`/`put`/
/// `removeIfPresent` for `(EUR, USD)` never reads or writes the same slot
/// as `(USD, EUR)`. Callers must pass canonical currency codes (as
/// [ReferenceFxRate]/[FxRate] already normalize to); this interface does
/// not itself re-validate currency codes.
abstract class ReferenceFxRateCache {
  /// Returns the cached rate for the exact `(baseCurrencyCode,
  /// quoteCurrencyCode)` pair, or `null` if nothing is cached for it.
  /// Never falls back to the inverse pair.
  Future<ReferenceFxRate?> get({
    required String baseCurrencyCode,
    required String quoteCurrencyCode,
  });

  /// Stores [rate], keyed by its own `(baseCurrencyCode,
  /// quoteCurrencyCode)` pair (see [ReferenceFxRate.baseCurrencyCode] /
  /// [ReferenceFxRate.quoteCurrencyCode]). Overwrites (upserts) any
  /// existing entry for that exact pair; never touches any other pair's
  /// entry, and never creates a second row for the same pair.
  Future<void> put(ReferenceFxRate rate);

  /// Removes the cached entry for `(baseCurrencyCode,
  /// quoteCurrencyCode)` if one is present. A no-op (not an error) if
  /// nothing is cached for that pair -- "remove if needed", not an
  /// unconditional/asserting remove. Never removes the reverse pair.
  Future<void> removeIfPresent({
    required String baseCurrencyCode,
    required String quoteCurrencyCode,
  });
}
