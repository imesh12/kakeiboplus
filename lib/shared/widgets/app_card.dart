import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Visual System Convergence Checkpoint 7.1's shared card primitive:
/// consistent surface color, radius, and internal padding, generalizing
/// the `Card(elevation: 0, color: colors.surfaceContainerHigh, shape:
/// RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)))` +
/// `Padding(padding: const EdgeInsets.all(16))` pair that was independently
/// hand-written four times on `home_screen.dart` alone (`_SecondaryCurrencyCard`,
/// `_BudgetCard`, `_SavingsGoalsCard`, `_UpcomingCommitmentsCard`), with
/// `_HeroCurrencyCard` as a fifth, larger-radius/different-color variant of
/// the exact same shape.
///
/// No financial/domain logic lives here — purely a surface primitive.
///
/// Defaults to zero external [margin] so the surrounding layout (a
/// `ListView`'s own padding, an explicit `SizedBox` gap between cards --
/// both already how every screen in this app manages spacing) is the only
/// thing controlling the gap around a card, rather than an invisible
/// implicit Material default (`Card`'s own un-themed default is
/// `EdgeInsets.all(4)`) that no screen here was ever written to account
/// for. `AppTheme` also sets this as the app-wide `CardThemeData.margin`,
/// so a bare `Card(...)` and an `AppCard(...)` behave the same way on that
/// front; this default just makes it explicit at the primitive itself too.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    super.key,
    this.padding,
    this.color,
    this.radius,
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.bordered = false,
  });

  final Widget child;

  /// Defaults to `EdgeInsets.all(tokens.spacing.md)` (16) -- the padding
  /// every existing `surfaceContainerHigh` card on Home already uses.
  final EdgeInsetsGeometry? padding;

  /// Defaults to `context.appTokens.colors.cardSurface`
  /// (`colorScheme.surfaceContainerHigh`).
  final Color? color;

  /// Defaults to `context.appTokens.radii.medium` (16). Pass
  /// `context.appTokens.radii.large` for a hero-style card (20).
  final double? radius;

  final EdgeInsetsGeometry margin;

  /// Only wraps [child] in an [InkWell] when non-null, so a non-tappable
  /// card (the common case today) never pays for or exposes tap
  /// semantics it doesn't have.
  final VoidCallback? onTap;

  /// Visual System Convergence Checkpoint 7.2: when true, renders a flat
  /// near-white card (`colorScheme.surface`) with a thin
  /// `context.appTokens.colors.subtleBorder` outline instead of the
  /// default tonal `cardSurface` fill with no border -- matching the
  /// approved Claude Design reference's "white, bordered, generously
  /// rounded" card treatment. [subtleBorder] was already defined by CP7.1
  /// (`app_tokens.dart`) but had no call site until this checkpoint. An
  /// explicit [color] still always wins over this flag's own default
  /// background (e.g. the hero currency card keeps its own
  /// `primaryContainer` fill either way); this flag only ever changes the
  /// DEFAULT background plus whether a border is drawn. `false` (the
  /// default) is pixel-identical to CP7.1's card -- no border, same
  /// tonal fill -- so every existing call site is unaffected until it
  /// opts in.
  final bool bordered;

  /// Visual System Convergence Checkpoint 7.3: the underlying [Card] now
  /// always sets `clipBehavior: Clip.antiAlias` (previously unset, i.e.
  /// `Clip.none`). Activity's transaction row -- CP7.3's first call site to
  /// combine [onTap] (an [InkWell] ripple) with this card's rounded
  /// corners -- needs its ripple clipped to the rounded shape, exactly like
  /// the raw `Card(clipBehavior: Clip.antiAlias, ...)` it replaces already
  /// did. A card with no [onTap] (every CP7.1/CP7.2 Home call site) has no
  /// ripple to clip and a [child] that never overflows its own rounded
  /// bounds, so this is invisible there -- see `app_card_test.dart`'s
  /// dedicated assertion.

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.appTokens;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final BorderRadius borderRadius = BorderRadius.circular(radius ?? tokens.radii.medium);
    final Widget content = Padding(
      padding: padding ?? EdgeInsets.all(tokens.spacing.md),
      child: child,
    );

    return Card(
      margin: margin,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: color ?? (bordered ? colorScheme.surface : tokens.colors.cardSurface),
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: bordered ? BorderSide(color: tokens.colors.subtleBorder) : BorderSide.none,
      ),
      child: onTap == null
          ? content
          : InkWell(onTap: onTap, borderRadius: borderRadius, child: content),
    );
  }
}
