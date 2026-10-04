import 'package:flutter/material.dart';

/// Visual System Convergence Checkpoint 7.1 — the shared spacing/radius/
/// semantic-color tokens every screen should eventually build on, instead
/// of each screen hand-picking its own magic numbers.
///
/// This file only introduces vocabulary for values that already exist in
/// the app today (see `lib/features/dashboard/presentation/home_screen.dart`
/// for the duplicated patterns this generalizes) — it does not change what
/// any of those numbers currently render as. [AppSpacing]/[AppRadii]'s
/// defaults were chosen to match the spacing/radius values already in use
/// across the app (4/8/12/16/20/24/32 for spacing; 8/16/20/999 for radii),
/// so wiring an existing call site to a token is a pure rename, not a
/// visual change, unless a screen is deliberately updated to use a
/// different token than the literal it previously hard-coded.

/// A small semantic spacing scale. Prefer these over scattering new magic
/// numbers across screens — see `docs/design/dashboard-ui-reference.png`
/// and the `financial-app-ui-ux-designer` skill's suggested base scale.
@immutable
class AppSpacing {
  const AppSpacing({
    this.xxs = 4,
    this.xs = 8,
    this.sm = 12,
    this.md = 16,
    this.lg = 20,
    this.xl = 24,
    this.xxl = 32,
  });

  final double xxs;
  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double xxl;
}

/// A small semantic corner-radius scale, plus [pillRadius] for fully
/// rounded chips/badges (`BorderRadius.circular(999)` is already how
/// `_CurrencyBadge` and every status-chip pattern on Home get a pill
/// shape — this just names it).
///
/// [xl] -- Checkpoint 10 (Icon-Led UI Foundation) addition: the approved
/// 8-screen reference's hero/feature cards (the Home balance card, the
/// Family Wallet balance card) round more generously than [large] (20) --
/// visually closer to 24. Purely additive: every pre-existing call site
/// that reads [small]/[medium]/[large]/[pill] is completely unaffected,
/// since this is a new field with its own default, not a change to any
/// existing one.
@immutable
class AppRadii {
  const AppRadii({
    this.small = 8,
    this.medium = 16,
    this.large = 20,
    this.xl = 24,
    this.pill = 999,
  });

  final double small;
  final double medium;
  final double large;

  /// Hero/feature-card radius -- see the class doc comment.
  final double xl;
  final double pill;

  BorderRadius get smallRadius => BorderRadius.circular(small);
  BorderRadius get mediumRadius => BorderRadius.circular(medium);
  BorderRadius get largeRadius => BorderRadius.circular(large);
  BorderRadius get xlRadius => BorderRadius.circular(xl);
  BorderRadius get pillRadius => BorderRadius.circular(pill);
}

/// Checkpoint 10 (Icon-Led UI Foundation): named container/glyph sizes for
/// [AppIconTile] (`lib/shared/widgets/app_icon_tile.dart`), so a screen
/// picks one of three named tiers instead of a magic pixel size. Values
/// match what already exists in the app today rather than inventing new
/// ones: [medium] (40 container / 20 icon) is exactly
/// `TransactionIconBadge`'s pre-existing size (see that widget, which this
/// checkpoint refactors to build on [AppIconTile] at this same tier), so
/// converging a transaction row onto the shared tile is a pure rename,
/// not a resize. [small] and [large] are new tiers for denser rows (an
/// account/subscription list item, matching the reference's compact list
/// icon size) and more prominent single-icon contexts respectively.
@immutable
class AppIconSizes {
  const AppIconSizes({
    this.smallContainer = 32,
    this.smallIcon = 16,
    this.mediumContainer = 40,
    this.mediumIcon = 20,
    this.largeContainer = 48,
    this.largeIcon = 24,
  });

  final double smallContainer;
  final double smallIcon;
  final double mediumContainer;
  final double mediumIcon;
  final double largeContainer;
  final double largeIcon;
}

/// Surface/border/status colors that either have no direct [ColorScheme]
/// role (Material 3's stable [ColorScheme] has no "warning" slot) or are
/// worth naming once so every screen agrees on which [ColorScheme] role
/// backs a given concept, instead of re-deriving it ad hoc per screen (as
/// `home_screen.dart`'s `_ConfiguredBudget`/`_PriorityGoalSummary`/
/// `_RecurringItemSummary` each currently do independently for their own
/// status colors).
///
/// Every value here is DERIVED from the active [ColorScheme] — nothing is
/// a hard-coded, theme-independent color — so a future dark/pink/ocean/
/// forest theme (not implemented in CP7.1; see that class's own doc
/// comment) only ever needs to supply a different [ColorScheme], and every
/// screen already using these tokens re-themes for free.
@immutable
class AppSemanticColors {
  const AppSemanticColors({
    required this.cardSurface,
    required this.elevatedSurface,
    required this.subtleBorder,
    required this.positive,
    required this.warning,
    required this.negative,
    required this.secondaryText,
    required this.mutedText,
    required this.info,
    required this.ambientGradient,
    this.heroGradient,
    this.warmCardSurface,
    this.warmCardBorder,
    this.warmCardForeground,
    this.dashboardPageBackground,
    this.positiveGradient,
    this.negativeGradient,
    this.navSelectedColor,
  });

  /// The standard card/surface background — matches
  /// `colorScheme.surfaceContainerHigh`, already used identically by every
  /// non-hero card on Home.
  final Color cardSurface;

  /// A step up from [cardSurface] for content that should read as sitting
  /// above the card surface (e.g. a nested tile) — Beta 0/CP7.1 has no
  /// call site yet, included so one exists before it's needed ad hoc.
  final Color elevatedSurface;

  /// A subtle separator/border color — replaces screens reaching for
  /// `colorScheme.outlineVariant` directly.
  final Color subtleBorder;

  /// Income / on-track / positive-direction money. Matches the existing
  /// convention (`financial-app-ui-ux-designer` skill §4): income uses
  /// `colorScheme.primary`, never a hard-coded green.
  final Color positive;

  /// "Ahead of pace" / caution, without being alarming. Material 3's
  /// stable [ColorScheme] has no dedicated warning role, so this is
  /// exactly the kind of token [ThemeExtension] exists for — currently
  /// backed by `colorScheme.tertiary`, matching
  /// `_ConfiguredBudget`'s existing `BudgetStatus.caution` mapping.
  final Color warning;

  /// Expense / overdue / negative-direction money. Matches the existing
  /// convention: expense uses `colorScheme.error`, never a hard-coded red.
  final Color negative;

  /// Secondary/supporting text (labels, metadata) — matches
  /// `colorScheme.onSurfaceVariant`, already used pervasively for this.
  final Color secondaryText;

  /// The most de-emphasized text/icon color still expected to be legible
  /// (e.g. a disabled-looking hint) — matches `colorScheme.outline`,
  /// deliberately distinct from [secondaryText] so screens have two
  /// levels of de-emphasis rather than reaching for opacity hacks.
  final Color mutedText;

  /// Checkpoint 10 (Icon-Led UI Foundation) addition: informational,
  /// non-alarming status (e.g. a neutral "reference rate"/"pending"
  /// indicator) — distinct from [warning] (caution) and [negative]
  /// (error/expense). Material 3's stable [ColorScheme] has no dedicated
  /// "info" role either, same situation [warning] already solved by
  /// borrowing `tertiary` — [info] borrows the one remaining distinct
  /// chromatic role, `colorScheme.secondary`, so all four semantic states
  /// (positive/warning/negative/info) resolve to four visually distinct
  /// [ColorScheme] roles on every theme without inventing a hard-coded
  /// color.
  final Color info;

  /// Checkpoint 10 (Icon-Led UI Foundation) addition: a restrained,
  /// theme-derived two-stop gradient for the "subtle ambient gradient"
  /// decorative treatment the approved reference uses behind a screen's
  /// hero header (see the reference's Home/Family Wallet top status-bar
  /// wash). Deliberately just [colorScheme.primary]/[colorScheme.secondary]
  /// at a low, fixed alpha rather than new literal colors -- so every
  /// theme (including a theme this checkpoint doesn't know about yet)
  /// produces a tasteful, on-brand wash automatically, and "themes must
  /// not recolor the entire application" is satisfied by construction:
  /// this is consumed by exactly one decorative background layer, never
  /// spread across arbitrary surfaces.
  final List<Color> ambientGradient;

  /// Checkpoint U3 (docs/23_DASHBOARD_HEADER_BRAND_SPEC.md §9/§11):
  /// KakeiboPlus's own fixed brand gradient for the Dashboard hero
  /// card's background -- `null` for every theme that doesn't
  /// explicitly opt in (see `app_theme.dart`'s `light()`/`dark()`,
  /// which pass one; `pink()`/`ocean()`/`forest()` deliberately do
  /// not).
  ///
  /// Unlike [ambientGradient] (always derived from the theme's own
  /// `colorScheme.primary`/`secondary`, so every theme -- including one
  /// this checkpoint doesn't know about yet -- produces a tasteful wash
  /// automatically), this is a small set of FIXED literal brand colors,
  /// the same architecture the More screen's wordmark already
  /// established (`more_screen.dart`: "the wordmark PNG's ink is a
  /// FIXED brand green ... unlike every other color on this screen it
  /// deliberately does NOT come from `colorScheme`"). docs/23 §9
  /// specifies exact hex values as "the approved starting palette" --
  /// values, not a derivation rule -- so deriving them from a seed
  /// would not reproduce them.
  ///
  /// Deliberately scoped to Light/Dark only, not a global reseed:
  /// `app_theme.dart`'s own history already recorded ONE deliberate
  /// recoloring of the app's shared seed (Checkpoint 10 Visual
  /// Convergence, teal/green -> blue) and a SEPARATE deliberate
  /// decision to move Income/Spending back OUT of the hero card
  /// (also Checkpoint 10). Re-deriving the global seed from docs/23's
  /// teal, or moving Income/Expense back into the hero card, would
  /// silently reverse both of those without ever being told to --
  /// this field instead adds ONLY a new, additive, optional hero-card
  /// background treatment, consumed by exactly one widget
  /// (`_HeroCurrencyCard`), leaving `colorScheme` and every other
  /// screen completely untouched, exactly like [ambientGradient]'s own
  /// "consumed by exactly one decorative layer" principle. Pink/Ocean/
  /// Forest keep their own already-tuned flat `primaryContainer` hero
  /// fill unchanged (docs/23 §19: custom themes "may alter ... possibly
  /// hero skin in the future" -- future, not this checkpoint).
  final List<Color>? heroGradient;

  /// Dashboard V1 Finalization checkpoint (docs/23 §9's "Sunny Yellow"
  /// accent, Request D's "warm/calm, not alarming" Upcoming Commitments
  /// empty-state treatment): a fixed warm cream surface for the Home
  /// "Upcoming commitments" card's empty ("You're all caught up") state
  /// -- `null` for every theme that doesn't explicitly opt in, exactly
  /// like [heroGradient]. Deliberately NOT `colorScheme.tertiary`/
  /// `tertiaryContainer` -- the app-wide seed is still Checkpoint 10's
  /// blue (see `app_theme.dart`), so a seed-derived tertiary would not
  /// reliably land on a warm cream/tan hue. Consumed by exactly one
  /// widget (the Upcoming Commitments card's empty state), never a
  /// general "warning" color -- [warning] already owns that role.
  final Color? warmCardSurface;

  /// Border companion to [warmCardSurface]. `null` alongside it.
  final Color? warmCardBorder;

  /// Foreground/text companion to [warmCardSurface] -- a warm amber-
  /// brown, never red, per the "calm, not alarming" empty-state
  /// requirement (this is a *positive* empty state, not a warning).
  /// `null` alongside [warmCardSurface].
  final Color? warmCardForeground;

  /// Dashboard Visual Refresh Pass (docs/design/dashboard-referancenew.png):
  /// a fixed, soft mint page background for the Home Dashboard screen
  /// specifically -- `null` for every theme that doesn't explicitly opt
  /// in, exactly like [heroGradient]/[warmCardSurface]. Deliberately NOT
  /// a change to [ColorScheme.surface]/`scaffoldBackgroundColor` (which
  /// stays the app-wide default for every other screen) -- consumed by
  /// exactly one Scaffold (`HomeScreen`'s own), never a global
  /// re-background, per this pass's "targets the Dashboard only" scope.
  final Color? dashboardPageBackground;

  /// Dashboard progress-bar gradient refinement: a fixed, premium "deep
  /// emerald -> fresh mint/green" gradient for a within-budget/healthy
  /// [AppProgressBar] fill on the Dashboard -- `null` for every theme
  /// that doesn't explicitly opt in, exactly like [heroGradient]/
  /// [warmCardSurface]. Deliberately NOT a change to [positive] itself
  /// (still `colorScheme.primary`, unaffected everywhere else) -- this
  /// is a second, additive, opt-in gradient consumed by exactly the two
  /// Dashboard budget-progress-bar call sites that pass it, never a
  /// redefinition of what "positive" means app-wide. A `null` value
  /// means the caller falls back to painting [positive] as a flat
  /// color, exactly as every progress bar already does today.
  final List<Color>? positiveGradient;

  /// Dashboard progress-bar gradient refinement: the companion
  /// "exceeded/over-budget" gradient -- a fixed "deep coral-red ->
  /// brighter warm red" treatment, `null` alongside [positiveGradient]
  /// for the same reasons and under the same fallback rule ([negative]
  /// painted flat).
  final List<Color>? negativeGradient;

  /// U3 Final Polish Pass (item 10 -- "Current selected bottom-nav
  /// color looks gray"): the fixed KakeiboPlus teal/emerald used for
  /// the bottom-navigation bar's SELECTED icon and label only -- `null`
  /// for every theme that doesn't explicitly opt in, exactly like
  /// [heroGradient]/[dashboardPageBackground]/[positiveGradient].
  ///
  /// Root cause this replaces: the nav bar's selected state previously
  /// had no override at all, so it fell through to Material 3's own
  /// `NavigationBarThemeData` default (`colorScheme.onSecondaryContainer`
  /// / the `secondaryContainer` indicator) -- under this app's blue seed
  /// (`AppTheme._seed`, Checkpoint 10 Visual Convergence), that tonal
  /// role renders as a desaturated blue-gray, which is exactly what read
  /// as "looks gray" rather than a deliberate brand color.
  ///
  /// Deliberately reuses the SAME literal teal/emerald already vetted
  /// for [positiveGradient]'s middle stop (Light) / brightest stop
  /// (Dark) -- see `app_theme.dart`'s `_kakeiboNavSelectedLight`/
  /// `_kakeiboNavSelectedDark` -- rather than inventing a new brand
  /// color, per this pass's own "avoid ... random raw colors ... use
  /// theme/tokens where practical" requirement. The soft mint pill/
  /// indicator behind the selected icon is DERIVED from this same
  /// color at a low alpha (see `app_shell.dart`) -- the same
  /// color-tinted-background idiom [AppIconTile] already uses for
  /// every other tinted-icon container in the app -- rather than a
  /// second, separate literal, so there is exactly one new brand color
  /// to reason about. Pink/Ocean/Forest deliberately do not set this
  /// (their own nav selected state keeps today's `secondaryContainer`-
  /// derived behavior, unchanged by this pass), matching how
  /// [heroGradient]/[dashboardPageBackground] already scope every
  /// fixed-brand-literal addition to Light/Dark only.
  final Color? navSelectedColor;

  /// [positiveOverride] -- Checkpoint 8.1 addition, optional and
  /// defaulting to `null` (= unchanged behavior: [positive] is
  /// `colorScheme.primary`, exactly as it always was for every theme
  /// that predates CP8.1). It exists for one reason: a decorative theme
  /// whose seed color is ITSELF green (the Forest theme -- see
  /// `app_theme.dart`) would otherwise make income/positive figures
  /// silently identical to Forest's muted decorative primary green, in
  /// violation of the "money readability beats decoration" requirement.
  /// When supplied, [positiveOverride] is used for [positive] instead of
  /// `colorScheme.primary`; every other semantic color is unaffected.
  /// [negative] never needs an equivalent override for any theme --
  /// Material's seed algorithm derives the error/red tonal palette
  /// independently of the seed hue, so there is no analogous red/
  /// negative-color collision risk to guard against.
  factory AppSemanticColors.fromColorScheme(
    ColorScheme colorScheme, {
    Color? positiveOverride,
    List<Color>? heroGradient,
    Color? warmCardSurface,
    Color? warmCardBorder,
    Color? warmCardForeground,
    Color? dashboardPageBackground,
    List<Color>? positiveGradient,
    List<Color>? negativeGradient,
    Color? navSelectedColor,
  }) {
    return AppSemanticColors(
      cardSurface: colorScheme.surfaceContainerHigh,
      elevatedSurface: colorScheme.surfaceContainerHighest,
      subtleBorder: colorScheme.outlineVariant,
      positive: positiveOverride ?? colorScheme.primary,
      warning: colorScheme.tertiary,
      negative: colorScheme.error,
      secondaryText: colorScheme.onSurfaceVariant,
      mutedText: colorScheme.outline,
      info: colorScheme.secondary,
      ambientGradient: <Color>[
        colorScheme.primary.withValues(alpha: 0.10),
        colorScheme.secondary.withValues(alpha: 0.06),
        colorScheme.surface.withValues(alpha: 0),
      ],
      heroGradient: heroGradient,
      warmCardSurface: warmCardSurface,
      warmCardBorder: warmCardBorder,
      warmCardForeground: warmCardForeground,
      dashboardPageBackground: dashboardPageBackground,
      positiveGradient: positiveGradient,
      negativeGradient: negativeGradient,
      navSelectedColor: navSelectedColor,
    );
  }
}

/// The [ThemeExtension] that carries [AppSpacing]/[AppRadii]/
/// [AppSemanticColors] on [ThemeData] — see `app_theme.dart`, which
/// registers one of these (derived from that theme's own [ColorScheme])
/// on both [ThemeData.light]/[ThemeData.dark].
///
/// A single extension holding three small grouped value objects, rather
/// than three separate [ThemeExtension]s or one flat giant one — enough
/// structure to stay organized, not enough to be a framework (Beta 0/
/// CP7.1 scope guard: "a small clear theme extension is better than a
/// giant one").
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.spacing,
    required this.radii,
    required this.colors,
    this.iconSizes = const AppIconSizes(),
  });

  final AppSpacing spacing;
  final AppRadii radii;
  final AppSemanticColors colors;

  /// Checkpoint 10 (Icon-Led UI Foundation) addition -- see
  /// [AppIconSizes]. Defaults to `const AppIconSizes()` so every
  /// pre-existing construction of [AppTokens] (there is exactly one,
  /// [AppTokens.fromColorScheme] below) keeps compiling and behaving
  /// identically without having to pass this explicitly.
  final AppIconSizes iconSizes;

  /// [positiveOverride] passes straight through to
  /// [AppSemanticColors.fromColorScheme] -- see that factory's own doc
  /// comment (Checkpoint 8.1 addition, defaults to `null`/unchanged
  /// behavior).
  factory AppTokens.fromColorScheme(
    ColorScheme colorScheme, {
    Color? positiveOverride,
    List<Color>? heroGradient,
    Color? warmCardSurface,
    Color? warmCardBorder,
    Color? warmCardForeground,
    Color? dashboardPageBackground,
    List<Color>? positiveGradient,
    List<Color>? negativeGradient,
    Color? navSelectedColor,
  }) {
    return AppTokens(
      spacing: const AppSpacing(),
      radii: const AppRadii(),
      colors: AppSemanticColors.fromColorScheme(
        colorScheme,
        positiveOverride: positiveOverride,
        heroGradient: heroGradient,
        warmCardSurface: warmCardSurface,
        warmCardBorder: warmCardBorder,
        warmCardForeground: warmCardForeground,
        dashboardPageBackground: dashboardPageBackground,
        positiveGradient: positiveGradient,
        negativeGradient: negativeGradient,
        navSelectedColor: navSelectedColor,
      ),
      iconSizes: const AppIconSizes(),
    );
  }

  @override
  AppTokens copyWith({
    AppSpacing? spacing,
    AppRadii? radii,
    AppSemanticColors? colors,
    AppIconSizes? iconSizes,
  }) {
    return AppTokens(
      spacing: spacing ?? this.spacing,
      radii: radii ?? this.radii,
      colors: colors ?? this.colors,
      iconSizes: iconSizes ?? this.iconSizes,
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    // Spacing/radii/semantic-color tokens are discrete design decisions,
    // not values meaningfully interpolated frame-by-frame (Beta 0 has no
    // animated theme transition) -- snap at the midpoint like
    // ThemeExtension's own documented default for non-interpolable data.
    if (other is! AppTokens) return this;
    return t < 0.5 ? this : other;
  }
}

/// Ergonomic accessor: `context.appTokens.spacing.md` instead of
/// `Theme.of(context).extension<AppTokens>()!.spacing.md` at every call
/// site. Falls back to deriving fresh tokens from the current
/// [ColorScheme] if the extension is somehow missing (defensive only —
/// `AppTheme.light`/`AppTheme.dark` always register it), so a call site
/// using this never null-check-crashes.
extension AppTokensX on BuildContext {
  AppTokens get appTokens {
    final ThemeData theme = Theme.of(this);
    return theme.extension<AppTokens>() ?? AppTokens.fromColorScheme(theme.colorScheme);
  }
}
