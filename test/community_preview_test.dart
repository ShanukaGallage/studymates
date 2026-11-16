import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:studymates/app/app.dart';
import 'package:studymates/app/router.dart';
import 'package:studymates/core/models/community_models.dart';
import 'package:studymates/core/widgets/app_text_field.dart';
import 'package:studymates/features/communities/presentation/controllers/community_providers.dart';
import 'package:studymates/preview/preview_repositories.dart';
import 'package:studymates/preview/preview_scope.dart';

void main() {
  testWidgets('PreviewScope continues to bind MemoryCommunityRepository', (
    tester,
  ) async {
    late ProviderContainer container;
    await tester.pumpWidget(
      PreviewScope(
        child: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(
      container.read(communityRepositoryProvider),
      isA<MemoryCommunityRepository>(),
    );
  });

  test('membership requires parent, is idempotent, and leaving parent clears children', () async {
    final repo = MemoryCommunityRepository();
    await expectLater(
      repo.setSubgroupMembership('esp32', MembershipState.joined),
      throwsA(
        isA<RepositoryException>().having(
          (e) => e.code,
          'code',
          RepositoryError.membershipRequired,
        ),
      ),
    );
    await repo.setSigMembership('iot', MembershipState.joined);
    await repo.setSubgroupMembership('esp32', MembershipState.joined);
    final joined = await repo.setSubgroupMembership(
      'esp32',
      MembershipState.joined,
    );
    expect(joined.subgroup('esp32')!.membership, MembershipState.joined);
    final left = await repo.setSigMembership('iot', MembershipState.notJoined);
    expect(left.subgroup('esp32')!.membership, MembershipState.notJoined);
    expect(joined.subgroup('esp32')!.membership, MembershipState.joined);
    await repo.setSigMembership('iot', MembershipState.joined);
    expect(
      (await repo.loadCatalog()).subgroup('esp32')!.membership,
      MembershipState.notJoined,
    );
    await expectLater(
      repo.setSigMembership('missing', MembershipState.joined),
      throwsA(isA<RepositoryException>()),
    );
    expect(
      (await MemoryCommunityRepository().loadCatalog()).sig('iot')!.membership,
      MembershipState.notJoined,
    );
  });

  test(
    'preview owner can create, edit and close locally created communities',
    () async {
      final repo = MemoryCommunityRepository();
      final afterCreate = await repo.createSig(
        name: '  Study Systems ',
        category: 'Technology',
        description: 'Read and build together.',
      );
      final sig = afterCreate.sigs.last;
      expect(sig.ownerId, afterCreate.profile.id);
      final created = await repo.createSubgroup(
        sigId: sig.id,
        name: 'Methods',
        description: 'Compare study methods.',
      );
      final subgroup = created.subgroups.last;
      final edited = await repo.updateSubgroup(
        sigId: sig.id,
        subgroupId: subgroup.id,
        name: 'Updated methods',
        description: 'A revised description.',
      );
      expect(edited.subgroup(subgroup.id)!.name, 'Updated methods');
      final joined = await repo.setSubgroupMembership(
        subgroup.id,
        MembershipState.joined,
      );
      expect(joined.subgroup(subgroup.id)!.membership, MembershipState.joined);
      final deleted = await repo.deleteSubgroup(
        sigId: sig.id,
        subgroupId: subgroup.id,
      );
      expect(deleted.subgroup(subgroup.id)?.status, SubgroupStatus.closed);
      expect(deleted.subgroup(subgroup.id)?.membership, MembershipState.joined);
      expect(
        deleted.activeSubgroups.map((group) => group.id),
        isNot(contains(subgroup.id)),
      );
    },
  );

  test('closed subgroups cannot be rejoined or expose their rooms', () async {
    final communityRepository = MemoryCommunityRepository();
    final sigs = await communityRepository.createSig(
      name: 'Study Systems',
      category: 'Technology',
      description: 'Study together.',
    );
    final sig = sigs.sigs.last;
    final groups = await communityRepository.createSubgroup(
      sigId: sig.id,
      name: 'Methods',
      description: 'Compare study methods.',
    );
    final subgroup = groups.subgroups.last;
    await communityRepository.setSubgroupMembership(
      subgroup.id,
      MembershipState.joined,
    );
    await communityRepository.deleteSubgroup(
      sigId: sig.id,
      subgroupId: subgroup.id,
    );

    await expectLater(
      communityRepository.setSubgroupMembership(
        subgroup.id,
        MembershipState.joined,
      ),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryError.notFound,
        ),
      ),
    );

    final roomRepository = MemoryRoomRepository(
      isSubgroupActive: (id) async => id != 'esp32',
    );
    expect(await roomRepository.listRooms('esp32'), isEmpty);
    expect(await roomRepository.getRoom('first-sensor'), isNull);
  });

  test(
    'room fixtures are filtered, immutable and have empty/full examples',
    () async {
      final repo = MemoryRoomRepository();
      final rooms = await repo.listRooms('esp32');
      expect(rooms.every((room) => room.subgroupId == 'esp32'), isTrue);
      expect(rooms.any((room) => room.occupiedSeats == 0), isTrue);
      expect(rooms.any((room) => room.isFull), isTrue);
      expect(() => rooms.clear(), throwsUnsupportedError);
      expect(await repo.listRooms('dart'), isEmpty);
      expect(await repo.getRoom('missing'), isNull);
    },
  );

  Future<ProviderContainer> mount(
    WidgetTester tester, {
    String path = '/discover',
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
        child: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(narrow ? 2 : 1)),
          child: const StudyMatesApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(StudyMatesApp)),
    );
    container.read(appRouterProvider).go(path);
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> tap(WidgetTester tester, String label) async {
    final target = label == 'Clear search'
        ? find.byTooltip(label)
        : find.text(label);
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets('owner forms create SIGs and manage subgroups', (tester) async {
    final container = await mount(tester);
    container.read(appRouterProvider).go('/sigs/iot');
    await tester.pumpAndSettle();
    expect(find.text('Create subgroup'), findsNothing);
    container.read(appRouterProvider).go('/discover');
    await tester.pumpAndSettle();
    await tap(tester, 'Create');
    final sigFields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(sigFields.at(0), 'Study Systems');
    await tester.enterText(sigFields.at(1), 'Technology');
    await tester.enterText(sigFields.at(2), 'Study and build together.');
    await tap(tester, 'Create SIG');
    await tester.scrollUntilVisible(
      find.text('Study Systems'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Study Systems'), findsOneWidget);

    container.read(appRouterProvider).go('/sigs/preview-sig-1');
    await tester.pumpAndSettle();
    await tap(tester, 'Create subgroup');
    final subgroupFields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(subgroupFields.at(0), 'Methods');
    await tester.enterText(subgroupFields.at(1), 'Compare study methods.');
    await tester.tap(find.text('Create subgroup').last);
    await tester.pumpAndSettle();
    expect(find.text('Edit Methods'), findsOneWidget);
    expect(find.text('Delete Methods'), findsOneWidget);

    await tap(tester, 'Edit Methods');
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'Learning methods',
    );
    await tap(tester, 'Save changes');
    expect(find.text('Learning methods'), findsOneWidget);

    await tap(tester, 'Delete Learning methods');
    await tap(tester, 'Delete');
    expect(find.text('No subgroups yet'), findsOneWidget);
    final closedGroup = container
        .read(communityCatalogProvider)
        .requireValue
        .subgroup('preview-subgroup-2');
    expect(closedGroup?.status, SubgroupStatus.closed);
    container.read(appRouterProvider).go('/subgroups/preview-subgroup-2');
    await tester.pumpAndSettle();
    expect(find.textContaining('This subgroup is closed.'), findsOneWidget);
    expect(find.text('Study rooms'), findsNothing);
  });

  testWidgets(
    'search, join hierarchy, open room, return and leave consistently',
    (tester) async {
      await mount(tester);
      await tester.enterText(find.byType(AppTextField), 'nonsense');
      await tester.pumpAndSettle();
      expect(find.text('No matches'), findsOneWidget);
      await tap(tester, 'Clear search');
      await tester.enterText(find.byType(AppTextField), 'IOT');
      await tester.pumpAndSettle();
      expect(find.text('Programming'), findsNothing);
      await tap(tester, 'IoT');
      await tap(tester, 'Open ESP32');
      expect(
        find.text('Join IoT first to join this subgroup.'),
        findsOneWidget,
      );
      final join = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Join subgroup'),
      );
      expect(join.onPressed, isNull);
      await tap(tester, 'Back to IoT');
      await tap(tester, 'Join SIG');
      await tap(tester, 'Open ESP32');
      await tap(tester, 'Join subgroup');
      await tap(tester, 'Preview First Sensor Project');
      expect(find.text('Room scene preview'), findsOneWidget);
      expect(
        find.text(
          'Subgroup joined in preview. You have not entered or reserved a seat.',
        ),
        findsOneWidget,
      );
      expect(
        GoRouterState.of(tester.element(find.text('Room scene preview')))
            .uri
            .path,
        '/rooms/first-sensor',
      );
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );
      await tap(tester, 'Back to ESP32');
      await tap(tester, 'Back to IoT');
      await tap(tester, 'Leave SIG');
      await tap(tester, 'Cancel');
      expect(find.text('You joined this SIG in preview.'), findsOneWidget);
      await tap(tester, 'Leave SIG');
      await tap(tester, 'Leave');
      await tap(tester, 'Open ESP32');
      expect(
        find.text('Join IoT first to join this subgroup.'),
        findsOneWidget,
      );
      expect(find.text('Leave subgroup'), findsNothing);
    },
  );

  testWidgets('deep links, missing IDs and tab restoration use shared routes', (
    tester,
  ) async {
    final container = await mount(tester, path: '/subgroups/flutter');
    expect(find.text('Flutter'), findsOneWidget);
    await tap(tester, 'Preview My First Flutter Screen');
    await tap(tester, 'Profile');
    await tap(tester, 'Discover');
    expect(find.text('My First Flutter Screen'), findsOneWidget);
    for (final path in [
      '/sigs/missing',
      '/subgroups/missing',
      '/rooms/missing',
    ]) {
      container.read(appRouterProvider).go(path);
      await tester.pumpAndSettle();
      expect(find.text('Not found'), findsOneWidget);
      await tap(tester, 'Back to Discover');
      expect(find.text('Search communities'), findsOneWidget);
    }
  });

  testWidgets('preview scenarios show empty, loading and recoverable errors', (
    tester,
  ) async {
    final container = await mount(tester);
    await tester.tap(find.byTooltip('Preview data'));
    await tester.pumpAndSettle();
    await tap(tester, 'Empty data');
    await tap(tester, 'Open Discover');
    expect(find.text('No communities yet'), findsOneWidget);
    await tester.tap(find.byTooltip('Preview data'));
    await tester.pumpAndSettle();
    await tap(tester, 'Error once');
    await tap(tester, 'Open Discover');
    expect(
      find.text('Communities are unavailable. Try again.'),
      findsOneWidget,
    );
    await tap(tester, 'Retry');
    expect(find.text('IoT'), findsOneWidget);
    container.read(appRouterProvider).go('/subgroups/esp32');
    await tester.pumpAndSettle();
    expect(find.text('Rooms are unavailable. Try again.'), findsOneWidget);
    await tap(tester, 'Retry');
    expect(find.text('First Sensor Project'), findsOneWidget);
    container
        .read(previewScenarioProvider.notifier)
        .select(PreviewScenario.loading);
    container.read(appRouterProvider).go('/discover');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Loading communities…'), findsOneWidget);
    container
        .read(previewScenarioProvider.notifier)
        .select(PreviewScenario.sample);
    await tester.pumpAndSettle();
    expect(find.text('IoT'), findsOneWidget);
  });

  testWidgets(
    'narrow large-text screens handle long names, empty lists and full rooms',
    (tester) async {
      final container = await mount(tester, narrow: true);
      for (final path in [
        '/sigs/design',
        '/subgroups/dart',
        '/subgroups/esp32',
        '/rooms/sensor-club',
      ]) {
        container.read(appRouterProvider).go(path);
        await tester.pumpAndSettle();
        await tester.drag(
          find
              .byWidgetPredicate(
                (widget) =>
                    widget is Scrollable &&
                    widget.axisDirection == AxisDirection.down,
              )
              .last,
          const Offset(0, -1200),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(
        find.text('This sample room is full. No seat is available.'),
        findsOneWidget,
      );
      expect(
        MediaQuery.textScalerOf(tester.element(find.text('Room scene preview')))
            .scale(16),
        32,
      );
    },
  );
}
