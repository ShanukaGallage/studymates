import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_study_repository.dart';

/// Each fresh claim appends its desk to a rules-validated FIFO queue. Renewing a
/// lease never changes order. Only an unavailable host can be replaced.
extension RoomHostCoordinator on FirestoreStudyRepository {
  Future<void> maintainRoomHost(
    String subgroup,
    String room, {
    bool closeIfEmpty = false,
  }) async {
    final user = uid;
    for (var step = 0; step < 43; step++) {
      String? rejectedHead;
      try {
        final changed = await db.runTransaction((tx) async {
          final reference = roomRef(subgroup, room);
          final data = (await tx.get(reference)).data();
          if (data == null || data['status'] == 'closed') return false;
          final now = DateTime.now().toUtc();
          final oldHost = data['hostUid'] as String;
          final hostClaim = (await tx.get(claimRef(oldHost))).data();
          final ownClaim = oldHost == user
              ? hostClaim
              : (await tx.get(claimRef(user))).data();
          if (oldHost != user && !_liveClaim(ownClaim, subgroup, room, now)) {
            return false;
          }
          if (currentUid() != user) {
            throw const StudyFailure('Account changed.');
          }
          if (!data.containsKey('hostQueue')) {
            // One-time upgrade by the existing host; readers cannot invent an
            // ordering for an old room whose host has not yet upgraded.
            if (oldHost != user) return false;
            final seats = <Map<String, dynamic>>[];
            for (var i = 1; i <= (data['capacity'] as int? ?? 6); i++) {
              final seat = (await tx.get(seatRef(subgroup, room, 'seat-$i')))
                  .data();
              if (seat?['status'] == 'occupied') seats.add(seat!);
            }
            seats.sort((a, b) {
              final order = time(a['claimedAt'])
                  .compareTo(time(b['claimedAt']));
              return order != 0
                  ? order
                  : (a['seatId'] as String).compareTo(b['seatId'] as String);
            });
            tx.update(reference, {
              'hostQueue': seats.map((s) => s['seatId']).toList(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
            return true;
          }
          if (closeIfEmpty && oldHost == user && data['hostReleased'] != true) {
            tx.update(reference, {
              'hostReleased': true,
              'updatedAt': FieldValue.serverTimestamp(),
            });
            return true;
          }
          final available =
              _liveClaim(hostClaim, subgroup, room, now) ||
              (data['hostReleased'] != true &&
                  time(data['createdAt'])
                      .add(const Duration(seconds: 125))
                      .isAfter(now));
          if (available) return false;
          final queue = List<String>.from(data['hostQueue']);
          if (queue.isEmpty) {
            if (closeIfEmpty && oldHost == user) {
              tx.update(reference, {
                'status': 'closed',
                'updatedAt': FieldValue.serverTimestamp(),
              });
            }
            return false;
          }
          final head = queue.first;
          final seat = (await tx.get(seatRef(subgroup, room, head))).data();
          final candidate = seat?['userId'] as String?;
          final candidateClaim = candidate == null
              ? null
              : (await tx.get(claimRef(candidate))).data();
          final valid =
              seat?['status'] == 'occupied' &&
              time(seat!['leaseExpiresAt']).isAfter(now) &&
              _liveClaim(candidateClaim, subgroup, room, now) &&
              candidateClaim?['seatId'] == head &&
              candidateClaim?['claimId'] == seat['claimId'];
          if (!valid) {
            tx.update(reference, {
              'hostQueue': queue.sublist(1),
              'updatedAt': FieldValue.serverTimestamp(),
            });
            return true;
          }
          rejectedHead = head;
          // Rules check the candidate's private membership without exposing it
          // to another learner. The queue head is the only permitted successor.
          tx.update(reference, {
            'hostUid': candidate,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          return false;
        });
        if (!changed) return;
      } on FirebaseException catch (error) {
        if (error.code != 'permission-denied' || rejectedHead == null) rethrow;
        // A live but ineligible head (e.g. leaving its subgroup) can be removed
        // only if rules independently confirm its ineligibility.
        await db.runTransaction((tx) async {
          final reference = roomRef(subgroup, room);
          final data = (await tx.get(reference)).data();
          final queue = List<String>.from(data?['hostQueue'] ?? []);
          if (queue.isEmpty ||
              queue.first != rejectedHead ||
              currentUid() != user) {
            return;
          }
          tx.update(reference, {
            'hostQueue': queue.sublist(1),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        });
      }
    }
    throw const StudyFailure(
      'Host handover is still settling. Reopen the room to retry.',
    );
  }
}

bool _liveClaim(
  Map<String, dynamic>? claim,
  String subgroup,
  String room,
  DateTime now,
) =>
    claim != null &&
    claim['subgroupId'] == subgroup &&
    claim['roomId'] == room &&
    time(claim['leaseExpiresAt']).isAfter(now);
