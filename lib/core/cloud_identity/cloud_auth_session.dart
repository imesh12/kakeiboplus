import 'package:meta/meta.dart';

/// The smallest local representation of "signed in as one authenticated
/// cloud user" -- Checkpoint 12.2 (Cloud Identity / Auth Foundation).
///
/// Deliberately holds nothing but [cloudUserId]. No access/refresh
/// token, no password, no email, no display name: V1 has no real
/// backend to source any of that from truthfully yet (see
/// `UnavailableCloudAuthProvider`'s own doc comment), and this class's
/// only job is to answer "which stable, server-assigned cloud user is
/// this session for" -- see
/// `docs/21_CLOUD_SYNC_ARCHITECTURE.md` §3 for the full V1 identity
/// contract. A future checkpoint that adds a real backend and needs to
/// carry richer session data (email, tokens, expiry) extends this class
/// deliberately then -- it is not guessed at here.
///
/// [cloudUserId] must always be supplied by the authenticated server or
/// provider that produced this session -- never manufactured locally,
/// and never conflated with any client-generated id (a transaction id, a
/// local profile id, a future device/install id). See
/// `CloudAuthProvider` for who is trusted to construct one of these.
@immutable
class CloudAuthSession {
  const CloudAuthSession({required this.cloudUserId});

  /// The stable, server-assigned cloud user identifier.
  final String cloudUserId;

  @override
  bool operator ==(Object other) =>
      other is CloudAuthSession && other.cloudUserId == cloudUserId;

  @override
  int get hashCode => cloudUserId.hashCode;

  /// Deliberately includes [cloudUserId] -- an opaque server-assigned
  /// identifier, not a secret (unlike a token, which this class never
  /// carries in the first place -- see the class doc). Safe to log for
  /// debugging, matching the checkpoint's "never log tokens/authorization
  /// headers/passwords/sensitive financial payloads" rule, which this
  /// does not touch.
  @override
  String toString() => 'CloudAuthSession(cloudUserId: $cloudUserId)';
}
