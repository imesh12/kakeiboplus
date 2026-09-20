import 'dart:async';

import 'cloud_auth_provider.dart';
import 'cloud_auth_session.dart';

/// A deterministic, purely in-memory [CloudAuthProvider] --
/// DEVELOPMENT AND TEST USE ONLY. Never wired into `lib/main.dart` or
/// `lib/app/app.dart`; only test files
/// (`test/features/cloud_account/...`, `test/core/cloud_identity/...`)
/// construct this class. Production always resolves
/// `cloudAuthProviderProvider` to `UnavailableCloudAuthProvider` with no
/// override -- see that provider's own doc comment.
///
/// [isAvailable] is always `true` and every session it produces is a
/// deterministic, entirely fabricated in-memory value -- clearly and
/// permanently labeled as such by this class's name and location
/// (`lib/core/cloud_identity/`, alongside the interface it fakes, not
/// under `lib/features/`). Nothing here ever reaches a real network or
/// backend, and nothing it produces is ever persisted to disk by this
/// class itself (no Drift table, no file, no secure storage) -- state
/// lives only in [_session] for the lifetime of one instance, which is
/// exactly what "fake, for tests" should mean.
///
/// Also exposes [signInAs], OUTSIDE the [CloudAuthProvider] interface --
/// tests that need to simulate signing into a SPECIFIC cloud account
/// (e.g. to exercise `CloudAccountLinkRepository`'s different-account
/// refusal) call this directly rather than through the interface's
/// parameterless [signIn]. See [CloudAuthProvider.signIn]'s own doc for
/// why the interface itself never takes an account-selecting parameter.
class InMemoryCloudAuthProvider implements CloudAuthProvider {
  InMemoryCloudAuthProvider();

  static const String _defaultDevCloudUserId = 'dev-fake-cloud-user';

  CloudAuthSession? _session;
  final StreamController<CloudAuthSession?> _controller =
      StreamController<CloudAuthSession?>.broadcast();

  @override
  bool get isAvailable => true;

  @override
  Stream<CloudAuthSession?> watchSession() async* {
    // Replays the current snapshot to every new listener before future
    // events -- same "a fresh subscriber immediately sees where things
    // stand" contract `ProfileRepository.watchProfile`'s underlying
    // Drift stream gives for free; a hand-written broadcast
    // `StreamController` does not do this on its own, so it's done
    // explicitly here.
    yield _session;
    yield* _controller.stream;
  }

  @override
  Future<CloudAuthSession> signIn() => signInAs(_defaultDevCloudUserId);

  /// Test/dev-only: signs in as a specific [cloudUserId], simulating
  /// exactly what a real backend's auth flow would eventually resolve to
  /// -- see the class doc.
  Future<CloudAuthSession> signInAs(String cloudUserId) async {
    final CloudAuthSession session = CloudAuthSession(cloudUserId: cloudUserId);
    _session = session;
    _controller.add(session);
    return session;
  }

  @override
  Future<void> signOut() async {
    _session = null;
    _controller.add(null);
  }

  /// Test-only: simulates a session disappearing WITHOUT an explicit
  /// [signOut] call -- e.g. a token silently expiring server-side. Used
  /// to exercise the session-expiration reconciliation path (CP12.2)
  /// without a real backend to expire a real token against.
  void simulateSessionDroppedWithoutSignOut() {
    _session = null;
    _controller.add(null);
  }

  /// Releases this provider's internal stream controller. Tests should
  /// call this in `tearDown`/`addTearDown` once they're done with an
  /// instance, matching every other disposable test double in this
  /// codebase.
  Future<void> dispose() => _controller.close();
}
