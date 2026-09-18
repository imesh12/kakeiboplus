import 'reference_fx_rate.dart';

/// A cache of current [ReferenceFxRate] quotes, keyed by the exact
/// `(baseCurrencyCode, quoteCurrencyCode)` pair.
///
/// This is an interface only. See [InMemoryReferenceFxRateCache] for the
/// only implementation CP9.2 ships -- an in-memory-only cache that does
/// **not** survive process restart. A durable (cross-restart) cache would
/// require a new Drift table/migration, which is explicitly out of scope
/// for this checkpoint (see the CP9.2 report's "DEFERRED CP9.x WORK"
/// section) -- no implementation of this interface should ever claim
/// durability it doesn't actually have.
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
  ReferenceFxRate? get({
    required String baseCurrencyCode,
    required String quoteCurrencyCode,
  });

  /// Stores [rate], keyed by its own `(baseCurrencyCode,
  /// quoteCurrencyCode)` pair (see [ReferenceFxRate.baseCurrencyCode] /
  /// [ReferenceFxRate.quoteCurrencyCode]). Overwrites any existing entry
  /// for that exact pair; never touches any other pair's entry.
  void put(ReferenceFxRate rate);

  /// Removes the cached entry for `(baseCurrencyCode,
  /// quoteCurrencyCode)` if one is present. A no-op (not an error) if
  /// nothing is cached for that pair -- "remove if needed", not an
  /// unconditional/asserting remove.
  void removeIfPresent({
    required String baseCurrencyCode,
    required String quoteCurrencyCode,
  });
}
