import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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
import '../../recurring/domain/recurring_rule_kind.dart';
import '../../recurring/presentation/recurring_providers.dart';
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
                const _UpcomingCommitmentsCard(
                 key: Key('upcomingCommitmentsCardSection'),
                ),
                const SizedBox(height: 28),
                // CP5.1: the "Accounts" label had no flex protection at
                // all (unlike the analogous header rows on the budget
                // and recurring cards just above) -- at 320px + 1.6x it
                // overflowed the row on its own. Letting it yield first
                // (Expanded + one-line ellipsis) matches those two
                // existing header rows; the "Manage" button's own
                // behavior is unchanged.
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Accounts',
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
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
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
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
                    // CP5.1: `_CurrencyBadge` (e.g. "Living currency") is
                    // the only non-flexible sibling in this Row -- at
                    // narrow widths combined with large text scale its
                    // own natural width can exceed what's left after the
                    // icon+code group, so it must be allowed to shrink
                    // (and, per `_CurrencyBadge`'s own ellipsis) rather
                    // than paint past the card.
                    if (badge != null)
                      Flexible(child: _CurrencyBadge(label: badge!, prominent: true)),
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
/// Pairs an authoritative primary money value with a secondary
/// descriptive value (a target/budgeted amount prefixed with "of ", or a
/// scheduled date) -- International / Localization Foundation
/// Checkpoint 5.1. Shared by [_ConfiguredBudget], [_PriorityGoalSummary],
/// and [_RecurringItemSummary], which each had the same underlying gap:
/// a bare `Wrap` already correctly drops [secondaryText] onto its own
/// line whenever the pair TOGETHER don't fit the row (a `Wrap` only ever
/// decides between its children's own natural widths, so that part
/// already worked) -- but `Wrap` never constrains an individual child's
/// width, so if [primaryText] ALONE is wider than the row -- a real
/// possibility at large text scale and/or narrow widths, and/or with
/// KWD's extra minor-unit digit or a very large amount -- it painted
/// past the row's own bounds instead of ever wrapping.
///
/// This measures both texts' own natural width at the CURRENT text
/// style and text scale ([MediaQuery.textScalerOf]) against the row's
/// actual available width ([LayoutBuilder]). When they comfortably fit
/// side by side, this renders exactly the previous `Wrap` -- primary
/// then secondary, bottom-aligned -- unchanged from before this
/// checkpoint (`key`ed `'<keyPrefix>SideBySide'`). When they don't,
/// [secondaryText] moves below [primaryText] instead of beside it
/// (`key`ed `'<keyPrefix>Stacked'`).
///
/// In EITHER arrangement, [primaryText] is a plain [Text] that is never
/// wrapped in `FittedBox`, never ellipsized, and never has `maxLines`
/// capped -- every digit `MoneyFormatter` produced always renders, full
/// stop. In the stacked arrangement it sits directly in a [Column],
/// which bounds it to the row's own available width without capping its
/// height -- so even in the (rarer) case where [primaryText] alone is
/// too wide for one line, it simply wraps onto a second line rather than
/// painting outside the card. [secondaryText] MAY ellipsize (capped to
/// one line) -- it is never itself the authoritative figure (it either
/// restates [primaryText]'s sibling total, e.g. "of ¥120,000", or is a
/// date).
///
/// Deliberately does not branch on currency code, transaction/rule kind,
/// or locale anywhere -- the decision depends only on the two strings'
/// own measured widths, so it applies identically regardless of what
/// produced them.
class _AdaptiveAmountLine extends StatelessWidget {
  const _AdaptiveAmountLine({
    required this.keyPrefix,
    required this.primaryText,
    required this.primaryStyle,
    required this.secondaryText,
    required this.secondaryStyle,
  });

  /// Distinguishes this instance's layout-mode keys from the other
  /// cards reusing this same widget on the same screen (e.g.
  /// `'budgetAmount'`, `'goalAmount'`, `'recurringAmount'`) -- tests
  /// assert on `Key('<keyPrefix>SideBySide')`/`Key('<keyPrefix>Stacked')`
  /// to confirm which arrangement actually rendered.
  final String keyPrefix;
  final String primaryText;
  final TextStyle? primaryStyle;
  final String secondaryText;
  final TextStyle? secondaryStyle;

  /// Horizontal gap between primary and secondary in the side-by-side
  /// arrangement -- matches the previous `Wrap`'s `spacing: 8`.
  static const double _gap = 8;

  @override
  Widget build(BuildContext context) {
    final Widget primary = Text(primaryText, style: primaryStyle);
    final Widget secondary = Text(
      secondaryText,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: secondaryStyle,
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final TextScaler scaler = MediaQuery.textScalerOf(context);
        final direction = Directionality.of(context);
        final double primaryWidth = (TextPainter(
          text: TextSpan(text: primaryText, style: primaryStyle),
          textDirection: direction,
          textScaler: scaler,
        )..layout())
            .width;
        final double secondaryWidth = (TextPainter(
          text: TextSpan(text: secondaryText, style: secondaryStyle),
          textDirection: direction,
          textScaler: scaler,
        )..layout())
            .width;

        final bool fitsSideBySide = primaryWidth + _gap + secondaryWidth <= constraints.maxWidth;

        if (fitsSideBySide) {
          return Wrap(
            key: Key('${keyPrefix}SideBySide'),
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: _gap,
            runSpacing: 2,
            children: <Widget>[primary, secondary],
          );
        }

        return Column(
          key: Key('${keyPrefix}Stacked'),
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[primary, const SizedBox(height: 2), secondary],
        );
      },
    );
  }
}

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
        // International / Localization Foundation Checkpoint 5.1: see
        // `_AdaptiveAmountLine`'s doc comment for why a bare `Wrap` here
        // wasn't quite enough -- it never bounded the remaining amount's
        // OWN width, so a KWD-precision or very large remaining amount
        // at large text scale on a narrow screen could paint past the
        // card. Never shrinks, ellipsizes, or branches on currency.
        _AdaptiveAmountLine(
          keyPrefix: 'budgetAmount',
          primaryText: _formatter.format(remaining),
          primaryStyle: text.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: remaining.isNegative ? colors.error : null,
          ),
          secondaryText: 'of ${_formatter.format(budgeted)}',
          secondaryStyle: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
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
        // CP5.1: both the status chip and the percentage figure were
        // previously non-flexible in a `spaceBetween` Row -- a longer
        // status label (e.g. a longer translation of "Ahead of pace") or
        // an uncapped, potentially multi-digit "<percent>% used" at large
        // text scale on a narrow screen could together exceed the row's
        // width with neither able to shrink. Wrapping each in `Flexible`
        // (with the chip's and figure's own text allowed to ellipsize)
        // lets them shrink instead of overflowing; the true, uncapped
        // percentage value itself is never altered -- only its rendered
        // width can, in the extreme case, be visually truncated.
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Flexible(
              child: Container(
                key: const Key('budgetStatusChip'),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelSmall?.copyWith(color: statusColor, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '$percentUsed% used',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: text.labelSmall?.copyWith(color: colors.onSurfaceVariant),
              ),
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
        // CP5.1: see `_AdaptiveAmountLine`'s doc comment -- same fix as
        // `_ConfiguredBudget` above, applied to the saved-vs-target pair.
        _AdaptiveAmountLine(
          keyPrefix: 'goalAmount',
          primaryText: _formatter.format(calc.saved),
          primaryStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          secondaryText: 'of ${_formatter.format(calc.target)}',
          secondaryStyle: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
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
        // CP5.1: same fix as `_ConfiguredBudget`'s status/percent row --
        // both the status chip and the percentage figure were
        // non-flexible in a `spaceBetween` Row, so a longer status label
        // or the percentage at large text scale on a narrow screen could
        // together exceed the row with neither able to shrink. Wrapping
        // each in `Flexible` (with one-line ellipsis) lets them shrink
        // instead of overflowing; `calc.wholePercentSaved` itself is
        // never altered, only its rendered width can, in the extreme,
        // visually truncate.
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelSmall?.copyWith(color: statusColor, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '${calc.wholePercentSaved}%',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: text.labelSmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// "Recurring" tile -- Beta 1 Task 4A. Shows the single
/// highest-priority pending item (overdue first, then due today, then
/// nearest upcoming) from [homeRecurringSelectionProvider], never a
/// summed total: recurring rules can span multiple currencies and
/// `Money.operator+` throws on a currency mismatch by design (ADR-017),
/// so this card deliberately never adds amounts together -- exactly the
/// same single-item, no-fabricated-total rule [_SavingsGoalsCard]
/// already follows for goals (see `docs/14_DECISION_LOG.md` ADR-023).
class _UpcomingCommitmentsCard extends ConsumerWidget {
  // CP5.1: accepts a key so tests can deterministically scroll the
  // Home ListView until this card is mounted (`tester.scrollUntilVisible`)
  // instead of relying on a tall-enough fixed viewport -- presentation-only,
  // no behavior change.
  const _UpcomingCommitmentsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<RecurringHomeSelection> selectionAsync =
        ref.watch(homeRecurringSelectionProvider);
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final RecurringHomeSelection? selection = selectionAsync.valueOrNull;

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
                    'Recurring',
                    style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (selection != null && selection.kind != RecurringHomeSelectionKind.empty)
                  TextButton(
                    key: const Key('viewAllRecurringButton'),
                    onPressed: () => context.push(AppRoutes.recurring),
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
              RecurringHomeSelectionKind.empty => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'No recurring bills or income set up yet.',
                      style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      key: const Key('setRecurringRuleButton'),
                      onPressed: () => context.push(AppRoutes.recurring),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Set up recurring'),
                    ),
                  ],
                ),
              RecurringHomeSelectionKind.item => _RecurringItemSummary(item: selection!.item!),
            },
          ],
        ),
      ),
    );
  }
}

/// The single-item contents of [_UpcomingCommitmentsCard] -- the rule's
/// name, its urgency (Overdue/Due today/Upcoming), the scheduled date,
/// and the amount in the rule's own currency. Never any cross-currency
/// arithmetic -- [RecurringPendingItem.rule] carries its own
/// [RecurringRuleRow.currencyCode], formatted on its own.
class _RecurringItemSummary extends StatelessWidget {
  const _RecurringItemSummary({required this.item});
  final RecurringPendingItem item;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final RecurringRuleRow rule = item.rule;

    final (Color urgencyColor, String urgencyLabel) = switch (item.urgency) {
      RecurringItemUrgency.overdue => (colors.error, 'Overdue'),
      RecurringItemUrgency.dueToday => (colors.primary, 'Due today'),
      RecurringItemUrgency.upcoming => (colors.onSurfaceVariant, 'Upcoming'),
    };
    final IconData kindIcon = switch (RecurringRuleKind.values.byName(rule.kind)) {
      RecurringRuleKind.expense => Icons.arrow_upward_rounded,
      RecurringRuleKind.income => Icons.arrow_downward_rounded,
      RecurringRuleKind.transfer => Icons.swap_horiz_rounded,
    };
    final Money amount = Money.fromMinorUnits(rule.amountMinorUnits, rule.currencyCode);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(kindIcon, size: 18, color: colors.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                rule.name,
                style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // CP5.1: see `_AdaptiveAmountLine`'s doc comment -- same fix as
        // `_ConfiguredBudget` above, applied to the amount-vs-scheduled-
        // date pair.
        _AdaptiveAmountLine(
          keyPrefix: 'recurringAmount',
          primaryText: _formatter.format(amount),
          primaryStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          secondaryText: DateFormat.yMMMd().format(item.scheduledDateUtc),
          secondaryStyle: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: urgencyColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            urgencyLabel,
            style: text.labelSmall?.copyWith(color: urgencyColor, fontWeight: FontWeight.w600),
          ),
        ),
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
    final TextStyle? moneyStyle = Theme.of(context).textTheme.titleMedium;

    // CP5.2a: was a bare `Card(ListTile(title:, subtitle:, trailing:))`.
    // `ListTile` gives no guarantee that a long account name and a
    // large/high-precision balance can coexist -- its `trailing` slot is
    // sized independently of `title`/`subtitle`, so the balance could
    // end up silently clipped (`DefaultTextStyle`'s default
    // `TextOverflow.clip`) with no thrown error and no visible sign a
    // digit went missing. `_AdaptiveAccountRow` replaces it with a
    // measurement-based row that guarantees the balance always renders
    // in full -- see its doc comment. No `onTap` existed before this
    // change and none is added here.
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: balanceAsync.when(
          loading: () => _AdaptiveAccountRow(
            accountId: account.id,
            name: account.name,
            currencyCode: account.currencyCode,
            money: const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (Object e, StackTrace st) => _AdaptiveAccountRow(
            accountId: account.id,
            name: account.name,
            currencyCode: account.currencyCode,
            money: const Icon(Icons.error_outline),
          ),
          data: (Money balance) {
            final String formatted = _formatter.format(balance);
            return _AdaptiveAccountRow(
              accountId: account.id,
              name: account.name,
              currencyCode: account.currencyCode,
              money: Text(formatted, style: moneyStyle),
              moneyMeasureText: formatted,
              moneyStyle: moneyStyle,
            );
          },
        ),
      ),
    );
  }
}

/// Arranges an account tile's descriptive content (name + currency
/// code) against its authoritative balance -- International /
/// Localization Foundation Checkpoint 5.2a. See `_AccountTile`'s doc
/// comment for why a bare `ListTile` wasn't safe here.
///
/// This measures the balance's own natural (single-line) width at the
/// current text style and text scale ([MediaQuery.textScalerOf])
/// against the row's actual available width ([LayoutBuilder]). The
/// descriptive column (name + currency code) is always allowed to
/// ellipsize down to almost nothing, so the only real question is
/// whether the balance ALONE fits the row: when it does, this renders
/// name/currency and the balance side by side -- unchanged in spirit
/// from the previous `ListTile` arrangement, keyed
/// `'accountTileHorizontal_<accountId>'`. When the balance alone would
/// not fit even with the descriptive column squeezed to nothing (a
/// long account name plus a large/high-precision balance at narrow
/// width and large text scale), the balance instead moves onto its own
/// line below the descriptive content, given the card's full content
/// width rather than whatever a row would have left over -- keyed
/// `'accountTileStacked_<accountId>'`.
///
/// The balance is never wrapped in `FittedBox`, never ellipsized, and
/// never has `maxLines` capped in either arrangement -- every digit
/// `MoneyFormatter` produced always renders. In the rare case where
/// even the full stacked width isn't enough for one line, it simply
/// wraps onto a second line rather than losing a digit. Only the
/// account name and currency code may ellipsize (each capped to one
/// line) -- they are never the authoritative figure. While the balance
/// is still loading or errored, [moneyMeasureText] is left null and
/// this always renders horizontally -- a small spinner or icon never
/// needs to stack.
///
/// Deliberately does not branch on currency code -- the decision
/// depends only on the balance string's own measured width, so it
/// applies identically regardless of what produced it.
class _AdaptiveAccountRow extends StatelessWidget {
  const _AdaptiveAccountRow({
    required this.accountId,
    required this.name,
    required this.currencyCode,
    required this.money,
    this.moneyMeasureText,
    this.moneyStyle,
  });

  /// Distinguishes this tile's layout-mode keys from every other
  /// account tile on the same screen -- tests assert on
  /// `Key('accountTileHorizontal_<accountId>')`/
  /// `Key('accountTileStacked_<accountId>')` to confirm which
  /// arrangement actually rendered for a specific seeded account.
  final String accountId;
  final String name;
  final String currencyCode;

  /// The trailing content: the formatted balance `Text` once loaded, or
  /// a small fixed-size loading spinner / error icon otherwise.
  final Widget money;

  /// The exact string [money] renders when it's the formatted balance,
  /// used only to measure whether it fits the row. Null while
  /// loading/erroring.
  final String? moneyMeasureText;
  final TextStyle? moneyStyle;

  static const double _gap = 12;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;

    final Widget descriptive = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodyLarge),
        Text(
          currencyCode,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
      ],
    );

    final String? measureText = moneyMeasureText;
    if (measureText == null) {
      // Loading/error: nothing to stack -- the trailing widget is small
      // and fixed-size.
      return MergeSemantics(
        child: Row(
          key: Key('accountTileHorizontal_$accountId'),
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(child: descriptive),
            const SizedBox(width: _gap),
            money,
          ],
        ),
      );
    }

    return MergeSemantics(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final TextScaler scaler = MediaQuery.textScalerOf(context);
          final direction = Directionality.of(context);
          final double moneyWidth = (TextPainter(
            text: TextSpan(text: measureText, style: moneyStyle),
            textDirection: direction,
            textScaler: scaler,
          )..layout())
              .width;

          final bool fitsHorizontal = moneyWidth + _gap <= constraints.maxWidth;

          if (fitsHorizontal) {
            return Row(
              key: Key('accountTileHorizontal_$accountId'),
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Expanded(child: descriptive),
                const SizedBox(width: _gap),
                money,
              ],
            );
          }

          return Column(
            key: Key('accountTileStacked_$accountId'),
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              descriptive,
              const SizedBox(height: 6),
              Align(alignment: Alignment.centerLeft, child: money),
            ],
          );
        },
      ),
    );
  }
}
