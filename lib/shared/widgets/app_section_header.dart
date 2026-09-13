import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';

/// Visual System Convergence Checkpoint 7.1's shared section-header
/// primitive: an optional leading icon, a title that always yields (one
/// line, ellipsis) before an optional trailing action, generalizing the
/// identical `Row(children: [Icon(...), SizedBox(width: 8),
/// Expanded(Text(..., style: titleMedium/w600, overflow: ellipsis)),
/// if (...) TextButton(...)])` pattern `_BudgetCard`, `_SavingsGoalsCard`,
/// and `_UpcomingCommitmentsCard` each wrote independently on
/// `home_screen.dart`, and the icon-less variant `HomeScreen`'s own
/// "Accounts" row used.
///
/// Localization-safe and narrow-width safe by construction: [title] is
/// always wrapped in `Expanded` with a one-line ellipsis, so a longer
/// translation shrinks gracefully instead of pushing [trailing] off the
/// row or overflowing.
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    required this.title,
    super.key,
    this.icon,
    this.trailing,
    this.eyebrow = false,
  });

  final String title;

  /// Omit for a bare title + optional trailing action (e.g. a top-level
  /// screen section like Home's "Accounts" row); pass one to reproduce a
  /// card-header row like `_BudgetCard`'s.
  final IconData? icon;

  /// Typically a `TextButton` ("Manage"/"View all") -- never resized or
  /// reflowed by this widget beyond sitting at the row's end.
  final Widget? trailing;

  /// Visual System Convergence Checkpoint 7.2: when true, styles [title]
  /// with [AppTypography.eyebrow] (small, muted, letter-spaced, semibold)
  /// instead of [AppTypography.sectionTitle] -- matching the approved
  /// Claude Design reference's section-header treatment. Deliberately
  /// does NOT change [title]'s casing: the string rendered is always
  /// exactly [title], unchanged, so every existing `find.text(title)`
  /// assertion across the app keeps matching regardless of which value
  /// this flag is given. Purely a visual-hierarchy choice, like
  /// `AppMoneyEmphasis` on `AppMoneyText`.
  final bool eyebrow;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final AppTokens tokens = context.appTokens;
    final TextStyle? style =
        eyebrow ? context.appTypography.eyebrow : context.appTypography.sectionTitle;

    return Row(
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Icon(icon, color: colors.primary),
          SizedBox(width: tokens.spacing.xs),
        ],
        Expanded(
          child: Text(title, style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
