import 'package:ai_financial_coach/core/notifications/notification_scheduler.dart';

/// An in-memory [NotificationScheduler] fake for tests -- no device, no
/// `flutter_local_notifications` plugin. Shared by every Beta 1 Task 4B
/// test that needs to observe/control scheduling without a real OS.
class FakeNotificationScheduler implements NotificationScheduler {
  FakeNotificationScheduler({this.permission = NotificationPermissionStatus.granted});

  /// What [permissionStatus]/[requestPermission] report -- set this
  /// before a test exercises a denied/restricted/not-determined path.
  NotificationPermissionStatus permission;

  /// Every currently-scheduled reminder, keyed by id -- mirrors what a
  /// real OS would consider "pending".
  final Map<int, ScheduledReminder> scheduled = <int, ScheduledReminder>{};

  /// Every id ever passed to [cancel], in call order -- including ones
  /// that were never actually pending (a real scheduler no-ops on
  /// those too; tests can still assert on intent via this list).
  final List<int> cancelledIds = <int>[];

  int scheduleCallCount = 0;
  int requestPermissionCallCount = 0;

  @override
  Future<NotificationPermissionStatus> permissionStatus() async => permission;

  @override
  Future<NotificationPermissionStatus> requestPermission() async {
    requestPermissionCallCount++;
    return permission;
  }

  @override
  Future<void> schedule(ScheduledReminder reminder) async {
    scheduleCallCount++;
    scheduled[reminder.id] = reminder;
  }

  @override
  Future<void> cancel(int id) async {
    cancelledIds.add(id);
    scheduled.remove(id);
  }

  @override
  Future<Set<int>> pendingIds() async => scheduled.keys.toSet();
}
