import '../../../l10n/generated/app_localizations.dart';
import 'category_icon.dart';

/// Checkpoint U1 (Category, Service, Currency & Card Visual Identity
/// Foundation): the localized display label shown next to each
/// [categoryIconKeys] entry in the category icon picker.
///
/// Deliberately a separate file from `category_icon.dart` -- that file's
/// own doc comment says it stays "pure and stateless -- no
/// `BuildContext`, no theme", and every existing call site
/// (`TransactionIconBadge`, `account_detail_screen.dart`) relies on
/// [categoryIconFor] never needing an [AppLocalizations] instance. This
/// file is the one place an icon KEY (not a category's resolved icon)
/// needs a user-facing name, so it lives on its own rather than pulling
/// a localization dependency into the shared resolver.
///
/// [categoryIconLabel] never throws: an icon key this build doesn't have
/// a label for (which cannot happen for any key in
/// [categoryIconKeys] today, but keeps this total rather than partial
/// against a future mismatch) falls back to [AppLocalizations.categoryIconOther]'s
/// generic "Other" label rather than crashing a picker that iterates
/// every key.
String categoryIconLabel(AppLocalizations l10n, String iconKey) {
  return switch (iconKey) {
    'shopping_cart' => l10n.categoryIconGroceries,
    'directions_bus' => l10n.categoryIconPublicTransport,
    'receipt_long' => l10n.categoryIconBillsUtilities,
    'restaurant' => l10n.categoryIconDiningOut,
    'local_hospital' => l10n.categoryIconHealth,
    'category' => l10n.categoryIconOther,
    'work' => l10n.categoryIconSalary,
    'attach_money' => l10n.categoryIconOtherIncome,
    'local_cafe' => l10n.categoryIconCoffeeCafe,
    'local_bar' => l10n.categoryIconBarsDrinks,
    'bakery_dining' => l10n.categoryIconBakery,
    'shopping_bag' => l10n.categoryIconShopping,
    'checkroom' => l10n.categoryIconClothing,
    'diamond' => l10n.categoryIconJewelryAccessories,
    'directions_car' => l10n.categoryIconCarFuel,
    'local_taxi' => l10n.categoryIconTaxiRideshare,
    'pedal_bike' => l10n.categoryIconBikeScooter,
    'flight' => l10n.categoryIconFlights,
    'home' => l10n.categoryIconRentHousing,
    'bolt' => l10n.categoryIconElectricity,
    'water_drop' => l10n.categoryIconWater,
    'wifi' => l10n.categoryIconInternetPhone,
    'build' => l10n.categoryIconRepairsMaintenance,
    'medication' => l10n.categoryIconPharmacyMedicine,
    'fitness_center' => l10n.categoryIconFitness,
    'spa' => l10n.categoryIconPersonalCare,
    'movie' => l10n.categoryIconMoviesEntertainment,
    'sports_esports' => l10n.categoryIconGames,
    'confirmation_number' => l10n.categoryIconEventsTickets,
    'celebration' => l10n.categoryIconCelebrations,
    'school' => l10n.categoryIconEducation,
    'menu_book' => l10n.categoryIconBooksLearning,
    'child_care' => l10n.categoryIconKids,
    'pets' => l10n.categoryIconPets,
    'luggage' => l10n.categoryIconTravel,
    'hotel' => l10n.categoryIconHotelsLodging,
    'account_balance' => l10n.categoryIconBankFees,
    'security' => l10n.categoryIconInsurance,
    'savings' => l10n.categoryIconSavingsInvestments,
    'credit_card' => l10n.categoryIconCardFees,
    'request_quote' => l10n.categoryIconTaxes,
    'card_giftcard' => l10n.categoryIconGifts,
    'volunteer_activism' => l10n.categoryIconDonationsCharity,
    'subscriptions' => l10n.categoryIconSubscriptions,
    'cloud' => l10n.categoryIconCloudStorage,
    'smart_toy' => l10n.categoryIconAiSoftware,
    'trending_up' => l10n.categoryIconInvestmentIncome,
    'storefront' => l10n.categoryIconBusinessIncome,
    'redeem' => l10n.categoryIconBonusReward,
    'more_horiz' => l10n.categoryIconMiscellaneous,
    _ => l10n.categoryIconOther,
  };
}
