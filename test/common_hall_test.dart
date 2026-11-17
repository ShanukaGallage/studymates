import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:studymates/app/app.dart';
import 'package:studymates/app/app_mode.dart';
import 'package:studymates/app/common_hall_coordinator.dart';
import 'package:studymates/app/router.dart';
import 'package:studymates/core/models/completion_record.dart';
import 'package:studymates/core/theme/app_theme.dart';
import 'package:studymates/features/auth/domain/auth_state.dart';
import 'package:studymates/features/auth/presentation/controllers/auth_providers.dart';
import 'package:studymates/features/common_hall/data/common_hall_repository.dart';
import 'package:studymates/features/common_hall/data/hall_background_service.dart';
import 'package:studymates/features/common_hall/domain/common_hall_models.dart';
import 'package:studymates/features/common_hall/presentation/common_hall_providers.dart';
import 'package:studymates/features/common_hall/presentation/common_hall_screen.dart';
import 'package:studymates/preview/preview_scope.dart';
import 'package:studymates/features/progress/presentation/controllers/progress_history_controller.dart';
import 'package:studymates/features/sessions/data/completion_history_repository.dart';

class _Identity extends AuthStateController {
  @override
  AuthState build() =>
      const AuthState.ready(userId: 'one', displayName: 'Learner');
  void change(String id) =>
      state = AuthState.ready(userId: id, displayName: id);
}

class _Background implements HallBackgroundService {
  int prepared = 0, started = 0, stopped = 0;
  bool denied = false, failedStart = false;
  VoidCallback? openHall;
  @override
  Future<void> prepare() async {
    prepared++;
    if (denied) throw const HallFailure('Allow notifications to study.');
  }

  @override
  Future<void> start(HallSession session) async {
    started++;
    if (failedStart) throw const HallFailure('Background timer failed.');
  }

  @override
  Future<void> stop() async {
    stopped++;
  }

  @override
  VoidCallback listenForOpen(
    VoidCallback onOpen, {
    required VoidCallback onInterrupted,
  }) {
    openHall = onOpen;
    return () => openHall = null;
  }
}

HallSession session({String user = 'one', int age = 0}) {
  final now = DateTime.now().toUtc();
  return HallSession(
    userId: user,
    sessionId: 'hall-one',
    goalText: 'Self study',
    startsAt: now.subtract(const Duration(minutes: 30)),
    confirmedAt: now.subtract(Duration(seconds: age)),
  );
}

HallParticipant person(int i, {int age = 0}) => HallParticipant(
  userId: i == 0 ? 'one' : 'learner-$i',
  sessionId: 'hall-$i',
  displayName: 'Learner $i with a long name that wraps',
  avatarId: 'default',
  joinedAt: DateTime.now().subtract(const Duration(minutes: 3)),
  lastSeenAt: DateTime.now().subtract(Duration(seconds: age)),
);

class _Hall implements CommonHallRepository {
  HallSession? active;
  List<HallParticipant> people = [];
  final changes = StreamController<HallSession?>.broadcast();
  final desks = StreamController<List<HallParticipant>>.broadcast();
  int entered = 0, finished = 0;
  GoalOutcome? outcome;
  @override
  Stream<HallSession?> watchCurrentSession() async* {
    yield active;
    yield* changes.stream;
  }

  @override
  Stream<List<HallParticipant>> watchParticipants() async* {
    yield people;
    yield* desks.stream;
  }

  @override
  Future<HallSession?> getCurrentSession() async => active;
  @override
  Future<HallSession> enter({required String goalText}) async {
    entered++;
    active = session();
    changes.add(active);
    people = [person(0)];
    desks.add(people);
    return active!;
  }

  @override
  Future<HallSession> renew(String expectedSessionId) async => active!;
  @override
  Future<CompletionRecord> finish({
    required String expectedSessionId,
    required GoalOutcome goalOutcome,
  }) async {
    finished++;
    outcome = goalOutcome;
    active = null;
    changes.add(null);
    people = [];
    desks.add(people);
    return CompletionRecord(
      recordId: expectedSessionId,
      userId: 'one',
      sessionId: expectedSessionId,
      goalText: 'Self study',
      endedAt: DateTime.now(),
      creditedSeconds: 1500,
      timerStatus: TimerCompletionStatus.completed,
      goalOutcome: goalOutcome,
      isDemo: false,
    );
  }

  Future<void> dispose() async {
    await changes.close();
    await desks.close();
  }
}

class _History implements CompletionHistoryRepository {
  int seconds = 0;
  @override
  Future<CompletionHistorySummary> loadCurrentUserSummary() async =>
      CompletionHistorySummary(
        creditedSeconds: seconds,
        completedSessionCount: seconds == 0 ? 0 : 1,
      );
  @override
  Future<CompletionHistoryPage> loadCurrentUserHistoryPage({
    String? pageToken,
  }) async => CompletionHistoryPage(records: []);
}

void main() {
  test('personal 25/5 timing excludes breaks across repeated cycles', () {
    for (final sample in [
      (0, 0, false, 1500, 0),
      (1499, 1499, false, 1, 0),
      (1500, 1500, true, 300, 0),
      (1799, 1500, true, 1, 0),
      (1800, 1500, false, 1500, 1),
      (8400, 7200, false, 300, 4),
      (-10, 0, false, 1500, 0),
    ]) {
      final time = HallTiming.elapsed(sample.$1);
      expect(
        (
          time.creditedSeconds,
          time.isBreak,
          time.remainingSeconds,
          time.completedCycles,
        ),
        (sample.$2, sample.$3, sample.$4, sample.$5),
        reason: '${sample.$1}s',
      );
    }
    final start = DateTime.utc(2026, 11, 17);
    expect(
      HallTiming(
        startsAt: start.toLocal(),
        now: start.add(const Duration(minutes: 30)),
      ).creditedSeconds,
      1500,
    );
    expect(session(age: 180).isLive(DateTime.now()), isFalse);
  });

  Future<ProviderContainer> mount(
    WidgetTester tester,
    _Hall hall,
    _Background background, {
    double scale = 1,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appModeProvider.overrideWithValue(AppMode.connected),
          authStateProvider.overrideWith(_Identity.new),
          commonHallRepositoryProvider.overrideWithValue(hall),
          hallBackgroundServiceProvider.overrideWithValue(background),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: const Scaffold(body: SafeArea(child: CommonHallScreen())),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(hall.dispose);
    return ProviderScope.containerOf(
      tester.element(find.byType(CommonHallScreen)),
    );
  }

  testWidgets(
    'permission denial creates no session; entry starts background timer and adds one desk; finish removes it',
    (tester) async {
      final hall = _Hall(), background = _Background()..denied = true;
      await mount(tester, hall, background);
      await tester.tap(find.text('Enter and start studying'));
      await tester.pumpAndSettle();
      expect(hall.entered, 0);
      expect(find.text('Allow notifications to study.'), findsOneWidget);
      background.denied = false;
      await tester.tap(find.text('Enter and start studying'));
      await tester.pumpAndSettle();
      expect(hall.entered, 1);
      expect(background.started, 1);
      expect(find.text('1 learner · 1 desk'), findsOneWidget);
      await tester.tap(find.text('Finish and leave'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Goal completed'));
      await tester.tap(find.widgetWithText(TextButton, 'Finish and leave'));
      await tester.pumpAndSettle();
      expect(hall.finished, 1);
      expect(hall.outcome, GoalOutcome.completed);
      expect(background.stopped, 1);
      expect(find.text('0h 25m 0s saved to Progress.'), findsOneWidget);
      expect(find.text('0 learners · 0 desks'), findsOneWidget);
      expect(find.byKey(const ValueKey('hall-countdown')), findsNothing);
    },
  );

  testWidgets(
    'background startup failure keeps a recoverable session and retry',
    (tester) async {
      final hall = _Hall(), background = _Background()..failedStart = true;
      await mount(tester, hall, background);
      await tester.tap(find.text('Enter and start studying'));
      await tester.pumpAndSettle();
      expect(hall.active, isNotNull);
      expect(find.text('Retry background timer'), findsOneWidget);
      background.failedStart = false;
      await tester.tap(find.text('Retry background timer'));
      await tester.pumpAndSettle();
      expect(background.started, 2);
      expect(find.text('Retry background timer'), findsNothing);
    },
  );

  testWidgets('33 dynamic desks, expiry and narrow large-text scrolling', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final hall = _Hall()
      ..people = [...List.generate(33, person), person(99, age: 181)];
    await mount(tester, hall, _Background(), scale: 2);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('hall-desk-count')),
      250,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('33 learners · 33 desks'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('hall-desk-learner-32')),
      400,
      maxScrolls: 150,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.byKey(const ValueKey('hall-desk-learner-32')), findsOneWidget);
    expect(find.byKey(const ValueKey('hall-desk-learner-99')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'expired session displays only confirmed time and allows saving',
    (tester) async {
      final hall = _Hall()..active = session(age: 181);
      await mount(tester, hall, _Background());
      expect(find.text('Connection ended'), findsOneWidget);
      expect(find.text('Retry background timer'), findsNothing);
      await tester.tap(find.text('Finish and leave'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Finish and leave'));
      await tester.pumpAndSettle();
      expect(hall.outcome, GoalOutcome.unfinished);
      expect(find.byKey(const ValueKey('hall-saved')), findsOneWidget);
    },
  );

  testWidgets(
    'plus chooser opens hall without Firebase in preview and rooms keeps Discover selected',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const PreviewScope(
          child: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2)),
            child: StudyMatesApp(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(StudyMatesApp)),
      );
      await tester.tap(find.byTooltip('Start studying'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('study-choice-hall')),
      );
      await tester.tap(find.byKey(const ValueKey('study-choice-hall')));
      await tester.pumpAndSettle();
      expect(
        container
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .path,
        '/common-hall',
      );
      expect(find.textContaining('signed-in Android app'), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0,
      );
      await tester.tap(find.byTooltip('Start studying'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('study-choice-room')),
      );
      await tester.tap(find.byKey(const ValueKey('study-choice-room')));
      await tester.pumpAndSettle();
      expect(
        container
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .path,
        '/discover',
      );
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'session ending outside the hall screen refreshes cached Progress',
    (tester) async {
      final hall = _Hall()..active = session();
      final background = _Background(), history = _History();
      final router = createAppRouter(mode: AppMode.preview);
      final container = ProviderContainer(
        overrides: [
          appModeProvider.overrideWithValue(AppMode.connected),
          authStateProvider.overrideWith(_Identity.new),
          commonHallRepositoryProvider.overrideWithValue(hall),
          hallBackgroundServiceProvider.overrideWithValue(background),
          progressHistoryRepositoryProvider.overrideWithValue(history),
          appRouterProvider.overrideWithValue(router),
        ],
      );
      final subscription = container.listen(progressHistoryProvider, (_, _) {});
      final coordinator = container.listen(
        commonHallCoordinatorProvider,
        (_, _) {},
      );
      await tester.pumpAndSettle();
      expect(
        container.read(commonHallSessionProvider).asData?.value,
        isNotNull,
      );
      background.openHall!();
      expect(router.routeInformationProvider.value.uri.path, '/common-hall');
      expect(
        (await container.read(progressHistoryProvider.future))
            .summary
            .creditedSeconds,
        0,
      );
      history.seconds = 1500;
      await hall.finish(
        expectedSessionId: 'hall-one',
        goalOutcome: GoalOutcome.unfinished,
      );
      await tester.pumpAndSettle();
      expect(container.read(commonHallSessionProvider).asData?.value, isNull);
      expect(
        (await container.read(progressHistoryProvider.future))
            .summary
            .creditedSeconds,
        1500,
      );
      expect(background.stopped, greaterThanOrEqualTo(1));
      subscription.close();
      coordinator.close();
      container.dispose();
      router.dispose();
      await hall.dispose();
    },
  );

  test(
    'account change cannot retain another user’s private hall session',
    () async {
      final hall = _Hall()..active = session();
      final container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith(_Identity.new),
          commonHallRepositoryProvider.overrideWithValue(hall),
        ],
      );
      final subscription = container.listen(
        commonHallSessionProvider,
        (_, _) {},
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(commonHallSessionProvider).asData?.value?.userId,
        'one',
      );
      (container.read(authStateProvider.notifier) as _Identity).change('two');
      await Future<void>.delayed(Duration.zero);
      expect(container.read(commonHallSessionProvider).asData?.value, isNull);
      subscription.close();
      container.dispose();
      await hall.dispose();
    },
  );
}
