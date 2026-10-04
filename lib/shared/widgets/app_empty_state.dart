import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';

/// Visual System Convergence Checkpoint 7.1's shared inline empty-state
/// primitive: generalizes the identical `Column([Text(message,
/// style: bodyMedium/onSurfaceVariant), SizedBox(height: 12),
/// OutlinedButton.icon(onPressed:, icon: Icon(Icons.add_rounded),
/// label: Text(actionLabel))])` pattern `_BudgetCard` ("no budget set"),
/// `_SavingsGoalsCard` ("no savings goal"), and `_UpcomingCommitmentsCard`
/// ("no recurring") each wrote independently on `home_screen.dart` --
/// three exact structural repeats, which is what justifies a shared
/// primitive here (per this checkpoint's "only create one if a repeated
/// pattern already exists enough to justify it" guidance) rather than the
/// more general "no matching/no items yet" empty states elsewhere in the
/// app, which are simple one-line messages with no repeated
/// call-to-action structure to generalize.
///
/// No financial/domain logic here -- [message] and [actionLabel] are
/// already-localized ARB text supplied by the caller, and [onAction] is
/// whatever the caller was already doing (e.g. `context.push(...)`).
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    required this.message,
    required this.actionLabel,
    required this.onAction,
    super.key,
    this.icon = Icons.add_rounded,
    this.actionKey,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final IconData icon;

  /// Forwarded to the action button so call sites can keep an existing
  /// stable `Key` (e.g. `setMonthlyBudgetButton`) that tests already rely
  /// on.
  final Key? actionKey;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.appTokens;
    final TextStyle? style = context.appTypography.secondaryBody;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(message, style: style),
        SizedBox(height: tokens.spacing.sm),
        // U3 narrow-screen investigation (docs/14): this was the SECOND,
        // still-unfixed occurrence of the same bug fixed on
        // `_UpcomingCommitmentsCard`'s warm empty state --
        // `OutlinedButton.icon(icon:, label:)` never wraps its label in
        // `Flexible`, so a long `actionLabel` (e.g. "Set a monthly
        // budget", longer than that other card's "Set up recurring")
        // can overflow at a high text-scale factor on a narrow screen
        // even with only this widget's single padding layer. Every test
        // that leaves the Budget or Savings Goals section unconfigured
        // hits this shared widget regardless of that test's own nominal
        // target, which is why the overflow kept appearing after the
        // other fix landed. Rebuilt by hand with the same `Flexible` +
        // ellipsis convention used everywhere else -- no visual change
        // except once space genuinely runs out.
        OutlinedButton(
          key: actionKey,
          onPressed: onAction,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 18),
              SizedBox(width: tokens.spacing.xs),
              Flexible(
                child: Text(
                  actionLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
