import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import 'account_type_presentation.dart';

/// The name + type fields originally shared by the V1 Account
/// Detail/Edit Checkpoint's Add Account dialog and `EditAccountScreen`.
/// Checkpoint G (Add Account UX) removed that dialog entirely (its own
/// adaptive per-kind form replaced it -- see `add_account_form_screen.dart`),
/// so `EditAccountScreen` is this widget's only caller today; kept as
/// its own widget regardless, so Edit's name/type validation/rendering
/// stays in one place rather than inlined into that screen.
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
    this.typeOptions = kAccountTypes,
    this.typeEditable = true,
    super.key,
  });

  final TextEditingController nameController;

  /// The currently-selected/persisted `type` value. The caller owns this
  /// as its own piece of state (via [onTypeChanged]) -- this widget is
  /// stateless and never stores a selection of its own. Not required to
  /// already be one of [typeOptions] -- see [typeOptions]'s own doc.
  final String type;
  final ValueChanged<String?> onTypeChanged;

  /// The values offered when [typeEditable] is true. Defaults to
  /// [kAccountTypes] (this widget's original, pre-Checkpoint-G behavior,
  /// unaffected for any caller that doesn't pass this). [type] itself is
  /// always included even if missing from this list -- a
  /// `DropdownButtonFormField` requires its `value` to match exactly one
  /// `DropdownMenuItem`, so this guarantees that invariant holds no
  /// matter what [type] contains, rather than relying on every caller to
  /// keep this list in sync with every value that can ever reach it (the
  /// Checkpoint G Android regression this repair fixes: `type: 'creditCard'`
  /// against the old, unconditional `kAccountTypes`-only item list).
  final List<String> typeOptions;

  /// When false, renders [type] as a read-only display (mirroring the
  /// currency field's own disabled-`TextFormField` treatment) instead of
  /// an editable dropdown. See `isAccountTypeEditable`'s own doc for why
  /// `EditAccountScreen` passes false for `creditCard`/`deposit`
  /// accounts specifically. Defaults to true -- unaffected for any
  /// caller that doesn't pass this.
  final bool typeEditable;

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
        if (typeEditable)
          DropdownButtonFormField<String>(
            initialValue: type,
            decoration: InputDecoration(labelText: l10n.accountTypeLabel),
            items: <DropdownMenuItem<String>>[
              // `{...typeOptions, type}`: see [typeOptions]'s own doc --
              // this is what guarantees `type` always has exactly one
              // matching item.
              for (final String t in <String>{...typeOptions, type})
                DropdownMenuItem<String>(value: t, child: Text(accountTypeDisplayLabel(l10n, t))),
            ],
            onChanged: onTypeChanged,
          )
        else
          TextFormField(
            initialValue: accountTypeDisplayLabel(l10n, type),
            enabled: false,
            decoration: InputDecoration(labelText: l10n.accountTypeLabel),
          ),
      ],
    );
  }
}
