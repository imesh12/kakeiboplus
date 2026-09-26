import 'package:flutter/material.dart';

import '../../categories/domain/category_color.dart';

/// Checkpoint U1 (Category, Service, Currency & Card Visual Identity
/// Foundation): a SEPARATE identity catalog for services/subscriptions
/// (e.g. "Netflix", "Spotify") -- category ("Entertainment") and
/// service ("Netflix") are deliberately different concepts, per the
/// checkpoint brief's own explicit requirement.
///
/// # Why this is a family catalog, not a brand-logo catalog
///
/// The brief requires: use official/licensed/permitted brand assets
/// WHERE APPROPRIATE, or otherwise fall back to a neutral service
/// identity -- and separately forbids ever fabricating an approximation
/// of a real trademark, recoloring a brand logo, or depending on a
/// remote logo URL. This codebase has no licensed brand-asset source
/// available to it (no asset files, no vetted logo package -- see this
/// checkpoint's own audit in `docs/14_DECISION_LOG.md` ADR-044), so the
/// only choice consistent with the brief's own rules is the neutral
/// fallback branch: every [ServiceIdentityKey] here names a service
/// FAMILY (streaming video, music, cloud storage, AI/software,
/// productivity, gaming) and resolves to a generic, unbranded icon +
/// color -- never a specific company's mark. This is a deliberate,
/// explicit choice, not an oversight: it satisfies "never fabricate a
/// trademark approximation" and "never depend on a remote logo" at zero
/// risk, while still proving the "category identity and service
/// identity are two separate catalogs" architecture the brief asks for.
/// A future checkpoint that gains a genuine licensed-asset source can
/// extend this enum with specific branded entries without changing
/// [serviceIdentityIconFor]/[serviceIdentityColorFor]'s call sites.
///
/// # Not wired into any screen yet
///
/// No existing transaction/recurring-rule/subscription feature in this
/// codebase persists a "which service" selection anywhere (the
/// pre-checkpoint audit found no service/subscription matching logic
/// at all) -- so there is nothing yet to attach this catalog TO. This
/// checkpoint proves the architecture (this file, [ServiceIdentityIcon],
/// and their tests) without inventing a new persisted field or a
/// merchant-matching heuristic; the brief itself only asks that
/// "service matching... be conservative/presentation-only" WHEN it
/// exists, and that persistence be added only once actually needed --
/// premature persistence for a feature with no UI yet would violate
/// that same "audit before adding a column" discipline this checkpoint
/// applied everywhere else.
enum ServiceIdentityKey {
  streaming('streaming'),
  music('music'),
  cloudStorage('cloudStorage'),
  aiSoftware('aiSoftware'),
  productivity('productivity'),
  gaming('gaming'),
  other('other');

  const ServiceIdentityKey(this.storageValue);

  /// Reserved for the day a service SELECTION is actually persisted
  /// somewhere -- not read/written by anything in this checkpoint. Kept
  /// as a stable string, matching every other identity key in this
  /// checkpoint (`CategoryColorKey.storageValue`, `CardNetwork
  /// .storageValue`), so that day never has to invent this convention.
  final String storageValue;

  static ServiceIdentityKey fromStorageValue(String? value) {
    for (final ServiceIdentityKey key in ServiceIdentityKey.values) {
      if (key.storageValue == value) return key;
    }
    return ServiceIdentityKey.other;
  }
}

const Map<ServiceIdentityKey, IconData> _icons = <ServiceIdentityKey, IconData>{
  ServiceIdentityKey.streaming: Icons.smart_display,
  ServiceIdentityKey.music: Icons.music_note,
  ServiceIdentityKey.cloudStorage: Icons.cloud,
  ServiceIdentityKey.aiSoftware: Icons.smart_toy,
  ServiceIdentityKey.productivity: Icons.apps,
  ServiceIdentityKey.gaming: Icons.sports_esports,
  ServiceIdentityKey.other: Icons.subscriptions,
};

/// Reuses [CategoryColorKey]'s existing curated, light+dark-safe palette
/// rather than inventing a second color system -- see this file's own
/// "prefer extending/reusing existing architecture" doc note above.
const Map<ServiceIdentityKey, CategoryColorKey> _colorKeys = <ServiceIdentityKey, CategoryColorKey>{
  ServiceIdentityKey.streaming: CategoryColorKey.red,
  ServiceIdentityKey.music: CategoryColorKey.green,
  ServiceIdentityKey.cloudStorage: CategoryColorKey.blue,
  ServiceIdentityKey.aiSoftware: CategoryColorKey.purple,
  ServiceIdentityKey.productivity: CategoryColorKey.indigo,
  ServiceIdentityKey.gaming: CategoryColorKey.teal,
  ServiceIdentityKey.other: CategoryColorKey.slate,
};

/// The generic, unbranded icon for [key]. Total over [ServiceIdentityKey
/// .values] -- every enum value has an entry, so this never needs a
/// fallback branch of its own (unlike [categoryIconFor], which resolves
/// an arbitrary persisted string).
IconData serviceIdentityIconFor(ServiceIdentityKey key) => _icons[key] ?? Icons.subscriptions;

/// The color for [key], for [isDark]. See [_colorKeys]'s own doc note
/// for why this delegates to [categoryColorForKey] instead of a second
/// palette.
Color serviceIdentityColorFor(ServiceIdentityKey key, {required bool isDark}) {
  final CategoryColorKey colorKey = _colorKeys[key] ?? CategoryColorKey.slate;
  return categoryColorForKey(colorKey, isDark: isDark);
}
