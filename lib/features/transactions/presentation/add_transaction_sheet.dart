import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/theme/app_tokens.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_icon_tile.dart';

/// The "+ Add" menu (Master Blueprint §38): a modal sheet, not a fifth
/// navigation-bar destination. Beta 0 only enables Expense / Income /
/// Transfer — Receipt and Goal Contribution are omitted entirely rather
/// than shown disabled, per Decision 12 ("should not pretend to work
/// before their stages").
///
/// # Activity Type Picker UI Polish checkpoint
///
/// Presentation-only redesign -- the three plain [ListTile] rows (a
/// generic Material glyph + default list-tile spacing) are now
/// [_AddTransactionOptionTile]s: the same shared [AppCard]/[AppIconTile]
/// primitives every other "premium" surface in this app already builds
/// on (see each widget's own doc comment), rendering the three approved
/// custom icons (`assets/icons/activity/*.png`) instead of generic
/// glyphs. Every behavior below is byte-for-byte unchanged from before
/// this checkpoint: same three options, same order, same
/// `l10n.transactionType*` labels, same pop-then-push navigation via the
/// ORIGINAL `context` (never `sheetContext`), same
/// `AppRoutes.addTransaction?type=...` destinations, same
/// `showDragHandle: true` (the modal's own rounded-top-corner shape
/// already comes from `AppTheme`'s app-wide `BottomSheetThemeData`, so
/// this file never needed its own `shape` override). Only the visual
/// chrome of each row changed.
Future<void> showAddTransactionSheet(BuildContext context) {
  // CP6.1 (Localization Phase 1): resolved once from the caller's own
  // context (already inside `MaterialApp.router`'s `Localizations`
  // subtree via `AppShell`) rather than re-resolving from `sheetContext`
  // per builder call -- there is only ever one build of this sheet's
  // content per invocation, so there is no benefit to re-reading it
  // from the modal's own (about-to-be-popped) context instead. `tokens`/
  // `colors` are resolved the same way, for the same reason.
  final AppLocalizations l10n = AppLocalizations.of(context);
  final AppTokens tokens = context.appTokens;
  final ColorScheme colors = Theme.of(context).colorScheme;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext sheetContext) {
      return SafeArea(
        // Validation Pass checkpoint -- REAL bug fix, not a test
        // workaround: `showModalBottomSheet` (without
        // `isScrollControlled`) gives its builder's content a bounded
        // (finite) max height, and this sheet's own premium row sizing
        // -- `AppIconTileSize.large`'s 48px icon slot, the generous
        // `AppCard` padding, bold `titleMedium` labels -- made the three
        // rows' combined natural height exceed that bound: 6.5px over on
        // a normal test surface, 94px over at 320px width + 2.0x text
        // scale (where each row's text line height alone roughly
        // doubles). The plain `Column` below has no way to shrink or
        // scroll, so it painted past its bounds -- a real RenderFlex
        // overflow, not a test-only artifact.
        //
        // `SingleChildScrollView` is the fix, not `Expanded` (there is
        // no flexible/bounded ancestor here for `Expanded` to flex
        // within -- this is a modal sheet, not a `Scaffold` body) and
        // not shrinking the icons/text (the approved artwork and type
        // size stay exactly as specified). Laid out with an unbounded
        // scroll-axis constraint, it reports its OWN size as
        // `min(child's natural height, the bound offered)`: on a normal
        // phone height the three rows already fit under the bound, so
        // this reports the exact same natural height as before and the
        // sheet looks pixel-identical to today; only when content
        // genuinely exceeds the bound (320px + 2.0x, Japanese + 2.0x)
        // does it fill the bound and scroll internally instead of
        // overflowing. Direction-agnostic -- RTL only mirrors the
        // horizontal axis, which this scroll view never touches.
        child: SingleChildScrollView(
          child: Padding(
            padding:
                EdgeInsets.fromLTRB(tokens.spacing.md, tokens.spacing.xs, tokens.spacing.md, tokens.spacing.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _AddTransactionOptionTile(
                  label: l10n.transactionTypeExpense,
                  assetPath: 'assets/icons/activity/expense.png',
                  // Never actually painted while the asset above resolves
                  // ([AppIconTile] only falls back to this glyph if
                  // `assetPath` itself is ever removed) -- kept as the
                  // same semantically-correct glyph this row always used,
                  // not a placeholder.
                  fallbackIcon: Icons.remove_circle_outline,
                  // Matches `activity_screen.dart`'s own
                  // expense/income/transfer -> color convention exactly
                  // (Checkpoint 8.2: income reads through
                  // `AppTokens.colors.positive`, not `colorScheme.primary`
                  // directly, for Forest-theme safety -- expense/transfer
                  // have no such override and read straight off
                  // `ColorScheme`).
                  color: colors.error,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    // Navigate via the ORIGINAL `context` (the screen
                    // behind the sheet), not `sheetContext` — the
                    // sheet's own context belongs to a route that is
                    // being popped, so routing through it is
                    // unnecessary risk for no benefit.
                    context.push('${AppRoutes.addTransaction}?type=expense');
                  },
                ),
                _AddTransactionOptionTile(
                  label: l10n.transactionTypeIncome,
                  assetPath: 'assets/icons/activity/income.png',
                  fallbackIcon: Icons.add_circle_outline,
                  color: tokens.colors.positive,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    context.push('${AppRoutes.addTransaction}?type=income');
                  },
                ),
                _AddTransactionOptionTile(
                  label: l10n.transactionTypeTransfer,
                  assetPath: 'assets/icons/activity/transfer.png',
                  fallbackIcon: Icons.swap_horiz,
                  color: colors.onSurfaceVariant,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    context.push('${AppRoutes.addTransaction}?type=transfer');
                  },
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Activity Type Picker UI Polish checkpoint: one premium, tappable
/// Expense/Income/Transfer row in [showAddTransactionSheet]'s modal --
/// custom icon on the left (via [AppIconTile]'s existing `assetPath`
/// support, exactly the same mechanism `CategoryIdentityIcon` already
/// uses for curated category artwork), the label vertically centered
/// next to it, and a trailing chevron affording "this opens something".
///
/// Built entirely from existing shared primitives -- [AppCard] (the
/// same "white, bordered, generously rounded" surface its own doc
/// comment describes as the approved reference's card treatment, here
/// with [AppCard.onTap] for a clipped, rounded-corner ink ripple) and
/// [AppIconTile] at [AppIconTileSize.large] for a comfortably-sized,
/// never-tiny icon slot -- so this row introduces no new visual
/// language, no hardcoded colors, and no new reusable widget beyond
/// this file's own private composition of the two.
class _AddTransactionOptionTile extends StatelessWidget {
  const _AddTransactionOptionTile({
    required this.label,
    required this.assetPath,
    required this.fallbackIcon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String assetPath;
  final IconData fallbackIcon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.appTokens;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return AppCard(
      bordered: true,
      margin: EdgeInsets.only(bottom: tokens.spacing.sm),
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.md, vertical: tokens.spacing.sm + 4),
      onTap: onTap,
      child: Row(
        children: <Widget>[
          AppIconTile(
            icon: fallbackIcon,
            assetPath: assetPath,
            color: color,
            size: AppIconTileSize.large,
          ),
          SizedBox(width: tokens.spacing.md),
          Expanded(
            child: Text(
              label,
              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
        ],
      ),
    );
  }
}
