import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_study_repository.dart';

/// Immutable room schedules, independent of any learner's personal completions.
extension RoomCycleRepository on FirestoreStudyRepository {
  Stream<List<Map<String, dynamic>>> watchRoomCycles(
    String subgroup,
    String room,
  ) => db
      .collection('roomSessions')
      .where('subgroupId', isEqualTo: subgroup)
      .where('roomId', isEqualTo: room)
      .snapshots(includeMetadataChanges: true)
      .map(
        (snapshot) => snapshot.docs
            .map(
              (doc) => {
                ...doc.data(),
                'sessionId': doc.id,
                'cached': snapshot.metadata.isFromCache,
              },
            )
            .toList(),
      );
}

int completedRoomCycles(
  Iterable<Map<String, dynamic>> cycles,
  DateTime now, {
  bool demo = false,
}) => cycles
    .where(
      (cycle) =>
          cycle['isDemo'] == demo &&
          cycle['startsAt'] is Timestamp &&
          !time(cycle['startsAt'])
              .add(Duration(seconds: demo ? 60 : 1800))
              .isAfter(now.toUtc()),
    )
    .length;
