import 'cloud_auth_exceptions.dart';
import 'cloud_auth_provider.dart';
import 'cloud_auth_session.dart';

/// The production [CloudAuthProvider] for every build until a real
/// backend exists -- see `docs/21_CLOUD_SYNC_ARCHITECTURE.md` §8 for the
/// planned FastAPI backend this will eventually be replaced/joined by.
///
/// Truthfully and permanently reports "not configured": [isAvailable]
/// is always `false`, [watchSession] always emits `null` (never a fake
/// session), and [signIn] always throws
/// [CloudAuthNotConfiguredException] rather than fabricating a
/// successful sign-in. This is what makes CP12.2's "do NOT fake
/// successful production authentication" instruction true by
/// construction rather than by convention -- there is no code path in
/// this class that can produce a non-null [CloudAuthSession].
///
/// [signOut] is a no-op that always succeeds: there is never a real
/// session to end, and a caller reconciling local state (e.g. after
/// detecting a stale link -- see `CloudAccountLinkRepository
/// .recordSignOut`) should never have to special-case "the provider
/// says there's nothing to sign out of."
///
/// Wired as the sole [CloudAuthProvider] implementation `main.dart`/
/// `app.dart` ever reach -- see
/// `lib/features/cloud_account/presentation/cloud_account_providers.dart`
/// `cloudAuthProviderProvider`, which resolves to this class with no
/// override in production, and only `InMemoryCloudAuthProvider` in
/// tests.
class UnavailableCloudAuthProvider implements CloudAuthProvider {
  const UnavailableCloudAuthProvider();

  @override
  bool get isAvailable => false;

  @override
  Stream<CloudAuthSession?> watchSession() => Stream<CloudAuthSession?>.value(null);

  @override
  Future<CloudAuthSession> signIn() async {
    throw const CloudAuthNotConfiguredException();
  }

  @override
  Future<void> signOut() async {
    // Nothing to sign out of -- see class doc.
  }
}
