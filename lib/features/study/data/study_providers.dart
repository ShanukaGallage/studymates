import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/controllers/auth_providers.dart';
import 'firestore_study_repository.dart';
import '../../../core/models/community_models.dart';

final liveRoomsProvider = StreamProvider.autoDispose.family(
  (ref, String subgroup) =>
      ref.watch(studyRepositoryProvider).watchRooms(subgroup),
);
final ownSeatClaimProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final uid = ref.watch(authStateProvider.select((value) => value.userId));
  if (uid == null) return Stream.value(null);
  return ref
      .watch(studyRepositoryProvider)
      .claimRef(uid)
      .snapshots()
      .map((d) => d.data());
});

/// One foreground lease-renewer per connected app, shared by Home/room/session.
final studyLeaseKeeperProvider = Provider<void>((ref) {
  final claim = ref.watch(ownSeatClaimProvider).asData?.value;
  if (claim == null || claim['userId'] != ref.read(authStateProvider).userId) {
    return;
  }
  bool busy = false;
  final timer = Timer.periodic(const Duration(seconds: 30), (_) async {
    if (busy ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    busy = true;
    try {
      await ref
          .read(studyRepositoryProvider)
          .renewSeatLease(
            subgroupId: claim['subgroupId'],
            roomId: claim['roomId'],
            seatId: claim['seatId'],
            expectedClaimId: claim['claimId'],
          );
    } catch (_) {
      // The visible room/session explicitly revalidates and displays errors.
      // Never turn failed renewal into local success or automatic re-claim.
    } finally {
      busy = false;
    }
  });
  ref.onDispose(timer.cancel);
});

final connectedRoomSummariesProvider = StreamProvider.autoDispose
    .family<List<RoomSummary>, String>(
      (ref, subgroup) => ref
          .watch(studyRepositoryProvider)
          .watchRooms(subgroup)
          .map(
            (rooms) => rooms
                .map(
                  (r) => RoomSummary(
                    id: r.roomId,
                    subgroupId: r.subgroupId,
                    title: r.title,
                    occupiedSeats: 0,
                  ),
                )
                .toList(),
          ),
    );