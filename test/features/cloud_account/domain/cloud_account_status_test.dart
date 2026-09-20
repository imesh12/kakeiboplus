import 'package:ai_financial_coach/core/cloud_identity/cloud_account_link_status.dart';
import 'package:ai_financial_coach/features/cloud_account/domain/cloud_account_status.dart';
import 'package:flutter_test/flutter_test.dart';

// Checkpoint 12.2 (Cloud Identity / Auth Foundation): CloudAccountStatus.resolve is the one
// decision table the whole Cloud Account UI is driven by -- this test locks down all 4
// outcomes and the precedence between its inputs (provider availability > live session >
// persisted link), independent of any Riverpod provider or Drift table.
void main() {
  group('CloudAccountStatus.resolve', () {
    test('provider unavailable -> unavailable, regardless of any persisted link', () {
      final CloudAccountStatus status = CloudAccountStatus.resolve(
        providerAvailable: false,
        liveSessionCloudUserId: 'should-be-ignored',
        persistedLinkStatus: CloudAccountLinkStatus.active,
        persistedLinkCloudUserId: 'should-be-ignored',
      );
      expect(status.kind, CloudAccountStatusKind.unavailable);
      expect(status.cloudUserId, isNull);
      expect(status, const CloudAccountStatus.unavailable());
    });

    test('provider available, no session, no link -> localOnly', () {
      final CloudAccountStatus status = CloudAccountStatus.resolve(
        providerAvailable: true,
        liveSessionCloudUserId: null,
        persistedLinkStatus: null,
        persistedLinkCloudUserId: null,
      );
      expect(status.kind, CloudAccountStatusKind.localOnly);
      expect(status.cloudUserId, isNull);
    });

    test('provider available, live session -> signedIn with that session\'s cloud user id, '
        'even if a link exists for a different (stale) account', () {
      final CloudAccountStatus status = CloudAccountStatus.resolve(
        providerAvailable: true,
        liveSessionCloudUserId: 'live-user',
        persistedLinkStatus: CloudAccountLinkStatus.signedOut,
        persistedLinkCloudUserId: 'stale-user',
      );
      expect(status.kind, CloudAccountStatusKind.signedIn);
      expect(status.cloudUserId, 'live-user');
    });

    test('provider available, no live session, link is active -> sessionExpired -- the '
        'reconciliation case', () {
      final CloudAccountStatus status = CloudAccountStatus.resolve(
        providerAvailable: true,
        liveSessionCloudUserId: null,
        persistedLinkStatus: CloudAccountLinkStatus.active,
        persistedLinkCloudUserId: 'expired-user',
      );
      expect(status.kind, CloudAccountStatusKind.sessionExpired);
      expect(status.cloudUserId, 'expired-user');
    });

    test('provider available, no live session, link is signedOut -> localOnly, not '
        'sessionExpired', () {
      final CloudAccountStatus status = CloudAccountStatus.resolve(
        providerAvailable: true,
        liveSessionCloudUserId: null,
        persistedLinkStatus: CloudAccountLinkStatus.signedOut,
        persistedLinkCloudUserId: 'signed-out-user',
      );
      expect(status.kind, CloudAccountStatusKind.localOnly);
    });

    test('provider available, no live session, link already sessionExpired -> stays '
        'localOnly-shaped (not re-derived as sessionExpired again with a stale id)', () {
      final CloudAccountStatus status = CloudAccountStatus.resolve(
        providerAvailable: true,
        liveSessionCloudUserId: null,
        persistedLinkStatus: CloudAccountLinkStatus.sessionExpired,
        persistedLinkCloudUserId: 'already-expired-user',
      );
      expect(status.kind, CloudAccountStatusKind.localOnly);
    });
  });

  group('CloudAccountStatus equality', () {
    test('two signedIn statuses with the same cloudUserId are equal', () {
      expect(
        const CloudAccountStatus.signedIn('user-1'),
        const CloudAccountStatus.signedIn('user-1'),
      );
    });

    test('two signedIn statuses with different cloudUserIds are not equal', () {
      expect(
        const CloudAccountStatus.signedIn('user-1') == const CloudAccountStatus.signedIn('user-2'),
        isFalse,
      );
    });

    test('unavailable and localOnly are not equal', () {
      expect(
        const CloudAccountStatus.unavailable() == const CloudAccountStatus.localOnly(),
        isFalse,
      );
    });
  });
}
