import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:studymates/features/sessions/data/active_session_providers.dart';
import 'package:studymates/features/study/data/firestore_study_repository.dart';
import 'package:studymates/features/study/data/study_providers.dart';
import 'package:studymates/features/study/presentation/seat_recovery_card.dart';

class _Study extends Fake implements FirestoreStudyRepository {
  int releases = 0;
  @override
  Future<void> releaseRoomSeat({
    required String subgroup,
    required String room,
    required String seat,
    required String claimId,
  }) async {
    expect(
      (subgroup, room, seat, claimId),
      ('group', 'old-room', 'seat-2', 'expected-claim'),
    );
    releases++;
  }
}

void main() {
  testWidgets(
    'reserved seat offers recovery and release needs explicit confirmation',
    (tester) async {
      final repo = _Study();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ownSeatClaimProvider.overrideWith(
              (ref) => Stream.value({
                'subgroupId': 'group',
                'roomId': 'old-room',
                'seatId': 'seat-2',
                'claimId': 'expected-claim',
              }),
            ),
            currentUserActiveSessionProvider.overrideWith(
              (ref) => const AsyncData(null),
            ),
            studyRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(
            home: Scaffold(body: SeatRecoveryCard(roomId: 'new-room')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Open my reserved room'), findsOneWidget);
      expect(find.textContaining('Desk 2'), findsOneWidget);
      expect(repo.releases, 0);
      await tester.tap(find.text('Release reserved seat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep seat'));
      await tester.pumpAndSettle();
      expect(repo.releases, 0);
      await tester.tap(find.text('Release reserved seat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Release seat'));
      await tester.pumpAndSettle();
      expect(repo.releases, 1);
    },
  );
}
