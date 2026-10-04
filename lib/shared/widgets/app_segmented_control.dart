import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// One option inside an [AppSegmentedControl].
@immutable
class AppSegmentedControlOption<T> {
  const AppSegmentedControlOption({required this.value, required this.label, this.semanticLabel});

  final T value;
  final String label;

  /// Overrides the segment's accessibility label; defaults to [label]
  /// itself when `null`.
  final String? semanticLabel;
}

/// Checkpoint 10 (Icon-Led UI Foundation)'s shared segmented-control
/// foundation: a single-select row of pill segments inside a soft tonal
/// track, with the selected segment drawn as a solid, fully-rounded
/// capsule that animates between positions -- the approved 8-screen
/// reference's "All / Cash / Bank / Cards / Assets" (Accounts), "All /
/// Active / Upcoming / Expired" (Subscriptions), and "Assets / Liabilities
/// / Net Worth" (Assets & Liabilities) treatment.
///
/// # Why this is new rather than an evolution of an existing widget
///
/// The CP10 audit found no existing segmented-control pattern anywhere in
/// the app to generalize from: `categories_screen.dart`'s Expense/Income
/// split uses Flutter's [TabBar]/[TabBarView]/[DefaultTabController] (a
/// stateful, swipe-gesture-connected widget whose controller/page-view
/// behavior this checkpoint must not disturb -- replacing it would be a
/// navigation/interaction change, not a visual reskin), and
/// `add_transaction_sheet.dart`'s Expense/Income/Transfer choice is a
/// modal menu of [ListTile]s, not an in-screen toggle. This widget is
/// therefore a genuinely new foundation primitive, built and tested in
/// isolation this checkpoint per the CP10 spec's own item 7 -- see the
/// final report's "Deferred visual work" for why it is not yet wired into
/// an existing screen (every current segmented-looking surface would
/// require a behavior change, not a pure visual swap, to adopt it).
///
/// # Selection model
///
/// Single-select only, matching every segmented control in the reference
/// (never a multi-select filter -- see [AppFilterChip]
/// (`app_filter_chip.dart`) for that shape instead). [selected] and
/// [onChanged] are both required and driven entirely by the caller --
/// this widget holds no state of its own, exactly like every other
/// primitive in `lib/shared/widgets/`.
///
/// # RTL / text-scale safety
///
/// Segments are laid out in a plain [Row] of [Expanded] children, which
/// [Directionality] mirrors automatically under RTL. Each label renders
/// on a single line with an ellipsis, so a longer translation shrinks
/// rather than overflowing or breaking the track's fixed pill shape.
class AppSegmentedControl<T> extends StatelessWidget {
  const AppSegmentedControl({
    required this.options,
    required this.selected,
    required this.onChanged,
    super.key,
    this.quietTrack = false,
    this.selectedGradient,
  });

  final List<AppSegmentedControlOption<T>> options;
  final T selected;
  final bool quietTrack;
  final ValueChanged<T> onChanged;

  /// Recurring UI Upgrade + History Views checkpoint: an optional
  /// gradient fill for the selected pill, replacing the flat
  /// [ColorScheme.primary] fill. `null` (the default) is
  /// pixel-identical to every other call site.
  final Gradient? selectedGradient;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.appTokens;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.all(tokens.spacing.xxs / 2),
      decoration: BoxDecoration(
        color: quietTrack ? Colors.transparent : tokens.colors.cardSurface,
        borderRadius: tokens.radii.pillRadius,
      ),
      child: Row(
        children: <Widget>[
          for (final AppSegmentedControlOption<T> option in options)
            Expanded(
              child: _Segment<T>(
                option: option,
                isSelected: option.value == selected,
                onChanged: onChanged,
                selectedColor: colors.primary,
                selectedGradient: selectedGradient,
                selectedTextColor: colors.onPrimary,
                unselectedTextColor: tokens.colors.secondaryText,
                pillRadius: tokens.radii.pillRadius,
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment<T> extends StatelessWidget {
  const _Segment({
    required this.option,
    required this.isSelected,
    required this.onChanged,
    required this.selectedColor,
    required this.selectedTextColor,
    required this.unselectedTextColor,
    required this.pillRadius,
    this.selectedGradient,
  });

  final AppSegmentedControlOption<T> option;
  final bool isSelected;
  final ValueChanged<T> onChanged;
  final Color selectedColor;
  final Gradient? selectedGradient;
  final Color selectedTextColor;
  final Color unselectedTextColor;
  final BorderRadius pillRadius;

  @override
  Widget build(BuildContext context) {
    final TextStyle? style = Theme.of(context).textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
      color: isSelected ? selectedTextColor : unselectedTextColor,
    );

    return Semantics(
      button: true,
      selected: isSelected,
      label: option.semanticLabel ?? option.label,
      child: GestureDetector(
        onTap: () => onChanged(option.value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            // A transparent paint color would also suppress the shader's alpha.
            color: isSelected
                ? (selectedGradient == null ? selectedColor : null)
                : Colors.transparent,
            gradient: isSelected ? selectedGradient : null,
            borderRadius: pillRadius,
          ),
          alignment: Alignment.center,
          child: Text(
            option.label,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
