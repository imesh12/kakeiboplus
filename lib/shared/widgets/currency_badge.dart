import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../theme/app_tokens.dart';

/// Checkpoint U1 (Category, Service, Currency & Card Visual Identity
/// Foundation): a small, secondary presentation badge for a currency's
/// ISO 4217 [currencyCode].
///
/// # Code stays authoritative, a region indicator is optional decoration
///
/// The checkpoint brief is explicit that the currency CODE (and, at a
/// call site's own discretion, its symbol -- via the existing `Money`/
/// `MoneyFormatter` infrastructure, never duplicated here) remains the
/// authoritative identifier; a flag/region glyph is at most secondary
/// decoration. This widget always renders [currencyCode] itself; the
/// optional monogram [showRegionIndicator] adds is deliberately NOT an
/// emoji flag (the brief's own audit concern: emoji flag glyphs render
/// inconsistently across platforms/fonts) and deliberately does NOT
/// claim "this currency belongs to exactly one country" -- see
/// [_regionGlyphFor]'s own doc comment, especially for EUR.
///
/// # Never throws, never over-claims
///
/// A currency code this widget has no region glyph for (anything not in
/// [_regionGlyphFor]'s small, explicit map) simply shows no region
/// glyph at all -- this widget never guesses a country for a currency
/// it doesn't have an explicit, deliberate answer for.
class CurrencyBadge extends StatelessWidget {
  const CurrencyBadge({
    required this.currencyCode,
    super.key,
    this.showRegionIndicator = false,
    this.prominent = false,
  });

  /// ISO 4217 alphabetic code, e.g. "JPY", "KWD". Always shown verbatim
  /// (already upper-case per `Currency.code`'s own contract).
  final String currencyCode;

  /// Whether to also show the small, secondary region monogram -- see
  /// the class doc comment. Defaults to `false`: per the checkpoint
  /// brief's own "avoid duplicating the same flag/code six times inside
  /// one card" guidance, most call sites should render the plain code
  /// badge and opt into the region monogram only where it adds real
  /// context (e.g. a currency picker/selector row).
  final bool showRegionIndicator;

  /// Matches `AppIconTile`/status-chip callers' own `prominent`-vs-quiet
  /// convention (see `home_screen.dart`'s pre-existing `_CurrencyBadge`,
  /// which this widget deliberately does not touch/replace -- that one
  /// is Dashboard-local and Dashboard is explicitly out of scope for
  /// this checkpoint). `true` uses `colorScheme.primary`/`onPrimary`
  /// (a hero-card badge); `false` (the default) uses the quieter
  /// `secondaryContainer`/`onSecondaryContainer` pairing.
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme colors = Theme.of(context).colorScheme;
    final AppTokens tokens = context.appTokens;
    final Color background = prominent ? colors.primary : colors.secondaryContainer;
    final Color foreground = prominent ? colors.onPrimary : colors.onSecondaryContainer;
    final String? regionGlyph = showRegionIndicator ? _regionGlyphFor(currencyCode) : null;

    return Semantics(
      label: l10n.currencyBadgeSemanticLabel(currencyCode),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: tokens.spacing.xs, vertical: 4),
        decoration: BoxDecoration(color: background, borderRadius: tokens.radii.pillRadius),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (regionGlyph != null) ...<Widget>[
              Text(
                regionGlyph,
                maxLines: 1,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: foreground.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              currencyCode,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: foreground, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small, deliberate, offline, app-controlled monogram for a currency
/// code -- NEVER an emoji flag (inconsistent rendering across platforms/
/// fonts, per the checkpoint brief's own audit concern) and never a
/// downloaded/remote image.
///
/// Every entry maps a currency code to a REGION, not necessarily a
/// single country -- EUR explicitly maps to the neutral 'EU' rather
/// than arbitrarily picking one Eurozone member, per the brief's own
/// "handle EUR and other multi-region currencies via an appropriate
/// regional or neutral representation rather than arbitrarily choosing
/// one country" requirement. A currency code not listed here (any
/// currency this catalog doesn't have a deliberate answer for) returns
/// `null` -- [CurrencyBadge] then simply omits the glyph rather than
/// guessing.
String? _regionGlyphFor(String currencyCode) {
  const Map<String, String> glyphs = <String, String>{
    'JPY': 'JP',
    'KRW': 'KR',
    'VND': 'VN',
    'KWD': 'KW',
    'LKR': 'LK',
    'NPR': 'NP',
    'INR': 'IN',
    'BDT': 'BD',
    'MMK': 'MM',
    'QAR': 'QA',
    'CAD': 'CA',
    'EUR': 'EU',
    'USD': 'US',
  };
  return glyphs[currencyCode.toUpperCase()];
}
