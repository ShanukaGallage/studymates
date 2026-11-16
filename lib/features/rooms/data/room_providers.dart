import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/community_models.dart';
import 'room_repository.dart';
import '../../study/data/firestore_study_repository.dart';

final roomRepositoryProvider = Provider<RoomRepository>(
  (ref) => ref.watch(studyRepositoryProvider),
);

/// Live operations have no default backend until the M2/schema integration is
/// available. Preview/test compositions must bind an explicit implementation.
final liveRoomRepositoryProvider = Provider<LiveRoomRepository>(
  (ref) => ref.watch(studyRepositoryProvider),
);

final subgroupRoomsProvider = FutureProvider.autoDispose
    .family<List<RoomSummary>, String>(
      (ref, id) => ref.watch(roomRepositoryProvider).listRooms(id),
      retry: (count, error) => null,
    );
final roomSummaryProvider = FutureProvider.autoDispose
    .family<RoomSummary?, String>(
      (ref, id) => ref.watch(roomRepositoryProvider).getRoom(id),
      retry: (count, error) => null,
    );
