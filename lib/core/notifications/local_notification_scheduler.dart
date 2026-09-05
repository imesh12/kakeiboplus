import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'notification_scheduler.dart';

/// The real [NotificationScheduler], backed by
/// `flutter_local_notifications` + `timezone` (+ `flutter_timezone`,
/// purely to read the device's current IANA timezone name). This is the
/// ONLY file in the app that imports any of those three packages --
/// every recurring provider/repository/domain file (and every test of
/// them) depends on [NotificationScheduler] instead, per Beta 1 Task
/// 4B's architecture requirement -- see `docs/14_DECISION_LOG.md`
/// ADR-024.
///
/// Written against `flutter_local_notifications` 22.x's DOCUMENTED
/// public API, fetched from pub.dev at implementation time (no Flutter
/// toolchain was available in the environment that wrote this file, so
/// it could not be compiled or run against the actual resolved
/// package): `zonedSchedule`'s named `title`/`body` parameters,
/// `AndroidScheduleMode.inexactAllowWhileIdle`,
/// `pendingNotificationRequests`,
/// `AndroidFlutterLocalNotificationsPlugin
/// .requestNotificationsPermission`/`areNotificationsEnabled`,
/// `IOSFlutterLocalNotificationsPlugin
/// .requestPermissions`/`checkPermissions`,
/// `resolvePlatformSpecificImplementation<T>()`. **Verify this still
/// matches once `flutter pub get` resolves the actual installed
/// version** -- this plugin's API has changed across major versions
/// before (e.g. `zonedSchedule`'s title/body were positional required
/// parameters in older major versions).
///
/// # Why 09:00 local, DST-safe
///
/// [schedule] never does its own UTC-offset arithmetic. It builds a
/// `tz.TZDateTime(location, year, month, day, 9)` directly from the
/// occurrence's calendar date -- that constructor resolves "09:00 wall
/// clock on this date, in this IANA zone" correctly on its own even
/// across a DST transition, which a fixed-offset calculation would get
/// wrong twice a year in zones that observe DST.
class LocalNotificationScheduler implements NotificationScheduler {
  LocalNotificationScheduler({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// Beta 1's single fixed local reminder hour (24h, local time) -- see
  /// `docs/14_DECISION_LOG.md` ADR-024.
  static const int _reminderHour = 9;

  /// The one notification channel every recurring reminder posts to on
  /// Android -- a single fixed channel for Beta 1 rather than one per
  /// rule, so there's exactly one system "Recurring reminders" toggle
  /// for the user to find, not one per rule name.
  static const String _androidChannelId = 'recurring_reminders';
  static const String _androidChannelName = 'Recurring reminders';
  static const String _androidChannelDescription =
      "Local reminders for recurring income, expenses, and transfers you've opted in to.";

  Future<void>? _initFuture;
  tz.Location _localLocation = tz.UTC;

  /// Idempotent -- every public method awaits this first; only the
  /// very first call does any work (detects the device timezone,
  /// initializes the `timezone` database, initializes the plugin,
  /// creates the Android channel). Safe to call from app start,
  /// reconciliation, and the UI toggle handler alike.
  Future<void> _ensureInitialized() => _initFuture ??= _initialize();

  Future<void> _initialize() async {
    tz_data.initializeTimeZones();

    String? deviceTimezoneName;
    try {
      final TimezoneInfo info = await FlutterTimezone.getLocalTimezone();
      deviceTimezoneName = info.identifier;
    } catch (_) {
      // Falls through to UTC below -- a reminder that ends up firing at
      // 09:00 UTC rather than 09:00 device-local time is a reasonable,
      // never-crashing degradation, not a reason to fail every
      // scheduling call.
    }

    tz.Location location = tz.UTC;
    if (deviceTimezoneName != null) {
      try {
        location = tz.getLocation(deviceTimezoneName);
      } catch (_) {
        location = tz.UTC;
      }
    }
    _localLocation = location;
    tz.setLocalLocation(location);

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );
    await _plugin.initialize(settings: settings);

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _androidChannelId,
          _androidChannelName,
          description: _androidChannelDescription,
        ),
      );
    }
  }

  @override
  Future<NotificationPermissionStatus> permissionStatus() async {
    await _ensureInitialized();
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
          _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final bool? enabled = await androidPlugin?.areNotificationsEnabled();
      if (enabled == null) return NotificationPermissionStatus.notDetermined;
      return enabled ? NotificationPermissionStatus.granted : NotificationPermissionStatus.denied;
    }
    if (Platform.isIOS || Platform.isMacOS) {
      final IOSFlutterLocalNotificationsPlugin? iosPlugin =
          _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      final NotificationsEnabledOptions? options = await iosPlugin?.checkPermissions();
      if (options == null) return NotificationPermissionStatus.notDetermined;
      return options.isEnabled
          ? NotificationPermissionStatus.granted
          : NotificationPermissionStatus.denied;
    }
    // Any other platform: never claim permission is granted on a
    // platform this abstraction hasn't been verified against.
    return NotificationPermissionStatus.notDetermined;
  }

  @override
  Future<NotificationPermissionStatus> requestPermission() async {
    await _ensureInitialized();
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
          _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final bool? granted = await androidPlugin?.requestNotificationsPermission();
      if (granted == null) return NotificationPermissionStatus.notDetermined;
      return granted ? NotificationPermissionStatus.granted : NotificationPermissionStatus.denied;
    }
    if (Platform.isIOS || Platform.isMacOS) {
      final IOSFlutterLocalNotificationsPlugin? iosPlugin =
          _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      final bool? granted =
          await iosPlugin?.requestPermissions(alert: true, badge: true, sound: true);
      if (granted == null) return NotificationPermissionStatus.notDetermined;
      return granted ? NotificationPermissionStatus.granted : NotificationPermissionStatus.denied;
    }
    return NotificationPermissionStatus.notDetermined;
  }

  @override
  Future<void> schedule(ScheduledReminder reminder) async {
    await _ensureInitialized();
    final DateTime date = reminder.scheduledDateUtc;
    final tz.TZDateTime target =
        tz.TZDateTime(_localLocation, date.year, date.month, date.day, _reminderHour);

    if (!target.isAfter(tz.TZDateTime.now(_localLocation))) {
      // Already past the reminder hour on this calendar date in the
      // device's current local timezone -- the in-app Overdue/Due-today
      // list already surfaces this occurrence; do not attempt to
      // schedule a notification in the past (the plugin requires a
      // future instant). Simply not scheduling this id also keeps it
      // out of `pendingIds()`, which is what a caller re-diffing the
      // desired set expects.
      return;
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _androidChannelId,
      _androidChannelName,
      channelDescription: _androidChannelDescription,
    );
    const DarwinNotificationDetails darwinDetails = DarwinNotificationDetails();
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _plugin.zonedSchedule(
      id: reminder.id,
      scheduledDate: target,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: reminder.title,
      body: reminder.body,
    );
  }

  @override
  Future<void> cancel(int id) async {
    await _ensureInitialized();
    await _plugin.cancel(id: id);
  }

  @override
  Future<Set<int>> pendingIds() async {
    await _ensureInitialized();
    final List<PendingNotificationRequest> pending = await _plugin.pendingNotificationRequests();
    return pending.map((PendingNotificationRequest request) => request.id).toSet();
  }
}
