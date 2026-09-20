import 'package:flutter/material.dart';

/// Visual System Convergence Checkpoint 7.1 — names the text-style roles
/// screens already reach for by hand, without introducing a single new
/// font size or weight. Every getter below returns EXACTLY the
/// `Theme.of(context).textTheme.<x>` style (plus, where the existing call
/// sites already added one, the same `fontWeight` override) already used
/// at the call site it generalizes:
///
///  - [screenTitle]   — `textTheme.headlineSmall`, e.g. Home's greeting.
///  - [sectionTitle]  — `textTheme.titleMedium` + `FontWeight.w600`, e.g.
///    the Budget/Savings Goals/Upcoming Commitments card headers.
///  - [cardTitle]     — same as [sectionTitle]; a distinct name because a
///    card's own title and a screen's section heading are a different
///    semantic role even where Beta 0 happens to use the same underlying
///    style for both.
///  - [body]/[secondaryBody]/[caption] — `bodyMedium`/`bodyMedium` (muted)
///    /`bodySmall` (muted).
///  - [largeMoney]    — `textTheme.headlineMedium` + bold, e.g. the hero
///    currency card's balance.
///  - [mediumMoney]   — `textTheme.titleLarge` + `FontWeight.w700`, e.g.
///    the secondary currency card's balance and the priority-goal/
///    recurring-item amounts.
///  - [smallMoney]    — `textTheme.titleMedium` + `FontWeight.w700`, e.g.
///    a `_MetricTile`'s value in its non-emphasized (secondary-card)
///    context.
///
/// Because these are pure aliases for what a screen already computed
/// inline, swapping a call site over to [AppTypography] is a rename, not
/// a resize -- it does not change any `_AdaptiveAmountLine`/
/// `_AdaptiveAccountRow`-style width measurement that depends on the
/// exact `TextStyle` passed to it (see `home_screen.dart`), since the
/// resolved style is identical either way.
///
/// A per-color variant (e.g. an over-budget amount in `colorScheme.error`)
/// is still the caller's job via `.copyWith(color: ...)` — this class only
/// owns the shape (font size/weight) of each role, not per-instance color,
/// exactly like [TextTheme] itself.
@immutable
class AppTypography {
  const AppTypography._(this._text, this._colors);

  final TextTheme _text;
  final ColorScheme _colors;

  factory AppTypography.of(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppTypography._(theme.textTheme, theme.colorScheme);
  }

  TextStyle? get screenTitle => _text.headlineSmall;

  TextStyle? get sectionTitle => _text.titleMedium?.copyWith(fontWeight: FontWeight.w600);

  TextStyle? get cardTitle => _text.titleMedium?.copyWith(fontWeight: FontWeight.w600);

  TextStyle? get body => _text.bodyMedium;

  TextStyle? get secondaryBody => _text.bodyMedium?.copyWith(color: _colors.onSurfaceVariant);

  TextStyle? get caption => _text.bodySmall?.copyWith(color: _colors.onSurfaceVariant);

  /// Checkpoint 10 (Icon-Led UI Foundation) addition: a step above
  /// [largeMoney], for the ONE truly dominant balance on a screen (the
  /// approved reference's Home total-balance figure) -- `headlineLarge`
  /// (32) + bold, vs. [largeMoney]'s `headlineMedium` (28) + bold.
  /// Additive only: no existing call site is changed to use this, so
  /// every current hero-currency-card rendering (still [largeMoney]) is
  /// byte-for-byte unaffected until a screen deliberately opts in.
  TextStyle? get heroMoney => _text.headlineLarge?.copyWith(fontWeight: FontWeight.bold);

  TextStyle? get largeMoney => _text.headlineMedium?.copyWith(fontWeight: FontWeight.bold);

  TextStyle? get mediumMoney => _text.titleLarge?.copyWith(fontWeight: FontWeight.w700);

  TextStyle? get smallMoney => _text.titleMedium?.copyWith(fontWeight: FontWeight.w700);

  /// Visual System Convergence Checkpoint 7.2 addition: a small, muted,
  /// letter-spaced label role -- matching the approved Claude Design
  /// reference's section-header treatment (e.g. "TOTAL AVAILABLE
  /// BALANCE", "UPCOMING COMMITMENTS"). This getter only owns the shape
  /// (size/weight/tracking/color) of the role, exactly like every other
  /// getter here -- it does NOT uppercase text itself. [AppSectionHeader]'s
  /// own `eyebrow` flag renders its title styled with this role while
  /// deliberately preserving the title's original casing (rather than
  /// calling `.toUpperCase()`), because dozens of existing widget tests
  /// across the app assert on the exact ARB-sourced title strings (e.g.
  /// `find.text('Remaining monthly budget')`) -- see that flag's own doc
  /// comment for the full reasoning. A caller that separately wants a
  /// true all-caps look may still call `.toUpperCase()` on its own text
  /// before styling it with this getter.
  TextStyle? get eyebrow => _text.labelSmall?.copyWith(
    color: _colors.onSurfaceVariant,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
  );
}

/// Ergonomic accessor, matching `context.appTokens` in `app_tokens.dart`.
extension AppTypographyX on BuildContext {
  AppTypography get appTypography => AppTypography.of(this);
}
