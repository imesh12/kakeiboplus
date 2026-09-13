import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_routes.dart';
import '../../features/transactions/presentation/add_transaction_sheet.dart';
import '../../l10n/generated/app_localizations.dart';

/// The Beta 0 navigation shell: Home / Activity / Add / Profile — see
/// `docs/14_DECISION_LOG.md` ADR-015 and Decision 12
/// (`STAGE1_BETA0_IMPLEMENTATION_PLAN.md` §9). No Goals destination yet;
/// "Add" opens a modal sheet rather than being its own screen.
///
/// Beta 1 Transaction UX Phase B, Checkpoint 6 gave the Add destination
/// a visually stronger circular tonal icon; Visual System Convergence
/// Checkpoint 7.2 takes this further, converging on the approved Claude
/// Design reference's raised, solid-color, floating-looking Add button
/// (see [_addIcon]) -- larger, filled with `colorScheme.primary` rather
/// than the softer tonal `primaryContainer`, genuinely elevated via a
/// [Material] with non-zero `elevation`, and nudged upward with
/// [Transform.translate] so it visually "pops" above the bar line. This
/// is STILL presentation-only: `_currentIndex`, `onDestinationSelected`,
/// and the destination count are all unchanged from before either
/// checkpoint -- Add remains index 2, remains an action rather than a
/// routable destination, and is still exactly the widget passed to
/// `NavigationDestination.icon`/`selectedIcon`, so the bar's own
/// semantics/tap-target/RTL-mirroring behavior (already proven by
/// `app_shell_test.dart`'s CP5.5/CP5.6/CP6.1 groups) is untouched --
/// `Transform.translate` only repaints (and re-hit-tests) this one
/// child, it doesn't change the destination's own layout box, so tapping
/// "Add" anywhere in its destination area keeps working exactly as
/// before.
class AppShell extends StatelessWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  int _currentIndex(BuildContext context) {
    final String location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith(AppRoutes.activity)) return 1;
    if (location.startsWith(AppRoutes.profile)) return 3;
    return 0;
  }

  /// The Add destination's icon. Visual System Convergence Checkpoint
  /// 7.2: the same Material icon passed in (`add_circle_outline` for
  /// unselected, `add_circle` for selected) inside a larger, solid
  /// `colorScheme.primary` circle with real elevation, nudged upward so
  /// it visually floats above the bar line -- matching the approved
  /// Claude Design reference's raised center Add button. `ColorScheme`
  /// only, still no hard-coded finance colors. This is purely the widget
  /// passed to `NavigationDestination.icon`/`selectedIcon`; the bar's own
  /// built-in tap handling and semantics are untouched.
  Widget _addIcon(ColorScheme colors, IconData icon) {
    return Transform.translate(
      offset: const Offset(0, -10),
      child: Material(
        color: colors.primary,
        shape: const CircleBorder(),
        elevation: 4,
        shadowColor: colors.shadow,
        child: SizedBox(
          width: 56,
          height: 56,
          child: Center(child: Icon(icon, size: 30, color: colors.onPrimary)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    // CP6.1 (Localization Phase 1): the four destination labels are now
    // ARB-backed (`navHome`/`navActivity`/`navAdd`/`navProfile` in
    // `lib/l10n/app_en.arb`/`app_ja.arb`) instead of literal English --
    // Japanese becomes a real end-to-end proof language for the shell
    // itself. Routing/selection logic above (`_currentIndex`,
    // `onDestinationSelected`) is untouched: only the `label:` strings
    // change per locale.
    final AppLocalizations l10n = AppLocalizations.of(context);

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
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l10n.navHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.receipt_long_outlined),
            selectedIcon: const Icon(Icons.receipt_long),
            label: l10n.navActivity,
          ),
          NavigationDestination(
            icon: _addIcon(colors, Icons.add_circle_outline),
            selectedIcon: _addIcon(colors, Icons.add_circle),
            label: l10n.navAdd,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: l10n.navProfile,
          ),
        ],
      ),
    );
  }
}
