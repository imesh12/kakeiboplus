import 'package:meta/meta.dart';

import '../../../core/cloud_identity/cloud_account_link_status.dart';

/// The 4 truthful states the Cloud Account UI must be able to
/// distinguish -- Checkpoint 12.2: "The UI must truthfully distinguish:
/// local-only; signed in; session expired; cloud/auth unavailable/not
/// configured." None of these ever implies financial sync has happened
/// -- CP12.2 is explicit that the UI must never claim "Synced"/
/// "Backed up"/"Up to date", and no [CloudAccountStatusKind] value here
/// means or implies any of those.
enum CloudAccountStatusKind {
  /// No cloud backend is configured in this build (every production
  /// build today -- see `UnavailableCloudAuthProvider`). Distinct from
  /// [localOnly]: this means cloud accounts cannot be used AT ALL right
  /// now, not merely "you haven't signed in yet."
  unavailable,

  /// A cloud backend IS available (`CloudAuthProvider.isAvailable` is
  /// `true` -- true only in dev/test in V1), but this profile has no
  /// active session and no remembered link. All data stays local.
  localOnly,

  /// This profile has a live session with a cloud account.
  signedIn,

  /// This profile's session disappeared without an explicit sign-out
  /// (CP12.2's "session expired / reauthentication required" state).
  /// Local financial data on this device is completely unaffected.
  sessionExpired,
}

/// Merges provider availability + live session + persisted local link
/// state into one value the UI renders from -- see [resolve] for the
/// decision table. Deliberately computed fresh from its inputs every
/// time rather than stored anywhere; there is no "CloudAccountStatus"
/// column in any table.
@immutable
class CloudAccountStatus {
  const CloudAccountStatus._(this.kind, this.cloudUserId);

  const CloudAccountStatus.unavailable() : this._(CloudAccountStatusKind.unavailable, null);

  const CloudAccountStatus.localOnly() : this._(CloudAccountStatusKind.localOnly, null);

  const CloudAccountStatus.signedIn(String cloudUserId)
      : this._(CloudAccountStatusKind.signedIn, cloudUserId);

  const CloudAccountStatus.sessionExpired(String cloudUserId)
      : this._(CloudAccountStatusKind.sessionExpired, cloudUserId);

  final CloudAccountStatusKind kind;

  /// Non-null only for [CloudAccountStatusKind.signedIn] and
  /// [CloudAccountStatusKind.sessionExpired] -- the two states that have
  /// a specific cloud account to refer to.
  final String? cloudUserId;

  /// Combines [providerAvailable] (`CloudAuthProvider.isAvailable`),
  /// [liveSessionCloudUserId] (the current
  /// `CloudAuthSession?.cloudUserId` from `watchSession()`, already
  /// unwrapped by the caller), and [persistedLinkStatus] +
  /// [persistedLinkCloudUserId] (the current `CloudAccountLinks` row's
  /// `status`/`cloudUserId`, if any) into exactly one
  /// [CloudAccountStatusKind]:
  ///
  /// 1. Provider unavailable -> [CloudAccountStatusKind.unavailable],
  ///    regardless of any persisted link (an unavailable provider can
  ///    never have a live session to contradict a stale link either).
  /// 2. A live session exists -> [CloudAccountStatusKind.signedIn] with
  ///    that session's cloud user id -- the live session is always
  ///    authoritative over the persisted link when both are present.
  /// 3. No live session, but the persisted link's status is
  ///    [CloudAccountLinkStatus.active] ->
  ///    [CloudAccountStatusKind.sessionExpired]. This is the
  ///    reconciliation case: the link was never explicitly signed out,
  ///    yet the provider no longer has a session for it -- exactly what
  ///    CP12.2 calls "session expired / reauthentication required."
  /// 4. Otherwise (no live session, and no link, or the link is
  ///    `signedOut`/`sessionExpired` already) ->
  ///    [CloudAccountStatusKind.localOnly].
  static CloudAccountStatus resolve({
    required bool providerAvailable,
    required String? liveSessionCloudUserId,
    required CloudAccountLinkStatus? persistedLinkStatus,
    required String? persistedLinkCloudUserId,
  }) {
    if (!providerAvailable) return const CloudAccountStatus.unavailable();
    if (liveSessionCloudUserId != null) {
      return CloudAccountStatus.signedIn(liveSessionCloudUserId);
    }
    if (persistedLinkStatus == CloudAccountLinkStatus.active && persistedLinkCloudUserId != null) {
      return CloudAccountStatus.sessionExpired(persistedLinkCloudUserId);
    }
    return const CloudAccountStatus.localOnly();
  }

  @override
  bool operator ==(Object other) =>
      other is CloudAccountStatus && other.kind == kind && other.cloudUserId == cloudUserId;

  @override
  int get hashCode => Object.hash(kind, cloudUserId);

  @override
  String toString() => 'CloudAccountStatus(kind: $kind, cloudUserId: $cloudUserId)';
}
