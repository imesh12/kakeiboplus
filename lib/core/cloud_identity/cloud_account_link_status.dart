/// The persisted status of a `CloudAccountLinks` row (`tables.dart`) --
/// one of the states Checkpoint 12.2 requires the local cloud-link
/// state to represent: "authenticated cloud identity", "session expired
/// / reauthentication required", and (implicitly, via the row simply
/// not existing) "local-only / signed out".
///
/// Stored as `storageValue` in the plain `TextColumn status` -- same
/// enum-as-text convention `AppThemeStyle` already established for
/// `profiles.theme_preference` in this schema (see that class's own
/// doc). [fromStorageValue] never throws on an unrecognized/corrupt
/// value, matching `AppThemeStyle.fromStorageValue`'s own safety
/// contract -- falling back to [signedOut] is the safe choice here: it
/// is the state that grants the LEAST trust (no active session implied),
/// so a corrupt row never accidentally reads back as "still signed in."
enum CloudAccountLinkStatus {
  /// This profile is currently signed into a cloud account and the last
  /// known session was live (subject to reconciliation catching up if a
  /// session silently dropped -- see `CloudAccountLinkRepository
  /// .recordSessionExpired`).
  active('active'),

  /// This profile explicitly signed out of its cloud account. The link row
  /// itself is NOT deleted -- `cloudUserId` is deliberately remembered
  /// (see `CloudAccountLinks.cloudUserId`'s own doc) so a later sign-in
  /// attempt with a DIFFERENT cloud account on this device can still be
  /// detected and refused.
  signedOut('signedOut'),

  /// This profile was signed in, but the session disappeared without an
  /// explicit sign-out (e.g. a token expired). Distinct from
  /// [signedOut] so the UI can truthfully prompt "session expired --
  /// sign in again" rather than presenting it identically to a
  /// deliberate sign-out.
  sessionExpired('sessionExpired');

  const CloudAccountLinkStatus(this.storageValue);

  final String storageValue;

  static CloudAccountLinkStatus fromStorageValue(String value) {
    return CloudAccountLinkStatus.values.firstWhere(
      (CloudAccountLinkStatus status) => status.storageValue == value,
      orElse: () => CloudAccountLinkStatus.signedOut,
    );
  }
}
