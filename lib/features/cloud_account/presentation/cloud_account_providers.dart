import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cloud_identity/cloud_account_link_status.dart';
import '../../../core/cloud_identity/cloud_auth_provider.dart';
import '../../../core/cloud_identity/cloud_auth_session.dart';
import '../../../core/cloud_identity/unavailable_cloud_auth_provider.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/providers.dart';
import '../../../core/database/repositories/different_cloud_account_linked_exception.dart';
import '../../onboarding/presentation/profile_providers.dart';
import '../domain/cloud_account_status.dart';

/// The single [CloudAuthProvider] the whole app uses. Resolves to
/// [UnavailableCloudAuthProvider] with NO override -- every production
/// build (`lib/main.dart` -> `ProviderScope` with no overrides) gets
/// the truthful "not configured" provider. Tests override this exact
/// provider with `InMemoryCloudAuthProvider` (see
/// `test/features/cloud_account/`) -- nothing else in this file, or in
/// any UI/domain code that consumes it, needs to change for a test to
/// exercise the signed-in/session-expired paths.
final Provider<CloudAuthProvider> cloudAuthProviderProvider = Provider<CloudAuthProvider>((ref) {
  return const UnavailableCloudAuthProvider();
});

/// The current session from [cloudAuthProviderProvider], live. `null`
/// means "no active session" (signed out, or the provider is
/// unavailable) -- see [CloudAuthProvider.watchSession]'s doc.
final StreamProvider<CloudAuthSession?> cloudAuthSessionProvider =
    StreamProvider<CloudAuthSession?>((ref) {
  return ref.watch(cloudAuthProviderProvider).watchSession();
});

/// The current local profile's persisted `cloud_account_links` row, or
/// `null` before a profile exists or before this profile has ever been
/// linked to a cloud account. Mirrors
/// [recurringOccurrenceRepositoryProvider]-style composition: derives
/// the id it needs (`profileId`) from [activeProfileProvider] rather
/// than requiring every call site to supply one.
final StreamProvider<CloudAccountLink?> cloudAccountLinkProvider =
    StreamProvider<CloudAccountLink?>((ref) {
  final ProfileRow? profile = ref.watch(activeProfileProvider).valueOrNull;
  if (profile == null) return Stream<CloudAccountLink?>.value(null);
  return ref.watch(cloudAccountLinkRepositoryProvider).watchLink(profile.id);
});

/// The merged, UI-facing 4-state [CloudAccountStatus] -- see that
/// class's [CloudAccountStatus.resolve] doc for the exact decision
/// table. `AsyncValue.loading()` while either the session stream or the
/// link stream hasn't produced a first value yet; `AsyncValue.error()`
/// propagates a genuine failure from either rather than papering over it
/// with a fake status (CP12.2's "truthfully distinguish" requirement
/// extends to error/loading, not just the 4 steady states).
final Provider<AsyncValue<CloudAccountStatus>> cloudAccountStatusProvider =
    Provider<AsyncValue<CloudAccountStatus>>((ref) {
  final AsyncValue<CloudAuthSession?> sessionAsync = ref.watch(cloudAuthSessionProvider);
  final AsyncValue<CloudAccountLink?> linkAsync = ref.watch(cloudAccountLinkProvider);
  final bool providerAvailable = ref.watch(cloudAuthProviderProvider).isAvailable;

  if (sessionAsync.hasError) {
    return AsyncValue<CloudAccountStatus>.error(
      sessionAsync.error!,
      sessionAsync.stackTrace ?? StackTrace.current,
    );
  }
  if (linkAsync.hasError) {
    return AsyncValue<CloudAccountStatus>.error(
      linkAsync.error!,
      linkAsync.stackTrace ?? StackTrace.current,
    );
  }
  if (!sessionAsync.hasValue || !linkAsync.hasValue) {
    return const AsyncValue<CloudAccountStatus>.loading();
  }

  final CloudAccountLink? link = linkAsync.value;
  return AsyncValue<CloudAccountStatus>.data(
    CloudAccountStatus.resolve(
      providerAvailable: providerAvailable,
      liveSessionCloudUserId: sessionAsync.value?.cloudUserId,
      persistedLinkStatus: link == null ? null : CloudAccountLinkStatus.fromStorageValue(link.status),
      persistedLinkCloudUserId: link?.cloudUserId,
    ),
  );
});

/// Reconciliation: when the live session has disappeared without an
/// explicit sign-out while the persisted link still says `active`,
/// persists that as [CloudAccountLinkStatus.sessionExpired] -- CP12.2's
/// "reconciliation write path for detecting a session that disappeared
/// without an explicit sign-out." [cloudAccountStatusProvider] already
/// DERIVES `sessionExpired` in-memory the instant this happens (so the
/// UI is correct immediately, with no write needed for correctness);
/// this provider is what additionally makes that state durable across a
/// restart, exactly like `recurringNotificationReconcilerProvider`
/// reconciles reminder state as a side effect of watched providers
/// changing -- see that provider's doc for the same fire-and-forget,
/// plain (non-`.autoDispose`) `Provider<void>` shape.
final Provider<void> cloudAccountLinkReconcilerProvider = Provider<void>((ref) {
  final AsyncValue<CloudAuthSession?> sessionAsync = ref.watch(cloudAuthSessionProvider);
  final AsyncValue<CloudAccountLink?> linkAsync = ref.watch(cloudAccountLinkProvider);
  final ProfileRow? profile = ref.watch(activeProfileProvider).valueOrNull;

  final CloudAuthSession? session = sessionAsync.valueOrNull;
  final CloudAccountLink? link = linkAsync.valueOrNull;
  if (profile == null || link == null) return;
  // A live session still exists, or the stream hasn't resolved a value
  // yet (sessionAsync could be loading/error) -- nothing to reconcile.
  if (!sessionAsync.hasValue || session != null) return;
  if (CloudAccountLinkStatus.fromStorageValue(link.status) != CloudAccountLinkStatus.active) return;

  unawaited(ref.read(cloudAccountLinkRepositoryProvider).recordSessionExpired(profile.id));
});

/// Signs in, then records the resulting session on the current local
/// profile's link -- the one action call site
/// `lib/features/cloud_account/presentation/cloud_account_screen.dart`
/// needs. Lets `DifferentCloudAccountLinkedException` propagate
/// uncaught to the caller -- the screen catches it to show the blocking
/// "can't switch cloud accounts" message rather than this helper
/// swallowing it.
Future<void> signInAndLinkCurrentProfile(WidgetRef ref) async {
  final ProfileRow? profile = ref.read(activeProfileProvider).valueOrNull;
  if (profile == null) return;
  final CloudAuthProvider authProvider = ref.read(cloudAuthProviderProvider);
  final CloudAuthSession session = await authProvider.signIn();
  try {
    await ref.read(cloudAccountLinkRepositoryProvider).recordSignIn(
          profileId: profile.id,
          cloudUserId: session.cloudUserId,
        );
  } on DifferentCloudAccountLinkedException {
    // Undo the just-established provider session -- a refused link must
    // never leave `cloudAccountStatusProvider` reporting "signed in" as
    // an account this device's local data was never actually associated
    // with (a live session always takes precedence over the persisted
    // link in `CloudAccountStatus.resolve`, so leaving it set here would
    // make the UI show the wrong account as signed in even though the
    // repository correctly refused to persist that link).
    await authProvider.signOut();
    rethrow;
  }
}

/// Signs out of the cloud provider AND marks the current profile's link
/// `signedOut`. Never touches any financial table -- see
/// `CloudAccountLinkRepository.recordSignOut`'s own doc.
Future<void> signOutCurrentProfile(WidgetRef ref) async {
  final ProfileRow? profile = ref.read(activeProfileProvider).valueOrNull;
  await ref.read(cloudAuthProviderProvider).signOut();
  if (profile == null) return;
  await ref.read(cloudAccountLinkRepositoryProvider).recordSignOut(profile.id);
}
