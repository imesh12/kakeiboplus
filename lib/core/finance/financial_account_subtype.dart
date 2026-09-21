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
/// Checkpoint E adds [creditCard] -- docs/20 §12.1's frozen
/// `CreditFacilityDetails` liability subtype: a `FinancialAccount` with
/// `subtype: creditCard` is the only account shape a `CreditFacilityDetails`
/// row (`lib/core/database/repositories/credit_facility_repository.dart`)
/// may ever attach to, and the only liability shape a `creditCard`
/// `PaymentInstrument` (already frozen by Checkpoint D) may ever link
/// to. No migration ever backfills an existing row to this value --
/// `classifyLegacyAccountType` (this checkpoint's own conservative
/// migration policy, docs/20 §13.1) never returns it, matching that
/// policy's explicit "never auto-convert a legacy `card` row to a
/// liability" rule; a `creditCard`-subtype account can only ever be
/// created going forward, through `CreditFacilityRepository.createFacility`
/// (which itself never creates the underlying `FinancialAccount` row --
/// Checkpoint E ships no Add Account UX, docs/20 §13.4 checkpoint G).
///
/// Deliberately still NOT defined here: `checking`/`savings` (bank is
/// not split -- docs/20 §13.5 open question 1, unresolved by design) or
/// `deposit` (docs/20 §12.1's other liability/asset-detail subtype --
/// Checkpoint F's own scope, not E's). `subtype` is a plain `TextColumn`
/// (matching this schema's enum-as-text convention -- see
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
  creditCard('creditCard'),
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
