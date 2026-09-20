import 'package:drift/drift.dart';

import '../../cloud_identity/cloud_account_link_status.dart';
import '../app_database.dart';
import 'different_cloud_account_linked_exception.dart';

/// Reads and writes the single `cloud_account_links` row for a local
/// profile -- Checkpoint 12.2's local-only cloud-identity-link
/// bookkeeping. See `tables.dart`'s `CloudAccountLinks` doc for the full
/// schema rationale.
///
/// Never talks to a `CloudAuthProvider` and never receives a token --
/// this repository's only inputs are a `profileId` and a `cloudUserId`
/// string (already resolved by the caller, ultimately from a
/// `CloudAuthSession`). It has no network dependency and no knowledge of
/// how a session was obtained, exactly like every other repository in
/// this schema knows nothing about the UI/domain layer that calls it.
class CloudAccountLinkRepository {
  CloudAccountLinkRepository(this._db);

  final AppDatabase _db;

  /// Emits the current link for [profileId], or `null` if this profile
  /// has never been linked to any cloud account. Replays the current
  /// row to every new listener, then emits again on every write -- same
  /// live-Drift-stream contract every other `watchX` method in this
  /// schema already has (see `ProfileRepository.watchProfile`).
  Stream<CloudAccountLink?> watchLink(String profileId) {
    return (_db.select(_db.cloudAccountLinks)..where((tbl) => tbl.profileId.equals(profileId)))
        .watchSingleOrNull();
  }

  Future<CloudAccountLink?> getLink(String profileId) {
    return (_db.select(_db.cloudAccountLinks)..where((tbl) => tbl.profileId.equals(profileId)))
        .getSingleOrNull();
  }

  /// Records a successful sign-in for [profileId] as [cloudUserId].
  ///
  /// Three cases:
  /// - No existing link: creates one, [status] `active`, `linkedAt` =
  ///   now.
  /// - Existing link to the SAME [cloudUserId] (whether it was `active`,
  ///   `signedOut`, or `sessionExpired`): reactivates it to `active`,
  ///   `linkedAt` is preserved unchanged (it marks when this profile was
  ///   FIRST linked to this cloud account, not the most recent sign-in).
  ///   Signing back into the same account is always safe -- CP12.2:
  ///   "signing back into the same account" must work.
  /// - Existing link to a DIFFERENT [cloudUserId]: throws
  ///   [DifferentCloudAccountLinkedException] and writes nothing. This
  ///   is the mechanism that makes "never silently associate existing
  ///   local financial data with a different cloud identity" true by
  ///   construction -- see that exception's own doc.
  Future<void> recordSignIn({required String profileId, required String cloudUserId}) async {
    final CloudAccountLink? existing = await getLink(profileId);
    if (existing != null && existing.cloudUserId != cloudUserId) {
      throw DifferentCloudAccountLinkedException(
        profileId: profileId,
        existingCloudUserId: existing.cloudUserId,
        attemptedCloudUserId: cloudUserId,
      );
    }
    final DateTime now = DateTime.now().toUtc();
    await _db.into(_db.cloudAccountLinks).insertOnConflictUpdate(
          CloudAccountLinksCompanion.insert(
            profileId: profileId,
            cloudUserId: cloudUserId,
            status: CloudAccountLinkStatus.active.storageValue,
            linkedAt: existing?.linkedAt ?? now,
            updatedAt: now,
          ),
        );
  }

  /// Marks [profileId]'s link as explicitly signed out. A no-op if this
  /// profile has never been linked to any cloud account. Never touches
  /// any other table -- signing out never deletes local financial data
  /// (CP12.2's explicit instruction), and this method's own effect is
  /// limited to one row in `cloud_account_links`.
  ///
  /// `cloudUserId` and `linkedAt` are left unchanged -- see
  /// `CloudAccountLinks.cloudUserId`'s doc for why remembering which
  /// account this device was linked to must survive a sign-out.
  Future<void> recordSignOut(String profileId) async {
    final CloudAccountLink? existing = await getLink(profileId);
    if (existing == null) return;
    await (_db.update(_db.cloudAccountLinks)..where((tbl) => tbl.profileId.equals(profileId)))
        .write(
      CloudAccountLinksCompanion(
        status: Value<String>(CloudAccountLinkStatus.signedOut.storageValue),
        updatedAt: Value<DateTime>(DateTime.now().toUtc()),
      ),
    );
  }

  /// Marks [profileId]'s link as `sessionExpired` -- called by the
  /// reconciliation path
  /// (`lib/features/cloud_account/presentation/cloud_account_providers.dart`)
  /// when the live `CloudAuthProvider` session has disappeared without
  /// an explicit sign-out. A no-op if this profile has never been linked
  /// or is already `signedOut`/`sessionExpired` -- this method only ever
  /// moves a link OUT of `active`, never re-marks an already-inactive
  /// link, so it is always safe to call repeatedly/redundantly from a
  /// reactive reconciler without corrupting `updatedAt` on every rebuild.
  Future<void> recordSessionExpired(String profileId) async {
    final CloudAccountLink? existing = await getLink(profileId);
    if (existing == null) return;
    if (CloudAccountLinkStatus.fromStorageValue(existing.status) != CloudAccountLinkStatus.active) {
      return;
    }
    await (_db.update(_db.cloudAccountLinks)..where((tbl) => tbl.profileId.equals(profileId)))
        .write(
      CloudAccountLinksCompanion(
        status: Value<String>(CloudAccountLinkStatus.sessionExpired.storageValue),
        updatedAt: Value<DateTime>(DateTime.now().toUtc()),
      ),
    );
  }
}
