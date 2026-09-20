/// The secure-storage boundary Checkpoint 12.2 requires for any future
/// access/refresh token: "Do not store access/refresh tokens in
/// ordinary Drift tables. Define/use a secure-storage boundary
/// appropriate for Android/iOS."
///
/// # Why V1 defines this interface but ships no real implementation
///
/// There is currently no real cloud backend (`UnavailableCloudAuthProvider`
/// is production's only `CloudAuthProvider`), so production never has an
/// actual token to store -- there is nothing for a real implementation
/// to do yet. A genuine platform-secure-storage-backed implementation
/// (e.g. via Android Keystore / iOS Keychain, most likely through the
/// `flutter_secure_storage` package) is a NEW DEPENDENCY, and CP12.2's
/// instruction is explicit: "If implementing secure token persistence
/// requires a new dependency: STOP before adding it and report the
/// recommendation." This checkpoint's final report does exactly that --
/// recommends `flutter_secure_storage` for whichever future checkpoint
/// first has a real token to persist -- without adding the dependency
/// now, since nothing in V1 actually needs it to function.
///
/// Defining the interface now (with only a test double behind it, see
/// [InMemorySecureTokenStore]) means that future checkpoint only ever
/// adds a new class here, never changes to any call site that already
/// depends on this boundary.
///
/// # The one invariant that already matters today
///
/// No implementation of this interface may EVER be backed by a Drift
/// table, a plain file, `SharedPreferences`, or any other
/// non-secure/non-platform-secure storage -- see
/// `docs/14_DECISION_LOG.md` ADR-033 for CP12.2's identity/auth
/// decisions, including this one.
abstract class SecureTokenStore {
  /// Reads the value stored under [key], or `null` if nothing is stored.
  Future<String?> read(String key);

  /// Stores [value] under [key], replacing any existing value.
  Future<void> write(String key, String value);

  /// Removes any value stored under [key]. A no-op if nothing was
  /// stored.
  Future<void> delete(String key);
}

/// A purely in-memory [SecureTokenStore] -- DEVELOPMENT AND TEST USE
/// ONLY, exactly like `InMemoryCloudAuthProvider`
/// (`in_memory_cloud_auth_provider.dart`) it is meant to accompany.
/// Never persists anything to disk, never touches any platform secure
/// storage API, and loses everything the moment the instance is
/// discarded -- which is exactly right for a fake that must never be
/// mistaken for the real thing. Never wired into production.
class InMemorySecureTokenStore implements SecureTokenStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }
}
