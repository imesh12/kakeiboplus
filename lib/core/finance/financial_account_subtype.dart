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
/// Checkpoint F adds [deposit] -- docs/20 §12.1's frozen `DepositDetails`
/// asset subtype: a `FinancialAccount` with `subtype: deposit` is the
/// only account shape a `DepositDetails` row
/// (`lib/core/database/repositories/deposit_repository.dart`) may ever
/// attach to. No migration ever backfills an existing row to this value
/// -- exactly the same "never auto-convert a legacy row" discipline
/// [creditCard] already established; a `deposit`-subtype account can
/// only ever be created going forward, and only through
/// `DepositRepository.createDetails` attaching metadata to an
/// already-asset-classified account (Checkpoint F ships no Add Account
/// UX either -- docs/20 §13.4 checkpoint G).
///
/// Checkpoint K adds [savings] -- resolving docs/20 §13.5 open question
/// 1 ("bank is not split") by giving Savings its own first-class
/// subtype rather than continuing to alias [bank]. A `FinancialAccount`
/// with `subtype: savings` is a normal, liquid asset -- identical to
/// [bank]/[cash]/[wallet] for every accounting purpose (availability,
/// net worth, lifecycle); the only thing that distinguishes it from
/// those is this subtype value itself. `checking` remains NOT defined
/// here -- out of scope for Checkpoint K, which only adds the one value
/// its brief calls for. No migration ever backfills an existing row to
/// this value: `classifyLegacyAccountType` never returns it, so an
/// existing `bank`-subtype account (created before this checkpoint)
/// keeps its `bank` subtype forever, never heuristically reclassified.
/// `subtype` is a plain `TextColumn` (matching this schema's
/// enum-as-text convention -- see `Transactions.type`'s doc comment in
/// `tables.dart`), so adding this value needed no schema migration --
/// exactly as this doc comment predicted before Checkpoint K.
///
/// Stored as [storageValue]. [fromStorageValue] never throws on an
/// unrecognized/corrupt value -- falling back to
/// [legacyUnknownNeedsReview], the same "needs review, never guessed"
/// value this checkpoint's migration itself falls back to for an
/// unrecognized legacy `type`.
enum FinancialAccountSubtype {
  cash('cash'),
  bank('bank'),
  savings('savings'),
  wallet('wallet'),
  creditCard('creditCard'),
  deposit('deposit'),
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
