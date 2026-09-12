import 'package:flutter/widgets.dart';

/// CP5.6 (RTL Smoke / Directional Layout Audit) shared TEST-ONLY harness --
/// used by every widget test that needs to pump a screen under
/// [TextDirection.rtl] to validate *layout directionality*, not translated
/// content. Nothing here touches locale, `AppLocalizations`, or any ARB
/// file -- this is not an Arabic localization rollout.
///
/// A `MaterialApp`/`MaterialApp.router` always builds its own
/// `Directionality` internally (derived from the resolved locale via
/// `WidgetsApp`), so wrapping an already-built `MaterialApp` in
/// `Directionality` from the *outside* has no effect -- the inner one
/// shadows it for every descendant. Passing [rtlAppBuilder] as that
/// `MaterialApp`'s own `builder:` instead re-parents the routed content
/// under a forced RTL `Directionality` from *inside* the already-built
/// `Localizations`/`MediaQuery` tree, which is what every widget under
/// test actually reads back via `Directionality.of(context)` (and what
/// `Row`, `Align`(Directional), `EdgeInsets(Directional)`, etc. all key
/// off of).
///
/// Usage: give an existing test app-builder helper an `{bool rtl = false}`
/// parameter and pass `builder: rtl ? rtlAppBuilder : null` to its
/// `MaterialApp`/`MaterialApp.router` call -- see
/// `test/widget/app_shell_test.dart`, `test/widget/accounts_screen_test.dart`,
/// `test/widget/home_screen_test.dart`, `test/widget/activity_screen_test.dart`,
/// and `test/widget/goal_detail_screen_test.dart` for the pattern.
Widget rtlAppBuilder(BuildContext context, Widget? child) {
  return Directionality(
    textDirection: TextDirection.rtl,
    child: child ?? const SizedBox.shrink(),
  );
}
