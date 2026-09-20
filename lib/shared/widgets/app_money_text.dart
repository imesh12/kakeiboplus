import 'package:flutter/material.dart';

import '../theme/app_typography.dart';

/// Visual hierarchy variant for [AppMoneyText] -- purely which
/// [AppTypography] money role backs it (hero/primary/secondary size), not
/// a formatting decision.
enum AppMoneyEmphasis { hero, primary, secondary }

/// Visual System Convergence Checkpoint 7.1's shared money-display
/// primitive: consistent visual hierarchy ONLY.
///
/// # What this deliberately does NOT do
///
/// This widget MUST NOT format money itself -- it renders exactly the
/// [formattedAmount] string it is given, verbatim, with no reformatting,
/// truncation, or currency-specific branching. `MoneyFormatter`
/// (`lib/core/money/money_formatter.dart`) and `CurrencyRegistry` remain
/// the sole authority on what digits/symbol/precision a `Money` value
/// renders as -- every call site must format its `Money` through
/// `MoneyFormatter` first and pass the resulting `String` in here.
///
/// It also never wraps its `Text` in a `FittedBox`, never sets
/// `maxLines`, and never applies `TextOverflow.ellipsis` -- every digit
/// [formattedAmount] contains is always rendered, in full, exactly like
/// every existing money `Text` on Home today. A caller that needs
/// shrink-to-fit behavior (e.g. the hero/secondary currency cards' large
/// balances) keeps doing that itself by wrapping this widget in its own
/// `FittedBox`, precisely as those call sites already do for the raw
/// `Text` this replaces -- this widget changes nothing about that
/// surrounding behavior.
///
/// [emphasis] selects which of [AppTypography]'s three money roles
/// ([AppTypography.largeMoney]/[AppTypography.mediumMoney]/
/// [AppTypography.smallMoney]) backs the text; [color] optionally
/// overrides that role's color (e.g. `colorScheme.error` for a negative
/// balance) without touching its size/weight.
class AppMoneyText extends StatelessWidget {
  const AppMoneyText(
    this.formattedAmount, {
    super.key,
    this.emphasis = AppMoneyEmphasis.primary,
    this.color,
  });

  /// Already-formatted output of `MoneyFormatter.format(...)` -- never a
  /// raw `Money`/`num`/minor-units value. This widget performs no
  /// currency lookup and no digit manipulation of its own.
  final String formattedAmount;

  final AppMoneyEmphasis emphasis;

  /// Overrides the resolved style's color only; leaves font size/weight
  /// untouched. Null keeps the role's own default color (`onSurface`/
  /// theme text color).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final AppTypography typography = context.appTypography;
    // Checkpoint 10 (Icon-Led UI Foundation): `.hero` now resolves to the
    // new `AppTypography.heroMoney` role (headlineLarge/32, vs.
    // `largeMoney`'s headlineMedium/28) -- matching the approved
    // reference's more dominant total-balance figure. This is a visual
    // size bump for every existing `.hero`-emphasis call site (today,
    // exactly one: `home_screen.dart`'s hero currency card balance,
    // already wrapped in its own `FittedBox(fit: BoxFit.scaleDown)`, so a
    // larger source style still never overflows). `.primary`/`.secondary`
    // are completely unchanged.
    final TextStyle? style = switch (emphasis) {
      AppMoneyEmphasis.hero => typography.heroMoney,
      AppMoneyEmphasis.primary => typography.mediumMoney,
      AppMoneyEmphasis.secondary => typography.smallMoney,
    };
    return Text(formattedAmount, style: color == null ? style : style?.copyWith(color: color));
  }
}
