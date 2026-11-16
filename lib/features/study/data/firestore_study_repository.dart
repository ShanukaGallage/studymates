import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/active_room_session.dart';
import '../../../core/models/community_models.dart';
import '../../../core/models/completion_record.dart';
import '../../../core/models/room_models.dart';
import '../../auth/presentation/controllers/auth_providers.dart';
import '../../communities/data/firestore_membership_repository.dart';
import '../../communities/data/membership_repository.dart';
import '../../rooms/data/room_repository.dart';
import '../../rooms/data/seat_claim_policy.dart';
import '../../rooms/data/seat_claim_result.dart';
import '../../rooms/data/seat_lease_repository.dart';
import '../../sessions/data/active_session_repository.dart';
import '../../sessions/data/completion_history_repository.dart';

final studyRepositoryProvider = Provider<FirestoreStudyRepository>(
  (ref) => FirestoreStudyRepository(
    db: FirebaseFirestore.instance,
    membership: ref.watch(membershipRepositoryProvider),
    currentUid: () => ref.read(authStateProvider).userId,
  ),
);

class StudyFailure implements Exception {
  const StudyFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class FirestoreStudyRepository
    implements
        LiveRoomRepository,
        SeatLeaseRepository,
        ActiveSessionRepository,
        CompletionHistoryRepository {
  FirestoreStudyRepository({
    required this.db,
    required this.membership,
    required this.currentUid,
  });
  final FirebaseFirestore db;
  final MembershipRepository membership;
  final String? Function() currentUid;
  String get uid =>
      currentUid() ?? (throw const StudyFailure('Please sign in again.'));
  DocumentReference<Map<String, dynamic>> roomRef(
    String subgroup,
    String room,
  ) => db.doc('subgroups/$subgroup/rooms/$room');
  DocumentReference<Map<String, dynamic>> seatRef(
    String subgroup,
    String room,
    String seat,
  ) => roomRef(subgroup, room).collection('seats').doc(seat);
  DocumentReference<Map<String, dynamic>> claimRef(String user) =>
      db.doc('activeSeatClaims/$user');
  DocumentReference<Map<String, dynamic>> activeRef(String user) =>
      db.doc('users/$user/activeSession/current');

  Future<void> createCommunity(String title, {String? parentSig}) async {
    final user = uid;
    if (title.trim().isEmpty || title.trim().length > 80) {
      throw const StudyFailure('Enter a name of 1–80 characters.');
    }
    if (parentSig == null) {
      await db.collection('sigs').add({
        'name': title.trim(),
        'category': 'Study',
        'description': 'Learn together in $title.',
        'ownerId': user,
        'status': 'active',
        'membershipRevision': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      await db.collection('subgroups').add({
        'sigId': parentSig,
        'name': title.trim(),
        'description': 'Study $title together.',
        'status': 'active',
      });
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchRoomDocument(
    String subgroup,
    String room,
  ) => roomRef(subgroup, room).snapshots(includeMetadataChanges: true);

  Future<void> releaseRoomSeat({
    required String subgroup,
    required String room,
    required String seat,
    required String claimId,
  }) async {
    final user = uid;
    final active = (await activeRef(
      user,
    ).get(const GetOptions(source: Source.server))).data();
    _sameUser(user);
    if (active != null) {
      throw const StudyFailure(
        'End your session first using Return to session on Home.',
      );
    }
    final result = await releaseSeat(
      subgroupId: subgroup,
      roomId: room,
      seatId: seat,
      expectedClaimId: claimId,
    );
    if (result is SeatLeaseFailed) throw StudyFailure(result.message);
  }

  Future<Map<String, dynamic>> locator(String room) async {
    final value =
        (await db
                .doc('roomDirectory/$room')
                .get(const GetOptions(source: Source.server)))
            .data();
    if (value == null) throw const StudyFailure('Room no longer exists.');
    return value;
  }

  Future<String> _eligible(Transaction tx, String subgroup) async {
    final group = (await tx.get(db.doc('subgroups/$subgroup'))).data();
    if (group == null) throw const StudyFailure('Subgroup no longer exists.');
    final sig = group['sigId'] as String;
    final result = await membership.verifyRoomEligibilityInTransaction(
      transaction: tx,
      sigId: sig,
      subgroupId: subgroup,
    );
    if (result != MembershipCheckResult.member) {
      throw const StudyFailure(
        'Active community and subgroup membership is required.',
      );
    }
    return sig;
  }

  @override
  Future<RoomSnapshot> createRoom({
    required String subgroupId,
    required String title,
  }) async {
    final user = uid;
    final name = title.trim();
    if (name.isEmpty || name.length > 80) {
      throw const StudyFailure('Enter a room title of 1–80 characters.');
    }
    final reference = roomRef(
      subgroupId,
      db.collection('roomDirectory').doc().id,
    );
    await db.runTransaction((tx) async {
      final sig = await _eligible(tx, subgroupId);
      _sameUser(user);
      final data = {
        'roomId': reference.id,
        'subgroupId': subgroupId,
        'sigId': sig,
        'title': name,
        'createdBy': user,
        'hostUid': user,
        'status': 'waiting',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      tx.set(reference, data);
      tx.set(db.doc('roomDirectory/${reference.id}'), {
        'subgroupId': subgroupId,
        'sigId': sig,
      });
      for (final seat in fixedRoomSeatIds) {
        tx.set(reference.collection('seats').doc(seat), {
          'seatId': seat,
          'status': 'available',
        });
      }
    });
    return (await getRoomSnapshot(reference.id))!;
  }

  @override
  Future<List<RoomSnapshot>> listRoomSnapshots(String subgroupId) async =>
      (await db.collection('subgroups/$subgroupId/rooms').get()).docs
          .map((d) => decodeRoom(d.data()))
          .toList();
  @override
  Future<RoomSnapshot?> getRoomSnapshot(String roomId) async {
    final place = await locator(roomId);
    final data = (await roomRef(place['subgroupId'], roomId).get()).data();
    return data == null ? null : decodeRoom(data);
  }

  @override
  Stream<List<RoomSnapshot>> watchRooms(String subgroupId) => db
      .collection('subgroups/$subgroupId/rooms')
      .snapshots()
      .where((value) => value.docs.every((d) => !d.metadata.hasPendingWrites))
      .map((value) => value.docs.map((d) => decodeRoom(d.data())).toList());
  @override
  Stream<RoomSnapshot?> watchRoom(String roomId) async* {
    final place = await locator(roomId);
    yield* roomRef(
      place['subgroupId'],
      roomId,
    ).snapshots().map((d) => d.data() == null ? null : decodeRoom(d.data()!));
  }

  @override
  Stream<List<SeatState>> watchSeats(String roomId) async* {
    final place = await locator(roomId);
    yield* roomRef(place['subgroupId'], roomId)
        .collection('seats')
        .snapshots()
        .map((data) => data.docs.map((d) => decodeSeat(d.data())).toList());
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchSeatDocuments(
    String subgroup,
    String room,
  ) => roomRef(
    subgroup,
    room,
  ).collection('seats').snapshots(includeMetadataChanges: true);
  @override
  Future<List<RoomSummary>> listRooms(String subgroupId) async {
    final rooms = await listRoomSnapshots(subgroupId);
    return Future.wait(
      rooms.map(
        (room) async => _summary(
          room,
          (await roomRef(subgroupId, room.roomId).collection('seats').get())
              .docs
              .map((d) => decodeSeat(d.data()))
              .toList(),
        ),
      ),
    );
  }

  @override
  Future<RoomSummary?> getRoom(String id) async {
    final room = await getRoomSnapshot(id);
    return room == null ? null : _summary(room, await watchSeats(id).first);
  }

  RoomSummary _summary(RoomSnapshot room, List<SeatState> seats) => RoomSummary(
    id: room.roomId,
    subgroupId: room.subgroupId,
    title: room.title,
    occupiedSeats: seats
        .where(
          (s) => s.leaseExpiresAt?.isAfter(DateTime.now().toUtc()) ?? false,
        )
        .length,
  );

  @override
  Future<SeatClaimResult> claimSeat({
    required String subgroupId,
    required String roomId,
    required String seatId,
  }) async {
    return claimSeatWithInvitation(
      subgroupId: subgroupId,
      roomId: roomId,
      seatId: seatId,
    );
  }

  Future<SeatClaimResult> claimSeatWithInvitation({
    required String subgroupId,
    required String roomId,
    required String seatId,
    String? token,
  }) async {
    if (currentUid() == null) {
      return const SeatClaimFailed(SeatClaimFailure.permissionDenied);
    }
    final user = uid;
    if (!fixedRoomSeatIds.contains(seatId)) {
      return const SeatClaimFailed(SeatClaimFailure.seatNotFound);
    }
    try {
      return await db.runTransaction((tx) async {
        if (token != null) {
          final invite = (await tx.get(db.doc('roomInvites/$token'))).data();
          if (invite == null ||
              invite['revoked'] == true ||
              invite['roomId'] != roomId ||
              invite['subgroupId'] != subgroupId ||
              !time(invite['expiresAt']).isAfter(DateTime.now().toUtc())) {
            throw const StudyFailure('Invitation expired or revoked.');
          }
        }
        await _eligible(tx, subgroupId);
        final room = (await tx.get(roomRef(subgroupId, roomId))).data();
        if (room == null) {
          return const SeatClaimFailed(SeatClaimFailure.roomUnavailable);
        }
        final seats = <SeatState>[];
        for (final id in fixedRoomSeatIds) {
          final data = (await tx.get(seatRef(subgroupId, roomId, id))).data();
          if (data == null) {
            return const SeatClaimFailed(SeatClaimFailure.unavailable);
          }
          seats.add(decodeSeat(data));
        }
        final target = seats.firstWhere((s) => s.seatId == seatId);
        final claims = <String, ActiveSeatClaimSnapshot>{};
        for (final owner in {user, ?target.userId}) {
          final data = (await tx.get(claimRef(owner))).data();
          if (data == null) {
            claims[owner] = const ActiveSeatClaimSnapshot.missing();
            continue;
          }
          final reference = ActiveSeatClaimReference(
            subgroupId: data['subgroupId'],
            roomId: data['roomId'],
            seatId: data['seatId'],
          );
          final prior = (await tx.get(
            seatRef(reference.subgroupId, reference.roomId, reference.seatId),
          )).data();
          claims[owner] = ActiveSeatClaimSnapshot.valid(
            reference: reference,
            referencedSeat: prior == null ? null : decodeSeat(prior),
          );
        }
        final profile = (await tx.get(db.doc('users/$user'))).data();
        final activeParticipation = (await tx.get(activeRef(user))).data();
        _sameUser(user);
        final decision = SeatClaimPolicy.evaluate(
          roomStatus: decodeRoom(room).status,
          subgroupId: subgroupId,
          roomId: roomId,
          seats: seats,
          requestedSeatId: seatId,
          userId: user,
          nowUtc: DateTime.now().toUtc(),
          activeClaimsByUser: claims,
        );
        final result = decision.result;
        if (result is SeatClaimSucceeded &&
            !result.wasAlreadyClaimed &&
            activeParticipation != null) {
          throw const StudyFailure(
            'End your saved participation before claiming another seat.',
          );
        }
        if (result is! SeatClaimSucceeded || result.wasAlreadyClaimed) {
          return result;
        }
        for (final cleanup in decision.staleClaimsToClean) {
          tx.delete(claimRef(cleanup.userId));
          final old = cleanup.reference;
          if (cleanup.userId == user &&
              !old.identifies(
                subgroupId: subgroupId,
                roomId: roomId,
                seatId: seatId,
              )) {
            tx.set(seatRef(old.subgroupId, old.roomId, old.seatId), {
              'seatId': old.seatId,
              'status': 'available',
            });
          }
        }
        final claimId = db.collection('roomDirectory').doc().id;
        final expiry = Timestamp.fromDate(result.seat.leaseExpiresAt!);
        tx.set(seatRef(subgroupId, roomId, seatId), {
          'seatId': seatId,
          'status': 'occupied',
          'userId': user,
          'claimedAt': FieldValue.serverTimestamp(),
          'lastRenewedAt': FieldValue.serverTimestamp(),
          'leaseExpiresAt': expiry,
          'claimId': claimId,
          'displayName': profile?['displayName'] ?? 'Study mate',
          'avatarId': profile?['avatarId'] ?? 'default',
        });
        tx.set(claimRef(user), {
          'userId': user,
          'subgroupId': subgroupId,
          'roomId': roomId,
          'seatId': seatId,
          'claimId': claimId,
          'leaseExpiresAt': expiry,
        });
        return result;
      });
    } on StudyFailure catch (error) {
      return SeatClaimFailed(
        error.message.startsWith('Active community')
            ? SeatClaimFailure.membershipRequired
            : error.message.startsWith('End your saved')
            ? SeatClaimFailure.alreadySeated
            : SeatClaimFailure.unavailable,
      );
    } on FirebaseException catch (error) {
      return SeatClaimFailed(
        error.code == 'permission-denied'
            ? SeatClaimFailure.permissionDenied
            : SeatClaimFailure.unavailable,
      );
    }
  }

  @override
  Future<SeatLeaseResult> releaseSeat({
    required String subgroupId,
    required String roomId,
    required String seatId,
    required String expectedClaimId,
  }) => _leaseResult(subgroupId, roomId, seatId, expectedClaimId, true);
  @override
  Future<SeatLeaseResult> renewSeatLease({
    required String subgroupId,
    required String roomId,
    required String seatId,
    required String expectedClaimId,
  }) => _leaseResult(subgroupId, roomId, seatId, expectedClaimId, false);

  Future<SeatLeaseResult> _leaseResult(
    String subgroup,
    String room,
    String seat,
    String claim,
    bool release,
  ) async {
    if (currentUid() == null) {
      return const SeatLeaseFailed(
        SeatLeaseFailure.notAuthenticated,
        'Please sign in again.',
      );
    }
    try {
      await updateLease(
        subgroup: subgroup,
        room: room,
        seat: seat,
        expectedClaimId: claim,
        release: release,
      );
      return const SeatLeaseSucceeded();
    } on StudyFailure catch (error) {
      final reason = error.message.startsWith('Your seat changed')
          ? SeatLeaseFailure.seatChanged
          : error.message.startsWith('Seat lease expired')
          ? SeatLeaseFailure.leaseExpired
          : error.message.startsWith('Active community')
          ? SeatLeaseFailure.membershipRequired
          : SeatLeaseFailure.unavailable;
      return SeatLeaseFailed(reason, error.message);
    } on FirebaseException catch (error) {
      return SeatLeaseFailed(
        error.code == 'permission-denied'
            ? SeatLeaseFailure.permissionDenied
            : SeatLeaseFailure.unavailable,
        'Seat operation could not be confirmed. Recheck before retrying.',
      );
    }
  }

  /// Expected claim ID prevents a delayed release/renew affecting a later claim.
  Future<void> updateLease({
    required String subgroup,
    required String room,
    required String seat,
    required String expectedClaimId,
    bool release = false,
  }) async {
    final user = uid;
    await db.runTransaction((tx) async {
      if (!release) await _eligible(tx, subgroup);
      final reference = seatRef(subgroup, room, seat);
      final data = (await tx.get(reference)).data();
      final claim = (await tx.get(claimRef(user))).data();
      _sameUser(user);
      if (release && (data?['status'] == 'available' || claim == null)) return;
      if (data?['userId'] != user ||
          data?['claimId'] != expectedClaimId ||
          claim?['claimId'] != expectedClaimId) {
        throw const StudyFailure(
          'Your seat changed. Reopen the room to check it.',
        );
      }
      if (release) {
        tx.set(reference, {'seatId': seat, 'status': 'available'});
        tx.delete(claimRef(user));
      } else {
        if (!time(data!['leaseExpiresAt']).isAfter(DateTime.now().toUtc())) {
          throw const StudyFailure('Seat lease expired. Choose a seat again.');
        }
        final expiry = Timestamp.fromDate(
          DateTime.now().toUtc().add(seatLeaseDuration),
        );
        tx.update(reference, {
          'lastRenewedAt': FieldValue.serverTimestamp(),
          'leaseExpiresAt': expiry,
        });
        tx.update(claimRef(user), {'leaseExpiresAt': expiry});
      }
    });
  }

  Future<String> beginSession({
    required String subgroup,
    required String room,
    required String seat,
    required String claimId,
    required String goal,
    required bool demo,
  }) async {
    final user = uid;
    if (goal.trim().isEmpty || goal.trim().length > 160) {
      throw const StudyFailure('Set a goal of 1–160 characters.');
    }
    final fresh = db.collection('roomSessions').doc();
    return db.runTransaction((tx) async {
      await _eligible(tx, subgroup);
      final roomData = (await tx.get(roomRef(subgroup, room))).data()!;
      final seatData = (await tx.get(seatRef(subgroup, room, seat))).data()!;
      final currentActive = (await tx.get(activeRef(user))).data();
      final oldId = roomData['sessionId'] as String?;
      final oldSessionRaw = oldId == null
          ? null
          : (await tx.get(db.doc('roomSessions/$oldId'))).data();
      final oldSession = oldSessionRaw == null
          ? null
          : sessionSchedule(oldSessionRaw);
      _sameUser(user);
      final now = DateTime.now().toUtc();
      if (seatData['userId'] != user ||
          seatData['claimId'] != claimId ||
          !time(seatData['leaseExpiresAt']).isAfter(now)) {
        throw const StudyFailure('A valid seat is required.');
      }
      if (currentActive != null) {
        if (currentActive['roomId'] == room &&
            currentActive['claimId'] == claimId) {
          return currentActive['sessionId'] as String;
        }
        throw const StudyFailure(
          'Finish your existing session before starting another.',
        );
      }
      final running =
          oldSession != null && time(oldSession['breakEndsAt']).isAfter(now);
      final id = running ? oldId! : fresh.id;
      final priorCompletion = await tx.get(
        db.doc('users/$user/completions/$id'),
      );
      if (priorCompletion.exists) {
        throw const StudyFailure(
          'Your participation in this cycle is already saved. Wait for the next cycle.',
        );
      }
      if (!running) {
        if (roomData['hostUid'] != user) {
          throw const StudyFailure('Ask the host to start the shared cycle.');
        }
        tx.set(fresh, {
          'sessionId': id,
          'roomId': room,
          'subgroupId': subgroup,
          'hostUid': user,
          'roomTitle': roomData['title'],
          'startsAt': FieldValue.serverTimestamp(),
          'isDemo': demo,
        });
        tx.update(roomRef(subgroup, room), {
          'sessionId': id,
          'status': 'active',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      tx.set(activeRef(user), {
        'sessionId': id,
        'roomId': room,
        'subgroupId': subgroup,
        'seatId': seat,
        'claimId': claimId,
        'userId': user,
        'goalText': goal.trim(),
        'joinedAt': FieldValue.serverTimestamp(),
      });
      return id;
    });
  }

  Future<ActiveRoomSession?> revalidateSession() async {
    final user = uid;
    final active = (await activeRef(
      user,
    ).get(const GetOptions(source: Source.server))).data();
    if (active == null) return null;
    final membershipResult = await membership.checkSubgroupMembership(
      sigId: (await locator(active['roomId']))['sigId'],
      subgroupId: active['subgroupId'],
    );
    if (membershipResult != MembershipCheckResult.member) {
      throw const StudyFailure('Membership could not be confirmed.');
    }
    final currentRoom = (await roomRef(
      active['subgroupId'],
      active['roomId'],
    ).get(const GetOptions(source: Source.server))).data();
    if (currentRoom == null ||
        currentRoom['status'] == 'closed' ||
        currentRoom['sessionId'] != active['sessionId']) {
      throw const StudyFailure(
        'Room closed or cycle changed. Review and end your saved participation.',
      );
    }
    final sessionRaw =
        (await db
                .doc('roomSessions/${active['sessionId']}')
                .get(const GetOptions(source: Source.server)))
            .data();
    final seat = (await seatRef(
      active['subgroupId'],
      active['roomId'],
      active['seatId'],
    ).get(const GetOptions(source: Source.server))).data();
    final session = sessionRaw == null ? null : sessionSchedule(sessionRaw);
    _sameUser(user);
    if (session == null ||
        seat == null ||
        seat['claimId'] != active['claimId'] ||
        seat['userId'] != user ||
        !time(seat['leaseExpiresAt']).isAfter(DateTime.now().toUtc())) {
      throw const StudyFailure(
        'Seat lost or expired. End this participation before joining again.',
      );
    }
    return _activeModel(active, session, seat, true);
  }

  @override
  Stream<ActiveRoomSession?> watchCurrentUserActiveSession() {
    final user = uid;
    return activeRef(user)
        .snapshots(includeMetadataChanges: true)
        .where((d) => !d.metadata.hasPendingWrites)
        .asyncMap((snapshot) async {
          if (currentUid() != user) return null;
          final active = snapshot.data();
          if (active == null) return null;
          final sessionRaw =
              (await db.doc('roomSessions/${active['sessionId']}').get())
                  .data();
          final session = sessionRaw == null
              ? null
              : sessionSchedule(sessionRaw);
          final seatSnapshot = await seatRef(
            active['subgroupId'],
            active['roomId'],
            active['seatId'],
          ).get();
          final seat = seatSnapshot.data();
          if (session == null || seat == null) {
            throw const StudyFailure('Session data is unavailable.');
          }
          if (currentUid() != user) return null;
          return _activeModel(
            active,
            session,
            seat,
            !snapshot.metadata.isFromCache &&
                !seatSnapshot.metadata.isFromCache &&
                seat['claimId'] == active['claimId'],
          );
        });
  }

  ActiveRoomSession _activeModel(
    Map<String, dynamic> active,
    Map<String, dynamic> session,
    Map<String, dynamic> seat,
    bool verified,
  ) => ActiveRoomSession(
    sessionId: active['sessionId'],
    roomId: active['roomId'],
    subgroupId: active['subgroupId'],
    roomTitle: session['roomTitle'],
    seatId: active['seatId'],
    userId: active['userId'],
    goalText: active['goalText'],
    isDemo: session['isDemo'],
    startsAt: time(session['startsAt']),
    focusEndsAt: time(session['focusEndsAt']),
    breakEndsAt: time(session['breakEndsAt']),
    participationSeat: decodeSeat(seat),
    seatLeaseVerified: verified,
    nowUtc: DateTime.now().toUtc(),
  );

  Future<CompletionRecord> finishSession(
    GoalOutcome outcome, {
    String? expectedSessionId,
  }) async {
    final user = uid;
    final active = (await activeRef(
      user,
    ).get(const GetOptions(source: Source.server))).data();
    if (active == null) {
      if (expectedSessionId != null) {
        final saved =
            (await db
                    .doc('users/$user/completions/$expectedSessionId')
                    .get(const GetOptions(source: Source.server)))
                .data();
        _sameUser(user);
        if (saved != null) return decodeCompletion(saved);
      }
      throw const StudyFailure(
        'No active session. Check Progress for a saved completion.',
      );
    }
    final id = active['sessionId'] as String;
    if (expectedSessionId != null && id != expectedSessionId) {
      throw const StudyFailure('Session changed. Reopen it before ending.');
    }
    final destination = db.doc('users/$user/completions/$id');
    await db.runTransaction((tx) async {
      final existing = await tx.get(destination);
      final current = (await tx.get(activeRef(user))).data();
      if (existing.exists) return;
      if (current == null || current['sessionId'] != id) {
        throw const StudyFailure('Session changed. Reopen it.');
      }
      final sessionRaw = (await tx.get(db.doc('roomSessions/$id'))).data()!;
      final session = sessionSchedule(sessionRaw);
      final seat = (await tx.get(
        seatRef(active['subgroupId'], active['roomId'], active['seatId']),
      )).data();
      _sameUser(user);
      final now = DateTime.now().toUtc();
      final joined = time(active['joinedAt']);
      final focusEnd = time(session['focusEndsAt']);
      final until = now.isBefore(focusEnd) ? now : focusEnd;
      final valid =
          seat?['userId'] == user &&
          seat?['claimId'] == active['claimId'] &&
          time(seat!['leaseExpiresAt']).isAfter(now);
      // Conservative elapsed focus credit while the same claim is valid. An
      // expired/reassigned lease yields zero; this does not measure attention.
      final credited = valid
          ? max(0, until.difference(joined).inSeconds - 1)
          : 0;
      tx.set(destination, {
        'recordId': id,
        'userId': user,
        'sessionId': id,
        'goalText': active['goalText'],
        'endedAt': FieldValue.serverTimestamp(),
        'creditedSeconds': credited,
        'timerStatus': now.isBefore(time(session['breakEndsAt']))
            ? 'endedEarly'
            : 'completed',
        'goalOutcome': outcome.name,
        'isDemo': session['isDemo'],
      });
      tx.delete(activeRef(user));
    });
    return decodeCompletion((await destination.get()).data()!);
  }

  @override
  Future<CompletionHistoryPage> loadCurrentUserHistoryPage({
    String? pageToken,
  }) async {
    final user = uid;
    Query<Map<String, dynamic>> query = db
        .collection('users/$user/completions')
        .orderBy(FieldPath.documentId)
        .limit(30);
    if (pageToken != null) query = query.startAfter([pageToken]);
    final data = await query.get(const GetOptions(source: Source.server));
    _sameUser(user);
    return CompletionHistoryPage(
      records: data.docs.map((d) => decodeCompletion(d.data())),
      nextPageToken: data.docs.length == 30 ? data.docs.last.id : null,
    );
  }

  @override
  Future<CompletionHistorySummary> loadCurrentUserSummary() async {
    final user = uid;
    final records =
        (await db
                .collection('users/$user/completions')
                .get(const GetOptions(source: Source.server)))
            .docs
            .map((d) => decodeCompletion(d.data()))
            .where((r) => !r.isDemo);
    _sameUser(user);
    return CompletionHistorySummary(
      creditedSeconds: records.fold(0, (total, r) => total + r.creditedSeconds),
      completedSessionCount: records
          .where((r) => r.timerStatus == TimerCompletionStatus.completed)
          .length,
    );
  }

  void _sameUser(String expected) {
    if (currentUid() != expected) {
      throw const StudyFailure('Account changed. Please reopen the page.');
    }
  }
}

DateTime time(dynamic value) => (value as Timestamp).toDate().toUtc();
RoomSnapshot decodeRoom(Map<String, dynamic> data) => RoomSnapshot(
  roomId: data['roomId'],
  subgroupId: data['subgroupId'],
  title: data['title'],
  createdBy: data['createdBy'],
  hostUid: data['hostUid'],
  status: RoomStatus.values.byName(data['status']),
  createdAt: time(data['createdAt']),
  updatedAt: time(data['updatedAt']),
);
SeatState decodeSeat(Map<String, dynamic> data) => SeatState(
  seatId: data['seatId'],
  status: SeatStatus.values.byName(data['status']),
  userId: data['userId'],
  claimedAt: data['claimedAt'] == null ? null : time(data['claimedAt']),
  leaseExpiresAt: data['leaseExpiresAt'] == null
      ? null
      : time(data['leaseExpiresAt']),
  lastRenewedAt: data['lastRenewedAt'] == null
      ? null
      : time(data['lastRenewedAt']),
);
CompletionRecord decodeCompletion(Map<String, dynamic> data) =>
    CompletionRecord(
      recordId: data['recordId'],
      userId: data['userId'],
      sessionId: data['sessionId'],
      goalText: data['goalText'],
      endedAt: time(data['endedAt']),
      creditedSeconds: data['creditedSeconds'],
      timerStatus: TimerCompletionStatus.values.byName(data['timerStatus']),
      goalOutcome: GoalOutcome.values.byName(data['goalOutcome']),
      isDemo: data['isDemo'],
    );

/// Phase ends derive from one server-recorded start, with fixed approved lengths.
Map<String, dynamic> sessionSchedule(Map<String, dynamic> data) {
  final start = time(data['startsAt']);
  final demo = data['isDemo'] == true;
  return {
    ...data,
    'focusEndsAt': Timestamp.fromDate(
      start.add(Duration(seconds: demo ? 45 : 1500)),
    ),
    'breakEndsAt': Timestamp.fromDate(
      start.add(Duration(seconds: demo ? 60 : 1800)),
    ),
  };
}
