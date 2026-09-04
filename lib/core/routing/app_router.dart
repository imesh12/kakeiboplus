import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/accounts/presentation/accounts_screen.dart';
import '../../features/budgets/presentation/budgets_screen.dart';
import '../../features/categories/presentation/categories_screen.dart';
import '../../features/dashboard/presentation/home_screen.dart';
import '../../features/goals/presentation/goal_detail_screen.dart';
import '../../features/goals/presentation/savings_goals_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/onboarding/presentation/profile_providers.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/transactions/presentation/activity_screen.dart';
import '../../features/transactions/presentation/add_transaction_screen.dart';
import '../../shared/widgets/app_shell.dart';
import 'app_routes.dart';
import 'go_router_refresh_stream.dart';

/// The route tree: onboarding (outside the shell) plus the
/// Home/Activity/Profile shell destinations, an Accounts screen, a
/// Categories screen, the shared Add Expense/Income/Transfer screen, a
/// Budgets screen (Beta 1 Task 2), and a Savings Goals list + detail
/// screen (Beta 1 Task 3 -- see `docs/14_DECISION_LOG.md` ADR-022).
/// Goals deliberately gets no new bottom-nav item, same as Budgets --
/// see `STAGE1_BETA0_IMPLEMENTATION_PLAN.md` §9 for the full navigation
/// rationale.
final Provider<GoRouter> routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: GoRouterRefreshStream(ref.watch(activeProfileProvider.stream)),
    redirect: (context, state) {
      final bool? hasProfile = ref.read(hasProfileProvider).valueOrNull;
      if (hasProfile == null) return null; // still loading — don't redirect yet
      final bool goingToOnboarding = state.matchedLocation == AppRoutes.onboarding;
      if (!hasProfile && !goingToOnboarding) return AppRoutes.onboarding;
      if (hasProfile && goingToOnboarding) return AppRoutes.home;
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: <RouteBase>[
          GoRoute(path: AppRoutes.home, builder: (context, state) => const HomeScreen()),
          GoRoute(path: AppRoutes.activity, builder: (context, state) => const ActivityScreen()),
          GoRoute(path: AppRoutes.profile, builder: (context, state) => const SettingsScreen()),
        ],
      ),
      GoRoute(
        path: AppRoutes.addTransaction,
        builder: (context, state) => AddTransactionScreen(
          initialType: state.uri.queryParameters['type'],
        ),
      ),
      GoRoute(path: AppRoutes.accounts, builder: (context, state) => const AccountsScreen()),
      GoRoute(path: AppRoutes.categories, builder: (context, state) => const CategoriesScreen()),
      GoRoute(path: AppRoutes.budgets, builder: (context, state) => const BudgetsScreen()),
      GoRoute(path: AppRoutes.goals, builder: (context, state) => const SavingsGoalsScreen()),
      GoRoute(
        path: AppRoutes.goalDetailPath,
        builder: (context, state) => GoalDetailScreen(goalId: state.pathParameters['id']!),
      ),
    ],
  );
});
