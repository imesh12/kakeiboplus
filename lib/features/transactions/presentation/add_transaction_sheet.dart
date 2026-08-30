import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';

/// The "+ Add" menu (Master Blueprint §38): a modal sheet, not a fifth
/// navigation-bar destination. Beta 0 only enables Expense / Income /
/// Transfer — Receipt and Goal Contribution are omitted entirely rather
/// than shown disabled, per Decision 12 ("should not pretend to work
/// before their stages").
Future<void> showAddTransactionSheet(BuildContext context) {
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
              title: const Text('Expense'),
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
              title: const Text('Income'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.push('${AppRoutes.addTransaction}?type=income');
              },
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('Transfer'),
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
