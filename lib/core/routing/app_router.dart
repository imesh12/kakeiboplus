import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/accounts/presentation/accounts_screen.dart';
import '../../features/categories/presentation/categories_screen.dart';
import '../../features/dashboard/presentation/home_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/onboarding/presentation/profile_providers.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/transactions/presentation/activity_screen.dart';
import '../../features/transactions/presentation/add_transaction_screen.dart';
import '../../shared/widgets/app_shell.dart';
import 'app_routes.dart';
import 'go_router_refresh_stream.dart';

/// The Beta 0 route tree: onboarding (outside the shell) plus the
/// Home/Activity/Profile shell destinations, an Accounts screen, a
/// Categories screen, and the shared Add Expense/Income/Transfer screen.
/// See `docs/14_DECISION_LOG.md` ADR-015/Decision 12 for why there is no
/// Goals destination yet, and `STAGE1_BETA0_IMPLEMENTATION_PLAN.md` §9
/// for the full navigation rationale.
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
    ],
  );
});
