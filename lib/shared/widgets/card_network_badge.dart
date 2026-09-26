import 'package:flutter/material.dart';

import '../../core/finance/card_network.dart';
import '../../l10n/generated/app_localizations.dart';
import 'app_status_chip.dart';

/// Checkpoint U1 (Category, Service, Currency & Card Visual Identity
/// Foundation): shows a payment instrument's [CardNetwork] as a small
/// pill -- reuses [AppStatusChip] directly rather than inventing a new
/// pill shape (see `REUSE BEFORE CREATION` in the project's own UI/UX
/// guidance), since a network badge is exactly that primitive's
/// existing "small label + color" shape with nothing extra.
///
/// # Text, deliberately never a recreated brand logo
///
/// The checkpoint brief explicitly warns against "fake approximations
/// of trademarks merely to imitate them" and against recoloring/
/// reproducing brand logos. This badge renders the network's plain
/// NAME as text (reusing the exact labels
/// `add_account_form_screen.dart`'s network dropdown already
/// localizes -- `addAccountCardNetwork*` -- rather than adding a
/// second, possibly-divergent copy of the same four/five names), never
/// an image asset -- which sidesteps that concern entirely rather than
/// trying to license/recreate real network marks. This also means the
/// badge works fully offline with zero new asset files, per the
/// brief's own "must work offline" / "avoid a remote logo dependency"
/// requirements.
///
/// # Only when genuinely known
///
/// [network] is nullable, matching `PaymentInstruments.network`'s own
/// nullability exactly -- a `null` network (never fabricated, never
/// guessed from a card number -- this widget doesn't even accept one)
/// renders the neutral [AppLocalizations.cardNetworkBadgeUnknownLabel]
/// fallback rather than omitting the badge or throwing.
class CardNetworkBadge extends StatelessWidget {
  const CardNetworkBadge({required this.network, super.key});

  final CardNetwork? network;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme colors = Theme.of(context).colorScheme;
    return AppStatusChip(label: _label(l10n), color: colors.onSurfaceVariant);
  }

  String _label(AppLocalizations l10n) {
    return switch (network) {
      CardNetwork.visa => l10n.addAccountCardNetworkVisa,
      CardNetwork.mastercard => l10n.addAccountCardNetworkMastercard,
      CardNetwork.jcb => l10n.addAccountCardNetworkJcb,
      CardNetwork.amex => l10n.addAccountCardNetworkAmex,
      CardNetwork.other => l10n.addAccountCardNetworkOther,
      null => l10n.cardNetworkBadgeUnknownLabel,
    };
  }
}
