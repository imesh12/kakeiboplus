/// Thrown by `CloudAccountLinkRepository.recordSignIn` when [profileId]
/// already has a remembered link to a cloud account OTHER than the one
/// being signed into.
///
/// This is the core different-account-safety mechanism Checkpoint 12.2
/// requires: "Never silently associate existing local financial data
/// with a different cloud identity." There is no code path in
/// `CloudAccountLinkRepository` that reassigns [existingCloudUserId] to
/// [attemptedCloudUserId] -- `recordSignIn` refuses the write entirely
/// and throws this instead, exactly like
/// `FxSnapshotAlreadyExistsException` refuses a second historical FX
/// snapshot rather than overwriting the first (same
/// "throw instead of silently doing the unsafe thing" shape, different
/// invariant).
///
/// V1 implements only the minimum safe behavior here: sign-in with a
/// different cloud account is refused outright, with no reset/merge
/// flow. A UI-level "sign out, then explicitly wipe this device's local
/// data to switch cloud accounts" flow is deliberately NOT implemented
/// in this checkpoint (see `docs/21_CLOUD_SYNC_ARCHITECTURE.md`'s
/// CP12.2 entry and `docs/14_DECISION_LOG.md` ADR-033) -- this exception
/// is what makes that boundary hold even before any such flow exists.
class DifferentCloudAccountLinkedException implements Exception {
  const DifferentCloudAccountLinkedException({
    required this.profileId,
    required this.existingCloudUserId,
    required this.attemptedCloudUserId,
  });

  final String profileId;
  final String existingCloudUserId;
  final String attemptedCloudUserId;

  @override
  String toString() =>
      'DifferentCloudAccountLinkedException: local profile $profileId is already linked to '
      'a different cloud account -- refusing to silently reassign its local financial data. '
      'Sign out and use the same cloud account, or see CP12.2 scope for why switching cloud '
      'accounts on a device with existing local data is not yet supported.';
}
