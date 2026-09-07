import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_routes.dart';
import '../../features/transactions/presentation/add_transaction_sheet.dart';

/// The Beta 0 navigation shell: Home / Activity / Add / Profile — see
/// `docs/14_DECISION_LOG.md` ADR-015 and Decision 12
/// (`STAGE1_BETA0_IMPLEMENTATION_PLAN.md` §9). No Goals destination yet;
/// "Add" opens a modal sheet rather than being its own screen.
///
/// Beta 1 Transaction UX Phase B, Checkpoint 6 gives the Add destination
/// a visually stronger circular tonal icon (see [_addIcon]) so it reads
/// as the primary action among the four. This is presentation-only:
/// `_currentIndex`, `onDestinationSelected`, and the destination count
/// are all unchanged from before this checkpoint -- Add remains index 2
/// and remains an action, never a routable destination.
class AppShell extends StatelessWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  int _currentIndex(BuildContext context) {
    final String location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith(AppRoutes.activity)) return 1;
    if (location.startsWith(AppRoutes.profile)) return 3;
    return 0;
  }

  /// The Add destination's icon, Checkpoint 6: the same Material icon
  /// passed in (`add_circle_outline` for unselected, `add_circle` for
  /// selected) inside a circular tonal container -- `ColorScheme` only,
  /// no hard-coded finance colors, no elevation/shadow. This is purely
  /// the widget passed to `NavigationDestination.icon`/`selectedIcon`;
  /// the bar's own built-in tap handling and semantics are untouched.
  Widget _addIcon(ColorScheme colors, IconData icon) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: colors.primaryContainer, shape: BoxShape.circle),
      child: Icon(icon, size: 27, color: colors.onPrimaryContainer),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex(context),
        onDestinationSelected: (int index) {
          switch (index) {
            case 0:
              context.go(AppRoutes.home);
            case 1:
              context.go(AppRoutes.activity);
            case 2:
              showAddTransactionSheet(context);
            case 3:
              context.go(AppRoutes.profile);
          }
        },
        destinations: <NavigationDestination>[
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Activity',
          ),
          NavigationDestination(
            icon: _addIcon(colors, Icons.add_circle_outline),
            selectedIcon: _addIcon(colors, Icons.add_circle),
            label: 'Add',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
