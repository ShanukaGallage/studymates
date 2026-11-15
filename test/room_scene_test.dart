import 'dart:ui' show SemanticsAction;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:studymates/core/theme/app_theme.dart';
import 'package:studymates/core/widgets/app_text_field.dart';
import 'package:studymates/features/rooms/presentation/widgets/room_lobby_preview.dart';
import 'package:studymates/features/rooms/presentation/widgets/room_scene.dart';
import 'package:studymates/features/rooms/presentation/widgets/room_scene_models.dart';
import 'package:studymates/preview/community_fixtures.dart';
import 'package:studymates/preview/room_scene_fixtures.dart';

void main() {
  Future<void> mount(
    WidgetTester tester, {
    bool member = true,
    bool narrow = false,
    VoidCallback? onLeave,
  }) async {
    if (narrow) {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(narrow ? 2 : 1)),
          child: child!,
        ),
        home: Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                RoomLobbyPreview(
                  room: previewRooms.first,
                  seats: roomSceneFixtures('first-sensor'),
                  isMember: member,
                  onLeave: onLeave ?? () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.pumpAndSettle();
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  Future<void> tapSeat(WidgetTester tester, int number) async {
    await tester.ensureVisible(find.byKey(ValueKey('seat-$number')));
    await tester.pump();
    await tester.tap(find.byKey(ValueKey('seat-$number')));
    await tester.pump();
  }

  RoomSeatStatus status(WidgetTester tester, int number) =>
      tester.widget<RoomScene>(find.byType(RoomScene)).seats[number - 1].status;

  testWidgets(
    'six targets remain aligned and usable at narrow and wide widths',
    (tester) async {
      for (final width in [280.0, 390.0, 600.0]) {
        final tapped = <int>[];
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(
                  width: width,
                  child: RoomScene(
                    seats: roomSceneFixtures('quiet-lab'),
                    onSeatTap: tapped.add,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (var number = 1; number <= 6; number++) {
          final finder = find.byKey(ValueKey('seat-$number'));
          await tester.ensureVisible(finder);
          await tester.pumpAndSettle();
          expect(tester.getSize(finder).width, greaterThanOrEqualTo(48));
          expect(tester.getSize(finder).height, greaterThanOrEqualTo(48));
          await tester.tap(finder);
        }
        expect(tapped, [1, 2, 3, 4, 5, 6]);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'all seat states have labels; occupied and pending seats do not react',
    (tester) async {
      final semantics = tester.ensureSemantics();

      final tapped = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 320,
                child: RoomScene(
                  seats: galleryRoomSeats,
                  onSeatTap: tapped.add,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final seat in galleryRoomSeats) {
        final finder = find.byKey(ValueKey('seat-${seat.number}'));
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        expect(
          tester.getSemantics(finder).label,
          'Seat ${seat.number}, ${seat.description}',
        );
        final interactive = [1, 3, 6].contains(seat.number);
        expect(
          tester
              .getSemantics(finder)
              .getSemanticsData()
              .hasAction(SemanticsAction.tap),
          interactive,
        );
        await tester.tap(finder);
      }
      expect(tapped, [1, 3, 6]);
      semantics.dispose();
    },
  );

  testWidgets('classroom uses two columns and stacks for large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final scale in [1.0, 2.0]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: RoomScene(
                    seats: [
                      const RoomSeat(
                        number: 1,
                        status: RoomSeatStatus.occupied,
                        occupant: SeatOccupant(
                          name: 'A study mate with a very long display name',
                          avatarId: 'mint',
                        ),
                      ),
                      ...roomSceneFixtures('quiet-lab').skip(1),
                    ],
                    onSeatTap: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final first = tester.getRect(find.byKey(const ValueKey('seat-1')));
      final second = tester.getRect(find.byKey(const ValueKey('seat-2')));
      if (scale == 1) {
        expect(first.top, second.top);
        expect(second.left, greaterThan(first.right));
      } else {
        expect(first.left, second.left);
        expect(second.top, greaterThan(first.bottom));
      }
      for (var n = 1; n <= 6; n++) {
        final seat = find.byKey(ValueKey('seat-$n'));
        await tester.ensureVisible(seat);
        await tester.pumpAndSettle();
        final rect = tester.getRect(seat);
        expect(rect.left, greaterThanOrEqualTo(16));
        expect(rect.right, lessThanOrEqualTo(304));
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('non-members cannot select seats or set goals', (tester) async {
    await mount(tester, member: false);
    await tapSeat(tester, 4);
    expect(status(tester, 4), RoomSeatStatus.available);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Set preview goal'),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets(
    'pending blocks repeated selection; conflict retry preserves one selected seat',
    (tester) async {
      await mount(tester);
      await tapSeat(tester, 1);
      expect(status(tester, 1), RoomSeatStatus.occupied);
      await tapSeat(tester, 4);
      expect(status(tester, 4), RoomSeatStatus.pending);
      await tapSeat(tester, 5);
      expect(status(tester, 5), RoomSeatStatus.available);
      await tester.pump(const Duration(milliseconds: 500));
      expect(status(tester, 4), RoomSeatStatus.selected);
      await tapText(tester, 'Preview controls');
      await tapText(tester, 'Simulate next selection conflict');
      await tapSeat(tester, 5);
      await tester.pump(const Duration(milliseconds: 500));
      expect(status(tester, 5), RoomSeatStatus.failed);
      expect(status(tester, 4), RoomSeatStatus.selected);
      await tapSeat(tester, 5);
      await tester.pump(const Duration(milliseconds: 500));
      expect(status(tester, 5), RoomSeatStatus.selected);
      expect(status(tester, 4), RoomSeatStatus.available);
      await tapSeat(tester, 5);
      expect(status(tester, 5), RoomSeatStatus.available);
    },
  );

  testWidgets(
    'goal validates, saves and cancels edits; leave clears draft after confirmation',
    (tester) async {
      var leaves = 0;
      await mount(tester, onLeave: () => leaves++);
      await tapText(tester, 'Set preview goal');
      await tapText(tester, 'Save preview goal');
      expect(find.text('Enter a goal before saving.'), findsOneWidget);
      await tester.enterText(
        find.byType(AppTextField),
        '  Wire my first sensor  ',
      );
      await tapText(tester, 'Save preview goal');
      expect(find.text('Wire my first sensor'), findsOneWidget);
      await tapText(tester, 'Edit preview goal');
      await tester.enterText(find.byType(AppTextField), 'Unsaved change');
      await tapText(tester, 'Cancel');
      expect(find.text('Wire my first sensor'), findsOneWidget);
      await tapText(tester, 'Leave room preview');
      await tapText(tester, 'Stay');
      expect(leaves, 0);
      await tapText(tester, 'Leave room preview');
      await tapText(tester, 'Leave preview');
      expect(leaves, 1);
      expect(find.text('No preview goal yet.'), findsOneWidget);
    },
  );

  testWidgets('narrow large-text goal sheet scrolls above keyboard', (
    tester,
  ) async {
    await mount(tester, narrow: true);
    await tapText(tester, 'Set preview goal');
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    await tester.enterText(
      find.byType(AppTextField),
      'Read one section and write a short explanation in my own words.',
    );
    await tapText(tester, 'Save preview goal');
    expect(tester.takeException(), isNull);
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
  });

  testWidgets('disposing during pending selection cancels the local timer', (
    tester,
  ) async {
    await mount(tester);
    await tapSeat(tester, 4);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
}
