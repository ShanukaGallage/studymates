import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as zones;
import 'package:timezone/timezone.dart' as tz;
import 'package:studymates/features/common_hall/domain/common_hall_models.dart';
import 'package:studymates/features/notifications/data/local_notification_transport.dart';
import 'package:studymates/features/notifications/data/study_notification_service.dart';
import 'package:studymates/features/notifications/domain/study_notification.dart';

import 'support/notification_fakes.dart';

void main() {
  final start = DateTime.utc(2026, 11, 17);
  HallSession session(
    int elapsed, {
    String id = 'hall-one',
    String uid = 'one',
  }) => HallSession(
    userId: uid,
    sessionId: id,
    goalText: 'Private goal must not be in notifications',
    startsAt: start,
    confirmedAt: start.add(Duration(seconds: elapsed)),
  );
  StudyAlert alert(String id, {String uid = 'one', int seconds = 0}) =>
      StudyAlert(
        id: id,
        userId: uid,
        kind: StudyAlertKind.test,
        at: start.add(Duration(seconds: seconds)),
      );

  test(
    'one alert per phase, restart deduplication and no missed-cycle burst',
    () async {
      final transport = TestNotificationTransport(),
          service = testNotificationService();
      final active = StudyNotificationService(
        store: service.store,
        transport: transport,
      );
      await active.bindAccount('one');
      var engine = HallNotificationEngine(active);
      for (final seconds in [0, 1499, 1500, 1500]) {
        await engine.tick(
          session(seconds),
          start.add(Duration(seconds: seconds)),
        );
      }
      expect(transport.shown.map((a) => a.kind), [
        StudyAlertKind.focusFinished,
      ]);
      engine = HallNotificationEngine(active);
      await engine.tick(
        session(1501),
        start.add(const Duration(seconds: 1501)),
      );
      expect(transport.shown.length, 1);
      await engine.tick(
        session(1800),
        start.add(const Duration(seconds: 1800)),
      );
      expect(transport.shown.last.kind, StudyAlertKind.breakFinished);
      await engine.tick(
        session(8400),
        start.add(const Duration(seconds: 8400)),
      );
      expect(transport.shown.length, 3);
      expect(
        transport.shown.every((a) => !a.encode().contains('Private goal')),
        isTrue,
      );
      expect((await active.store.history('one')).length, 3);
      await active.dispose();
      await service.dispose();
    },
  );
  test(
    'first open in an existing phase does not claim old cycles as new alerts',
    () async {
      final transport = TestNotificationTransport(),
          service = testNotificationService();
      final active = StudyNotificationService(
        store: service.store,
        transport: transport,
      );
      await active.bindAccount('one');
      await HallNotificationEngine(active)
          .tick(session(8500), start.add(const Duration(seconds: 8500)));
      expect(transport.shown, isEmpty);
      await active.dispose();
      await service.dispose();
    },
  );
  test(
    'preferences suppress cycle/recovery alerts without backfilling on enable',
    () async {
      final service = testNotificationService();
      await service.bindAccount('one');
      await service.saveSettings(
        'one',
        const NotificationPreferences(cycles: false, recovery: false),
      );
      final engine = HallNotificationEngine(service);
      await engine.tick(session(0), start);
      await engine.tick(
        session(1500),
        start.add(const Duration(seconds: 1500)),
      );
      await engine.interrupted('one', 'hall-one');
      expect(await service.store.history('one'), isEmpty);
      await service.saveSettings('one', const NotificationPreferences());
      await engine.tick(
        session(1501),
        start.add(const Duration(seconds: 1501)),
      );
      expect(await service.store.history('one'), isEmpty);
      await engine.tick(
        session(1800),
        start.add(const Duration(seconds: 1800)),
      );
      expect(
        (await service.store.history('one')).single.alert.kind,
        StudyAlertKind.breakFinished,
      );
      await service.dispose();
    },
  );
  test(
    'recovery alerts occur once and expired sessions cannot emit phase alerts',
    () async {
      final service = testNotificationService();
      await service.bindAccount('one');
      final engine = HallNotificationEngine(service);
      await engine.interrupted('one', 'hall-one');
      await engine.interrupted('one', 'hall-one');
      await engine.tick(session(0), start.add(const Duration(seconds: 1500)));
      expect((await service.store.history('one')).length, 1);
      expect(
        (await service.store.history('one')).single.alert.kind,
        StudyAlertKind.recovery,
      );
      await service.dispose();
    },
  );
  test(
    'blocked Android permission retains important alerts in local inbox only',
    () async {
      final transport = TestNotificationTransport()..granted = false;
      final service = testNotificationService(transport: transport);
      await service.bindAccount('one');
      await service.publish(alert('blocked'));
      expect(transport.shown, isEmpty);
      expect((await service.store.history('one')).length, 1);
      await expectLater(service.test('one'), throwsStateError);
      await service.dispose();
    },
  );
  test('account switch cancels delivered/reminder notifications and rejects stale worker events', () async {
    final transport = TestNotificationTransport(),
        service = testNotificationService();
    final active = StudyNotificationService(
      store: service.store,
      transport: transport,
    );
    await active.bindAccount('one');
    await active.saveSettings(
      'one',
      const NotificationPreferences(dailyReminder: true, hour: 20, minute: 30),
    );
    await active.publish(alert('old'));
    await active.bindAccount('two');
    expect(transport.shown, isEmpty);
    expect(transport.reminderUser, 'two');
    expect(transport.reminderSettings!.dailyReminder, isFalse);
    await active.publish(alert('stale'));
    expect((await active.store.history('one')).map((a) => a.alert.id), ['old']);
    expect(await active.store.history('two'), isEmpty);
    await active.bindAccount(null);
    expect(await active.store.owner(), isNull);
    expect(transport.reminderUser, isNull);
    await active.bindAccount('one');
    expect(transport.reminderSettings!.hour, 20);
    expect(transport.reminderSettings!.dailyReminder, isTrue);
    await active.dispose();
    await service.dispose();
  });
  test('history is bounded, newest first and read state is isolated by full account ID', () async {
    final service = testNotificationService();
    await service.bindAccount('one');
    await service.store.record(alert('other', uid: 'one.other'));
    for (var i = 0; i < 55; i++) {
      await service.store.record(alert('event-$i', seconds: i));
    }
    final items = await service.store.history('one');
    expect(items.length, 50);
    expect(items.first.alert.id, 'event-54');
    expect(items.last.alert.id, 'event-5');
    await service.store.markRead('one', 'event-54');
    expect((await service.store.history('one')).first.isRead, isTrue);
    expect((await service.store.history('one.other')).single.isRead, isFalse);
    await service.store.markAllRead('one');
    expect(
      (await service.store.history('one')).every((item) => item.isRead),
      isTrue,
    );
    await service.dispose();
  });
  test('local payloads reject malformed events and never carry arbitrary navigation', () {
    expect(StudyAlert.decode('broken'), isNull);
    expect(StudyAlert.decode('{"v":1}'), isNull);
    final decoded = StudyAlert.decode(alert('one').encode());
    expect(decoded!.opensHall, isFalse);
    expect(decoded.title, alert('one').title);
    expect(decoded.encode(), isNot(contains('goal')));
  });
  test('daily reminders follow device local date and roll forward after chosen time', () {
    zones.initializeTimeZones();
    final zone = tz.getLocation('Asia/Colombo');
    expect(
      nextStudyReminder(tz.TZDateTime(zone, 2026, 11, 17, 18, 59), 19, 0),
      tz.TZDateTime(zone, 2026, 11, 17, 19),
    );
    expect(
      nextStudyReminder(tz.TZDateTime(zone, 2026, 11, 17, 19), 19, 0),
      tz.TZDateTime(zone, 2026, 11, 18, 19),
    );
    expect(const NotificationPreferences().dailyReminder, isFalse);
  });
}
