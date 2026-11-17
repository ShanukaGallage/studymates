import 'dart:async';

import '../../common_hall/domain/common_hall_models.dart';
import '../domain/study_notification.dart';
import 'notification_store.dart';
import 'local_notification_transport.dart';

class StudyNotificationService {
  StudyNotificationService({
    required this.store,
    required this.transport,
    this.isPreview = false,
  });
  factory StudyNotificationService.android() => StudyNotificationService(
    store: NotificationStore(DeviceNotificationValues()),
    transport: AndroidNotificationTransport(),
  );
  final NotificationStore store;
  final NotificationTransport transport;
  final bool isPreview;
  final taps = StreamController<StudyAlert>.broadcast();
  final changes = StreamController<void>.broadcast();
  Future<void>? _operation;
  Future<void> _serial(Future<void> Function() action) {
    final previous = _operation;
    final current = () async {
      if (previous != null) {
        try {
          await previous;
        } catch (_) {}
      }
      await action();
    }();
    _operation = current;
    return current.whenComplete(() {
      if (identical(_operation, current)) _operation = null;
    });
  }

  bool get available => transport.supported || isPreview;
  Future<void> initialize() => transport.initialize(taps.add);
  Future<void> bindAccount(String? uid) => _serial(() async {
    if (!available) return;
    await initialize();
    if (await store.owner() != uid) {
      await store.setOwner(null);
      await transport.cancelAllStudyAlerts();
      await store.setOwner(uid);
    }
    await transport.scheduleReminder(
      uid,
      uid == null
          ? const NotificationPreferences()
          : await store.preferences(uid),
    );
  });
  Future<void> saveSettings(String uid, NotificationPreferences settings) =>
      _serial(() async {
        if (!available || await store.owner() != uid) {
          throw StateError('Account changed');
        }
        await store.savePreferences(uid, settings);
        await transport.scheduleReminder(uid, settings);
        changes.add(null);
      });
  Future<void> publish(StudyAlert alert) async {
    if (!available || await store.owner() != alert.userId) return;
    final settings = await store.preferences(alert.userId);
    if (alert.kind == StudyAlertKind.recovery && !settings.recovery) return;
    if ((alert.kind == StudyAlertKind.focusFinished ||
            alert.kind == StudyAlertKind.breakFinished) &&
        !settings.cycles) {
      return;
    }
    await store.record(alert);
    changes.add(null);
    if (await store.owner() != alert.userId) return;
    if (await transport.permission()) {
      // Recheck ownership after the asynchronous permission query as well.
      if (await store.owner() == alert.userId) {
        await transport.show(alert, settings);
      }
    }
  }

  Future<void> test(String uid) async {
    await initialize();
    if (!isPreview && !await transport.permission(request: true)) {
      throw StateError(
        'Allow notifications in Android settings, then try again.',
      );
    }
    await publish(
      StudyAlert(
        id: 'test-${DateTime.now().microsecondsSinceEpoch}',
        userId: uid,
        kind: StudyAlertKind.test,
        at: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> recordOpenedReminder(StudyAlert alert) async {
    if (alert.kind != StudyAlertKind.reminder ||
        await store.owner() != alert.userId) {
      return;
    }
    final now = DateTime.now();
    await store.record(
      StudyAlert(
        id: 'reminder-${now.year}-${now.month}-${now.day}',
        userId: alert.userId,
        kind: alert.kind,
        at: now.toUtc(),
      ),
    );
    await store.markRead(
      alert.userId,
      'reminder-${now.year}-${now.month}-${now.day}',
    );
    changes.add(null);
  }

  Future<void> dispose() async {
    await taps.close();
    await changes.close();
  }
}

/// Only the existing Android foreground task drives hall phase events. Starting
/// or restoring a task seeds its cursor; missed cycles never generate a burst.
class HallNotificationEngine {
  HallNotificationEngine(this.service);
  final StudyNotificationService service;
  bool _busy = false;
  int? _observedOrdinal;
  String? _observedSession;
  Future<void> tick(HallSession session, DateTime now) async {
    if (_busy || !session.isLive(now)) return;
    final timing = HallTiming(startsAt: session.startsAt, now: now);
    final ordinal = timing.completedCycles * 2 + (timing.isBreak ? 1 : 0);
    if (_observedSession == session.sessionId && _observedOrdinal == ordinal) {
      return;
    }
    _busy = true;
    try {
      if (await service.store.owner() != session.userId) return;
      final changed = await service.store.advancePhase(
        session.userId,
        session.sessionId,
        ordinal,
      );
      _observedSession = session.sessionId;
      _observedOrdinal = ordinal;
      if (changed) {
        await service.publish(
          StudyAlert(
            id: '${session.sessionId}-phase-$ordinal',
            userId: session.userId,
            sessionId: session.sessionId,
            kind: timing.isBreak
                ? StudyAlertKind.focusFinished
                : StudyAlertKind.breakFinished,
            at: now.toUtc(),
          ),
        );
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> interrupted(String uid, String sessionId) async {
    if (await service.store.owner() != uid ||
        !await service.store.claimRecovery(uid, sessionId)) {
      return;
    }
    await service.publish(
      StudyAlert(
        id: '$sessionId-recovery',
        userId: uid,
        sessionId: sessionId,
        kind: StudyAlertKind.recovery,
        at: DateTime.now().toUtc(),
      ),
    );
  }
}
