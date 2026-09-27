import 'package:flutter/material.dart';

import '../../../shared/widgets/app_icon_tile.dart';
import '../domain/service_identity.dart';
import '../domain/service_identity_catalog.dart';

/// Checkpoint U2: renders a persisted `serviceIdentityKey` string (a
/// `Transactions`/`RecurringRules` column value) through the same shared
/// `AppIconTile` primitive `CategoryIdentityIcon`/`TransactionIconBadge`
/// already build on.
///
/// # Evolves U1's widget of the same name
///
/// U1's `ServiceIdentityIcon` took a `ServiceIdentityKey` enum value
/// directly -- reasonable when nothing persisted a selection yet. Now
/// that a real, persisted string exists (see `docs/14_DECISION_LOG.md`
/// ADR-045), this widget takes that raw [serviceIdentityKey] string
/// instead and resolves it itself via `serviceIdentityDefinitionFor` --
/// exactly [CategoryIdentityIcon]'s own "take the persisted string,
/// resolve internally, never require the caller to pre-resolve" contract.
///
/// Total, never throws: `null` and any unrecognized string both resolve
/// safely (`serviceIdentityDefinitionFor`'s own contract) to a rendered
/// icon+color -- this widget has no "nothing to show" state of its own.
/// A caller that wants a fallback to category identity or a generic
/// transaction icon when there is NO service at all should check
/// `serviceIdentityKey == null` itself first (see
/// `TransactionIconBadge`'s own updated doc comment for the one shared
/// resolution hierarchy this checkpoint establishes) -- this widget by
/// itself only answers "how does the service identity named by this key
/// render", not "should a service identity render here at all".
class ServiceIdentityIcon extends StatelessWidget {
  const ServiceIdentityIcon({
    super.key,
    this.serviceIdentityKey,
    this.size = AppIconTileSize.medium,
    this.semanticLabel,
  });

  /// A `ServiceIdentityDefinition.id`, or `null` to render the safe
  /// generic-family fallback (`serviceIdentityDefinitionFor(null)`
  /// resolves to `null`, which this widget itself further falls back to
  /// the `other` family for -- see `build`).
  final String? serviceIdentityKey;

  final AppIconTileSize size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    // `serviceIdentityDefinitionFor` returns null only for a null key
    // (see its own doc comment) -- this widget renders SOMETHING
    // regardless, so a null key/definition still falls through to the
    // same generic `other`-family icon+color a caller who wants "no
    // service at all" should have avoided reaching this widget for in
    // the first place (see the class doc comment).
    final ServiceIdentityFamily family =
        serviceIdentityDefinitionFor(serviceIdentityKey)?.family ?? ServiceIdentityFamily.other;
    return AppIconTile(
      icon: serviceFamilyIconFor(family),
      color: serviceFamilyColorFor(family, isDark: isDark),
      size: size,
      semanticLabel: semanticLabel,
    );
  }
}
