import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as zones;
import 'package:timezone/timezone.dart' as tz;

import '../domain/study_notification.dart';

abstract interface class NotificationTransport {
  bool get supported;
  Future<void> initialize(void Function(StudyAlert) onTap);
  Future<StudyAlert?> launchAlert();
  Future<bool> permission({bool request = false});
  Future<void> show(StudyAlert alert, NotificationPreferences settings);
  Future<void> cancelSession(String uid, String sessionId);
  Future<void> cancelAllStudyAlerts();
  Future<void> scheduleReminder(String? uid, NotificationPreferences settings);
}

tz.TZDateTime nextStudyReminder(tz.TZDateTime now, int hour, int minute) {
  var next = tz.TZDateTime(
    now.location,
    now.year,
    now.month,
    now.day,
    hour,
    minute,
  );
  if (!next.isAfter(now)) {
    next = tz.TZDateTime(
      now.location,
      now.year,
      now.month,
      now.day + 1,
      hour,
      minute,
    );
  }
  return next;
}

class AndroidNotificationTransport implements NotificationTransport {
  final plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _initializing;
  bool _launchConsumed = false;
  static const phaseId = 501, recoveryId = 502, testId = 503, reminderId = 504;
  @override
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  @override
  Future<void> initialize(void Function(StudyAlert) onTap) => _initializing ??=
      () async {
        if (!supported) return;
        await plugin.initialize(
          settings: const InitializationSettings(
            android: AndroidInitializationSettings('ic_stat_study'),
          ),
          onDidReceiveNotificationResponse: (response) {
            final alert = StudyAlert.decode(response.payload);
            if (alert != null) onTap(alert);
          },
        );
      }().catchError((Object error, StackTrace stack) {
        _initializing = null;
        Error.throwWithStackTrace(error, stack);
      });
  @override
  Future<StudyAlert?> launchAlert() async {
    if (!supported || _launchConsumed) return null;
    final details = await plugin.getNotificationAppLaunchDetails();
    _launchConsumed = true;
    return details?.didNotificationLaunchApp == true
        ? StudyAlert.decode(details?.notificationResponse?.payload)
        : null;
  }

  @override
  Future<bool> permission({bool request = false}) async {
    if (!supported) return false;
    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()!;
    return (request
            ? await android.requestNotificationsPermission()
            : await android.areNotificationsEnabled()) ??
        false;
  }

  NotificationDetails details(NotificationPreferences settings) {
    final mode =
        '${settings.sound ? 'sound' : 'silent'}_${settings.vibration ? 'vibrate' : 'still'}';
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'studymates_alerts_$mode',
        'Study alerts · ${settings.sound ? 'sound' : 'silent'}${settings.vibration ? ' + vibration' : ''}',
        channelDescription:
            'Focus, break, recovery and opted-in study reminders.',
        importance: Importance.high,
        priority: Priority.high,
        playSound: settings.sound,
        enableVibration: settings.vibration,
        visibility: NotificationVisibility.private,
        category: AndroidNotificationCategory.reminder,
        autoCancel: true,
      ),
    );
  }

  @override
  Future<void> show(StudyAlert alert, NotificationPreferences settings) async {
    await plugin.show(
      id: switch (alert.kind) {
        StudyAlertKind.recovery => recoveryId,
        StudyAlertKind.test => testId,
        StudyAlertKind.reminder => reminderId,
        _ => phaseId,
      },
      title: alert.title,
      body: alert.body,
      notificationDetails: details(settings),
      payload: alert.encode(),
    );
  }

  @override
  Future<void> cancelSession(String uid, String sessionId) async {
    if (!supported) return;
    for (final notification in await plugin.getActiveNotifications()) {
      if (notification.id != phaseId && notification.id != recoveryId) continue;
      final alert = StudyAlert.decode(notification.payload);
      if (alert?.userId == uid && alert?.sessionId == sessionId) {
        await plugin.cancel(id: notification.id!);
      }
    }
  }

  @override
  Future<void> cancelAllStudyAlerts() async {
    if (!supported) return;
    // Do not cancel the separate ongoing foreground timer (ID 301).
    for (final id in [phaseId, recoveryId, testId, reminderId]) {
      await plugin.cancel(id: id);
    }
  }

  @override
  Future<void> scheduleReminder(
    String? uid,
    NotificationPreferences settings,
  ) async {
    if (!supported) return;
    await plugin.cancel(id: reminderId);
    if (uid == null || !settings.dailyReminder || !await permission()) return;
    zones.initializeTimeZones();
    final location = tz.getLocation(
      (await FlutterTimezone.getLocalTimezone()).identifier,
    );
    final now = tz.TZDateTime.now(location);
    final next = nextStudyReminder(now, settings.hour, settings.minute);
    final alert = StudyAlert(
      id: 'daily-reminder',
      userId: uid,
      kind: StudyAlertKind.reminder,
      at: next.toUtc(),
    );
    await plugin.zonedSchedule(
      id: reminderId,
      title: alert.title,
      body: alert.body,
      scheduledDate: next,
      notificationDetails: details(settings),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: alert.encode(),
    );
  }
}

class PreviewNotificationTransport implements NotificationTransport {
  @override
  bool get supported => false;
  @override
  Future<void> initialize(void Function(StudyAlert) onTap) async {}
  @override
  Future<StudyAlert?> launchAlert() async => null;
  @override
  Future<bool> permission({bool request = false}) async => false;
  @override
  Future<void> show(StudyAlert alert, NotificationPreferences settings) async {}
  @override
  Future<void> cancelSession(String uid, String sessionId) async {}
  @override
  Future<void> cancelAllStudyAlerts() async {}
  @override
  Future<void> scheduleReminder(
    String? uid,
    NotificationPreferences settings,
  ) async {}
}
