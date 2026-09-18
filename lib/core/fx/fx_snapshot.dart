import 'package:meta/meta.dart';

import '../money/money.dart';
import 'fx_rate.dart';

/// A pure-Dart, database-agnostic view of one historical FX conversion
/// attached to a transaction -- the domain shape
/// `TransactionExchangeRateRepository` maps `TransactionExchangeRate`
/// Drift rows to/from.
///
/// # Immutability (ADR-010)
///
/// Every field here is a historical fact, fixed at the moment this
/// snapshot was created: [rate] and [convertedAmount] are never
/// recomputed or replaced when a newer market rate becomes available
/// later -- see `TransactionExchangeRateRepository`'s class doc for how
/// that's enforced (no update path exists at all).
@immutable
class FxSnapshot {
  const FxSnapshot({
    required this.id,
    required this.transactionId,
    required this.rate,
    required this.convertedAmount,
    required this.source,
    required this.providerTimestamp,
    required this.fetchedAt,
    this.isManual = false,
  });

  final String id;
  final String transactionId;

  /// The exact rate this snapshot was computed with -- see [FxRate]'s
  /// own doc for the directional/exact-decimal contract.
  final FxRate rate;

  /// The converted result, denominated in [rate].quoteCurrencyCode --
  /// already rounded (ROUND HALF UP, ADR-018) at the moment this
  /// snapshot was computed. This is the immutable historical fact; it is
  /// never recomputed from a later/different rate. The transaction's own
  /// original `amount`/`currencyCode` remain the sole authoritative
  /// financial record (ADR-010) -- this is contextual/reference
  /// information only.
  final Money convertedAmount;

  /// Free-text provenance -- a provider name, or `'manual'` for a
  /// user-entered rate. Matches the `provider` column.
  final String source;

  /// When [rate] was actually observed/quoted by [source].
  final DateTime providerTimestamp;

  /// When this snapshot was fetched/computed and persisted.
  final DateTime fetchedAt;

  /// Whether [rate] was entered by the user rather than fetched from a
  /// provider.
  final bool isManual;
}
