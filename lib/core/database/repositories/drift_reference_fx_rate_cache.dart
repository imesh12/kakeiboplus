import 'package:drift/drift.dart';

import '../../fx/fx_rate.dart';
import '../../fx/reference_fx_rate.dart';
import '../../fx/reference_fx_rate_cache.dart';
import '../app_database.dart';

/// The persistent [ReferenceFxRateCache] implementation — Checkpoint 9.3
/// — backed by the `reference_exchange_rates` table (schema v7, see
/// `lib/core/database/tables.dart`'s `ReferenceExchangeRates` doc for the
/// full table design, including why its primary key is the composite
/// `(baseCurrency, quoteCurrency)` pair).
///
/// This survives an app restart, unlike `InMemoryReferenceFxRateCache`
/// (which remains available for tests and any context a database isn't
/// appropriate for — see `lib/core/fx/reference_fx_rate_providers.dart`).
///
/// # No freshness logic here
///
/// This class only ever does exact-pair reads/writes. Whether a cached
/// row still counts as "fresh" is entirely `ReferenceFxRateService`'s
/// decision (see that class's "Freshness contract" doc) — this cache
/// never inspects [ReferenceFxRate.fetchedAt]/`observedAt` to decide
/// whether to return, keep, or refuse a row. It always returns exactly
/// what's stored for the requested pair, or `null`.
///
/// # Upsert, not reject-on-duplicate
///
/// [put] always succeeds and always leaves exactly one row for
/// [ReferenceFxRate.baseCurrencyCode]/[ReferenceFxRate.quoteCurrencyCode]
/// — an existing row for that exact pair is replaced in place
/// (`INSERT ... ON CONFLICT(...) DO UPDATE`, via Drift's
/// `insertOnConflictUpdate`), never duplicated, and never rejected. This
/// is a deliberately different invariant from
/// `TransactionExchangeRateRepository.attach`, which throws
/// `FxSnapshotAlreadyExistsException` on a second write for the same
/// transaction — that table is immutable history; this one is a
/// replaceable cache (see `ReferenceExchangeRates`'s class doc for the
/// full "why a different rule" rationale).
class DriftReferenceFxRateCache implements ReferenceFxRateCache {
  DriftReferenceFxRateCache(this._db);

  final AppDatabase _db;

  ReferenceFxRate _toDomain(ReferenceExchangeRate row) {
    return ReferenceFxRate(
      rate: FxRate(
        baseCurrencyCode: row.baseCurrency,
        quoteCurrencyCode: row.quoteCurrency,
        rate: row.rate,
      ),
      source: row.provider,
      // Re-tag to UTC on the way out -- identical rationale to
      // `TransactionExchangeRateRepository._toDomain`'s own doc comment
      // ("DateTime instants are always UTC"): Drift's default
      // (non-text) DateTime storage round-trips the correct instant but
      // reconstructs it tagged as local time, not UTC. `.toUtc()` never
      // moves the instant, it only re-tags it, so this cannot alter any
      // already-persisted data -- it just makes the returned
      // `DateTime`s satisfy `isUtc == true` the way every other FX
      // repository in this codebase already does.
      observedAt: row.observedAt.toUtc(),
      fetchedAt: row.fetchedAt.toUtc(),
    );
  }

  @override
  Future<ReferenceFxRate?> get({
    required String baseCurrencyCode,
    required String quoteCurrencyCode,
  }) async {
    // Canonical (upper-case) lookup -- matches `FxRate`/`ReferenceFxRate`
    // /`CurrencyRegistry`'s own canonicalization, so a caller passing a
    // lower/mixed-case code still finds an entry stored under its
    // canonical form. Never falls back to the inverse pair -- see the
    // interface's "Pair safety" doc.
    final ReferenceExchangeRate? row = await (_db.select(_db.referenceExchangeRates)
          ..where(
            (tbl) =>
                tbl.baseCurrency.equals(baseCurrencyCode.toUpperCase()) &
                tbl.quoteCurrency.equals(quoteCurrencyCode.toUpperCase()),
          ))
        .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<void> put(ReferenceFxRate rate) async {
    await _db.into(_db.referenceExchangeRates).insertOnConflictUpdate(
          ReferenceExchangeRatesCompanion.insert(
            baseCurrency: rate.baseCurrencyCode,
            quoteCurrency: rate.quoteCurrencyCode,
            // `FxRate.rateAsString` -- the canonical, round-trip-stable
            // plain-decimal-string form (never `double`/REAL). See
            // `FxRate`'s own doc for why this always reconstructs the
            // exact same `Decimal`.
            rate: rate.rate.rateAsString,
            provider: rate.source,
            // Normalized to UTC at the write boundary -- same rationale
            // as `TransactionExchangeRateRepository.attach`: `.toUtc()`
            // never moves the instant a caller passed in, it only
            // ensures the stored/round-tripped value is anchored to a
            // UTC tag rather than whatever zone the caller's `DateTime`
            // happened to carry (`ReferenceFxRate`'s own constructor
            // already does this normalization too, so this is a
            // defensive no-op in the normal path, not a second source
            // of truth for it).
            observedAt: rate.observedAt.toUtc(),
            fetchedAt: rate.fetchedAt.toUtc(),
          ),
        );
  }

  @override
  Future<void> removeIfPresent({
    required String baseCurrencyCode,
    required String quoteCurrencyCode,
  }) async {
    // A no-op (zero rows deleted, no exception) if nothing is cached for
    // this exact pair -- see the interface's doc. Never touches the
    // reverse pair.
    await (_db.delete(_db.referenceExchangeRates)
          ..where(
            (tbl) =>
                tbl.baseCurrency.equals(baseCurrencyCode.toUpperCase()) &
                tbl.quoteCurrency.equals(quoteCurrencyCode.toUpperCase()),
          ))
        .go();
  }
}
