/// Whether a `FinancialAccount` (physically still the `accounts` table
/// -- see `docs/20_ACCOUNTS_ASSETS_HOUSEHOLD_ARCHITECTURE.md` §13.1)
/// represents money owned ([asset]) or money owed ([liability]). This is
/// the frozen sign-convention classification from that document's §12.2
/// ("Freeze immutability invariants") / §12.3 ("Freeze balance sign
/// semantics") -- see ADR-035.
///
/// Checkpoint B (schema v9) only ever writes [asset]: the current Add
/// Account UX cannot create a liability yet (see the Checkpoint B
/// brief), and every migrated legacy account -- even an ambiguous
/// `type: 'card'` row -- becomes an [asset], never guessed as a
/// [liability] (docs/20 §13.1). `FinanceEngine` does not yet read this
/// value at all -- that adaptation is Checkpoint C's (docs/20 §13.4).
///
/// Stored as [storageValue] in the plain `TextColumn balanceClass` --
/// same enum-as-text convention `CloudAccountLinkStatus` already
/// established for `cloud_account_links.status` (see that class's own
/// doc). [fromStorageValue] never throws on an unrecognized/corrupt
/// value -- falling back to [asset] is the safe choice: an account's
/// `balanceClass` is architecturally immutable once it has history
/// (docs/20 §12.2), and defaulting a corrupt value to "owned" rather
/// than "owed" never overstates what the user owes.
enum BalanceClass {
  asset('asset'),
  liability('liability');

  const BalanceClass(this.storageValue);

  final String storageValue;

  static BalanceClass fromStorageValue(String value) {
    return BalanceClass.values.firstWhere(
      (BalanceClass balanceClass) => balanceClass.storageValue == value,
      orElse: () => BalanceClass.asset,
    );
  }
}
