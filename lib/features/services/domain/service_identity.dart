import 'package:flutter/material.dart';

import '../../categories/domain/category_color.dart';

/// Checkpoint U2 (Service / Merchant Identity Integration & App-Wide
/// Financial Visual Consistency): the coarse VISUAL family a service
/// identity belongs to -- "streaming", "music", "cloud infrastructure",
/// etc. Every icon/color this app ever shows for a service -- named
/// (Netflix) or generic ("Streaming service") -- resolves through one of
/// these 8 families; see `ServiceIdentityDefinition` in
/// `service_identity_catalog.dart` for the NAMED layer built on top of
/// this one.
///
/// # Evolves U1's `ServiceIdentityKey`, does not replace its architecture
///
/// U1 shipped this exact enum under the name `ServiceIdentityKey` with 7
/// values, deliberately unwired to any persisted field (its own doc
/// comment: "nothing yet persists a selection"). Since nothing has ever
/// stored one of its `storageValue` strings anywhere (confirmed: no DB
/// column existed for it before this checkpoint), renaming it here to
/// `ServiceIdentityFamily` -- and splitting its old single `aiSoftware`
/// value into separate [cloudInfrastructure] and [ai] families, matching
/// this checkpoint's brief -- changes no persisted data and breaks no
/// migration. The resolution architecture itself (a fixed, generic,
/// unbranded icon+color per value, reusing `CategoryColorKey`'s palette
/// rather than a second one) is unchanged from U1.
///
/// # Still a family catalog, not a brand-logo catalog
///
/// Exactly as U1 established: this codebase has no licensed brand-asset
/// source (see `docs/14_DECISION_LOG.md` ADR-044/045), so every value
/// here resolves to a generic, unbranded icon + color -- never a
/// specific company's mark. A NAMED service (e.g. "Netflix") still
/// renders through its family's generic icon/color today; see
/// `ServiceIdentityDefinition`'s own doc comment for the seam a future
/// checkpoint with a genuine licensed-asset source would extend instead
/// of replace.
enum ServiceIdentityFamily {
  streaming('streaming'),
  music('music'),
  cloudStorage('cloudStorage'),
  cloudInfrastructure('cloudInfrastructure'),
  ai('ai'),
  productivity('productivity'),
  gaming('gaming'),
  other('other');

  const ServiceIdentityFamily(this.storageValue);

  /// Stable string -- never persisted directly by anything in this
  /// checkpoint (a transaction/recurring rule persists a
  /// `ServiceIdentityDefinition.id` instead, which for a generic-family
  /// selection simply equals this value -- see that class's doc
  /// comment), but kept as a stable string regardless, matching every
  /// other identity key in this codebase (`CategoryColorKey
  /// .storageValue`, `CardNetwork.storageValue`).
  final String storageValue;

  static ServiceIdentityFamily fromStorageValue(String? value) {
    for (final ServiceIdentityFamily family in ServiceIdentityFamily.values) {
      if (family.storageValue == value) return family;
    }
    return ServiceIdentityFamily.other;
  }
}

const Map<ServiceIdentityFamily, IconData> _icons = <ServiceIdentityFamily, IconData>{
  ServiceIdentityFamily.streaming: Icons.smart_display,
  ServiceIdentityFamily.music: Icons.music_note,
  ServiceIdentityFamily.cloudStorage: Icons.cloud,
  ServiceIdentityFamily.cloudInfrastructure: Icons.dns,
  ServiceIdentityFamily.ai: Icons.smart_toy,
  ServiceIdentityFamily.productivity: Icons.apps,
  ServiceIdentityFamily.gaming: Icons.sports_esports,
  ServiceIdentityFamily.other: Icons.subscriptions,
};

/// Reuses `CategoryColorKey`'s existing curated, light+dark-safe palette
/// rather than inventing a second color system -- unchanged from U1's
/// own reasoning, just extended to the 2 new families.
const Map<ServiceIdentityFamily, CategoryColorKey> _colorKeys =
    <ServiceIdentityFamily, CategoryColorKey>{
  ServiceIdentityFamily.streaming: CategoryColorKey.red,
  ServiceIdentityFamily.music: CategoryColorKey.green,
  ServiceIdentityFamily.cloudStorage: CategoryColorKey.blue,
  ServiceIdentityFamily.cloudInfrastructure: CategoryColorKey.cyan,
  ServiceIdentityFamily.ai: CategoryColorKey.purple,
  ServiceIdentityFamily.productivity: CategoryColorKey.indigo,
  ServiceIdentityFamily.gaming: CategoryColorKey.teal,
  ServiceIdentityFamily.other: CategoryColorKey.slate,
};

/// The generic, unbranded icon for [family]. Total over
/// [ServiceIdentityFamily.values] -- every enum value has an entry, so
/// this never needs a fallback branch of its own.
IconData serviceFamilyIconFor(ServiceIdentityFamily family) =>
    _icons[family] ?? Icons.subscriptions;

/// The color for [family], for [isDark]. Delegates to
/// `categoryColorForKey` -- see [_colorKeys]'s own doc note.
Color serviceFamilyColorFor(ServiceIdentityFamily family, {required bool isDark}) {
  final CategoryColorKey colorKey = _colorKeys[family] ?? CategoryColorKey.slate;
  return categoryColorForKey(colorKey, isDark: isDark);
}
