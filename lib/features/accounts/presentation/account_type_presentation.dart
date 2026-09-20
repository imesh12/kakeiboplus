import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';

/// The closed set of account `type` values the Add/Edit Account forms
/// let a user choose from -- V1 Account Detail/Edit Checkpoint moves
/// this out of `accounts_screen.dart`'s private `_AddAccountDialogState`
/// (unchanged in content) so `EditAccountScreen`'s form can reuse the
/// exact same list rather than duplicating it.
const List<String> kAccountTypes = <String>['cash', 'bank', 'card', 'wallet'];

/// Localized display label for a persisted account `type` value -- moved
/// from `accounts_screen.dart`'s private `_accountTypeLabel` (CP6.5)
/// unchanged, so both the Accounts list and the new Account Detail/Edit
/// screens render the exact same label for the exact same stored value.
/// `type` is always one of [kAccountTypes] today (a closed,
/// dialog/form-created set), so mapping it to a translated label is safe
/// and does not touch the stored value. Falls back to the raw string for
/// any value outside that set (defensive only; not reachable through the
/// current Add/Edit Account forms).
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
    default:
      return Icons.account_balance_wallet_outlined;
  }
}
