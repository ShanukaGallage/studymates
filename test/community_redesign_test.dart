import 'package:studymates/features/common_hall/presentation/common_hall_providers.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:studymates/app/app.dart';
import 'package:studymates/app/app_mode.dart';
import 'package:studymates/app/router.dart';
import 'package:studymates/core/models/community_models.dart';
import 'package:studymates/core/models/room_models.dart';
import 'package:studymates/features/auth/domain/auth_state.dart';
import 'package:studymates/features/auth/presentation/controllers/auth_providers.dart';
import 'package:studymates/features/communities/data/community_repository.dart';
import 'package:studymates/features/communities/presentation/controllers/community_providers.dart';
import 'package:studymates/features/communities/presentation/controllers/discovery_connection_provider.dart';
import 'package:studymates/features/communities/presentation/controllers/pending_leave_providers.dart';
import 'package:studymates/features/profile/presentation/controllers/profile_providers.dart';
import 'package:studymates/features/sessions/data/active_session_providers.dart';
import 'package:studymates/features/study/data/firestore_study_repository.dart';
import 'package:studymates/features/study/data/study_providers.dart';
import 'package:studymates/preview/preview_scope.dart';

void main() {
  testWidgets(
    'switching and collapsing subgroups uses only the selected room stream',
    (tester) async {
      final rooms = _Rooms();
      await _mount(tester, rooms: rooms);
      expect(find.text('Study rooms'), findsNothing);
      expect(find.text('2'), findsOneWidget);
      await _tap(tester, find.byKey(const ValueKey('subgroup-toggle-a')));
      expect(find.text('Room A'), findsOneWidget);
      expect(find.text('2 desks'), findsOneWidget);
      expect(find.text('Room B'), findsNothing);
      expect(rooms.watched, ['a']);
      await _tap(tester, find.byKey(const ValueKey('subgroup-toggle-b')));
      expect(find.text('Room A'), findsNothing);
      expect(find.text('Room B'), findsOneWidget);
      expect(find.text('40 desks'), findsOneWidget);
      expect(find.textContaining('occupied'), findsNothing);
      expect(rooms.watched, ['a', 'b']);
      await _tap(tester, find.byKey(const ValueKey('subgroup-toggle-b')));
      expect(find.text('Study rooms'), findsNothing);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );
      expect(find.text('StudyMates'), findsNothing);
    },
  );

  testWidgets(
    'room loading, failure, retry and empty state remain inside the subgroup',
    (tester) async {
      final events = StreamController<List<RoomSnapshot>>.broadcast();
      addTearDown(events.close);
      final rooms = _Rooms()..overrideStream = events.stream;
      await _mount(tester, rooms: rooms);
      await tester.tap(find.byKey(const ValueKey('subgroup-toggle-a')));
      await tester.pump();
      expect(find.text('Loading rooms…'), findsOneWidget);
      expect(find.text('Test circle'), findsOneWidget);
      events.addError(const StudyFailure('Unavailable'));
      await tester.pumpAndSettle();
      expect(find.text('Rooms are unavailable. Try again.'), findsOneWidget);
      rooms.overrideStream = null;
      rooms.values['a'] = [];
      await _tap(tester, find.text('Retry'));
      expect(find.text('No rooms yet'), findsOneWidget);
      await _tap(tester, find.byKey(const ValueKey('subgroup-toggle-b')));
      expect(find.text('Room B'), findsOneWidget);
    },
  );

  testWidgets('membership and owner actions stay within existing permissions', (
    tester,
  ) async {
    final catalog = _Catalog(parentJoined: false, groupJoined: false);
    await _mount(tester, catalog: catalog);
    await _tap(tester, find.byKey(const ValueKey('subgroup-toggle-a')));
    expect(
      find.text('Join Test circle first to join this subgroup.'),
      findsOneWidget,
    );
    expect(find.text('Join subgroup'), findsNothing);
    expect(find.text('Create room'), findsNothing);
    expect(find.text('Create subgroup'), findsNothing);
    expect(find.text('Edit Topic A'), findsNothing);
    await _tap(tester, find.text('Join community'));
    expect(find.text('Join subgroup'), findsOneWidget);
    expect(find.text('Create room'), findsNothing);
    await _tap(tester, find.text('Join subgroup'));
    expect(find.byKey(const ValueKey('create-room-a')), findsOneWidget);
    await _tap(tester, find.text('Leave subgroup'));
    expect(find.text('Leave subgroup?'), findsOneWidget);
    await _tap(tester, find.text('Cancel'));
    expect(catalog.value.subgroup('a')!.membership, MembershipState.joined);
    await _tap(tester, find.text('Leave subgroup'));
    await _tap(tester, find.text('Leave'));
    expect(find.text('Create room'), findsNothing);
    expect(find.text('Join subgroup'), findsOneWidget);
  });

  testWidgets(
    'community overflow keeps leave confirmation and clears subgroup membership',
    (tester) async {
      final catalog = _Catalog();
      await _mount(tester, catalog: catalog);
      await _tap(tester, find.byTooltip('Community actions'));
      await _tap(tester, find.text('Leave community'));
      expect(find.text('Leave community?'), findsOneWidget);
      await _tap(tester, find.text('Cancel'));
      expect(catalog.value.sig('circle')!.membership, MembershipState.joined);
      await _tap(tester, find.byTooltip('Community actions'));
      await _tap(tester, find.text('Leave community'));
      await _tap(tester, find.text('Leave'));
      expect(find.text('Join community'), findsOneWidget);
      expect(
        catalog.value.subgroup('a')!.membership,
        MembershipState.notJoined,
      );
    },
  );

  testWidgets(
    'creation uses the expanded subgroup, updates it, and returns to it',
    (tester) async {
      final rooms = _Rooms();
      final container = await _mount(tester, rooms: rooms);
      await _tap(tester, find.byKey(const ValueKey('subgroup-toggle-b')));
      await _tap(tester, find.byKey(const ValueKey('create-room-b')));
      final fields = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(fields.at(0), 'New room B');
      await tester.enterText(fields.at(1), '8');
      await _tap(tester, find.text('Create'));
      expect(rooms.created, (
        subgroup: 'b',
        title: 'New room B',
        capacity: 8,
        private: false,
      ));
      expect(container.read(appRouterProvider).state.uri.path, '/rooms/new-b');
      container.read(appRouterProvider).pop();
      await tester.pumpAndSettle();
      expect(find.text('Room A'), findsNothing);
      await _reveal(tester, find.byKey(const ValueKey('room-row-new-b')));
      expect(find.text('New room B'), findsOneWidget);
      expect(find.text('8 desks'), findsOneWidget);
    },
  );

  testWidgets('creation failure stays in the subgroup and permits retry', (
    tester,
  ) async {
    final rooms = _Rooms()
      ..createFailure = const StudyFailure('Please retry creation.');
    final container = await _mount(tester, rooms: rooms);
    await _tap(tester, find.byKey(const ValueKey('subgroup-toggle-a')));
    await _tap(tester, find.byKey(const ValueKey('create-room-a')));
    final fields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(fields.first, 'New room');
    await _tap(tester, find.text('Create'));
    expect(container.read(appRouterProvider).state.uri.path, '/sigs/circle');
    expect(find.text('Please retry creation.'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('create-room-a')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('preview room return restores expansion and scroll position', (
    tester,
  ) async {
    await tester.pumpWidget(const PreviewScope(child: StudyMatesApp()));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(StudyMatesApp)),
    );
    final router = container.read(appRouterProvider);
    router.go('/sigs/iot');
    await tester.pumpAndSettle();
    await _tap(tester, find.byKey(const ValueKey('subgroup-toggle-esp32')));
    await _reveal(tester, find.byKey(const ValueKey('room-row-sensor-club')));
    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    final offset = scrollable.position.pixels;
    await tester.tap(find.byKey(const ValueKey('room-row-sensor-club')));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/rooms/sensor-club');
    expect(find.text('Room scene preview'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/sigs/iot');
    expect(find.text('Study rooms'), findsOneWidget);
    expect(
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels,
      closeTo(offset, 1),
    );
    expect(find.byKey(const ValueKey('room-row-sensor-club')), findsOneWidget);
  });

  testWidgets(
    '320dp and large text support long names and subgroup owner controls',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final catalog = _Catalog(owner: true, longNames: true);
      await _mount(tester, catalog: catalog, largeText: true);
      await _tap(tester, find.byKey(const ValueKey('subgroup-toggle-a')));
      await _reveal(tester, find.text('Leave subgroup'));
      await _reveal(
        tester,
        find.text('Delete ${catalog.value.subgroup('a')!.name}'),
      );
      expect(tester.takeException(), isNull);
    },
  );
}

Future<ProviderContainer> _mount(
  WidgetTester tester, {
  _Catalog? catalog,
  _Rooms? rooms,
  bool largeText = false,
}) async {
  catalog ??= _Catalog();
  rooms ??= _Rooms();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        commonHallSessionProvider.overrideWith((ref) => const AsyncData(null)),
        appModeProvider.overrideWithValue(AppMode.connected),
        authStateProvider.overrideWith(_Identity.new),
        currentProfileProvider.overrideWith(
          (ref) =>
              Stream.value(UserProfile(id: 'learner', displayName: 'Learner')),
        ),
        communityRepositoryProvider.overrideWithValue(catalog),
        studyRepositoryProvider.overrideWithValue(rooms),
        currentUserActiveSessionProvider.overrideWith(
          (ref) => const AsyncData(null),
        ),
        studyLeaseKeeperProvider.overrideWith((ref) {}),
        pendingLeaveCountProvider.overrideWith((ref) => Stream.value(0)),
        discoveryConnectionProvider.overrideWith((ref) => Stream.value(true)),
      ],
      child: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(largeText ? 2 : 1)),
        child: const StudyMatesApp(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(StudyMatesApp)),
  );
  container.read(appRouterProvider).go('/sigs/circle');
  await tester.pumpAndSettle();
  return container;
}

Future<void> _reveal(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await _reveal(tester, target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

class _Identity extends AuthStateController {
  @override
  AuthState build() =>
      const AuthState.ready(userId: 'learner', displayName: 'Learner');
}

class _Catalog extends Fake implements CommunityRepository {
  _Catalog({
    bool parentJoined = true,
    bool groupJoined = true,
    bool owner = false,
    bool longNames = false,
  }) {
    value = CommunityCatalog(
      profile: UserProfile(id: 'learner', displayName: 'Learner'),
      sigs: [
        SigSummary(
          id: 'circle',
          name: longNames
              ? 'A community for accessible collaborative learning and software engineering'
              : 'Test circle',
          category: 'Study',
          description: 'Learn together.',
          ownerId: owner ? 'learner' : 'owner',
          membership: parentJoined
              ? MembershipState.joined
              : MembershipState.notJoined,
        ),
      ],
      subgroups: [
        for (final id in ['a', 'b'])
          SubgroupSummary(
            id: id,
            sigId: 'circle',
            name: longNames
                ? 'A subgroup with a long descriptive name about learning together $id'
                : 'Topic ${id.toUpperCase()}',
            description: '',
            membership: groupJoined
                ? MembershipState.joined
                : MembershipState.notJoined,
          ),
      ],
    );
  }
  late CommunityCatalog value;
  @override
  Future<CommunityCatalog> loadCatalog() async => value;
  @override
  Future<CommunityCatalog> setSigMembership(
    String id,
    MembershipState membership,
  ) async => value = CommunityCatalog(
    profile: value.profile,
    sigs: value.sigs.map((s) => s.withMembership(membership)).toList(),
    subgroups: value.subgroups
        .map(
          (g) => membership == MembershipState.notJoined
              ? g.withMembership(membership)
              : g,
        )
        .toList(),
  );
  @override
  Future<CommunityCatalog> setSubgroupMembership(
    String id,
    MembershipState membership,
  ) async => value = CommunityCatalog(
    profile: value.profile,
    sigs: value.sigs,
    subgroups: value.subgroups
        .map((g) => g.id == id ? g.withMembership(membership) : g)
        .toList(),
  );
}

class _Rooms extends Fake implements FirestoreStudyRepository {
  final watched = <String>[];
  final values = {
    for (final id in ['a', 'b'])
      id: [
        RoomSnapshot(
          roomId: 'room-$id',
          subgroupId: id,
          title: 'Room ${id.toUpperCase()}',
          createdBy: 'owner',
          hostUid: 'owner',
          status: RoomStatus.waiting,
          capacity: id == 'a' ? 2 : 40,
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      ],
  };
  Stream<List<RoomSnapshot>>? overrideStream;
  ({String subgroup, String title, int capacity, bool private})? created;
  Object? createFailure;
  @override
  Stream<List<RoomSnapshot>> watchRooms(String subgroupId) {
    watched.add(subgroupId);
    return overrideStream ?? Stream.value(values[subgroupId]!);
  }

  @override
  Future<RoomSnapshot> createRoom({
    required String subgroupId,
    required String title,
    int capacity = 6,
    bool isPrivate = false,
  }) async {
    created = (
      subgroup: subgroupId,
      title: title,
      capacity: capacity,
      private: isPrivate,
    );
    if (createFailure case final error?) throw error;
    final room = RoomSnapshot(
      roomId: 'new-$subgroupId',
      subgroupId: subgroupId,
      title: title,
      createdBy: 'learner',
      hostUid: 'learner',
      status: RoomStatus.waiting,
      capacity: capacity,
      isPrivate: isPrivate,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    values[subgroupId]!.add(room);
    return room;
  }

  @override
  Future<Map<String, dynamic>> locator(String id) async =>
      throw const StudyFailure('No real backend in a widget test.');
}
