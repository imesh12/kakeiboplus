import 'package:flutter/material.dart';

import '../../../shared/widgets/app_icon_tile.dart';
import '../domain/service_identity.dart';

/// Checkpoint U1: renders a [ServiceIdentityKey]'s generic icon+color
/// through the same shared [AppIconTile] primitive [CategoryIdentityIcon]
/// (`lib/features/categories/presentation/category_identity_icon.dart`)
/// and `TransactionIconBadge` already build on -- see
/// [ServiceIdentityKey]'s own doc comment for why this renders a
/// generic family icon rather than a brand logo.
///
/// Total, never throws: [key] defaults to [ServiceIdentityKey.other],
/// and [ServiceIdentityKey.fromStorageValue] (for the day a caller has
/// a raw persisted string instead of an enum value in hand) already
/// falls back to it for anything unrecognized.
class ServiceIdentityIcon extends StatelessWidget {
  const ServiceIdentityIcon({
    super.key,
    this.identityKey = ServiceIdentityKey.other,
    this.size = AppIconTileSize.medium,
    this.semanticLabel,
  });

  final ServiceIdentityKey identityKey;
  final AppIconTileSize size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return AppIconTile(
      icon: serviceIdentityIconFor(identityKey),
      color: serviceIdentityColorFor(identityKey, isDark: isDark),
      size: size,
      semanticLabel: semanticLabel,
    );
  }
}
