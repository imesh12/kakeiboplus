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
  static const String categories = '/categories';
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
}
