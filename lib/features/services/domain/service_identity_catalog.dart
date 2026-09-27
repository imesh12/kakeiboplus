import '../../../l10n/generated/app_localizations.dart';
import 'service_identity.dart';

/// Checkpoint U2: one entry in the curated service/subscription
/// identity catalog -- either a NAMED service ("Netflix") or a generic,
/// unnamed placeholder for its whole [family] ("a streaming service, no
/// specific name chosen").
///
/// # Stable persisted key, never a display concept
///
/// [id] is the ONLY thing a `Transactions`/`RecurringRules` row ever
/// persists (`Categories.icon`/`CategoryColorKey.storageValue`'s exact
/// convention: a plain, stable string -- never an `IconData` codepoint,
/// never a Flutter asset path, never an index into [serviceIdentityCatalog]
/// itself, which could reorder). For a generic (unnamed) entry, [id]
/// is deliberately identical to `family.storageValue` -- there is
/// exactly one generic entry per [ServiceIdentityFamily], so no extra
/// namespacing is needed to keep it distinct from every named id below
/// (see [serviceIdentityCatalogUniqueIds] and its own test coverage).
///
/// # Category identity and service identity are separate relationships
///
/// A [ServiceIdentityDefinition] never implies or overrides a category.
/// "Netflix" (a service) commonly sits under "Entertainment" (a
/// category), but the two are independent, optional selections stored
/// in independent columns -- see `docs/14_DECISION_LOG.md` ADR-045.
///
/// # Brand-asset seam (Phase 4 of this checkpoint's brief)
///
/// This checkpoint has no licensed/approved brand-asset source, so
/// EVERY entry here -- named or generic -- resolves its rendered
/// icon+color purely from [family] (`serviceFamilyIconFor`/
/// `serviceFamilyColorFor`), never a company-specific mark. [properName]
/// is presentation text only (an official product name, e.g.
/// "Netflix" -- deliberately never localized, since a proper noun
/// doesn't translate) -- it never feeds icon/color resolution. A future
/// checkpoint with a genuine licensed-asset source has exactly one seam
/// to extend: adding an optional "which bundled asset, if any" field to
/// this class and preferring it inside `ServiceIdentityIcon`'s resolver
/// when present, falling back to today's family icon/color otherwise.
/// That change touches zero persisted data (every existing
/// `serviceIdentityKey` string stays meaningful) and zero call sites
/// beyond that one widget.
class ServiceIdentityDefinition {
  const ServiceIdentityDefinition({required this.id, required this.family, this.properName});

  /// Stable, persisted identifier -- see the class doc comment.
  final String id;

  final ServiceIdentityFamily family;

  /// The service's real, official name (e.g. "Netflix", "AWS") -- never
  /// localized (see the class doc comment). `null` for a generic,
  /// unnamed [family] placeholder entry.
  final String? properName;

  /// Whether this entry names a specific, real service, as opposed to
  /// being the generic "no specific name" placeholder for [family].
  bool get isNamed => properName != null;
}

/// The curated catalog -- Checkpoint U2's Phase 3: useful common
/// services/subscriptions grouped by family, per the checkpoint brief's
/// own list, plus exactly one generic entry per
/// [ServiceIdentityFamily] so every family remains selectable even
/// without picking a specific named service. Deliberately NOT hundreds
/// of entries -- the brief explicitly asks for a useful curated set, not
/// a merchant database.
///
/// Order here is also this catalog's presentation order (grouped by
/// family) wherever it's rendered as a flat list, e.g.
/// `ServiceIdentityDropdown`.
const List<ServiceIdentityDefinition> serviceIdentityCatalog = <ServiceIdentityDefinition>[
  // Streaming / video.
  ServiceIdentityDefinition(id: 'netflix', family: ServiceIdentityFamily.streaming, properName: 'Netflix'),
  ServiceIdentityDefinition(id: 'youtube', family: ServiceIdentityFamily.streaming, properName: 'YouTube'),
  ServiceIdentityDefinition(
    id: 'youtubePremium',
    family: ServiceIdentityFamily.streaming,
    properName: 'YouTube Premium',
  ),
  ServiceIdentityDefinition(id: 'disneyPlus', family: ServiceIdentityFamily.streaming, properName: 'Disney+'),
  ServiceIdentityDefinition(
    id: 'primeVideo',
    family: ServiceIdentityFamily.streaming,
    properName: 'Prime Video',
  ),
  ServiceIdentityDefinition(id: 'streaming', family: ServiceIdentityFamily.streaming),

  // Music.
  ServiceIdentityDefinition(id: 'spotify', family: ServiceIdentityFamily.music, properName: 'Spotify'),
  ServiceIdentityDefinition(
    id: 'appleMusic',
    family: ServiceIdentityFamily.music,
    properName: 'Apple Music',
  ),
  ServiceIdentityDefinition(
    id: 'youtubeMusic',
    family: ServiceIdentityFamily.music,
    properName: 'YouTube Music',
  ),
  ServiceIdentityDefinition(id: 'music', family: ServiceIdentityFamily.music),

  // Cloud / storage.
  ServiceIdentityDefinition(
    id: 'googleDrive',
    family: ServiceIdentityFamily.cloudStorage,
    properName: 'Google Drive',
  ),
  ServiceIdentityDefinition(
    id: 'googleOne',
    family: ServiceIdentityFamily.cloudStorage,
    properName: 'Google One',
  ),
  ServiceIdentityDefinition(id: 'icloud', family: ServiceIdentityFamily.cloudStorage, properName: 'iCloud'),
  ServiceIdentityDefinition(id: 'dropbox', family: ServiceIdentityFamily.cloudStorage, properName: 'Dropbox'),
  ServiceIdentityDefinition(
    id: 'oneDrive',
    family: ServiceIdentityFamily.cloudStorage,
    properName: 'OneDrive',
  ),
  ServiceIdentityDefinition(id: 'cloudStorage', family: ServiceIdentityFamily.cloudStorage),

  // Cloud infrastructure.
  ServiceIdentityDefinition(id: 'aws', family: ServiceIdentityFamily.cloudInfrastructure, properName: 'AWS'),
  ServiceIdentityDefinition(
    id: 'googleCloud',
    family: ServiceIdentityFamily.cloudInfrastructure,
    properName: 'Google Cloud',
  ),
  ServiceIdentityDefinition(
    id: 'azure',
    family: ServiceIdentityFamily.cloudInfrastructure,
    properName: 'Microsoft Azure',
  ),
  ServiceIdentityDefinition(id: 'cloudInfrastructure', family: ServiceIdentityFamily.cloudInfrastructure),

  // AI.
  ServiceIdentityDefinition(id: 'chatgpt', family: ServiceIdentityFamily.ai, properName: 'ChatGPT'),
  ServiceIdentityDefinition(id: 'claude', family: ServiceIdentityFamily.ai, properName: 'Claude'),
  ServiceIdentityDefinition(id: 'gemini', family: ServiceIdentityFamily.ai, properName: 'Gemini'),
  ServiceIdentityDefinition(id: 'ai', family: ServiceIdentityFamily.ai),

  // Productivity / developer.
  ServiceIdentityDefinition(
    id: 'microsoft365',
    family: ServiceIdentityFamily.productivity,
    properName: 'Microsoft 365',
  ),
  ServiceIdentityDefinition(
    id: 'googleWorkspace',
    family: ServiceIdentityFamily.productivity,
    properName: 'Google Workspace',
  ),
  ServiceIdentityDefinition(id: 'adobe', family: ServiceIdentityFamily.productivity, properName: 'Adobe'),
  ServiceIdentityDefinition(id: 'github', family: ServiceIdentityFamily.productivity, properName: 'GitHub'),
  ServiceIdentityDefinition(id: 'notion', family: ServiceIdentityFamily.productivity, properName: 'Notion'),
  ServiceIdentityDefinition(id: 'productivity', family: ServiceIdentityFamily.productivity),

  // Gaming.
  ServiceIdentityDefinition(
    id: 'playstation',
    family: ServiceIdentityFamily.gaming,
    properName: 'PlayStation',
  ),
  ServiceIdentityDefinition(id: 'xbox', family: ServiceIdentityFamily.gaming, properName: 'Xbox'),
  ServiceIdentityDefinition(id: 'nintendo', family: ServiceIdentityFamily.gaming, properName: 'Nintendo'),
  ServiceIdentityDefinition(id: 'steam', family: ServiceIdentityFamily.gaming, properName: 'Steam'),
  ServiceIdentityDefinition(id: 'gaming', family: ServiceIdentityFamily.gaming),

  // Other / catch-all -- generic only, matching `ServiceIdentityFamily
  // .other`'s own role as the safe fallback family.
  ServiceIdentityDefinition(id: 'other', family: ServiceIdentityFamily.other),
];

/// `null` means "no service selected" (never stored as any particular
/// string -- a `null` `serviceIdentityKey` column value). A non-null
/// [key] that isn't in [serviceIdentityCatalog] -- a legacy id removed
/// in a future catalog revision, or corrupted data -- degrades safely to
/// the generic [ServiceIdentityFamily.other] entry rather than throwing
/// or silently becoming indistinguishable from "no service": exactly
/// [CategoryColorKey.storageValue]'s/`categoryIconFor`'s own "resolve
/// safely, never crash on an unrecognized persisted string" contract.
ServiceIdentityDefinition? serviceIdentityDefinitionFor(String? key) {
  if (key == null) return null;
  for (final ServiceIdentityDefinition definition in serviceIdentityCatalog) {
    if (definition.id == key) return definition;
  }
  return serviceIdentityCatalog.last; // the 'other' generic entry
}

/// The accessible/localized display name for [definition] -- a real
/// service's own [ServiceIdentityDefinition.properName] verbatim (never
/// localized -- proper nouns don't translate), or a localized generic
/// label naming the family for an unnamed entry (e.g. "Generic
/// streaming service").
String serviceIdentityDisplayName(AppLocalizations l10n, ServiceIdentityDefinition definition) {
  final String? properName = definition.properName;
  if (properName != null) return properName;
  return switch (definition.family) {
    ServiceIdentityFamily.streaming => l10n.serviceFamilyStreamingGenericLabel,
    ServiceIdentityFamily.music => l10n.serviceFamilyMusicGenericLabel,
    ServiceIdentityFamily.cloudStorage => l10n.serviceFamilyCloudStorageGenericLabel,
    ServiceIdentityFamily.cloudInfrastructure => l10n.serviceFamilyCloudInfrastructureGenericLabel,
    ServiceIdentityFamily.ai => l10n.serviceFamilyAiGenericLabel,
    ServiceIdentityFamily.productivity => l10n.serviceFamilyProductivityGenericLabel,
    ServiceIdentityFamily.gaming => l10n.serviceFamilyGamingGenericLabel,
    ServiceIdentityFamily.other => l10n.serviceFamilyOtherGenericLabel,
  };
}
