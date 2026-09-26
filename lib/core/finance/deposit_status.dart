/// A deposit's maturity status, derived purely from its stored
/// `DepositDetails.maturityDate` compared against the current date --
/// Checkpoint J item 8. This is the ONLY input: no interest/renewal
/// state, no transaction history, and (critically) no
/// `AccountRow.isActive`/`deletedAt` ever participates in this
/// calculation. See this enum's own [fromMaturityDate] doc for exactly
/// why deposit status and account lifecycle status must stay
/// independent concepts that happen to both be shown on the same
/// screen, never conflated into one.
///
/// Deliberately just two values. A real bank might also track "pending
/// funding" or "closed/withdrawn early" states, but this V1 schema
/// stores no data that would let either be determined reliably (docs/20
/// §12.1 -- no funding-confirmation column, no early-withdrawal
/// column) -- inventing either state here would be exactly the
/// "fabricate a status the persisted model cannot actually support"
/// mistake Checkpoint J's own brief warns against. [active]/[matured]
/// are the only two states [DepositDetailsRow.maturityDate] alone can
/// answer reliably.
enum DepositStatus {
  /// Today (in UTC calendar terms) is strictly before the deposit's
  /// [maturityDate] -- the term has not yet elapsed.
  active,

  /// Today is on or after the deposit's [maturityDate] -- the term has
  /// elapsed. This says nothing about whether the principal was
  /// actually withdrawn, rolled over, or left in place: `autoRenew`
  /// exists on `DepositDetails` as a stored declaration of intent, but
  /// V1 implements no automatic renewal/rollover behavior (Checkpoint J
  /// item 10's explicit exclusion), so a matured deposit's account
  /// simply keeps whatever balance it has until the user acts on it.
  matured;

  /// The single source of truth for deriving a [DepositStatus] from
  /// persisted data -- both [maturityDateUtc] and [nowUtc] must already
  /// be calendar-only, UTC-midnight-normalized dates (exactly what
  /// `DepositRepository`'s own `_normalizeCalendarDate`/
  /// `_canonicalizeStoredDate` guarantee for a value read back off
  /// `DepositDetailsRow.maturityDate`, and what callers must normalize
  /// [nowUtc] to themselves via the same convention before calling this
  /// -- see call sites for `DateTime.utc(now.year, now.month, now.day)`).
  /// This function does no normalization itself: it is a pure
  /// comparison, so it can be unit-tested with exact `DateTime.utc(...)`
  /// values without needing a real deposit-account fixture.
  ///
  /// `nowUtc.isBefore(maturityDateUtc)` -> [active];
  /// otherwise (on or after maturity) -> [matured]. Maturity DAY itself
  /// counts as matured, not the last active day -- matching the
  /// "maturityDate = startDate + term" definition: the term has fully
  /// elapsed as of that date.
  static DepositStatus fromMaturityDate({required DateTime maturityDateUtc, required DateTime nowUtc}) {
    return nowUtc.isBefore(maturityDateUtc) ? DepositStatus.active : DepositStatus.matured;
  }
}
