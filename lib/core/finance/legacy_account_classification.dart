import 'balance_class.dart';
import 'financial_account_subtype.dart';

/// The result of classifying a legacy `Accounts.type` free-text value
/// into the frozen [BalanceClass]/[FinancialAccountSubtype] pair -- see
/// `docs/20_ACCOUNTS_ASSETS_HOUSEHOLD_ARCHITECTURE.md` §13.1 and the
/// Checkpoint B brief's "conservative migration decision."
typedef LegacyAccountClassification = ({
  BalanceClass balanceClass,
  FinancialAccountSubtype subtype,
});

/// Maps a legacy `Accounts.type` string to its frozen
/// `balanceClass`/`subtype` pair -- the SAME mapping schema v9's
/// migration backfills existing rows with (see
/// `AppDatabase.migration`'s `from < 9` branch) and that
/// `AccountRepository.createAccount` uses to classify every account the
/// current (not-yet-redesigned) Add Account UX creates. Kept here as a
/// single, independently-unit-testable source of truth rather than
/// duplicated inline in both places.
///
/// Every legacy `type` -- including the one genuinely ambiguous 'card'
/// -- classifies to [BalanceClass.asset]. This checkpoint never guesses
/// [BalanceClass.liability] for anything (docs/20 §13.1): the richer Add
/// Credit Card flow that can correctly capture a real credit limit and
/// current-owed figure is future work (docs/20 §12.6/§13.4, checkpoint
/// E/G), not this one.
///
/// An unrecognized [legacyType] (anything other than 'cash', 'bank',
/// 'wallet', 'card') returns
/// [FinancialAccountSubtype.legacyUnknownNeedsReview] -- never guessed
/// as one of the other subtypes, per the Checkpoint B brief's "if
/// unexpected/unknown legacy type strings exist, DO NOT guess."
///
/// NOTE: schema v9's migration (`app_database.dart`) does NOT call this
/// function -- it uses hand-written SQL literals instead, deliberately,
/// so a shipped migration remains a frozen historical artifact
/// independent of this function ever being refactored. See that
/// migration step's own doc comment.
LegacyAccountClassification classifyLegacyAccountType(String legacyType) {
  switch (legacyType) {
    case 'cash':
      return (balanceClass: BalanceClass.asset, subtype: FinancialAccountSubtype.cash);
    case 'bank':
      return (balanceClass: BalanceClass.asset, subtype: FinancialAccountSubtype.bank);
    case 'wallet':
      return (balanceClass: BalanceClass.asset, subtype: FinancialAccountSubtype.wallet);
    case 'card':
      return (
        balanceClass: BalanceClass.asset,
        subtype: FinancialAccountSubtype.legacyCardNeedsReview,
      );
    default:
      return (
        balanceClass: BalanceClass.asset,
        subtype: FinancialAccountSubtype.legacyUnknownNeedsReview,
      );
  }
}
