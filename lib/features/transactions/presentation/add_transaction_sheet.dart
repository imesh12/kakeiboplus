import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../l10n/generated/app_localizations.dart';

/// The "+ Add" menu (Master Blueprint §38): a modal sheet, not a fifth
/// navigation-bar destination. Beta 0 only enables Expense / Income /
/// Transfer — Receipt and Goal Contribution are omitted entirely rather
/// than shown disabled, per Decision 12 ("should not pretend to work
/// before their stages").
Future<void> showAddTransactionSheet(BuildContext context) {
  // CP6.1 (Localization Phase 1): resolved once from the caller's own
  // context (already inside `MaterialApp.router`'s `Localizations`
  // subtree via `AppShell`) rather than re-resolving from `sheetContext`
  // per builder call -- there is only ever one build of this sheet's
  // content per invocation, so there is no benefit to re-reading it
  // from the modal's own (about-to-be-popped) context instead.
  final AppLocalizations l10n = AppLocalizations.of(context);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.remove_circle_outline),
              title: Text(l10n.transactionTypeExpense),
              onTap: () {
                Navigator.of(sheetContext).pop();
                // Navigate via the ORIGINAL `context` (the screen behind
                // the sheet), not `sheetContext` — the sheet's own
                // context belongs to a route that is being popped, so
                // routing through it is unnecessary risk for no benefit.
                context.push('${AppRoutes.addTransaction}?type=expense');
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: Text(l10n.transactionTypeIncome),
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.push('${AppRoutes.addTransaction}?type=income');
              },
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: Text(l10n.transactionTypeTransfer),
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.push('${AppRoutes.addTransaction}?type=transfer');
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
