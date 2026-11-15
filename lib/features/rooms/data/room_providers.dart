import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/community_models.dart';
import 'room_repository.dart';

final roomRepositoryProvider = Provider<RoomRepository>(
  (ref) => throw StateError(
    'No room repository configured. Use the preview entry point.',
  ),
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
