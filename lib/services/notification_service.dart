import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Thin wrapper over flutter_local_notifications used as a "dumb alarm clock":
/// it only fires an alert at a wall-clock time and carries no dose state. All
/// truth lives in the schedule rules + intake log; confirmation is in-app only.
///
/// Every call is guarded so the app stays fully usable even where local
/// notifications are unavailable (e.g. desktop/web during development).
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  bool get isReady => _ready;

  static const String _channelId = 'dose_reminders';
  static const String _channelName = 'Dose reminders';

  bool get _supportedPlatform =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

  Future<void> init() async {
    if (!_supportedPlatform) return;
    try {
      tzdata.initializeTimeZones();
      try {
        final name = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(name));
      } catch (_) {
        tz.setLocalLocation(tz.getLocation('UTC'));
      }

      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const settings = InitializationSettings(android: android, iOS: darwin, macOS: darwin);
      await _plugin.initialize(settings);
      _ready = true;
    } catch (e) {
      debugPrint('NotificationService.init failed: $e');
      _ready = false;
    }
  }

  Future<bool> requestPermissions() async {
    if (!_ready) return false;
    try {
      if (Platform.isAndroid) {
        final android =
            _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        final granted = await android?.requestNotificationsPermission() ?? false;
        await android?.requestExactAlarmsPermission();
        return granted;
      }
      final ios =
          _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      return await ios?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
    } catch (e) {
      debugPrint('requestPermissions failed: $e');
      return false;
    }
  }

  Future<bool> areNotificationsEnabled() async {
    if (!_ready) return false;
    try {
      if (Platform.isAndroid) {
        final android =
            _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        return await android?.areNotificationsEnabled() ?? false;
      }
    } catch (_) {}
    return _ready;
  }

  Future<bool> canScheduleExactAlarms() async {
    if (!_ready) return true;
    try {
      if (Platform.isAndroid) {
        final android =
            _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        return await android?.canScheduleExactNotifications() ?? false;
      }
    } catch (_) {}
    return true;
  }

  NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Reminders for when a dose is due',
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      );

  Future<List<int>> pendingIds() async {
    if (!_ready) return const [];
    try {
      final reqs = await _plugin.pendingNotificationRequests();
      return reqs.map((r) => r.id).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {
    if (!_ready) return;
    try {
      final tzWhen = tz.TZDateTime.from(when, tz.local);
      if (!tzWhen.isAfter(tz.TZDateTime.now(tz.local))) return;
      final exact = await canScheduleExactAlarms();
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzWhen,
        _details,
        androidScheduleMode:
            exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('schedule failed: $e');
    }
  }

  Future<void> cancel(int id) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id);
    } catch (_) {}
  }

  Future<void> cancelAll() async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }
}
