import 'cloud_auth_session.dart';

/// The replaceable auth/session provider boundary Checkpoint 12.2
/// requires -- "Do not hard-wire UI/domain code directly to a vendor
/// SDK. Create an abstraction suitable for the planned FastAPI backend,
/// with a replaceable auth/session provider boundary."
///
/// No UI or domain code (`lib/features/cloud_account/...`,
/// `lib/features/settings/...`) may import a vendor SDK or talk to a
/// concrete backend directly -- everything goes through this interface.
/// V1 ships exactly two implementations:
///
/// - `UnavailableCloudAuthProvider` -- production. Truthfully reports
///   "not configured" and never fakes a successful sign-in.
/// - `InMemoryCloudAuthProvider` (`in_memory_cloud_auth_provider.dart`)
///   -- development/test only, clearly labeled, never wired into the
///   production entrypoint (`lib/main.dart`/`lib/app/app.dart`).
///
/// A real implementation talking to the planned FastAPI backend is
/// explicitly deferred CP12.3+ work -- see this checkpoint's final
/// report. Adding it later means adding a new class here, never
/// changing this interface's shape or any call site that depends on it.
abstract class CloudAuthProvider {
  /// Whether this provider is backed by a real, configured cloud
  /// backend. `false` in every production build today (V1 has no
  /// backend yet) -- callers must check this before assuming [signIn]
  /// can succeed, and the UI layer uses it to render an honest
  /// "unavailable" state rather than a broken sign-in button.
  bool get isAvailable;

  /// Emits the current session, replaying it to every new listener (like
  /// every other live stream in this app -- see
  /// `ProfileRepository.watchProfile`'s doc comment for the same
  /// convention), then emitting again on every subsequent sign-in/
  /// sign-out/expiry. `null` means "no active session" -- signed out,
  /// or this provider is [isAvailable] == false.
  Stream<CloudAuthSession?> watchSession();

  /// Starts a sign-in. Throws [CloudAuthNotConfiguredException] when
  /// [isAvailable] is `false` -- never fakes a successful production
  /// sign-in (CP12.2's explicit instruction).
  ///
  /// Deliberately takes no parameters describing WHICH cloud account to
  /// sign into -- a real backend's auth flow (e.g. an OAuth redirect)
  /// determines the resulting [CloudAuthSession.cloudUserId] itself; the
  /// caller never chooses it. `InMemoryCloudAuthProvider` exposes its
  /// own additional dev/test-only `signInAs(String cloudUserId)` method
  /// for simulating a specific account, outside this interface.
  Future<CloudAuthSession> signIn();

  /// Ends the current session, if any. Never touches local financial
  /// data -- signing out of the cloud identity layer and deleting local
  /// data are completely separate operations (CP12.2: "Do not delete
  /// local financial data automatically").
  Future<void> signOut();
}
