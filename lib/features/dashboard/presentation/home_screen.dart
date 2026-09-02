import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/money/money.dart';
import '../../../core/money/money_formatter.dart';
import '../../../core/routing/app_routes.dart';
import '../../accounts/presentation/account_providers.dart';
import '../../onboarding/presentation/profile_providers.dart';
import 'dashboard_providers.dart';

const MoneyFormatter _formatter = MoneyFormatter();

/// Beta 1 Home dashboard. Answers "am I okay with money?" at a glance:
/// a hero card for the primary (living) currency, smaller cards for any
/// other currency the user holds ([dashboardCurrencySummariesProvider]),
/// remaining monthly budget (empty state until Beta 1's budgets feature
/// exists), upcoming commitments (empty state until Beta 1's recurring
/// feature exists), and the existing per-account balance list.
///
/// This file is presentation only — every color comes from
/// `Theme.of(context).colorScheme` rather than a literal `Color(...)`,
/// so a future theme swap (this task's "theme-ready architecture" prep —
/// see `lib/shared/theme/app_theme.dart`) reskins this screen by
/// changing the seed color alone, with no widget-level changes needed.
///
/// The fuller vision in `docs/00_MASTER_BLUEPRINT.md` §39 (goal
/// progress, AI insight, spending breakdown) is still out of scope —
/// those features don't exist yet.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ProfileRow?> profileAsync = ref.watch(activeProfileProvider);
    final AsyncValue<List<AccountRow>> accountsAsync = ref.watch(accountsProvider);
    final AsyncValue<List<CurrencyDashboardSummary>> summariesAsync =
        ref.watch(dashboardCurrencySummariesProvider);

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
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              children: <Widget>[
                Text(
                  'Hi, ${profile.displayName}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 20),
                _CurrencySummarySection(
                  summariesAsync: summariesAsync,
                  livingCurrency: profile.livingCurrency,
                  homeCurrency: profile.homeCurrency,
                ),
                const SizedBox(height: 20),
                const _BudgetCard(),
                const SizedBox(height: 16),
                const _UpcomingCommitmentsCard(),
                const SizedBox(height: 28),
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
                const SizedBox(height: 4),
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

/// Renders the primary (first, per
/// [dashboardCurrencySummariesProvider]'s living-currency-first
/// ordering) currency as a prominent [_HeroCurrencyCard] and every other
/// currency the user holds as a smaller [_SecondaryCurrencyCard] — or an
/// empty state before any account exists. Deliberately never combines
/// currencies into a single figure; see that provider's doc comment for
/// why.
class _CurrencySummarySection extends StatelessWidget {
  const _CurrencySummarySection({
    required this.summariesAsync,
    required this.livingCurrency,
    required this.homeCurrency,
  });

  final AsyncValue<List<CurrencyDashboardSummary>> summariesAsync;
  final String livingCurrency;
  final String homeCurrency;

  String? _badgeFor(CurrencyDashboardSummary summary) {
    if (summary.currencyCode == livingCurrency) return 'Living currency';
    if (summary.currencyCode == homeCurrency) return 'Home currency';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return summariesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (Object e, StackTrace st) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Could not load your balances: $e'),
        ),
      ),
      data: (List<CurrencyDashboardSummary> summaries) {
        if (summaries.isEmpty) {
          return Card(
            elevation: 0,
            color: colors.surfaceContainerHigh,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: <Widget>[
                  Icon(Icons.account_balance_wallet_outlined, color: colors.primary),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Add an account to see your balance, income, and spending here.'),
                  ),
                ],
              ),
            ),
          );
        }
        final CurrencyDashboardSummary primary = summaries.first;
        final List<CurrencyDashboardSummary> secondary = summaries.skip(1).toList();
        return Column(
          children: <Widget>[
            _HeroCurrencyCard(summary: primary, badge: _badgeFor(primary)),
            for (final CurrencyDashboardSummary summary in secondary)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _SecondaryCurrencyCard(summary: summary, badge: _badgeFor(summary)),
              ),
          ],
        );
      },
    );
  }
}

/// A small rounded label — "Living currency" / "Home currency" — used on
/// both the hero and secondary currency cards. [prominent] switches
/// between the filled treatment used on the hero card and the quieter
/// container treatment used on secondary cards.
class _CurrencyBadge extends StatelessWidget {
  const _CurrencyBadge({required this.label, this.prominent = false});

  final String label;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color background = prominent ? colors.primary : colors.secondaryContainer;
    final Color foreground = prominent ? colors.onPrimary : colors.onSecondaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: foreground, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// The strongest element on the screen: the user's primary currency's
/// balance, large and unmissable, so "am I okay with money?" is
/// answerable within a few seconds.
///
/// Wrapped in a [Stack] — with only one layer today — specifically so a
/// future lightweight overlay (the animated companion mentioned in the
/// product backlog) can be added later as a sibling `Positioned` widget
/// without restructuring this card. No mascot code, assets, or
/// dependency is added by this task.
class _HeroCurrencyCard extends StatelessWidget {
  const _HeroCurrencyCard({required this.summary, this.badge});

  final CurrencyDashboardSummary summary;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final bool isNegative = summary.balance.isNegative;

    return Stack(
      children: <Widget>[
        Card(
          key: Key('heroCurrencyCard_${summary.currencyCode}'),
          elevation: 0,
          color: colors.primaryContainer,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.account_balance_wallet_rounded,
                            color: colors.onPrimaryContainer,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              summary.currencyCode,
                              style: text.titleMedium?.copyWith(
                                color: colors.onPrimaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (badge != null) _CurrencyBadge(label: badge!, prominent: true),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    if (isNegative)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(Icons.south_rounded, color: colors.error, size: 22),
                      ),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _formatter.format(summary.balance),
                          style: text.headlineMedium?.copyWith(
                            color: isNegative ? colors.error : colors.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Total available balance',
                  style: text.bodyMedium?.copyWith(color: colors.onPrimaryContainer),
                ),
                const SizedBox(height: 18),
                _MonthlyMetricsSection(
                  summary: summary,
                  emphasize: true,
                  tint: colors.onPrimaryContainer,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A currency the user holds beyond their primary one — same figures as
/// [_HeroCurrencyCard], visually distinct but deliberately less
/// dominant. Never summed with the hero card's currency.
class _SecondaryCurrencyCard extends StatelessWidget {
  const _SecondaryCurrencyCard({required this.summary, this.badge});

  final CurrencyDashboardSummary summary;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final bool isNegative = summary.balance.isNegative;

    return Card(
      key: Key('secondaryCurrencyCard_${summary.currencyCode}'),
      elevation: 0,
      color: colors.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Flexible(
                  child: Text(
                    summary.currencyCode,
                    style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (badge != null) _CurrencyBadge(label: badge!),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                if (isNegative)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(Icons.south_rounded, color: colors.error, size: 16),
                  ),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _formatter.format(summary.balance),
                      style: text.titleLarge?.copyWith(
                        color: isNegative ? colors.error : colors.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Text('Total available balance', style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
            const SizedBox(height: 12),
            _MonthlyMetricsSection(summary: summary, emphasize: false),
          ],
        ),
      ),
    );
  }
}

/// Income / Spending / Daily-pace, given room to breathe. Income and
/// Spending sit side by side on a normal-width screen and stack
/// vertically on a narrow one (see [LayoutBuilder] below) rather than
/// ever forcing three values into one cramped row; Daily Spending Pace
/// always gets its own full-width tile underneath.
///
/// [tint] overrides every value/label/icon color with a single color
/// (used on the hero card, which sits on a filled `primaryContainer`
/// background) — omitted on secondary cards, which use the default
/// on-surface colors instead. The underlying calculations are untouched;
/// this widget only formats and lays out what
/// [dashboardCurrencySummariesProvider] already computed.
class _MonthlyMetricsSection extends StatelessWidget {
  const _MonthlyMetricsSection({required this.summary, required this.emphasize, this.tint});

  final CurrencyDashboardSummary summary;
  final bool emphasize;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final TextStyle? valueStyle = (emphasize ? textTheme.titleLarge : textTheme.titleMedium)
        ?.copyWith(fontWeight: FontWeight.w700, color: tint);
    final TextStyle? labelStyle = textTheme.bodySmall?.copyWith(
      color: tint ?? colors.onSurfaceVariant,
    );

    final Widget incomeTile = _MetricTile(
      icon: Icons.trending_up_rounded,
      iconColor: tint ?? colors.primary,
      label: 'Income this month',
      value: summary.income,
      valueStyle: valueStyle,
      labelStyle: labelStyle,
    );
    final Widget spendTile = _MetricTile(
      icon: Icons.trending_down_rounded,
      iconColor: tint ?? colors.error,
      label: 'Spent this month',
      value: summary.expense,
      valueStyle: valueStyle,
      labelStyle: labelStyle,
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // Below ~320 logical px of content width, two side-by-side
        // metric tiles compress into unreadable, colliding text (the
        // problem this polish pass exists to fix) -- stack them instead
        // of forcing a fixed-width row. `Expanded` only appears in the
        // wide-layout Row: reusing it inside the narrow Column would hit
        // Flutter's "unbounded height" `RenderFlex` error, since a
        // `Column` inside a `Card`/`ListView` sizes to its content
        // rather than offering a bounded height to expand into.
        final bool narrow = constraints.maxWidth < 320;
        final Widget incomeSpendRow = narrow
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[incomeTile, const SizedBox(height: 12), spendTile],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: incomeTile),
                  const SizedBox(width: 12),
                  Expanded(child: spendTile),
                ],
              );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            incomeSpendRow,
            const SizedBox(height: 12),
            _MetricTile(
              icon: Icons.calendar_today_rounded,
              iconColor: tint ?? colors.tertiary,
              label: 'Daily spending pace',
              secondaryLabel: 'Average spend per day so far this month',
              value: summary.dailyPace,
              valueStyle: valueStyle,
              labelStyle: labelStyle,
              wide: true,
            ),
          ],
        );
      },
    );
  }
}

/// One labeled money value with a leading icon, optionally with a small
/// secondary explanation line underneath. The value is wrapped in a
/// [FittedBox] so a large formatted amount shrinks to fit rather than
/// clipping or overflowing on a narrow screen.
class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.secondaryLabel,
    this.valueStyle,
    this.labelStyle,
    this.wide = false,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final Money value;
  final String? secondaryLabel;
  final TextStyle? valueStyle;
  final TextStyle? labelStyle;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 6),
            Flexible(child: Text(label, style: labelStyle, overflow: TextOverflow.ellipsis)),
          ],
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(_formatter.format(value), style: valueStyle),
        ),
        if (secondaryLabel != null) ...<Widget>[
          const SizedBox(height: 2),
          Text(
            secondaryLabel!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: labelStyle?.color),
          ),
        ],
      ],
    );
    return wide ? SizedBox(width: double.infinity, child: content) : content;
  }
}

/// "Remaining monthly budget" tile. Beta 0/1 has no budgets feature yet
/// (`lib/features/budgets/README.md`) — [monthlyBudgetSummaryProvider]
/// always reports "not configured" today, so this always shows the
/// polished empty state (icon, explanation, and a disabled
/// "Set a monthly budget" call-to-action) rather than a number. The
/// button is intentionally `onPressed: null` -- there is no budgets flow
/// to open yet; wiring it up is Beta 1's budgets task, not this
/// UI-polish pass. Once that feature exists, the provider starts
/// returning a real remaining amount and this widget needs no change.
class _BudgetCard extends ConsumerWidget {
  const _BudgetCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MonthlyBudgetSummary budget = ref.watch(monthlyBudgetSummaryProvider);
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      color: colors.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.savings_outlined, color: colors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Remaining monthly budget',
                    style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (budget.remaining == null) ...<Widget>[
              Text(
                "You haven't set a monthly budget yet. Set one to see how much you have left to spend.",
                style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Set a monthly budget'),
              ),
            ] else
              Text(
                _formatter.format(budget.remaining!),
                style: text.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
          ],
        ),
      ),
    );
  }
}

/// "Upcoming commitments" tile. Beta 0/1 has no recurring-transactions
/// feature yet (`lib/features/recurring/README.md`) —
/// [upcomingCommitmentsProvider] always reports an empty list today, so
/// this always shows the polished empty state. Once that feature
/// exists, this widget renders whatever it returns without needing to
/// change.
class _UpcomingCommitmentsCard extends ConsumerWidget {
  const _UpcomingCommitmentsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<UpcomingCommitmentSummary> commitments = ref.watch(upcomingCommitmentsProvider);
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      color: colors.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.event_note_outlined, color: colors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Upcoming commitments',
                    style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (commitments.isEmpty) ...<Widget>[
              Text('No upcoming commitments yet.', style: text.bodyMedium),
              const SizedBox(height: 4),
              Text(
                'Recurring bills and scheduled payments will appear here.',
                style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ] else
              for (final UpcomingCommitmentSummary commitment in commitments)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Flexible(
                        child: Text(commitment.label, overflow: TextOverflow.ellipsis),
                      ),
                      Text(_formatter.format(commitment.amount)),
                    ],
                  ),
                ),
          ],
        ),
      ),
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
