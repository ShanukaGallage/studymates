import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studymates/core/models/room_models.dart';
import 'package:studymates/features/study/data/firestore_study_repository.dart';

void main() {
  test('Firestore room, seat and completion decode UTC and preserve identity and credit', () {
    final date = Timestamp.fromDate(DateTime.utc(2026, 11, 16));
    final room = decodeRoom({
      'roomId': 'r',
      'subgroupId': 'g',
      'title': 'Study',
      'createdBy': 'u',
      'hostUid': 'u',
      'status': 'active',
      'createdAt': date,
      'updatedAt': date,
    });
    expect(room.status, RoomStatus.active);
    expect(room.createdAt.isUtc, isTrue);
    final seat = decodeSeat({
      'seatId': 'seat-1',
      'status': 'occupied',
      'userId': 'u',
      'claimedAt': date,
      'leaseExpiresAt': Timestamp.fromDate(DateTime.utc(2026, 11, 16, 0, 2)),
      'lastRenewedAt': date,
    });
    expect(seat.userId, 'u');
    expect(seat.leaseExpiresAt!.difference(seat.claimedAt!).inSeconds, 120);
    final completion = decodeCompletion({
      'recordId': 's',
      'sessionId': 's',
      'userId': 'u',
      'goalText': 'Learn',
      'endedAt': date,
      'creditedSeconds': 41,
      'timerStatus': 'endedEarly',
      'goalOutcome': 'unfinished',
      'isDemo': true,
    });
    expect(completion.creditedSeconds, 41);
    expect(completion.isDemo, isTrue);
    expect(completion.goalText, 'Learn');
  });
}