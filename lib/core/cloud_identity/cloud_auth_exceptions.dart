/// Thrown by a `CloudAuthProvider` when a caller attempts an action that
/// requires a real, configured backend and none is wired up --
/// currently every production build, since Checkpoint 12.2 introduces
/// only the identity/auth FOUNDATION, not a real FastAPI backend
/// integration (see `docs/21_CLOUD_SYNC_ARCHITECTURE.md` §8/roadmap).
///
/// `UnavailableCloudAuthProvider.signIn()` throws this rather than
/// faking a successful sign-in -- CP12.2's explicit instruction is "If a
/// real external auth provider/backend does not yet exist, do NOT fake
/// successful production authentication."
class CloudAuthNotConfiguredException implements Exception {
  const CloudAuthNotConfiguredException();

  @override
  String toString() =>
      'CloudAuthNotConfiguredException: no cloud auth backend is configured in this build. '
      'Cloud sign-in is not available yet -- the app remains fully usable locally without it.';
}
