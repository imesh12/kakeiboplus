/// Recurring UI Upgrade + History Views checkpoint: the two approved,
/// fixed-purpose artwork files for this feature --
/// `docs/design/app-icon/recurring/subscription-navy-mint.png` (the
/// summary card's leading icon) and
/// `docs/design/app-icon/recurring/paid-bill-stamp.png` (the "posted"
/// status stamp on a history row) -- copied into
/// `assets/icons/recurring/` under normalized names and registered in
/// `pubspec.yaml`. Neither source `docs/design` path is ever referenced
/// at runtime.
///
/// Unlike `service_icon_asset.dart`/`category_icon_asset.dart`/
/// `account_icon_asset.dart` (each a `String? resolverFor(key)` function
/// keyed off persisted domain data, because a service/category/account
/// can be any of several types), these two icons each have exactly one,
/// fixed, non-keyed purpose -- there is nothing to resolve. Plain
/// constants are the centralized, non-duplicated single source of
/// truth for both paths instead.
class RecurringIconAssets {
  const RecurringIconAssets._();

  /// The Recurring screen's summary card ("Monthly estimated total")
  /// leading icon.
  static const String subscriptionSummary = 'assets/icons/recurring/subscription_summary.png';

  /// The small status stamp shown next to a 'posted' history row. A
  /// 'skipped' row never uses this -- see `recurring_history_screen.dart`
  /// for the (Material-glyph, not bundled-art) skipped indicator, since
  /// no skipped-specific artwork was provided in this icon pack.
  static const String paidStamp = 'assets/icons/recurring/paid_stamp.png';
}
