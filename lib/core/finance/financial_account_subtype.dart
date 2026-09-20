/// The specific product shape of a `FinancialAccount` (physically still
/// the `accounts` table -- see
/// `docs/20_ACCOUNTS_ASSETS_HOUSEHOLD_ARCHITECTURE.md` §13.1). Frozen by
/// that document's §12.1 -- see ADR-035.
///
/// Checkpoint B (schema v9) only ever produces four of these values:
/// [cash], [bank], and [wallet] for the three unambiguous legacy `type`
/// strings, and [legacyCardNeedsReview] for the one genuinely ambiguous
/// legacy `type` ('card') that must never be auto-converted to a
/// liability (docs/20 §13.1). [legacyUnknownNeedsReview] is the
/// conservative fallback for any legacy `type` string this app has
/// never used -- defensive only; no known production data should hit
/// it, but "do not guess" (the Checkpoint B brief) requires a named,
/// reviewable value to fall back to rather than silently reusing one of
/// the other four.
///
/// Deliberately NOT yet defined here: `creditCard`, `deposit`, or the
/// other subtypes from the frozen architecture's full list (docs/20
/// §12.1) -- Checkpoint B must not overpopulate subtype values merely
/// because a future checkpoint will need them. `subtype` is a plain
/// `TextColumn` (matching this schema's enum-as-text convention -- see
/// `Transactions.type`'s doc comment in `tables.dart`), so a later
/// checkpoint can introduce a new value without a schema migration.
///
/// Stored as [storageValue]. [fromStorageValue] never throws on an
/// unrecognized/corrupt value -- falling back to
/// [legacyUnknownNeedsReview], the same "needs review, never guessed"
/// value this checkpoint's migration itself falls back to for an
/// unrecognized legacy `type`.
enum FinancialAccountSubtype {
  cash('cash'),
  bank('bank'),
  wallet('wallet'),
  legacyCardNeedsReview('legacyCardNeedsReview'),
  legacyUnknownNeedsReview('legacyUnknownNeedsReview');

  const FinancialAccountSubtype(this.storageValue);

  final String storageValue;

  static FinancialAccountSubtype fromStorageValue(String value) {
    return FinancialAccountSubtype.values.firstWhere(
      (FinancialAccountSubtype subtype) => subtype.storageValue == value,
      orElse: () => FinancialAccountSubtype.legacyUnknownNeedsReview,
    );
  }
}
