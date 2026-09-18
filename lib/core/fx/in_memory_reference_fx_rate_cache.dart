import 'reference_fx_rate.dart';
import 'reference_fx_rate_cache.dart';

/// The only [ReferenceFxRateCache] implementation CP9.2 ships: a plain
/// in-process `Map`, scoped to this object's own lifetime.
///
/// # This is NOT persistent -- read this before reusing it
///
/// Nothing here survives an app restart, a hot restart, or this object
/// being garbage-collected. There is deliberately no Drift table backing
/// it: no current/reference-rate table exists in the schema today (only
/// the historical `transaction_exchange_rates` table from CP9.1) and
/// adding one is a genuine migration (schema v6 -> v7), which CP9.2's
/// Database Migration Gate explicitly forbids implementing without a
/// separate, dedicated approval. See the CP9.2 report's "AUDIT RESULT"
/// and "DEFERRED CP9.x WORK" sections for the full reasoning.
///
/// Do not wrap this in anything that implies durability (e.g. don't name
/// a future decorator "PersistentReferenceFxRateCache" while it's really
/// just this class underneath) -- when durable caching is actually
/// approved, it should get its own migration-backed implementation of
/// [ReferenceFxRateCache], not a relabeling of this one.
class InMemoryReferenceFxRateCache implements ReferenceFxRateCache {
  final Map<String, ReferenceFxRate> _entries = <String, ReferenceFxRate>{};

  /// Keys are the ordered pair, uppercased -- so `(EUR, USD)` and
  /// `(USD, EUR)` are always distinct slots (see [ReferenceFxRateCache]'s
  /// "Pair safety" doc). The separator is a character that can never
  /// appear inside an ISO 4217 alphabetic code, so this can never
  /// collide two different pairs onto the same key.
  static String _key(String baseCurrencyCode, String quoteCurrencyCode) =>
      '${baseCurrencyCode.toUpperCase()}|${quoteCurrencyCode.toUpperCase()}';

  @override
  ReferenceFxRate? get({
    required String baseCurrencyCode,
    required String quoteCurrencyCode,
  }) =>
      _entries[_key(baseCurrencyCode, quoteCurrencyCode)];

  @override
  void put(ReferenceFxRate rate) {
    _entries[_key(rate.baseCurrencyCode, rate.quoteCurrencyCode)] = rate;
  }

  @override
  void removeIfPresent({
    required String baseCurrencyCode,
    required String quoteCurrencyCode,
  }) {
    _entries.remove(_key(baseCurrencyCode, quoteCurrencyCode));
  }
}
