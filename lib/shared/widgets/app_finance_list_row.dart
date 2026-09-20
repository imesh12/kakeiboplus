import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import 'app_icon_tile.dart';

/// Checkpoint 10 (Icon-Led UI Foundation)'s shared compact list-row
/// primitive: leading [AppIconTile], a title/subtitle text column, and a
/// trailing slot -- generalizing the "icon tile + title/metadata +
/// amount" row shape the approved 8-screen reference uses for every list
/// (Home's Upcoming items, Accounts' account rows, Subscriptions' rows,
/// Family Wallet's Recent Activity).
///
/// # What this deliberately does NOT do
///
/// This widget never formats money, never computes a status/urgency
/// color, and never fetches data -- exactly like [AppCard]/`AppMoneyText`,
/// it is a pure presentation primitive. The caller supplies an
/// already-resolved [leadingIcon]/[leadingColor], already-localized
/// [title]/[subtitle] strings, and an already-built [trailing] widget
/// (typically an `AppMoneyText`, optionally stacked with an
/// [AppStatusChip]) -- this row only arranges them.
///
/// # RTL / text-scale / localization safety
///
/// [title] always renders on a single line with an ellipsis inside an
/// [Expanded] column, exactly like [AppSectionHeader]'s own title --  a
/// longer translation shrinks gracefully rather than pushing [trailing]
/// off the row. The leading icon tile and trailing slot sit at the row's
/// natural start/end edges via a plain [Row], which [Directionality]
/// mirrors automatically under RTL with no manual `EdgeInsets`/alignment
/// flip required.
///
/// [trailing] renders at its own natural size at every width this row is
/// realistically used at -- a [LayoutBuilder] only caps its maximum width
/// to whatever [title]'s `Expanded` column would otherwise be entitled to
/// (the row's width minus the icon tile and both spacers), and that cap
/// sits above [trailing]'s natural size except in a genuinely too-narrow
/// layout. In that emergency case the cap engages instead of letting the
/// `Row` overflow: [trailing] soft-wraps onto a second line rather than
/// being clipped, so a caller's already text-scale-safe, never-clipping
/// widget (e.g. `AppMoneyText`) still never has a single digit truncated
/// -- it just, in that one narrow case, is no longer guaranteed to stay
/// on one line.
///
/// No existing screen is required to adopt this row this checkpoint --
/// every current list (Home's Upcoming/Accounts, Activity's transaction
/// list) already has its own bespoke width-adaptive layout
/// (`_AdaptiveAmountLine`/`_AdaptiveAccountRow` on `home_screen.dart`)
/// that guarantees a large balance is never silently clipped by measuring
/// available width -- swapping either onto this simpler fixed-layout row
/// would regress that guarantee, so it is left for a future checkpoint
/// that can budget for reworking those call sites' adaptive logic into a
/// shared primitive without behavior loss (see the CP10 final report's
/// "Deferred visual work").
class AppFinanceListRow extends StatelessWidget {
  const AppFinanceListRow({
    required this.leadingIcon,
    required this.leadingColor,
    required this.title,
    super.key,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconTileSize = AppIconTileSize.medium,
  });

  final IconData leadingIcon;
  final Color leadingColor;

  final String title;

  /// Optional supporting metadata line (e.g. "Cash · Dining", "Next: Sep
  /// 18, 2026") -- omitted entirely (no reserved blank space) when
  /// `null`, exactly like [AppSectionHeader]'s optional [trailing].
  final String? subtitle;

  /// Typically an `AppMoneyText`, optionally wrapped in a small `Column`
  /// with an `AppStatusChip` beneath it for a status tag (e.g.
  /// "Subscription", a category label) -- entirely the caller's choice of
  /// content; this row only positions it at the row's end.
  final Widget? trailing;

  /// Only wraps the row in an [InkWell] when non-null, matching
  /// [AppCard]'s own `onTap` convention -- a non-tappable row (most list
  /// contexts) never pays for or exposes tap semantics it doesn't have.
  final VoidCallback? onTap;

  final AppIconTileSize iconTileSize;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.appTokens;
    final AppTypography typography = context.appTypography;

    // Checkpoint 10 hardening: the leading icon tile's own container width
    // (32/40/48 depending on [iconTileSize]) is the only other fixed cost
    // besides the two spacers below -- computed here so the width cap on
    // [trailing] further down can be sized against this row's actual
    // available width rather than an assumed constant.
    final double iconContainerSize = switch (iconTileSize) {
      AppIconTileSize.small => tokens.iconSizes.smallContainer,
      AppIconTileSize.medium => tokens.iconSizes.mediumContainer,
      AppIconTileSize.large => tokens.iconSizes.largeContainer,
    };

    final Widget content = Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.xs),
      child: LayoutBuilder(
        builder: (BuildContext _, BoxConstraints constraints) {
          // Checkpoint 10 hardening: [trailing] is deliberately
          // unconstrained content -- see the class doc comment; this row
          // must never silently clip or truncate a financial amount -- so
          // on its own it isn't protected from the classic Row-overflow
          // failure mode: the title column's `Expanded` can only ever
          // shrink itself down to a floor of 0, it can never claw space
          // back FROM a non-flexible sibling that already asked for more
          // than the row has. At a sufficiently narrow width (a long
          // title plus a wide trailing amount both wanting the same row),
          // that floor of 0 still isn't enough and the Row overflows.
          //
          // [maxTrailingWidth] is exactly the width remaining after the
          // icon tile and both spacers -- i.e. everything the title
          // column's `Expanded` would otherwise be entitled to. Capping
          // [trailing] to that bound (instead of leaving it truly
          // unbounded) means at every normal width the cap is larger than
          // [trailing]'s own natural size, so it never actually binds and
          // nothing about this row's normal appearance changes. Only when
          // the row is too narrow for both to fit does the cap engage,
          // and it engages on [trailing] alone: Flutter's default `Text`
          // behavior when squeezed under its natural single-line width is
          // to soft-wrap onto a second line, never to clip a digit, so
          // "never truncate money" still holds even in that emergency
          // case -- and the Row itself can no longer overflow, since
          // title-plus-bounded-trailing can never together demand more
          // than the icon and spacers left available.
          final double roomForTrailing =
              constraints.maxWidth - iconContainerSize - tokens.spacing.sm * 2;
          final double maxTrailingWidth = roomForTrailing < 0 ? 0.0 : roomForTrailing;

          return Row(
            children: <Widget>[
              AppIconTile(icon: leadingIcon, color: leadingColor, size: iconTileSize),
              SizedBox(width: tokens.spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      title,
                      style: typography.body?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...<Widget>[
                      SizedBox(height: tokens.spacing.xxs / 2),
                      Text(
                        subtitle!,
                        style: typography.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...<Widget>[
                SizedBox(width: tokens.spacing.sm),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxTrailingWidth),
                  child: trailing!,
                ),
              ],
            ],
          );
        },
      ),
    );

    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: tokens.radii.smallRadius,
      child: content,
    );
  }
}
