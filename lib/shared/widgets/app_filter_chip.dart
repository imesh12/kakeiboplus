import 'package:flutter/material.dart';

/// Checkpoint 10 (Icon-Led UI Foundation)'s lightweight reusable
/// multi-select pill-filter wrapper around Flutter's built-in
/// [FilterChip].
///
/// # Why a thin wrapper, not a new widget from scratch
///
/// The CP10 audit found this shape already effectively solved:
/// `activity_screen.dart`'s pre-existing `_TypeFilterChip` already wraps
/// [FilterChip] directly, which already renders a checkmark on its
/// selected state (a non-color signal) and already exposes
/// `Semantics(selected: ...)` for free -- and [FilterChip]'s pill shape
/// already comes from `AppTheme`'s own `ChipThemeData` (`shape:
/// RoundedRectangleBorder(borderRadius: pillRadius)`, set since CP7.1).
/// There was nothing broken to fix, only duplication to remove: this
/// checkpoint moves that exact call site onto this one shared,
/// independently-tested wrapper instead of a private per-screen class, so
/// a second multi-select filter elsewhere in the app doesn't have to
/// re-write the same three-line [FilterChip] wrapper a third time.
///
/// This widget adds no new visual treatment of its own beyond what
/// [FilterChip] + [AppTheme]'s theme already produce -- moving
/// `activity_screen.dart`'s type filter onto it is a pure rename, not a
/// visual change.
class AppFilterChip extends StatelessWidget {
  const AppFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(label: Text(label), selected: selected, onSelected: onSelected);
  }
}
