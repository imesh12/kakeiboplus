import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../fx/fx_rate.dart';
import '../../fx/fx_snapshot.dart';
import '../../money/money.dart';
import '../app_database.dart';
import 'fx_snapshot_already_exists_exception.dart';

/// Persists and reads back historical FX conversion snapshots attached
/// to a [Transaction] row, via the `transaction_exchange_rates` table.
///
/// That table has existed in the schema since v1 (Beta 0) -- reserved
/// per `docs/14_DECISION_LOG.md` ADR-009/ADR-010/ADR-020 specifically so
/// this checkpoint (CP9.1) would never need a migration. No production
/// code path writes to it before this checkpoint.
///
/// # Immutability (ADR-010)
///
/// There is deliberately no `update`/`replace` method on this
/// repository. [attach] is the only write path, and it throws
/// [FxSnapshotAlreadyExistsException] if [transactionId] already has a
/// snapshot -- the same "enforce the one-row invariant at the
/// application layer, since the table itself has no DB-level uniqueness
/// constraint on `transaction_id`" precedent `BudgetRepository`
/// (one-active-row-per-key) and `RecurringOccurrenceRepository`
/// (one-row-per-rule/date) already establish elsewhere in this codebase.
/// The check-then-insert here is not concurrency-safe against two
/// simultaneous writers -- acceptable under the same local-only,
/// single-writer-at-a-time scope those repositories document. A newer
/// market rate becoming available can never rewrite an existing
/// transaction's historical conversion.
///
/// # Scope (CP9.1 is foundation only)
///
/// Nothing calls [attach] from any transaction-creation/edit flow yet --
/// CP9.1 does not start automatically converting every transaction. This
/// repository has no join to, and no effect on,
/// `FinanceEngine`/balance/budget/income/expense calculations, which
/// read the `transactions` table directly; attaching a snapshot to a
/// transaction changes nothing about how that transaction is totaled or
/// balanced.
///
/// # DateTime instants (`providerTimestamp`/`fetchedAt`) are always UTC
///
/// Same Drift default-`DateTime`-storage caveat as
/// `SavingsGoalRepository._withUtcDateTimes` and
/// `SavingsGoalContributionRepository._withUtcDateTimes` (see those
/// classes' doc comments): for `NativeDatabase`'s default (non-text)
/// `DateTime` column encoding, the underlying instant round-trips
/// correctly through SQLite, but is reconstructed on read tagged as
/// *local* time, not UTC -- `.toUtc()` never moves that instant, it only
/// re-tags it. Left alone, that local-tagged value fails Dart's
/// `DateTime.==` against a UTC-tagged expectation even though both
/// represent the exact same moment (this is exactly what produced the
/// apparent "+9 hours" symptom on a UTC+9 machine: the same instant,
/// printed via a local-tagged `DateTime.toString()`).
///
/// [providerTimestamp] and [fetchedAt] are absolute instants -- an FX
/// provider quote observed/fetched at a specific moment -- not
/// calendar-only dates, so both directions are normalized here rather
/// than left to whatever tag happens to survive the round trip:
///
///  - **Write** ([attach]): both are normalized to UTC via `.toUtc()`
///    before being persisted, so a caller passing a local-offset
///    `DateTime` (or any other zone) still stores the correct instant
///    -- normalizing at the write boundary, not just the read boundary,
///    is what makes this timezone-independent regardless of what a
///    caller happens to pass in.
///  - **Read** ([_toDomain]): both are re-tagged back to UTC on the way
///    out, mirroring [SavingsGoalRepository]/[SavingsGoalContributionRepository]'s
///    established pattern.
///
/// Net effect: [FxSnapshot.providerTimestamp]/[FxSnapshot.fetchedAt] are
/// always UTC-tagged `DateTime`s representing the same instant that was
/// given to [attach], on every device in every timezone -- this is
/// exactly what a historical FX snapshot's immutability guarantee
/// requires (see the class doc above): the recorded instant can never
/// silently drift depending on which machine reads it back.
class TransactionExchangeRateRepository {
  TransactionExchangeRateRepository(this._db);

  final AppDatabase _db;
  static const Uuid _uuid = Uuid();

  FxSnapshot _toDomain(TransactionExchangeRate row) {
    return FxSnapshot(
      id: row.id,
      transactionId: row.transactionId,
      rate: FxRate(
        baseCurrencyCode: row.baseCurrency,
        quoteCurrencyCode: row.quoteCurrency,
        rate: row.rate,
      ),
      convertedAmount: Money.fromMinorUnits(row.convertedAmountMinorUnits, row.quoteCurrency),
      source: row.provider,
      // Re-tag to UTC on the way out -- see the class doc's "DateTime
      // instants are always UTC" section. `.toUtc()` never moves the
      // underlying instant, so this cannot alter any already-persisted
      // data.
      providerTimestamp: row.providerTimestamp.toUtc(),
      fetchedAt: row.fetchedAt.toUtc(),
      isManual: row.isManual,
    );
  }

  /// The historical snapshot attached to [transactionId], or `null` if
  /// none has been attached yet.
  Future<FxSnapshot?> forTransaction(String transactionId) async {
    final TransactionExchangeRate? row = await (_db.select(_db.transactionExchangeRates)
          ..where((tbl) => tbl.transactionId.equals(transactionId)))
        .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  /// Attaches a historical FX snapshot to [transactionId].
  ///
  /// [convertedAmount] must already be denominated in
  /// [rate].quoteCurrencyCode -- this never relabels or re-derives it;
  /// the caller (typically `FxConverter.convert`'s result) is
  /// responsible for having computed it correctly.
  ///
  /// [providerTimestamp] and [fetchedAt] are absolute instants and are
  /// normalized to UTC (via `.toUtc()`) before being persisted -- see
  /// the class doc's "DateTime instants are always UTC" section. Passing
  /// a local-offset (non-UTC-tagged) `DateTime` still stores the correct
  /// instant; only the *tag* is normalized, never the moment itself.
  ///
  /// Throws [FxSnapshotAlreadyExistsException] if [transactionId]
  /// already has a snapshot -- see the class doc for why there is no
  /// update path instead. Throws [ArgumentError] if [convertedAmount]'s
  /// currency doesn't match [rate].quoteCurrencyCode.
  Future<String> attach({
    required String transactionId,
    required FxRate rate,
    required Money convertedAmount,
    required String source,
    required DateTime providerTimestamp,
    required DateTime fetchedAt,
    bool isManual = false,
  }) async {
    if (convertedAmount.currencyCode != rate.quoteCurrencyCode) {
      throw ArgumentError.value(
        convertedAmount,
        'convertedAmount',
        "Must be denominated in ${rate.quoteCurrencyCode} (the rate's quote currency).",
      );
    }

    final FxSnapshot? existing = await forTransaction(transactionId);
    if (existing != null) {
      throw FxSnapshotAlreadyExistsException(transactionId);
    }

    final String id = _uuid.v4();
    await _db.into(_db.transactionExchangeRates).insert(
          TransactionExchangeRatesCompanion.insert(
            id: id,
            transactionId: transactionId,
            baseCurrency: rate.baseCurrencyCode,
            quoteCurrency: rate.quoteCurrencyCode,
            rate: rate.rateAsString,
            convertedAmountMinorUnits: convertedAmount.minorUnits,
            provider: source,
            // Normalized to UTC at the write boundary -- see the class
            // doc and this method's own doc comment. `.toUtc()` never
            // moves the instant a caller passed in, it only ensures the
            // stored/round-tripped value is anchored to a UTC tag
            // rather than whatever zone the caller's DateTime happened
            // to carry.
            providerTimestamp: providerTimestamp.toUtc(),
            fetchedAt: fetchedAt.toUtc(),
            isManual: Value<bool>(isManual),
          ),
        );
    return id;
  }
}
