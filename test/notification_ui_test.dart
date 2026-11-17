import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:studymates/app/app.dart';
import 'package:studymates/app/app_mode.dart';
import 'package:studymates/app/router.dart';
import 'package:studymates/app/notification_coordinator.dart';
import 'package:studymates/features/common_hall/data/common_hall_repository.dart';
import 'package:studymates/features/common_hall/domain/common_hall_models.dart';
import 'package:studymates/features/common_hall/presentation/common_hall_providers.dart';
import 'package:studymates/features/notifications/data/study_notification_service.dart';
import 'package:studymates/features/notifications/domain/study_notification.dart';
import 'package:studymates/features/notifications/presentation/notification_providers.dart';
import 'package:studymates/features/notifications/presentation/notification_screens.dart';
import 'package:studymates/preview/preview_scope.dart';

import 'support/notification_fakes.dart';

class _Hall extends Fake implements CommonHallRepository {
  HallSession? active;
  bool failed = false;
  int reads = 0;
  @override
  Future<HallSession?> getCurrentSession() async {
    reads++;
    if (failed) throw StateError('offline');
    return active;
  }
}

void main() {
  Future<ProviderContainer> mount(
    WidgetTester tester,
    StudyNotificationService service, {
    bool narrow = false,
  }) async {
    if (narrow) {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }
    await tester.pumpWidget(
      PreviewScope(
        child: ProviderScope(
          overrides: [notificationServiceProvider.overrideWithValue(service)],
          child: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(narrow ? 2 : 1)),
            child: const StudyMatesApp(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(StudyMatesApp)),
    );
    addTearDown(service.dispose);
    return container;
  }

  Future<void> open(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'bell sits immediately right of QR; unread alerts, read action and settings use existing routes',
    (tester) async {
      final service = testNotificationService(preview: true);
      final container = await mount(tester, service);
      expect(
        tester.getCenter(find.byTooltip('Notifications')).dx,
        greaterThan(tester.getCenter(find.byTooltip('Scanner preview')).dx),
      );
      expect(
        tester.getSize(find.byTooltip('Notifications')).width,
        greaterThanOrEqualTo(48),
      );
      await service.publish(
        StudyAlert(
          id: 'one',
          userId: 'notification-preview',
          kind: StudyAlertKind.focusFinished,
          at: DateTime.now(),
          sessionId: 'hall-one',
        ),
      );
      await tester.pumpAndSettle();
      expect(
        container.read(notificationSnapshotProvider).asData!.value.unread,
        1,
      );
      await open(tester, find.byTooltip('Notifications'));
      expect(find.text('Time for a break'), findsOneWidget);
      await open(tester, find.text('Mark all read'));
      expect(
        container.read(notificationSnapshotProvider).asData!.value.unread,
        0,
      );
      await open(tester, find.byTooltip('Notification settings'));
      expect(find.byType(NotificationSettingsScreen), findsOneWidget);
      await tester.scrollUntilVisible(
        find.widgetWithText(SwitchListTile, 'Sound'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(NotificationSettingsScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await open(tester, find.widgetWithText(SwitchListTile, 'Sound'));
      expect(
        (await service.store.preferences('notification-preview')).sound,
        isFalse,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'settings and long alert rows scroll at 320px with 200 percent text',
    (tester) async {
      final service = testNotificationService(preview: true);
      final container = await mount(tester, service, narrow: true);
      container.read(appRouterProvider).go('/notification-settings');
      await tester.pumpAndSettle();
      final list = find
          .descendant(
            of: find.byType(NotificationSettingsScreen),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('Add preview notification'),
        250,
        scrollable: list,
      );
      await tester.tap(find.text('Add preview notification'));
      await tester.pumpAndSettle();
      expect((await service.store.history('notification-preview')).length, 1);
      ScaffoldMessenger.of(
        tester.element(find.byType(NotificationSettingsScreen)),
      ).clearSnackBars();
      await tester.pumpAndSettle();
      container.read(appRouterProvider).go('/notifications');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('StudyMates notifications are ready'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(NotificationInboxScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('StudyMates notifications are ready'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'daily reminder is opt-in and stores the selected device-local time',
    (tester) async {
      final service = testNotificationService(preview: true);
      final container = await mount(tester, service);
      container.read(appRouterProvider).go('/notification-settings');
      await tester.pumpAndSettle();
      expect(find.text('Reminder time'), findsNothing);
      await open(
        tester,
        find.widgetWithText(SwitchListTile, 'Remind me to study'),
      );
      expect(
        (await service.store.preferences('notification-preview')).dailyReminder,
        isTrue,
      );
      await container
          .read(notificationSnapshotProvider.notifier)
          .settings(
            const NotificationPreferences(
              dailyReminder: true,
              hour: 20,
              minute: 15,
            ),
          );
      await tester.pumpAndSettle();
      expect(find.textContaining('8:15'), findsOneWidget);
      await open(
        tester,
        find.widgetWithText(SwitchListTile, 'Remind me to study'),
      );
      expect(
        (await service.store.preferences('notification-preview')).dailyReminder,
        isFalse,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('blocked notification permission explains Android recovery', (
    tester,
  ) async {
    final transport = TestNotificationTransport()..granted = false;
    final service = testNotificationService(transport: transport);
    final container = await mount(tester, service);
    container.read(appRouterProvider).go('/notification-settings');
    await tester.pumpAndSettle();
    await open(tester, find.text('Allow notifications'));
    expect(find.textContaining('Notifications are blocked.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'notification taps revalidate session, reject another account, and show ended/offline recovery',
    (tester) async {
      final service = testNotificationService();
      final hall = _Hall()
        ..active = HallSession(
          userId: 'one',
          sessionId: 'hall-one',
          goalText: 'Read',
          startsAt: DateTime.now(),
          confirmedAt: DateTime.now(),
        );
      final router = createAppRouter(mode: AppMode.preview);
      final container = ProviderContainer(
        overrides: [
          appModeProvider.overrideWithValue(AppMode.connected),
          notificationUserProvider.overrideWithValue('one'),
          notificationServiceProvider.overrideWithValue(service),
          appRouterProvider.overrideWithValue(router),
          commonHallRepositoryProvider.overrideWithValue(hall),
        ],
      );
      final coordinator = container.listen(
        notificationCoordinatorProvider,
        (_, _) {},
      );
      await tester.pumpAndSettle();
      StudyAlert alert({String uid = 'one'}) => StudyAlert(
        id: 'phase',
        userId: uid,
        kind: StudyAlertKind.focusFinished,
        at: DateTime.now(),
        sessionId: 'hall-one',
      );
      service.taps.add(alert(uid: 'other'));
      await tester.pumpAndSettle();
      expect(hall.reads, 0);
      service.taps.add(alert());
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/common-hall');
      hall.active = null;
      service.taps.add(alert());
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/notifications');
      expect(container.read(notificationNoticeProvider), contains('has ended'));
      hall.failed = true;
      service.taps.add(alert());
      await tester.pumpAndSettle();
      expect(container.read(notificationNoticeProvider), contains('Reconnect'));
      coordinator.close();
      container.dispose();
      router.dispose();
      await service.dispose();
    },
  );
}
