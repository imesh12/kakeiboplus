import 'package:flutter/material.dart';

/// Checkpoint U1 (Category, Service, Currency & Card Visual Identity
/// Foundation) -- the curated, accessible category color palette, plus
/// the resolver that maps a category's persisted `colorKey` (see
/// `Categories.colorKey`, `lib/core/database/tables.dart`) to a concrete
/// [Color].
///
/// # Why a stable string key, never a raw [Color]/index
///
/// Same discipline as `category_icon.dart`'s `Categories.icon` ->
/// [IconData] mapping (see that file's own doc comment) and the U1
/// checkpoint brief's own non-negotiable principle: persisting a raw ARGB
/// int or a palette *index* would silently break if this list is ever
/// reordered, and persisting a [Color] that was itself derived from
/// `Theme.of(context).colorScheme` would make the same category render a
/// different color depending on which theme happened to be active when it
/// was saved. A small named [_CategoryColorKey] set, stored as plain text
/// exactly like `Categories.icon` already is, is immune to both problems
/// and reads/writes identically regardless of theme.
///
/// # Light + dark safety
///
/// Every entry below is one fixed pair of Material-tonal-palette-derived
/// colors (a "light" value used in a light theme, a "dark" value used in
/// a dark theme) rather than one raw hex applied unchanged in both --
/// picked so each maintains reasonable contrast against both
/// `ColorScheme.light().surface` and `ColorScheme.dark().surface` at the
/// alpha [AppIconTile]/[AppStatusChip]-style tinted containers already
/// use elsewhere in this app. This mapping never reads `Theme.of(context)`
/// itself (see [categoryColorForKey]'s own doc) -- the caller supplies
/// `Theme.of(context).brightness` once, exactly like any other
/// presentation primitive in this app.
///
/// # Never throws
///
/// [categoryColorForKey] and [resolveCategoryColorKey] both fall back
/// deterministically for `null` or any unrecognized key -- see their own
/// doc comments -- so a legacy row created before this checkpoint, or a
/// future app version's not-yet-understood key read by an older build,
/// always renders a real color rather than crashing or rendering nothing.
enum CategoryColorKey {
  slate('slate'),
  red('red'),
  orange('orange'),
  amber('amber'),
  yellow('yellow'),
  lime('lime'),
  green('green'),
  teal('teal'),
  cyan('cyan'),
  blue('blue'),
  indigo('indigo'),
  purple('purple'),
  pink('pink'),
  brown('brown');

  const CategoryColorKey(this.storageValue);

  /// The exact string persisted in `Categories.colorKey`. Never rename an
  /// existing value once shipped -- add a new entry instead, following
  /// `CardNetwork.storageValue`'s own established convention
  /// (`lib/core/finance/card_network.dart`).
  final String storageValue;

  static CategoryColorKey? fromStorageValue(String? value) {
    if (value == null) return null;
    for (final CategoryColorKey key in CategoryColorKey.values) {
      if (key.storageValue == value) return key;
    }
    return null;
  }
}

/// One light/dark color pair per [CategoryColorKey]. Chosen from the
/// Material 3 tonal palette family (roughly tone 40 for light, tone 70 for
/// dark) so every entry keeps comparable contrast/vibrancy against its
/// own theme's surface -- the same reason [AppIconTile]'s 0.14-alpha tint
/// idiom works consistently for any color passed to it regardless of
/// theme.
const Map<CategoryColorKey, Color> _lightColors = <CategoryColorKey, Color>{
  CategoryColorKey.slate: Color(0xFF546472),
  CategoryColorKey.red: Color(0xFFB3261E),
  CategoryColorKey.orange: Color(0xFFB2540A),
  CategoryColorKey.amber: Color(0xFF8C6D00),
  CategoryColorKey.yellow: Color(0xFF766D00),
  CategoryColorKey.lime: Color(0xFF5C7A0A),
  CategoryColorKey.green: Color(0xFF2E7D4F),
  CategoryColorKey.teal: Color(0xFF00766C),
  CategoryColorKey.cyan: Color(0xFF00696F),
  CategoryColorKey.blue: Color(0xFF2E5FA3),
  CategoryColorKey.indigo: Color(0xFF4A5CC7),
  CategoryColorKey.purple: Color(0xFF7B4FA3),
  CategoryColorKey.pink: Color(0xFFA33465),
  CategoryColorKey.brown: Color(0xFF7A5333),
};

const Map<CategoryColorKey, Color> _darkColors = <CategoryColorKey, Color>{
  CategoryColorKey.slate: Color(0xFFBDC9D6),
  CategoryColorKey.red: Color(0xFFFFB4A9),
  CategoryColorKey.orange: Color(0xFFFFB77C),
  CategoryColorKey.amber: Color(0xFFE8C449),
  CategoryColorKey.yellow: Color(0xFFD6CB4B),
  CategoryColorKey.lime: Color(0xFFBFE070),
  CategoryColorKey.green: Color(0xFF8FDBAA),
  CategoryColorKey.teal: Color(0xFF6FDBD1),
  CategoryColorKey.cyan: Color(0xFF6BD8E0),
  CategoryColorKey.blue: Color(0xFFAAC7FF),
  CategoryColorKey.indigo: Color(0xFFBFC6FF),
  CategoryColorKey.purple: Color(0xFFE2B8FF),
  CategoryColorKey.pink: Color(0xFFFFB0CB),
  CategoryColorKey.brown: Color(0xFFE3B584),
};

/// Stable order used only by [resolveCategoryColorKey]'s deterministic
/// fallback -- see that function's doc comment. NOT the display order for
/// a color picker (a picker should use [CategoryColorKey.values] or its
/// own deliberately-chosen order); this list exists purely so the fallback
/// hash has a fixed, never-reordered sequence to index into.
const List<CategoryColorKey> _fallbackOrder = CategoryColorKey.values;

/// The color to render for a category's persisted `colorKey` column,
/// given the category's own stable `id` for the fallback case. Never
/// throws.
///
/// - If [storedColorKey] names a recognized [CategoryColorKey], returns
///   that key's color for [isDark].
/// - Otherwise (a legacy row with `colorKey == null`, or a key this build
///   doesn't recognize) falls back to a color chosen deterministically
///   from [categoryId] -- the same category id always maps to the same
///   fallback color on every load, so a legacy category's color never
///   flickers or looks random across sessions, satisfying the checkpoint
///   brief's "deterministic (never random) visual identity, stable across
///   sessions" requirement without needing a backfill migration for every
///   pre-existing row.
Color categoryColorFor({required String categoryId, String? storedColorKey, required bool isDark}) {
  final CategoryColorKey key = resolveCategoryColorKey(categoryId: categoryId, storedColorKey: storedColorKey);
  final Map<CategoryColorKey, Color> palette = isDark ? _darkColors : _lightColors;
  return palette[key]!;
}

/// The [CategoryColorKey] [categoryColorFor] would use -- exposed
/// separately so a picker can show which named color is "currently in
/// effect" for a category that has never had one explicitly chosen, and
/// so [Categories.colorKey] can be written to the stable, deterministic
/// value the first time a user opens the color picker for a legacy
/// category, rather than the picker itself trying to redo this
/// computation independently.
CategoryColorKey resolveCategoryColorKey({required String categoryId, String? storedColorKey}) {
  final CategoryColorKey? stored = CategoryColorKey.fromStorageValue(storedColorKey);
  if (stored != null) return stored;
  final int index = categoryId.hashCode.abs() % _fallbackOrder.length;
  return _fallbackOrder[index];
}

/// The color for a color picker swatch representing [key] directly (the
/// user is choosing a key, not yet resolving a category's stored value) --
/// never throws, defaulting to [CategoryColorKey.slate] only if [key]
/// somehow isn't in the palette map (which cannot happen for any value in
/// [CategoryColorKey.values], but keeps this total rather than partial).
Color categoryColorForKey(CategoryColorKey key, {required bool isDark}) {
  final Map<CategoryColorKey, Color> palette = isDark ? _darkColors : _lightColors;
  return palette[key] ?? _lightColors[CategoryColorKey.slate]!;
}
