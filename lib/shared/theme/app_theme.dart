import 'package:flutter/material.dart';

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
/// `_seed` is still the only literal, theme-independent color in this
/// file -- so a future theme (pink/ocean/forest, not implemented in
/// CP7.1) only ever needs to supply a different seed/`ColorScheme`, and
/// every screen already reading from [AppTokens]/`ColorScheme` re-themes
/// for free (see `app_tokens.dart`'s doc comment).
class AppTheme {
  AppTheme._();

  static const Color _seed = Color(0xFF2E7D6B);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final ColorScheme colorScheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
    final AppTokens tokens = AppTokens.fromColorScheme(colorScheme);
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
