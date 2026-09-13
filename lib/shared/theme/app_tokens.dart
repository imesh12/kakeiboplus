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
@immutable
class AppRadii {
  const AppRadii({this.small = 8, this.medium = 16, this.large = 20, this.pill = 999});

  final double small;
  final double medium;
  final double large;
  final double pill;

  BorderRadius get smallRadius => BorderRadius.circular(small);
  BorderRadius get mediumRadius => BorderRadius.circular(medium);
  BorderRadius get largeRadius => BorderRadius.circular(large);
  BorderRadius get pillRadius => BorderRadius.circular(pill);
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
  factory AppSemanticColors.fromColorScheme(ColorScheme colorScheme, {Color? positiveOverride}) {
    return AppSemanticColors(
      cardSurface: colorScheme.surfaceContainerHigh,
      elevatedSurface: colorScheme.surfaceContainerHighest,
      subtleBorder: colorScheme.outlineVariant,
      positive: positiveOverride ?? colorScheme.primary,
      warning: colorScheme.tertiary,
      negative: colorScheme.error,
      secondaryText: colorScheme.onSurfaceVariant,
      mutedText: colorScheme.outline,
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
  const AppTokens({required this.spacing, required this.radii, required this.colors});

  final AppSpacing spacing;
  final AppRadii radii;
  final AppSemanticColors colors;

  /// [positiveOverride] passes straight through to
  /// [AppSemanticColors.fromColorScheme] -- see that factory's own doc
  /// comment (Checkpoint 8.1 addition, defaults to `null`/unchanged
  /// behavior).
  factory AppTokens.fromColorScheme(ColorScheme colorScheme, {Color? positiveOverride}) {
    return AppTokens(
      spacing: const AppSpacing(),
      radii: const AppRadii(),
      colors: AppSemanticColors.fromColorScheme(colorScheme, positiveOverride: positiveOverride),
    );
  }

  @override
  AppTokens copyWith({AppSpacing? spacing, AppRadii? radii, AppSemanticColors? colors}) {
    return AppTokens(
      spacing: spacing ?? this.spacing,
      radii: radii ?? this.radii,
      colors: colors ?? this.colors,
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
