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
///
/// # Checkpoint U1 (Category, Service, Currency & Card Visual Identity
/// Foundation) addition
///
/// This map is now also the curated ~50-concept icon catalog the
/// checkpoint brief asks for -- there is deliberately only ONE map from
/// a stable string key to an [IconData] in this codebase, reused for
/// both "resolve a stored value" ([categoryIconFor], unchanged) and
/// "list the choices a picker offers" ([categoryIconKeys], new). Adding
/// a picker UI must never fork a second, potentially-inconsistent
/// key/icon list. See `category_icon_catalog.dart` for the localized
/// label shown next to each key in that picker -- kept in a separate
/// file specifically so this one stays free of any `AppLocalizations`/
/// `BuildContext` dependency, per the "pure and stateless" contract
/// above.
///
/// Every one of the 8 keys this map had before Checkpoint U1 keeps its
/// exact original [IconData] -- no existing category's rendered icon
/// changes as a side effect of this catalog's expansion.

/// The icon shown for a category whose `icon` value is `null` or isn't
/// (yet) recognized by [categoryIconFor].
const IconData fallbackCategoryIcon = Icons.category;

/// The curated category icon catalog. One entry per concept spanning
/// Food & Dining through Miscellaneous/Other -- deliberately a small,
/// hand-picked ~50-entry set (per the checkpoint brief's own "not dozens
/// of nearly indistinguishable icons" guidance), not an exhaustive dump
/// of every `Icons.*` constant that could vaguely apply. The first 8
/// entries are the pre-existing system-category seed icons
/// (`CategoryRepository._systemCategories`); keep those in sync if that
/// seed list ever changes. Every other entry is available for a user
/// to pick for a custom category, or to re-pick for a system one, via
/// the category icon picker (`category_icon_catalog.dart`).
const Map<String, IconData> _categoryIconsByName = <String, IconData>{
  // Pre-existing system-category seed icons -- unchanged.
  'shopping_cart': Icons.shopping_cart,
  'directions_bus': Icons.directions_bus,
  'receipt_long': Icons.receipt_long,
  'restaurant': Icons.restaurant,
  'local_hospital': Icons.local_hospital,
  'category': Icons.category,
  'work': Icons.work,
  'attach_money': Icons.attach_money,
  // Food & Dining.
  'local_cafe': Icons.local_cafe,
  'local_bar': Icons.local_bar,
  'bakery_dining': Icons.bakery_dining,
  // Shopping.
  'shopping_bag': Icons.shopping_bag,
  'checkroom': Icons.checkroom,
  'diamond': Icons.diamond,
  // Transport.
  'directions_car': Icons.directions_car,
  'local_taxi': Icons.local_taxi,
  'pedal_bike': Icons.pedal_bike,
  'flight': Icons.flight,
  // Housing & bills.
  'home': Icons.home,
  'bolt': Icons.bolt,
  'water_drop': Icons.water_drop,
  'wifi': Icons.wifi,
  'build': Icons.build,
  // Health & personal care.
  'medication': Icons.medication,
  'fitness_center': Icons.fitness_center,
  'spa': Icons.spa,
  // Entertainment & leisure.
  'movie': Icons.movie,
  'sports_esports': Icons.sports_esports,
  'confirmation_number': Icons.confirmation_number,
  'celebration': Icons.celebration,
  // Education.
  'school': Icons.school,
  'menu_book': Icons.menu_book,
  // Family & pets.
  'child_care': Icons.child_care,
  'pets': Icons.pets,
  // Travel.
  'luggage': Icons.luggage,
  'hotel': Icons.hotel,
  // Finance, fees & insurance.
  'account_balance': Icons.account_balance,
  'security': Icons.security,
  'savings': Icons.savings,
  'credit_card': Icons.credit_card,
  'request_quote': Icons.request_quote,
  // Gifts & giving.
  'card_giftcard': Icons.card_giftcard,
  'volunteer_activism': Icons.volunteer_activism,
  // Subscriptions & digital services.
  'subscriptions': Icons.subscriptions,
  'cloud': Icons.cloud,
  'smart_toy': Icons.smart_toy,
  // Income.
  'trending_up': Icons.trending_up,
  'storefront': Icons.storefront,
  'redeem': Icons.redeem,
  // Miscellaneous.
  'more_horiz': Icons.more_horiz,
};

/// The [IconData] to render for a category's `icon` column value.
/// Returns [fallbackCategoryIcon] for `null` or any unrecognized name.
IconData categoryIconFor(String? iconName) {
  if (iconName == null) return fallbackCategoryIcon;
  return _categoryIconsByName[iconName] ?? fallbackCategoryIcon;
}

/// Every key [categoryIconFor] recognizes, in the catalog's own stable
/// declaration order -- what a category icon picker iterates over. A
/// `List`, not the `Map` itself, so a picker can render a fixed-order
/// grid without also exposing (or being able to mutate) the resolution
/// map.
final List<String> categoryIconKeys = List<String>.unmodifiable(_categoryIconsByName.keys);
