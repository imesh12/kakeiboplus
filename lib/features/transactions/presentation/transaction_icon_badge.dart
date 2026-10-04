import 'package:flutter/material.dart';

import '../../../shared/widgets/app_icon_tile.dart';
import '../../categories/domain/category_icon.dart';
import '../../categories/domain/category_icon_asset.dart';
import '../../services/domain/service_identity.dart';
import '../../services/domain/service_identity_catalog.dart';

/// A small rounded-square tinted icon badge for one transaction row --
/// Beta 1 Transaction UX Phase B, Checkpoint 2
/// (`docs/14_DECISION_LOG.md` ADR-025/026).
///
/// Mirrors the tinted icon-badge idiom `home_screen.dart`'s
/// `_MetricTile` already establishes (a soft, [color]-tinted background
/// behind a [color]-tinted icon) rather than inventing a new visual
/// language, and is entirely [ColorScheme]-driven through the [color]
/// the caller passes in -- this widget never hardcodes a `Color`
/// constant of its own.
///
/// Checkpoint 10 (Icon-Led UI Foundation): this widget's own 40px/radius-12/
/// alpha-0.14 shape is now generalized into the shared [AppIconTile]
/// primitive (`lib/shared/widgets/app_icon_tile.dart`), and this class
/// delegates to it at [AppIconTileSize.medium] -- [AppIconTile]'s medium
/// tier was deliberately defined to match this widget's own pre-existing
/// numbers exactly, so this is a pure internal refactor (evolve, don't
/// duplicate) with byte-for-byte identical rendered output: same 40x40
/// container, same radius-12 corners, same 0.14 background alpha, same
/// 20px glyph. Only [type]/[categoryIconName] -> [IconData] resolution
/// stays local to this widget; the tinted-container presentation itself
/// now lives in one place.
///
/// For `type == 'transfer'`, always shows the transfer icon -- a
/// transfer never carries a category (ADR-025 Correction 2), so
/// [categoryIconName] is expected (but not required) to be `null` in
/// that case. For `'expense'`/`'income'` WITH a category chosen, shows
/// that category's icon via [categoryIconFor] (which itself falls back
/// safely for an unrecognized icon name). For `'expense'`/`'income'`
/// with NO category chosen ([categoryIconName] is `null`), falls back
/// to the same plain "+"/"-" icon Activity used before this checkpoint
/// -- preserved deliberately so the expense/income distinction never
/// depends on a category being present, on top of [color] and the
/// caller's separate sign-prefixed amount text.
///
/// Checkpoint U2 (Service / Merchant Identity Integration): [serviceIdentityKey]
/// adds one more, HIGHEST-precedence rung to the glyph-only fallback
/// ladder above -- service identity (if present) > category icon (if
/// present) > plain type glyph. Deliberately a GLYPH-only override: the
/// tinted container's [color] always stays exactly what the caller
/// already passes in (the transaction TYPE color -- error/primary/
/// onSurfaceVariant), never a service- or category-specific color, so
/// "color = financial type" remains authoritative in list/row contexts
/// exactly as before this checkpoint. (Full-color service/category
/// identity rendering is reserved for picker/dialog contexts via
/// [ServiceIdentityIcon]/`CategoryIdentityIcon`, not this row badge.)
/// An unrecognized/legacy [serviceIdentityKey] resolves safely to the
/// generic "other" family glyph via [serviceIdentityDefinitionFor] --
/// never a crash, never silently treated as "no service" when a
/// non-null key was actually stored.
///
/// # UI/Icon Polish checkpoint: curated category artwork
///
/// When the ladder above resolves to a plain category glyph (no service
/// identity, not a transfer, a category IS chosen), [categoryIconAssetFor]
/// -- the exact same resolver `CategoryIdentityIcon` already uses, not a
/// second map -- may additionally resolve a curated PNG for that same
/// icon key. When it does, [AppIconTile] renders that PNG instead of the
/// glyph; when it doesn't (no curated asset, an unrecognized key, or no
/// category), the glyph computed above renders exactly as before this
/// checkpoint. This is a strictly ADDITIVE rung at the BOTTOM of the
/// existing precedence -- service identity > category (asset-or-glyph)
/// > plain type glyph -- never a new rung above service identity, and
/// never anything for a transfer (which never carries a category).
class TransactionIconBadge extends StatelessWidget {
  const TransactionIconBadge({
    required this.type,
    required this.color,
    super.key,
    this.categoryIconName,
    this.serviceIdentityKey,
    this.containerSize,
    this.glyphSize,
  });

  /// `'expense'` | `'income'` | `'transfer'` -- `Transaction.type`.
  final String type;
  final Color color;
  final String? categoryIconName;

  /// Persisted `Transaction.serviceIdentityKey` /
  /// `RecurringRule.serviceIdentityKey` -- `null` means no service was
  /// chosen for this entry (never expected for a transfer, mirroring
  /// [categoryIconName]).
  final String? serviceIdentityKey;

  /// Dashboard "Upcoming" row pass (docs/14_DECISION_LOG.md ADR-049):
  /// optional pass-through to [AppIconTile.containerSize] -- `null` (the
  /// default) is pixel-identical to every pre-existing call site (still
  /// [AppIconTileSize.medium]'s own 40px). Lets one caller (today, the
  /// Home Upcoming row) ask for a container between [AppIconTileSize]'s
  /// named tiers (e.g. 44, between medium's 40 and large's 48) without
  /// introducing a second icon system or a new size tier that would also
  /// affect every other existing call site of this widget.
  final double? containerSize;

  /// Pass-through to [AppIconTile.glyphSize], independent of
  /// [containerSize] -- `null` (the default) is pixel-identical to every
  /// pre-existing call site.
  final double? glyphSize;

  @override
  Widget build(BuildContext context) {
    final ServiceIdentityDefinition? serviceDefinition =
        serviceIdentityDefinitionFor(serviceIdentityKey);
    final IconData icon = serviceDefinition != null
        ? serviceFamilyIconFor(serviceDefinition.family)
        : switch (type) {
            'transfer' => Icons.swap_horiz,
            'income' => categoryIconName != null ? categoryIconFor(categoryIconName) : Icons.add,
            _ => categoryIconName != null ? categoryIconFor(categoryIconName) : Icons.remove,
          };
    // UI/Icon Polish checkpoint: one more, LOWEST-precedence rung below
    // the glyph ladder above -- a curated category PNG
    // (`categoryIconAssetFor`, the same resolver `CategoryIdentityIcon`
    // already uses) renders INSTEAD of the plain category glyph, but
    // only when nothing higher in the ladder already claimed the icon:
    // never when a service identity is present (service identity's own
    // glyph always wins -- this never regresses that precedence), and
    // never for a transfer (categoryIconName is contractually null
    // there already, so this is also just defense in depth). A category
    // with no curated asset, an unrecognized icon key, or no category
    // at all all resolve `categoryIconAssetFor` to `null` -- AppIconTile
    // then falls back to the exact same `icon` glyph computed above, so
    // this can never render blank or throw.
    final String? categoryAsset = serviceDefinition == null && type != 'transfer'
        ? categoryIconAssetFor(categoryIconName)
        : null;
    return AppIconTile(
      icon: icon,
      assetPath: categoryAsset,
      color: color,
      size: AppIconTileSize.medium,
      containerSize: containerSize,
      glyphSize: glyphSize,
    );
  }
}
