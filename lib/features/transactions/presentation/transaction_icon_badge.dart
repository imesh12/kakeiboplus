import 'package:flutter/material.dart';

import '../../categories/domain/category_icon.dart';

/// A small rounded-square tinted icon badge for one transaction row --
/// Beta 1 Transaction UX Phase B, Checkpoint 2
/// (`docs/14_DECISION_LOG.md` ADR-025/026).
///
/// Mirrors the tinted icon-badge idiom `home_screen.dart`'s
/// `_MetricTile` already establishes (a soft, [color]-tinted background
/// behind a [color]-tinted icon) rather than inventing a new visual
/// language, and is entirely [ColorScheme]-driven through the [color]
/// the caller passes in -- this widget never hardcodes a `Color`
/// constant of its own.
///
/// For `type == 'transfer'`, always shows the transfer icon -- a
/// transfer never carries a category (ADR-025 Correction 2), so
/// [categoryIconName] is expected (but not required) to be `null` in
/// that case. For `'expense'`/`'income'` WITH a category chosen, shows
/// that category's icon via [categoryIconFor] (which itself falls back
/// safely for an unrecognized icon name). For `'expense'`/`'income'`
/// with NO category chosen ([categoryIconName] is `null`), falls back
/// to the same plain "+"/"-" icon Activity used before this checkpoint
/// -- preserved deliberately so the expense/income distinction never
/// depends on a category being present, on top of [color] and the
/// caller's separate sign-prefixed amount text.
class TransactionIconBadge extends StatelessWidget {
  const TransactionIconBadge({
    required this.type,
    required this.color,
    super.key,
    this.categoryIconName,
  });

  /// `'expense'` | `'income'` | `'transfer'` -- `Transaction.type`.
  final String type;
  final Color color;
  final String? categoryIconName;

  @override
  Widget build(BuildContext context) {
    final IconData icon = switch (type) {
      'transfer' => Icons.swap_horiz,
      'income' => categoryIconName != null ? categoryIconFor(categoryIconName) : Icons.add,
      _ => categoryIconName != null ? categoryIconFor(categoryIconName) : Icons.remove,
    };
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}
