import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:studymates/core/models/active_room_session.dart';
import 'package:studymates/preview/active_session_fixtures.dart';

void main() {
  group('FixtureActiveSessionRepository', () {
    late FixtureActiveSessionRepository repository;

    setUp(() {
      repository = FixtureActiveSessionRepository(
        currentUserId: 'preview-user-1',
        sessionsByUser: {
          'preview-user-1': ActiveSessionFixtures.validActiveSession,
          'preview-user-2': ActiveSessionFixtures.otherUserActiveSession,
          'empty-user': ActiveSessionFixtures.noActiveSession,
        },
      );
    });

    tearDown(() => repository.dispose());

    test('emits the current authenticated user session', () async {
      await expectLater(
        repository.watchCurrentUserActiveSession(),
        emits(ActiveSessionFixtures.validActiveSession),
      );
    });

    test('null event confirms no active session', () async {
      repository.switchUserForTest('empty-user');

      await expectLater(
        repository.watchCurrentUserActiveSession(),
        emits(ActiveSessionFixtures.noActiveSession),
      );
    });

    test('forwards lookup failure as a stream error', () async {
      repository.failForTest('preview-user-1', StateError('lookup failed'));

      await expectLater(
        repository.watchCurrentUserActiveSession(),
        emitsError(isA<StateError>()),
      );
    });

    test('switching accounts prevents old-user updates from leaking', () async {
      final events = <ActiveRoomSession?>[];
      final reachedOtherUser = Completer<void>();
      final subscription = repository
          .watchCurrentUserActiveSession()
          .listen((session) {
            events.add(session);
            if (session?.userId == 'preview-user-2' &&
                !reachedOtherUser.isCompleted) {
              reachedOtherUser.complete();
            }
          });
      addTearDown(subscription.cancel);

      await Future<void>.delayed(Duration.zero);
      repository.switchUserForTest('preview-user-2');
      await reachedOtherUser.future.timeout(const Duration(seconds: 1));
      repository.setSessionForTest(
        'preview-user-1',
        ActiveSessionFixtures.sessionRequiringRevalidation,
      );
      await Future<void>.delayed(Duration.zero);

      expect(events.map((session) => session?.userId), [
        'preview-user-1',
        'preview-user-2',
      ]);
    });
  });
}
