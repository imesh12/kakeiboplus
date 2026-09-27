import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_icon_tile.dart';
import '../domain/service_identity_catalog.dart';
import 'service_identity_icon.dart';

/// Checkpoint U2: the ONE shared service-identity selector, used by
/// both the Add/Edit Transaction screen and the recurring rule dialog
/// (Phase 5 of this checkpoint's brief) -- unlike `_CategoryDropdown`,
/// which is deliberately duplicated per screen because each copy watches
/// a different Riverpod family parameter, [serviceIdentityCatalog] is a
/// plain constant list with nothing to watch, so one shared, stateless
/// widget is strictly simpler than screen-local duplicates and is
/// preferred here (see this checkpoint's own "prefer existing patterns,
/// evolve don't duplicate" working-style instruction).
///
/// Always offers "None" (this field is optional everywhere it appears --
/// Phase 5's explicit requirement) plus every catalog entry, grouped by
/// family in [serviceIdentityCatalog]'s own declared order. An
/// unrecognized/legacy [value] (removed from a future catalog revision)
/// is preserved rather than silently discarded, via the exact
/// `_itemsPreservingCurrentValue` technique
/// `international_preferences_screen.dart` already established for this
/// same "`DropdownButtonFormField` requires exactly one matching item"
/// constraint.
///
/// Accessibility: this is a standard `DropdownButtonFormField` -- the
/// same mechanism `_CategoryDropdown`'s already-proven category picker
/// uses -- not the custom selectable-`Semantics`-grid pattern the U1
/// category icon/color picker regressed on. That pattern (nested
/// `Semantics` + `Tooltip` + `GridView` without `ExcludeSemantics`) is
/// NOT reintroduced here; each item's own icon+text is enough for
/// Flutter's built-in dropdown-item semantics, exactly as the pre-existing
/// category dropdown already demonstrates safely.
class ServiceIdentityDropdown extends StatelessWidget {
  const ServiceIdentityDropdown({required this.value, required this.onChanged, super.key});

  /// A `ServiceIdentityDefinition.id`, or `null` for "no service".
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool valueIsKnown = value == null || serviceIdentityCatalog.any((d) => d.id == value);

    return DropdownButtonFormField<String?>(
      key: const Key('serviceIdentityDropdown'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: l10n.serviceOptionalLabel),
      items: <DropdownMenuItem<String?>>[
        DropdownMenuItem<String?>(value: null, child: Text(l10n.noneOptionLabel)),
        // An unrecognized persisted value gets one synthetic extra item
        // (its own id, generically iconed/labeled) so opening this
        // dropdown never throws `DropdownButtonFormField`'s "there
        // should be exactly one item with the button's value" assertion
        // and never silently swaps the stored value out from under the
        // user just by opening the form -- same reasoning
        // `_itemsPreservingCurrentValue` documents.
        if (!valueIsKnown)
          DropdownMenuItem<String?>(
            value: value,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ServiceIdentityIcon(serviceIdentityKey: value, size: AppIconTileSize.small),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(l10n.serviceFamilyOtherGenericLabel, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        for (final def in serviceIdentityCatalog)
          DropdownMenuItem<String?>(
            value: def.id,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ServiceIdentityIcon(serviceIdentityKey: def.id, size: AppIconTileSize.small),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    serviceIdentityDisplayName(l10n, def),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }
}
