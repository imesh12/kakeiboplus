import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_routes.dart';
import '../../features/transactions/presentation/add_transaction_sheet.dart';
import '../../l10n/generated/app_localizations.dart';
import '../theme/app_tokens.dart';

/// The V1 navigation shell -- Home / Activity / Add / Accounts / More.
///
/// V1 Navigation Shell Implementation Checkpoint: implements the
/// approved five-destination primary navigation frozen by
/// `docs/22_UI_REFERENCE_PRODUCT_ARCHITECTURE.md` §26 and
/// `docs/14_DECISION_LOG.md` ADR-034, replacing the Beta 0 shell (Home /
/// Activity / Add / Profile -- see ADR-015 and Decision 12,
/// `STAGE1_BETA0_IMPLEMENTATION_PLAN.md` §9) this widget implemented
/// before this checkpoint. Accounts is promoted from a Profile-reached
/// detail screen into a primary destination; Profile is removed from
/// primary navigation but not from the app -- it remains a real,
/// reachable route (`AppRoutes.profile`), now pushed from a row on the
/// new More destination instead of being a bottom-nav tab itself (see
/// `more_screen.dart`). "Add" is still a center ACTION, not a routable
/// destination -- unchanged from every prior checkpoint.
class AppShell extends StatelessWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  /// V1 Navigation Shell Implementation Checkpoint: five destinations
  /// (0 Home, 1 Activity, 2 Add [action, never matched here], 3
  /// Accounts, 4 More). `AppRoutes.profile` is deliberately absent from
  /// this list -- it is no longer a ShellRoute child (see
  /// `app_router.dart`), so `GoRouterState.of(context).matchedLocation`
  /// is never `/profile` while this widget is actually mounted, exactly
  /// like every other pushed-on-top screen (Budgets, Goals, Recurring,
  /// Categories, International Preferences, ...) that was already true
  /// before this checkpoint.
  int _currentIndex(BuildContext context) {
    final String location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith(AppRoutes.activity)) return 1;
    if (location.startsWith(AppRoutes.accounts)) return 3;
    if (location.startsWith(AppRoutes.more)) return 4;
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
  /// built-in tap handling and semantics are untouched. Unchanged by the
  /// V1 Navigation Shell Implementation Checkpoint -- Add stays index 2,
  /// still an action, still exactly this same widget.
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
    // The five destination labels are ARB-backed
    // (`navHome`/`navActivity`/`navAdd`/`navAccounts`/`navMore` in
    // `lib/l10n/app_en.arb`/`app_ja.arb`), same pattern every prior
    // checkpoint already used for the four Beta 0 labels. `navProfile`
    // is untouched and still used by `SettingsScreen`'s own AppBar
    // title -- Profile just no longer appears on this bar.
    final AppLocalizations l10n = AppLocalizations.of(context);

    // Checkpoint 10 (Icon-Led UI Foundation): a hairline top border on the
    // nav bar -- matching the approved reference's subtle separation
    // between scrollable content and the bottom bar -- instead of the
    // heavier Material shadow `AppTheme`'s `navigationBarTheme` already
    // deliberately sets `elevation: 0` to avoid (see that theme's own
    // "restrained elevation everywhere" doc comment). Purely decorative:
    // unchanged by this checkpoint.
    final AppTokens tokens = context.appTokens;

    return Scaffold(
      body: child,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: tokens.colors.subtleBorder)),
        ),
        child: NavigationBar(
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
                context.go(AppRoutes.accounts);
              case 4:
                context.go(AppRoutes.more);
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
            // V1 Navigation Shell Implementation Checkpoint: Accounts
            // promoted to a primary destination -- same wallet glyph
            // `SettingsScreen`'s former Accounts row used, so the icon's
            // meaning carries over rather than being reinvented.
            NavigationDestination(
              icon: const Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: const Icon(Icons.account_balance_wallet),
              label: l10n.navAccounts,
            ),
            // V1 Navigation Shell Implementation Checkpoint: More
            // replaces Profile's former bottom-nav slot -- the
            // conventional "more/overflow" glyph, since this
            // destination is now a tool/settings directory (see
            // `more_screen.dart`) rather than a single person's profile.
            NavigationDestination(
              icon: const Icon(Icons.more_horiz_outlined),
              selectedIcon: const Icon(Icons.more_horiz),
              label: l10n.navMore,
            ),
          ],
        ),
      ),
    );
  }
}
