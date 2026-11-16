import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:studymates/core/models/room_models.dart';
import 'package:studymates/core/theme/app_theme.dart';
import 'package:studymates/features/rooms/data/seat_claim_policy.dart';
import 'package:studymates/features/rooms/data/seat_claim_result.dart';
import 'package:studymates/features/rooms/presentation/widgets/room_scene.dart';
import 'package:studymates/features/rooms/presentation/widgets/room_scene_models.dart';
import 'package:studymates/features/study/presentation/study_dialogs.dart';

void main() {
  test('policy supports two and forty seats and rejects IDs past capacity', () {
    for (final capacity in [2, 40]) {
      final seats = [
        for (final id in roomSeatIds(capacity))
          SeatState(seatId: id, status: SeatStatus.available),
      ];
      SeatClaimResult claim(String id) => SeatClaimPolicy.evaluate(
        capacity: capacity,
        roomStatus: RoomStatus.waiting,
        subgroupId: 'g',
        roomId: 'r',
        seats: seats,
        requestedSeatId: id,
        userId: 'u',
        nowUtc: DateTime.utc(2026),
        activeClaimsByUser: {},
      ).result;
      expect(claim('seat-$capacity'), isA<SeatClaimSucceeded>());
      expect(
        (claim('seat-${capacity + 1}') as SeatClaimFailed).failure,
        SeatClaimFailure.seatNotFound,
      );
      expect(
        validateSeatCollection(seats, capacity: capacity).length,
        capacity,
      );
    }
    expect(() => roomSeatIds(1), throwsArgumentError);
    expect(() => roomSeatIds(41), throwsArgumentError);
  });
  testWidgets(
    'creation validates capacity and returns explicit private settings',
    (tester) async {
      RoomCreationOptions? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await studyRoomDialog(context);
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Private study');
      await tester.enterText(find.byType(TextFormField).last, '41');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      expect(find.text('Choose 2–40 desks.'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).last, '40');
      await tester.tap(find.text('Private room'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      expect(result!.capacity, 40);
      expect(result!.isPrivate, isTrue);
      expect(result!.title, 'Private study');
    },
  );
  testWidgets(
    'all forty desks remain reachable with large text on narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      int? tapped;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: RoomScene(
                    seats: [
                      for (var n = 1; n <= 40; n++)
                        RoomSeat(number: n, status: RoomSeatStatus.available),
                    ],
                    onSeatTap: (n) => tapped = n,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.ensureVisible(find.byKey(const ValueKey('seat-40')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('seat-40')));
      await tester.pumpAndSettle();
      expect(tapped, 40);
      expect(tester.takeException(), isNull);
    },
  );
}
