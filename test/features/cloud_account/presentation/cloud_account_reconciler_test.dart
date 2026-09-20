import 'package:ai_financial_coach/core/cloud_identity/cloud_account_link_status.dart';
import 'package:ai_financial_coach/core/cloud_identity/in_memory_cloud_auth_provider.dart';
import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/providers.dart';
import 'package:ai_financial_coach/core/database/repositories/cloud_account_link_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/features/cloud_account/presentation/cloud_account_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Checkpoint 12.2 (Cloud Identity / Auth Foundation): cloudAccountLinkReconcilerProvider is
/// what makes a dropped session durable across a restart, not just correct in-memory (see
/// `cloudAccountStatusProvider`, which already derives `sessionExpired` immediately without
/// this write). This test exercises the reconciler in isolation via a plain
/// `ProviderContainer` -- no widget tree needed.
void main() {
  test('a session that disappears without an explicit sign-out is persisted as '
      'sessionExpired once the reconciler provider is listened to', () async {
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    final ProfileRepository profileRepo = ProfileRepository(db);
    final String profileId = await profileRepo.createProfile(
      displayName: 'Test User',
      homeCountry: 'US',
      currentCountry: 'JP',
      homeCurrency: 'USD',
      livingCurrency: 'JPY',
      preferredLanguage: 'en',
      timezone: 'Asia/Tokyo',
      dateFormat: 'yyyy-MM-dd',
      numberFormat: '#,##0.##',
    );
    final CloudAccountLinkRepository linkRepo = CloudAccountLinkRepository(db);
    await linkRepo.recordSignIn(profileId: profileId, cloudUserId: 'cloud-user-1');

    final InMemoryCloudAuthProvider fakeAuth = InMemoryCloudAuthProvider();
    addTearDown(fakeAuth.dispose);
    // The fake starts signed OUT (isolated instance) -- simulate that this profile's
    // provider-level session had been live, then dropped, without ever calling signOut.
    await fakeAuth.signInAs('cloud-user-1');

    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(db),
        cloudAuthProviderProvider.overrideWithValue(fakeAuth),
      ],
    );
    addTearDown(container.dispose);

    // Keep the reconciler (and its dependencies) alive, exactly like `app.dart`'s
    // `ref.watch(cloudAccountLinkReconcilerProvider)` does.
    container.listen(cloudAccountLinkReconcilerProvider, (_, __) {});
    // Let the profile/link streams and the reconciler's own logic settle.
    await Future<void>.delayed(const Duration(milliseconds: 10));

    // Still signed in -- the reconciler must NOT touch an active, live-backed link.
    CloudAccountLink? link = await linkRepo.getLink(profileId);
    expect(CloudAccountLinkStatus.fromStorageValue(link!.status), CloudAccountLinkStatus.active);

    fakeAuth.simulateSessionDroppedWithoutSignOut();
    await Future<void>.delayed(const Duration(milliseconds: 10));

    link = await linkRepo.getLink(profileId);
    expect(
      CloudAccountLinkStatus.fromStorageValue(link!.status),
      CloudAccountLinkStatus.sessionExpired,
    );
    expect(link.cloudUserId, 'cloud-user-1');

    await db.close();
  });

  test('the reconciler never touches a link for a profile that already signed out', () async {
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    final ProfileRepository profileRepo = ProfileRepository(db);
    final String profileId = await profileRepo.createProfile(
      displayName: 'Test User',
      homeCountry: 'US',
      currentCountry: 'JP',
      homeCurrency: 'USD',
      livingCurrency: 'JPY',
      preferredLanguage: 'en',
      timezone: 'Asia/Tokyo',
      dateFormat: 'yyyy-MM-dd',
      numberFormat: '#,##0.##',
    );
    final CloudAccountLinkRepository linkRepo = CloudAccountLinkRepository(db);
    await linkRepo.recordSignIn(profileId: profileId, cloudUserId: 'cloud-user-1');
    await linkRepo.recordSignOut(profileId);

    final InMemoryCloudAuthProvider fakeAuth = InMemoryCloudAuthProvider();
    addTearDown(fakeAuth.dispose);
    // No live session -- matches the already-signed-out link.

    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(db),
        cloudAuthProviderProvider.overrideWithValue(fakeAuth),
      ],
    );
    addTearDown(container.dispose);

    container.listen(cloudAccountLinkReconcilerProvider, (_, __) {});
    await Future<void>.delayed(const Duration(milliseconds: 10));

    final CloudAccountLink? link = await linkRepo.getLink(profileId);
    expect(
      CloudAccountLinkStatus.fromStorageValue(link!.status),
      CloudAccountLinkStatus.signedOut,
    );

    await db.close();
  });
}
