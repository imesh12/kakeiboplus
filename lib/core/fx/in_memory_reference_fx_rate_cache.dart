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
/// just this class underneath) -- CP9.3 added exactly that as its own
/// separate implementation, `DriftReferenceFxRateCache`
/// (`lib/core/database/repositories/drift_reference_fx_rate_cache.dart`),
/// rather than relabeling this one.
///
/// [ReferenceFxRateCache]'s methods are `Future`-returning (a CP9.3
/// interface change made necessary by that Drift-backed sibling -- see
/// that interface's doc), but every `Future` here still completes
/// synchronously: this class never actually performs I/O.
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
  Future<ReferenceFxRate?> get({
    required String baseCurrencyCode,
    required String quoteCurrencyCode,
  }) async =>
      _entries[_key(baseCurrencyCode, quoteCurrencyCode)];

  @override
  Future<void> put(ReferenceFxRate rate) async {
    _entries[_key(rate.baseCurrencyCode, rate.quoteCurrencyCode)] = rate;
  }

  @override
  Future<void> removeIfPresent({
    required String baseCurrencyCode,
    required String quoteCurrencyCode,
  }) async {
    _entries.remove(_key(baseCurrencyCode, quoteCurrencyCode));
  }
}
