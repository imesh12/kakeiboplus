/// App Icon Integration checkpoint: presentation-only, additive artwork
/// for a curated subset of [categoryIconFor]'s existing icon-key catalog
/// (`category_icon.dart`) -- never a new column, never a new persisted
/// value, never a change to `Categories.icon`'s meaning.
///
/// # Presentation layer only -- resolves a KEY that already exists
///
/// Every key this map recognizes is already a real, pre-existing entry
/// in [categoryIconKeys] (`category_icon.dart`) -- this file adds no new
/// icon key, no new category, and no schema/seed change. It only gives
/// some of those already-resolvable keys nicer custom artwork than the
/// generic Material glyph [categoryIconFor] falls back to. A category
/// (system or user-created) picks its `icon` value exactly as before;
/// this map is consulted purely at render time by [CategoryIdentityIcon]
/// to decide whether a PNG is available for that value.
///
/// # Deliberately a separate file/map from `category_icon.dart`
///
/// `category_icon.dart`'s own doc comment is explicit that it stays "the
/// ONE map from a stable string key to an `IconData`" -- adding asset
/// paths into that map would blur "the Material glyph for this key" with
/// "the artwork override for this key", two different concerns with
/// different fallback semantics (an asset can be absent; the Material
/// icon never is). Keeping them in separate maps means
/// [categoryIconFor] is untouched and every existing `IconData` caller
/// keeps working exactly as before -- this file is purely additive.
///
/// # `'category'` IS mapped -- narrowly, and deliberately so
///
/// `'category'` is also [fallbackCategoryIcon] -- the fallback rendered
/// for `null` and for any icon key this build doesn't recognize. An
/// earlier revision of this file left `'category'` unmapped specifically
/// to avoid that fallback silently picking up custom artwork. That
/// caution turns out not to apply here: [categoryIconAssetFor] returns
/// `null` for a `null` key BEFORE ever consulting this map (see its own
/// body below), and a genuinely unrecognized string key (one that isn't
/// a literal entry in this map) also simply misses the lookup and
/// returns `null` -- this map has no "wildcard applies to the fallback
/// too" behavior of its own; that only lives in the separate
/// `categoryIconFor`/`fallbackCategoryIcon` pairing in `category_icon
/// .dart`, which this file does not touch. So mapping the literal string
/// `'category'` here affects ONLY a category whose `icon` column is
/// exactly that string -- the seeded "Other" expense category
/// (`CategoryRepository._systemCategories`'s `sys-other-expense` row),
/// and any category (system or user-created) where a user has
/// explicitly picked "Other" from the icon catalog's picker (`category
/// _icon_catalog.dart`'s `'category' => l10n.categoryIconOther` entry).
/// A category with NO icon set, or with some other unrecognized value,
/// is untouched and keeps rendering the generic Material glyph exactly
/// as before -- see `category_icon_asset_test.dart`'s own coverage for
/// both of those cases.
///
/// [categoryIconAssetFor] never throws: a `null` or unrecognized key
/// simply returns `null`, which callers (see [CategoryIdentityIcon])
/// treat as "no custom artwork for this -- render the Material icon
/// instead", never as an error or a blank icon.
const Map<String, String> _categoryIconAssetsByKey = <String, String>{
  'shopping_cart': 'assets/icons/categories/groceries.png',
  'directions_bus': 'assets/icons/categories/transport.png',
  'receipt_long': 'assets/icons/categories/bills_utilities.png',
  'restaurant': 'assets/icons/categories/dining_out.png',
  'local_hospital': 'assets/icons/categories/health.png',
  'category': 'assets/icons/categories/other.png',
  'work': 'assets/icons/categories/salary.png',
  'attach_money': 'assets/icons/categories/other_income.png',
  'shopping_bag': 'assets/icons/categories/shopping_bag.png',
};

/// The custom artwork asset path for a category's `icon` column value,
/// or `null` when no custom artwork exists for it (a `null` key, or any
/// key with no entry in [_categoryIconAssetsByKey] -- which, as of the
/// Category Icon Source Correction checkpoint, no longer includes
/// `'category'`; see this file's own doc comment for exactly which
/// categories that now affects). Callers fall back to [categoryIconFor]'s
/// Material glyph when this returns `null`.
String? categoryIconAssetFor(String? iconKey) {
  if (iconKey == null) return null;
  return _categoryIconAssetsByKey[iconKey];
}
