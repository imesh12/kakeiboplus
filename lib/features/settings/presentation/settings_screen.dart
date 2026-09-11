import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/routing/app_routes.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../onboarding/presentation/profile_providers.dart';

/// The "Profile" destination — Beta 0 keeps this to a read-only profile
/// summary plus links to Accounts/Categories management. Editing
/// home/living currency, notification preferences, and privacy controls
/// (per `docs/00_MASTER_BLUEPRINT.md` §43) are Beta 1+ — none of that is
/// implemented yet, so this screen doesn't pretend it is.
///
/// Checkpoint 4.3 (International / Localization Foundation): only the
/// "International preferences" row's own label moves onto
/// `AppLocalizations` here -- every other row ("Profile" title,
/// Accounts/Categories/Budgets/Savings Goals/Recurring, the Beta 0
/// disclaimer) is out of this checkpoint's small proof surface and
/// stays an English literal.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ProfileRow?> profileAsync = ref.watch(activeProfileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace st) => Center(child: Text('Could not load profile: $e')),
        data: (ProfileRow? profile) {
          if (profile == null) return const SizedBox.shrink();
          return ListView(
            children: <Widget>[
              ListTile(
                title: Text(profile.displayName),
                subtitle: Text(
                  'Living in ${profile.currentCountry} (${profile.livingCurrency}) · '
                  'Home: ${profile.homeCountry} (${profile.homeCurrency})',
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: const Text('Accounts'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppRoutes.accounts),
              ),
              ListTile(
                leading: const Icon(Icons.category_outlined),
                title: const Text('Categories'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppRoutes.categories),
              ),
              ListTile(
                leading: const Icon(Icons.savings_outlined),
                title: const Text('Budgets'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppRoutes.budgets),
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Savings Goals'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppRoutes.goals),
              ),
              ListTile(
                leading: const Icon(Icons.repeat_outlined),
                title: const Text('Recurring'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppRoutes.recurring),
              ),
              ListTile(
                leading: const Icon(Icons.public),
                title: Text(AppLocalizations.of(context).internationalPreferences),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppRoutes.internationalPreferences),
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Beta 0 — local money engine. FX, receipts, notifications, '
                  'cloud sync, and AI coaching are not implemented yet.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
