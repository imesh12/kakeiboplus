import 'package:ai_financial_coach/core/cloud_identity/cloud_auth_exceptions.dart';
import 'package:ai_financial_coach/core/cloud_identity/cloud_auth_session.dart';
import 'package:ai_financial_coach/core/cloud_identity/unavailable_cloud_auth_provider.dart';
import 'package:flutter_test/flutter_test.dart';

// Checkpoint 12.2 (Cloud Identity / Auth Foundation): UnavailableCloudAuthProvider is the ONLY
// CloudAuthProvider production ever wires up. This test locks down the "truthfully reports
// unavailable, never fakes a successful sign-in" contract.
void main() {
  group('UnavailableCloudAuthProvider', () {
    test('isAvailable is always false', () {
      const UnavailableCloudAuthProvider provider = UnavailableCloudAuthProvider();
      expect(provider.isAvailable, isFalse);
    });

    test('watchSession always emits null -- never a fake session', () async {
      const UnavailableCloudAuthProvider provider = UnavailableCloudAuthProvider();
      final CloudAuthSession? session = await provider.watchSession().first;
      expect(session, isNull);
    });

    test('signIn throws CloudAuthNotConfiguredException rather than faking success', () async {
      const UnavailableCloudAuthProvider provider = UnavailableCloudAuthProvider();
      await expectLater(
        provider.signIn,
        throwsA(isA<CloudAuthNotConfiguredException>()),
      );
    });

    test('signOut is a safe no-op', () async {
      const UnavailableCloudAuthProvider provider = UnavailableCloudAuthProvider();
      await provider.signOut(); // must not throw
    });
  });
}
