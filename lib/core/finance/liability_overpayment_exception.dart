import '../money/money.dart';

/// Thrown by [FinanceEngine.accountBalance] when folding a liability
/// account's full transaction history would leave it owing a negative
/// amount -- i.e. more has been paid toward the debt than was ever owed.
///
/// This is Checkpoint C's frozen decision for the "liability overpayment
/// / negative owed" edge case (see the checkpoint brief and
/// `docs/14_DECISION_LOG.md` ADR-035): V1 does **not** silently clamp an
/// overpaid liability to zero, and does not invent a "credit balance"
/// representation for the difference -- both are separate design work
/// for a future checkpoint. Rejecting loudly here means a data or UI bug
/// that lets a payment exceed what's owed surfaces immediately, rather
/// than silently producing a balance no product screen has a defined
/// meaning for.
class LiabilityOverpaymentException implements Exception {
  const LiabilityOverpaymentException({required this.accountId, required this.resultingBalance});

  final String accountId;

  /// What [FinanceEngine.accountBalance] computed before rejecting --
  /// negative in class-native "amount owed" terms. Included only for
  /// diagnostics; nothing persists this value.
  final Money resultingBalance;

  @override
  String toString() =>
      'LiabilityOverpaymentException: liability account $accountId would '
      'owe a negative amount (${resultingBalance.toMajorUnitsString()} '
      '${resultingBalance.currencyCode}) after applying its full '
      'transaction history -- V1 does not represent an overpaid '
      'liability; see docs/14_DECISION_LOG.md.';
}
