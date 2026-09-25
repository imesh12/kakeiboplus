import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/finance/account_creation_kind.dart';
import '../../../core/routing/app_routes.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_icon_tile.dart';
import 'account_creation_kind_presentation.dart';

/// Checkpoint G (Add Account UX, docs/20 §13.4): the icon-led account
/// type chooser -- the FIRST step of the new Add Account flow, replacing
/// `accounts_screen.dart`'s old `_AddAccountDialog`'s name+type-dropdown
/// dialog. Reached by [AppRoutes.addAccount].
///
/// Every row here is a plain-language choice (docs/20 §13.4's own list:
/// Cash / Bank account / Savings account / E-money / Wallet / Deposit /
/// Credit card) -- [AccountCreationKind] is the ONLY place that maps a
/// choice to the frozen `balanceClass`/`subtype` pair it creates; this
/// screen never mentions either term to the user (per the checkpoint's
/// explicit "never expose balanceClass/asset-liability" instruction) and
/// never references them itself beyond passing [AccountCreationKind.name]
/// through the route.
///
/// Reuses [AppCard]/[AppIconTile] -- the same icon-tile-in-a-card idiom
/// already established for other rows in this app (per the checkpoint's
/// own "prefer reusing existing components" instruction) -- rather than
/// introducing a new list-row primitive for a one-screen use. The
/// title/description/icon per kind come from
/// `account_creation_kind_presentation.dart`, shared with
/// `AddAccountFormScreen`'s own `AppBar` title.
class AddAccountTypeScreen extends StatelessWidget {
  const AddAccountTypeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.addAccountTypeScreenTitle)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: <Widget>[
          for (final AccountCreationKind kind in AccountCreationKind.values)
            AppCard(
              bordered: true,
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              onTap: () => context.push(AppRoutes.addAccountForm(kind.name)),
              child: Row(
                children: <Widget>[
                  AppIconTile(icon: accountCreationKindIcon(kind), color: colorScheme.primary),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          accountCreationKindTitle(l10n, kind),
                          style: context.appTypography.sectionTitle,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          accountCreationKindDescription(l10n, kind),
                          style: context.appTypography.caption,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
