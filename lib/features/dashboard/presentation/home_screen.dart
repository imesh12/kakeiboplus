import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/money/money.dart';
import '../../../core/money/money_formatter.dart';
import '../../../core/routing/app_routes.dart';
import '../../accounts/presentation/account_providers.dart';
import '../../budgets/domain/budget_calculation.dart';
import '../../budgets/domain/budget_status.dart';
import '../../goals/domain/savings_goal_calculation.dart';
import '../../goals/domain/savings_goal_status.dart';
import '../../goals/presentation/savings_goal_providers.dart';
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
                const _SavingsGoalsCard(),
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

/// "Remaining monthly budget" tile. Reads [monthlyBudgetSummaryProvider]
/// (see `dashboard_providers.dart` and Beta 1 Task 2 --
/// `docs/14_DECISION_LOG.md` ADR-021). Shows the polished empty state
/// (icon, explanation, "Set a monthly budget" call-to-action -- now
/// routes to the budgets screen) when no overall budget is configured
/// for the living currency this month, or the real
/// budgeted/spent/remaining figures, a progress bar, a deterministic
/// status label, and the recommended daily spend for the rest of the
/// month once one is. Never fabricates a number for the empty state --
/// see the Beta 1 Task 1 spec's ban on fake financial values, which
/// still applies.
class _BudgetCard extends ConsumerWidget {
  const _BudgetCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MonthlyBudgetSummary budget = ref.watch(monthlyBudgetSummaryProvider);
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final BudgetCalculation? calculation = budget.calculation;

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
                if (calculation != null)
                  TextButton(
                    key: const Key('manageBudgetsButton'),
                    onPressed: () => context.push(AppRoutes.budgets),
                    child: const Text('Manage'),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (calculation == null) ...<Widget>[
              Text(
                "You haven't set a monthly budget yet. Set one to see how much you have left to spend.",
                style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => context.push(AppRoutes.budgets),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Set a monthly budget'),
              ),
            ] else
              _ConfiguredBudget(calculation: calculation),
          ],
        ),
      ),
    );
  }
}

/// The configured (budget-exists) contents of [_BudgetCard]: remaining
/// vs. budgeted, a progress bar, a deterministic status chip, the
/// textual percentage used, and (when defined -- see
/// `BudgetCalculator.evaluate`) the recommended daily spend for the rest
/// of the month.
///
/// Percentage-used rules (see `docs/14_DECISION_LOG.md` ADR-021): the
/// **text** always shows the true, uncapped ratio -- an overspent budget
/// reads as e.g. "142% used", never silently hidden behind a false
/// "100%". Only the progress bar's fill fraction is clamped to 100%,
/// purely because a progress bar cannot visually render past full; the
/// over-budget state stays explicit via the status chip and the (still
/// uncapped) percentage text right next to it.
class _ConfiguredBudget extends StatelessWidget {
  const _ConfiguredBudget({required this.calculation});

  final BudgetCalculation calculation;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;

    final Money remaining = calculation.remaining;
    final Money budgeted = calculation.budgeted;
    final Money spent = calculation.spent;
    final BudgetStatus? status = calculation.status;

    // Presentation-only ratio -- never authoritative Money, never fed
    // back into any calculation. budgeted is always strictly positive
    // (BudgetRepository rejects zero/negative amounts before they can
    // ever be persisted), so this never divides by zero.
    final double ratio = spent.minorUnits / budgeted.minorUnits;
    final int percentUsed = (ratio * 100).round();

    final (Color statusColor, String statusLabel) = switch (status) {
      BudgetStatus.healthy => (colors.primary, 'On track'),
      BudgetStatus.caution => (colors.tertiary, 'Ahead of pace'),
      BudgetStatus.overBudget => (colors.error, 'Over budget'),
      null => (colors.onSurfaceVariant, 'This month'),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // A `Wrap`, not a `Row` -- at narrow widths (see the 320px test in
        // `test/widget/home_screen_test.dart`) the remaining amount plus
        // "of <budgeted>" can be wider than the card, and neither figure
        // may be clipped, ellipsized, or shrunk to stay readable. `Wrap`
        // renders them on one line whenever they fit (identical to the
        // previous `Row` on a normal-width phone) and drops "of
        // <budgeted>" to its own line, still fully legible, only when
        // they don't.
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 8,
          runSpacing: 2,
          children: <Widget>[
            Text(
              _formatter.format(remaining),
              style: text.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: remaining.isNegative ? colors.error : null,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                'of ${_formatter.format(budgeted)}',
                style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: colors.surfaceContainerHighest,
            color: statusColor,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Container(
              key: const Key('budgetStatusChip'),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                statusLabel,
                style: text.labelSmall?.copyWith(color: statusColor, fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              '$percentUsed% used',
              style: text.labelSmall?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
        if (calculation.dailyRecommendedSpend != null) ...<Widget>[
          const SizedBox(height: 10),
          Text(
            'Recommended: ${_formatter.format(calculation.dailyRecommendedSpend!)} / day '
            'for the rest of the month',
            style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

/// Savings goals card -- Beta 1 Task 3. Shows the single
/// highest-priority unfinished goal (see [selectHomeGoalSummary] in
/// `savings_goal_providers.dart`), an honest empty state before any goal
/// exists, or an "all goals completed" state when every goal is done.
/// There is deliberately no "most recently completed goal" fallback --
/// completion timestamps aren't persisted, so ADR-022 chose an explicit
/// all-completed state over a guess (`docs/14_DECISION_LOG.md` ADR-022).
class _SavingsGoalsCard extends ConsumerWidget {
  const _SavingsGoalsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<GoalHomeSelection> selectionAsync = ref.watch(homeGoalSelectionProvider);
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final GoalHomeSelection? selection = selectionAsync.valueOrNull;

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
                Icon(Icons.flag_outlined, color: colors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Savings Goals',
                    style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (selection != null && selection.kind != GoalHomeSelectionKind.empty)
                  TextButton(
                    key: const Key('viewAllGoalsButton'),
                    onPressed: () => context.push(AppRoutes.goals),
                    child: const Text('View all'),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            switch (selection?.kind) {
              null => const SizedBox(
                  height: 24,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              GoalHomeSelectionKind.empty => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      "You haven't set a savings goal yet.",
                      style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      key: const Key('setSavingsGoalButton'),
                      onPressed: () => context.push(AppRoutes.goals),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Set a savings goal'),
                    ),
                  ],
                ),
              GoalHomeSelectionKind.allCompleted => Text(
                  'All your savings goals are completed.',
                  style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
                ),
              GoalHomeSelectionKind.priorityGoal => _PriorityGoalSummary(summary: selection!.summary!),
            },
          ],
        ),
      ),
    );
  }
}

/// The priority-goal contents of [_SavingsGoalsCard] -- one goal's name,
/// saved-vs-target, a progress bar, and a status chip. Mirrors
/// `_ConfiguredBudget`'s percentage-display rule: the text percentage
/// ([SavingsGoalCalculation.wholePercentSaved]) is floor-rounded and
/// uncapped, never silently reading "100%" before the goal is actually
/// [SavingsGoalStatus.completed] -- only the progress bar's fill
/// fraction clamps to 1.0.
class _PriorityGoalSummary extends StatelessWidget {
  const _PriorityGoalSummary({required this.summary});
  final SavingsGoalSummary summary;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final SavingsGoalCalculation calc = summary.calculation;

    final (Color statusColor, String statusLabel) = switch (calc.status) {
      SavingsGoalStatus.overdue => (colors.error, 'Overdue'),
      SavingsGoalStatus.inProgress => (colors.primary, 'In progress'),
      SavingsGoalStatus.completed => (colors.primary, 'Completed'), // not reached via this card
    };

    final double ratio =
        calc.target.minorUnits == 0 ? 0 : calc.saved.minorUnits / calc.target.minorUnits;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(summary.name, style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 8,
          runSpacing: 2,
          children: <Widget>[
            Text(
              _formatter.format(calc.saved),
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                'of ${_formatter.format(calc.target)}',
                style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: colors.surfaceContainerHighest,
            color: statusColor,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                statusLabel,
                style: text.labelSmall?.copyWith(color: statusColor, fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              '${calc.wholePercentSaved}%',
              style: text.labelSmall?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ],
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
