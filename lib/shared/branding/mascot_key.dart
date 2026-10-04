/// Checkpoint (Dashboard mascot): the personality/branding layer's
/// stable identity key -- mirrors the same "stable key resolves to a
/// resource" architecture already used elsewhere in this codebase
/// (`CategoryColorKey`, `ServiceIdentityFamily`, `CardNetwork`), so a
/// future checkpoint that adds alternate mascot characters or
/// seasonal/theme variants has exactly the same seam to extend, and
/// nothing outside `lib/shared/branding/` ever needs to know a literal
/// asset path.
///
/// # Presentation/branding only -- never financial or domain truth
///
/// Nothing in this app persists a value of this enum today, and it
/// must never become financial or domain truth: no transaction,
/// account, profile, or any other domain model should ever store a
/// [MascotKey] (or, worse, a literal asset path) as a field. See this
/// project's "Core architectural rule" (financial truth must be
/// deterministic) -- a mascot selection is pure presentation, exactly
/// like `CategoryColorKey` already is for categories.
enum MascotKey {
  /// KakeiboPlus's default companion -- a dog, shown on the Dashboard
  /// header. The first, and for now only, variant.
  defaultDog('defaultDog');

  const MascotKey(this.storageValue);

  /// A stable string, kept for the same reason every other identity
  /// key in this codebase keeps one (`CategoryColorKey.storageValue`,
  /// `ServiceIdentityFamily.storageValue`) even though nothing
  /// persists it yet: so the day something DOES need to store a
  /// selection (a user-chosen mascot, a seasonal variant), the stable
  /// string already exists and no migration has to invent one
  /// retroactively.
  final String storageValue;
}

/// See pubspec.yaml's own comment on `assets/branding/pets/` for why
/// that folder is registered as a whole directory rather than
/// per-file: new variants added here are automatically bundled
/// without a second pubspec edit, matching this enum's own
/// "future-ready for alternate mascot variants" requirement.
const Map<MascotKey, String> _assetPaths = <MascotKey, String>{
  MascotKey.defaultDog: 'assets/branding/pets/kakeiboplus_dog_default.png',
};

/// The literal asset path for [key]. Total over [MascotKey.values] --
/// every enum value has an entry -- but keeps a defensive fallback to
/// [MascotKey.defaultDog]'s own path rather than throwing, matching
/// every other resolver of this shape in the codebase (e.g.
/// `serviceFamilyIconFor`), so a future enum value added without also
/// updating this map degrades to the default mascot instead of
/// crashing the Dashboard.
String mascotAssetPathFor(MascotKey key) =>
    _assetPaths[key] ?? _assetPaths[MascotKey.defaultDog]!;
