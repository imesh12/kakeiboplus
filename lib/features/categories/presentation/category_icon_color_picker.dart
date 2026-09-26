import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/theme/app_tokens.dart';
import '../domain/category_color.dart';
import '../domain/category_icon.dart';
import '../domain/category_icon_catalog.dart';

/// Checkpoint U1 (Category, Service, Currency & Card Visual Identity
/// Foundation): the category icon picker used by the Add/Edit category
/// dialogs (`categories_screen.dart`).
///
/// "For V1, 'custom icon' means choosing from the curated app catalog" --
/// per the checkpoint brief, this is deliberately a fixed grid over
/// [categoryIconKeys], never an arbitrary uploaded image/SVG picker.
///
/// # Follows `_ThemeSwatchCard`'s established selectable-swatch pattern
/// EXACTLY -- this is a repair, not just a similar-looking pattern
///
/// U1's first cut of this widget used a `GridView.builder` (a second,
/// nested `Scrollable` inside the dialog's own `SingleChildScrollView`)
/// and wrapped each option in an explicit `Semantics` AROUND a `Tooltip`
/// AROUND an `InkWell` with no `ExcludeSemantics` anywhere -- so the
/// outer `Semantics` node and the `Tooltip`'s own implicit semantics
/// node and the `InkWell`/`GestureDetector`'s own implicit "button"
/// semantics node all needed to merge, and with all ~50 of these
/// conflicting-annotation nodes being built inside a dialog's opening
/// transition, that produced a real `!semantics.parentDataDirty`
/// framework assertion (Checkpoint U1 repair -- see
/// `docs/14_DECISION_LOG.md` ADR-044's repair note). `theme_customization
/// _screen.dart`'s pre-existing, already-proven `_ThemeSwatchCard` never
/// hits this: it uses a plain `Wrap` (no nested `Scrollable`), no
/// `Tooltip`, and -- the actual missing piece -- wraps its tappable
/// content in `ExcludeSemantics` so the descendant `InkWell`/`Material`
/// contribute NO semantics of their own; the outer `Semantics(button:,
/// selected:, label:)` is the ONLY node for that option. This picker (and
/// [CategoryColorPicker] below) now follow that exact structure --
/// `Semantics(...) > ExcludeSemantics(child: Material(...InkWell...))` --
/// rather than a similar-looking but subtly unsafe variant.
///
/// This is not a reduction in accessibility: the descendant semantics
/// [ExcludeSemantics] removes were genuinely redundant with (and, left
/// unmerged, in conflict with) the explicit label/selected/button
/// annotation already provided at the top -- a screen reader still
/// announces the exact same label and selected state as before, from
/// one authoritative node instead of several that had to be reconciled.
class CategoryIconPicker extends StatelessWidget {
  const CategoryIconPicker({required this.selectedIconKey, required this.onChanged, super.key});

  final String? selectedIconKey;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: <Widget>[
        for (final String iconKey in categoryIconKeys)
          _IconOption(
            iconKey: iconKey,
            label: categoryIconLabel(l10n, iconKey),
            selected: iconKey == selectedIconKey,
            selectedSemanticSuffix: l10n.themeSelectedSemanticLabel,
            onTap: () => onChanged(iconKey),
          ),
      ],
    );
  }
}

class _IconOption extends StatelessWidget {
  const _IconOption({
    required this.iconKey,
    required this.label,
    required this.selected,
    required this.selectedSemanticSuffix,
    required this.onTap,
  });

  final String iconKey;
  final String label;
  final bool selected;
  final String selectedSemanticSuffix;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.appTokens;
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: selected ? '$label, $selectedSemanticSuffix' : label,
      child: ExcludeSemantics(
        child: SizedBox(
          width: 44,
          height: 44,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: Key('categoryIconOption_$iconKey'),
              borderRadius: tokens.radii.mediumRadius,
              onTap: onTap,
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  borderRadius: tokens.radii.mediumRadius,
                  border: Border.all(
                    color: selected ? colors.primary : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    Icon(categoryIconFor(iconKey), color: colors.onSurfaceVariant),
                    if (selected)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Icon(Icons.check_circle, size: 14, color: colors.primary),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Checkpoint U1: the category color picker used by the Add/Edit
/// category dialogs -- see [CategoryIconPicker]'s own doc comment for
/// the shared `Semantics` + `ExcludeSemantics` convention both follow.
class CategoryColorPicker extends StatelessWidget {
  const CategoryColorPicker({required this.selectedColorKey, required this.onChanged, super.key});

  final CategoryColorKey? selectedColorKey;
  final ValueChanged<CategoryColorKey> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        for (final CategoryColorKey key in CategoryColorKey.values)
          _ColorOption(
            colorKey: key,
            label: _colorLabel(l10n, key),
            selected: key == selectedColorKey,
            selectedSemanticSuffix: l10n.themeSelectedSemanticLabel,
            swatchColor: categoryColorForKey(key, isDark: isDark),
            selectionRingColor: colors.onSurface,
            onTap: () => onChanged(key),
          ),
      ],
    );
  }

  static String _colorLabel(AppLocalizations l10n, CategoryColorKey key) {
    return switch (key) {
      CategoryColorKey.slate => l10n.categoryColorSlate,
      CategoryColorKey.red => l10n.categoryColorRed,
      CategoryColorKey.orange => l10n.categoryColorOrange,
      CategoryColorKey.amber => l10n.categoryColorAmber,
      CategoryColorKey.yellow => l10n.categoryColorYellow,
      CategoryColorKey.lime => l10n.categoryColorLime,
      CategoryColorKey.green => l10n.categoryColorGreen,
      CategoryColorKey.teal => l10n.categoryColorTeal,
      CategoryColorKey.cyan => l10n.categoryColorCyan,
      CategoryColorKey.blue => l10n.categoryColorBlue,
      CategoryColorKey.indigo => l10n.categoryColorIndigo,
      CategoryColorKey.purple => l10n.categoryColorPurple,
      CategoryColorKey.pink => l10n.categoryColorPink,
      CategoryColorKey.brown => l10n.categoryColorBrown,
    };
  }
}

class _ColorOption extends StatelessWidget {
  const _ColorOption({
    required this.colorKey,
    required this.label,
    required this.selected,
    required this.selectedSemanticSuffix,
    required this.swatchColor,
    required this.selectionRingColor,
    required this.onTap,
  });

  final CategoryColorKey colorKey;
  final String label;
  final bool selected;
  final String selectedSemanticSuffix;
  final Color swatchColor;
  final Color selectionRingColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color checkColor = ThemeData.estimateBrightnessForColor(swatchColor) == Brightness.dark
        ? Colors.white
        : Colors.black;
    return Semantics(
      button: true,
      selected: selected,
      label: selected ? '$label, $selectedSemanticSuffix' : label,
      child: ExcludeSemantics(
        child: SizedBox(
          width: 36,
          height: 36,
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              key: Key('categoryColorOption_${colorKey.storageValue}'),
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: swatchColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? selectionRingColor : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: selected ? Icon(Icons.check, size: 18, color: checkColor) : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
