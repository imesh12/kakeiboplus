import 'transaction_type.dart';

/// Thrown by [FinanceEngine.accountBalance] when a transaction's role is
/// structurally invalid for a liability account -- see
/// `docs/20_ACCOUNTS_ASSETS_HOUSEHOLD_ARCHITECTURE.md` §12.3 (the frozen
/// sign-convention effect table) and ADR-035.
///
/// V1 defines exactly two invalid liability roles, and both throw this
/// rather than silently producing an undefined balance:
///
/// - a [TransactionType.income] transaction targeting a liability
///   account -- there is no V1 product concept of "income" paid onto a
///   debt; a liability only grows via [TransactionType.expense] and only
///   shrinks via being the *destination* side of a
///   [TransactionType.transfer] payment;
/// - a liability account used as the *source* of a
///   [TransactionType.transfer] -- a liability cannot itself send money
///   in V1, it can only receive a payment as the destination side.
///
/// Refund-to-credit-card, cash advances, balance transfers, interest, and
/// fees beyond an ordinary expense are explicitly out of scope for this
/// checkpoint (deferred by the architecture freeze) and are not what
/// this exception represents -- it exists only for the two roles above.
class InvalidLiabilityOperationException implements Exception {
  const InvalidLiabilityOperationException({
    required this.accountId,
    required this.transactionId,
    required this.transactionType,
    required this.reason,
  });

  final String accountId;
  final String transactionId;
  final TransactionType transactionType;

  /// Short, human-readable explanation of which of the two invalid roles
  /// this was -- see the class doc.
  final String reason;

  @override
  String toString() =>
      'InvalidLiabilityOperationException: transaction $transactionId '
      '(${transactionType.name}) is not a valid operation on liability '
      'account $accountId -- $reason';
}
