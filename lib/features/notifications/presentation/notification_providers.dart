import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_mode.dart';
import '../../auth/presentation/controllers/auth_providers.dart';
import '../data/notification_store.dart';
import '../data/local_notification_transport.dart';
import '../data/study_notification_service.dart';
import '../domain/study_notification.dart';

final notificationServiceProvider = Provider<StudyNotificationService>((ref) {
  final preview = ref.watch(appModeProvider) == AppMode.preview;
  final service = preview
      ? StudyNotificationService(
          store: NotificationStore(MemoryNotificationValues()),
          transport: PreviewNotificationTransport(),
          isPreview: true,
        )
      : StudyNotificationService.android();
  ref.onDispose(service.dispose);
  return service;
}, dependencies: [appModeProvider]);

final notificationUserProvider = Provider<String?>(
  (ref) => ref.watch(appModeProvider) == AppMode.preview
      ? 'notification-preview'
      : ref.watch(authStateProvider.select((state) => state.userId)),
  dependencies: [appModeProvider],
);

class NotificationSnapshot {
  const NotificationSnapshot({
    required this.userId,
    required this.available,
    required this.preview,
    required this.allowed,
    required this.settings,
    required this.items,
  });
  final String? userId;
  final bool available, preview, allowed;
  final NotificationPreferences settings;
  final List<NotificationInboxItem> items;
  int get unread => items.where((item) => !item.isRead).length;
}

final notificationSnapshotProvider =
    AsyncNotifierProvider<NotificationController, NotificationSnapshot>(
      NotificationController.new,
      dependencies: [notificationServiceProvider, notificationUserProvider],
      retry: (_, _) => null,
    );

class NotificationController extends AsyncNotifier<NotificationSnapshot> {
  @override
  Future<NotificationSnapshot> build() async {
    final uid = ref.watch(notificationUserProvider);
    final service = ref.watch(notificationServiceProvider);
    await service.bindAccount(uid);
    if (uid == null || !service.available) {
      return NotificationSnapshot(
        userId: uid,
        available: false,
        preview: service.isPreview,
        allowed: false,
        settings: const NotificationPreferences(),
        items: const [],
      );
    }
    final settings = await service.store.preferences(uid);
    final items = await service.store.history(uid);
    final allowed = await service.transport.permission();
    return NotificationSnapshot(
      userId: uid,
      available: true,
      preview: service.isPreview,
      allowed: allowed,
      settings: settings,
      items: items,
    );
  }

  Future<void> settings(NotificationPreferences value) async {
    final uid = ref.read(notificationUserProvider);
    if (uid == null) return;
    await ref.read(notificationServiceProvider).saveSettings(uid, value);
    if (ref.mounted) ref.invalidateSelf();
  }

  Future<bool> enable() async {
    final service = ref.read(notificationServiceProvider);
    await service.initialize();
    final allowed = await service.transport.permission(request: true);
    if (ref.mounted) ref.invalidateSelf();
    return allowed;
  }

  Future<void> test() async {
    final uid = ref.read(notificationUserProvider);
    if (uid != null) await ref.read(notificationServiceProvider).test(uid);
    if (ref.mounted) ref.invalidateSelf();
  }

  Future<void> markAllRead() async {
    final uid = ref.read(notificationUserProvider);
    if (uid != null) {
      await ref.read(notificationServiceProvider).store.markAllRead(uid);
    }
    if (ref.mounted) ref.invalidateSelf();
  }
}

final notificationNoticeProvider =
    NotifierProvider<NotificationNotice, String?>(NotificationNotice.new);

class NotificationNotice extends Notifier<String?> {
  @override
  String? build() => null;
  void show(String? text) => state = text;
}
