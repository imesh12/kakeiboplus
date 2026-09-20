import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/theme/app_tokens.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/app_card.dart';
import '../../onboarding/presentation/profile_providers.dart';

/// The "Profile" destination — a read-only local profile summary.
///
/// V1 Navigation Shell Implementation Checkpoint
/// (`docs/22_UI_REFERENCE_PRODUCT_ARCHITECTURE.md` §26 / ADR-034):
/// Profile is no longer a primary bottom-nav destination -- it is now
/// reached as a pushed screen from a row on the new `MoreScreen`. This
/// checkpoint also moves every nav row this screen used to show
/// (Accounts, Categories, Budgets, Savings Goals, Recurring,
/// International Preferences, Appearance, Cloud Account) and the Beta 0
/// disclaimer onto `MoreScreen` instead -- Accounts is now its own
/// primary shell destination rather than a Profile row, and the rest
/// are organized there under the approved Planning / Recurring / Money
/// Tools / Organization / Personalization / Cloud & Security groups
/// (§26.4). This screen therefore now shows ONLY the identity card
/// (display name + location/currency summary) it always had -- no
/// content, financial or otherwise, was deleted, only relocated. See
/// `more_screen.dart` and `more_screen_test.dart` for that moved
/// coverage.
///
/// Editing home/living currency, notification preferences, and privacy
/// controls (per `docs/00_MASTER_BLUEPRINT.md` §43) remain Beta 1+ --
/// none of that is implemented yet, so this screen doesn't pretend it
/// is.
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

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: <Widget>[
              // Checkpoint 10 Visual Convergence Pass: a premium-feeling
              // identity card -- a circular, primary-tinted avatar leading
              // the name/location summary, a soft shadow instead of a
              // plain outline, and the more generous hero-style radius.
              // Unchanged by the V1 Navigation Shell Implementation
              // Checkpoint -- same exact content
              // (`profile.displayName`, the unchanged
              // `profileLocationSummary` sentence).
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
            ],
          );
        },
      ),
    );
  }
}
