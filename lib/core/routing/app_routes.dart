/// Route path constants for Beta 0. Only the destinations Beta 0 actually
/// builds — see `docs/14_DECISION_LOG.md` ADR-016/Decision 12: no
/// placeholder routes for budgets/goals/fx/receipts, which don't have
/// screens yet.
abstract class AppRoutes {
  static const String onboarding = '/onboarding';
  static const String home = '/home';
  static const String activity = '/activity';
  static const String profile = '/profile';
  static const String accounts = '/accounts';
  static const String categories = '/categories';

  /// Query parameter `type` = `expense` | `income` | `transfer`.
  static const String addTransaction = '/transactions/add';
}
