import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/providers.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/locale/app_locale_provider.dart';
import 'package:ai_financial_coach/features/onboarding/presentation/profile_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// NOTE: exercises generated Drift code -- see CLAUDE_FIRST_CODING_PROMPT.md.
//
// International / Localization Foundation Checkpoint 4.2:
// appLocaleProvider's own tests. Plain test()s, not testWidgets()s --
// same rationale as test/core/dashboard/dashboard_providers_test.dart:
// there is no widget tree here, only a Riverpod provider reading a Drift
// stream, so plain test() runs on the real event loop rather than
// Flutter's FakeAsync-driven testWidgets() clock, avoiding the "Timer is
// still pending" class of failure that rationale already documents.
//
// Cases A-E use a real in-memory AppDatabase + ProfileRepository, the
// same appDatabaseProvider.overrideWithValue(db) pattern
// dashboard_providers_test.dart already establishes for this repo's
// provider-level tests.
//
// Case G (loading) reuses that SAME real-DB pattern rather than any new
// plumbing: a StreamProvider's state is synchronously AsyncLoading on
// its very first read, before its Stream has had any chance to emit --
// that's Riverpod's own initial-state guarantee, not a race against real
// Drift timing, so a plain synchronous read right after building the
// container deterministically observes it.
//
// Case F (provider error) is the one case that doesn't reuse the real-DB
// pattern: forcing a genuine Drift-backed stream into AsyncError
// deterministically would mean closing/breaking the database out from
// under an in-flight query, which is timing-dependent and not something
// this repo already has an established pattern for at the read/stream
// layer (CP3B's existing "Save failure" test closes the db before a
// *write*, a different, already-synchronous failure mode). Overriding
// activeProfileProvider directly with Stream<ProfileRow?>.error(...) is
// the standard, documented Riverpod technique for forcing a provider's
// error state in a test -- it substitutes only that one upstream
// provider's stream implementation, it is not a repository mock (this
// repo deliberately has no mocking library -- see
// dashboard_providers_test.dart's own doc comment), and it still
// exercises appLocaleProvider's real, unmodified logic against a real
// AsyncError.

void main() {
  late AppDatabase db;
  late ProfileRepository profileRepo;
  late ProviderContainer container;

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  /// Wires [container] against a fresh in-memory [db] via the same
  /// appDatabaseProvider.overrideWithValue(db) pattern used throughout
  /// this repo's provider tests. Does NOT create a profile -- callers
  /// seed one afterward (or not, for the "no profile yet" case).
  void setUpRealDb() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    profileRepo = ProfileRepository(db);
    container = ProviderContainer(
      overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
    );
  }

  Future<String> seedProfile({required String preferredLanguage}) {
    return profileRepo.createProfile(
      displayName: 'Test User',
      homeCountry: 'LK',
      currentCountry: 'JP',
      homeCurrency: 'LKR',
      livingCurrency: 'JPY',
      preferredLanguage: preferredLanguage,
      timezone: 'Asia/Tokyo',
      dateFormat: 'yyyy-MM-dd',
      numberFormat: '#,##0.##',
    );
  }

  test('A: no profile yet (pre-onboarding) resolves to Locale(en)', () async {
    setUpRealDb();

    await container.read(activeProfileProvider.future);

    expect(container.read(appLocaleProvider), const Locale('en'));
  });

  test('B: preferredLanguage "en" resolves to Locale(en)', () async {
    setUpRealDb();
    await seedProfile(preferredLanguage: 'en');

    await container.read(activeProfileProvider.future);

    expect(container.read(appLocaleProvider), const Locale('en'));
  });

  test('C: preferredLanguage "ja" resolves to Locale(ja)', () async {
    setUpRealDb();
    await seedProfile(preferredLanguage: 'ja');

    await container.read(activeProfileProvider.future);

    expect(container.read(appLocaleProvider), const Locale('ja'));
  });

  test('D: unknown persisted language runtime-falls-back to Locale(en)', () async {
    setUpRealDb();
    await seedProfile(preferredLanguage: 'xx');

    await container.read(activeProfileProvider.future);

    expect(container.read(appLocaleProvider), const Locale('en'));
  });

  test(
      'E: reading appLocaleProvider for an unknown persisted language never '
      'rewrites storage -- the raw value round-trips unchanged', () async {
    setUpRealDb();
    final String profileId = await seedProfile(preferredLanguage: 'xx');

    await container.read(activeProfileProvider.future);
    // Read repeatedly, as a real running app would on every rebuild --
    // never a write, however many times it's read.
    container.read(appLocaleProvider);
    container.read(appLocaleProvider);
    container.read(appLocaleProvider);

    final ProfileRow? profile = await profileRepo.getProfile();
    expect(profile!.id, profileId);
    expect(profile.preferredLanguage, 'xx'); // preserved raw, unchanged
  });

  test('F: an errored profile stream resolves to Locale(en)', () async {
    final ProviderContainer errorContainer = ProviderContainer(
      overrides: <Override>[
        activeProfileProvider.overrideWith(
          (ref) => Stream<ProfileRow?>.error(StateError('simulated profile stream failure')),
        ),
      ],
    );
    addTearDown(errorContainer.dispose);

    // .future rejects for an errored stream -- awaited via try/catch
    // (rather than left unhandled) purely to let the error actually
    // propagate into AsyncValue.error before reading the derived locale.
    try {
      await errorContainer.read(activeProfileProvider.future);
    } catch (_) {
      // Expected -- the point of this test is the resulting error state.
    }

    expect(errorContainer.read(activeProfileProvider), isA<AsyncError<ProfileRow?>>());
    expect(errorContainer.read(appLocaleProvider), const Locale('en'));
  });

  test('G: a still-loading profile stream resolves to Locale(en)', () {
    setUpRealDb();

    // No `await` at all: a StreamProvider's state is synchronously
    // AsyncLoading on first read, before its Stream has had any chance
    // to emit -- see the file-level doc comment for why this is
    // deterministic rather than a timing race.
    expect(container.read(activeProfileProvider), const AsyncValue<ProfileRow?>.loading());
    expect(container.read(appLocaleProvider), const Locale('en'));
  });
}
