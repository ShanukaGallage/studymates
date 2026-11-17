import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/study_notification.dart';

abstract interface class NotificationValues {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> remove(String key);
  Future<Map<String, Object?>> all();
}

class DeviceNotificationValues implements NotificationValues {
  SharedPreferencesAsync? _instance;
  SharedPreferencesAsync get _prefs => _instance ??= SharedPreferencesAsync();
  @override
  Future<String?> read(String key) => _prefs.getString(key);
  @override
  Future<void> write(String key, String value) => _prefs.setString(key, value);
  @override
  Future<void> remove(String key) => _prefs.remove(key);
  @override
  Future<Map<String, Object?>> all() => _prefs.getAll();
}

/// Explicit preview/test composition only; never a backend-failure fallback.
class MemoryNotificationValues implements NotificationValues {
  final values = <String, Object?>{};
  @override
  Future<String?> read(String key) async => values[key] as String?;
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }

  @override
  Future<Map<String, Object?>> all() async => Map.of(values);
}

class NotificationStore {
  NotificationStore(this.values);
  final NotificationValues values;
  String scope(String uid) => base64Url.encode(utf8.encode(uid));
  String eventKey(String uid, String id) =>
      'notifications.event.${scope(uid)}.${Uri.encodeComponent(id)}';
  String readKey(String uid, String id) =>
      'notifications.read.${scope(uid)}.${Uri.encodeComponent(id)}';
  Future<String?> owner() async {
    final uid = await values.read('notifications.owner');
    return uid == null || uid.isEmpty ? null : uid;
  }

  Future<void> setOwner(String? uid) =>
      values.write('notifications.owner', uid ?? '');
  Future<NotificationPreferences> preferences(String uid) async {
    final raw = await values.read('notifications.settings.${scope(uid)}');
    if (raw == null) return const NotificationPreferences();
    return NotificationPreferences.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }

  Future<void> savePreferences(String uid, NotificationPreferences settings) =>
      values.write(
        'notifications.settings.${scope(uid)}',
        jsonEncode(settings.toJson()),
      );
  Future<List<NotificationInboxItem>> history(String uid) async {
    final all = await values.all();
    final prefix = 'notifications.event.${scope(uid)}.';
    final result = <NotificationInboxItem>[];
    for (final entry in all.entries) {
      if (!entry.key.startsWith(prefix) || entry.value is! String) continue;
      final alert = StudyAlert.decode(entry.value as String);
      if (alert == null || alert.userId != uid) continue;
      result.add(
        NotificationInboxItem(
          alert,
          isRead: all[readKey(uid, alert.id)] == 'true',
        ),
      );
    }
    result.sort((a, b) => b.alert.at.compareTo(a.alert.at));
    return result.take(50).toList();
  }

  Future<void> record(StudyAlert alert) async {
    await values.write(eventKey(alert.userId, alert.id), alert.encode());
    final all = await values.all();
    final prefix = 'notifications.event.${scope(alert.userId)}.';
    final events =
        all.entries
            .where(
              (entry) => entry.key.startsWith(prefix) && entry.value is String,
            )
            .map((entry) => StudyAlert.decode(entry.value as String))
            .whereType<StudyAlert>()
            .where((entry) => entry.userId == alert.userId)
            .toList()
          ..sort((a, b) => b.at.compareTo(a.at));
    for (final old in events.skip(50)) {
      await values.remove(eventKey(old.userId, old.id));
      await values.remove(readKey(old.userId, old.id));
    }
  }

  Future<void> markRead(String uid, String id) =>
      values.write(readKey(uid, id), 'true');
  Future<void> markAllRead(String uid) async {
    for (final item in await history(uid)) {
      await markRead(uid, item.alert.id);
    }
  }

  /// One phase cursor per account, separate from inbox/read state. Restarts,
  /// rebuilds and missed ticks never replay an entire sequence of old alerts.
  Future<bool> advancePhase(String uid, String sessionId, int ordinal) async {
    final key = 'notifications.phase.${scope(uid)}';
    final raw = await values.read(key);
    final previous = raw == null
        ? null
        : jsonDecode(raw) as Map<String, dynamic>;
    if (previous?['sessionId'] == sessionId &&
        ordinal <= (previous!['ordinal'] as int)) {
      return false;
    }
    await values.write(
      key,
      jsonEncode({'sessionId': sessionId, 'ordinal': ordinal}),
    );
    return previous?['sessionId'] == sessionId;
  }

  Future<bool> claimRecovery(String uid, String sessionId) async {
    final key = 'notifications.recovery.${scope(uid)}';
    if (await values.read(key) == sessionId) return false;
    await values.write(key, sessionId);
    return true;
  }
}
