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
    this.gradient,
    this.trackKey,
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

  /// Dashboard progress-bar gradient refinement: an optional premium
  /// fill gradient (e.g. [AppSemanticColors.positiveGradient]/
  /// [AppSemanticColors.negativeGradient]), painted over the fill
  /// instead of flat [color] when supplied. `null` (the default)
  /// preserves every pre-existing call site's exact current appearance
  /// -- unchanged, since this field simply doesn't exist for them. Not
  /// a replacement for [color]: [color] still backs the underlying
  /// [LinearProgressIndicator] this widget renders either way, so a
  /// theme with no matching gradient token (Pink/Ocean/Forest -- see
  /// `app_theme.dart`) falls back to the exact same flat-color bar a
  /// caller already gets today, just by passing `null` here.
  final Gradient? gradient;

  /// Final card-dimension pass: an optional [Key] applied to the
  /// OUTER, full-width track container (the [ClipRRect] this widget
  /// always returns, in both the flat-[color] and [gradient]
  /// branches) -- added specifically so a regression test can measure
  /// the real track/container unambiguously by key, instead of by
  /// widget type or tree shape, which repeatedly proved unreliable for
  /// telling the full-width track apart from the [gradient] branch's
  /// own value-scaled fill. `null` (the default) preserves every
  /// pre-existing call site's behavior exactly -- no key is ever
  /// attached unless a caller opts in.
  ///
  /// There is deliberately no matching `fillKey`: the fractional-fill
  /// fraction is this widget's own internal implementation detail,
  /// covered by `app_progress_bar_test.dart`'s own focused component
  /// test, not something a caller (Home included) needs to reach into
  /// from the outside.
  final Key? trackKey;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.appTokens;
    final Gradient? fillGradient = gradient;
    if (fillGradient == null) {
      return ClipRRect(
        key: trackKey,
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
    // Gradient path: `LinearProgressIndicator.color` can only ever paint
    // a flat color, never a `Gradient` -- so the indicator itself stays
    // mounted with `color: Colors.transparent` purely to keep its exact
    // existing `Semantics`/`value` contract (screen readers announce the
    // same percentage either way), while a `FractionallySizedBox`
    // painted on top supplies the actual gradient-filled visual, sized
    // to the SAME [value] fraction. The neutral track is unchanged --
    // still `tokens.colors.elevatedSurface`, painted by the (still very
    // much real, just invisibly-filled) `LinearProgressIndicator` below.
    return ClipRRect(
      key: trackKey,
      borderRadius: BorderRadius.circular(minHeight),
      child: SizedBox(
        height: minHeight,
        child: Stack(
          children: <Widget>[
            LinearProgressIndicator(
              value: value,
              minHeight: minHeight,
              backgroundColor: tokens.colors.elevatedSurface,
              color: Colors.transparent,
              semanticsLabel: semanticLabel,
            ),
            Positioned.fill(
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: value,
                child: DecoratedBox(decoration: BoxDecoration(gradient: fillGradient)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
