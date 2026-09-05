import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_notification_scheduler.dart';
import 'notification_scheduler.dart';

/// The app-wide [NotificationScheduler] -- a plain `Provider` (not
/// `.autoDispose`), same convention `appDatabaseProvider` established:
/// this should live for the whole process, not be torn down whenever
/// its last listener unsubscribes.
///
/// Overridden with a fake in every widget/provider test that touches
/// recurring reminders (see `test/features/recurring/presentation/
/// recurring_notification_providers_test.dart`) -- no test needs a real
/// device or the `flutter_local_notifications` plugin.
final Provider<NotificationScheduler> notificationSchedulerProvider =
    Provider<NotificationScheduler>((ref) => LocalNotificationScheduler());
