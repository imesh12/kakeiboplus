import 'package:flutter/material.dart';

import 'mascot_key.dart';

/// The Dashboard's default hero/header mascot -- a purely decorative
/// branding element with no unique financial information of its own.
///
/// # Presentation/branding only
///
/// This widget (and everything in `lib/shared/branding/`) exists
/// purely to render a personality layer on top of the deterministic
/// financial screens. It never reads, computes, or displays any
/// financial data itself, and nothing here is ever treated as domain
/// truth -- see [MascotKey]'s own doc comment.
///
/// # Why no `Semantics` wrapper
///
/// Unlike the More screen's wordmark image (`more_screen.dart`), which
/// wraps its `Image.asset` in an explicit `Semantics(label: ...,
/// image: true)` because the wordmark IS the informational content on
/// that row, this mascot conveys no unique information a screen
/// reader user would otherwise miss -- the greeting text beside it
/// already carries the same "hello" sentiment. `excludeFromSemantics:
/// true` below, with no wrapping `Semantics` of its own, keeps this
/// image fully silent to screen readers rather than adding a noisy,
/// uninformative announcement, matching this project's existing
/// "avoid duplicate/unnecessary semantics" principle.
///
/// # Layout contract -- why this is safe beside financial text
///
/// Callers size this via [height]; width follows automatically via
/// `BoxFit.contain`, so the source PNG's own aspect ratio (and its
/// transparent background) is preserved and the mascot itself is
/// never clipped. This widget is meant to be placed as a fixed-size
/// sibling in a `Row`/`Flex` alongside flexible content (e.g.
/// `Expanded(child: Text(...))`) -- NOT inside a `Stack` overlaid on
/// top of any card that shows a balance, budget figure, or other
/// financial text. `BoxFit.contain` only guarantees the mascot itself
/// renders without clipping; it cannot guarantee it won't obscure
/// whatever it's drawn on top of -- that guarantee has to come from
/// the caller's layout choice instead.
///
/// See `home_screen.dart`'s call site for why the header -- not
/// `_HeroCurrencyCard`'s own `Stack`, despite that class's older doc
/// comment anticipating a possible future mascot overlay there -- was
/// chosen for this default mascot: a `Row` alongside the greeting can
/// never overlap anything, by construction, regardless of locale/
/// translation length or how many digits the balance below happens to
/// need. `_HeroCurrencyCard`'s seam remains available for a future,
/// different treatment (e.g. an animated companion reacting to the
/// balance itself) that genuinely needs to live on that card.
class DashboardMascot extends StatelessWidget {
  const DashboardMascot({super.key, this.mascotKey = MascotKey.defaultDog, this.height = 56});

  final MascotKey mascotKey;

  /// Logical height. Width follows naturally via `BoxFit.contain`.
  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      mascotAssetPathFor(mascotKey),
      height: height,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
      // Defensive only: an asset load failure (e.g. a future variant
      // added to the enum map before its file actually ships)
      // degrades to rendering nothing rather than throwing inside the
      // Dashboard -- this is a purely decorative widget, never worth
      // crashing a financial screen over.
      errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) =>
          const SizedBox.shrink(),
    );
  }
}
