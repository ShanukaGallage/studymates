import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/common_hall/presentation/common_hall_providers.dart';
import '../features/notifications/domain/study_notification.dart';
import '../features/notifications/presentation/notification_providers.dart';
import 'app_mode.dart';
import 'router.dart';

final notificationCoordinatorProvider = Provider<void>(
  (ref) {
    final service = ref.watch(notificationServiceProvider);
    Future<void> open(StudyAlert alert) async {
      final uid = ref.read(notificationUserProvider);
      if (uid == null || alert.userId != uid) return;
      var destination = '/notifications';
      String? notice;
      if (alert.opensHall && ref.read(appModeProvider) == AppMode.connected) {
        try {
          final session = await ref
              .read(commonHallRepositoryProvider)
              .getCurrentSession();
          if (session?.userId == uid && session?.sessionId == alert.sessionId) {
            destination = '/common-hall';
          } else {
            notice = 'This study session has ended. Open Progress to see saved study time.';
          }
        } catch (_) {
          notice = 'Could not check this session. Reconnect and tap the alert to retry.';
        }
      } else if (alert.kind == StudyAlertKind.reminder) {
        destination = '/home';
      }
      if (!ref.mounted || ref.read(notificationUserProvider) != uid) return;
      try {
        await service.recordOpenedReminder(alert);
        if (alert.kind != StudyAlertKind.reminder) {
          await service.store.markRead(uid, alert.id);
        }
      } catch (_) {
        /* Navigation still works if local history cannot be updated. */
      }
      if (!ref.mounted || ref.read(notificationUserProvider) != uid) return;
      ref.read(notificationNoticeProvider.notifier).show(notice);
      ref.invalidate(notificationSnapshotProvider);
      ref.read(appRouterProvider).go(destination);
    }

    final tap = service.taps.stream.listen((alert) => unawaited(open(alert)));
    final changed = service.changes.stream.listen((_) {
      if (ref.mounted) ref.invalidate(notificationSnapshotProvider);
    });
    ref.listen(notificationSnapshotProvider, (_, next) {
      if (next.asData?.value.userId == null) return;
      unawaited(
        () async {
          final initial = await service.transport.launchAlert();
          if (ref.mounted && initial != null) await open(initial);
        }().catchError((_) {}),
      );
    }, fireImmediately: true);
    ref.listen(notificationUserProvider, (_, _) {
      ref.read(notificationNoticeProvider.notifier).show(null);
    });
    void receive(Object data) {
      if (data == 'study-notification-added' && ref.mounted) {
        ref.invalidate(notificationSnapshotProvider);
      }
    }

    final android = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    if (android) FlutterForegroundTask.addTaskDataCallback(receive);
    final observer = _NotificationLifecycle(() {
      if (ref.mounted) ref.invalidate(notificationSnapshotProvider);
    });
    WidgetsBinding.instance.addObserver(observer);
    ref.onDispose(() {
      unawaited(tap.cancel());
      unawaited(changed.cancel());
      WidgetsBinding.instance.removeObserver(observer);
      if (android) FlutterForegroundTask.removeTaskDataCallback(receive);
    });
  },
  dependencies: [
    notificationServiceProvider,
    notificationSnapshotProvider,
    notificationUserProvider,
    appRouterProvider,
    appModeProvider,
  ],
);

class _NotificationLifecycle extends WidgetsBindingObserver {
  _NotificationLifecycle(this.resume);
  final VoidCallback resume;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) resume();
  }
}
