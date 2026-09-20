import 'package:ai_financial_coach/core/cloud_identity/cloud_auth_session.dart';
import 'package:ai_financial_coach/core/cloud_identity/in_memory_cloud_auth_provider.dart';
import 'package:flutter_test/flutter_test.dart';

// Checkpoint 12.2 (Cloud Identity / Auth Foundation): InMemoryCloudAuthProvider is a
// development/test-only fake -- never wired into production. This test covers its own
// contract in isolation (session lifecycle, replay-to-new-listener, the dev-only
// simulateSessionDroppedWithoutSignOut hook) so higher-level tests (the reconciler, the
// screen) can rely on it being correct.
void main() {
  group('InMemoryCloudAuthProvider', () {
    late InMemoryCloudAuthProvider provider;

    setUp(() {
      provider = InMemoryCloudAuthProvider();
    });

    tearDown(() async {
      await provider.dispose();
    });

    test('isAvailable is always true', () {
      expect(provider.isAvailable, isTrue);
    });

    test('watchSession replays the current (null) snapshot to a fresh listener', () async {
      final CloudAuthSession? session = await provider.watchSession().first;
      expect(session, isNull);
    });

    test('signIn produces a session with the default dev cloud user id, and watchSession '
        'reflects it', () async {
      final CloudAuthSession session = await provider.signIn();
      expect(session.cloudUserId, isNotEmpty);

      final CloudAuthSession? replayed = await provider.watchSession().first;
      expect(replayed, session);
    });

    test('signInAs signs in as a specific cloud user id -- used to simulate different-'
        'account scenarios', () async {
      final CloudAuthSession session = await provider.signInAs('specific-user-42');
      expect(session.cloudUserId, 'specific-user-42');
      expect((await provider.watchSession().first)!.cloudUserId, 'specific-user-42');
    });

    test('signOut clears the session', () async {
      await provider.signInAs('user-a');
      await provider.signOut();
      expect(await provider.watchSession().first, isNull);
    });

    test('watchSession emits sign-in and sign-out transitions to an already-subscribed '
        'listener', () async {
      final List<String?> cloudUserIds = <String?>[];
      final subscription = provider.watchSession().listen((CloudAuthSession? s) {
        cloudUserIds.add(s?.cloudUserId);
      });

      await Future<void>.delayed(Duration.zero);
      await provider.signInAs('user-b');
      await Future<void>.delayed(Duration.zero);
      await provider.signOut();
      await Future<void>.delayed(Duration.zero);

      await subscription.cancel();

      expect(cloudUserIds.first, isNull);
      expect(cloudUserIds, contains('user-b'));
      expect(cloudUserIds.last, isNull);
    });

    test('simulateSessionDroppedWithoutSignOut clears the session exactly like signOut, for '
        'exercising session-expiry reconciliation without a real backend', () async {
      await provider.signInAs('user-c');
      provider.simulateSessionDroppedWithoutSignOut();
      expect(await provider.watchSession().first, isNull);
    });
  });
}
