import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:studymates/app/app_mode.dart';
import 'package:studymates/core/models/completion_record.dart';
import 'package:studymates/core/theme/app_theme.dart';
import 'package:studymates/features/auth/domain/auth_state.dart';
import 'package:studymates/features/auth/presentation/controllers/auth_providers.dart';
import 'package:studymates/features/common_hall/data/firestore_common_hall_repository.dart';
import 'package:studymates/features/common_hall/data/hall_background_service.dart';
import 'package:studymates/features/common_hall/presentation/common_hall_providers.dart';
import 'package:studymates/features/common_hall/presentation/common_hall_screen.dart';
import 'package:studymates/features/communities/data/firestore_membership_repository.dart';
import 'package:studymates/features/study/data/firestore_study_repository.dart';
import 'package:studymates/firebase_options.dart';

class _Identity extends AuthStateController {
  _Identity(this.uid);
  final String uid;
  @override
  AuthState build() =>
      AuthState.ready(userId: uid, displayName: 'Hall test learner');
}

// Admin fixtures are restricted to the loopback emulator, never a live project.
Future<void> fixture(String path, Map<String, dynamic> values) async {
  const host = String.fromEnvironment('STUDYMATES_EMULATOR_HOST');
  if (host != '127.0.0.1' && host != 'localhost') {
    throw StateError('Loopback only');
  }
  final client = HttpClient();
  try {
    final request = await client.patchUrl(
      Uri.parse(
        'http://$host:8080/v1/projects/studymates-dev/databases/(default)/documents/$path',
      ),
    );
    request.headers.set('Authorization', 'Bearer owner');
    request.headers.contentType = ContentType.json;
    request.write(
      jsonEncode({
        'fields': values.map(
          (key, value) => MapEntry(
            key,
            value is DateTime
                ? {'timestampValue': value.toUtc().toIso8601String()}
                : value is bool
                ? {'booleanValue': value}
                : value is int
                ? {'integerValue': '$value'}
                : {'stringValue': value},
          ),
        ),
      }),
    );
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    expect(response.statusCode, 200, reason: body);
  } finally {
    client.close();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'shared hall, locked-screen heartbeat, unique save and combined Progress',
    (tester) async {
      const host = String.fromEnvironment('STUDYMATES_EMULATOR_HOST');
      if (host != '127.0.0.1') {
        throw StateError('Use adb reverse with local emulators');
      }
      final suffix = DateTime.now().microsecondsSinceEpoch;
      final apps = <FirebaseApp>[];
      final identities = <FirebaseAuth>[];
      final databases = <FirebaseFirestore>[];
      for (var i = 0; i < 2; i++) {
        final app = await Firebase.initializeApp(
          name: 'hall-test-$suffix-$i',
          options: DefaultFirebaseOptions.currentPlatform,
        );
        final auth = FirebaseAuth.instanceFor(app: app);
        await auth.useAuthEmulator(host, 9099, automaticHostMapping: false);
        final db = FirebaseFirestore.instanceFor(app: app);
        db.settings = const Settings(persistenceEnabled: false);
        db.useFirestoreEmulator(host, 8080, automaticHostMapping: false);
        await auth.createUserWithEmailAndPassword(
          email: 'hall-$suffix-$i@example.test',
          password: 'hall-native-test',
        );
        await db.doc('users/${auth.currentUser!.uid}').set({
          'displayName': 'Hall test learner $i',
          'avatarId': 'default',
        });
        apps.add(app);
        identities.add(auth);
        databases.add(db);
      }
      final uid = identities.first.currentUser!.uid;
      final repository = FirestoreCommonHallRepository(
        db: databases.first,
        currentUid: () => identities.first.currentUser?.uid,
      );
      final other = FirestoreCommonHallRepository(
        db: databases.last,
        currentUid: () => identities.last.currentUser?.uid,
      );
      final background = AndroidHallBackgroundService(
        firebaseAppName: apps.first.name,
        emulatorHost: host,
      );
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appModeProvider.overrideWithValue(AppMode.connected),
              authStateProvider.overrideWith(() => _Identity(uid)),
              commonHallRepositoryProvider.overrideWithValue(repository),
              hallBackgroundServiceProvider.overrideWithValue(background),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              home: const Scaffold(body: SafeArea(child: CommonHallScreen())),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await background.prepare();
        final first = await repository.enter(goalText: 'Read independently');
        final duplicate = await repository.enter(goalText: 'Do not reset');
        expect(duplicate.sessionId, first.sessionId);
        expect(duplicate.startsAt, first.startsAt);
        final second = await other.enter(goalText: 'Another learner');
        final participants = await repository.watchParticipants().firstWhere(
          (people) => people.any((p) => p.userId == second.userId),
        );
        expect(participants.where((p) => p.userId == uid).length, 1);
        await expectLater(
          databases.last
              .doc('users/$uid/hallSession/current')
              .get(const GetOptions(source: Source.server)),
          throwsA(
            isA<FirebaseException>().having(
              (e) => e.code,
              'code',
              'permission-denied',
            ),
          ),
        );
        // Create a realistic two-hour focus fixture and a separate one-hour room
        // completion; the normal Progress reader must combine them unchanged.
        final confirmed = DateTime.now().toUtc();
        final started = confirmed.subtract(const Duration(seconds: 8400));
        await fixture('users/$uid/hallSession/current', {
          'userId': uid,
          'sessionId': first.sessionId,
          'goalText': first.goalText,
          'startsAt': started,
          'confirmedAt': confirmed,
        });
        await fixture('commonHallPresence/$uid', {
          'userId': uid,
          'sessionId': first.sessionId,
          'displayName': 'Hall test learner 0',
          'avatarId': 'default',
          'joinedAt': started,
          'lastSeenAt': confirmed,
        });
        await fixture('users/$uid/completions/room-history', {
          'recordId': 'room-history',
          'userId': uid,
          'sessionId': 'room-history',
          'goalText': 'Room focus',
          'endedAt': confirmed,
          'creditedSeconds': 3600,
          'timerStatus': 'completed',
          'goalOutcome': 'completed',
          'isDemo': false,
        });
        final current = (await repository.getCurrentSession())!;
        await background.start(current);
        await tester.pumpAndSettle();
        expect(await FlutterForegroundTask.isRunningService, isTrue);
        debugPrint('HALL_LOCK_TEST_READY uid=$uid session=${first.sessionId}');
        // The host locks the phone after the marker. This wait deliberately uses
        // wall time so the separate Android task must renew while the UI is paused.
        await Future<void>.delayed(const Duration(seconds: 75));
        final renewed = (await repository.getCurrentSession())!;
        expect(
          renewed.confirmedAt.difference(current.confirmedAt).inSeconds,
          greaterThanOrEqualTo(55),
        );
        expect(renewed.startsAt, current.startsAt);
        debugPrint('HALL_LOCK_HEARTBEAT_PASSED');
        final saved = await repository.finish(
          expectedSessionId: first.sessionId,
          goalOutcome: GoalOutcome.unfinished,
        );
        final again = await repository.finish(
          expectedSessionId: first.sessionId,
          goalOutcome: GoalOutcome.completed,
        );
        expect(again.recordId, saved.recordId);
        expect(again.goalOutcome, GoalOutcome.unfinished);
        expect(saved.creditedSeconds, inInclusiveRange(7200, 7350));
        expect(saved.isDemo, isFalse);
        expect(await repository.getCurrentSession(), isNull);
        final remaining = await other.watchParticipants().first;
        expect(remaining.any((p) => p.userId == uid), isFalse);
        final study = FirestoreStudyRepository(
          db: databases.first,
          membership: FirestoreMembershipRepository(
            firestore: databases.first,
            currentUserId: () => uid,
          ),
          currentUid: () => uid,
        );
        final summary = await study.loadCurrentUserSummary();
        expect(summary.creditedSeconds, 3600 + saved.creditedSeconds);
        expect(summary.completedSessionCount, 2);
        final history = await study.loadCurrentUserHistoryPage();
        expect(history.records.map((r) => r.recordId).toSet(), {
          first.sessionId,
          'room-history',
        });
        await background.stop();
        expect(await FlutterForegroundTask.isRunningService, isFalse);
        await other.finish(
          expectedSessionId: second.sessionId,
          goalOutcome: GoalOutcome.completed,
        );
        debugPrint(
          'HALL_ANDROID_CHECKS_PASSED focusSeconds=${saved.creditedSeconds} combinedSeconds=${summary.creditedSeconds}',
        );
      } finally {
        await background.stop();
        await tester.pumpWidget(const SizedBox.shrink());
        for (var i = 0; i < apps.length; i++) {
          await identities[i].signOut();
          await databases[i].terminate();
          await apps[i].delete();
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
