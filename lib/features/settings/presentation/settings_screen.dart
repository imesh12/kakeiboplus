import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/routing/app_routes.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/app_card.dart';
import '../../onboarding/presentation/profile_providers.dart';

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
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: <Widget>[
              AppCard(
                bordered: true,
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(profile.displayName, style: context.appTypography.cardTitle),
                  subtitle: Text(
                    l10n.profileLocationSummary(
                      profile.currentCountry,
                      profile.livingCurrency,
                      profile.homeCountry,
                      profile.homeCurrency,
                    ),
                    style: context.appTypography.secondaryBody,
                  ),
                ),
              ),
              AppCard(
                bordered: true,
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.account_balance_wallet_outlined),
                  title: Text(l10n.accountsSectionTitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.accounts),
                ),
              ),
              AppCard(
                bordered: true,
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.category_outlined),
                  title: Text(l10n.categoriesScreenTitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.categories),
                ),
              ),
              AppCard(
                bordered: true,
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.savings_outlined),
                  title: Text(l10n.budgetsTitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.budgets),
                ),
              ),
              AppCard(
                bordered: true,
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: Text(l10n.savingsGoalsTitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.goals),
                ),
              ),
              AppCard(
                bordered: true,
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.repeat_outlined),
                  title: Text(l10n.recurringTitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.recurring),
                ),
              ),
              AppCard(
                bordered: true,
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.public),
                  title: Text(l10n.internationalPreferences),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.internationalPreferences),
                ),
              ),
              // Checkpoint 8.1 (Premium Theme Personalization
              // Foundation): the entry point into the new Theme
              // Customization screen -- same AppCard+ListTile row
              // pattern every other Settings nav row above already
              // uses, so it never introduces a second row idiom.
              AppCard(
                bordered: true,
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: Text(l10n.appearanceSectionTitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.themeCustomization),
                ),
              ),
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
