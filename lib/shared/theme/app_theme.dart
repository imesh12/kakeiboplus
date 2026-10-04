import 'package:flutter/material.dart';

import 'app_theme_style.dart';
import 'app_tokens.dart';

/// A single, calm, Material 3 theme — per
/// `docs/00_MASTER_BLUEPRINT.md` §37 ("premium, calm, modern, friendly,
/// trustworthy, lightweight ... avoid ... aggressive red warnings").
/// Beta 0 does not implement dark-mode-specific tuning beyond what
/// `ColorScheme.fromSeed` already provides for `Brightness.dark`.
///
/// Visual System Convergence Checkpoint 7.1 hardens this from "just a
/// `ColorScheme`" into the app's shared visual foundation: every
/// [ThemeData] this produces now also carries an [AppTokens]
/// [ThemeExtension] (spacing/radii/semantic colors -- see
/// `app_tokens.dart`) and configures the common component themes
/// (card/button/input/chip/divider/navigation-bar/dialog/bottom-sheet/
/// snack-bar) so a screen gets a coherent look from `ThemeData` alone,
/// without re-styling every widget by hand.
///
/// CP7.1 is explicitly light-mode-only for actual design work (see the
/// checkpoint spec §3) -- [dark] still exists (it's wired into
/// `AiFinancialCoachApp.darkTheme` and Flutter falls back to it whenever
/// the OS reports a dark platform brightness, so removing it would be a
/// behavior change, not a no-op) and gets the exact same [AppTokens]/
/// component-theme treatment, purely so nothing has to be rewritten when
/// dark mode is deliberately designed later -- no dark-specific color
/// tuning beyond what `ColorScheme.fromSeed(brightness: Brightness.dark)`
/// already provides is done here.
///
/// Every color below is derived from the seeded [ColorScheme] --
/// `_seed` is still the only literal, theme-independent color backing
/// [light]/[dark] -- so a future theme only ever needs to supply a
/// different seed/`ColorScheme`, and every screen already reading from
/// [AppTokens]/`ColorScheme` re-themes for free (see `app_tokens.dart`'s
/// doc comment).
///
/// # Checkpoint 8.1 (Premium Theme Personalization Foundation)
///
/// Adds [pink]/[ocean]/[forest] and [resolve] alongside the pre-existing
/// [light]/[dark] -- [light] and [dark] are UNCHANGED (same `_seed`,
/// same `_build` call shape) specifically so every existing test that
/// asserts exact colors against `AppTheme.light()`/`AppTheme.dark()`
/// keeps passing unmodified. Each new theme is just a different seed
/// color run through the exact same [_build] pipeline every existing
/// theme already uses -- no screen anywhere branches on
/// `if (theme == pink)`; every visual difference between themes flows
/// entirely through [ColorScheme]/[AppTokens], per this checkpoint's own
/// "do not scatter theme conditionals through feature screens"
/// requirement. [forest] is the one theme that also passes a
/// `positiveOverride` to [AppTokens.fromColorScheme] -- see
/// `_forestPositiveGreen`'s own doc comment for why.
class AppTheme {
  AppTheme._();

  // Checkpoint 10 Visual Convergence Pass: recalibrated from the
  // previous teal/green (0xFF2E7D6B) to a calm, confident blue matching
  // the approved 8-screen reference's primary interaction accent (the
  // Add button, "See all" links, selected nav state, card gradients).
  // `light()`/`dark()` both still run through the exact same seeded
  // `ColorScheme.fromSeed` pipeline every other theme uses -- this is a
  // one-line recoloring, not an architecture change, and every screen
  // that already reads `colorScheme.primary`/`AppTokens` (rather than a
  // literal `Color(...)`) re-themes automatically. `AppSemanticColors
  // .positive` still derives from `colorScheme.primary` for Light/Dark
  // with no override (see `app_tokens.dart` and
  // `test/shared/theme/app_theme_test.dart`'s locked-in "no override for
  // light/dark" contract) -- this pass does not change that mechanism,
  // only which literal seed feeds it. Pink/Ocean/Forest keep their own
  // independent seeds below, completely untouched, so their
  // personalization is unaffected.
  static const Color _seed = Color(0xFF2563EB);

  /// Pink theme seed -- a warm rose/magenta (Material 3 rose-600
  /// family), matching the approved Claude Design reference's Pink
  /// swatch. Deliberately not neon/saturated -- `ColorScheme.fromSeed`
  /// derives a full tonal palette from this single seed, so the
  /// resulting surfaces/text stay neutral and readable while only the
  /// primary/accent roles read as pink (see the design reference's own
  /// dashboard-pink.png, where income/expense indicators stay standard
  /// green/red even though the hero balance and FAB are pink).
  static const Color _pinkSeed = Color(0xFFDB2777);

  /// Ocean theme seed -- a calm blue-teal (Material 3 cyan-700 family),
  /// matching the reference's Ocean swatch. Not an electric/saturated
  /// blue -- kept premium and calm per this checkpoint's Ocean
  /// personality guidance.
  static const Color _oceanSeed = Color(0xFF0E7490);

  /// Forest theme seed -- a deep, muted pine/moss green, matching the
  /// reference's Forest swatch (Forest's swatch is authentically green;
  /// see `_forestPositiveGreen` for how this theme still keeps that
  /// decorative green distinguishable from financial income green).
  static const Color _forestSeed = Color(0xFF3F6B4F);

  /// A crisp, bright "true success" green -- deliberately different in
  /// both hue-warmth and value from [_forestSeed]'s more muted, darker
  /// decorative moss-green primary. Forest is the one theme whose seed
  /// is itself green, so without this override
  /// `AppSemanticColors.positive` (income/success) would default to
  /// `colorScheme.primary` and become visually identical to Forest's
  /// own decorative accent -- exactly the confusion this checkpoint's
  /// CRITICAL requirement ("Forest's decorative green must remain
  /// distinguishable from financial success/income semantics") forbids.
  /// Passed only to [forest]'s [AppTokens.fromColorScheme] call; every
  /// other theme is unaffected and keeps deriving `positive` from its
  /// own `colorScheme.primary` exactly as before.
  static const Color _forestPositiveGreen = Color(0xFF16A34A);

  /// Checkpoint U3 (docs/23_DASHBOARD_HEADER_BRAND_SPEC.md §9/§11):
  /// KakeiboPlus's own fixed hero-card gradient for the LIGHT theme.
  /// Final U3 Visual Polish Pass: a third, deeper mid-stop was added to
  /// docs/23 §11's original two approved hex stops (`#0F9E9A ->
  /// #19B7A5`) for more perceived depth -- still the same teal/mint hue
  /// family and the same topLeft(darker) -> bottomRight(lighter)
  /// direction, just less flat/single-tone; deliberately NOT brightened
  /// or saturated further (that would read as neon, the opposite of
  /// "premium"). Still a literal, fixed list, not derived from [_seed]
  /// -- see [AppSemanticColors.heroGradient]'s own doc comment for why
  /// this does NOT re-seed the app's shared [ColorScheme] (which stays
  /// [_seed], the Checkpoint 10 blue, for every other color on every
  /// screen).
  // Dashboard Visual Refresh Pass (docs/design/dashboard-referancenew.png,
  // approved 2026-09): the hero/brand-bar gradient's exact stops were
  // updated to this pass's approved teal target -- still the same hue
  // family and topLeft(darker) -> bottomRight(lighter) direction as the
  // prior Final U3 Visual Polish Pass stops it replaces, just recalibrated
  // to the newly approved reference's exact hex values (a literal design
  // value, not a derivation -- see [AppSemanticColors.heroGradient]'s own
  // doc comment for why this does not re-seed the shared ColorScheme).
  // Light-only, per this pass's explicit "default/light Dashboard only"
  // scope -- [_kakeiboHeroGradientDark] is deliberately left unchanged.
  static const List<Color> _kakeiboHeroGradientLight = <Color>[
    Color(0xFF007F87),
    Color(0xFF009B98),
    Color(0xFF12C9AE),
  ];

  /// The DARK-theme counterpart to [_kakeiboHeroGradientLight] -- the
  /// same three stops, each channel scaled down ~30%, keeping the same
  /// hue/relationship (and the same added mid-stop for depth) just
  /// darker, so the hero still reads as the same brand gradient in both
  /// brightnesses.
  static const List<Color> _kakeiboHeroGradientDark = <Color>[
    Color(0xFF084D49),
    Color(0xFF0D6963),
    Color(0xFF18867A),
  ];

  /// Dashboard V1 Finalization checkpoint: a fixed warm cream surface/
  /// border/foreground trio for the Home "Upcoming commitments" card's
  /// empty ("You're all caught up") state -- a tint of docs/23 §9's
  /// approved "Sunny Yellow" accent, deliberately warm rather than red
  /// (this is a positive, calm empty state, not a warning -- see
  /// `app_tokens.dart`'s [AppSemanticColors.warmCardSurface] doc
  /// comment). [_kakeiboWarmForegroundLight]/[_kakeiboWarmForegroundDark]
  /// intentionally match the existing amber [CategoryColorKey] tones
  /// (`category_color.dart`) rather than inventing a fourth unrelated
  /// brown -- same warm-amber family already proven accessible on both
  /// light and dark surfaces elsewhere in this app.
  // Dashboard Visual Refresh Pass: recalibrated to the newly approved
  // reference's exact Upcoming-commitments cream/amber/brown trio --
  // still the same warm, calm (never red) empty-state treatment
  // [warmCardSurface]'s own doc comment describes, just updated literal
  // values. Light-only -- [_kakeiboWarmSurfaceDark] and its siblings are
  // deliberately left unchanged, per this pass's light-only scope.
  static const Color _kakeiboWarmSurfaceLight = Color(0xFFFFFAEB);
  static const Color _kakeiboWarmBorderLight = Color(0xFFFFDA83);
  static const Color _kakeiboWarmForegroundLight = Color(0xFF87430C);
  static const Color _kakeiboWarmSurfaceDark = Color(0xFF2E2A1C);
  static const Color _kakeiboWarmBorderDark = Color(0xFF4A421F);
  static const Color _kakeiboWarmForegroundDark = Color(0xFFE8C449);

  /// Dashboard Visual Refresh Pass: the Home Dashboard's own soft mint
  /// page background -- see [AppSemanticColors.dashboardPageBackground]'s
  /// doc comment. Light-only, passed only from [light()]; [dark()] does
  /// not pass this, so `HomeScreen`'s Scaffold falls back to the
  /// ordinary `colorScheme.surface` under Dark, exactly as before this
  /// pass.
  static const Color _kakeiboDashboardPageBackgroundLight = Color(0xFFF2FCFA);

  /// Dashboard progress-bar gradient refinement: a premium "deep emerald
  /// -> fresh mint/green" fill for a within-budget/healthy
  /// [AppProgressBar] on the Dashboard -- deliberately a muted, calm
  /// green family (not neon/glossy), matching the "avoid ... aggressive
  /// ... warnings"/"premium, calm" guidance this file's own class doc
  /// comment already cites. Three stops, same topLeft(darker) ->
  /// bottomRight(lighter) direction as [_kakeiboHeroGradientLight], for
  /// visual consistency with the hero card's own gradient treatment.
  static const List<Color> _kakeiboPositiveGradientLight = <Color>[
    Color(0xFF0B6E4F),
    Color(0xFF14926B),
    Color(0xFF4CC38A),
  ];

  /// DARK-theme counterpart to [_kakeiboPositiveGradientLight] -- same
  /// hue relationship, each stop darkened, matching how
  /// [_kakeiboHeroGradientDark] relates to its light counterpart.
  static const List<Color> _kakeiboPositiveGradientDark = <Color>[
    Color(0xFF063A29),
    Color(0xFF0B5A44),
    Color(0xFF1F7A5C),
  ];

  /// Dashboard progress-bar gradient refinement: the companion
  /// "exceeded/over-budget" fill -- a "deep coral-red -> brighter warm
  /// red" family, deliberately warm/coral rather than a pure alarm-siren
  /// crimson, per the same "calm, not alarming" guidance [warmCardSurface]
  /// already follows for its own (positive) empty state. Same three-stop,
  /// topLeft -> bottomRight shape as [_kakeiboPositiveGradientLight].
  static const List<Color> _kakeiboNegativeGradientLight = <Color>[
    Color(0xFFB3271D),
    Color(0xFFD6453A),
    Color(0xFFEF6C61),
  ];

  /// DARK-theme counterpart to [_kakeiboNegativeGradientLight].
  static const List<Color> _kakeiboNegativeGradientDark = <Color>[
    Color(0xFF5C1712),
    Color(0xFF7A2A22),
    Color(0xFF9C3F35),
  ];

  /// U3 Final Polish Pass (item 10): the bottom-navigation bar's
  /// SELECTED icon/label color -- see
  /// [AppSemanticColors.navSelectedColor]'s own doc comment for why
  /// this exists and why it deliberately reuses rather than invents a
  /// brand color. Same literal as [_kakeiboPositiveGradientLight]'s
  /// middle "fresh emerald/teal" stop, not a new hex.
  static const Color _kakeiboNavSelectedLight = Color(0xFF14926B);

  /// DARK-theme counterpart -- the brightest/lightest stop of
  /// [_kakeiboPositiveGradientDark], for adequate contrast against a
  /// dark `colorScheme.surface` (the darker stops of that gradient,
  /// tuned for a large gradient fill, would read too dim for small
  /// nav-bar text/icon sizes).
  static const Color _kakeiboNavSelectedDark = Color(0xFF1F7A5C);

  static ThemeData light() => _build(
        Brightness.light,
        seed: _seed,
        heroGradient: _kakeiboHeroGradientLight,
        warmCardSurface: _kakeiboWarmSurfaceLight,
        warmCardBorder: _kakeiboWarmBorderLight,
        warmCardForeground: _kakeiboWarmForegroundLight,
        dashboardPageBackground: _kakeiboDashboardPageBackgroundLight,
        positiveGradient: _kakeiboPositiveGradientLight,
        negativeGradient: _kakeiboNegativeGradientLight,
        navSelectedColor: _kakeiboNavSelectedLight,
      );

  static ThemeData dark() => _build(
        Brightness.dark,
        seed: _seed,
        heroGradient: _kakeiboHeroGradientDark,
        warmCardSurface: _kakeiboWarmSurfaceDark,
        warmCardBorder: _kakeiboWarmBorderDark,
        warmCardForeground: _kakeiboWarmForegroundDark,
        positiveGradient: _kakeiboPositiveGradientDark,
        negativeGradient: _kakeiboNegativeGradientDark,
        navSelectedColor: _kakeiboNavSelectedDark,
      );

  /// Pink -- warm, playful, premium. Light-brightness only (per this
  /// checkpoint's locked initial theme family; Pink is not a
  /// light/dark pair the way the base product theme is).
  static ThemeData pink() => _build(Brightness.light, seed: _pinkSeed);

  /// Ocean -- calm blue/teal, focused, clean.
  static ThemeData ocean() => _build(Brightness.light, seed: _oceanSeed);

  /// Forest -- calm green/earth, grounded, natural. See
  /// `_forestPositiveGreen`'s doc comment for the income/decoration
  /// safety mechanism this theme uniquely relies on.
  static ThemeData forest() =>
      _build(Brightness.light, seed: _forestSeed, positiveOverride: _forestPositiveGreen);

  /// Resolves any [AppThemeStyle] to its [ThemeData] -- the single
  /// entry point `lib/app/app.dart` uses so the app root never
  /// hard-codes a `switch`/`if` over theme identity anywhere else.
  static ThemeData resolve(AppThemeStyle style) {
    return switch (style) {
      AppThemeStyle.light => light(),
      AppThemeStyle.dark => dark(),
      AppThemeStyle.pink => pink(),
      AppThemeStyle.ocean => ocean(),
      AppThemeStyle.forest => forest(),
    };
  }

  static ThemeData _build(
    Brightness brightness, {
    required Color seed,
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
    final ColorScheme colorScheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    final AppTokens tokens = AppTokens.fromColorScheme(
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
    );
    final BorderRadius smallRadius = tokens.radii.smallRadius;
    final BorderRadius mediumRadius = tokens.radii.mediumRadius;
    final BorderRadius largeRadius = tokens.radii.largeRadius;
    final BorderRadius pillRadius = tokens.radii.pillRadius;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      extensions: <ThemeExtension<dynamic>>[tokens],
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      // Restrained elevation everywhere: every card is a flat, tonal
      // surface distinguished by color/border rather than a shadow (see
      // the `financial-app-ui-ux-designer` skill §9). `margin: zero`
      // makes a card's footprint exactly its content box -- every screen
      // already manages the gap around its cards explicitly (a
      // `ListView`'s own padding, an explicit `SizedBox` between cards),
      // so an un-themed `Card`'s implicit default margin
      // (`EdgeInsets.all(4)`) was invisible extra spacing no screen was
      // ever written to account for, not a deliberate design choice.
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: tokens.colors.cardSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: mediumRadius),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: smallRadius)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: smallRadius),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: smallRadius)),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: smallRadius)),
      ),
      // Border/color only -- deliberately does not set `filled`/
      // `fillColor`/`contentPadding`, which would change the visual
      // weight/height of every form field app-wide without this
      // checkpoint having reviewed every screen that uses one (CP7.1's
      // own scope boundary: no full-screen restyling of Add Transaction/
      // dialogs this checkpoint).
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: smallRadius,
          borderSide: BorderSide(color: tokens.colors.subtleBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: smallRadius,
          borderSide: BorderSide(color: tokens.colors.subtleBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: smallRadius,
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: smallRadius,
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: smallRadius,
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: pillRadius),
        side: BorderSide.none,
      ),
      // Color only -- `thickness`/`space` are left at the Material
      // default so this doesn't change layout spacing on screens this
      // checkpoint didn't review; several screens already pass an
      // explicit `Divider(height: 1)` themselves where a tighter divider
      // is wanted, which this theme doesn't touch either way.
      dividerTheme: DividerThemeData(color: tokens.colors.subtleBorder),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: colorScheme.secondaryContainer,
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: largeRadius),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(tokens.radii.large)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: smallRadius),
      ),
    );
  }
}
