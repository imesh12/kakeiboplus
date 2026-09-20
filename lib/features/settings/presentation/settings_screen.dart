import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/routing/app_routes.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/theme/app_tokens.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_icon_tile.dart';
import '../../onboarding/presentation/profile_providers.dart';

/// Checkpoint 10 Visual Convergence Pass: purely DECORATIVE per-row icon
/// tints for this screen's navigation rows -- distinct from
/// [AppSemanticColors] (`app_tokens.dart`), which owns FINANCIAL meaning
/// (income/expense/warning) and must stay theme-derived. These rows carry
/// no financial meaning of their own (they're destinations, like
/// "Categories" or "Appearance"), so -- exactly like a transaction's
/// per-category icon color, or the approved reference's own
/// per-subscription brand colors (Netflix red, Spotify green) staying
/// fixed regardless of the active app theme -- a small fixed decorative
/// palette here is the "documented exceptional reason" the
/// `financial-app-ui-ux-designer` skill's icon rules (§10-11) allow,
/// rather than a `ColorScheme` role. Kept intentionally calm/desaturated
/// per that skill's visual-personality guidance (no neon).
class _ProfileRowColors {
  const _ProfileRowColors._();

  static const Color categories = Color(0xFF9333EA);

  /// Reuses `app_theme.dart`'s own "true success" green literal
  /// (`_forestPositiveGreen`) rather than inventing a second green
  /// constant -- the same color already means "healthy/positive" for
  /// budgets elsewhere in this app.
  static const Color budgets = Color(0xFF16A34A);
  static const Color goals = Color(0xFFF59E0B);
  static const Color recurring = Color(0xFF6366F1);
  static const Color international = Color(0xFF0D9488);

  /// Matches `AppTheme`'s own Pink theme seed -- fitting, since this row
  /// is literally the entry point to choosing that theme.
  static const Color appearance = Color(0xFFDB2777);

  /// Checkpoint 12.2 (Cloud Identity / Auth Foundation): a calm, neutral
  /// slate/blue -- deliberately NOT [budgets]' green or any other color
  /// that could read as a status/success signal on its own. This row's
  /// destination truthfully shows "unavailable" for almost every real
  /// user today (see `CloudAccountScreen`'s own doc); its icon tint
  /// should never look like a green checkmark promising something that
  /// isn't there yet.
  static const Color cloudAccount = Color(0xFF64748B);
}

/// The "Profile" destination — Beta 0 keeps this to a read-only profile
/// summary plus links to Accounts/Categories management. Editing
/// home/living currency, notification preferences, and privacy controls
/// (per `docs/00_MASTER_BLUEPRINT.md` §43) are Beta 1+ — none of that is
/// implemented yet, so this screen doesn't pretend it is.
///
/// Checkpoint 4.3 (International / Localization Foundation) localized only
/// the "International preferences" row's own label.
///
/// Checkpoint 6.8 (Localization Phase 1) finishes the rest of this
/// screen's static chrome: the AppBar title (reuses `navProfile` -- this
/// screen IS the app's "Profile" destination, so the existing nav-label
/// key already carries the exact text/meaning needed here), the error
/// message, the profile summary line (an interpolated sentence built
/// around the persisted, never-translated country/currency codes -- see
/// `profileLocationSummary`), every nav-row label (`Accounts`/
/// `Categories`/`Savings Goals`/`Recurring` reuse the same keys their own
/// destination screens' titles/Home's section headers already use --
/// `accountsSectionTitle`/`categoriesScreenTitle`/`savingsGoalsTitle`/
/// `recurringTitle` -- exact text and exact meaning; `Budgets` gets a new
/// `budgetsTitle` key since no existing plain-"Budgets" key exists), and
/// the Beta 0 disclaimer. `profile.displayName` (user-entered content)
/// is never translated.
///
/// Checkpoint 8.1 adds one more row, "Appearance", reached the exact
/// same way every other nav row already is -- it opens
/// `ThemeCustomizationScreen`, where the user picks one of the 5 product
/// themes (see `lib/shared/theme/app_theme_style.dart`).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ProfileRow?> profileAsync = ref.watch(activeProfileProvider);
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navProfile)),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace st) => Center(child: Text(l10n.couldNotLoadProfile('$e'))),
        data: (ProfileRow? profile) {
          if (profile == null) return const SizedBox.shrink();
          final AppTokens tokens = context.appTokens;
          final ColorScheme colors = Theme.of(context).colorScheme;

          // Checkpoint 10 Visual Convergence Pass: a shared row idiom for
          // every navigation row below -- an icon-led [ListTile] with no
          // per-row [AppCard] of its own, so several rows can share ONE
          // bordered card (see `navGroup` below) instead of each row
          // being its own separately-bordered box. Exact same
          // destinations/`onTap` behavior as before -- this only changes
          // how the rows are visually grouped and gives each one a
          // distinct tinted icon instead of a uniform monochrome one.
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

          // A single bordered card containing several rows, separated by
          // a hairline divider indented past the leading icon -- reduces
          // the previous "every row is its own outlined box" repetition
          // into fewer, clearer groups while keeping the exact same
          // [AppCard]-bordered contract (`colorScheme.surface` fill,
          // `tokens.colors.subtleBorder` outline) every existing test
          // already asserts for these rows.
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

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: <Widget>[
              // Checkpoint 10 Visual Convergence Pass: a premium-feeling
              // identity card -- a circular, primary-tinted avatar leading
              // the name/location summary, a soft shadow instead of a
              // plain outline, and the more generous hero-style radius --
              // instead of the plain bordered `ListTile` box every other
              // row also used before this pass. Same exact content
              // (`profile.displayName`, the unchanged
              // `profileLocationSummary` sentence) -- presentation only.
              AppCard(
                bordered: true,
                softShadow: true,
                radius: tokens.radii.large,
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.person, color: colors.primary, size: 26),
                    ),
                    SizedBox(width: tokens.spacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(profile.displayName, style: context.appTypography.cardTitle),
                          const SizedBox(height: 2),
                          Text(
                            l10n.profileLocationSummary(
                              profile.currentCountry,
                              profile.livingCurrency,
                              profile.homeCountry,
                              profile.homeCurrency,
                            ),
                            style: context.appTypography.secondaryBody,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              navGroup(<Widget>[
                navRow(
                  icon: Icons.account_balance_wallet_outlined,
                  color: colors.primary,
                  title: l10n.accountsSectionTitle,
                  onTap: () => context.push(AppRoutes.accounts),
                ),
                navRow(
                  icon: Icons.category_outlined,
                  color: _ProfileRowColors.categories,
                  title: l10n.categoriesScreenTitle,
                  onTap: () => context.push(AppRoutes.categories),
                ),
                navRow(
                  icon: Icons.savings_outlined,
                  color: _ProfileRowColors.budgets,
                  title: l10n.budgetsTitle,
                  onTap: () => context.push(AppRoutes.budgets),
                ),
                navRow(
                  icon: Icons.flag_outlined,
                  color: _ProfileRowColors.goals,
                  title: l10n.savingsGoalsTitle,
                  onTap: () => context.push(AppRoutes.goals),
                ),
                navRow(
                  icon: Icons.repeat_outlined,
                  color: _ProfileRowColors.recurring,
                  title: l10n.recurringTitle,
                  onTap: () => context.push(AppRoutes.recurring),
                ),
              ]),
              navGroup(<Widget>[
                navRow(
                  icon: Icons.public,
                  color: _ProfileRowColors.international,
                  title: l10n.internationalPreferences,
                  onTap: () => context.push(AppRoutes.internationalPreferences),
                ),
                // Checkpoint 8.1 (Premium Theme Personalization
                // Foundation): the entry point into the Theme
                // Customization screen -- same shared row idiom every
                // other Settings nav row above already uses.
                navRow(
                  icon: Icons.palette_outlined,
                  color: _ProfileRowColors.appearance,
                  title: l10n.appearanceSectionTitle,
                  onTap: () => context.push(AppRoutes.themeCustomization),
                ),
                // Checkpoint 12.2 (Cloud Identity / Auth Foundation):
                // the entry point into the Cloud Account screen -- same
                // shared row idiom every other Settings nav row above
                // already uses. See `CloudAccountScreen`'s own doc for
                // why this truthfully shows "unavailable" in every
                // production build today.
                navRow(
                  icon: Icons.cloud_outlined,
                  color: _ProfileRowColors.cloudAccount,
                  title: l10n.cloudAccountSectionTitle,
                  onTap: () => context.push(AppRoutes.cloudAccount),
                ),
              ]),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l10n.beta0DisclaimerMessage,
                  style: context.appTypography.caption,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
