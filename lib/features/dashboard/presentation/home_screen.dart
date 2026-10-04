import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import 'package:intl/intl.dart' hide TextDirection;
import '../../../shared/branding/dashboard_mascot.dart';
import '../../../shared/theme/app_tokens.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_icon_tile.dart';
import '../../../shared/widgets/app_money_text.dart';
import '../../../shared/widgets/app_progress_bar.dart';
import '../../../shared/widgets/app_section_header.dart';
import '../../../shared/widgets/app_status_chip.dart';
import '../../accounts/presentation/account_providers.dart';
import '../../budgets/domain/budget_calculation.dart';
import '../../budgets/domain/budget_status.dart';
import '../../categories/domain/category_color.dart';
import '../../categories/presentation/category_providers.dart';
import '../../goals/domain/savings_goal_calculation.dart';
import '../../goals/domain/savings_goal_status.dart';
import '../../goals/presentation/savings_goal_providers.dart';
import '../../onboarding/presentation/profile_providers.dart';
import '../../recurring/domain/recurring_rule_kind.dart';
import '../../recurring/presentation/recurring_providers.dart';
import '../../transactions/presentation/transaction_icon_badge.dart';
import '../domain/greeting_period.dart';
import 'dashboard_providers.dart';
import 'spending_by_category_section.dart';

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
      // Dashboard Visual Refresh Pass (docs/design/dashboard-referancenew.png):
      // the Home Dashboard's own soft mint page background -- `null` on
      // Pink/Ocean/Forest/Dark (see `AppTokens.colors
      // .dashboardPageBackground`'s own doc comment), in which case this
      // falls back to the ordinary theme `scaffoldBackgroundColor`
      // (`colorScheme.surface`) exactly as before this pass. Scoped to
      // this one Scaffold only -- every other screen's background is
      // completely unaffected.
      backgroundColor: tokens.colors.dashboardPageBackground,
      // Dashboard V1 Finalization checkpoint (docs/23 §4.1 "Layer A --
      // brand top bar"): the plain Material `AppBar` is gone entirely --
      // `_KakeiboBrandBar` below is now the screen's own top identity,
      // painted with the same fixed brand gradient as the hero card so
      // the two read as one coherent brand area (docs/23 §3). It renders
      // as the ListView's own first child (inside the `SafeArea` it
      // provides itself), not as `Scaffold.appBar`, so it scrolls away
      // with the rest of the header rather than staying pinned --
      // matching docs/23 §4.1's "should not look like a default Material
      // AppBar." `l10n.navHome` still labels the bottom-nav "Home"
      // destination in `app_shell.dart` (untouched) -- only this
      // screen's own top identity changed.
      body: Stack(
        children: <Widget>[
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
                child: CustomScrollView(
                  slivers: <Widget>[
                    // Dashboard V1 Finalization checkpoint (docs/23 §4.1
                    // "Layer A -- brand top bar"): replaces the former
                    // bare wordmark row -- see `_KakeiboBrandBar`'s own
                    // doc comment. Root-cause fix: a bare `Padding` with
                    // negative `EdgeInsets` (the previous approach here)
                    // is never valid Flutter -- `RenderPadding
                    // .performLayout()` (`shifted_box.dart`) asserts
                    // `padding.isNonNegative` unconditionally, so every
                    // widget test that mounted this screen at all (not
                    // just narrow/theme variants) was failing that
                    // assertion the moment this sliver built. Rendering
                    // the bar as its own unpadded `SliverToBoxAdapter`,
                    // ahead of the `SliverPadding` below that now carries
                    // every other section's existing 16/20/16/32 inset
                    // completely unchanged, gets the identical edge-to-
                    // edge visual (docs/23 §4.1's "compact full-width...
                    // brand header," matching the reference) through
                    // ordinary sliver composition instead of a negative
                    // inset -- and it still scrolls away with the rest of
                    // the header, exactly as before.
                    const SliverToBoxAdapter(child: _KakeiboBrandBar()),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate(<Widget>[
                    // Checkpoint U3 (docs/23 §4.2 "Layer B -- greeting
                    // block"): one primary, time-of-day-aware greeting
                    // line plus one short supporting line -- no financial
                    // numbers here (docs/23's own greeting rule), and no
                    // mascot beside it either: the mascot moved into
                    // `_HeroCurrencyCard` itself (docs/23 §6.2 "right
                    // side of hero card") -- see that class's own doc
                    // comment for why a `Row` sibling there, not a
                    // `Stack` overlay, is what actually satisfies §6.3's
                    // "never cover the main amount."
                    //
                    // [GreetingPeriod.forHour] is a pure, Flutter-free
                    // function (see that file's own doc comment for why
                    // no new time/clock service was added) -- `DateTime
                    // .now()` is already local device time, exactly like
                    // every other "this calendar month" calculation on
                    // this screen already assumes.
                    // Dashboard Visual Refresh Pass: a single, subtle,
                    // low-alpha leaf accent on the trailing side --
                    // echoing the same leaf motif already in the brand
                    // mark/mascot bandana (see `_KakeiboBrandBar`'s new
                    // mark and `DashboardMascot`), rather than a
                    // time-of-day sun icon that would look wrong once
                    // `GreetingPeriod` reaches evening. `Expanded` keeps
                    // the greeting text as the width-authoritative
                    // element -- the icon can never crowd or wrap it,
                    // only occupy space the text didn't need.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                switch (GreetingPeriod.forHour(DateTime.now().hour)) {
                                  GreetingPeriod.morning =>
                                    l10n.homeGreetingMorning(profile.displayName),
                                  GreetingPeriod.afternoon =>
                                    l10n.homeGreetingAfternoon(profile.displayName),
                                  GreetingPeriod.evening =>
                                    l10n.homeGreetingEvening(profile.displayName),
                                },
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.homeGreetingSupportingLine,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: tokens.colors.secondaryText,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 8, top: 2),
                          child: Icon(
                            Icons.eco_rounded,
                            color: tokens.colors.positive.withValues(alpha: 0.28),
                            size: 30,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Dashboard Visual Refresh Pass: `_CurrencySummarySection`
                    // renders ONLY the hero card + 2x2 metrics grid.
                    // `homeCurrency` isn't needed here any more (it was
                    // only ever used for the secondary cards' "Home
                    // currency" badge -- U3 Final Polish Pass removed
                    // that whole section from Home; see this build
                    // method's own doc comment further down for why).
                    _CurrencySummarySection(
                      summariesAsync: summariesAsync,
                      livingCurrency: profile.livingCurrency,
                    ),
                    SizedBox(height: context.appTokens.spacing.md),
                    // Dashboard V1 Finalization checkpoint: reordered to
                    // follow the approved reference's section sequence
                    // (hero+grid, Upcoming commitments, Spending this
                    // month, Savings Goals, then the full Budget detail
                    // card) -- no section's own provider/logic changed,
                    // only where it sits on the page.
                    //
                    const _UpcomingCommitmentsCard(
                      key: Key('upcomingCommitmentsCardSection'),
                    ),
                    SizedBox(height: context.appTokens.spacing.md),
                    const SpendingByCategorySection(),
                    SizedBox(height: context.appTokens.spacing.md),
                    // U3 Final Polish Pass (Home presentation cleanup):
                    // Home now ends with Savings Goals -- both the
                    // secondary currency/account-summary section AND
                    // the full Budget detail card that used to render
                    // below this point were removed from THIS screen
                    // only. Remaining Budget is already represented in
                    // the 2x2 metrics grid above (`_RemainingBudgetTile`
                    // /`Key('remainingBudgetTile')`), so a second, large
                    // Budget card here was unnecessary duplication, not
                    // a distinct feature -- the full Budget detail
                    // experience (progress bar, status chip, percentage,
                    // daily recommendation, "Manage") remains completely
                    // intact on its own screen (`AppRoutes.budgets`,
                    // reachable from the 2x2 tile and from More/Budgets
                    // navigation); this pass only stopped duplicating it
                    // a second time on Home. `BudgetCalculation` and
                    // every budget repository/provider are untouched --
                    // this is presentation-only, exactly like the
                    // earlier account/currency-summary removal it sits
                    // alongside. `AccountRepository`/`accountsProvider`/
                    // `allAccountsProvider` and every account row in the
                    // database are likewise completely untouched (see
                    // the pull-to-refresh callback above, which still
                    // invalidates `accountsProvider` for the Accounts
                    // tab's own benefit), and the Accounts tab
                    // (`AppRoutes.accounts`) still lists every account
                    // exactly as before -- only this screen stopped
                    // re-displaying that same list a second time. The
                    // now-unreachable `_SecondaryCurrencySummarySection`/
                    // `_SecondaryCurrencyCard`/`_CurrencyBadge`/
                    // `_MonthlyMetricsSection`/`_currencyBadgeLabel`/
                    // `_AccountTile`/`_AdaptiveAccountRow`/`_BudgetCard`/
                    // `_ConfiguredBudget` were deleted outright rather
                    // than left as dead, analyzer-flagged
                    // (`unused_element`) private code with no remaining
                    // call site.
                    const _SavingsGoalsCard(),
                        ]),
                      ),
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

/// Dashboard Visual Refresh Pass (docs/design/dashboard-referancenew.png
/// §5/§9): renders the hero card + 2x2 monthly metrics grid. U3 Final
/// Polish Pass (Home presentation cleanup): every OTHER currency the
/// user holds is no longer shown on Home at all -- it previously
/// rendered further down the page as a `_SecondaryCurrencySummarySection`,
/// which this pass removed outright (see `HomeScreen.build`'s own doc
/// comment on that removal); those balances remain fully available on
/// the Accounts tab. Deliberately never combines currencies into a
/// single figure; see [dashboardCurrencySummariesProvider]'s doc comment
/// for why.
class _CurrencySummarySection extends StatelessWidget {
  const _CurrencySummarySection({
    required this.summariesAsync,
    required this.livingCurrency,
  });

  final AsyncValue<List<CurrencyDashboardSummary>> summariesAsync;
  final String livingCurrency;

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
        return Column(
          children: <Widget>[
            _HeroCurrencyCard(
              summary: primary,
              livingCurrencyCode: livingCurrency,
            ),
            const SizedBox(height: 16),
            // Dashboard V1 Finalization checkpoint: the exact 2x2
            // structure (Monthly Income, Monthly Spending, Remaining
            // Budget, Daily Spending Pace) as four INDEPENDENT cards --
            // supersedes both the single `AppCard`-wrapped
            // `_MonthlyMetricsSection` and the `_BudgetGoalsQuickGlanceRow`
            // this checkpoint replaces (see `_MonthlyMetricsGrid`'s own
            // doc comment). Every figure is still the SAME
            // `primary`/`monthlyBudgetSummaryProvider` data these two
            // removed widgets already read -- never a new calculation.
            _MonthlyMetricsGrid(summary: primary),
          ],
        );
      },
    );
  }
}

/// Dashboard V1 Finalization checkpoint (docs/23 §4.1 "Layer A -- brand
/// top bar"): a compact, full-bleed brand header -- the fixed
/// KakeiboPlus teal/emerald gradient (the SAME [AppTokens.colors
/// .heroGradient] the hero card already uses, so the two read as one
/// coherent brand area per docs/23 §3), the app name, and a compact
/// profile action.
///
/// Dashboard Visual Refresh Pass (docs/design/dashboard-referancenew.png):
/// the brand mark is now `assets/branding/kakeiboplus-mark-light.png` --
/// a WHITE-INK crop of the existing `kakeiboplus-primary-logo.png` "K+"
/// glyph (generated once from that same source artwork, not a new logo)
/// -- rather than the generic `Icons.savings_rounded` placeholder this
/// bar used before. `kakeiboplus-wordmark.png` itself is still not used
/// here: that asset's ink is a fixed brand color meant for a LIGHT
/// background (see `more_screen.dart`'s own doc comment on that asset),
/// so it would read poorly on this bar's own dark teal/emerald fill --
/// the same reason a light-ink variant of the "K+" mark was made instead
/// of reusing that asset directly. Plain white bold [Text] for the
/// wordmark still guarantees legible contrast in both Light and Dark
/// (docs/23 §4.1: "the wordmark/name should remain clearly legible").
///
/// The gradient direction now matches [_HeroCurrencyCard]'s own
/// `topLeft -> bottomRight` diagonal (previously a flatter
/// `centerLeft -> centerRight`) for a richer, more "radiant" feel
/// consistent with the hero card's own palette -- plus one subtle,
/// low-alpha decorative glow (never covering the wordmark/profile
/// button, `IgnorePointer`+clipped to the bar's own bounds) rather than
/// a flat color block.
///
/// On Pink/Ocean/Forest (`heroGradient == null`), this bar falls back to
/// `colorScheme.primary` as a solid fill -- every theme still gets a
/// coherent, on-brand top bar, never an unstyled/transparent one.
///
/// The profile action reuses the existing `AppRoutes.profile` route
/// (already reachable from the More screen) rather than inventing new
/// navigation -- docs/23 §4.1 "avoid multiple competing actions" and
/// this project's own "do not change navigation architecture...unless
/// explicitly authorized" rule.
class _KakeiboBrandBar extends StatelessWidget {
  const _KakeiboBrandBar();

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.appTokens;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<Color>? heroGradientColors = tokens.colors.heroGradient;
    final Gradient? barGradient = heroGradientColors == null
        ? null
        : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: heroGradientColors,
          );
    final Color fallbackColor = Theme.of(context).colorScheme.primary;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: barGradient == null ? fallbackColor : null,
        gradient: barGradient,
      ),
      // Dashboard Visual Refresh Pass: a `Stack` so a subtle decorative
      // glow can sit BEHIND the real content -- `clipBehavior:
      // Clip.hardEdge` (the `Stack` default, named explicitly here for
      // clarity) keeps the glow from ever painting outside this bar's
      // own bounds, and `IgnorePointer` keeps it out of hit-testing/
      // semantics entirely, so it can never intercept the profile
      // button's tap or be announced to a screen reader.
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: <Widget>[
          const Positioned(
            top: -28,
            right: -24,
            child: IgnorePointer(
              child: _BrandBarGlow(),
            ),
          ),
          SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.md,
            vertical: tokens.spacing.sm,
          ),
          child: Row(
            children: <Widget>[
              Image.asset(
                'assets/branding/kakeiboplus-mark-light.png',
                width: 24,
                height: 24,
                excludeFromSemantics: true,
              ),
              SizedBox(width: tokens.spacing.xs),
              Expanded(
                child: Text(
                  l10n.brandName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              // `ExcludeSemantics` on the `InkWell` suppresses its own
              // automatic button semantics so the explicit `Semantics`
              // below is the one and only node a screen reader
              // announces for this control -- avoiding the duplicate
              // "button, button" announcement an `InkWell` + a second
              // wrapping `Semantics` would otherwise produce.
              Semantics(
                label: l10n.navProfile,
                button: true,
                child: ExcludeSemantics(
                  child: InkWell(
                    key: const Key('brandBarProfileButton'),
                    customBorder: const CircleBorder(),
                    onTap: () => context.push(AppRoutes.profile),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: CircleAvatar(
                        radius: 15,
                        backgroundColor: Colors.white.withValues(alpha: 0.22),
                        child: const Icon(Icons.person_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
          ),
        ],
      ),
    );
  }
}

/// A single, subtle, low-alpha decorative glow -- see
/// `_KakeiboBrandBar`'s own doc comment for why this exists (a "richer,
/// radiant" header background per the Dashboard Visual Refresh Pass,
/// rather than a flat gradient with no depth). Purely decorative:
/// `IgnorePointer`-wrapped by its one call site, contributes no
/// semantics of its own (a plain, unlabeled [DecoratedBox] is not a
/// semantics boundary), and painted BEHIND the header's real content,
/// never on top of it.
class _BrandBarGlow extends StatelessWidget {
  const _BrandBarGlow();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: <Color>[
            Colors.white.withValues(alpha: 0.14),
            Colors.white.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

/// Dashboard V1 Finalization checkpoint: the exact 2x2 grid (Monthly
/// Income, Monthly Spending / Remaining Budget, Daily Spending Pace) as
/// four INDEPENDENT [AppCard]s -- explicitly required over one large
/// wrapping card. Reuses [_MetricTile] for Income/Spending/Pace (the
/// exact same widget/data the former single-card [_MonthlyMetricsSection]
/// used for those three) and a new [_RemainingBudgetTile] for the
/// budget figure, reading the SAME [monthlyBudgetSummaryProvider] the
/// full Budget detail screen (`AppRoutes.budgets`) already computes
/// from -- never a second, divergent calculation. Below ~340 logical px (wider
/// than the single-pair 320px threshold elsewhere on this screen,
/// because this grid must fit FOUR cards' worth of icon+label+value
/// content, not two, before two-per-row becomes unreadable) this
/// collapses to one column.
/// Icon-balance visual-polish pass: shared sizing constants for the
/// 2x2 Dashboard metric grid's icon/title/padding geometry.
/// Centralized here -- rather than repeating the same literals across
/// [_MetricTile], [_RemainingBudgetTile], and
/// [_computeMetricsGridTileHeight] -- so the widget tree and the
/// shared-height estimate can never drift out of lockstep with each
/// other, exactly the risk this file's own earlier comments have
/// repeatedly flagged. These replace the former
/// `tokens.iconSizes.largeContainer` (48) / `tokens.spacing.xs` (8) /
/// `tokens.spacing.md * 2` (32) values used for icon-container size,
/// icon-to-title gap, and horizontal card padding on just these four
/// cards; every OTHER screen's icons and cards (e.g.
/// `account_detail_screen.dart`) are completely unaffected, since
/// those still read the shared tokens directly.
const double _metricsGridIconContainerSize = 44.0;
const double _metricsGridIconTitleGap = 6.0;
const double _metricsGridHorizontalPadding = 11.0;
const double _metricsGridMinimumHeight = 106.0;
const double _metricsGridFooterGap = 6.0;

// Local presentation roles for these four cards only. Retain the active
// theme's accessible foregrounds in dark mode; light uses the approved ink.
TextStyle? _metricsValueStyle(BuildContext context) => context.appTypography.smallMoney?.copyWith(
  fontSize: 18,
  height: 1.2,
  letterSpacing: -0.2,
  color: Theme.of(context).brightness == Brightness.light
      ? const Color(0xFF101631)
      : Theme.of(context).colorScheme.onSurface,
);

TextStyle? _metricsSupportingStyle(BuildContext context) => context.appTypography.caption?.copyWith(
  fontSize: 11,
  height: 1.3,
  letterSpacing: 0,
  color: Theme.of(context).brightness == Brightness.light
      ? const Color(0xFF7C879F)
      : Theme.of(context).colorScheme.onSurfaceVariant,
);

/// Icon-balance visual-polish pass: the default icon glyph size for
/// the 2x2 grid, used by the two visually "denser/blockier" glyphs
/// ([Icons.account_balance_wallet_rounded]/[Icons.bar_chart_rounded]).
const double _metricsGridIconGlyphSize = 21.0;

/// Icon-balance visual-polish pass: the two "trending" glyphs
/// ([Icons.trending_up_rounded]/[Icons.trending_down_rounded]) are a
/// thinner arrow-based silhouette that reads as visually LIGHTER than
/// the denser, more solid wallet/bar-chart glyphs above at the exact
/// same numerical [Icon.size] -- a known Material-icon-set quirk, not
/// a bug -- so these two get a small, honestly-caveated 1-logical-
/// pixel optical bump to read as the same visual weight. Both sizes
/// stay inside the user's specified 21-22px range and every icon still
/// shares the identical 44x44 container and corner radius.
const double _metricsGridTrendingIconGlyphSize = 22.0;

/// Icon-balance visual-polish pass: tries the title candidate font
/// sizes largest-first and returns the biggest one at which ALL of
/// [titles] still fit on their own single line within [titleMaxWidth]
/// -- so the four 2x2-grid cards always share one resolved size
/// (never a per-card mismatch) and normal phone width should never
/// actually need [_metricTitleText]'s `TextOverflow.ellipsis`
/// fallback, which remains only for a genuinely-too-narrow width or a
/// very large accessibility text scale. Falls back to the smallest
/// candidate if even that does not fit every title -- still never
/// forcing a second line; the ellipsis fallback covers that extreme
/// case instead, exactly as before this pass.
TextStyle? _resolveMetricsGridTitleStyle({
  required TextStyle? baseStyle,
  required List<String> titles,
  required double titleMaxWidth,
  required TextDirection direction,
  required TextScaler scaler,
}) {
  const List<double> candidateSizes = <double>[11.0, 10.5, 10.0];

  bool fitsAtSize(double fontSize) {
    final TextStyle? candidateStyle = baseStyle?.copyWith(
      fontSize: fontSize,
      fontWeight: FontWeight.w500,
      height: 1.2,
      letterSpacing: 0,
    );
    for (final String title in titles) {
      final TextPainter painter = TextPainter(
        text: TextSpan(text: title, style: candidateStyle),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      if (painter.width > titleMaxWidth) return false;
    }
    return true;
  }

  for (final double fontSize in candidateSizes) {
    if (fitsAtSize(fontSize)) {
      return baseStyle?.copyWith(fontSize: fontSize, fontWeight: FontWeight.w500, height: 1.2, letterSpacing: 0);
    }
  }
  return baseStyle?.copyWith(fontSize: candidateSizes.last, fontWeight: FontWeight.w500, height: 1.2, letterSpacing: 0);
}

class _MonthlyMetricsGrid extends ConsumerWidget {
  const _MonthlyMetricsGrid({required this.summary});

  final CurrencyDashboardSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTokens tokens = context.appTokens;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final TextStyle? valueStyle = _metricsValueStyle(context);
    final TextStyle? labelStyle = _metricsSupportingStyle(context);
    // Icon-balance visual-polish pass: `titleStyle` is no longer a
    // single fixed style computed here -- a responsive font size
    // (resolved inside `LayoutBuilder` below, once the real per-branch
    // tile width is known) replaced the old fixed `labelSmall` so all
    // four titles can render their FULL text on one line at normal
    // phone width instead of ellipsizing. This is the title's BASE
    // style (family/color/weight) that the resolved size is layered
    // onto; `labelSmall` remains the starting Material 3 token, never
    // a new raw literal.
    final TextStyle? titleBaseStyle = textTheme.labelSmall?.copyWith(
      color: labelStyle?.color,
    );
    // The four real title strings the responsive sizing pass measures
    // against -- the exact same labels each tile renders below, never
    // a duplicated/divergent copy.
    final List<String> titleStrings = <String>[
      l10n.incomeThisMonth,
      l10n.spentThisMonth,
      l10n.homeRemainingBudgetLabel,
      l10n.dailySpendingPace,
    ];
    // Reference-layout final pass: the shared tile height computed
    // below needs to know [_RemainingBudgetTile]'s own real state
    // (empty vs configured, whether `remainingDaysInclusive` is set) so
    // the height FORMULA can size the grid around what that tile will
    // actually render, instead of rendering a duplicate widget tree to
    // measure it. Watching the SAME provider [_RemainingBudgetTile]
    // itself watches is not a second calculation -- Riverpod caches the
    // provider's value once per container, so both widgets simply read
    // the one real result.
    final MonthlyBudgetSummary budget = ref.watch(monthlyBudgetSummaryProvider);
    final BudgetCalculation? calculation = budget.calculation;

    // Compactness correction (U3 Final Polish Pass follow-up): a smaller
    // vertical padding than `AppCard`'s own default (`tokens.spacing.md`,
    // 16 on every side) -- LOCAL to these four 2x2 tiles only, via
    // `AppCard.padding`'s own override parameter, never by touching
    // `AppCard`'s default or any other screen's cards.
    //
    // Icon-balance visual-polish pass: horizontal padding tightened
    // further, from `spacing.md` (16/side) to the new shared
    // `_metricsGridHorizontalPadding` (11/side) constant -- freeing the
    // extra width each title needed to fit its full text on one line at
    // normal phone width. Vertical padding is bumped back up, from
    // `spacing.xxs` (4/side) to `spacing.sm` (12/side), as the
    // compensating adjustment that keeps the overall card height near
    // the approved ~106px target now that the "Budget <total>" footer
    // line (and its leading gap) is removed below -- a calculated
    // estimate from this pass's own content-height arithmetic, not a
    // locally-verified measurement (this environment cannot run
    // `flutter test`); please confirm the real rendered height from
    // your own test run. `_computeMetricsGridTileHeight`'s own
    // `verticalPadding`/`cardHorizontalPadding` constants mirror these
    // same values.
    Widget tileCard(Widget child, {Key? key}) {
      return AppCard(
        key: key,
        bordered: true,
        softShadow: true,
        // Neutral surface: accents belong to icons and progress, not the card fill.
        color: colors.surfaceContainerLowest,
        // SVG-reference polish pass: `radii.large` (20) instead of
        // `AppCard`'s own default `radii.medium` (16) -- matches the
        // more generously-rounded "premium" corner radius in the
        // approved `cards.svg` reference (~18-20px) -- an existing
        // token, the same one the Dashboard hero card already uses,
        // never a new raw radius literal.
        radius: tokens.radii.large,
        padding: EdgeInsets.symmetric(
          horizontal: _metricsGridHorizontalPadding,
          vertical: tokens.spacing.sm,
        ),
        child: child,
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool narrow = constraints.maxWidth < 340;
        final double gap = tokens.spacing.sm;
        // Icon-balance visual-polish pass: `tileWidth` is now computed
        // up front for BOTH branches (previously only the non-narrow
        // 2x2 branch needed it) -- the responsive title-size
        // calculation right below needs the real available width
        // whichever layout is active, since the narrow single-column
        // branch gives each card the FULL `constraints.maxWidth`
        // rather than half of it.
        final double tileWidth = narrow
            ? constraints.maxWidth
            : (constraints.maxWidth - gap) / 2;

        // Icon-balance visual-polish pass: the responsive title style
        // is resolved HERE, inside `LayoutBuilder`, because it genuinely
        // needs this real per-branch `tileWidth` -- it could not be
        // computed earlier in `build()`, before this width was known.
        // All four cards still share this ONE resolved style, same as
        // the previous fixed `labelSmall` did; see
        // `_resolveMetricsGridTitleStyle`'s own doc comment for how it
        // picks the size.
        final double titleMaxWidth =
            tileWidth
            - (_metricsGridHorizontalPadding * 2)
            - _metricsGridIconContainerSize
            - _metricsGridIconTitleGap;
        final TextStyle? titleStyle = _resolveMetricsGridTitleStyle(
          baseStyle: titleBaseStyle,
          titles: titleStrings,
          titleMaxWidth: titleMaxWidth,
          direction: Directionality.of(context),
          scaler: MediaQuery.textScalerOf(context),
        );

        // Icon colors are unchanged by this pass -- `tokens.colors.positive`
        // is the theme-PRIMARY color (blue on Light/Dark today -- see
        // `AppSemanticColors.fromColorScheme`'s own doc comment on why it
        // deliberately doesn't hard-code green), not a true green, so
        // Income/Remaining Budget read their green/teal from the SAME real,
        // theme-aware `positiveGradient` family the budget progress bar's
        // healthy state already paints with (see `_budgetStatusGradient`
        // below) -- a centralized, theme-aware green, never a new raw hex
        // constant -- falling back to `positive` for themes that don't opt
        // into a custom gradient (Pink/Ocean/Forest).
        final Widget incomeContent = _MetricTile(
          icon: Icons.trending_up_rounded,
          assetPath: 'assets/icons/dashboard/monthly_income.png',
          iconColor: tokens.colors.positiveGradient?.elementAt(1) ?? tokens.colors.positive,
          label: l10n.incomeThisMonth,
          secondaryLabel: l10n.budgetStatusThisMonth,
          value: summary.income,
          valueStyle: valueStyle,
          labelStyle: labelStyle,
          titleStyle: titleStyle,
          // Icon-balance visual-polish pass: the thinner "trending"
          // glyph gets the +1 optical bump -- see
          // `_metricsGridTrendingIconGlyphSize`'s own doc comment.
          iconGlyphSize: _metricsGridTrendingIconGlyphSize,
        );
        final Widget spendContent = _MetricTile(
          icon: Icons.trending_down_rounded,
          assetPath: 'assets/icons/dashboard/monthly_spending.png',
          // `tokens.colors.negative` is `colorScheme.error` by definition
          // (see `AppSemanticColors.fromColorScheme`) -- same coral/red
          // value as before, just the centralized semantic name instead of
          // reading `colorScheme.error` directly.
          iconColor: tokens.colors.negative,
          label: l10n.spentThisMonth,
          secondaryLabel: l10n.budgetStatusThisMonth,
          value: summary.expense,
          valueStyle: valueStyle,
          labelStyle: labelStyle,
          titleStyle: titleStyle,
          // Icon-balance visual-polish pass: the thinner "trending"
          // glyph gets the +1 optical bump -- see
          // `_metricsGridTrendingIconGlyphSize`'s own doc comment.
          iconGlyphSize: _metricsGridTrendingIconGlyphSize,
        );
        final Widget paceContent = _MetricTile(
          icon: Icons.bar_chart_rounded,
          assetPath: 'assets/icons/dashboard/daily_spending_pace.png',
          // `colors.tertiary` is unchanged -- already the app's "purple"
          // semantic slot on every KakeiboPlus-branded theme; Pink/Ocean/
          // Forest keep whatever their own tuned `tertiary` already is.
          iconColor: colors.tertiary,
          label: l10n.dailySpendingPace,
          secondaryLabel: l10n.dailySpendingPaceDetail,
          value: summary.dailyPace,
          valueStyle: valueStyle,
          labelStyle: labelStyle,
          titleStyle: titleStyle,
        );
        // Icon-balance visual-polish pass: `_RemainingBudgetTile` now
        // takes the SAME resolved `titleStyle` as the other three (see
        // its own constructor), so it is no longer `const` -- harmless,
        // it was only ever `const` because it previously took no
        // arguments at all.
        final Widget remainingBudgetContent = _RemainingBudgetTile(titleStyle: titleStyle);

        final Widget incomeTile = tileCard(incomeContent, key: const Key('monthlyIncomeTile'));
        final Widget spendTile = tileCard(spendContent, key: const Key('monthlySpendingTile'));
        final Widget remainingBudgetTile = tileCard(
          remainingBudgetContent,
          key: const Key('remainingBudgetTile'),
        );
        final Widget paceTile = tileCard(paceContent, key: const Key('dailySpendingPaceTile'));

        if (narrow) {
          return Column(
            children: <Widget>[
              incomeTile,
              SizedBox(height: gap),
              spendTile,
              SizedBox(height: gap),
              remainingBudgetTile,
              SizedBox(height: gap),
              paceTile,
            ],
          );
        }

        // Reference-layout final pass (2x2 card-height correction):
        // the shared height every card gets is now a single real-
        // typography CALCULATION -- see `_computeMetricsGridTileHeight`
        // -- derived from this tile's actual width (`tileWidth`, the
        // same width each `Expanded` cell below actually receives), the
        // context's real text scale, and each tile's real content,
        // rather than rendering an invisible duplicate widget tree and
        // measuring it a frame later. This is what keeps the grid
        // compact: the previous mechanism forced every card up to
        // Remaining Budget's full natural height (its real content has
        // more rows than Income/Spending/Pace), which is taller than
        // the approved compact reference; this formula instead derives
        // one tight shared height from real metrics up front.
        final double sharedHeight = _computeMetricsGridTileHeight(
          context: context,
          tileWidth: tileWidth,
          tokens: tokens,
          l10n: l10n,
          valueStyle: valueStyle,
          labelStyle: labelStyle,
          titleStyle: titleStyle,
          calculation: calculation,
        );

        // A `minHeight`-only floor, not a tight `SizedBox` height: the
        // formula above is a close real-typography estimate, not a
        // live measurement of this exact widget tree, so a card is
        // allowed to grow past `sharedHeight` if its own real content
        // ever needs more room than the estimate gave it (a longer
        // translation, an unusual font metric) -- it simply never
        // clips or overflows. In the normal case the estimate is
        // accurate and every card renders at exactly `sharedHeight`,
        // same visual result as a fixed height would have given.
        Widget cell(Widget tile) {
          return ConstrainedBox(
            constraints: BoxConstraints(minHeight: sharedHeight),
            child: tile,
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: cell(incomeTile)),
                SizedBox(width: gap),
                Expanded(child: cell(spendTile)),
              ],
            ),
            SizedBox(height: gap),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: cell(remainingBudgetTile)),
                SizedBox(width: gap),
                Expanded(child: cell(paceTile)),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Reference-layout final pass: replaces the previous Offstage +
/// IntrinsicHeight + post-frame-measurement equal-height mechanism
/// entirely (that approach rendered a full, invisible SECOND copy of
/// all four cards every frame just to read back their natural height).
/// Because [_RemainingBudgetTile]'s real content was inherently the
/// tallest of the four (more real rows -- amount, days-left, and a
/// progress/percent footer -- versus Income/Spending/Pace's amount
/// plus one supporting line; a former fourth `"Budget <total>"` line was
/// removed in a later pass, see that tile's own build() comment), that
/// mechanism forced every card up to that full natural height, which
/// renders noticeably taller than the approved compact reference.
///
/// This computes one shared height directly instead, using
/// [TextPainter] to lay out each tile's actual label/value/caption
/// strings at the real [TextStyle]s and the context's real
/// [TextScaler] -- so large text scale and longer translations are
/// already accounted for, never a hand-typed magic pixel height -- at
/// the tile's REAL available width (so a title that genuinely needs a
/// second line at 320px, but not at normal phone width, is detected
/// from the actual width passed in, never guessed). No extra widgets
/// are built or painted to do this: it is pure text-metric arithmetic,
/// run once per `build()`, mirroring the exact gap/row structure
/// [_MetricTile] and [_RemainingBudgetTile] actually render below.
double _computeMetricsGridTileHeight({
  required BuildContext context,
  required double tileWidth,
  required AppTokens tokens,
  required AppLocalizations l10n,
  required TextStyle? valueStyle,
  required TextStyle? labelStyle,
  required TextStyle? titleStyle,
  required BudgetCalculation? calculation,
}) {
  final TextScaler scaler = MediaQuery.textScalerOf(context);
  // No explicit `TextDirection` type annotation here -- this file no
  // longer imports `package:intl/intl.dart` (removed as part of the
  // ADR-049 compile/analyzer cleanup, once dead), so there is no
  // longer a real ambiguity to sidestep, but leaving the type
  // inferred from `Directionality.of`'s own return type is still the
  // established convention this file and `goal_detail_screen.dart`'s
  // own `direction` variable both use.
  final direction = Directionality.of(context);
  // Icon-balance visual-polish pass: these three now read the shared
  // `_metricsGridIconContainerSize`/`_metricsGridIconTitleGap`/
  // `_metricsGridHorizontalPadding` constants instead of
  // `tokens.iconSizes.largeContainer`/`tokens.spacing.xs`/
  // `tokens.spacing.md * 2` -- see those constants' own doc comment
  // for why this formula and the real widget tree below must stay in
  // lockstep.
  const double iconContainerSize = _metricsGridIconContainerSize;
  const double iconTitleGap = _metricsGridIconTitleGap;
  const double cardHorizontalPadding = _metricsGridHorizontalPadding * 2;

  double measureLineHeight(TextStyle? style) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: 'Ag', style: style),
      textDirection: direction,
      textScaler: scaler,
    )..layout();
    return painter.height;
  }

  int measureLineCount(String text, TextStyle? style, double maxWidth) {
    if (maxWidth <= 0) return 2;
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: direction,
      textScaler: scaler,
      maxLines: 2,
    )..layout(maxWidth: maxWidth);
    // `maxLines: 2` above already caps this at 2; `math.max(1, ...)`
    // just guards the (never-expected) empty-string/zero-line case so
    // this always returns a genuine line count, never 0.
    return math.max(1, painter.computeLineMetrics().length);
  }

  final double titleMaxWidth =
      tileWidth - cardHorizontalPadding - iconContainerSize - iconTitleGap;
  // Every supporting/caption line (and the Remaining Budget footer
  // text) uses `labelStyle` (`bodySmall`) -- see `_MetricTile`/
  // `_RemainingBudgetTile`'s own styling -- so one measurement covers
  // all of them.
  final double labelLineHeight = measureLineHeight(labelStyle);
  final double valueLineHeight = measureLineHeight(valueStyle);
  // Final reference-match pass: the title now has its OWN distinct
  // style (`titleStyle`, `labelSmall` -- smaller + medium-weight) and
  // is pinned to exactly one line (`_metricTitleText`'s `maxLines: 1`
  // -- "do not intentionally wrap into 2 lines at normal width"), so
  // its height is simply its own single-line height at that style --
  // no width-based line-count measurement needed for the title any
  // more (an over-long translation ellipsizes instead of growing the
  // shared card height, which is the explicit, accepted tradeoff per
  // this pass's own "preserve accessibility and avoid overflow, but
  // normal phone width must be one line" instruction).
  final double titleLineHeight = measureLineHeight(titleStyle);

  // [_MetricTile]: title (1 fixed line), 3px gap, amount, 2px gap,
  // secondary caption -- then maxed against the icon container's own
  // height since both now sit side by side in the same row.
  //
  // The secondary caption's own line count is still REAL-MEASURED per
  // tile (`measureLineCount`, capped at 2) rather than assumed to
  // always be exactly one line -- Income/Spending's short "This month"
  // measures as 1 line; Daily Spending Pace's longer caption genuinely
  // needs up to 2, and only Pace's real height grows to match.
  double metricTileHeight(String? secondary) {
    double tail = 3 + valueLineHeight;
    if (secondary != null) {
      final int secondaryLines = measureLineCount(secondary, labelStyle, titleMaxWidth);
      tail += _metricsGridFooterGap + 5 + secondaryLines * labelLineHeight;
    }
    return math.max(iconContainerSize, titleLineHeight + tail);
  }

  final double incomeHeight = metricTileHeight(l10n.budgetStatusThisMonth);
  final double spendHeight = metricTileHeight(l10n.budgetStatusThisMonth);
  final double paceHeight = metricTileHeight(l10n.dailySpendingPaceDetail);

  // Remaining Budget's own height is still two independent pieces,
  // mirroring the real widget tree: [_RemainingBudgetTile] does not
  // nest its progress-bar/percent footer and "Budget <total>" line
  // inside the icon-indented `Expanded` column (that nesting is what
  // made the real progress bar render far narrower than the card
  // itself -- it was constrained to `tileWidth - padding - icon - gap`
  // instead of `tileWidth - padding`). The TOP area (title/amount/
  // days-left) still sits beside the icon and is still maxed against
  // `iconContainerSize`; the footer is a full-width sibling below it,
  // sized on its own and simply added underneath -- never maxed
  // against the icon, since nothing in the footer row is beside the
  // icon any more.
  double remainingBudgetHeight;
  if (calculation == null) {
    // Empty state: title (1 fixed line), 3px gap, "Not set" (same
    // `valueStyle` family as the configured amount below) -- no footer
    // exists in this state.
    remainingBudgetHeight = math.max(iconContainerSize, titleLineHeight + 3 + valueLineHeight);
  } else {
    final bool hasDaysLeft = calculation.remainingDaysInclusive != null;
    final double topAreaHeight = titleLineHeight
        + 3 // title -> amount
        + valueLineHeight
        // Final card-dimension pass: amount -> days-left gap tightened
        // from 4 to 1, mirroring `_RemainingBudgetTile`'s own matching
        // `SizedBox` change.
        + (hasDaysLeft ? 1 + labelLineHeight : 0); // amount -> days-left (only when shown)
    final double topRowHeight = math.max(iconContainerSize, topAreaHeight);

    // Final card-dimension pass: the progress-bar footer row's own
    // height is the max of the bar's `minHeight` (4, was 6) and the
    // percent-used text beside it.
    final double footerRowHeight = math.max(6.0, labelLineHeight);
    // Icon-balance visual-polish pass (Remaining Budget simplification):
    // the "Budget <total>" line (and its leading gap/former divider)
    // was removed from this Dashboard compact card -- see
    // `_RemainingBudgetTile`'s own matching change -- so the footer is
    // now just the progress-bar/percent-used row itself, with the same
    // "top area -> footer" gap as before.
    final double footerHeight = _metricsGridFooterGap + footerRowHeight;

    remainingBudgetHeight = topRowHeight + footerHeight;
  }

  final double contentHeight =
      <double>[incomeHeight, spendHeight, paceHeight, remainingBudgetHeight].reduce(math.max);
  // Icon-balance visual-polish pass: mirrors `tileCard`'s own
  // vertical padding, bumped back from `tokens.spacing.xxs` (4/side)
  // to `tokens.spacing.sm` (12/side) as the compensating adjustment
  // for the removed "Budget <total>" footer line above -- this
  // constant MUST stay in lockstep with that call site or this
  // formula's floor stops matching what actually renders.
  final double verticalPadding = tokens.spacing.sm * 2;
  return math.max(_metricsGridMinimumHeight, contentHeight + verticalPadding);
}

/// The compact "Remaining Budget" 2x2-grid tile -- Dashboard V1
/// Finalization checkpoint. Reads the SAME [monthlyBudgetSummaryProvider]
/// the full Budget detail screen (`AppRoutes.budgets`) reads from,
/// never a second calculation. Shows the empty state honestly (never a
/// fabricated figure) when no overall budget is configured yet.
///
/// U3 Final Polish Pass (item 2): this tile is now the ONLY
/// budget-progress presentation on Home -- the former full-size
/// `_BudgetCard`/`_ConfiguredBudget` detail card that used to render
/// further down this screen was removed as unnecessary duplication
/// (this tile already showed the same figure); the full detail
/// experience remains on its own screen, completely unchanged.

/// Budget status chooses the existing theme gradient; caution remains in-limit.
Gradient? _budgetStatusGradient(AppTokens tokens, BudgetStatus? status) {
  final List<Color>? stops = switch (status) {
    BudgetStatus.healthy => tokens.colors.positiveGradient,
    BudgetStatus.overBudget => tokens.colors.negativeGradient,
    BudgetStatus.caution => tokens.colors.positiveGradient,
    null => null,
  };
  return _dashboardProgressGradient(stops);
}

Gradient? _dashboardProgressGradient(List<Color>? stops) {
  if (stops == null) return null;
  return LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: stops);
}

class _RemainingBudgetTile extends ConsumerWidget {
  const _RemainingBudgetTile({this.titleStyle});

  /// Icon-balance visual-polish pass: the shared, responsively-sized
  /// title style resolved once by [_MonthlyMetricsGrid.build] and
  /// passed to all four 2x2-grid cards -- falls back to this tile's
  /// own previous inline `labelSmall` style if a future caller omits
  /// it, mirroring [_MetricTile]'s existing `titleStyle ?? labelStyle`
  /// pattern.
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MonthlyBudgetSummary budget = ref.watch(monthlyBudgetSummaryProvider);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final AppTokens tokens = context.appTokens;
    final BudgetCalculation? calculation = budget.calculation;

    // Final U3 Visual Polish Pass: medium icon tile (was small) and
    // the shared [_metricTitleText] helper -- same rationale as
    // [_MetricTile]'s identical change; lets "Remaining Budget" wrap to
    // a second line rather than truncate if a future locale's
    // translation needs more room than English does.
    // Icon swapped from `Icons.savings_outlined` (still used, unchanged,
    // by the real Budget detail screen's own section header) to
    // `Icons.account_balance_wallet_outlined` -- a more literal
    // "wallet/budget" glyph for this specific tile, per this pass's own
    // spec; the two icons are deliberately allowed to differ between
    // this compact tile and that other screen's card.
    //
    // Compactness correction (U3 Final Polish Pass follow-up): icon
    // color was `colors.primary` (the theme-PRIMARY blue) -- switched
    // to the same real, theme-aware green `positiveGradient` family
    // `_MonthlyMetricsGrid.buildIncomeContent` now uses (a different,
    // deeper stop -- "teal/emerald" per the approved reference, versus
    // Income's lighter "green/emerald"), with the same `positive`
    // fallback for themes without a custom gradient (`tokens` is
    // already declared above, from `context.appTokens`).
    // SVG-reference polish pass (Section 4): the icon stays a sibling
    // of the WHOLE text column (title, amount, days-left, progress
    // footer, budget total), not just the title -- same
    // `[icon]   Title / Amount / ...` left-edge alignment as
    // [_MetricTile] above, so every one of the four 2x2 cards shares
    // the identical alignment pattern the reference calls for.
    //
    // Dashboard icon asset pass: swapped from
    // `Icons.account_balance_wallet_outlined` to
    // `Icons.account_balance_wallet_rounded` -- same glyph, same
    // Material Icons font already bundled with the Flutter SDK (no new
    // dependency, no asset download), just the "Rounded" style variant
    // instead of "Outlined". This was the one real family mismatch
    // among the four 2x2 cards: Income/Spending/Pace already use
    // `_rounded` icons (`trending_up_rounded`/`trending_down_rounded`/
    // `bar_chart_rounded`); this tile was the lone `_outlined` one.
    // Now all four belong to the exact same icon family/stroke style,
    // which is what "premium, consistent" actually required here --
    // not a different icon source. The unrelated error-state icon at
    // this file's own `Icons.account_balance_wallet_outlined` call
    // site near the top of this screen (a different, non-2x2-grid
    // card) is intentionally left untouched -- out of this pass's
    // scope.
    // Final reference-match pass: icon bumped to [AppIconTileSize.large]
    // (48/24, was medium 40/20) -- same rationale as [_MetricTile]'s
    // identical change, so all four 2x2 icon containers stay the same
    // size. Title now uses the distinct, slightly smaller, medium-
    // weight `labelSmall` style (was sharing `bodySmall` with the
    // footer text) and [_metricTitleText] itself is now pinned to one
    // line -- see that helper's own updated doc comment.
    // Icon-balance visual-polish pass: container/glyph overrides so
    // this icon shares the EXACT same optical geometry as the other
    // three 2x2-grid icons (see the shared `_metricsGrid*` constants'
    // own doc comment) -- `AppIconTileSize.large` still selects the
    // corner radius, only the container/glyph pixel sizes are
    // overridden. `account_balance_wallet_rounded` is one of the two
    // visually "denser/blockier" glyphs, so it keeps the default
    // `_metricsGridIconGlyphSize` (21) rather than the trending icons'
    // 22.
    final Widget icon = AppIconTile(
      icon: Icons.account_balance_wallet_rounded,
      assetPath: 'assets/icons/dashboard/remaining_budget.png',
      color: tokens.colors.positiveGradient?.elementAt(0) ?? tokens.colors.positive,
      size: AppIconTileSize.large,
      containerSize: _metricsGridIconContainerSize,
      glyphSize: _metricsGridIconGlyphSize,
    );
    // Icon-balance visual-polish pass: uses the shared, responsively-
    // sized `titleStyle` (falling back to the previous inline
    // `labelSmall` style if a future caller omits it) instead of
    // always building its own fixed style inline.
    final Widget title = _metricTitleText(
      l10n.homeRemainingBudgetLabel,
      titleStyle ?? text.labelSmall?.copyWith(color: colors.onSurfaceVariant),
    );

    if (calculation == null) {
      return Row(
        // Align every icon with the top of its text stack.
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          icon,
          // Icon-balance visual-polish pass: tightened from 8 to the
          // shared `_metricsGridIconTitleGap` (6) -- same gap as the
          // other three 2x2-grid cards.
          const SizedBox(width: _metricsGridIconTitleGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                title,
                const SizedBox(height: 3),
                Text(
                  l10n.homeQuickGlanceNotSet,
                  style: _metricsValueStyle(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      );
    }

    final Money remaining = calculation.remaining;
    final Money budgeted = calculation.budgeted;
    final double ratio = budgeted.minorUnits == 0
        ? 0
        : calculation.spent.minorUnits / budgeted.minorUnits;
    // Same pattern as `budgets_screen.dart`'s own `percentUsed`: the
    // displayed percent is unclamped (so e.g. "120% used" is honest
    // when over budget), while the progress bar's own `value` stays
    // clamped to `[0.0, 1.0]` below, exactly as that screen does.
    final int percentUsed = (ratio * 100).round();
    final Color statusColor = switch (calculation.status) {
      BudgetStatus.healthy => colors.primary,
      BudgetStatus.caution => colors.tertiary,
      BudgetStatus.overBudget => colors.error,
      null => colors.onSurfaceVariant,
    };

    // Micro-polish pass: the progress bar/percent footer row and the
    // "Budget <total>" line are no longer nested inside the
    // icon-indented `Expanded` text column -- that constrained the
    // real green progress bar to a much narrower width than the card
    // actually has (card width minus icon, minus gap, minus padding),
    // which is why it rendered too short relative to the reference.
    // Only the TOP area (title/amount/days-left) stays aligned to the
    // icon per Section 4's alignment rule; the footer is a sibling
    // `Column` child below the icon row, so it spans the card's full
    // usable width (card width minus padding only) -- explicitly fine
    // per this pass's own instruction ("OK for the progress row to
    // extend underneath the icon column -- this is a footer/progress
    // area, not part of the title alignment column"). Nothing about
    // `ratio`, `percentUsed`, or `budgeted` changed -- only where the
    // footer sits in the tree.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          // Match the other cards: icon and title start on the same row.
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            icon,
            // Icon-balance visual-polish pass: tightened from 8 to the
            // shared `_metricsGridIconTitleGap` (6).
            const SizedBox(width: _metricsGridIconTitleGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  title,
                  // Final reference-match pass: tightened from 4px to
                  // 3px, same "bring the amount closer to the title"
                  // rhythm as [_MetricTile]'s identical change.
                  const SizedBox(height: 3),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _formatter.format(remaining),
                      style: _metricsValueStyle(context)?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: remaining.isNegative ? colors.error : null,
                      ),
                    ),
                  ),
                  // Reference-layout pass: the "X days left" supporting
                  // line is its own row (matching Income/Spending's
                  // single supporting-text line directly under the
                  // amount). Nothing here is fabricated: `daysLeft` is a
                  // pre-existing real figure already computed above;
                  // only its layout changed.
                  if (calculation.remainingDaysInclusive != null) ...<Widget>[
                    // Final card-dimension pass: tightened from 4px to
                    // 1px -- "Left for N days" sits directly under the
                    // amount with the same very-tight rhythm as the
                    // title->amount gap above it, needed to bring this
                    // tile's top block down toward the ~100px card
                    // target. No text, figure, or financial meaning
                    // changed, only the gap.
                    const SizedBox(height: 1),
                    Text(
                      l10n.homeBudgetDaysLeftLabel(calculation.remainingDaysInclusive!),
                      style: _metricsSupportingStyle(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        // Separate the summary from its existing progress footer.
        const SizedBox(height: _metricsGridFooterGap),
        // Micro-polish pass: this progress/percent row now spans the
        // card's full usable width (a direct `Column` child, not
        // nested under the icon-indented `Expanded` any more) -- the
        // real fix for "the green bar is too short": it was never a
        // rendering bug in `AppProgressBar`/the gradient, only the
        // width it was ever given. Gradient, rounded ends (via
        // `AppProgressBar`'s own `minHeight`-derived corner radius),
        // and the real percent-used readout are all unchanged.
        LayoutBuilder(
          builder: (context, constraints) {
            final label = l10n.percentUsedLabel('$percentUsed');
            final style = _metricsSupportingStyle(context)?.copyWith(
              fontWeight: FontWeight.w600,
            );
            final painter = TextPainter(
              text: TextSpan(text: label, style: style),
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
            )..layout();
            final stackFooter = painter.width + 8 + 24 > constraints.maxWidth;
            painter.dispose();
            final progress = AppProgressBar(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 6,
              color: statusColor,
              gradient: _budgetStatusGradient(tokens, calculation.status),
              semanticLabel: label,
              trackKey: const Key('remainingBudgetProgressTrack'),
            );
            // Keep the percentage readable and the track useful at large
            // text scales or with longer translations; never shrink the text.
            if (stackFooter) {
              return Column(
                key: const Key('remainingBudgetProgressFooterRow'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  progress,
                  const SizedBox(height: 4),
                  Text(label, style: style),
                ],
              );
            }
            return Row(
              key: const Key('remainingBudgetProgressFooterRow'),
              children: <Widget>[
                Expanded(child: progress),
                const SizedBox(width: 8),
                Text(label, style: style, maxLines: 1),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// The strongest element on the screen: the user's total available
/// balance, large and unmissable, so "am I okay with money?" is
/// answerable within a few seconds.
///
/// # Design Reversal Checkpoint (KakeiboPlus header reference)
///
/// Supersedes Checkpoint U3's "THIS MONTH / remaining-this-month"
/// headline: the headline metric is back to
/// [CurrencyDashboardSummary.availableBalance] -- the SAME existing,
/// already-tested balance figure this card headlined before U3, now
/// labeled with the new [AppLocalizations.dashboardTotalBalanceLabel]
/// ("TOTAL BALANCE") eyebrow instead of the old per-currency code +
/// currency-badge row, which this card no longer renders at all.
/// [CurrencyDashboardSummary.remainingThisMonth] (U3's `income -
/// expense` figure, docs/23 §5.2) is NOT deleted -- it simply is no
/// longer displayed here, per this checkpoint's own "no data-semantic
/// rewrites, presentation only" constraint; [_MonthlyMetricsGrid]
/// still shows Income/Expense/Daily-pace directly below this card, so
/// that information is not lost, only not duplicated inside the hero.
/// (U3 Final Polish Pass: every OTHER currency the user holds, and the
/// per-currency-code/badge row this paragraph originally contrasted
/// against, no longer render anywhere on Home at all -- see
/// `HomeScreen.build`'s own doc comment on that removal.)
/// [_LivingCurrencyEquivalentLine] is kept, immediately under the
/// headline, as the one small secondary converted-amount line this
/// checkpoint's own spec explicitly allows.
///
/// # Dashboard V1 Finalization checkpoint (mascot layout)
///
/// The mascot (docs/23 §6) now lives in a `Stack` positioned at the
/// card's bottom-right corner, deliberately allowed to bleed past its
/// own bounds into the card's padding/corner (`Stack.clipBehavior:
/// Clip.none`, cropped cleanly by the outer [AppCard]'s own
/// `Clip.antiAlias`) so it can read as "integrated into the card" and
/// occupy a substantially larger, more visible share of the hero
/// (docs/23 §6.2's "intentional lower crop is acceptable") -- this
/// class's older doc comment (below) described a `Row`/`Expanded`
/// sibling instead; that approach could not grow the mascot without
/// also shrinking the amount's available width, since both shared one
/// `Row`'s flex budget.
///
/// The new layout keeps docs/23 §6.3's "never cover the main amount" /
/// "never cover income/expense labels" guarantee by a DIFFERENT,
/// stronger construction: the financial content sits in a
/// [FractionallySizedBox] fixed to the card's left 62% width,
/// independent of the mascot entirely -- so growing the mascot (up to
/// its own clamped max) can never encroach on the text's reserved
/// space, unlike a shared-`Row`-flex design where a larger mascot would
/// necessarily take width away from the amount. [DashboardMascot]'s own
/// doc comment still gives the same reasoning from the mascot widget's
/// side. The mascot's height itself now scales with the card's own
/// measured width (`LayoutBuilder`, clamped 64-140 logical px) rather
/// than a fixed constant, satisfying docs/23 §17's "priority rule on
/// constrained widths" (financial text before mascot size) responsively
/// instead of via one fixed breakpoint.
///
/// The paragraph below describes the PRIOR (`Row`/`Transform.translate`)
/// mascot mechanism and is retained only as historical context for the
/// design decision it documents; it no longer describes the current
/// code.
class _HeroCurrencyCard extends StatelessWidget {
  const _HeroCurrencyCard({required this.summary, required this.livingCurrencyCode});

  final CurrencyDashboardSummary summary;

  /// CP9.5 Task F: the profile's living currency, threaded down purely
  /// so [_LivingCurrencyEquivalentLine] can decide whether this card
  /// needs a "≈ `<living currency amount>`" line at all (never when this
  /// card's own currency already IS the living currency).
  final String livingCurrencyCode;

  /// The mascot PNG's own real pixel dimensions (`assets/branding/pets/
  /// kakeiboplus_dog_default.png`, confirmed 1247x1261) -- used to
  /// derive the mascot's rendered WIDTH from a safety-bounded value
  /// (see the mascot-sizing block in `build()` below) rather than
  /// letting `Image.asset`'s own `BoxFit.contain` width-from-height
  /// derivation be the only thing standing between it and the text
  /// column. Every alternate mascot in `assets/branding/pets/` is a
  /// distinct character illustration, not guaranteed to share this
  /// exact ratio -- if a future checkpoint makes the mascot selectable,
  /// this constant needs to become per-`MascotKey` (or read from the
  /// decoded image) rather than staying a single hardcoded ratio.
  static const double _mascotAspectRatio = 1247 / 1261;

  /// Minimum guaranteed horizontal clearance between the mascot and the
  /// text column, independent of either's font metrics -- see the
  /// mascot-sizing block's own doc comment in `build()`.
  static const double _mascotGap = 12;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final AppTokens tokens = context.appTokens;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool isNegative = summary.availableBalance.isNegative;

    // Checkpoint U3 (docs/23 §9/§11): the fixed KakeiboPlus teal/mint
    // hero gradient -- `null` on Pink/Ocean/Forest (see
    // `AppSemanticColors.heroGradient`'s own doc comment), in which case
    // this card keeps its original flat `primaryContainer` fill/
    // `onPrimaryContainer` foreground, completely unchanged.
    final List<Color>? heroGradientColors = tokens.colors.heroGradient;
    final Gradient? heroGradient = heroGradientColors == null
        ? null
        : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: heroGradientColors,
          );
    // docs/23 §11 "Hero foreground: main amount: white, main labels:
    // white" -- only applied when the fixed gradient is actually
    // painted; Pink/Ocean/Forest keep their own already-tuned
    // `onPrimaryContainer` contrast against their own flat fill.
    final Color heroForeground = heroGradient != null ? Colors.white : colors.onPrimaryContainer;
    final Color heroForegroundMuted = heroForeground.withValues(alpha: 0.85);

    return AppCard(
      key: Key('heroCurrencyCard_${summary.currencyCode}'),
      color: colors.primaryContainer,
      gradient: heroGradient,
      radius: tokens.radii.xl,
      padding: EdgeInsets.all(tokens.spacing.lg),
      // Dashboard V1 Finalization checkpoint: the mascot moved from a
      // `Row`/`Expanded` sibling (see this class's older doc comment,
      // above) to a `Stack` with the financial `Column` WIDTH-CAPPED via
      // `FractionallySizedBox` to the card's left ~62% -- a STRONGER
      // non-overlap guarantee than the old `Row`, not a weaker one: the
      // money text's available width is now fixed by that fraction
      // regardless of how large the mascot grows, rather than the two
      // sharing one `Row`'s flex budget. `clipBehavior: Clip.none` on
      // the inner `Stack` deliberately lets the mascot bleed past its
      // own bounds into the card's padding/corner (docs/23 §6.2
      // "intentional lower crop is acceptable") -- the OUTER `AppCard`'s
      // own `Clip.antiAlias` (see `app_card.dart`) still crops it
      // cleanly to the card's rounded corner, so nothing ever paints
      // outside the card itself.
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          // Scales with the card's own width (docs/23 §17's "priority
          // rule on constrained widths": financial text/labels/controls
          // before mascot size) rather than a fixed pixel height, so a
          // narrow phone gets a proportionally smaller mascot instead of
          // either crowding the amount or clipping unpredictably.
          //
          // Part B (U3 narrow-screen investigation, docs/14): the
          // previous version derived this purely from
          // `constraints.maxWidth * 0.34` with no relationship to the
          // text column's own `FractionallySizedBox(widthFactor: 0.62)`
          // width -- on real measured text (the "TOTAL BALANCE" eyebrow
          // in its actual letter-spaced style), that left too little
          // clearance and the mascot genuinely overlapped it (see
          // `home_screen_test.dart`'s "hero mascot does not overflow"
          // test, which caught a real `Rect.overlaps` -- not a stale
          // test). Rather than guess at new magic-number margins, this
          // now derives the mascot's WIDTH from a guarantee that holds
          // regardless of font metrics: [DashboardMascot]'s own
          // `BoxFit.contain` text/`Image.asset` never paints wider than
          // its own box, and a plain `Text` never paints wider than the
          // `FractionallySizedBox`-allocated text column (it wraps
          // instead) -- so bounding the mascot's width to whatever is
          // left of that column, minus an explicit safety [_mascotGap],
          // makes overlap structurally impossible rather than merely
          // unlikely. The mascot still bleeds `tokens.spacing.sm`
          // further right via `Positioned.right` below, adding margin
          // on top of this, not counted against the guarantee.
          final double textZoneWidth = constraints.maxWidth * 0.62;
          final double naturalMascotHeight =
              (constraints.maxWidth * 0.34).clamp(64.0, 140.0);
          final double naturalMascotWidth =
              naturalMascotHeight * _mascotAspectRatio;
          final double maxSafeMascotWidth =
              (constraints.maxWidth - textZoneWidth - _mascotGap).clamp(0.0, double.infinity);
          final double mascotWidth = naturalMascotWidth < maxSafeMascotWidth
              ? naturalMascotWidth
              : maxSafeMascotWidth;
          final double mascotHeight = mascotWidth / _mascotAspectRatio;

          // Without an explicit minimum, the card's own height would be
          // determined purely by the text column (the only non-
          // positioned child a `Stack` sizes itself from) -- shorter
          // than the mascot in most cases -- and the mascot's bottom
          // portion would then be clipped away by the OUTER `AppCard`'s
          // own `Clip.antiAlias` well before its intended crop point,
          // leaving only a small sliver visible instead of the
          // "substantial portion of the hero" docs/23 §6.2/Request D
          // call for. This floors the Stack's height at the mascot's own
          // height so the card always has room for it.
          // Final U3 Visual Polish Pass (mascot vertical balance): the
          // Stack's minimum height is now `mascotHeight` PLUS a small
          // fixed breathing-room increment (`tokens.spacing.md`), not
          // `mascotHeight` alone. Previously the Stack had exactly zero
          // slack once the mascot dominated its sizing (the common
          // case on phone widths), so the mascot's bottom edge had
          // nowhere to go but past the Stack's own bottom -- forced to
          // bleed/crop by the full amount of its own top clearance,
          // reading as "stuck to the bottom edge." This extra
          // increment gives the card a little real vertical room so
          // the mascot's bottom sits closer to (usually just barely
          // past) the card's own bottom, instead of always cropping by
          // the same amount as its top clearance. See the mascot's own
          // `Positioned` below for the other half of this change.
          final double mascotStackMinHeight = mascotHeight + tokens.spacing.md;
          return ConstrainedBox(
            constraints: BoxConstraints(minHeight: mascotStackMinHeight),
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
              // Design Reversal Checkpoint (docs/14 Part A): forces this
              // `Stack` -- and therefore this `AppCard` -- to occupy the
              // FULL width `LayoutBuilder` actually received, matching
              // the Dashboard's other full-width sections (the 2x2
              // metrics grid, Upcoming/Spending/Savings). Without this,
              // a `Stack` given loose width constraints sizes itself to
              // its widest NON-positioned child -- here, the
              // `FractionallySizedBox` below, which is only 62% of
              // `constraints.maxWidth` -- so the hero card was silently
              // shrink-wrapping to ~62% of the available width instead
              // of filling it (caught by the hero-width regression
              // check in `home_screen_test.dart`). This child is
              // invisible (zero height) and purely a sizing anchor --
              // it paints nothing and never intercepts a gesture.
              SizedBox(width: constraints.maxWidth),
              FractionallySizedBox(
                widthFactor: 0.62,
                alignment: Alignment.topLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      l10n.dashboardTotalBalanceLabel,
                      style: context.appTypography.eyebrow?.copyWith(color: heroForegroundMuted),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (isNegative)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Icon(Icons.south_rounded, color: heroForeground, size: 22),
                          ),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: AppMoneyText(
                              _formatter.format(summary.availableBalance),
                              emphasis: AppMoneyEmphasis.hero,
                              color: heroForeground,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (summary.currencyCode != livingCurrencyCode) ...<Widget>[
                      const SizedBox(height: 8),
                      _LivingCurrencyEquivalentLine(
                        key: Key('livingCurrencyEquivalent_${summary.currencyCode}'),
                        currencyCode: summary.currencyCode,
                        livingCurrencyCode: livingCurrencyCode,
                        balance: summary.availableBalance,
                        tint: heroForegroundMuted,
                      ),
                    ],
                    // Checkpoint J (docs/20 §13.14): Home shows available/
                    // liquid money ONLY -- no net-worth figure of any kind
                    // renders anywhere on this screen, for any currency,
                    // ever. `CurrencyDashboardSummary.netWorth` itself is
                    // UNCHANGED and still computed the same way -- only
                    // this screen's UI never displays it (see
                    // `NetWorthScreen` for where net worth IS shown, on a
                    // deliberate tap only). docs/23 §5.1's identical ban
                    // on a Net Worth hero is satisfied by the same,
                    // still-unchanged fact.
                  ],
                ),
              ),
              // Dashboard Visual Refresh Pass (docs/design/
              // dashboard-referancenew.png): two small, low-alpha
              // sparkle accents echoing the reference's own decorative
              // sparkles beside the mascot -- positioned using the SAME
              // `mascotWidth`/`mascotHeight` budget the mascot itself is
              // bounded by, so they can never land inside the reserved
              // text-column width regardless of screen size (the same
              // structural guarantee `_mascotGap`/`maxSafeMascotWidth`
              // already give the mascot). `IgnorePointer`-wrapped and
              // excluded from semantics -- purely decorative, never a
              // control.
              Positioned(
                right: mascotWidth * 0.62,
                top: mascotHeight * 0.04,
                child: IgnorePointer(
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white.withValues(alpha: 0.55),
                    size: (mascotWidth * 0.09).clamp(10.0, 16.0),
                  ),
                ),
              ),
              Positioned(
                right: mascotWidth * 0.02,
                top: mascotHeight * 0.32,
                child: IgnorePointer(
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white.withValues(alpha: 0.35),
                    size: (mascotWidth * 0.06).clamp(8.0, 12.0),
                  ),
                ),
              ),
              Positioned(
                right: -tokens.spacing.sm,
                // Final U3 Visual Polish Pass (mascot vertical
                // balance): switched from a `bottom:` anchor to an
                // explicit `top:` anchor, still using the exact same
                // `tokens.spacing.lg` clearance the Design Reversal
                // Checkpoint (docs/14 Part B) validated as sufficient
                // to keep the mascot clear of the "TOTAL BALANCE"
                // eyebrow row at the narrowest tested width (320px) --
                // that clearance is NOT reduced by this change, so the
                // no-overlap guarantee this class's own width/height
                // math already provides (see `maxSafeMascotWidth`
                // above) is unaffected. What DOES change is where the
                // "slack" from `mascotStackMinHeight`'s new breathing-
                // room increment (see the `ConstrainedBox` above) goes:
                // previously (bottom-anchored) it had nowhere to go and
                // the mascot always bled/cropped by the full top-
                // clearance amount at the bottom; now (top-anchored)
                // that increment opens up genuine space BELOW the
                // mascot instead, so it visually reads as sitting
                // higher/more centered in the card's right side rather
                // than pinned to the bottom edge. Any remaining bottom
                // bleed is now small and incidental, not the dominant
                // visual effect it was before -- the face stays fully
                // visible either way, only the lower body/paws can
                // still crop.
                // `_mascotAspectRatio`/`mascotWidth`/`mascotHeight` are
                // unchanged -- only the vertical anchor moved.
                top: tokens.spacing.lg,
                // Part B (U3 narrow-screen investigation, docs/14): the
                // `Key('dashboardMascot')` used to sit directly on
                // `DashboardMascot`, whose own `Image.asset` derives its
                // WIDTH from the decoded PNG's aspect ratio (see that
                // widget's own doc comment: "width follows automatically
                // via BoxFit.contain") -- before the asset finishes
                // decoding, `RenderImage` has no aspect ratio to derive a
                // width from and reports a zero-width box even though the
                // explicit `height` still lays out normally. A widget
                // test's `tester.getRect(find.byKey(Key('dashboardMascot')))`
                // caught exactly this: a real, captured `Rect` with
                // `left == right` (zero width) but a plausible non-zero
                // height, which made every `Rect.overlaps()` check against
                // it vacuously pass -- the test was never actually
                // validating overlap. Moving the key to this `SizedBox`,
                // which is given BOTH `mascotWidth` and `mascotHeight`
                // directly (already derived above from
                // `_mascotAspectRatio`, independent of the decoded image),
                // makes the measured box deterministic regardless of
                // decode timing -- for the test, and for production, where
                // it also now avoids a possible one-frame layout shift
                // between "not yet decoded" and "decoded" sizes.
                // `DashboardMascot`'s own `height` parameter is
                // deliberately left at its default: this outer `SizedBox`
                // gives the child tight constraints, which always win over
                // an inner widget's own declared size, so setting it here
                // too would be redundant.
                child: SizedBox(
                  key: const Key('dashboardMascot'),
                  width: mascotWidth,
                  height: mascotHeight,
                  child: const DashboardMascot(),
                ),
              ),
              ],
            ),
          );
        },
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

/// Final reference-match pass: renders a 2x2 metric tile's title
/// pinned to ONE line. Previously allowed up to two lines (and the
/// shared card height budgeted for that), but the approved reference
/// shows every title on a single line, and the instruction is explicit
/// -- "do not intentionally wrap them into 2 lines at normal width" --
/// so this now matches that directly: `maxLines: 1` always, with
/// `overflow: TextOverflow.ellipsis` as the graceful fallback ONLY for
/// a genuinely-too-narrow width or very large accessibility text scale
/// (never a silent truncation under normal conditions -- the caller's
/// own [titleStyle]/available column width are chosen so normal
/// English titles fit without ever reaching the ellipsis case).
Widget _metricTitleText(String label, TextStyle? style) {
  return Text(label, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
}

/// One labeled money value with a leading icon, optionally with a small
/// secondary explanation line underneath. The value is wrapped in a
/// [FittedBox] so a large formatted amount shrinks to fit rather than
/// clipping or overflowing on a narrow screen.
///
/// U3 Final Polish Pass (2x2 card-height regression fix): the former
/// `wide` flag (and the per-tile `_reservedBudgetFooterHeight` magic-
/// number footer it used to pair with) were removed -- no caller ever
/// passed `wide`, and all four 2x2 cards now share one real height
/// computed by [_computeMetricsGridTileHeight] above, so neither is
/// needed any more.
class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.assetPath,
    required this.iconColor,
    required this.label,
    required this.value,
    this.secondaryLabel,
    this.valueStyle,
    this.labelStyle,
    this.titleStyle,
    this.iconGlyphSize = _metricsGridIconGlyphSize,
  });

  final IconData icon;
  final String assetPath;
  final Color iconColor;
  final String label;
  final Money value;
  final String? secondaryLabel;
  final TextStyle? valueStyle;
  final TextStyle? labelStyle;

  /// Icon-balance visual-polish pass: per-icon optical-size override
  /// (see the shared `_metricsGrid*` constants' own doc comment) --
  /// defaults to the "denser/blockier" glyph size; callers whose icon
  /// is one of the thinner "trending" glyphs pass
  /// `_metricsGridTrendingIconGlyphSize` instead. The container size
  /// (`_metricsGridIconContainerSize`) is NOT overridable per call --
  /// every 2x2-grid icon must share the identical container for the
  /// icons to look optically balanced.
  final double iconGlyphSize;

  /// Final reference-match pass: a distinct (smaller, medium-weight)
  /// style for the title only -- see `_MonthlyMetricsGrid.build`'s own
  /// `titleStyle` doc comment. Falls back to [labelStyle] so this
  /// widget still renders sensibly if a future caller forgets to pass
  /// it (never a hard `!`/crash).
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    // SVG-reference polish pass (Section 4 -- title/amount/caption
    // alignment): title, amount, and the optional caption now live
    // together in ONE column to the right of the icon, instead of the
    // title sharing a row with the icon while amount/caption sat in a
    // separate full-width row below (which left amount/caption flush
    // with the ICON's own left edge, not the title's). This is the
    // exact `[icon]   Title / Amount / Caption` structure from the
    // approved reference, with title/amount/caption all sharing one
    // left edge. `_computeMetricsGridTileHeight` mirrors this exact
    // nesting (icon-row height = max(icon container, text-column
    // height), not the old title-row-only calculation) so the shared
    // grid height still matches real layout.
    //
    // One aligned text column beside a consistently top-aligned icon.
    final Widget content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Final reference-match pass: bumped from
        // [AppIconTileSize.medium] (40/20) to [AppIconTileSize.large]
        // (48/24) -- matches the reference's visibly larger icon
        // block ("icon container around 44-48px, glyph around
        // 22-24px") via the SAME existing size tier every other icon
        // in the app already uses, not a new one-off dimension. Still
        // the exact same `icon`/`iconColor` the caller already
        // resolved, and still the same soft-tinted-container idiom
        // [AppIconTile] already provides (0.14-alpha tint behind a
        // full-opacity glyph), so every theme keeps re-tinting for
        // free.
        AppIconTile(
          icon: icon,
          assetPath: assetPath,
          color: iconColor,
          size: AppIconTileSize.large,
          containerSize: _metricsGridIconContainerSize,
          glyphSize: iconGlyphSize,
        ),
        // Icon-balance visual-polish pass: tightened from 8 to the
        // shared `_metricsGridIconTitleGap` (6).
        const SizedBox(width: _metricsGridIconTitleGap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Final reference-match pass: now pinned to ONE line
              // (see [_metricTitleText]'s own updated doc comment) at
              // the distinct, slightly smaller `titleStyle` instead of
              // sharing `labelStyle` with the caption below -- matches
              // the reference's compact single-line title treatment
              // without touching the caption's own (unchanged) style.
              _metricTitleText(label, titleStyle ?? labelStyle),
              // Final reference-match pass: tightened from 4px to 3px
              // -- "bring the amount closer to the title" -- still
              // within the requested 2-4px rhythm, just the tighter
              // end of it.
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(_formatter.format(value), style: valueStyle),
              ),
              if (secondaryLabel != null) ...<Widget>[
                const SizedBox(height: _metricsGridFooterGap),
                // Micro-polish pass: was pinned to a single line with
                // an ellipsis, which truncated Daily Spending Pace's
                // longer caption ("Average spend per day so far this
                // month") to "Average spen...". Now allows a real
                // second line instead -- `_computeMetricsGridTileHeight`
                // measures each tile's OWN real caption line count (1
                // for Income/Spending's short "This month", genuinely
                // up to 2 for Pace's longer string) rather than
                // assuming every caption is exactly one line, so the
                // shared grid height already accounts for whichever
                // card actually needs the second line -- no "height
                // explosion": the formula only adds the extra line's
                // real measured height, never a guess. `maxLines: 2`
                // still caps it (and `overflow: ellipsis` remains a
                // safety fallback only reached at extreme text-scale
                // combinations the formula didn't anticipate).
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: context.appTokens.colors.subtleBorder),
                    ),
                  ),
                  child: Text(
                    secondaryLabel!,
                    style: labelStyle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
    return content;
  }
}

// Dashboard V1 Finalization checkpoint: `_StatusMetricTile` and
// `_BudgetGoalsQuickGlanceRow` (the former Budgets/Savings-Goals
// "at a glance" pair) were removed here -- superseded by
// `_MonthlyMetricsGrid`'s Remaining Budget tile (real progress detail,
// not just a status word) plus the Savings Goals section now living in
// its own full card below (see this checkpoint's own report, item 4).
// Neither widget had any other call site.

// U3 Final Polish Pass (item 2): `_BudgetCard`/`_ConfiguredBudget` --
// the former full-size Budget detail card that used to render at the
// end of this screen -- were removed here. Remaining Budget was
// already represented in the 2x2 metrics grid above
// (`_RemainingBudgetTile`/`Key('remainingBudgetTile')`), so the full
// card was unnecessary duplication on Home, not a distinct feature.
// Presentation-only: `BudgetCalculation`, every budget repository/
// provider, and the full Budget detail experience (progress bar,
// status chip, percentage, daily recommendation, "Manage") all remain
// completely intact on their own screen (`AppRoutes.budgets`), reachable
// from the 2x2 tile and from More/Budgets navigation. See
// `HomeScreen.build`'s own doc comment for the full removal rationale.

/// Pairs an authoritative primary money value with a secondary
/// descriptive value (a target/budgeted amount prefixed with "of ", or a
/// scheduled date) -- International / Localization Foundation
/// Checkpoint 5.1. Shared by [_PriorityGoalSummary] and
/// [_RecurringItemSummary] (U3 Final Polish Pass, item 2: the former
/// third caller, `_ConfiguredBudget`, was removed along with the Home
/// Budget detail card it belonged to), which each had the same
/// underlying gap:
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppSectionHeader(
            assetPath: 'assets/icons/dashboard/savings_goal.png',
            assetSize: 28,
            titleStyle: context.appTypography.sectionTitle?.copyWith(fontSize: 14),
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
        const SizedBox(height: 6),
        AppCard(
      // Checkpoint 10 Visual Convergence follow-up: the flag icon this
      // card shares with the Home quick-glance row's goal tile is why
      // this key exists (U3 Final Polish Pass, item 2: the former
      // `Key('budgetCard')` this comment used to cross-reference was
      // removed along with the Home Budget detail card it belonged to).
      key: const Key('savingsGoalsCard'),
      // Final U3 Visual Polish Pass: bordered-only, no lift --
      // Budgets/Goals/Upcoming stay in the quieter tier, visibly
      // less prominent than the monthly metrics card, which now
      // carries the soft shadow instead.
      bordered: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[

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
        ),
      ],
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
        AppProgressBar(
          value: ratio.clamp(0.0, 1.0),
          minHeight: 6,
          color: calc.status == SavingsGoalStatus.overdue
              ? context.appTokens.colors.negative : context.appTokens.colors.positive,
          gradient: _dashboardProgressGradient(calc.status == SavingsGoalStatus.overdue
              ? context.appTokens.colors.negativeGradient
              : context.appTokens.colors.positiveGradient),
          semanticLabel: '${summary.name}: ${calc.wholePercentSaved}%',
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

/// Compact multi-row "Upcoming" card (docs/14_DECISION_LOG.md ADR-049,
/// superseding ONLY this ADR-023 point 8's "Home shows exactly one
/// item" decision). Shows every overdue item, every due-today item,
/// and every upcoming item scheduled within the next 7 calendar days
/// (inclusive) -- capped to [kHomeUpcomingMaxRows] rows, overdue-first
/// -- via [homeUpcomingItemsProvider] (additive on top of the existing
/// [recurringPendingItemsProvider]; never a second calculation engine).
/// Each row keeps its own item's own currency: recurring rules can span
/// multiple currencies and `Money.operator+` throws on a currency
/// mismatch by design (ADR-017), so this card still never adds amounts
/// together across rows -- exactly the same no-fabricated-total rule
/// [_SavingsGoalsCard] follows for goals and ADR-023 point 8 already
/// established here, just no longer limited to a single row.
///
/// [homeRecurringSelectionProvider]/[selectHomeRecurringItem] (the
/// single-item selector this card used before ADR-049) are left
/// completely unchanged and are no longer read here -- they keep their
/// own dedicated, still-passing test coverage in
/// `recurring_providers_test.dart`.
class _UpcomingCommitmentsCard extends ConsumerWidget {
  // CP5.1: accepts a key so tests can deterministically scroll the
  // Home ListView until this card is mounted (`tester.scrollUntilVisible`)
  // instead of relying on a tall-enough fixed viewport -- presentation-only,
  // no behavior change.
  const _UpcomingCommitmentsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<RecurringPendingItem>> itemsAsync = ref.watch(homeUpcomingItemsProvider);
    final List<RecurringPendingItem>? items = itemsAsync.valueOrNull;
    // ADR-049: every row needs the SAME normalized "today" instant
    // `homeUpcomingItemsProvider` itself filtered against, for its own
    // "In N days" relative-date text -- never a second, independently
    // -derived `DateTime.now()` call.
    final DateTime todayUtc = ref.watch(recurringTodayUtcProvider);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokens tokens = context.appTokens;
    final ColorScheme colors = Theme.of(context).colorScheme;

    // ADR-049 / this checkpoint's "category/type badge" + "identity
    // icon precedence" specs: resolved via the EXACT existing
    // `categoriesForTypeProvider` map-building pattern
    // `activity_screen.dart` already established (two watches, one
    // local id->row map) -- no new provider, no per-row family watch,
    // and no second category-lookup mechanism.
    final AsyncValue<List<CategoryRow>> expenseCategoriesAsync =
        ref.watch(categoriesForTypeProvider('expense'));
    final AsyncValue<List<CategoryRow>> incomeCategoriesAsync =
        ref.watch(categoriesForTypeProvider('income'));
    final Map<String, CategoryRow> categoriesById = <String, CategoryRow>{
      for (final CategoryRow c in expenseCategoriesAsync.valueOrNull ?? const <CategoryRow>[]) c.id: c,
      for (final CategoryRow c in incomeCategoriesAsync.valueOrNull ?? const <CategoryRow>[]) c.id: c,
    };

    late final Widget body;
    if (items == null) {
      body = const SizedBox(
        height: 24,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    } else if (items.isEmpty) {
      // Dashboard V1 Finalization checkpoint's warm, calm empty state
      // (docs/23-adjacent "financial-app-ui-ux-designer" skill §1.2
      // "calm, not alarming") -- UNCHANGED by ADR-049, per this
      // checkpoint's own "reuse the existing empty-state treatment,
      // do not build a new one" instruction. Same condition it always
      // was: no overdue, no due-today, and (now) no upcoming item
      // within the 7-day window either.
      body = Container(
        key: const Key('upcomingEmptyState'),
        padding: EdgeInsets.all(tokens.spacing.md),
        decoration: BoxDecoration(
          color: tokens.colors.warmCardSurface ?? colors.surfaceContainerHighest,
          borderRadius: tokens.radii.mediumRadius,
          border: Border.all(color: tokens.colors.warmCardBorder ?? colors.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AppIconTile(
                  icon: Icons.calendar_month_rounded,
                  color: tokens.colors.warmCardForeground ?? colors.primary,
                  size: AppIconTileSize.medium,
                ),
                SizedBox(width: tokens.spacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        l10n.homeUpcomingEmptyTitle,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: tokens.colors.warmCardForeground,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.homeUpcomingEmptySubtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: tokens.colors.secondaryText,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: tokens.spacing.xs),
            Text(
              l10n.homeUpcomingEmptyDescription,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: tokens.colors.secondaryText,
                  ),
            ),
            SizedBox(height: tokens.spacing.sm),
            // Part A (U3 narrow-screen investigation, docs/14): see
            // this button's own long-standing comment history --
            // rebuilt by hand (never `OutlinedButton.icon`) so its
            // label can ellipsize under a squeezed width instead of
            // overflowing. Unchanged by ADR-049.
            OutlinedButton(
              key: const Key('setRecurringRuleButton'),
              onPressed: () => context.push(AppRoutes.recurring),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.add_rounded, size: 18),
                  SizedBox(width: tokens.spacing.xs),
                  Flexible(
                    child: Text(
                      l10n.setUpRecurringButton,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      body = _UpcomingList(items: items, categoriesById: categoriesById, todayUtc: todayUtc);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppSectionHeader(
            assetPath: 'assets/icons/dashboard/upcoming.png',
            assetSize: 28,
            titleStyle: context.appTypography.sectionTitle?.copyWith(fontSize: 14),
            // ADR-049: the section title is now exactly "Upcoming" --
            // deliberately never "Upcoming * Next 7 days" (see this
            // file's own commit history / ADR-049), because an overdue
            // entry -- possibly days or weeks in the past -- can also
            // appear in this list, and "Next 7 days" would misdescribe
            // it. `l10n.recurringTitle` ("Recurring") is left
            // completely unchanged -- it's still the Recurring
            // screen's own AppBar title and the More screen's row
            // label.
            title: l10n.homeUpcomingCommitmentsTitle,
            eyebrow: true,
            trailing: items != null && items.isNotEmpty
                ? TextButton(
                    key: const Key('viewAllRecurringButton'),
                    onPressed: () => context.push(AppRoutes.recurring),
                    child: Text(l10n.viewAll),
                  )
                : null,
          ),
        const SizedBox(height: 6),
        AppCard(
      key: const Key('upcomingCommitmentsCard'),
      // Final U3 Visual Polish Pass: bordered-only, no lift --
      // Budgets/Goals/Upcoming stay in the quieter tier, visibly
      // less prominent than the monthly metrics card, which now
      // carries the soft shadow instead. ADR-049 keeps this choice.
      bordered: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[

          body,
        ],
      ),
        ),
      ],
    );
  }
}

/// The non-empty body of [_UpcomingCommitmentsCard] (ADR-049): one
/// compact column of [_UpcomingRow]s -- never a card-per-row -- with a
/// subtle inset divider between rows and none after the last one.
/// [items] is already ordered overdue-first/due-today-next/nearest-
/// upcoming-last and already capped to [kHomeUpcomingMaxRows] by
/// [homeUpcomingItemsProvider]; this widget never re-sorts or re-caps,
/// and is guaranteed non-empty by its only call site (the empty state
/// is rendered separately, one level up).
class _UpcomingList extends StatelessWidget {
  const _UpcomingList({required this.items, required this.categoriesById, required this.todayUtc});

  final List<RecurringPendingItem> items;
  final Map<String, CategoryRow> categoriesById;
  final DateTime todayUtc;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.appTokens;
    // Inset separator (this checkpoint's "row design" spec): starts
    // under the text column, not under the icon -- the icon's own
    // container width plus the icon-to-text gap this row uses below.
    // Final visual-polish pass: uses the semantic `subtleBorder`
    // token (today an alias of `outlineVariant`) rather than reading
    // `ColorScheme.outlineVariant` directly, so this one flat inset
    // divider -- never a per-row card -- stays correct if a future
    // theme ever gives `subtleBorder` its own value.
    final double dividerIndent = _UpcomingRow.iconContainerSize + tokens.spacing.sm;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < items.length; i++) ...<Widget>[
          _UpcomingRow(
            item: items[i],
            category: items[i].rule.categoryId == null ? null : categoriesById[items[i].rule.categoryId],
            todayUtc: todayUtc,
          ),
          if (i != items.length - 1)
            Divider(height: 1, thickness: 1, indent: dividerIndent, color: tokens.colors.subtleBorder),
        ],
      ],
    );
  }
}

/// One row inside [_UpcomingList] (ADR-049): `[identity icon][title +
/// metadata/badge][amount]`. Never fetches a brand logo, never a
/// scraped asset, never a second icon system -- [TransactionIconBadge]
/// is the one existing shared mechanism (service identity > category
/// identity > generic type glyph), exactly as every Activity-screen
/// transaction row already uses it.
class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow({required this.item, required this.category, required this.todayUtc});

  final RecurringPendingItem item;

  /// The rule's resolved category, or `null` when the rule has none,
  /// or a category id it names can't be resolved yet -- either way the
  /// icon falls back safely (service identity, then the generic type
  /// glyph via [TransactionIconBadge]) and the badge below is simply
  /// omitted, never invented from the rule's name.
  final CategoryRow? category;
  final DateTime todayUtc;

  /// This checkpoint's "~44px" icon-container spec -- slightly larger
  /// than [AppIconTileSize.medium]'s own 40px, via
  /// [TransactionIconBadge]'s additive `containerSize` override, never
  /// a new icon-tile size tier. Glyph bumped from 21 to 24 (Recurring
  /// UX checkpoint, Part A2: "container 44-48px, glyph 24-30px") --
  /// the container already sat inside that range.
  static const double iconContainerSize = 44;
  static const double iconGlyphSize = 24;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.appTokens;
    final AppTypography typography = context.appTypography;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final RecurringRuleRow rule = item.rule;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // Same type-color convention `activity_screen.dart`'s `amountColor`
    // already established (including the Forest-theme income safety
    // mechanism via `tokens.colors.positive`, rather than
    // `colorScheme.primary`) -- never a second, divergent mapping.
    final Color typeColor = switch (rule.kind) {
      'income' => tokens.colors.positive,
      'transfer' => colors.onSurfaceVariant,
      _ => colors.error,
    };

    final bool isOverdue = item.urgency == RecurringItemUrgency.overdue;
    // Overdue treatment: the existing negative semantic color on the
    // text itself -- never the whole-card red/flashing/bouncing
    // treatment the spec explicitly forbids.
    //
    // Recurring UX checkpoint (Part A5): every row now shows the
    // rule's own real, already-scheduled `item.scheduledDateUtc` --
    // never an invented date -- formatted exactly like every other
    // screen's date display (`DateFormat.yMMMd()`, the same bare,
    // locale-aware call `_PendingItemTile`'s own `dateLabel` already
    // used on the Recurring screen before this checkpoint). Overdue/
    // due-today prefix a status word onto that exact date ("Overdue
    // · Sep 18, 2026" / "Due today · Oct 3, 2026"); a future item
    // shows just the date, per this checkpoint's own reference layout
    // -- this supersedes ADR-049's relative "In N days" copy, which
    // `homeUpcomingInDaysLabel` is no longer called for.
    final String exactDateLabel = DateFormat.yMMMd().format(item.scheduledDateUtc);
    final (String metadataText, Color metadataColor) = switch (item.urgency) {
      RecurringItemUrgency.overdue => ('${l10n.overdueLabel} · $exactDateLabel', colors.error),
      RecurringItemUrgency.dueToday => (
          '${l10n.recurringStatusDueToday} · $exactDateLabel',
          colors.primary,
        ),
      RecurringItemUrgency.upcoming => (exactDateLabel, tokens.colors.secondaryText),
    };

    final Money amount = Money.fromMinorUnits(rule.amountMinorUnits, rule.currencyCode);

    // This checkpoint's "category / type badge" spec: ONE compact pill,
    // shown only when a real category is resolved -- never invented
    // from the rule's name. Reuses `AppStatusChip` (the same small-pill
    // primitive this row's own predecessor, `_RecurringItemSummary`,
    // already used for its urgency chip) and the existing
    // `categoryColorFor` category-color family -- never a new
    // arbitrary palette.
    final CategoryRow? resolvedCategory = category;
    final RecurringRuleKind ruleKind = RecurringRuleKind.values.byName(rule.kind);
    final Widget? categoryBadge;
    if (resolvedCategory != null) {
      categoryBadge = AppStatusChip(
        label: resolvedCategory.name,
        color: categoryColorFor(
          categoryId: resolvedCategory.id,
          storedColorKey: resolvedCategory.colorKey,
          isDark: isDark,
        ),
      );
    } else if (ruleKind != RecurringRuleKind.expense) {
      // A6: no category resolved, but the rule's own kind
      // (income/transfer) is itself a real, reliable classification --
      // never inferred from the rule's name -- so it becomes the badge
      // instead of omitting one entirely.
      categoryBadge = AppStatusChip(
        label: ruleKind == RecurringRuleKind.income
            ? l10n.transactionTypeIncome
            : l10n.transactionTypeTransfer,
        color: typeColor,
      );
    } else {
      categoryBadge = null;
    }

    final Widget rowContent = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // Bug fix (post-ADR-049 overflow pass, not a redesign): the
        // amount must always render every digit -- never clipped or
        // ellipsized, a hard requirement of this row's own spec --
        // and this Row must never overflow, even when the amount's
        // own natural width (a long KWD 3-decimal amount, or any
        // amount at a large text scale) plus the icon would
        // otherwise exceed the row's real available width. Capping
        // the amount's own `ConstrainedBox` at "available width minus
        // the icon and both fixed gaps" guarantees icon + gaps +
        // amount can never exceed `constraints.maxWidth`; the
        // `Expanded` title/metadata column still receives the TRUE
        // remainder exactly as before (this cap only engages in the
        // genuine edge case where the amount wouldn't fit even with
        // that column at zero width), and `FittedBox(fit:
        // BoxFit.scaleDown)` shrinks the whole amount -- never
        // truncating a single digit -- only then.
        final double amountMaxWidth = math.max(
          0.0,
          constraints.maxWidth - iconContainerSize - tokens.spacing.sm * 2,
        );

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            TransactionIconBadge(
              type: rule.kind,
              color: typeColor,
              categoryIconName: category?.icon,
              serviceIdentityKey: rule.serviceIdentityKey,
              containerSize: iconContainerSize,
              glyphSize: iconGlyphSize,
            ),
            SizedBox(width: tokens.spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    rule.name,
                    style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          metadataText,
                          style: typography.caption?.copyWith(
                            color: metadataColor,
                            fontWeight: isOverdue ? FontWeight.w600 : null,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (categoryBadge != null) ...<Widget>[
                        SizedBox(width: tokens.spacing.xs),
                        // Bug fix: a bare, non-flex badge here can
                        // force this inner metadata row to overflow
                        // once the outer row's amount has claimed
                        // most of the available width (see the
                        // outer `ConstrainedBox`/`FittedBox` amount
                        // fix above). `Flexible` lets the badge's
                        // own `AppStatusChip` text ellipsize rather
                        // than overflow -- exactly the "badge may
                        // move/wrap gracefully rather than forcing
                        // [content] off-screen" allowance this row's
                        // own spec already called for. Never engages
                        // when there is room.
                        Flexible(child: categoryBadge),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: tokens.spacing.sm),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: amountMaxWidth),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  _formatter.format(amount),
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.right,
                ),
              ),
            ),
          ],
        );
      },
    );

    // Overdue treatment (final visual-polish pass): a restrained,
    // low-alpha tint derived from `colors.error` -- the SAME semantic
    // color the "Overdue" label text above already uses, never a new
    // arbitrary palette entry -- behind the overdue row ONLY, never
    // the whole card. Deliberately square-cornered (no `borderRadius`)
    // and spanning this Container's full width (the SAME width every
    // other row's Container spans), so the tint reads as a flush,
    // edge-to-edge highlight inside the one outer Upcoming card
    // rather than a separate rounded "card inside a card" -- the
    // earlier `elevatedSurface` + `smallRadius` treatment read as
    // exactly that gray mini-card and is why this changed. No border,
    // no strong background, no animation. The SAME padding envelope
    // applies to every row regardless of urgency so every row's icon
    // column stays aligned; only the decoration differs for an
    // overdue row.
    return Container(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.xs, horizontal: tokens.spacing.xs),
      decoration: isOverdue ? BoxDecoration(color: colors.error.withValues(alpha: 0.07)) : null,
      child: rowContent,
    );
  }
}
