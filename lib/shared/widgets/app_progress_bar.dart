import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Checkpoint 10 (Icon-Led UI Foundation)'s shared thin semantic progress
/// bar -- generalizing the exact pattern `goal_detail_screen.dart`'s
/// savings-goal hero already hand-rolled: `ClipRRect(borderRadius:
/// circular(8), child: LinearProgressIndicator(value:, minHeight: 8,
/// backgroundColor: surfaceContainerHighest, color: statusColor))`. This
/// widget is that exact shape with a name -- moving an existing call site
/// onto it is a pure rename, not a visual change (see
/// `goal_detail_screen.dart`'s own updated call site and
/// `app_progress_bar_test.dart`).
///
/// # What this deliberately does NOT do
///
/// This widget never computes a ratio, a status, or a color of its own --
/// [value] (already clamped to `[0.0, 1.0]` by the caller, exactly as
/// `goal_detail_screen.dart` already does via `ratio.clamp(0.0, 1.0)`) and
/// [color] (an already-resolved semantic color -- `AppTokens.colors.positive`/
/// `.warning`/`.negative`/`.info`, or any other `ColorScheme` role the
/// caller chooses) are both supplied by the caller. No financial/domain
/// logic lives here, exactly like every other primitive in
/// `lib/shared/widgets/`.
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    required this.value,
    required this.color,
    super.key,
    this.minHeight = 8,
    this.semanticLabel,
  });

  /// Already clamped to `[0.0, 1.0]` by the caller -- this widget performs
  /// no clamping of its own, matching `LinearProgressIndicator`'s own
  /// contract (an out-of-range value is the caller's bug, not something
  /// silently corrected here).
  final double value;

  final Color color;

  /// Matches `goal_detail_screen.dart`'s pre-existing bar thickness (8) as
  /// the default -- a caller may pass a different thickness for a denser
  /// context (e.g. a compact list row) without this widget changing its
  /// corner radius independently, since the radius is always `minHeight`
  /// (a fully rounded thin bar, matching the reference's pill-ended
  /// progress bars regardless of thickness).
  final double minHeight;

  /// Optional accessibility label read alongside the percentage --
  /// `LinearProgressIndicator` already announces the numeric value itself
  /// via its own semantics; this only adds context (e.g. "Food & Dining
  /// budget") when the surrounding UI doesn't already provide it via
  /// adjacent text.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.appTokens;
    return ClipRRect(
      borderRadius: BorderRadius.circular(minHeight),
      child: LinearProgressIndicator(
        value: value,
        minHeight: minHeight,
        backgroundColor: tokens.colors.elevatedSurface,
        color: color,
        semanticsLabel: semanticLabel,
      ),
    );
  }
}
