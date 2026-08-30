import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/finance/ledger_models.dart';
import '../../../core/money/money.dart';
import '../../../core/money/money_formatter.dart';
import '../../../core/routing/app_routes.dart';
import '../../accounts/presentation/account_providers.dart';
import '../../onboarding/presentation/profile_providers.dart';
import 'dashboard_providers.dart';

const MoneyFormatter _formatter = MoneyFormatter();

/// Beta 0 Home dashboard: greeting, this month's income/expense (living
/// currency), account balances, and a jump to Accounts. The fuller vision
/// in `docs/00_MASTER_BLUEPRINT.md` §39 (goal progress, AI insight,
/// spending breakdown) is out of scope — those features don't exist yet
/// in Beta 0.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ProfileRow?> profileAsync = ref.watch(activeProfileProvider);
    final AsyncValue<List<AccountRow>> accountsAsync = ref.watch(accountsProvider);
    final AsyncValue<MoneyTotals> totalsAsync = ref.watch(currentMonthTotalsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace st) => Center(child: Text('Something went wrong: $e')),
        data: (ProfileRow? profile) {
          if (profile == null) {
            // Router redirect should prevent this, but keep the screen
            // safe on its own rather than crashing on a null profile.
            return const Center(child: CircularProgressIndicator());
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(activeProfileProvider);
              ref.invalidate(accountsProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                Text(
                  'Hi, ${profile.displayName}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                _MonthlyTotalsCard(totalsAsync: totalsAsync, livingCurrency: profile.livingCurrency),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text('Accounts', style: Theme.of(context).textTheme.titleMedium),
                    TextButton(
                      onPressed: () => context.push(AppRoutes.accounts),
                      child: const Text('Manage'),
                    ),
                  ],
                ),
                accountsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (Object e, StackTrace st) => Text('Could not load accounts: $e'),
                  data: (List<AccountRow> accounts) {
                    if (accounts.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('No accounts yet. Add one to start tracking.'),
                      );
                    }
                    return Column(
                      children: <Widget>[
                        for (final AccountRow account in accounts) _AccountTile(account: account),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MonthlyTotalsCard extends StatelessWidget {
  const _MonthlyTotalsCard({required this.totalsAsync, required this.livingCurrency});

  final AsyncValue<MoneyTotals> totalsAsync;
  final String livingCurrency;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: totalsAsync.when(
          loading: () => const SizedBox(
            height: 48,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (Object e, StackTrace st) => Text('Could not load totals: $e'),
          data: (MoneyTotals totals) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                _TotalColumn(label: 'Income this month', amount: totals.income),
                _TotalColumn(label: 'Spent this month', amount: totals.expense),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TotalColumn extends StatelessWidget {
  const _TotalColumn({required this.label, required this.amount});

  final String label;
  final Money amount;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(_formatter.format(amount), style: Theme.of(context).textTheme.titleLarge),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _AccountTile extends ConsumerWidget {
  const _AccountTile({required this.account});

  final AccountRow account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Money> balanceAsync = ref.watch(accountBalanceProvider(account.id));
    return Card(
      child: ListTile(
        title: Text(account.name),
        subtitle: Text(account.currencyCode),
        trailing: balanceAsync.when(
          loading: () => const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          error: (Object e, StackTrace st) => const Icon(Icons.error_outline),
          data: (Money balance) => Text(
            _formatter.format(balance),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ),
    );
  }
}
