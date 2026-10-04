/// Public Icons Pool Integration checkpoint: a small, curated resolver
/// for GENERIC semantic UI concepts, sourced from the approved public/
/// generic icon set reviewed under `docs/design/app-icon/public-icons/`
/// (that design-source folder is never referenced at runtime -- every
/// approved icon is copied once into `assets/icons/public/` under a
/// normalized snake_case filename, and only this file knows those
/// production paths).
///
/// # Scope -- generic concepts only
///
/// This pool exists ONLY for concepts that are not already owned by a
/// more specific identity system. The app's existing precedence, from
/// most to least specific, is:
///
///   service-specific icon (`service_icon_asset.dart`)
///   > category-specific icon (`category_icon_asset.dart`)
///   > feature-specific icon (a screen's own curated pack, e.g.
///     `assets/icons/more/`, `assets/icons/dashboard/`,
///     `assets/icons/activity/`)
///   > public/generic icon (this file)
///   > Material fallback glyph
///
/// A caller higher in that list always wins; this resolver is never
/// consulted by, and never overrides, any of those more specific
/// systems. It is deliberately NOT a dumping ground for every file in
/// the public-icons source folder -- only concepts an actual production
/// screen needs, with an exact or clearly-probable filename match, are
/// given a [PublicIconKey] (see the Icon Pool Integration audit/report
/// for the full inventory and which candidates were left unmapped as
/// ambiguous).
///
/// # Deterministic, key-based, never persisted
///
/// [PublicIconKey] is a closed enum -- never a free-text/title heuristic
/// -- and the key a caller passes always comes from a value the CALLER
/// already owns and persists itself (e.g. an `AccountCreationKind`, or a
/// persisted `Accounts.type` string); this resolver never reads or
/// writes a PNG path to the database, and no domain model stores one.
/// See `account_type_presentation.dart`'s/`account_creation_kind_presentation
/// .dart`'s own small `...PublicIconAsset` functions for exactly how a
/// feature maps ITS OWN typed value to a [PublicIconKey] -- that mapping
/// stays in the feature's own presentation file, not here, so this file
/// never needs to know what an "account type" is.
enum PublicIconKey {
  /// Generic cash / physical money concept. Exact filename match:
  /// `cash-in-hand.png`.
  cash,

  /// Generic bank / financial institution building concept. Probable
  /// (not exact) filename match: `business-building.png` -- no source
  /// icon in the approved set is named for "bank" specifically, but a
  /// building is the standard generic metaphor for a financial
  /// institution and was judged a safe, non-ambiguous choice.
  bank,
}

/// The production asset path for a generic [PublicIconKey] concept.
/// Deterministic and total -- every enum value is mapped, so this never
/// actually returns `null` today; it is nullable only so a future
/// [PublicIconKey] value can be added without forcing every call site to
/// handle a path that doesn't exist yet. Exactly like
/// `categoryIconAssetFor`/`serviceIconAssetFor`, a `null` result means
/// "no public icon for this concept yet" -- callers fall back to their
/// existing Material glyph, never a blank or broken image.
String? publicIconAssetFor(PublicIconKey key) => switch (key) {
  PublicIconKey.cash => 'assets/icons/public/cash_in_hand.png',
  PublicIconKey.bank => 'assets/icons/public/business_building.png',
};
