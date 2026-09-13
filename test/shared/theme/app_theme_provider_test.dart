import 'dart:async';

import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/providers.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/features/onboarding/presentation/profile_providers.dart';
import 'package:ai_financial_coach/shared/theme/app_theme_provider.dart';
import 'package:ai_financial_coach/shared/theme/app_theme_style.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// NOTE: exercises generated Drift code -- see CLAUDE_FIRST_CODING_PROMPT.md.
//
// Checkpoint 8.1 (Premium Theme Personalization Foundation):
// appThemeStyleProvider's own tests -- same shape, same rationale, as
// test/core/locale/app_locale_provider_test.dart (plain test()s against
// a real in-memory AppDatabase, since there is no widget tree here, only
// a Riverpod provider reading a Drift stream).
void main() {
  late AppDatabase db;
  late ProfileRepository profileRepo;
  late ProviderContainer container;

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  void setUpRealDb() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    profileRepo = ProfileRepository(db);
    container = ProviderContainer(
      overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
    );
  }

  Future<String> seedProfile() {
    return profileRepo.createProfile(
      displayName: 'Test User',
      homeCountry: 'LK',
      currentCountry: 'JP',
      homeCurrency: 'LKR',
      livingCurrency: 'JPY',
      preferredLanguage: 'en',
      timezone: 'Asia/Tokyo',
      dateFormat: 'yyyy-MM-dd',
      numberFormat: '#,##0.##',
    );
  }

  test('A: no profile yet (pre-onboarding) resolves to AppThemeStyle.fallback (Light)', () async {
    setUpRealDb();

    await container.read(activeProfileProvider.future);

    expect(container.read(appThemeStyleProvider), AppThemeStyle.fallback);
    expect(container.read(appThemeStyleProvider), AppThemeStyle.light);
  });

  test('B: a freshly-created profile defaults to Light (the schema column default)', () async {
    setUpRealDb();
    await seedProfile();

    await container.read(activeProfileProvider.future);

    expect(container.read(appThemeStyleProvider), AppThemeStyle.light);
  });

  for (final AppThemeStyle style in AppThemeStyle.values) {
    test('C: a persisted theme_preference of "${style.storageValue}" resolves to '
        'AppThemeStyle.$style', () async {
      setUpRealDb();
      final String profileId = await seedProfile();
      await profileRepo.updateThemePreference(
        profileId: profileId,
        themePreference: style.storageValue,
      );

      await container.read(activeProfileProvider.future);

      expect(container.read(appThemeStyleProvider), style);
    });
  }

  test('D: an unknown persisted theme_preference runtime-falls-back to Light', () async {
    setUpRealDb();
    final String profileId = await seedProfile();
    await profileRepo.updateThemePreference(profileId: profileId, themePreference: 'midnight');

    await container.read(activeProfileProvider.future);

    expect(container.read(appThemeStyleProvider), AppThemeStyle.light);
  });

  test(
      'E: reading appThemeStyleProvider for an unknown persisted value never rewrites storage '
      '-- the raw value round-trips unchanged', () async {
    setUpRealDb();
    final String profileId = await seedProfile();
    await profileRepo.updateThemePreference(profileId: profileId, themePreference: 'midnight');

    await container.read(activeProfileProvider.future);
    container.read(appThemeStyleProvider);
    container.read(appThemeStyleProvider);
    container.read(appThemeStyleProvider);

    final ProfileRow? profile = await profileRepo.getProfile();
    expect(profile!.id, profileId);
    expect(profile.themePreference, 'midnight'); // preserved raw, unchanged
  });

  test('F: an errored profile stream resolves to Light', () async {
    final ProviderContainer errorContainer = ProviderContainer(
      overrides: <Override>[
        activeProfileProvider.overrideWith(
          (ref) => Stream<ProfileRow?>.error(StateError('simulated profile stream failure')),
        ),
      ],
    );
    addTearDown(errorContainer.dispose);

    try {
      await errorContainer.read(activeProfileProvider.future);
    } catch (_) {
      // Expected -- the point of this test is the resulting error state.
    }

    expect(errorContainer.read(activeProfileProvider), isA<AsyncError<ProfileRow?>>());
    expect(errorContainer.read(appThemeStyleProvider), AppThemeStyle.light);
  });

  test('G: a still-loading profile stream resolves to Light', () {
    setUpRealDb();

    expect(container.read(activeProfileProvider), const AsyncValue<ProfileRow?>.loading());
    expect(container.read(appThemeStyleProvider), AppThemeStyle.light);
  });

  test('H: changing the persisted theme causes appThemeStyleProvider to recompute without any '
      'restart or manual invalidation -- the same live-Drift-stream mechanism '
      'appLocaleProvider already relies on', () async {
    setUpRealDb();
    final String profileId = await seedProfile();
    await container.read(activeProfileProvider.future);
    expect(container.read(appThemeStyleProvider), AppThemeStyle.light);

    // Rather than assume any particular timing for Drift's watch stream
    // to re-emit, listen for the derived provider to actually observe
    // the new value -- this is what proves recomputation happens
    // automatically, with no restart and no manual `ref.invalidate`
    // anywhere in production code.
    final Completer<void> sawForest = Completer<void>();
    final ProviderSubscription<AppThemeStyle> subscription = container.listen<AppThemeStyle>(
      appThemeStyleProvider,
      (AppThemeStyle? previous, AppThemeStyle next) {
        if (next == AppThemeStyle.forest && !sawForest.isCompleted) {
          sawForest.complete();
        }
      },
    );
    addTearDown(subscription.close);

    await profileRepo.updateThemePreference(profileId: profileId, themePreference: 'forest');
    await sawForest.future.timeout(const Duration(seconds: 5));

    expect(container.read(appThemeStyleProvider), AppThemeStyle.forest);
  });
}
