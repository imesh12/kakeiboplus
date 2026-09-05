import 'package:meta/meta.dart';

/// Whether the OS currently grants this app permission to show local
/// notifications -- Beta 1 Task 4B. Deliberately coarser than any one
/// platform's native enum: every [NotificationScheduler] implementation
/// (real or fake) maps its platform's answer onto these four values.
enum NotificationPermissionStatus {
  /// The OS will show notifications this app schedules.
  granted,

  /// The user has explicitly refused; the OS will not show a system
  /// permission prompt again on request -- [NotificationScheduler
  /// .requestPermission] may return this without ever surfacing a
  /// dialog.
  denied,

  /// Neither granted nor denied yet -- the OS has not been asked. Only
  /// [NotificationScheduler.requestPermission] (never `permissionStatus`
  /// alone) may surface a system prompt.
  notDetermined,

  /// The OS itself disallows notifications for this app (e.g. a device
  /// policy) -- requesting again cannot change this.
  restricted,
}

/// One fully-resolved local reminder a [NotificationScheduler] should
/// show. Deliberately carries only a calendar date
/// ([scheduledDateUtc]), never a precise instant or a `TZDateTime` --
/// converting "this UTC calendar date" into "09:00 in the device's
/// current local timezone, DST-safe" is a platform-specific concern
/// that belongs entirely inside the concrete scheduler implementation
/// (see `LocalNotificationScheduler`), never in
/// `RecurringSchedule`, the pure recurring reminder planner, or any
/// Riverpod provider -- see `docs/14_DECISION_LOG.md` ADR-024,
/// correction 5.
@immutable
class ScheduledReminder {
  const ScheduledReminder({
    required this.id,
    required this.ruleId,
    required this.scheduledDateUtc,
    required this.title,
    required this.body,
  });

  /// The platform notification id -- allocated by
  /// `NotificationIdAllocator`, guaranteed unique among every
  /// [ScheduledReminder] scheduled in the same reconciliation pass (see
  /// that class's doc comment for how collisions are resolved).
  final int id;

  /// The recurring rule this reminder is for -- carried through purely
  /// for logging/debugging; a [NotificationScheduler] must not use this
  /// for identity (that is [id]'s job).
  final String ruleId;

  /// The occurrence's calendar date (UTC midnight, already normalized
  /// by `normalizeRecurringDate`) -- NOT the instant the notification
  /// fires. See the class doc comment.
  final DateTime scheduledDateUtc;

  final String title;
  final String body;
}

/// The notification-scheduling abstraction every notification-aware
/// Riverpod provider depends on -- never a
/// `flutter_local_notifications`/`timezone` type directly. This keeps
/// every recurring provider/repository/domain file, and every test of
/// them, free of a concrete plugin dependency -- see
/// `docs/14_DECISION_LOG.md` ADR-024.
///
/// Every method here must be safe to call repeatedly with the same
/// arguments (idempotent) -- the Task 4B reconciliation loop calls
/// [schedule] for the FULL desired set on every pass rather than
/// diffing content itself, relying on implementations replacing (never
/// duplicating) an already-scheduled [ScheduledReminder.id].
abstract class NotificationScheduler {
  /// The current permission state, without ever surfacing a system
  /// prompt. Safe to call as often as needed (app start, every
  /// reconciliation pass, opening the Recurring screen) -- see
  /// correction 3: only [requestPermission] may prompt, and only ever
  /// as the direct result of the user turning "Remind me" on.
  Future<NotificationPermissionStatus> permissionStatus();

  /// Requests notification permission from the OS, prompting the user
  /// if (and only if) the platform has not already recorded an answer.
  /// Callers must invoke this ONLY as the direct, synchronous result of
  /// the user enabling a rule's "Remind me" toggle -- never at app
  /// startup, during reconciliation, or from an unrelated widget
  /// rebuild (correction 3).
  Future<NotificationPermissionStatus> requestPermission();

  /// Schedules (or, if [ScheduledReminder.id] already has a pending
  /// notification, replaces it in place -- same id, new content/date)
  /// exactly one local reminder. Must not throw merely because
  /// permission is currently denied; the reconciliation loop calls this
  /// unconditionally for the desired set, and a denied-permission
  /// schedule call is expected to silently no-op at the OS level.
  Future<void> schedule(ScheduledReminder reminder);

  /// Cancels the pending notification with this [id]. A no-op, never
  /// an error, if nothing is currently scheduled under that id.
  Future<void> cancel(int id);

  /// The ids of every notification currently pending (scheduled but not
  /// yet shown/dismissed) for this app. The reconciliation loop diffs
  /// this against the desired id set to find stale reminders to cancel
  /// -- see `recurring_notification_providers.dart`.
  Future<Set<int>> pendingIds();
}
