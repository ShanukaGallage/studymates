import 'dart:convert';

enum StudyAlertKind { focusFinished, breakFinished, recovery, reminder, test }

class NotificationPreferences {
  const NotificationPreferences({
    this.cycles = true,
    this.recovery = true,
    this.sound = true,
    this.vibration = true,
    this.dailyReminder = false,
    this.hour = 19,
    this.minute = 0,
  });
  final bool cycles, recovery, sound, vibration, dailyReminder;
  final int hour, minute;
  NotificationPreferences copyWith({
    bool? cycles,
    bool? recovery,
    bool? sound,
    bool? vibration,
    bool? dailyReminder,
    int? hour,
    int? minute,
  }) => NotificationPreferences(
    cycles: cycles ?? this.cycles,
    recovery: recovery ?? this.recovery,
    sound: sound ?? this.sound,
    vibration: vibration ?? this.vibration,
    dailyReminder: dailyReminder ?? this.dailyReminder,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
  );
  Map<String, dynamic> toJson() => {
    'cycles': cycles,
    'recovery': recovery,
    'sound': sound,
    'vibration': vibration,
    'dailyReminder': dailyReminder,
    'hour': hour,
    'minute': minute,
  };
  factory NotificationPreferences.fromJson(Map<String, dynamic> json) =>
      NotificationPreferences(
        cycles: json['cycles'] == true,
        recovery: json['recovery'] == true,
        sound: json['sound'] == true,
        vibration: json['vibration'] == true,
        dailyReminder: json['dailyReminder'] == true,
        hour: (json['hour'] as int).clamp(0, 23),
        minute: (json['minute'] as int).clamp(0, 59),
      );
}

/// A local device event, never an email, Firestore record or arbitrary route.
class StudyAlert {
  const StudyAlert({
    required this.id,
    required this.userId,
    required this.kind,
    required this.at,
    this.sessionId,
  });
  final String id, userId;
  final String? sessionId;
  final StudyAlertKind kind;
  final DateTime at;
  bool get opensHall => sessionId != null && kind != StudyAlertKind.test;
  String get title => switch (kind) {
    StudyAlertKind.focusFinished => 'Time for a break',
    StudyAlertKind.breakFinished => 'Ready to focus',
    StudyAlertKind.recovery => 'Study connection needs attention',
    StudyAlertKind.reminder => 'Make a little progress today',
    StudyAlertKind.test => 'StudyMates notifications are ready',
  };
  String get body => switch (kind) {
    StudyAlertKind.focusFinished =>
      '25 minutes done. Enjoy your 5-minute break.',
    StudyAlertKind.breakFinished =>
      'Your next Common Hall focus cycle has started.',
    StudyAlertKind.recovery =>
      'Open Common Hall to check your session and save confirmed time.',
    StudyAlertKind.reminder => 'Choose Common Hall or find a study room.',
    StudyAlertKind.test => 'Tap to open your notifications.',
  };
  String encode() => jsonEncode({
    'v': 1,
    'id': id,
    'userId': userId,
    'kind': kind.name,
    'at': at.toUtc().toIso8601String(),
    'sessionId': sessionId,
  });
  static StudyAlert? decode(String? raw) {
    try {
      final data = jsonDecode(raw!) as Map<String, dynamic>;
      if (data['v'] != 1 ||
          (data['id'] as String).isEmpty ||
          (data['userId'] as String).isEmpty) {
        return null;
      }
      return StudyAlert(
        id: data['id'],
        userId: data['userId'],
        kind: StudyAlertKind.values.byName(data['kind']),
        at: DateTime.parse(data['at']).toUtc(),
        sessionId: data['sessionId'],
      );
    } catch (_) {
      return null;
    }
  }
}

class NotificationInboxItem {
  const NotificationInboxItem(this.alert, {required this.isRead});
  final StudyAlert alert;
  final bool isRead;
}
