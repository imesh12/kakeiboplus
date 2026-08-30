import 'package:meta/meta.dart';

import '../money/money.dart';
import 'transaction_type.dart';

/// A pure-Dart, database-agnostic view of one transaction row, for use by
/// [FinanceEngine] and its tests. Repositories are responsible for
/// mapping Drift rows to/from this shape (see
/// `lib/features/transactions/data/transaction_repository.dart`) — the
/// finance engine itself never depends on Drift or Flutter, which is what
/// lets its rules be unit-tested with plain in-memory lists.
@immutable
class LedgerTransaction {
  const LedgerTransaction({
    required this.id,
    required this.accountId,
    required this.type,
    required this.amount,
    required this.occurredAtUtc,
    this.destinationAccountId,
    this.categoryId,
    this.isDeleted = false,
  });

  final String id;
  final String accountId;

  /// Set only for [TransactionType.transfer]; the account money moves
  /// *into*. [accountId] is always the account money moves *out of* (the
  /// source) for a transfer.
  final String? destinationAccountId;

  final TransactionType type;

  /// Always a positive (or zero) magnitude — direction is determined by
  /// [type] and which of [accountId]/[destinationAccountId] is being
  /// asked about, not by the sign of [amount] itself.
  final Money amount;

  final String? categoryId;

  /// Stored/compared in UTC. See `STAGE1_BETA0_IMPLEMENTATION_PLAN.md`
  /// §10: aggregation must not depend on the device's current timezone
  /// setting at query time — only on the range boundaries passed in.
  final DateTime occurredAtUtc;

  final bool isDeleted;
}

/// A pure-Dart view of one account, for [FinanceEngine].
@immutable
class LedgerAccount {
  const LedgerAccount({
    required this.id,
    required this.currencyCode,
    required this.openingBalance,
  });

  final String id;
  final String currencyCode;
  final Money openingBalance;
}

/// The result of [FinanceEngine.incomeExpenseTotals].
@immutable
class MoneyTotals {
  const MoneyTotals({required this.income, required this.expense});

  final Money income;
  final Money expense;
}
