/// Route path constants. Beta 0 only built the destinations it actually
/// had screens for — see `docs/14_DECISION_LOG.md` ADR-016/Decision 12:
/// no placeholder routes for a feature that doesn't have a screen yet.
/// `budgets` was added in Beta 1 Task 2, once the budgets feature had a
/// real screen to route to (see ADR-021); `goals`/`goalDetailPath` were
/// added in Beta 1 Task 3 for the same reason, once the savings goals
/// feature had real screens (see ADR-022). `recurring` was added in
/// Beta 1 Task 4A for the same reason, once the recurring money feature
/// had a real screen (see ADR-023). `fx`/`receipts` remain
/// unrouted -- still no screens.
abstract class AppRoutes {
  static const String onboarding = '/onboarding';
  static const String home = '/home';
  static const String activity = '/activity';
  static const String profile = '/profile';
  static const String accounts = '/accounts';

  /// Checkpoint G (Add Account UX, docs/20 §13.4): the icon-led
  /// account-type chooser -- the FAB on [accounts] now pushes here
  /// instead of opening the old `_AddAccountDialog`. Registered BEFORE
  /// [accountDetailPath] below in `app_router.dart` -- both are
  /// 2-segment `/accounts/...` paths, and GoRouter matches routes in
  /// list order, so the literal `/accounts/add` must be tried before
  /// the parameterized `/accounts/:id` or the latter would swallow it
  /// (the same `addTransaction`-before-`transactionDetailPath`
  /// precedent already established above).
  static const String addAccount = '/accounts/add';

  /// Path template for [GoRoute] registration -- see [addAccountForm]
  /// for building an actual navigable path for a specific
  /// `AccountCreationKind.name`. The adaptive Add Account form screen,
  /// reached by choosing a type on [addAccount].
  static const String addAccountFormPath = '/accounts/add/:kind';

  /// The path for the Add Account form for [kind] -- an
  /// `AccountCreationKind.name` string (e.g. `'cash'`, `'creditCard'`).
  static String addAccountForm(String kind) => '/accounts/add/$kind';

  /// Path template for [GoRoute] registration -- see [accountDetail] for
  /// building an actual navigable path for a specific account id. V1
  /// Accounts Detail + Edit Checkpoint. A pushed screen with no bottom
  /// nav of its own (same "list is a shell destination, detail is not"
  /// pattern [transactionDetailPath]/[goalDetailPath] already use), even
  /// though [accounts] itself is a shell destination.
  static const String accountDetailPath = '/accounts/:id';

  /// The path for one account's read-only detail screen.
  static String accountDetail(String id) => '/accounts/$id';

  /// Path template for [GoRoute] registration -- see [editAccount] for
  /// building an actual navigable path. Editing may not change an
  /// account's currency or opening balance -- see
  /// `AccountRepository.updateAccount`'s doc comment.
  static const String editAccountPath = '/accounts/:id/edit';

  /// The path for one account's edit screen.
  static String editAccount(String id) => '/accounts/$id/edit';

  static const String categories = '/categories';

  /// The "More" destination -- V1 Navigation Shell Implementation
  /// Checkpoint. Replaces `profile` as the shell's fourth primary
  /// bottom-navigation destination per
  /// `docs/22_UI_REFERENCE_PRODUCT_ARCHITECTURE.md` §26 / ADR-034
  /// (HOME / ACTIVITY / + ADD / ACCOUNTS / MORE). [profile] itself is
  /// unchanged below and remains a real, reachable route -- it is
  /// only removed from primary bottom navigation, reached instead as
  /// a pushed screen from a row on this new [more] destination.
  static const String more = '/more';
  static const String budgets = '/budgets';

  /// Query parameter `type` = `expense` | `income` | `transfer`.
  static const String addTransaction = '/transactions/add';

  /// Path template for [GoRoute] registration -- see [transactionDetail]
  /// for building an actual navigable path for a specific transaction
  /// id. Beta 1 Transaction UX (`docs/14_DECISION_LOG.md` ADR-025).
  static const String transactionDetailPath = '/transactions/:id';

  /// The path for one transaction's read-only detail screen.
  static String transactionDetail(String id) => '/transactions/$id';

  /// Path template for [GoRoute] registration -- see [editTransaction]
  /// for building an actual navigable path. Editing may not change a
  /// transaction's type -- see ADR-025.
  static const String editTransactionPath = '/transactions/:id/edit';

  /// The path for one transaction's edit screen.
  static String editTransaction(String id) => '/transactions/$id/edit';

  /// The savings goals list -- Beta 1 Task 3. See
  /// `docs/14_DECISION_LOG.md` ADR-022.
  static const String goals = '/goals';

  /// Path template for [GoRoute] registration -- see [goalDetail] for
  /// building an actual navigable path for a specific goal id.
  static const String goalDetailPath = '/goals/:id';

  /// The path for one goal's detail screen.
  static String goalDetail(String id) => '/goals/$id';

  /// The recurring rules list -- Beta 1 Task 4A. See
  /// `docs/14_DECISION_LOG.md` ADR-023.
  static const String recurring = '/recurring';

  /// International preference editing -- International / Localization
  /// Foundation Checkpoint 3B. Reached from the Profile/Settings screen.
  static const String internationalPreferences = '/international-preferences';

  /// The Theme Customization screen -- Checkpoint 8.1 (Premium Theme
  /// Personalization Foundation). Reached from the Profile/Settings
  /// screen's new "Appearance" row.
  static const String themeCustomization = '/theme-customization';

  /// The Currency Converter screen -- Checkpoint 9.6. Reached from
  /// International Preferences' Currency section, exactly like
  /// [internationalPreferences]/[themeCustomization] above are reached
  /// from Profile/Settings -- no new bottom-nav destination (see
  /// `docs/14_DECISION_LOG.md` ADR-028).
  static const String currencyConverter = '/currency-converter';

  /// The Cloud Account screen -- Checkpoint 12.2 (Cloud Identity / Auth
  /// Foundation). Reached from Profile/Settings' new "Cloud Account"
  /// row, same no-new-bottom-nav-destination pattern as
  /// [themeCustomization]/[currencyConverter] above.
  static const String cloudAccount = '/cloud-account';
}
