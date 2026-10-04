import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import 'app_icon_tile.dart';

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
/// always wrapped so a longer translation shrinks gracefully instead of
/// overflowing, and -- see the U3 narrow-screen investigation
/// (docs/14_DECISION_LOG.md) -- [trailing] is no longer placed bare at
/// the row's end. The previous version's claim that a longer
/// translation could never "push [trailing] off the row or overflow"
/// was wrong for [trailing] itself: only [title] had any width
/// protection, so once [title] shrank to zero, [icon] + [trailing]'s
/// own unguarded natural width could still exceed the row and throw a
/// real `RenderFlex` overflow -- confirmed directly via Flutter's own
/// "The relevant error-causing widget was: Row" diagnostic pointing at
/// this file when [SpendingByCategorySection]'s "Spending this month" /
/// "View details" header rendered at 320px + 1.6x/2.0x text scale. That
/// header renders unconditionally on every Home load (unlike the
/// Budget/Goals/Recurring cards' own buttons, which only render in
/// specific empty states), which is why every one of those failures
/// showed the identical overflow amount regardless of currency or which
/// card a given test actually targeted.
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    required this.title,
    super.key,
    this.icon,
    this.assetPath,
    this.assetSize = 24,
    this.titleStyle,
    this.trailing,
    this.eyebrow = false,
  });

  final String title;

  /// Omit for a bare title + optional trailing action (e.g. a top-level
  /// screen section like Home's "Accounts" row); pass one to reproduce a
  /// card-header row like `_BudgetCard`'s.
  final IconData? icon;

  /// Decorative artwork used in place of the optional glyph.
  final String? assetPath;
  final double assetSize;
  final TextStyle? titleStyle;

  /// Typically a `TextButton` ("Manage"/"View all"/"View details") --
  /// never resized (this widget never shrinks its own font/scale), but
  /// CAN be reflowed onto its own line below [title] when the two don't
  /// fit side by side -- see the responsive `Wrap` in `build()`.
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
        titleStyle ?? (eyebrow ? context.appTypography.eyebrow : context.appTypography.sectionTitle);

    final Widget titleText = Text(
      title,
      style: style,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    // Final U3 Visual Polish Pass: a compact `AppIconTile` (already
    // this app's shared tinted-icon idiom -- see that widget's own
    // doc comment) replaces the previous bare `Icon`, so every card
    // built on this header (`_BudgetCard`, `_SavingsGoalsCard`,
    // `_UpcomingCommitmentsCard`) picks up the same "compact icon
    // tile" treatment `_MetricTile`/`_StatusMetricTile` already use,
    // with zero call-site changes.
    final List<Widget> leading = <Widget>[
      if (assetPath != null) ...<Widget>[
        Image.asset(assetPath!, width: assetSize, height: assetSize, fit: BoxFit.contain,
          filterQuality: FilterQuality.high, excludeFromSemantics: true),
        SizedBox(width: tokens.spacing.xs),
      ] else if (icon != null) ...<Widget>[
        AppIconTile(icon: icon!, color: colors.primary, size: AppIconTileSize.small),
        SizedBox(width: tokens.spacing.xs),
      ],
    ];

    if (trailing == null) {
      // No trailing action to make room for -- `Expanded(title)` alone
      // can never overflow a Row (it always shrinks to whatever space
      // remains, down to zero), so this keeps the original, already-safe
      // structure unchanged.
      return Row(children: <Widget>[...leading, Expanded(child: titleText)]);
    }

    // U3 narrow-screen investigation (docs/14): `trailing` is an
    // arbitrary caller-supplied widget (typically a `TextButton`), not a
    // string, so it can't be measured with a `TextPainter` the way
    // `_AdaptiveAmountLine`/`_AdaptiveAccountRow` (home_screen.dart)
    // measure their own plain-string content ahead of laying out. `Wrap`
    // solves this without needing to know `trailing`'s width in advance:
    // both `titleText` and `trailing` are laid out at their own natural
    // sizes (each individually bounded by the space left after [icon],
    // via the `Expanded` below), packed onto one line with
    // `WrapAlignment.spaceBetween` -- title flush left, trailing flush
    // right, reproducing the exact previous visual whenever they fit --
    // and `trailing` is only pushed onto its own line, indented to
    // start where `titleText` does, once the two together don't fit.
    // `titleText` never loses space just because `trailing` is present;
    // its own `maxLines: 1, overflow: ellipsis` (unchanged from before)
    // is what still shrinks IT when its own text alone is too long for
    // the full available width -- Wrap doesn't bound an individual
    // too-wide child on its own (see `_AdaptiveAmountLine`'s own doc
    // comment on that exact limitation), but `titleText` already
    // handled that case correctly in isolation, so nothing new is needed
    // for it here.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        ...leading,
        Expanded(
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: tokens.spacing.sm,
            runSpacing: 2,
            children: <Widget>[titleText, trailing!],
          ),
        ),
      ],
    );
  }
}
