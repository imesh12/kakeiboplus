import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/currency/currency_registry.dart';
import '../../../core/database/app_database.dart';
import '../../../core/fx/fx_converter.dart';
import '../../../core/fx/reference_fx_rate_providers.dart';
import '../../../core/fx/reference_rate_result.dart';
import '../../../core/fx/reference_rate_view.dart';
import '../../../core/money/money.dart';
import '../../../core/money/money_formatter.dart';
import '../../../core/money/money_overflow_exception.dart';
import '../../../core/routing/app_routes.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/theme/app_tokens.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_icon_tile.dart';
import '../../../shared/widgets/app_money_text.dart';
import '../../../shared/widgets/app_section_header.dart';
import '../../../shared/widgets/app_status_chip.dart';
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
    final AppLocalizations l10n = AppLocalizations.of(context);

    // Checkpoint 10 (Icon-Led UI Foundation): a restrained, theme-derived
    // ambient gradient wash behind the top of the scrollable body --
    // matching the approved reference's soft blue/lavender header wash.
    // Purely decorative and purely additive: a `Positioned` layer BEHIND
    // the existing `profileAsync.when(...)` content in a new outer
    // `Stack`, so every existing widget/key/text below is completely
    // unaffected -- it only ever paints in empty space the scaffold
    // background would otherwise show. Uses `AppTokens.colors.ambientGradient`
    // (see that token's doc comment) rather than a literal color, so
    // every theme (Light/Dark/Pink/Ocean/Forest) gets its own on-brand,
    // low-alpha wash automatically -- this is the ONE place in the app
    // this token is consumed, per "themes must not recolor the entire
    // application".
    final AppTokens tokens = context.appTokens;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navHome)),
      body: Stack(
        children: <Widget>[
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 220,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: tokens.colors.ambientGradient,
                  ),
                ),
              ),
            ),
          ),
          profileAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (Object e, StackTrace st) =>
                Center(child: Text(l10n.somethingWentWrong(e.toString()))),
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
                  // Checkpoint I: dashboardCurrencySummariesProvider now
                  // reads allAccountsProvider (active + closed), not
                  // accountsProvider alone -- both are invalidated on
                  // pull-to-refresh for the same reason the original
                  // line invalidated accountsProvider.
                  ref.invalidate(allAccountsProvider);
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                  children: <Widget>[
                    Text(
                      l10n.homeGreeting(profile.displayName),
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
                    AppSectionHeader(
                      title: l10n.accountsSectionTitle,
                      eyebrow: true,
                      trailing: TextButton(
                        onPressed: () => context.push(AppRoutes.accounts),
                        child: Text(l10n.manage),
                      ),
                    ),
                    const SizedBox(height: 4),
                    accountsAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (Object e, StackTrace st) =>
                          Text(l10n.couldNotLoadAccounts(e.toString())),
                      data: (List<AccountRow> accounts) {
                        if (accounts.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(l10n.noAccountsYetMessage),
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
        ],
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

  // CP6.3: reuses the existing `livingCurrency`/`homeCurrency` ARB keys
  // (already used as field labels on the International Preferences
  // screen) rather than adding near-duplicate ones -- both contexts mean
  // exactly the same thing: "this is the profile's living/home currency".
  String? _badgeFor(AppLocalizations l10n, CurrencyDashboardSummary summary) {
    if (summary.currencyCode == livingCurrency) return l10n.livingCurrency;
    if (summary.currencyCode == homeCurrency) return l10n.homeCurrency;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final AppLocalizations l10n = AppLocalizations.of(context);
    return summariesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (Object e, StackTrace st) =>
          AppCard(bordered: true, child: Text(l10n.couldNotLoadBalances(e.toString()))),
      data: (List<CurrencyDashboardSummary> summaries) {
        if (summaries.isEmpty) {
          return AppCard(
            bordered: true,
            child: Row(
              children: <Widget>[
                Icon(Icons.account_balance_wallet_outlined, color: colors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(l10n.addAccountToSeeBalance),
                ),
              ],
            ),
          );
        }
        final CurrencyDashboardSummary primary = summaries.first;
        final List<CurrencyDashboardSummary> secondary = summaries.skip(1).toList();
        return Column(
          children: <Widget>[
            _HeroCurrencyCard(
              summary: primary,
              badge: _badgeFor(l10n, primary),
              livingCurrencyCode: livingCurrency,
            ),
            const SizedBox(height: 16),
            // Checkpoint 10 Visual Convergence Pass: Income/Expenses/Daily
            // pace for the primary (hero) currency now render HERE --
            // compact, icon-led, and outside the hero card's own filled
            // surface -- instead of crammed inside it ("do not put all
            // monthly metrics inside the balance hero"). This is the
            // exact same `_MonthlyMetricsSection` widget and the same
            // `primary` data the hero card always rendered internally
            // before this pass -- only its position and tint changed (no
            // `tint` now, since it no longer sits on a filled
            // `primaryContainer` background and instead uses the default
            // on-surface colors) -- so every existing Income/Expense/Pace
            // assertion still finds exactly the same text, the same
            // number of times, just one level higher in the tree. Never a
            // new calculation, never fabricated.
            _MonthlyMetricsSection(summary: primary, emphasize: true),
            const SizedBox(height: 16),
            // Checkpoint 10 Visual Convergence Pass: a second compact,
            // icon-led row for Budgets/Savings Goals, matching the
            // approved reference's Home hierarchy (hero, then compact
            // Income/Expenses/Budgets/Goals tiles). Reuses the exact same
            // `monthlyBudgetSummaryProvider`/`homeGoalSelectionProvider`
            // state the full cards further down this screen already
            // compute -- never a new calculation or a fabricated count
            // (e.g. no invented "N active goals" figure) -- see
            // `_BudgetGoalsQuickGlanceRow`'s own doc comment.
            const _BudgetGoalsQuickGlanceRow(),
            for (final CurrencyDashboardSummary summary in secondary)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _SecondaryCurrencyCard(
                  summary: summary,
                  badge: _badgeFor(l10n, summary),
                  livingCurrencyCode: livingCurrency,
                ),
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
  const _HeroCurrencyCard({required this.summary, required this.livingCurrencyCode, this.badge});

  final CurrencyDashboardSummary summary;

  /// CP9.5 Task F: the profile's living currency, threaded down purely
  /// so [_LivingCurrencyEquivalentLine] can decide whether this card
  /// needs a "≈ `<living currency amount>`" line at all (never when this
  /// card's own currency already IS the living currency).
  final String livingCurrencyCode;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final AppTokens tokens = context.appTokens;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool isNegative = summary.availableBalance.isNegative;

    return Stack(
      children: <Widget>[
        AppCard(
          key: Key('heroCurrencyCard_${summary.currencyCode}'),
          color: colors.primaryContainer,
          // Checkpoint 10 Visual Convergence: the more generous hero/
          // feature-card radius `AppRadii.xl` (24) was added specifically
          // for this card back when it was introduced (see that token's
          // own doc comment) but never actually wired up here -- this is
          // that wiring, matching the approved reference's more
          // generously rounded balance card.
          radius: tokens.radii.xl,
          padding: EdgeInsets.all(tokens.spacing.lg),
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
                        child: AppMoneyText(
                          _formatter.format(summary.availableBalance),
                          emphasis: AppMoneyEmphasis.hero,
                          color: isNegative ? colors.error : colors.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                // CP9.5 Task F / Repair #2: a quiet, secondary
                // "≈ <living currency>" line -- when this card's own
                // currency already is the living currency, the equivalent
                // widget is never even constructed (not just rendered
                // zero-height), so no `livingCurrencyEquivalent_*` key
                // exists in the tree at all for that card. Still omitted
                // (zero-height) when no reference rate is available --
                // see [_LivingCurrencyEquivalentLine]'s own doc for that
                // case. Never combined with or substituted for the
                // balance above, which remains the sole authoritative
                // figure. Checkpoint I: converts `availableBalance` (the
                // figure actually shown above), not `netWorth` -- the
                // "≈" line is always about the SAME figure it sits under.
                if (summary.currencyCode != livingCurrencyCode)
                  _LivingCurrencyEquivalentLine(
                    key: Key('livingCurrencyEquivalent_${summary.currencyCode}'),
                    currencyCode: summary.currencyCode,
                    livingCurrencyCode: livingCurrencyCode,
                    balance: summary.availableBalance,
                    tint: colors.onPrimaryContainer.withValues(alpha: 0.85),
                  ),
                // Visual System Convergence Checkpoint 7.2: styled with
                // the shared `eyebrow` typography role (small, muted,
                // letter-spaced, semibold) instead of a plain
                // `bodyMedium`, matching the approved Claude Design
                // reference's "TOTAL AVAILABLE BALANCE" caption -- tinted
                // to `onPrimaryContainer` (at reduced emphasis) since
                // this card sits on a filled `primaryContainer`
                // background. The string itself (`l10n.totalAvailableBalance`)
                // is unchanged -- only its style. Checkpoint I: this
                // caption now correctly describes `availableBalance`
                // (immediately spendable money) rather than the old,
                // unqualified per-currency sum that used to silently
                // include locked deposit principal.
                Text(
                  l10n.totalAvailableBalance,
                  style: context.appTypography.eyebrow?.copyWith(
                    color: colors.onPrimaryContainer.withValues(alpha: 0.85),
                  ),
                ),
                // Checkpoint I (docs/20 §13.4 checkpoint I): a single,
                // restrained secondary line for net worth -- shown ONLY
                // when it actually differs from the available balance
                // already shown above (i.e. this currency holds at
                // least one deposit and/or liability account, active or
                // closed). For the common case (only cash/bank/savings/
                // wallet accounts) `netWorth == availableBalance` and
                // this renders nothing at all, keeping the hero card
                // exactly as restrained as before this checkpoint --
                // "do not turn Home into an accounting report."
                if (summary.netWorth != summary.availableBalance)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      l10n.homeNetWorthLine(_formatter.format(summary.netWorth)),
                      style: context.appTypography.eyebrow?.copyWith(
                        color: colors.onPrimaryContainer.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
              ],
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
  const _SecondaryCurrencyCard({
    required this.summary,
    required this.livingCurrencyCode,
    this.badge,
  });

  final CurrencyDashboardSummary summary;

  /// See [_HeroCurrencyCard.livingCurrencyCode]'s doc comment.
  final String livingCurrencyCode;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool isNegative = summary.availableBalance.isNegative;

    return AppCard(
      key: Key('secondaryCurrencyCard_${summary.currencyCode}'),
      bordered: true,
      // Checkpoint 10 Visual Convergence Pass: a restrained soft shadow
      // instead of relying on the border alone for separation -- matches
      // the approved reference's white feature cards, which read as
      // gently lifted rather than flat/outlined. Does not change `color`/
      // `shape`/`border` -- see `AppCard.softShadow`'s own doc comment;
      // this is additive only.
      softShadow: true,
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
                  child: AppMoneyText(
                    _formatter.format(summary.availableBalance),
                    color: isNegative ? colors.error : colors.onSurface,
                  ),
                ),
              ),
            ],
          ),
          // CP9.5 Task F / Repair #2: see `_HeroCurrencyCard`'s identical
          // line for the full doc comment (including why the equivalent
          // widget is never constructed at all for a same-currency card).
          // Checkpoint I: converts `availableBalance`, same reasoning as
          // the hero card's identical line.
          if (summary.currencyCode != livingCurrencyCode)
            _LivingCurrencyEquivalentLine(
              key: Key('livingCurrencyEquivalent_${summary.currencyCode}'),
              currencyCode: summary.currencyCode,
              livingCurrencyCode: livingCurrencyCode,
              balance: summary.availableBalance,
            ),
          // CP7.2: shared `eyebrow` role, matching the hero card's own
          // caption above -- see that widget's comment. Checkpoint I:
          // now correctly describes `availableBalance` -- see the hero
          // card's identical caption comment.
          Text(l10n.totalAvailableBalance, style: context.appTypography.eyebrow),
          // Checkpoint I: see `_HeroCurrencyCard`'s identical net-worth
          // line for the full doc comment -- same restrained,
          // only-when-it-differs rule applies here.
          if (summary.netWorth != summary.availableBalance)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                l10n.homeNetWorthLine(_formatter.format(summary.netWorth)),
                style: context.appTypography.eyebrow,
              ),
            ),
          const SizedBox(height: 12),
          _MonthlyMetricsSection(summary: summary, emphasize: false),
        ],
      ),
    );
  }
}

/// CP9.5 Task F: a quiet "≈ `<balance converted to the living currency>`"
/// line for a currency card whose own currency ISN'T the living
/// currency -- e.g. a JPY hero card while living in Vietnam (living
/// currency VND) shows "≈ ₫1,234,567" beneath its own "¥98,500" balance.
///
/// # Why this never needs a mixed-currency aggregate
///
/// Every [CurrencyDashboardSummary] this converts FROM is already a
/// single, deterministic amount in exactly one currency (see
/// `dashboard_providers.dart`'s own doc comment on why Home never
/// combines currencies into one figure) -- this widget performs one
/// single-currency-to-single-currency [FxConverter.convert] per card, it
/// never sums multiple cards' balances together, and the result is
/// rendered as an additional, visually quieter SECOND figure beside each
/// card's own still-authoritative balance, never in place of it. There
/// is therefore no "mixed-currency aggregate" for this feature to have
/// stopped on (see CP9.5's Task F STOP condition) -- the ambiguity that
/// condition guards against does not arise here.
///
/// # Presentation only
///
/// This never writes anything, never affects any balance/budget/income/
/// expense/savings-goal calculation, and is never itself the "amount"
/// used anywhere else -- purely an extra, informational line. Renders
/// nothing at all (zero height, no loading spinner, no error text) for:
/// this card's own currency already being the living currency; the
/// living currency being unrecognized by [CurrencyRegistry] (mirrors
/// [ReferenceRateCard]'s own guard); the rate still loading; the rate
/// being genuinely unavailable ([ReferenceRateView.isUnavailable]); or a
/// conversion that would overflow [Money]'s 64-bit range
/// ([MoneyOverflowException], astronomically unlikely for a real
/// balance but never allowed to crash Home if it somehow occurred).
/// Never colored as positive/negative (Task J) -- always a neutral/muted
/// tone, optionally [tint]-overridden to match the hero card's own
/// on-`primaryContainer` caption treatment.
class _LivingCurrencyEquivalentLine extends ConsumerWidget {
  const _LivingCurrencyEquivalentLine({
    required this.currencyCode,
    required this.livingCurrencyCode,
    required this.balance,
    super.key,
    this.tint,
  });

  final String currencyCode;
  final String livingCurrencyCode;
  final Money balance;
  final Color? tint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (currencyCode == livingCurrencyCode) return const SizedBox.shrink();
    if (CurrencyRegistry.byCode(livingCurrencyCode) == null) return const SizedBox.shrink();

    final AsyncValue<ReferenceRateResult> resultAsync =
        ref.watch(referenceRateProvider((currencyCode, livingCurrencyCode)));

    return resultAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (Object e, StackTrace st) => const SizedBox.shrink(),
      data: (ReferenceRateResult result) {
        final ReferenceRateView view = ReferenceRateView.from(
          result,
          baseCurrencyCode: currencyCode,
          quoteCurrencyCode: livingCurrencyCode,
        );
        if (!view.hasUsableRate) return const SizedBox.shrink();

        Money equivalent;
        try {
          equivalent = FxConverter.convert(
            source: balance,
            targetCurrencyCode: livingCurrencyCode,
            rate: view.rate,
          );
        } on MoneyOverflowException {
          return const SizedBox.shrink();
        }

        final AppLocalizations l10n = AppLocalizations.of(context);
        final Color color = tint ?? Theme.of(context).colorScheme.onSurfaceVariant;
        final String formattedEquivalent = _formatter.format(equivalent);
        final String label = view.isStale
            ? l10n.approxAmountStaleLabel(formattedEquivalent)
            : l10n.approxAmountLabel(formattedEquivalent);

        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            label,
            style: context.appTypography.eyebrow?.copyWith(color: color),
          ),
        );
      },
    );
  }
}

/// Income / Spending / Daily-pace, given room to breathe. Income and
/// Spending sit side by side on a normal-width screen and stack
/// vertically on a narrow one (see [LayoutBuilder] below) rather than
/// ever forcing three values into one cramped row; Daily Spending Pace
/// always gets its own full-width tile underneath.
///
/// Always renders with default on-surface colors -- this section no
/// longer has a tinted hero placement (Checkpoint 10 Visual Convergence
/// moved it out from inside the hero card to a sibling position below
/// it), so the single-color override this widget previously supported
/// was removed as dead code rather than kept unused. The underlying
/// calculations are untouched; this widget only formats and lays out
/// what [dashboardCurrencySummariesProvider] already computed.
class _MonthlyMetricsSection extends StatelessWidget {
  const _MonthlyMetricsSection({required this.summary, required this.emphasize});

  final CurrencyDashboardSummary summary;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final AppTokens tokens = context.appTokens;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final TextStyle? valueStyle = (emphasize ? textTheme.titleLarge : textTheme.titleMedium)
        ?.copyWith(fontWeight: FontWeight.w700);
    final TextStyle? labelStyle = textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
    );

    // Checkpoint 8.2 (Whole-App Theme Compatibility): income reads
    // through `AppTokens.colors.positive`, not `colorScheme.primary`
    // directly -- Forest overrides `positive` to a distinct "true
    // success" green specifically so its own decorative primary accent
    // (itself green) is never mistaken for the income semantic (see
    // `app_theme.dart`'s `_forestPositiveGreen` doc comment). Every other
    // theme's `positive` still equals `colorScheme.primary`, so this is a
    // no-op everywhere except Forest.
    final Widget incomeTile = _MetricTile(
      icon: Icons.trending_up_rounded,
      iconColor: tokens.colors.positive,
      label: l10n.incomeThisMonth,
      value: summary.income,
      valueStyle: valueStyle,
      labelStyle: labelStyle,
    );
    final Widget spendTile = _MetricTile(
      icon: Icons.trending_down_rounded,
      iconColor: colors.error,
      label: l10n.spentThisMonth,
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
              iconColor: colors.tertiary,
              label: l10n.dailySpendingPace,
              secondaryLabel: l10n.dailySpendingPaceDetail,
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
            // Checkpoint 10 (Icon-Led UI Foundation): the shared
            // AppIconTile primitive (small tier -- 32/16, close to this
            // row's pre-existing bare 18px glyph) instead of a plain
            // Icon, matching the approved reference's tinted-container
            // icon treatment on every metric/summary tile. Purely
            // additive visually: still the same `icon`/`iconColor` the
            // caller already resolved, just presented in a small
            // rounded-square chip instead of bare.
            AppIconTile(icon: icon, color: iconColor, size: AppIconTileSize.small),
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

/// Checkpoint 10 Visual Convergence Pass: a compact, icon-led tile for a
/// short STATUS string (e.g. "On track", "Not set") rather than a
/// [Money] value -- [_MetricTile]'s own contract is specifically a money
/// value, so this is a small sibling widget with the same visual
/// language (an [AppIconTile], a muted label, a strong value line)
/// instead of overloading [_MetricTile] with a second value type.
class _StatusMetricTile extends StatelessWidget {
  const _StatusMetricTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            AppIconTile(icon: icon, color: iconColor, size: AppIconTileSize.small),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: valueColor),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// Checkpoint 10 Visual Convergence Pass: a compact, icon-led "at a
/// glance" pair of tiles for Budgets/Savings Goals, sitting directly
/// below the relocated Income/Expense/Pace section -- matching the
/// approved reference's Home hierarchy (a hero balance, then compact
/// Income/Expenses/Budgets/Goals tiles). Reuses the exact same
/// [monthlyBudgetSummaryProvider]/[homeGoalSelectionProvider] state the
/// full [_BudgetCard]/[_SavingsGoalsCard] sections further down this
/// screen already compute -- this never fabricates a number (e.g. no
/// invented "N active goals" count) and never duplicates a calculation:
/// it is a second, quieter, glance-level presentation of the exact same
/// already-truthful state. When a budget/goal genuinely isn't configured
/// yet, this honestly shows [AppLocalizations.homeQuickGlanceNotSet]
/// rather than a fake value, matching the empty-state discipline the
/// full cards below already follow.
class _BudgetGoalsQuickGlanceRow extends ConsumerWidget {
  const _BudgetGoalsQuickGlanceRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final MonthlyBudgetSummary budgetSummary = ref.watch(monthlyBudgetSummaryProvider);
    final AsyncValue<GoalHomeSelection> goalSelectionAsync = ref.watch(homeGoalSelectionProvider);

    // Mirrors `_ConfiguredBudget`'s own status->(color, label) mapping
    // exactly (same colors, same localized labels) -- this is a second
    // presentation of that same truth, never a new one. A `null`
    // calculation (no budget configured for this month at all) is
    // distinguished from a configured calculation with no specific
    // status, which keeps `_ConfiguredBudget`'s own existing
    // "budgetStatusThisMonth" fallback meaning intact.
    final BudgetCalculation? budgetCalc = budgetSummary.calculation;
    final (Color budgetColor, String budgetValue) = budgetCalc == null
        ? (colors.onSurfaceVariant, l10n.homeQuickGlanceNotSet)
        : switch (budgetCalc.status) {
            null => (colors.onSurfaceVariant, l10n.budgetStatusThisMonth),
            BudgetStatus.healthy => (colors.primary, l10n.budgetStatusOnTrack),
            BudgetStatus.caution => (colors.tertiary, l10n.budgetStatusAheadOfPace),
            BudgetStatus.overBudget => (colors.error, l10n.budgetStatusOverBudget),
          };

    final GoalHomeSelection? goalSelection = goalSelectionAsync.valueOrNull;
    final (Color goalColor, String goalValue) = switch (goalSelection?.kind) {
      null => (colors.onSurfaceVariant, l10n.homeQuickGlanceNotSet),
      GoalHomeSelectionKind.empty => (colors.onSurfaceVariant, l10n.homeQuickGlanceNotSet),
      GoalHomeSelectionKind.allCompleted => (colors.primary, l10n.goalStatusCompleted),
      GoalHomeSelectionKind.priorityGoal => (
          goalSelection!.summary!.calculation.status == SavingsGoalStatus.overdue
              ? colors.error
              : colors.primary,
          goalSelection.summary!.calculation.status == SavingsGoalStatus.overdue
              ? l10n.overdueLabel
              : l10n.goalStatusInProgress,
        ),
    };

    final Widget budgetTile = _StatusMetricTile(
      icon: Icons.savings_outlined,
      iconColor: budgetColor,
      label: l10n.budgetsTitle,
      value: budgetValue,
      valueColor: budgetColor,
    );
    final Widget goalTile = _StatusMetricTile(
      icon: Icons.flag_outlined,
      iconColor: goalColor,
      label: l10n.homeGoalsQuickGlanceLabel,
      value: goalValue,
      valueColor: goalColor,
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // Same 320px narrow-layout threshold `_MonthlyMetricsSection`
        // already uses immediately above this row, for the same reason:
        // two side-by-side tiles below that width compress into
        // colliding text.
        final bool narrow = constraints.maxWidth < 320;
        return narrow
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[budgetTile, const SizedBox(height: 12), goalTile],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: budgetTile),
                  const SizedBox(width: 12),
                  Expanded(child: goalTile),
                ],
              );
      },
    );
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
    final AppLocalizations l10n = AppLocalizations.of(context);
    final BudgetCalculation? calculation = budget.calculation;

    return AppCard(
      // Checkpoint 10 Visual Convergence follow-up: a stable key so
      // widget tests can scope `find.descendant` to this specific card
      // rather than a bare `find.byIcon(Icons.savings_outlined)`/
      // `find.byType(Card)`, which became ambiguous once the Home quick
      // -glance row (`_BudgetGoalsQuickGlanceRow`) introduced a second,
      // unrelated savings icon above this card. Presentation-only.
      key: const Key('budgetCard'),
      bordered: true,
      softShadow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AppSectionHeader(
            icon: Icons.savings_outlined,
            title: l10n.remainingMonthlyBudget,
            eyebrow: true,
            trailing: calculation != null
                ? TextButton(
                    key: const Key('manageBudgetsButton'),
                    onPressed: () => context.push(AppRoutes.budgets),
                    child: Text(l10n.manage),
                  )
                : null,
          ),
          const SizedBox(height: 10),
          if (calculation == null)
            AppEmptyState(
              message: l10n.noBudgetSetMessage,
              actionLabel: l10n.setMonthlyBudgetButton,
              onAction: () => context.push(AppRoutes.budgets),
            )
          else
            _ConfiguredBudget(calculation: calculation),
        ],
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
    final AppLocalizations l10n = AppLocalizations.of(context);

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
      BudgetStatus.healthy => (colors.primary, l10n.budgetStatusOnTrack),
      BudgetStatus.caution => (colors.tertiary, l10n.budgetStatusAheadOfPace),
      BudgetStatus.overBudget => (colors.error, l10n.budgetStatusOverBudget),
      null => (colors.onSurfaceVariant, l10n.budgetStatusThisMonth),
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
          secondaryText: l10n.ofAmount(_formatter.format(budgeted)),
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
              child: AppStatusChip(
                key: const Key('budgetStatusChip'),
                label: statusLabel,
                color: statusColor,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                l10n.percentUsedLabel('$percentUsed'),
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
            l10n.recommendedDailySpend(_formatter.format(calculation.dailyRecommendedSpend!)),
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
    final AppLocalizations l10n = AppLocalizations.of(context);
    final GoalHomeSelection? selection = selectionAsync.valueOrNull;

    return AppCard(
      // Checkpoint 10 Visual Convergence follow-up: see the matching
      // `Key('budgetCard')` comment above -- same reason, for the flag
      // icon this card shares with the Home quick-glance row's goal tile.
      key: const Key('savingsGoalsCard'),
      bordered: true,
      softShadow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AppSectionHeader(
            icon: Icons.flag_outlined,
            title: l10n.savingsGoalsTitle,
            eyebrow: true,
            trailing: selection != null && selection.kind != GoalHomeSelectionKind.empty
                ? TextButton(
                    key: const Key('viewAllGoalsButton'),
                    onPressed: () => context.push(AppRoutes.goals),
                    child: Text(l10n.viewAll),
                  )
                : null,
          ),
          const SizedBox(height: 10),
          switch (selection?.kind) {
            null => const SizedBox(
                height: 24,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            GoalHomeSelectionKind.empty => AppEmptyState(
                actionKey: const Key('setSavingsGoalButton'),
                message: l10n.noSavingsGoalMessage,
                actionLabel: l10n.setSavingsGoalButton,
                onAction: () => context.push(AppRoutes.goals),
              ),
            GoalHomeSelectionKind.allCompleted => Text(
                l10n.allGoalsCompletedMessage,
                style: context.appTypography.secondaryBody,
              ),
            GoalHomeSelectionKind.priorityGoal => _PriorityGoalSummary(summary: selection!.summary!),
          },
        ],
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
    final AppLocalizations l10n = AppLocalizations.of(context);
    final SavingsGoalCalculation calc = summary.calculation;

    final (Color statusColor, String statusLabel) = switch (calc.status) {
      SavingsGoalStatus.overdue => (colors.error, l10n.overdueLabel),
      SavingsGoalStatus.inProgress => (colors.primary, l10n.goalStatusInProgress),
      SavingsGoalStatus.completed => (colors.primary, l10n.goalStatusCompleted), // not reached via this card
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
          secondaryText: l10n.ofAmount(_formatter.format(calc.target)),
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
            Flexible(child: AppStatusChip(label: statusLabel, color: statusColor)),
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
    final AppLocalizations l10n = AppLocalizations.of(context);
    final RecurringHomeSelection? selection = selectionAsync.valueOrNull;

    return AppCard(
      bordered: true,
      softShadow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AppSectionHeader(
            icon: Icons.event_note_outlined,
            title: l10n.recurringTitle,
            eyebrow: true,
            trailing: selection != null && selection.kind != RecurringHomeSelectionKind.empty
                ? TextButton(
                    key: const Key('viewAllRecurringButton'),
                    onPressed: () => context.push(AppRoutes.recurring),
                    child: Text(l10n.viewAll),
                  )
                : null,
          ),
          const SizedBox(height: 10),
          switch (selection?.kind) {
            null => const SizedBox(
                height: 24,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            RecurringHomeSelectionKind.empty => AppEmptyState(
                actionKey: const Key('setRecurringRuleButton'),
                message: l10n.noRecurringMessage,
                actionLabel: l10n.setUpRecurringButton,
                onAction: () => context.push(AppRoutes.recurring),
              ),
            RecurringHomeSelectionKind.item => _RecurringItemSummary(item: selection!.item!),
          },
        ],
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
    final AppLocalizations l10n = AppLocalizations.of(context);
    final RecurringRuleRow rule = item.rule;

    final (Color urgencyColor, String urgencyLabel) = switch (item.urgency) {
      RecurringItemUrgency.overdue => (colors.error, l10n.overdueLabel),
      RecurringItemUrgency.dueToday => (colors.primary, l10n.recurringStatusDueToday),
      RecurringItemUrgency.upcoming => (colors.onSurfaceVariant, l10n.recurringStatusUpcoming),
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
        AppStatusChip(label: urgencyLabel, color: urgencyColor),
      ],
    );
  }
}

class _AccountTile extends ConsumerWidget {
  const _AccountTile({required this.account});

  final AccountRow account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Money> balanceAsync = ref.watch(accountBalanceProvider(account));
    final TextStyle? moneyStyle = Theme.of(context).textTheme.titleMedium;
    final AppTokens tokens = context.appTokens;

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
    return AppCard(
      bordered: true,
      softShadow: true,
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.md, vertical: tokens.spacing.sm),
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
