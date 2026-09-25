import 'package:flutter/material.dart';

import '../../../core/finance/financial_account_subtype.dart';
import '../../../l10n/generated/app_localizations.dart';

/// The closed set of account `type` values the V1 Account Detail/Edit
/// Checkpoint's `_AddAccountDialogState` originally let a user choose
/// from. Checkpoint G (Add Account UX) removed that dialog entirely
/// (`accounts_screen.dart`'s FAB now pushes the new type-chooser flow),
/// so [kAccountTypes] is unused by account CREATION today -- its only
/// remaining reader is [kEditableAccountTypeLabels] below, which starts
/// from it. Left exactly as-is (do not add to this specific list) so
/// its historical meaning ("the four values the old create dialog
/// offered") stays unambiguous; see [kEditableAccountTypeLabels] for
/// the list Edit Account actually uses.
const List<String> kAccountTypes = <String>['cash', 'bank', 'card', 'wallet'];

/// Checkpoint G Android regression repair: the account `type` values
/// `EditAccountScreen`'s type dropdown may freely relabel between.
///
/// A superset of [kAccountTypes] adding `'savings'`. `'savings'` is safe
/// to add here specifically (and ONLY here, not to [kAccountTypes] --
/// see that constant's own doc) because `type` is presentation-only
/// (see `AccountRepository.updateAccount`'s doc comment -- editing it
/// never touches `balanceClass`/`subtype`) and `'savings'`/`'bank'`
/// already share the exact same `FinancialAccountSubtype.bank`
/// (`AccountCreationKind.savings`'s own doc) -- offering it here changes
/// only the account's label/icon, never its accounting.
///
/// Deliberately still excludes `'deposit'`/`'creditCard'`: those two
/// subtypes carry a mandatory one-to-one composite record
/// (`DepositDetails`, or `CreditFacilityDetails` + a `creditCard`
/// `PaymentInstrument`) and their own dedicated identity elsewhere in
/// the product. Relabeling one of them away via this dropdown would
/// change nothing about the underlying account (`updateAccount` has no
/// `subtype`/`balanceClass` parameter at all -- see [isAccountTypeEditable]),
/// but WOULD make the account's list/detail icon and label lie about
/// what it actually is. [isAccountTypeEditable] routes those two
/// subtypes to a read-only type display instead (mirroring the
/// existing read-only currency field) rather than offering a dropdown
/// that can't safely include them as options.
const List<String> kEditableAccountTypeLabels = <String>[...kAccountTypes, 'savings'];

/// Whether `EditAccountScreen` may offer [kEditableAccountTypeLabels] as
/// an editable dropdown for an account of this [subtype], or must show
/// a read-only type display instead -- Checkpoint G Android regression
/// repair (docs/20 §13.2: the generic Edit screen "remains the correct
/// destination for every account that doesn't" have a dedicated
/// specialized screen yet; until `creditCard`/`deposit` get one -- §13.4
/// checkpoint F/H -- this is what keeps it safe to reach in the
/// meantime rather than either crashing or offering a misleading
/// relabel). See [kEditableAccountTypeLabels]'s own doc for why
/// `creditCard`/`deposit` are excluded; every other subtype (including
/// both legacy-review subtypes, which keep exactly their pre-Checkpoint-G
/// behavior) remains freely relabelable, unchanged.
bool isAccountTypeEditable(FinancialAccountSubtype subtype) {
  switch (subtype) {
    case FinancialAccountSubtype.creditCard:
    case FinancialAccountSubtype.deposit:
      return false;
    case FinancialAccountSubtype.cash:
    case FinancialAccountSubtype.bank:
    case FinancialAccountSubtype.wallet:
    case FinancialAccountSubtype.legacyCardNeedsReview:
    case FinancialAccountSubtype.legacyUnknownNeedsReview:
      return true;
  }
}

/// Localized display label for a persisted account `type` value -- moved
/// from `accounts_screen.dart`'s private `_accountTypeLabel` (CP6.5)
/// unchanged, so both the Accounts list and the new Account Detail/Edit
/// screens render the exact same label for the exact same stored value.
/// `type` is one of [kAccountTypes] for a pre-Checkpoint-G account, or
/// one of the three `AccountCreationKind.legacyTypeLabel` values
/// (`'savings'`/`'deposit'`/`'creditCard'`) for one created since --
/// every case below is a real, reachable value. Falls back to the raw
/// string for any value outside both sets (defensive only -- not
/// reachable through the current Add/Edit Account forms).
String accountTypeDisplayLabel(AppLocalizations l10n, String type) {
  switch (type) {
    case 'cash':
      return l10n.accountTypeCash;
    case 'bank':
      return l10n.accountTypeBank;
    case 'card':
      return l10n.accountTypeCard;
    case 'wallet':
      return l10n.accountTypeWallet;
    // Checkpoint G (Add Account UX): the three new
    // `AccountCreationKind.legacyTypeLabel` values a real account can
    // now be created with -- 'savings' shares `bank`'s
    // `FinancialAccountSubtype` (docs/20 §13.5 open question 1, "bank
    // is not split") but keeps its own label/icon here purely for
    // presentation, exactly as `AccountCreationKind`'s own doc
    // describes. Added to this switch only -- NOT to [kAccountTypes]
    // above, which stays the closed legacy set `EditAccountScreen`'s
    // dropdown still uses unmodified.
    case 'savings':
      return l10n.addAccountTypeSavingsTitle;
    case 'deposit':
      return l10n.addAccountTypeDepositTitle;
    case 'creditCard':
      return l10n.addAccountTypeCreditCardTitle;
    default:
      return type;
  }
}

/// A recognizable identity icon for a persisted account `type` value --
/// V1 Account Detail/Edit Checkpoint, for `AccountDetailScreen`'s header
/// `AppIconTile`. Purely decorative/identity, never load-bearing: nothing
/// downstream reads this back out, unlike [accountTypeDisplayLabel]'s
/// text (which is also always present alongside it -- see §11 of the
/// financial-app-ui-ux-designer skill, "icons support text rather than
/// replace it"). Falls back to a generic wallet icon for any value
/// outside [kAccountTypes], matching [accountTypeDisplayLabel]'s own
/// defensive fallback.
IconData accountTypeIcon(String type) {
  switch (type) {
    case 'cash':
      return Icons.payments_outlined;
    case 'bank':
      return Icons.account_balance_outlined;
    case 'card':
      return Icons.credit_card_outlined;
    case 'wallet':
      return Icons.account_balance_wallet_outlined;
    // Checkpoint G (Add Account UX): matches
    // `account_creation_kind_presentation.dart`'s own icon choice for
    // each kind, so an account looks the same on the Accounts list/
    // detail screens as it did on the type chooser that created it.
    case 'savings':
      return Icons.savings_outlined;
    case 'deposit':
      return Icons.lock_clock_outlined;
    case 'creditCard':
      return Icons.credit_card_outlined;
    default:
      return Icons.account_balance_wallet_outlined;
  }
}
