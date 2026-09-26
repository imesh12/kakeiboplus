import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/finance/account_creation_kind.dart';
import '../../features/accounts/presentation/account_detail_screen.dart';
import '../../features/accounts/presentation/accounts_screen.dart';
import '../../features/accounts/presentation/add_account_form_screen.dart';
import '../../features/accounts/presentation/add_account_type_screen.dart';
import '../../features/accounts/presentation/edit_account_screen.dart';
import '../../features/budgets/presentation/budgets_screen.dart';
import '../../features/cloud_account/presentation/cloud_account_screen.dart';
import '../../features/categories/presentation/categories_screen.dart';
import '../../features/cheques/presentation/cheque_detail_screen.dart';
import '../../features/cheques/presentation/cheques_screen.dart';
import '../../features/settings/presentation/currency_converter_screen.dart';
import '../../features/dashboard/presentation/home_screen.dart';
import '../../features/goals/presentation/goal_detail_screen.dart';
import '../../features/goals/presentation/savings_goals_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/onboarding/presentation/profile_providers.dart';
import '../../features/recurring/presentation/recurring_screen.dart';
import '../../features/settings/presentation/international_preferences_screen.dart';
import '../../features/settings/presentation/more_screen.dart';
import '../../features/networth/presentation/net_worth_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/settings/presentation/theme_customization_screen.dart';
import '../../features/transactions/presentation/activity_screen.dart';
import '../../features/transactions/presentation/add_transaction_screen.dart';
import '../../features/transactions/presentation/edit_transaction_screen.dart';
import '../../features/transactions/presentation/transaction_detail_screen.dart';
import '../../shared/widgets/app_shell.dart';
import 'app_routes.dart';
import 'go_router_refresh_stream.dart';

/// The route tree: onboarding (outside the shell) plus the
/// Home/Activity/Accounts/More shell destinations -- V1 Navigation
/// Shell Implementation Checkpoint, implementing
/// `docs/22_UI_REFERENCE_PRODUCT_ARCHITECTURE.md` §26 / ADR-034.
/// `AccountsScreen` moved INTO the shell here (it is now a primary
/// destination, reached with the bottom nav visible, not a pushed
/// detail screen); `SettingsScreen` (Profile) moved OUT of the shell
/// (it is no longer a bottom-nav tab -- it is pushed from a row on
/// the new `MoreScreen`, exactly like Budgets/Goals/Recurring/
/// Categories/International Preferences/Theme Customization/Cloud
/// Account already were before this checkpoint). A Categories
/// screen, the shared Add Expense/Income/Transfer screen, a Budgets
/// screen (Beta 1 Task 2), and a Savings Goals list + detail screen
/// (Beta 1 Task 3 -- see `docs/14_DECISION_LOG.md` ADR-022) remain
/// pushed screens with no bottom-nav item of their own -- see
/// `STAGE1_BETA0_IMPLEMENTATION_PLAN.md` §9 for the original
/// navigation rationale this checkpoint's ADR-034 supersedes only
/// for Accounts/Profile/More. Checkpoint 8.1's Theme Customization
/// screen keeps the same no-new-bottom-nav-item pattern, now reached
/// from `MoreScreen` instead of `SettingsScreen`.
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
          // V1 Navigation Shell Implementation Checkpoint: Accounts
          // moved in from the top-level route list below -- same
          // path, same `AccountsScreen()` builder, so every existing
          // `context.push(AppRoutes.accounts)` call site (Home's
          // shortcut) keeps working unchanged; it now additionally
          // renders with the bottom nav visible, since Accounts is a
          // primary destination.
          GoRoute(path: AppRoutes.accounts, builder: (context, state) => const AccountsScreen()),
          // V1 Navigation Shell Implementation Checkpoint: the new
          // More destination, replacing Profile's former slot here.
          GoRoute(path: AppRoutes.more, builder: (context, state) => const MoreScreen()),
        ],
      ),
      GoRoute(
        path: AppRoutes.addTransaction,
        builder: (context, state) => AddTransactionScreen(
          initialType: state.uri.queryParameters['type'],
        ),
      ),
      // Registered AFTER `AppRoutes.addTransaction` above -- both are
      // 2-segment `/transactions/...` paths and GoRouter matches routes
      // in list order, so the literal `/transactions/add` must be tried
      // before the parameterized `/transactions/:id` or the latter
      // would swallow it.
      GoRoute(
        path: AppRoutes.transactionDetailPath,
        builder: (context, state) =>
            TransactionDetailScreen(transactionId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.editTransactionPath,
        builder: (context, state) =>
            EditTransactionScreen(transactionId: state.pathParameters['id']!),
      ),
      // Checkpoint G (Add Account UX): registered BEFORE
      // `AppRoutes.accountDetailPath` below -- both are 2-segment
      // `/accounts/...` paths, and GoRouter matches routes in list
      // order, so the literal `/accounts/add` must be tried before the
      // parameterized `/accounts/:id` or the latter would swallow it
      // (the same `addTransaction`-before-`transactionDetailPath`
      // precedent above). `addAccountFormPath` is a 3-segment path
      // (`/accounts/add/:kind`) and never collides with either
      // `/accounts/:id` or `/accounts/:id/edit`, so its own position
      // relative to those doesn't matter.
      GoRoute(
        path: AppRoutes.addAccount,
        builder: (context, state) => const AddAccountTypeScreen(),
      ),
      GoRoute(
        path: AppRoutes.addAccountFormPath,
        builder: (context, state) => AddAccountFormScreen(
          kind: AccountCreationKind.values.byName(state.pathParameters['kind']!),
        ),
      ),
      // V1 Accounts Detail + Edit Checkpoint: top-level siblings of
      // the `ShellRoute` above, exactly like the transaction/goal
      // detail+edit pairs immediately above -- `AppRoutes.accounts`
      // itself stays a shell destination; these two do not, so
      // `AppShell._currentIndex()`'s `startsWith(AppRoutes.accounts)`
      // check (only ever evaluated while `AppShell` is the active
      // ancestor) can't be triggered by either and the five-destination
      // shell is unaffected. Registered as `/accounts/:id` and
      // `/accounts/:id/edit` -- neither collides with the literal
      // `/accounts` path above, so, unlike `addTransaction` vs.
      // `transactionDetailPath`, order relative to it doesn't matter.
      GoRoute(
        path: AppRoutes.accountDetailPath,
        builder: (context, state) =>
            AccountDetailScreen(accountId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.editAccountPath,
        builder: (context, state) =>
            EditAccountScreen(accountId: state.pathParameters['id']!),
      ),
      // V1 Navigation Shell Implementation Checkpoint: Profile moved
      // in from the ShellRoute above -- same path, same
      // `SettingsScreen()` builder, unchanged deep link -- it is now
      // a pushed screen with no bottom nav of its own, same pattern
      // every route below it already used, reached from a row on
      // the new `MoreScreen` (`AppRoutes.profile`).
      GoRoute(path: AppRoutes.profile, builder: (context, state) => const SettingsScreen()),
      GoRoute(path: AppRoutes.categories, builder: (context, state) => const CategoriesScreen()),
      GoRoute(path: AppRoutes.budgets, builder: (context, state) => const BudgetsScreen()),
      GoRoute(path: AppRoutes.goals, builder: (context, state) => const SavingsGoalsScreen()),
      GoRoute(
        path: AppRoutes.goalDetailPath,
        builder: (context, state) => GoalDetailScreen(goalId: state.pathParameters['id']!),
      ),
      GoRoute(path: AppRoutes.recurring, builder: (context, state) => const RecurringScreen()),
      GoRoute(
        path: AppRoutes.internationalPreferences,
        builder: (context, state) => const InternationalPreferencesScreen(),
      ),
      GoRoute(
        path: AppRoutes.themeCustomization,
        builder: (context, state) => const ThemeCustomizationScreen(),
      ),
      GoRoute(
        path: AppRoutes.currencyConverter,
        builder: (context, state) => const CurrencyConverterScreen(),
      ),
      GoRoute(
        path: AppRoutes.cloudAccount,
        builder: (context, state) => const CloudAccountScreen(),
      ),
      GoRoute(
        path: AppRoutes.netWorth,
        builder: (context, state) => const NetWorthScreen(),
      ),
      GoRoute(path: AppRoutes.cheques, builder: (context, state) => const ChequesScreen()),
      GoRoute(
        path: AppRoutes.chequeDetailPath,
        builder: (context, state) => ChequeDetailScreen(chequeId: state.pathParameters['id']!),
      ),
    ],
  );
});
