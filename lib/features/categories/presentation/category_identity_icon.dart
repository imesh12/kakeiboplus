import 'package:flutter/material.dart';

import '../../../shared/widgets/app_icon_tile.dart';
import '../domain/category_color.dart';
import '../domain/category_icon.dart';

/// Checkpoint U1 (Category, Service, Currency & Card Visual Identity
/// Foundation): the ONE authoritative widget that renders a category's
/// visual identity (icon + color together) from its persisted `icon`/
/// `colorKey` columns.
///
/// # Why this exists -- consistency, not decoration
///
/// Before this checkpoint, every screen that showed a category icon at
/// all resolved it independently through the bare [categoryIconFor]
/// function with a hand-picked color (see `TransactionIconBadge`,
/// `account_detail_screen.dart`), and no screen resolved a category
/// COLOR at all -- `CategoriesScreen`'s own category list didn't render
/// an icon or a color. [CategoryIdentityIcon] is the single place both
/// are resolved together, built on top of the exact same [AppIconTile]
/// primitive [TransactionIconBadge] already uses -- so a category's
/// icon+color renders IDENTICALLY wherever this widget is used (the
/// category list, every category picker/dropdown, a budget tile), which
/// is the specific property `category_identity_icon_test.dart` proves.
/// `TransactionIconBadge` itself is deliberately left as-is (it has its
/// own expense/income/transfer sign-color precedence that is out of
/// scope for this checkpoint's non-goals) rather than folded into this
/// widget.
///
/// # Never throws
///
/// [categoryIconFor]/[categoryColorFor] both already fall back safely
/// for `null`/unrecognized values (see their own doc comments) -- this
/// widget adds no additional validation of its own, so a category with
/// no icon/color set yet, or one carrying a value a future app version
/// doesn't recognize, always renders a real, deterministic icon+color
/// rather than throwing or rendering blank.
class CategoryIdentityIcon extends StatelessWidget {
  const CategoryIdentityIcon({
    required this.categoryId,
    super.key,
    this.iconKey,
    this.colorKey,
    this.size = AppIconTileSize.medium,
    this.semanticLabel,
  });

  /// The category's stable `id` -- used only as the deterministic
  /// fallback seed when [colorKey] is `null`/unrecognized. See
  /// `categoryColorFor`'s own doc comment.
  final String categoryId;

  /// The category's `icon` column value, or `null`.
  final String? iconKey;

  /// The category's `colorKey` column value, or `null`.
  final String? colorKey;

  final AppIconTileSize size;

  /// Optional accessibility label. `null` (the default) renders with no
  /// semantic label of its own -- most call sites already show adjacent
  /// text (the category's name) that makes the icon purely decorative to
  /// a screen reader, matching [AppIconTile]'s own default.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color color = categoryColorFor(categoryId: categoryId, storedColorKey: colorKey, isDark: isDark);
    return AppIconTile(
      icon: categoryIconFor(iconKey),
      color: color,
      size: size,
      semanticLabel: semanticLabel,
    );
  }
}
