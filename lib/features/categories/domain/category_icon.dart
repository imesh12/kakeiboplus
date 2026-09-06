import 'package:flutter/material.dart';

/// Beta 1 Transaction UX Phase B (`docs/14_DECISION_LOG.md` ADR-025/026) --
/// maps a `Categories.icon` value (see `lib/core/database/tables.dart`)
/// to the concrete [IconData] to render for it.
///
/// `Categories.icon` already exists in the schema and is already
/// populated for every system category by
/// `CategoryRepository._systemCategories` -- no migration, no schema
/// change. This mapping is what was previously missing: nothing in the
/// app (Activity, the transaction detail screen, or `CategoriesScreen`
/// itself) has ever rendered it.
///
/// Pure and stateless -- no `BuildContext`, no theme, no dependency on
/// which screen renders it, so Activity, the detail screen, and (if
/// wanted later) `CategoriesScreen` can all share this one mapping
/// rather than each inventing their own. Every currently-seeded system
/// category name has an explicit entry; a name this map doesn't
/// recognize (a user-added category, or any future seed name this map
/// hasn't been updated for yet) and a `null` icon (a user-added category
/// that didn't set one) both fall back to [fallbackCategoryIcon] rather
/// than throwing or rendering nothing.

/// The icon shown for a category whose `icon` value is `null` or isn't
/// (yet) recognized by [categoryIconFor].
const IconData fallbackCategoryIcon = Icons.category;

/// One entry per name `CategoryRepository._systemCategories` currently
/// seeds. Keep this in sync if that seed list changes -- an unlisted
/// name safely falls back to [fallbackCategoryIcon] rather than
/// breaking, so falling behind by one entry is never a crash, only a
/// slightly-less-specific icon.
const Map<String, IconData> _categoryIconsByName = <String, IconData>{
  'shopping_cart': Icons.shopping_cart,
  'directions_bus': Icons.directions_bus,
  'receipt_long': Icons.receipt_long,
  'restaurant': Icons.restaurant,
  'local_hospital': Icons.local_hospital,
  'category': Icons.category,
  'work': Icons.work,
  'attach_money': Icons.attach_money,
};

/// The [IconData] to render for a category's `icon` column value.
/// Returns [fallbackCategoryIcon] for `null` or any unrecognized name.
IconData categoryIconFor(String? iconName) {
  if (iconName == null) return fallbackCategoryIcon;
  return _categoryIconsByName[iconName] ?? fallbackCategoryIcon;
}
