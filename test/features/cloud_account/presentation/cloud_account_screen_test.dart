import 'package:ai_financial_coach/core/cloud_identity/in_memory_cloud_auth_provider.dart';
import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/providers.dart';
import 'package:ai_financial_coach/core/database/repositories/cloud_account_link_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/features/cloud_account/presentation/cloud_account_providers.dart';
import 'package:ai_financial_coach/features/cloud_account/presentation/cloud_account_screen.dart';
import 'package:ai_financial_coach/l10n/generated/app_localizations.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Checkpoint 12.2 (Cloud Identity / Auth Foundation) -- CloudAccountScreen widget tests.
///
/// Same hand-written-fake / real-in-memory-database conventions as every other widget test
/// in this project: `InMemoryCloudAuthProvider` (a REAL, already-tested class -- not a mock
/// -- see `test/core/cloud_identity/in_memory_cloud_auth_provider_test.dart`) overrides
/// `cloudAuthProviderProvider`, and a real in-memory `AppDatabase` backs
/// `cloudAccountLinkRepositoryProvider`/`activeProfileProvider` via `appDatabaseProvider`.
void main() {
  Future<(AppDatabase, String profileId)> seededDb() async {
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
    return (db, profileId);
  }

  Future<void> disposeInOrder(WidgetTester tester, ProviderContainer container, AppDatabase db) async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pumpAndSettle();
    await db.close();
  }

  Widget appWithCloudAccountScreen(
    ProviderContainer container, {
    Locale locale = const Locale('en'),
  }) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const CloudAccountScreen(),
      ),
    );
  }

  group('production default (no CloudAuthProvider override)', () {
    testWidgets(
      'shows the Unavailable chip, no sign-in/sign-out button, and never claims Synced/'
      'Backed up/Up to date -- local-only-no-auth-config works',
      (tester) async {
        final (AppDatabase db, String _) = await seededDb();
        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
        );
        addTearDown(() => disposeInOrder(tester, container, db));

        await tester.pumpWidget(appWithCloudAccountScreen(container));
        await tester.pumpAndSettle();

        expect(find.text('Unavailable'), findsOneWidget);
        expect(find.text('Sign in'), findsNothing);
        expect(find.text('Sign out'), findsNothing);
        expect(find.textContaining('Synced'), findsNothing);
        expect(find.textContaining('Backed up'), findsNothing);
        expect(find.textContaining('Up to date'), findsNothing);
      },
    );
  });

  group('localOnly / signedIn / sessionExpired (dev CloudAuthProvider override)', () {
    testWidgets('localOnly shows a Sign in button; tapping it transitions to signedIn with a '
        'Sign out button and the never-deletes-local-data note', (tester) async {
      final (AppDatabase db, String _) = await seededDb();
      final InMemoryCloudAuthProvider fakeAuth = InMemoryCloudAuthProvider();
      addTearDown(fakeAuth.dispose);
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          cloudAuthProviderProvider.overrideWithValue(fakeAuth),
        ],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithCloudAccountScreen(container));
      await tester.pumpAndSettle();

      expect(find.text('Local only'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);

      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('Signed in'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
      expect(find.text('Signing out never deletes anything saved on this device.'), findsOneWidget);
    });

    testWidgets('signedIn -> tapping Sign out returns to localOnly', (tester) async {
      final (AppDatabase db, String _) = await seededDb();
      final InMemoryCloudAuthProvider fakeAuth = InMemoryCloudAuthProvider();
      addTearDown(fakeAuth.dispose);
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          cloudAuthProviderProvider.overrideWithValue(fakeAuth),
        ],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithCloudAccountScreen(container));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Signed in'), findsOneWidget);

      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      expect(find.text('Local only'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
    });

    testWidgets('a session that disappears without an explicit sign-out shows Session '
        'expired, with a Sign in button to re-authenticate', (tester) async {
      final (AppDatabase db, String _) = await seededDb();
      final InMemoryCloudAuthProvider fakeAuth = InMemoryCloudAuthProvider();
      addTearDown(fakeAuth.dispose);
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          cloudAuthProviderProvider.overrideWithValue(fakeAuth),
        ],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithCloudAccountScreen(container));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Signed in'), findsOneWidget);

      fakeAuth.simulateSessionDroppedWithoutSignOut();
      await tester.pumpAndSettle();

      expect(find.text('Session expired'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
    });

    testWidgets('signing in when a DIFFERENT cloud account is already linked on this device '
        'shows a blocking dialog and never reassigns the existing link', (tester) async {
      final (AppDatabase db, String profileId) = await seededDb();
      // Pre-seed a link to a different account than the fake provider's default sign-in id.
      await CloudAccountLinkRepository(db).recordSignIn(
        profileId: profileId,
        cloudUserId: 'already-linked-account',
      );
      final InMemoryCloudAuthProvider fakeAuth = InMemoryCloudAuthProvider();
      addTearDown(fakeAuth.dispose);
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          cloudAuthProviderProvider.overrideWithValue(fakeAuth),
        ],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithCloudAccountScreen(container));
      await tester.pumpAndSettle();

      // No live session yet, but the link is still `active` -- this is the
      // sessionExpired/reconciliation state, with its own "Sign in" button.
      expect(find.text('Session expired'), findsOneWidget);

      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(find.text("Can't switch cloud accounts"), findsOneWidget);

      // Dismiss the dialog.
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // The UI reverts to Session expired for the ORIGINAL account -- not a misleading
      // "Signed in" for the refused account -- because signInAndLinkCurrentProfile signs the
      // provider back out when the repository refuses the link.
      expect(find.text('Session expired'), findsOneWidget);
      expect(find.text('Signed in'), findsNothing);

      final CloudAccountLink? link = await CloudAccountLinkRepository(db).getLink(profileId);
      expect(link!.cloudUserId, 'already-linked-account');
    });
  });

  group('localization', () {
    testWidgets('renders the Japanese translation of the unavailable state', (tester) async {
      final (AppDatabase db, String _) = await seededDb();
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithCloudAccountScreen(container, locale: const Locale('ja')));
      await tester.pumpAndSettle();

      expect(find.text('利用不可'), findsOneWidget);
      expect(
        find.text(
          'このバージョンではクラウドアカウントはまだ利用できません。入力したデータはすべてこの端末内に保存されます。',
        ),
        findsOneWidget,
      );
    });
  });

  group('narrow width / text scale compatibility', () {
    testWidgets('the signed-in state renders at 320px width and a 1.6x text scale without a '
        'layout exception', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final (AppDatabase db, String _) = await seededDb();
      final InMemoryCloudAuthProvider fakeAuth = InMemoryCloudAuthProvider();
      addTearDown(fakeAuth.dispose);
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          cloudAuthProviderProvider.overrideWithValue(fakeAuth),
        ],
      );
      addTearDown(() => disposeInOrder(tester, container, db));

      await tester.pumpWidget(appWithCloudAccountScreen(container));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Signed in'), findsOneWidget);
    });
  });
}
