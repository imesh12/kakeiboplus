import 'package:flutter/material.dart';

import '../../../core/finance/account_creation_kind.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Localized title/description/icon for each [AccountCreationKind] --
/// Checkpoint G. Shared by [AddAccountTypeScreen] (the type chooser,
/// where these are the row content) and [AddAccountFormScreen] (which
/// reuses [accountCreationKindTitle] as its own `AppBar` title, so the
/// user sees the exact same name for a kind on both screens) rather than
/// each screen keeping its own copy of this switch -- the same
/// "reuse before creation" discipline `account_type_presentation.dart`
/// already established for the legacy `Accounts.type` string.
///
/// Deliberately separate from `account_type_presentation.dart`:  that
/// file maps an already-PERSISTED `Accounts.type` string (rendered
/// after creation, on the Accounts list/detail screens, unmodified by
/// this checkpoint) to a label/icon; this file maps the pre-creation
/// [AccountCreationKind] choice itself (used only during the Add
/// Account flow). The two enums/vocabularies are related but distinct
/// (see [AccountCreationKind]'s own doc on why `savings` is a separate
/// choice here despite sharing a `FinancialAccountSubtype` with `bank`).
String accountCreationKindTitle(AppLocalizations l10n, AccountCreationKind kind) {
  switch (kind) {
    case AccountCreationKind.cash:
      return l10n.addAccountTypeCashTitle;
    case AccountCreationKind.bank:
      return l10n.addAccountTypeBankTitle;
    case AccountCreationKind.savings:
      return l10n.addAccountTypeSavingsTitle;
    case AccountCreationKind.wallet:
      return l10n.addAccountTypeWalletTitle;
    case AccountCreationKind.deposit:
      return l10n.addAccountTypeDepositTitle;
    case AccountCreationKind.creditCard:
      return l10n.addAccountTypeCreditCardTitle;
  }
}

/// See [accountCreationKindTitle]'s own doc -- the short explanatory
/// line shown under each type-chooser row (docs/20 §13.4's own "icon +
/// short localized title + short explanation" requirement). Never shown
/// on [AddAccountFormScreen] -- only the chooser needs the longer
/// explanatory text.
String accountCreationKindDescription(AppLocalizations l10n, AccountCreationKind kind) {
  switch (kind) {
    case AccountCreationKind.cash:
      return l10n.addAccountTypeCashDescription;
    case AccountCreationKind.bank:
      return l10n.addAccountTypeBankDescription;
    case AccountCreationKind.savings:
      return l10n.addAccountTypeSavingsDescription;
    case AccountCreationKind.wallet:
      return l10n.addAccountTypeWalletDescription;
    case AccountCreationKind.deposit:
      return l10n.addAccountTypeDepositDescription;
    case AccountCreationKind.creditCard:
      return l10n.addAccountTypeCreditCardDescription;
  }
}

/// See [accountCreationKindTitle]'s own doc -- purely decorative/identity
/// (per the financial-app-ui-ux-designer skill §11, "icons support text
/// rather than replace it"); always shown alongside [accountCreationKindTitle]'s
/// text, never alone.
IconData accountCreationKindIcon(AccountCreationKind kind) {
  switch (kind) {
    case AccountCreationKind.cash:
      return Icons.payments_outlined;
    case AccountCreationKind.bank:
      return Icons.account_balance_outlined;
    case AccountCreationKind.savings:
      return Icons.savings_outlined;
    case AccountCreationKind.wallet:
      return Icons.account_balance_wallet_outlined;
    case AccountCreationKind.deposit:
      return Icons.lock_clock_outlined;
    case AccountCreationKind.creditCard:
      return Icons.credit_card_outlined;
  }
}
