import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:studymates/core/models/completion_record.dart';
import 'package:studymates/core/theme/app_theme.dart';
import 'package:studymates/features/common_hall/data/firestore_common_hall_repository.dart';
import 'package:studymates/features/common_hall/data/hall_background_service.dart';
import 'package:studymates/features/notifications/data/local_notification_transport.dart';
import 'package:studymates/features/notifications/data/study_notification_service.dart';
import 'package:studymates/features/notifications/domain/study_notification.dart';
import 'package:studymates/firebase_options.dart';

import 'common_hall_test.dart' as local;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android background phase alerts, recovery, preferences and account cancellation',
    (tester) async {
      Future<void> requireForeground() async {
        final deadline = DateTime.now().add(const Duration(seconds: 45));
        while (WidgetsBinding.instance.lifecycleState !=
            AppLifecycleState.resumed) {
          if (DateTime.now().isAfter(deadline)) {
            fail(
              'Unlock the phone and foreground StudyMates before starting a fresh timer.',
            );
          }
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
      }

      const host = String.fromEnvironment('STUDYMATES_EMULATOR_HOST');
      if (host != '127.0.0.1') {
        throw StateError('Use loopback emulators and adb reverse');
      }
      final suffix = DateTime.now().microsecondsSinceEpoch;
      final app = await Firebase.initializeApp(
        name: 'notification-test-$suffix',
        options: DefaultFirebaseOptions.currentPlatform,
      );
      final auth = FirebaseAuth.instanceFor(app: app);
      await auth.useAuthEmulator(host, 9099, automaticHostMapping: false);
      final db = FirebaseFirestore.instanceFor(app: app);
      db.settings = const Settings(persistenceEnabled: false);
      db.useFirestoreEmulator(host, 8080, automaticHostMapping: false);
      await auth.createUserWithEmailAndPassword(
        email: 'notification-$suffix@example.test',
        password: 'notification-test-password',
      );
      final uid = auth.currentUser!.uid;
      await db.doc('users/$uid').set({
        'displayName': 'Notification test learner',
        'avatarId': 'default',
      });
      final repository = FirestoreCommonHallRepository(
        db: db,
        currentUid: () => auth.currentUser?.uid,
      );
      final service = StudyNotificationService.android();
      final transport = service.transport as AndroidNotificationTransport;
      final previousOwner = await service.store.owner();
      final background = AndroidHallBackgroundService(
        firebaseAppName: app.name,
        emulatorHost: host,
      );
      Future<void> seed(String id, int elapsed, {bool expired = false}) async {
        final confirmed = DateTime.now().toUtc().subtract(
          expired ? const Duration(seconds: 181) : Duration.zero,
        );
        final start = confirmed.subtract(Duration(seconds: elapsed));
        await local.fixture('users/$uid/hallSession/current', {
          'userId': uid,
          'sessionId': id,
          'goalText': 'Private test goal',
          'startsAt': start,
          'confirmedAt': confirmed,
        });
        await local.fixture('commonHallPresence/$uid', {
          'userId': uid,
          'sessionId': id,
          'displayName': 'Notification test learner',
          'avatarId': 'default',
          'joinedAt': start,
          'lastSeenAt': confirmed,
        });
      }

      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(
              body: Center(
                child: Text('Checking StudyMates device notifications'),
              ),
            ),
          ),
        );
        await service.bindAccount(uid);
        await background.prepare();
        expect(await transport.permission(), isTrue);
        await service.saveSettings(
          uid,
          const NotificationPreferences(
            sound: false,
            vibration: false,
            dailyReminder: true,
            hour: 23,
            minute: 59,
          ),
        );
        expect(
          (await transport.plugin.pendingNotificationRequests()).any(
            (entry) => entry.id == AndroidNotificationTransport.reminderId,
          ),
          isTrue,
        );
        final entered = await repository.enter(goalText: 'Private test goal');
        await seed(entered.sessionId, 1490);
        await background.start((await repository.getCurrentSession())!);
        debugPrint('NOTIFICATION_LOCK_TEST_READY');
        await Future<void>.delayed(const Duration(seconds: 17));
        var items = await service.store.history(uid);
        expect(
          items
              .where((item) => item.alert.kind == StudyAlertKind.focusFinished)
              .length,
          1,
        );
        var active = await transport.plugin.getActiveNotifications();
        expect(
          active.any((item) => item.id == AndroidNotificationTransport.phaseId),
          isTrue,
        );
        expect(active.any((item) => item.id == 301), isTrue);
        debugPrint('NOTIFICATION_LOCK_FOCUS_PASSED');
        // Let the host wake and foreground the activity after the lock check.
        // Android requires a foreground user action for a fresh service start.
        await Future<void>.delayed(const Duration(seconds: 4));
        await requireForeground();
        final channels = await transport.plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()!
            .getNotificationChannels();
        final channel = channels!.singleWhere(
          (channel) => channel.id == 'studymates_alerts_silent_still',
        );
        expect(channel.playSound, isFalse);
        expect(channel.enableVibration, isFalse);
        await background.stop();
        await seed(entered.sessionId, 1790);
        await requireForeground();
        await background.start((await repository.getCurrentSession())!);
        await Future<void>.delayed(const Duration(seconds: 17));
        items = await service.store.history(uid);
        expect(
          items
              .where((item) => item.alert.kind == StudyAlertKind.focusFinished)
              .length,
          1,
        );
        expect(
          items
              .where((item) => item.alert.kind == StudyAlertKind.breakFinished)
              .length,
          1,
        );
        await background.stop();
        await seed(entered.sessionId, 1500, expired: true);
        await requireForeground();
        await background.start((await repository.getCurrentSession())!);
        await Future<void>.delayed(const Duration(seconds: 7));
        items = await service.store.history(uid);
        expect(
          items
              .where((item) => item.alert.kind == StudyAlertKind.recovery)
              .length,
          1,
        );
        active = await transport.plugin.getActiveNotifications();
        expect(
          active.any(
            (item) => item.id == AndroidNotificationTransport.recoveryId,
          ),
          isTrue,
        );
        expect(await FlutterForegroundTask.isRunningService, isFalse);
        final record = await repository.finish(
          expectedSessionId: entered.sessionId,
          goalOutcome: GoalOutcome.unfinished,
        );
        expect(record.creditedSeconds, 1500);
        await background.stop();
        active = await transport.plugin.getActiveNotifications();
        expect(
          active.any(
            (item) =>
                item.id == AndroidNotificationTransport.recoveryId ||
                item.id == AndroidNotificationTransport.phaseId,
          ),
          isFalse,
        );
        await service.test(uid);
        expect(
          (await transport.plugin.getActiveNotifications()).any(
            (item) => item.id == AndroidNotificationTransport.testId,
          ),
          isTrue,
        );
        await service.bindAccount('notification-second-$suffix');
        expect(await transport.plugin.pendingNotificationRequests(), isEmpty);
        expect(await transport.plugin.getActiveNotifications(), isEmpty);
        expect(
          await service.store.history('notification-second-$suffix'),
          isEmpty,
        );
        debugPrint('NOTIFICATION_ANDROID_CHECKS_PASSED');
      } finally {
        await background.stop();
        await service.bindAccount(previousOwner);
        await service.dispose();
        await auth.signOut();
        await db.terminate();
        await app.delete();
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
