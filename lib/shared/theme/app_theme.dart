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

  static ThemeData light() => _build(Brightness.light, seed: _seed);

  static ThemeData dark() => _build(Brightness.dark, seed: _seed);

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

  static ThemeData _build(Brightness brightness, {required Color seed, Color? positiveOverride}) {
    final ColorScheme colorScheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    final AppTokens tokens = AppTokens.fromColorScheme(
      colorScheme,
      positiveOverride: positiveOverride,
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
