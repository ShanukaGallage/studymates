import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../communities/presentation/controllers/community_providers.dart';
import '../../../core/models/community_models.dart';
import '../../invites/data/invitation_service.dart';
import '../../invites/data/invitation_token.dart';
import '../../rooms/data/seat_claim_result.dart';
import 'firestore_study_repository.dart';

final firestoreInvitationServiceProvider = Provider<FirestoreInvitationService>(
  (ref) => FirestoreInvitationService(
    study: ref.watch(studyRepositoryProvider),
    catalog: () => ref.read(communityRepositoryProvider).loadCatalog(),
  ),
);

class FirestoreInvitationService implements InvitationService {
  FirestoreInvitationService({required this.study, required this.catalog});
  final FirestoreStudyRepository study;
  final Future<CommunityCatalog> Function() catalog;

  Stream<List<RoomInvitation>> watchRoomInvitations(
    String subgroup,
    String room,
  ) => study.db
      .collection('roomInvites')
      .where('subgroupId', isEqualTo: subgroup)
      .where('roomId', isEqualTo: room)
      .limit(50)
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs
                .map((doc) => RoomInvitation.fromData(doc.id, doc.data()))
                .toList()
              ..sort((a, b) => b.expiresAt.compareTo(a.expiresAt)),
      );

  Stream<RoomInvitation?> watchInvitation(String token) => study.db
      .doc('roomInvites/$token')
      .snapshots()
      .map(
        (doc) =>
            doc.exists ? RoomInvitation.fromData(doc.id, doc.data()!) : null,
      );

  Future<void> revokeInvitation(String token) async {
    if (!InvitationTokenParser.isOpaqueToken(token)) {
      throw const StudyFailure('Invitation code is invalid.');
    }
    final user = study.uid;
    final reference = study.db.doc('roomInvites/$token');
    await study.db.runTransaction((tx) async {
      final data = (await tx.get(reference)).data();
      if (study.currentUid() != user) {
        throw const StudyFailure('Account changed.');
      }
      if (data == null) {
        throw const StudyFailure('Invitation no longer exists.');
      }
      if (data['revoked'] == true) return;
      tx.update(reference, {'revoked': true});
    });
  }

  Future<String> issue(String subgroup, String room) async {
    const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    final token = List.generate(
      16,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
    await study.db.runTransaction((tx) async {
      final roomData = (await tx.get(study.roomRef(subgroup, room))).data();
      if (roomData == null) throw const StudyFailure('Room unavailable.');
      tx.set(study.db.doc('roomInvites/$token'), {
        'subgroupId': subgroup,
        'roomId': room,
        'issuedBy': study.uid,
        'expiresAt': Timestamp.fromDate(
          DateTime.now().toUtc().add(const Duration(hours: 12)),
        ),
        'revoked': false,
      });
    });
    return token;
  }

  @override
  Future<InvitationPreviewResult> resolveInvitation(String opaqueToken) async {
    if (!InvitationTokenParser.isOpaqueToken(opaqueToken)) {
      return const InvitationPreviewResult(
        status: InvitationPreviewStatus.invalid,
      );
    }
    try {
      final data =
          (await study.db
                  .doc('roomInvites/$opaqueToken')
                  .get(const GetOptions(source: Source.server)))
              .data();
      if (data == null) {
        return const InvitationPreviewResult(
          status: InvitationPreviewStatus.invalid,
        );
      }
      if (data['revoked'] == true ||
          !time(data['expiresAt']).isAfter(DateTime.now().toUtc())) {
        return const InvitationPreviewResult(
          status: InvitationPreviewStatus.expiredOrRevoked,
        );
      }
      final snapshot = await study.getRoom(data['roomId']);
      final values = await catalog();
      final group = values.subgroup(data['subgroupId']);
      final sig = group == null ? null : values.sig(group.sigId);
      if (snapshot == null || sig == null || group == null) {
        return const InvitationPreviewResult(
          status: InvitationPreviewStatus.invalid,
        );
      }
      final preview = InvitationPreview(
        room: snapshot,
        sig: sig,
        subgroup: group,
      );
      final member =
          sig.membership.name == 'joined' && group.membership.name == 'joined';
      return InvitationPreviewResult(
        status: !member
            ? InvitationPreviewStatus.membershipRequired
            : snapshot.isFull
            ? InvitationPreviewStatus.fullRoom
            : InvitationPreviewStatus.ready,
        preview: preview,
      );
    } catch (_) {
      return const InvitationPreviewResult(
        status: InvitationPreviewStatus.unavailable,
      );
    }
  }

  @override
  Future<InvitationAdmissionResult> admitInvitation({
    required String opaqueToken,
    required bool membershipConsentGranted,
  }) async {
    // Admission rechecks invitation inside the same transaction as claimSeat.
    final preview = await resolveInvitation(opaqueToken);
    if (preview.status != InvitationPreviewStatus.ready &&
        preview.status != InvitationPreviewStatus.fullRoom) {
      return InvitationAdmissionResult(switch (preview.status) {
        InvitationPreviewStatus.invalid => InvitationAdmissionStatus.invalid,
        InvitationPreviewStatus.expiredOrRevoked =>
          InvitationAdmissionStatus.expiredOrRevoked,
        InvitationPreviewStatus.membershipRequired =>
          InvitationAdmissionStatus.membershipRequired,
        _ => InvitationAdmissionStatus.unavailable,
      });
    }
    final room = preview.preview!.room;
    for (var i = 1; i <= room.capacity; i++) {
      final result = await study.claimSeatWithInvitation(
        subgroupId: room.subgroupId,
        roomId: room.id,
        seatId: 'seat-$i',
        token: opaqueToken,
      );
      if (result is SeatClaimSucceeded) {
        return const InvitationAdmissionResult(
          InvitationAdmissionStatus.admitted,
        );
      }
      if (result is SeatClaimFailed &&
          result.failure == SeatClaimFailure.hallSessionActive) {
        return const InvitationAdmissionResult(
          InvitationAdmissionStatus.hallSessionActive,
        );
      }
      if (result is SeatClaimFailed &&
          result.failure == SeatClaimFailure.alreadySeated) {
        final claim =
            (await study
                    .claimRef(study.uid)
                    .get(const GetOptions(source: Source.server)))
                .data();
        if (claim?['roomId'] == room.id) {
          final same = await study.claimSeatWithInvitation(
            subgroupId: room.subgroupId,
            roomId: room.id,
            seatId: claim!['seatId'],
            token: opaqueToken,
          );
          if (same is SeatClaimSucceeded) {
            return const InvitationAdmissionResult(
              InvitationAdmissionStatus.admitted,
            );
          }
        }
        return const InvitationAdmissionResult(
          InvitationAdmissionStatus.unavailable,
        );
      }
      if (result is SeatClaimFailed &&
          result.failure != SeatClaimFailure.seatTaken &&
          result.failure != SeatClaimFailure.fullRoom) {
        if (result.failure == SeatClaimFailure.membershipRequired) {
          return const InvitationAdmissionResult(
            InvitationAdmissionStatus.membershipRequired,
          );
        }
        final fresh = await resolveInvitation(opaqueToken);
        return InvitationAdmissionResult(
          fresh.status == InvitationPreviewStatus.expiredOrRevoked
              ? InvitationAdmissionStatus.expiredOrRevoked
              : InvitationAdmissionStatus.unavailable,
        );
      }
    }
    return const InvitationAdmissionResult(InvitationAdmissionStatus.fullRoom);
  }
}

class RoomInvitation {
  const RoomInvitation({
    required this.token,
    required this.expiresAt,
    required this.revoked,
  });
  factory RoomInvitation.fromData(String token, Map<String, dynamic> data) =>
      RoomInvitation(
        token: token,
        expiresAt: time(data['expiresAt']),
        revoked: data['revoked'] == true,
      );
  final String token;
  final DateTime expiresAt;
  final bool revoked;
  bool get expired => !expiresAt.isAfter(DateTime.now().toUtc());
  String get manualCode =>
      List.generate(4, (i) => token.substring(i * 4, i * 4 + 4)).join('-');
}
