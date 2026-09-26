import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/theme/app_tokens.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_icon_tile.dart';
import '../../../shared/widgets/app_section_header.dart';

/// V1 Navigation Shell Implementation Checkpoint
/// (`docs/22_UI_REFERENCE_PRODUCT_ARCHITECTURE.md` §26 / ADR-034): the
/// new "More" primary destination, replacing Profile's former
/// bottom-nav slot. Organizes every existing tool/settings row that
/// used to live directly on `SettingsScreen` (Categories, Budgets,
/// Savings Goals, Recurring, International Preferences, Appearance,
/// Cloud Account) plus a new "Profile" row (Profile itself is NOT
/// removed from the app -- see that screen's own doc comment) into the
/// approved group hierarchy from §26.4:
///
/// Planning (Budgets, Savings Goals) / Recurring (Recurring) / Money
/// Tools (Currency Converter) / Organization (Categories) /
/// Personalization (Profile, International Preferences, Appearance) /
/// Cloud & Security (Cloud Account).
///
/// Deliberately reuses every existing route/screen -- no domain logic,
/// account balances, or money arithmetic changes. Accounts is
/// deliberately absent: it is now its own primary shell destination
/// (§26.4's own "Accounts is deliberately absent from this list" note),
/// not a More row.
///
/// # Canonical destinations deliberately OMITTED here
///
/// The approved architecture's canonical More hierarchy also lists
/// Insights (Money Tools), Exchange Rates (Money Tools -- it exists
/// only as an embedded `ReferenceRateCard`, with no dedicated
/// screen/route of its own), Notifications (Personalization), Sync,
/// Security, Privacy & Data (Cloud & Security), and About. None of
/// these has a real V1 screen or route in this repository today, so
/// none of them is rendered here -- adding a row for any of them would
/// be a dead link, which this checkpoint's own scope guardrails
/// explicitly forbid. "Recurring Transactions" and "Subscriptions" are
/// two tabs of the ONE existing `RecurringScreen`/`AppRoutes.recurring`
/// (no separate route for either), so they collapse into the single
/// existing "Recurring" row below rather than a second, non-functional
/// entry.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokens tokens = context.appTokens;
    final ColorScheme colors = Theme.of(context).colorScheme;

    // Same shared icon-led row idiom `SettingsScreen`'s nav rows used
    // before this checkpoint -- moved here unchanged in shape, only in
    // location.
    Widget navRow({
      required IconData icon,
      required Color color,
      required String title,
      required VoidCallback onTap,
    }) {
      return ListTile(
        leading: AppIconTile(icon: icon, color: color, size: AppIconTileSize.small),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      );
    }

    Widget navGroup(List<Widget> rows) {
      final List<Widget> children = <Widget>[];
      for (int i = 0; i < rows.length; i++) {
        if (i > 0) {
          children.add(Divider(height: 1, indent: 56, color: tokens.colors.subtleBorder));
        }
        children.add(rows[i]);
      }
      return AppCard(
        bordered: true,
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        padding: EdgeInsets.zero,
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      );
    }

    Widget sectionTitle(String title) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: AppSectionHeader(title: title, eyebrow: true),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navMore)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: <Widget>[
          // Checkpoint M: the one place in the app that shows the
          // full KakeiboPlus wordmark -- see docs/14_DECISION_LOG.md
          // ADR-036. Purely an identity header, not a nav row: no
          // onTap, no chevron. The wordmark PNG's ink is a FIXED
          // brand green, not theme-derived -- unlike every other
          // color on this screen it deliberately does NOT come from
          // `colorScheme` (that rule governs semantic UI color, not a
          // fixed imported brand asset), because on the Dark/Ocean/
          // Forest themes' own dark `colorScheme.surface` the
          // wordmark's dark-green lettering would be close to
          // unreadable. Wrapping it in a small fixed off-white card
          // keeps it legible and on-brand across all five themes, the
          // same way a logo badge stays on-brand regardless of a host
          // app's own theme.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Container(
              key: const Key('moreBrandHeader'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFFDFDFB),
                borderRadius: BorderRadius.circular(tokens.radii.medium),
                border: Border.all(color: tokens.colors.subtleBorder),
              ),
              child: Center(
                child: Semantics(
                  label: l10n.brandName,
                  image: true,
                  // Checkpoint M validation fix: `Image` itself wraps its
                  // `RawImage` in a second, internal `Semantics(image:
                  // true, label: '')` node unless told not to
                  // (`Image.excludeFromSemantics`'s own doc: "useful when
                  // the caller already provides a semanticLabel via a
                  // wrapping Semantics widget" -- exactly this case).
                  // That inner node was already inert -- the explicit
                  // label above is the only one a screen reader ever
                  // announced -- but it left a second, redundant
                  // `Semantics`-typed widget sitting in the tree for no
                  // reason, which is what made a structural
                  // `find.byType(Semantics)` finder here ambiguous.
                  // `excludeFromSemantics: true` on the `Image` below
                  // stops it from being created at all, so there is now
                  // exactly one `Semantics` widget in this subtree, both
                  // in the accessibility tree and in the widget tree a
                  // test walks.
                  child: Image.asset(
                    'assets/branding/kakeiboplus-wordmark.png',
                    height: 32,
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(l10n.moreScreenSubtitle, style: context.appTypography.secondaryBody),
          ),

          // Planning: Budgets, Savings Goals.
          sectionTitle(l10n.morePlanningSectionTitle),
          navGroup(<Widget>[
            navRow(
              icon: Icons.savings_outlined,
              color: _MoreRowColors.budgets,
              title: l10n.budgetsTitle,
              onTap: () => context.push(AppRoutes.budgets),
            ),
            navRow(
              icon: Icons.flag_outlined,
              color: _MoreRowColors.goals,
              title: l10n.savingsGoalsTitle,
              onTap: () => context.push(AppRoutes.goals),
            ),
          ]),

          // Recurring: the single existing Recurring screen (its own
          // Subscriptions tab lives inside it -- see class doc comment).
          sectionTitle(l10n.recurringTitle),
          navGroup(<Widget>[
            navRow(
              icon: Icons.repeat_outlined,
              color: _MoreRowColors.recurring,
              title: l10n.recurringTitle,
              onTap: () => context.push(AppRoutes.recurring),
            ),
          ]),

          // Money Tools: Currency Converter, Net Worth (Insights/Exchange
          // Rates omitted -- see class doc comment). Checkpoint J: Net
          // Worth is the ONLY way to reach `NetWorthScreen` -- Home
          // deliberately shows no net-worth figure (see
          // `home_screen.dart`'s doc comment) -- so this row is a
          // privacy boundary, not merely a convenience shortcut.
          sectionTitle(l10n.moreMoneyToolsSectionTitle),
          navGroup(<Widget>[
            navRow(
              icon: Icons.calculate_outlined,
              color: _MoreRowColors.currencyConverter,
              title: l10n.currencyConverterTitle,
              onTap: () => context.push(AppRoutes.currencyConverter),
            ),
            navRow(
              icon: Icons.account_balance_outlined,
              color: _MoreRowColors.netWorth,
              title: l10n.netWorthTitle,
              onTap: () => context.push(AppRoutes.netWorth),
            ),
          ]),

          // Organization: Categories.
          sectionTitle(l10n.moreOrganizationSectionTitle),
          navGroup(<Widget>[
            navRow(
              icon: Icons.category_outlined,
              color: _MoreRowColors.categories,
              title: l10n.categoriesScreenTitle,
              onTap: () => context.push(AppRoutes.categories),
            ),
          ]),

          // Personalization: Profile, International Preferences,
          // Appearance (Notifications omitted -- see class doc comment).
          sectionTitle(l10n.morePersonalizationSectionTitle),
          navGroup(<Widget>[
            navRow(
              icon: Icons.person_outline,
              color: colors.primary,
              title: l10n.navProfile,
              onTap: () => context.push(AppRoutes.profile),
            ),
            navRow(
              icon: Icons.public,
              color: _MoreRowColors.international,
              title: l10n.internationalPreferences,
              onTap: () => context.push(AppRoutes.internationalPreferences),
            ),
            navRow(
              icon: Icons.palette_outlined,
              color: _MoreRowColors.appearance,
              title: l10n.appearanceSectionTitle,
              onTap: () => context.push(AppRoutes.themeCustomization),
            ),
          ]),

          // Cloud & Security: Cloud Account (Sync/Security/Privacy &
          // Data omitted -- see class doc comment).
          sectionTitle(l10n.moreCloudSecuritySectionTitle),
          navGroup(<Widget>[
            navRow(
              icon: Icons.cloud_outlined,
              color: _MoreRowColors.cloudAccount,
              title: l10n.cloudAccountSectionTitle,
              onTap: () => context.push(AppRoutes.cloudAccount),
            ),
          ]),

          // About is omitted entirely -- no V1 screen/route exists for
          // it (see class doc comment); showing an empty or dead "About"
          // group would violate this checkpoint's no-dead-links rule.

          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l10n.beta0DisclaimerMessage,
              style: context.appTypography.caption,
            ),
          ),
        ],
      ),
    );
  }
}

/// Purely decorative per-row icon tints -- moved unchanged from
/// `SettingsScreen`'s former `_ProfileRowColors` (see that screen's
/// pre-checkpoint history for why a small fixed decorative palette is
/// the documented exceptional reason `financial-app-ui-ux-designer`'s
/// icon rules (§10-11) allow here, rather than a `ColorScheme` role).
/// `currencyConverter` is new -- a calm teal-blue distinct from every
/// other row's color, matching the calculator/reference-rate visual
/// language `currency_converter_screen.dart`/`reference_rate_card.dart`
/// already use elsewhere.
class _MoreRowColors {
  const _MoreRowColors._();

  static const Color categories = Color(0xFF9333EA);
  static const Color budgets = Color(0xFF16A34A);
  static const Color goals = Color(0xFFF59E0B);
  static const Color recurring = Color(0xFF6366F1);
  static const Color international = Color(0xFF0D9488);
  static const Color appearance = Color(0xFFDB2777);
  static const Color cloudAccount = Color(0xFF64748B);
  static const Color currencyConverter = Color(0xFF0EA5E9);
  static const Color netWorth = Color(0xFF7C3AED);
}
