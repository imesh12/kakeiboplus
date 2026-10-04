import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Checkpoint 10 (Icon-Led UI Foundation): which of [AppTokens.iconSizes]'
/// three named tiers backs an [AppIconTile] -- purely a size choice, like
/// [AppMoneyEmphasis] on `AppMoneyText`.
enum AppIconTileSize { small, medium, large }

/// Checkpoint 10 (Icon-Led UI Foundation)'s shared semantic icon-tile
/// primitive: a compact rounded-square, [color]-tinted background behind a
/// [color]-tinted icon -- the exact idiom the approved 8-screen reference
/// uses everywhere an icon needs a container (transaction/account/
/// subscription/category rows, Home's metric tiles).
///
/// # Evolves, does not duplicate, `TransactionIconBadge`
///
/// `lib/features/transactions/presentation/transaction_icon_badge.dart`
/// already established this exact visual idiom for one call site
/// (a transaction row's leading icon) before this checkpoint --
/// `Container(width: 40, height: 40, decoration: BoxDecoration(color:
/// color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
/// child: Icon(icon, color: color, size: 20))`. This checkpoint
/// generalizes that shape into a reusable primitive (this widget) with
/// named size tiers, and refactors `TransactionIconBadge` to build on it
/// at [AppIconTileSize.medium] -- the exact same 40/12/20/0.14 numbers, so
/// that refactor is a pure rename, not a visual change (see that widget's
/// own updated doc comment and `transaction_icon_badge_test.dart`-style
/// coverage in `app_icon_tile_test.dart`).
///
/// No financial/domain logic lives here -- purely a presentation
/// primitive, exactly like [AppCard]/`AppMoneyText`. The caller always
/// supplies its own semantic [color] (e.g. `context.appTokens.colors.positive`
/// for income, `colorScheme.error` for expense) -- this widget never
/// hardcodes a `Color` constant of its own, so every theme (Light/Dark/
/// Pink/Ocean/Forest) re-tints for free through whatever [ColorScheme]/
/// [AppTokens] role the caller already resolved.
class AppIconTile extends StatelessWidget {
  const AppIconTile({
    required this.icon,
    required this.color,
    super.key,
    this.size = AppIconTileSize.medium,
    this.semanticLabel,
    this.containerSize,
    this.glyphSize,
    this.assetPath,
  });

  final IconData icon;

  /// Optional multicolor artwork; leaves all glyph-only callers unchanged.
  final String? assetPath;

  /// Tints both the tile's background (at a fixed, restrained 0.14 alpha
  /// -- matching `TransactionIconBadge`'s existing tint) and the icon
  /// glyph itself (at full opacity) -- the same two-tone-of-one-color
  /// idiom every existing tinted-icon call site in this app already uses.
  final Color color;

  final AppIconTileSize size;

  /// Optional accessibility label for the icon alone. Most call sites
  /// already render adjacent text (a row's title, a section header) that
  /// makes the icon purely decorative to a screen reader -- this is only
  /// for the rarer case where the icon is the sole indicator of meaning.
  /// `null` (the default) renders the icon with no semantic label of its
  /// own, exactly like every existing tinted-icon call site today.
  final String? semanticLabel;

  /// Dashboard icon-balance pass: an optional override for the tile's
  /// own container width/height, replacing whatever [size]'s named
  /// tier would otherwise give. `null` (the default) is pixel-
  /// identical to every pre-existing call site -- this only exists so
  /// one caller (today, Home's 2x2 metric cards) can ask for a
  /// container size between two named tiers (e.g. 44, between
  /// [AppIconTileSize.medium]'s 40 and [AppIconTileSize.large]'s 48)
  /// without changing [AppIconTileSize.large]'s own shared numbers and
  /// so affecting every OTHER screen that already uses that tier
  /// (`account_detail_screen.dart`, for one). [size] still selects the
  /// corner radius either way.
  final double? containerSize;

  /// Dashboard icon-balance pass: an optional override for the glyph's
  /// own size, independent of [containerSize]/[size]'s container.
  /// Different [IconData] glyphs (an arrow-based "trending" icon vs. a
  /// solid "wallet"/"bar chart" icon) can read as a different visual
  /// weight at the exact same numerical [Icon.size], so a caller
  /// rendering several icons side by side for optical balance may need
  /// to nudge one glyph a point or two without changing its container
  /// -- `null` (the default) is pixel-identical to every pre-existing
  /// call site.
  final double? glyphSize;

  @override
  Widget build(BuildContext context) {
    final AppIconSizes sizes = context.appTokens.iconSizes;
    final (double tierContainer, double tierGlyph) = switch (size) {
      AppIconTileSize.small => (sizes.smallContainer, sizes.smallIcon),
      AppIconTileSize.medium => (sizes.mediumContainer, sizes.mediumIcon),
      AppIconTileSize.large => (sizes.largeContainer, sizes.largeIcon),
    };
    final double container = containerSize ?? tierContainer;
    final double glyph = glyphSize ?? tierGlyph;
    // Radius scales with container size so the tile's corners stay
    // proportionate at every tier, rather than a single fixed radius
    // looking too sharp on the small tile or too subtle on the large one
    // -- container/radius ratios of 32/8, 40/12 (TransactionIconBadge's
    // pre-existing ratio), and 48/16 stay visually consistent.
    final double radius = switch (size) {
      AppIconTileSize.small => 8,
      AppIconTileSize.medium => 12,
      AppIconTileSize.large => 16,
    };

    if (assetPath != null) {
      return SizedBox(
        width: container,
        height: container,
        child: Center(
          child: Image.asset(
            assetPath!, width: 32, height: 32, fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            excludeFromSemantics: semanticLabel == null,
            semanticLabel: semanticLabel,
          ),
        ),
      );
    }
    return Container(
      width: container,
      height: container,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, color: color, size: glyph, semanticLabel: semanticLabel),
    );
  }
}
