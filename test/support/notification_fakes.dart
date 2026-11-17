import 'package:studymates/features/notifications/data/local_notification_transport.dart';
import 'package:studymates/features/notifications/data/notification_store.dart';
import 'package:studymates/features/notifications/data/study_notification_service.dart';
import 'package:studymates/features/notifications/domain/study_notification.dart';

class TestNotificationTransport implements NotificationTransport {
  bool granted = true;
  int cancelled = 0;
  String? reminderUser;
  NotificationPreferences? reminderSettings;
  final shown = <StudyAlert>[];
  void Function(StudyAlert)? onTap;
  @override
  bool get supported => true;
  @override
  Future<void> initialize(void Function(StudyAlert) onTap) async {
    this.onTap = onTap;
  }

  @override
  Future<StudyAlert?> launchAlert() async => null;
  @override
  Future<bool> permission({bool request = false}) async => granted;
  @override
  Future<void> show(StudyAlert alert, NotificationPreferences settings) async {
    shown.add(alert);
  }

  @override
  Future<void> cancelSession(String uid, String sessionId) async {
    shown.removeWhere((a) => a.userId == uid && a.sessionId == sessionId);
  }

  @override
  Future<void> cancelAllStudyAlerts() async {
    cancelled++;
    shown.clear();
  }

  @override
  Future<void> scheduleReminder(
    String? uid,
    NotificationPreferences settings,
  ) async {
    reminderUser = uid;
    reminderSettings = settings;
  }
}

StudyNotificationService testNotificationService({
  TestNotificationTransport? transport,
  bool preview = false,
}) => StudyNotificationService(
  store: NotificationStore(MemoryNotificationValues()),
  transport: transport ?? TestNotificationTransport(),
  isPreview: preview,
);
