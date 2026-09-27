import 'package:flutter/material.dart';

import '../../../shared/widgets/app_icon_tile.dart';
import '../../categories/domain/category_icon.dart';
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
class TransactionIconBadge extends StatelessWidget {
  const TransactionIconBadge({
    required this.type,
    required this.color,
    super.key,
    this.categoryIconName,
    this.serviceIdentityKey,
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
    return AppIconTile(icon: icon, color: color, size: AppIconTileSize.medium);
  }
}
