import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_icon_tile.dart';
import '../domain/service_identity_catalog.dart';
import 'service_identity_icon.dart';

/// Checkpoint U2, evolved by the Premium Create/Edit Rule checkpoint:
/// the ONE shared service-identity selector, used by both the Add/Edit
/// Transaction screen and the recurring rule dialog -- unlike
/// `_CategoryDropdown`, which is deliberately duplicated per screen
/// because each copy watches a different Riverpod family parameter,
/// [serviceIdentityCatalog] is a plain constant list with nothing to
/// watch, so one shared, stateless widget is strictly simpler than
/// screen-local duplicates and is preferred here (see this checkpoint's
/// own "prefer existing patterns, evolve don't duplicate" working-style
/// instruction).
///
/// # Premium picker, same public contract
///
/// The field itself still renders `[icon] Selected name` collapsed
/// (exactly what a `DropdownButtonFormField` showed before this
/// checkpoint, so every existing caller/test that only reads the
/// collapsed field is unaffected). Tapping it no longer opens a native
/// dropdown menu -- it opens a full-height, scrollable bottom sheet
/// with a header, a client-side search field, and one row per catalog
/// entry (plus "None"), each with a 44px icon slot, the display name,
/// a selected-state check mark, and a divider between rows -- the
/// "premium service selector" this checkpoint's brief asked for,
/// in place of "a plain old dropdown with legacy icons".
///
/// Always offers "None" (this field is optional everywhere it appears)
/// plus every catalog entry not filtered out by the search field,
/// grouped by family in [serviceIdentityCatalog]'s own declared order.
/// "None" renders a neutral, generic "not selected" icon -- never a
/// fake service logo (this checkpoint's explicit requirement).
///
/// An unrecognized/legacy [value] (removed from a future catalog
/// revision) is preserved rather than silently discarded: the
/// collapsed field still labels it via [serviceFamilyOtherGenericLabel],
/// and simply dismissing the sheet without tapping a row never calls
/// [onChanged] at all, so opening this picker can never silently swap
/// the stored value out from under the user.
///
/// No title/name heuristics live here or anywhere this widget calls
/// into: the only input is the already-persisted [value] (a
/// `ServiceIdentityDefinition.id`), resolved through
/// [serviceIdentityDefinitionFor]/[serviceIdentityDisplayName] and (for
/// real branded artwork) [ServiceIdentityIcon]'s own single resolver --
/// never a rule/transaction name string.
class ServiceIdentityDropdown extends StatelessWidget {
  const ServiceIdentityDropdown({required this.value, required this.onChanged, super.key});

  /// A `ServiceIdentityDefinition.id`, or `null` for "no service".
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    // `serviceIdentityDefinitionFor` degrades a non-null, unrecognized
    // key to the catalog's own generic 'other' entry rather than
    // returning null (see its doc comment) -- so this never needs a
    // separate "unknown value" branch; an unrecognized legacy id simply
    // displays as "Other service" automatically, through the exact
    // same resolver every other row uses.
    final String label = value == null
        ? l10n.noneOptionLabel
        : serviceIdentityDisplayName(l10n, serviceIdentityDefinitionFor(value)!);

    return InkWell(
      key: const Key('serviceIdentityDropdown'),
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final _ServiceSelection? selection = await showModalBottomSheet<_ServiceSelection>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => _ServiceIdentityPickerSheet(currentValue: value),
        );
        if (selection != null) onChanged(selection.value);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: l10n.serviceOptionalLabel),
        isEmpty: false,
        child: Row(
          children: <Widget>[
            if (value != null)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: ServiceIdentityIcon(
                  serviceIdentityKey: value,
                  size: AppIconTileSize.small,
                  containerSize: 28,
                ),
              ),
            Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
            const Icon(Icons.expand_more_rounded),
          ],
        ),
      ),
    );
  }
}

/// Internal result of the premium picker sheet -- distinguishes "user
/// explicitly chose None" (`value: null`, but a real selection) from
/// "sheet was dismissed without choosing anything" (the whole object is
/// `null`), so a swipe-to-dismiss can never be mistaken for clearing
/// the field.
class _ServiceSelection {
  const _ServiceSelection(this.value);
  final String? value;
}

class _ServiceIdentityPickerSheet extends StatefulWidget {
  const _ServiceIdentityPickerSheet({required this.currentValue});

  final String? currentValue;

  @override
  State<_ServiceIdentityPickerSheet> createState() => _ServiceIdentityPickerSheetState();
}

class _ServiceIdentityPickerSheetState extends State<_ServiceIdentityPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme colors = Theme.of(context).colorScheme;
    final String normalizedQuery = _query.trim().toLowerCase();

    final List<ServiceIdentityDefinition> filtered = normalizedQuery.isEmpty
        ? serviceIdentityCatalog
        : serviceIdentityCatalog
            .where((ServiceIdentityDefinition d) =>
                serviceIdentityDisplayName(l10n, d).toLowerCase().contains(normalizedQuery))
            .toList();
    final bool showNoneRow =
        normalizedQuery.isEmpty || l10n.noneOptionLabel.toLowerCase().contains(normalizedQuery);
    final int itemCount = (showNoneRow ? 1 : 0) + filtered.length;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Text(
                  l10n.serviceOptionalLabel,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  key: const Key('serviceIdentitySearchField'),
                  controller: _searchController,
                  onChanged: (String v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded),
                    hintText: l10n.searchTooltip,
                    isDense: true,
                    filled: true,
                    fillColor: colors.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Flexible(
                child: itemCount == 0
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                        child: Text(
                          l10n.serviceFamilyOtherGenericLabel,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      )
                    : ListView.separated(
                        key: const Key('serviceIdentityPickerList'),
                        shrinkWrap: true,
                        padding: const EdgeInsets.only(bottom: 12, top: 4),
                        itemCount: itemCount,
                        separatorBuilder: (BuildContext _, int __) =>
                            Divider(height: 1, color: colors.outlineVariant),
                        itemBuilder: (BuildContext context, int index) {
                          if (showNoneRow && index == 0) {
                            return _ServiceRow(
                              label: l10n.noneOptionLabel,
                              serviceIdentityKey: null,
                              selected: widget.currentValue == null,
                              onTap: () =>
                                  Navigator.of(context).pop(const _ServiceSelection(null)),
                            );
                          }
                          final ServiceIdentityDefinition def =
                              filtered[index - (showNoneRow ? 1 : 0)];
                          return _ServiceRow(
                            label: serviceIdentityDisplayName(l10n, def),
                            serviceIdentityKey: def.id,
                            selected: widget.currentValue == def.id,
                            onTap: () =>
                                Navigator.of(context).pop(_ServiceSelection(def.id)),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One row in the premium service picker sheet: a 44px icon slot
/// (real branded artwork at 32px when approved artwork exists, a
/// neutral "no service" glyph for the None row, or the generic
/// family icon/color otherwise -- all through [ServiceIdentityIcon]'s
/// one resolver), the display name, and a trailing check mark when
/// this row is the currently-selected value.
class _ServiceRow extends StatelessWidget {
  const _ServiceRow({
    required this.label,
    required this.serviceIdentityKey,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String? serviceIdentityKey;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: serviceIdentityKey == null
                      ? Icon(
                          Icons.not_interested_rounded,
                          size: 22,
                          color: colors.onSurfaceVariant,
                        )
                      : ServiceIdentityIcon(
                          serviceIdentityKey: serviceIdentityKey,
                          size: AppIconTileSize.medium,
                          containerSize: 44,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, size: 22, color: colors.primary),
            ],
          ),
        ),
      ),
    );
  }
}
