import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import 'account_type_presentation.dart';

/// The name + type fields shared by the Add Account dialog
/// (`accounts_screen.dart`'s `_AddAccountDialog`) and `EditAccountScreen`
/// -- V1 Account Detail/Edit Checkpoint. Extracted so both forms
/// validate/render the account name and type in exactly the same way
/// rather than maintaining two copies of the same `TextFormField`
/// decoration/validator and `DropdownButtonFormField` items list (see
/// this checkpoint's "reuse the existing form, don't duplicate it"
/// requirement).
///
/// Deliberately does NOT include currency: account creation lets the
/// user choose it (a fresh account has no history to protect yet), but
/// `EditAccountScreen` never lets it change -- see
/// `AccountRepository.updateAccount`'s doc comment for why. Each caller
/// renders its own currency field (a picker for Add, a read-only display
/// for Edit) below this widget instead.
class AccountIdentityFormFields extends StatelessWidget {
  const AccountIdentityFormFields({
    required this.nameController,
    required this.type,
    required this.onTypeChanged,
    super.key,
  });

  final TextEditingController nameController;

  /// One of [kAccountTypes]. The caller owns this as its own piece of
  /// state (via [onTypeChanged]) -- this widget is stateless and never
  /// stores a selection of its own.
  final String type;
  final ValueChanged<String?> onTypeChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        TextFormField(
          controller: nameController,
          decoration: InputDecoration(labelText: l10n.accountNameLabel),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? l10n.enterAccountNameMessage : null,
        ),
        DropdownButtonFormField<String>(
          initialValue: type,
          decoration: InputDecoration(labelText: l10n.accountTypeLabel),
          items: <DropdownMenuItem<String>>[
            for (final String t in kAccountTypes)
              DropdownMenuItem<String>(value: t, child: Text(accountTypeDisplayLabel(l10n, t))),
          ],
          onChanged: onTypeChanged,
        ),
      ],
    );
  }
}
