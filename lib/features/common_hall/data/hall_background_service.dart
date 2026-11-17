import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../../../firebase_options.dart';
import '../domain/common_hall_models.dart';
import 'common_hall_repository.dart';
import 'firestore_common_hall_repository.dart';

abstract interface class HallBackgroundService {
  Future<void> prepare();
  Future<void> start(HallSession session);
  Future<void> stop();
  VoidCallback listenForOpen(
    VoidCallback onOpen, {
    required VoidCallback onInterrupted,
  });
}

class AndroidHallBackgroundService implements HallBackgroundService {
  AndroidHallBackgroundService({
    this.firebaseAppName = '[DEFAULT]',
    this.emulatorHost = const String.fromEnvironment(
      'STUDYMATES_EMULATOR_HOST',
    ),
  });
  final String firebaseAppName, emulatorHost;
  Future<void>? _operation;

  Future<void> _serialize(Future<void> Function() action) {
    final previous = _operation;
    final current = () async {
      if (previous != null) {
        try {
          await previous;
        } catch (_) {
          // A failed request must not prevent a later retry or stop.
        }
      }
      await action();
    }();
    _operation = current;
    return current.whenComplete(() {
      if (identical(_operation, current)) _operation = null;
    });
  }

  void _configure() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'studymates_common_hall',
        channelName: 'Common Hall study timer',
        channelDescription: 'Your ongoing personal focus and break cycle.',
        onlyAlertOnce: true,
        visibility: NotificationVisibility.VISIBILITY_PRIVATE,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(1000),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: true,
        allowAutoRestart: true,
        stopWithTask: false,
      ),
    );
  }

  @override
  Future<void> prepare() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw const HallFailure(
        'The background Common Hall timer is available in the Android app.',
      );
    }
    _configure();
    var permission = await FlutterForegroundTask.checkNotificationPermission();
    if (permission != NotificationPermission.granted) {
      permission = await FlutterForegroundTask.requestNotificationPermission();
    }
    if (permission != NotificationPermission.granted) {
      throw const HallFailure(
        'Allow StudyMates notifications to keep the hall timer running with your screen locked.',
      );
    }
  }

  @override
  Future<void> start(HallSession session) => _serialize(() => _start(session));

  Future<void> _start(HallSession session) async {
    _configure();
    if (await FlutterForegroundTask.checkNotificationPermission() !=
        NotificationPermission.granted) {
      throw const HallFailure(
        'Allow study notifications, then retry the background timer.',
      );
    }
    if (await FlutterForegroundTask.isRunningService) {
      final id = await FlutterForegroundTask.getData<String>(
        key: 'hall-session',
      );
      final user = await FlutterForegroundTask.getData<String>(
        key: 'hall-user',
      );
      if (id == session.sessionId && user == session.userId) {
        return;
      }
      await _stop();
    }
    await FlutterForegroundTask.saveData(
      key: 'hall-user',
      value: session.userId,
    );
    await FlutterForegroundTask.saveData(
      key: 'hall-session',
      value: session.sessionId,
    );
    await FlutterForegroundTask.saveData(
      key: 'hall-app',
      value: firebaseAppName,
    );
    await FlutterForegroundTask.saveData(
      key: 'hall-emulator',
      value: emulatorHost,
    );
    final result = await FlutterForegroundTask.startService(
      serviceId: 301,
      serviceTypes: [ForegroundServiceTypes.specialUse],
      notificationTitle: 'StudyMates · Common Hall',
      notificationText: 'Starting your personal study timer…',
      notificationInitialRoute: '/common-hall',
      callback: hallTaskEntry,
    );
    if (result is ServiceRequestFailure) {
      throw const HallFailure(
        'The background timer could not start. Reopen Common Hall and retry.',
      );
    }
  }

  @override
  Future<void> stop() => _serialize(_stop);

  Future<void> _stop() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    if (await FlutterForegroundTask.isRunningService) {
      final result = await FlutterForegroundTask.stopService();
      if (result is ServiceRequestFailure) {
        throw const HallFailure(
          'Could not stop the study notification. Please retry.',
        );
      }
    }
  }

  @override
  VoidCallback listenForOpen(
    VoidCallback onOpen, {
    required VoidCallback onInterrupted,
  }) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return () {};
    }
    FlutterForegroundTask.initCommunicationPort();
    void receive(Object data) {
      if (data == 'open-common-hall') onOpen();
      if (data == 'hall-interrupted') onInterrupted();
    }

    FlutterForegroundTask.addTaskDataCallback(receive);
    return () => FlutterForegroundTask.removeTaskDataCallback(receive);
  }
}

@pragma('vm:entry-point')
void hallTaskEntry() =>
    FlutterForegroundTask.setTaskHandler(_HallTaskHandler());

/// This isolate continues while Android's activity is paused/locked. It uses
/// the same authenticated Firebase app; no tokens or goals go into preferences.
class _HallTaskHandler extends TaskHandler {
  FirestoreCommonHallRepository? _repository;
  FirebaseAuth? _auth;
  HallSession? _session;
  String? _expectedUser, _expectedId;
  DateTime? _lastRenewal;
  bool _busy = false, _closed = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    try {
      _expectedUser = await FlutterForegroundTask.getData<String>(
        key: 'hall-user',
      );
      _expectedId = await FlutterForegroundTask.getData<String>(
        key: 'hall-session',
      );
      final name =
          await FlutterForegroundTask.getData<String>(key: 'hall-app') ??
          '[DEFAULT]';
      final host =
          await FlutterForegroundTask.getData<String>(key: 'hall-emulator') ??
          '';
      final app = await Firebase.initializeApp(
        name: name == '[DEFAULT]' ? null : name,
        options: DefaultFirebaseOptions.android,
      );
      final auth = FirebaseAuth.instanceFor(app: app);
      _auth = auth;
      final db = FirebaseFirestore.instanceFor(app: app);
      if (host.isNotEmpty) {
        await auth.useAuthEmulator(host, 9099, automaticHostMapping: false);
        db.settings = const Settings(persistenceEnabled: false);
        db.useFirestoreEmulator(host, 8080, automaticHostMapping: false);
      }
      final user =
          auth.currentUser ??
          await auth.authStateChanges().first.timeout(
            const Duration(seconds: 15),
          );
      if (user?.uid != _expectedUser || _expectedId == null) {
        await _stopIfCurrent();
        return;
      }
      _repository = FirestoreCommonHallRepository(
        db: db,
        currentUid: () => auth.currentUser?.uid,
      );
      _session = await _repository!.getCurrentSession();
      if (_session?.sessionId != _expectedId) {
        await _stopIfCurrent();
        return;
      }
      await _renew(timestamp);
    } catch (_) {
      await _interrupted();
    }
  }

  Future<void> _stopIfCurrent() async {
    if (await FlutterForegroundTask.getData<String>(key: 'hall-session') ==
        _expectedId) {
      await FlutterForegroundTask.stopService();
    }
  }

  Future<void> _interrupted() async {
    if (_closed) return;
    await FlutterForegroundTask.updateService(
      notificationTitle: 'Common Hall connection interrupted',
      notificationText: 'Open StudyMates to save confirmed time and continue.',
    );
    FlutterForegroundTask.sendDataToMain('hall-interrupted');
    // Expired sessions cannot be revived across an unverified offline gap.
    if (_session == null || !_session!.isLive(DateTime.now())) {
      await _stopIfCurrent();
    }
  }

  Future<void> _renew(DateTime now) async {
    if (_busy || _closed || _repository == null) return;
    _busy = true;
    // Bound retries as well as successful heartbeats; a fast permission/network
    // failure must not turn the one-second display tick into database polling.
    _lastRenewal = now;
    try {
      _session = await _repository!.renew(_expectedId!);
    } catch (_) {
      await _interrupted();
    } finally {
      _busy = false;
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    if (_closed || _repository == null || _session == null) return;
    if (_auth?.currentUser?.uid != _expectedUser) {
      unawaited(_stopIfCurrent());
      return;
    }
    final session = _session!;
    if (!session.isLive(timestamp)) {
      unawaited(_interrupted());
      return;
    }
    if (_lastRenewal == null ||
        timestamp.difference(_lastRenewal!).inSeconds >= 60) {
      unawaited(_renew(timestamp));
    }
    final timing = HallTiming(startsAt: session.startsAt, now: timestamp);
    final remaining =
        '${timing.remainingSeconds ~/ 60}:${(timing.remainingSeconds % 60).toString().padLeft(2, '0')}';
    unawaited(
      FlutterForegroundTask.updateService(
        notificationTitle:
            'Common Hall · ${timing.isBreak ? 'Break' : 'Focus'} $remaining',
        notificationText:
            'Cycle ${timing.completedCycles + 1} · ${timing.creditedSeconds ~/ 60} min focus · Tap to return',
      ),
    );
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _closed = true;
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.sendDataToMain('open-common-hall');
    FlutterForegroundTask.launchApp('/common-hall');
  }
}
