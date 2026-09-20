import 'dart:io';

import 'package:ai_financial_coach/core/cloud_identity/cloud_account_link_status.dart';
import 'package:ai_financial_coach/core/database/app_database.dart';
import 'package:ai_financial_coach/core/database/repositories/account_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/cloud_account_link_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/different_cloud_account_linked_exception.dart';
import 'package:ai_financial_coach/core/database/repositories/profile_repository.dart';
import 'package:ai_financial_coach/core/database/repositories/transaction_repository.dart';
import 'package:ai_financial_coach/core/money/money.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// NOTE: exercises generated Drift code -- see CLAUDE_FIRST_CODING_PROMPT.md.
//
// Checkpoint 12.2 (Cloud Identity / Auth Foundation): covers
// CloudAccountLinkRepository's sign-in/sign-out/session-expired write
// paths, and -- critically -- the different-account-safety refusal
// (DifferentCloudAccountLinkedException) that makes "never silently
// associate existing local financial data with a different cloud
// identity" true by construction.
void main() {
  group('In-memory repository behavior', () {
    late AppDatabase db;
    late ProfileRepository profileRepo;
    late AccountRepository accountRepo;
    late TransactionRepository txRepo;
    late CloudAccountLinkRepository linkRepo;
    late String profileId;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      profileRepo = ProfileRepository(db);
      accountRepo = AccountRepository(db);
      txRepo = TransactionRepository(db, accountRepo);
      linkRepo = CloudAccountLinkRepository(db);

      profileId = await profileRepo.createProfile(
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
    });

    tearDown(() async {
      await db.close();
    });

    test('getLink returns null before any sign-in -- local-only-no-auth-config works', () async {
      expect(await linkRepo.getLink(profileId), isNull);
    });

    test('recordSignIn creates a new link with status active', () async {
      await linkRepo.recordSignIn(profileId: profileId, cloudUserId: 'cloud-user-1');
      final CloudAccountLink? link = await linkRepo.getLink(profileId);
      expect(link, isNotNull);
      expect(link!.cloudUserId, 'cloud-user-1');
      expect(CloudAccountLinkStatus.fromStorageValue(link.status), CloudAccountLinkStatus.active);
    });

    test('local profile stays separate from cloud identity -- createProfile never writes a '
        'cloud_account_links row, and recordSignIn never writes to profiles', () async {
      expect(await linkRepo.getLink(profileId), isNull);

      await linkRepo.recordSignIn(profileId: profileId, cloudUserId: 'cloud-user-1');

      final ProfileRow? profile = await profileRepo.getProfile();
      expect(profile!.id, profileId);
      expect(profile.displayName, 'Test User');
    });

    test('signing back into the SAME cloud account after signing out is safe and preserves '
        'the original linkedAt', () async {
      await linkRepo.recordSignIn(profileId: profileId, cloudUserId: 'cloud-user-1');
      final CloudAccountLink firstLink = (await linkRepo.getLink(profileId))!;

      await linkRepo.recordSignOut(profileId);
      final CloudAccountLink signedOutLink = (await linkRepo.getLink(profileId))!;
      expect(
        CloudAccountLinkStatus.fromStorageValue(signedOutLink.status),
        CloudAccountLinkStatus.signedOut,
      );

      await linkRepo.recordSignIn(profileId: profileId, cloudUserId: 'cloud-user-1');
      final CloudAccountLink resignedLink = (await linkRepo.getLink(profileId))!;
      expect(
        CloudAccountLinkStatus.fromStorageValue(resignedLink.status),
        CloudAccountLinkStatus.active,
      );
      expect(resignedLink.linkedAt.toUtc(), firstLink.linkedAt.toUtc());
      expect(resignedLink.cloudUserId, 'cloud-user-1');
    });

    test('signing into a DIFFERENT cloud account throws DifferentCloudAccountLinkedException '
        'and never reassigns the existing link -- local financial data is never silently '
        'reassigned between cloud users', () async {
      await linkRepo.recordSignIn(profileId: profileId, cloudUserId: 'cloud-user-1');

      await expectLater(
        () => linkRepo.recordSignIn(profileId: profileId, cloudUserId: 'cloud-user-2'),
        throwsA(isA<DifferentCloudAccountLinkedException>()),
      );

      final CloudAccountLink? link = await linkRepo.getLink(profileId);
      expect(link!.cloudUserId, 'cloud-user-1');
      expect(CloudAccountLinkStatus.fromStorageValue(link.status), CloudAccountLinkStatus.active);
    });

    test('attempting a different-account sign-in even after an explicit sign-out is still '
        'refused -- cloudUserId is remembered across sign-out specifically to catch this',
        () async {
      await linkRepo.recordSignIn(profileId: profileId, cloudUserId: 'cloud-user-1');
      await linkRepo.recordSignOut(profileId);

      await expectLater(
        () => linkRepo.recordSignIn(profileId: profileId, cloudUserId: 'cloud-user-2'),
        throwsA(isA<DifferentCloudAccountLinkedException>()),
      );

      final CloudAccountLink? link = await linkRepo.getLink(profileId);
      expect(link!.cloudUserId, 'cloud-user-1');
      expect(
        CloudAccountLinkStatus.fromStorageValue(link.status),
        CloudAccountLinkStatus.signedOut,
      );
    });

    test('recordSignOut on a profile that was never linked is a safe no-op', () async {
      await linkRepo.recordSignOut(profileId);
      expect(await linkRepo.getLink(profileId), isNull);
    });

    test('recordSessionExpired transitions an active link to sessionExpired', () async {
      await linkRepo.recordSignIn(profileId: profileId, cloudUserId: 'cloud-user-1');
      await linkRepo.recordSessionExpired(profileId);

      final CloudAccountLink? link = await linkRepo.getLink(profileId);
      expect(
        CloudAccountLinkStatus.fromStorageValue(link!.status),
        CloudAccountLinkStatus.sessionExpired,
      );
      expect(link.cloudUserId, 'cloud-user-1');
    });

    test('recordSessionExpired never overwrites an already-signedOut link with '
        'sessionExpired', () async {
      await linkRepo.recordSignIn(profileId: profileId, cloudUserId: 'cloud-user-1');
      await linkRepo.recordSignOut(profileId);

      await linkRepo.recordSessionExpired(profileId);

      final CloudAccountLink? link = await linkRepo.getLink(profileId);
      expect(
        CloudAccountLinkStatus.fromStorageValue(link!.status),
        CloudAccountLinkStatus.signedOut,
      );
    });

    test('recordSessionExpired on a never-linked profile is a safe no-op', () async {
      await linkRepo.recordSessionExpired(profileId);
      expect(await linkRepo.getLink(profileId), isNull);
    });

    test('sign-out never deletes or modifies any financial data -- an existing account and '
        'transaction survive a full sign-in/sign-out cycle completely unchanged', () async {
      final String accountId = await accountRepo.createAccount(
        profileId: profileId,
        name: 'Wallet',
        type: 'cash',
        currencyCode: 'JPY',
      );
      final String txId = await txRepo.recordExpense(
        profileId: profileId,
        accountId: accountId,
        amount: Money.fromMinorUnits(50000, 'JPY'),
        occurredAtUtc: DateTime.now().toUtc(),
      );

      await linkRepo.recordSignIn(profileId: profileId, cloudUserId: 'cloud-user-1');
      await linkRepo.recordSignOut(profileId);

      final AccountRow account = await accountRepo.requireById(accountId);
      expect(account.name, 'Wallet');

      final Transaction tx = (await txRepo.watchById(txId).first)!;
      expect(tx.amountMinorUnits, 50000);
    });

    test('watchLink emits null, then the link, then updated states as sign-in/sign-out '
        'happen', () async {
      final List<CloudAccountLinkStatus?> statuses = <CloudAccountLinkStatus?>[];
      final Stream<CloudAccountLink?> stream = linkRepo.watchLink(profileId);
      final subscription = stream.listen((CloudAccountLink? link) {
        statuses.add(link == null ? null : CloudAccountLinkStatus.fromStorageValue(link.status));
      });

      await Future<void>.delayed(Duration.zero);
      await linkRepo.recordSignIn(profileId: profileId, cloudUserId: 'cloud-user-1');
      await Future<void>.delayed(Duration.zero);
      await linkRepo.recordSignOut(profileId);
      await Future<void>.delayed(Duration.zero);

      await subscription.cancel();

      expect(statuses.first, isNull);
      expect(statuses, contains(CloudAccountLinkStatus.active));
      expect(statuses.last, CloudAccountLinkStatus.signedOut);
    });

    test('no access/refresh token column exists on the cloud_account_links table -- tokens '
        'are never stored in Drift (CP12.2)', () async {
      final List<String> columnNames = db.cloudAccountLinks.$columns.map((c) => c.name).toList();
      for (final String name in columnNames) {
        final String lower = name.toLowerCase();
        expect(lower.contains('token'), isFalse, reason: 'unexpected column: $name');
        expect(lower.contains('password'), isFalse, reason: 'unexpected column: $name');
        expect(lower.contains('secret'), isFalse, reason: 'unexpected column: $name');
      }
      expect(columnNames, containsAll(<String>['profile_id', 'cloud_user_id', 'status']));
    });
  });

  group('Persistence survives a database reload', () {
    test('a cloud account link set via recordSignIn is still readable through a newly-opened '
        'AppDatabase/CloudAccountLinkRepository against the same on-disk file -- restart/'
        'persistence for non-secret identity metadata', () async {
      final Directory tempDir =
          Directory.systemTemp.createTempSync('afc_cloud_account_link_persistence_test_');
      final File dbFile = File('${tempDir.path}/test.sqlite');
      addTearDown(() {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });

      AppDatabase fileDb = AppDatabase.forTesting(NativeDatabase(dbFile));
      final ProfileRepository fileProfileRepo = ProfileRepository(fileDb);
      CloudAccountLinkRepository fileLinkRepo = CloudAccountLinkRepository(fileDb);

      final String fileProfileId = await fileProfileRepo.createProfile(
        displayName: 'Restart Test User',
        homeCountry: 'LK',
        currentCountry: 'JP',
        homeCurrency: 'LKR',
        livingCurrency: 'JPY',
        preferredLanguage: 'en',
        timezone: 'Asia/Tokyo',
        dateFormat: 'yyyy-MM-dd',
        numberFormat: '#,##0.##',
      );
      await fileLinkRepo.recordSignIn(profileId: fileProfileId, cloudUserId: 'cloud-user-restart');

      // --- "App restart" ---
      await fileDb.close();
      fileDb = AppDatabase.forTesting(NativeDatabase(dbFile));
      fileLinkRepo = CloudAccountLinkRepository(fileDb);

      final CloudAccountLink? link = await fileLinkRepo.getLink(fileProfileId);
      expect(link, isNotNull);
      expect(link!.cloudUserId, 'cloud-user-restart');
      expect(CloudAccountLinkStatus.fromStorageValue(link.status), CloudAccountLinkStatus.active);

      await fileDb.close();
    });
  });
}
