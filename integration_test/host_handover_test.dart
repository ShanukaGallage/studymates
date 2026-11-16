import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:integration_test/integration_test.dart';
import 'package:studymates/firebase_options.dart';
import 'package:studymates/core/models/completion_record.dart';
import 'package:studymates/features/study/data/firestore_invitation_service.dart';
import 'package:studymates/features/communities/data/firestore_membership_repository.dart';
import 'package:studymates/features/communities/data/spark_membership_cleanup.dart';
import 'package:studymates/features/rooms/data/seat_claim_result.dart';
import 'package:studymates/features/study/data/firestore_study_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'oldest-seat handover preserves cycle and new host manages invites',
    (tester) async {
      const host = String.fromEnvironment('STUDYMATES_EMULATOR_HOST');
      if (host.isEmpty) {
        throw StateError(
          'This test requires STUDYMATES_EMULATOR_HOST and local emulators.',
        );
      }
      final suffix = DateTime.now().microsecondsSinceEpoch;
      final repos = <FirestoreStudyRepository>[];
      final memberships = <FirestoreMembershipRepository>[];
      final databases = <FirebaseFirestore>[];
      for (var i = 0; i < 3; i++) {
        final app = await Firebase.initializeApp(
          name: 'study-$suffix-$i',
          options: kIsWeb
              ? DefaultFirebaseOptions.android
              : DefaultFirebaseOptions.currentPlatform,
        );
        final auth = FirebaseAuth.instanceFor(app: app);
        await auth.useAuthEmulator(host, 9099, automaticHostMapping: false);
        final db = FirebaseFirestore.instanceFor(app: app);
        db.settings = const Settings(persistenceEnabled: false);
        db.useFirestoreEmulator(host, 8080, automaticHostMapping: false);
        await auth.createUserWithEmailAndPassword(
          email: 'study-$suffix-$i@example.test',
          password: 'study-test-password',
        );
        await db.doc('users/${auth.currentUser!.uid}').set({
          'displayName': 'Learner $i',
          'avatarId': 'default',
          'interestIds': <String>[],
        });
        final membership = FirestoreMembershipRepository(
          firestore: db,
          currentUserId: () => auth.currentUser?.uid,
        );
        memberships.add(membership);
        databases.add(db);
        repos.add(
          FirestoreStudyRepository(
            db: db,
            membership: membership,
            currentUid: () => auth.currentUser?.uid,
          ),
        );
      }
      final a = repos[0], b = repos[1], c = repos[2];
      await a.createCommunity('Integration $suffix');
      final sig =
          (await databases[0]
                  .collection('sigs')
                  .where('ownerId', isEqualTo: a.uid)
                  .get())
              .docs
              .single
              .id;
      await memberships[1].joinSig(sigId: sig);
      await memberships[2].joinSig(sigId: sig);
      await a.createCommunity('Topic $suffix', parentSig: sig);
      final subgroup =
          (await databases[0]
                  .collection('subgroups')
                  .where('sigId', isEqualTo: sig)
                  .get())
              .docs
              .single
              .id;
      await memberships[0].joinSubgroup(sigId: sig, subgroupId: subgroup);
      await memberships[1].joinSubgroup(sigId: sig, subgroupId: subgroup);
      await memberships[2].joinSubgroup(sigId: sig, subgroupId: subgroup);
      final room = await a.createRoom(
        subgroupId: subgroup,
        title: 'Handover',
        capacity: 3,
      );
      final id = room.roomId;
      final ref = a.roomRef(subgroup, id);
      for (var i = 0; i < repos.length; i++) {
        expect(
          await repos[i].claimSeat(
            subgroupId: subgroup,
            roomId: id,
            seatId: 'seat-${i + 1}',
          ),
          isA<SeatClaimSucceeded>(),
        );
      }
      final own = (await a.claimRef(a.uid).get()).data()!;
      final session = await a.beginSession(
        subgroup: subgroup,
        room: id,
        seat: 'seat-1',
        claimId: own['claimId'],
        goal: 'Preserve this cycle',
        demo: true,
      );
      final issuer = FirestoreInvitationService(
        study: a,
        catalog: () async => throw UnimplementedError(),
      );
      final managerB = FirestoreInvitationService(
        study: b,
        catalog: () async => throw UnimplementedError(),
      );
      final managerC = FirestoreInvitationService(
        study: c,
        catalog: () async => throw UnimplementedError(),
      );
      final code = await issuer.issue(subgroup, id);
      await a.finishSession(GoalOutcome.unfinished, expectedSessionId: session);
      await a.releaseRoomSeat(
        subgroup: subgroup,
        room: id,
        seat: 'seat-1',
        claimId: own['claimId'],
      );
      expect((await ref.get()).data()!['hostUid'], b.uid);
      expect((await ref.get()).data()!['sessionId'], session);
      expect(
        (await managerB.watchRoomInvitations(subgroup, id).first).single.token,
        code,
      );
      await managerB.revokeInvitation(code);
      await managerB.revokeInvitation(code); // idempotent retry
      expect((await issuer.watchInvitation(code).first)!.revoked, isTrue);
      await expectLater(
        managerC.revokeInvitation(await issuer.issue(subgroup, id)),
        throwsA(isA<FirebaseException>()),
      );
      // Returning to a desk puts the former host last rather than reclaiming priority.
      expect(
        await a.claimSeat(subgroupId: subgroup, roomId: id, seatId: 'seat-1'),
        isA<SeatClaimSucceeded>(),
      );
      final bClaim = (await b.claimRef(b.uid).get()).data()!;
      await b.releaseRoomSeat(
        subgroup: subgroup,
        room: id,
        seat: 'seat-2',
        claimId: bClaim['claimId'],
      );
      expect((await ref.get()).data()!['hostUid'], c.uid);
      final cClaim = (await c.claimRef(c.uid).get()).data()!;
      await c.releaseRoomSeat(
        subgroup: subgroup,
        room: id,
        seat: 'seat-3',
        claimId: cClaim['claimId'],
      );
      expect((await ref.get()).data()!['hostUid'], a.uid);
      // SIG departure also transfers hosting if another eligible member remains.
      expect(
        await b.claimSeat(subgroupId: subgroup, roomId: id, seatId: 'seat-2'),
        isA<SeatClaimSucceeded>(),
      );
      final departure = await memberships[0].beginSubgroupLeave(
        sigId: sig,
        subgroupId: subgroup,
      );
      await SparkMembershipCleanup(a).complete(departure.requestId);
      await memberships[0].finalizeMembershipRemoval(departure.requestId);
      expect((await ref.get()).data()!['hostUid'], b.uid);
      expect((await ref.get()).data()!['status'], 'active');
    },
  );
}
