/// Thrown by [AccountRepository.updateAccount] when the account either
/// doesn't exist, is soft-deleted, or (in an unreachable-in-practice
/// race) no longer matches what the caller expected at write time.
///
/// Never a silent no-op: an edit the UI believes succeeded must never be
/// one that changed nothing underneath it -- same discipline
/// `TransactionNotFoundException` already applies to transaction edits.
class AccountNotFoundException implements Exception {
  const AccountNotFoundException(this.accountId);

  final String accountId;

  @override
  String toString() => 'AccountNotFoundException: no active account with id $accountId';
}
