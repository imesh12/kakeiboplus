/// Route path constants. Beta 0 only built the destinations it actually
/// had screens for — see `docs/14_DECISION_LOG.md` ADR-016/Decision 12:
/// no placeholder routes for a feature that doesn't have a screen yet.
/// `budgets` was added in Beta 1 Task 2, once the budgets feature had a
/// real screen to route to (see ADR-021); `goals`/`goalDetailPath` were
/// added in Beta 1 Task 3 for the same reason, once the savings goals
/// feature had real screens (see ADR-022). `fx`/`receipts` remain
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

  /// The savings goals list -- Beta 1 Task 3. See
  /// `docs/14_DECISION_LOG.md` ADR-022.
  static const String goals = '/goals';

  /// Path template for [GoRoute] registration -- see [goalDetail] for
  /// building an actual navigable path for a specific goal id.
  static const String goalDetailPath = '/goals/:id';

  /// The path for one goal's detail screen.
  static String goalDetail(String id) => '/goals/$id';
}
