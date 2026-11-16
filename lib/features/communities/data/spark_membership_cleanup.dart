import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/completion_record.dart';
import '../../study/data/firestore_study_repository.dart';
import '../../study/data/room_host_coordinator.dart';

/// Spark-compatible self-service cleanup. Never writes another user's seats,
/// goals or memberships. Hosting passes to the oldest eligible occupied desk.
class SparkMembershipCleanup {
  SparkMembershipCleanup(this.study);
  final FirestoreStudyRepository study;

  Future<void> complete(String requestId) async {
    final user = study.uid;
    final db = study.db;
    final requestRef = db.doc('membershipCleanupRequests/$requestId');
    var request = (await requestRef.get(
      const GetOptions(source: Source.server),
    )).data();
    if (request == null || request['userId'] != user) {
      throw const StudyFailure(
        'Leave request does not belong to this account.',
      );
    }
    if (request['status'] == 'completed') return;
    final groups = request['scope'] == 'subgroup'
        ? [request['subgroupId'] as String]
        : (await db
                  .collection('subgroups')
                  .where('sigId', isEqualTo: request['sigId'])
                  .get(const GetOptions(source: Source.server)))
              .docs
              .map((d) => d.id)
              .toList();
    final active =
        (await study
                .activeRef(user)
                .get(const GetOptions(source: Source.server)))
            .data();
    final claim =
        (await study
                .claimRef(user)
                .get(const GetOptions(source: Source.server)))
            .data();
    if ((active != null && !groups.contains(active['subgroupId'])) ||
        (claim != null && !groups.contains(claim['subgroupId']))) {
      throw const StudyFailure(
        'End your active session and release your seat in the other community, then finish this leave request.',
      );
    }
    if (active != null) {
      await study.finishSession(
        GoalOutcome.unfinished,
        expectedSessionId: active['sessionId'],
      );
    }
    if (claim != null) {
      await study.releaseRoomSeat(
        subgroup: claim['subgroupId'],
        room: claim['roomId'],
        seat: claim['seatId'],
        claimId: claim['claimId'],
      );
    }
    for (final group in groups) {
      final rooms = await db
          .collection('subgroups/$group/rooms')
          .where('hostUid', isEqualTo: user)
          .get(const GetOptions(source: Source.server));
      for (final room in rooms.docs) {
        await study.maintainRoomHost(group, room.id, closeIfEmpty: true);
      }
    }
    await db.runTransaction((tx) async {
      request = (await tx.get(requestRef)).data();
      final currentClaim = await tx.get(study.claimRef(user));
      final currentSession = await tx.get(study.activeRef(user));
      if (study.uid != user) {
        throw const StudyFailure('Account changed. Reopen the app.');
      }
      if (request?['userId'] != user ||
          currentClaim.exists ||
          currentSession.exists) {
        throw const StudyFailure(
          'Finish your session and release your seat before leaving.',
        );
      }
      if (request?['status'] == 'completed') return;
      tx.update(requestRef, {
        'status': 'completed',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<int> resumeAll() async {
    final user = study.uid;
    final requests = await study.db
        .collection('membershipCleanupRequests')
        .where('userId', isEqualTo: user)
        .get(const GetOptions(source: Source.server));
    var count = 0;
    for (final doc in requests.docs) {
      // Also retry finalization after cleanup succeeded but its response was lost.
      await complete(doc.id);
      await study.membership.finalizeMembershipRemoval(doc.id);
      count++;
    }
    return count;
  }
}
