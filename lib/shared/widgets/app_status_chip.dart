import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Visual System Convergence Checkpoint 7.1's shared small-status-label
/// primitive ("AppStatusChip"/"AppPill"): generalizes the identical
/// `Container(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
/// decoration: BoxDecoration(color: color.withValues(alpha: 0.14),
/// borderRadius: BorderRadius.circular(999)), child: Text(label, style:
/// labelSmall/w600/color)))` pattern `_ConfiguredBudget` (budget status:
/// on track / ahead of pace / over budget), `_PriorityGoalSummary` (goal
/// status: in progress / overdue), and `_RecurringItemSummary` (urgency:
/// overdue / due today / upcoming) on `home_screen.dart` each wrote
/// independently, with a different `color` chosen per call site from
/// `ColorScheme`/[AppSemanticColors] but the exact same container shape.
///
/// Carries no domain knowledge of its own -- every call site still picks
/// its own [label] (already localized ARB text) and [color] (still
/// exactly the same `ColorScheme.primary`/`tertiary`/`error`/
/// `onSurfaceVariant` mapping each existing status switch already
/// computed); this widget only owns the shared compact-pill presentation.
///
/// Localized-text safe: [label] always gets a one-line ellipsis rather
/// than wrapping the pill or overflowing, matching every existing status
/// chip on Home.
class AppStatusChip extends StatelessWidget {
  const AppStatusChip({required this.label, required this.color, super.key});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.appTokens;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.xs, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: tokens.radii.pillRadius),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
