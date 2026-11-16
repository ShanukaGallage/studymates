import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:integration_test/integration_test.dart';
import 'package:studymates/firebase_options.dart';
import 'package:studymates/core/models/completion_record.dart';
import 'package:studymates/core/models/community_models.dart';
import 'package:studymates/features/study/data/firestore_invitation_service.dart';
import 'package:studymates/features/invites/data/invitation_service.dart';
import 'package:studymates/features/invites/data/invitation_token.dart';
import 'package:studymates/features/communities/data/firestore_membership_repository.dart';
import 'package:studymates/features/rooms/data/seat_claim_result.dart';
import 'package:studymates/features/study/data/firestore_study_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'two real SDK clients: room race, leases, shared session, recovery and unique history',
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
      for (var i = 0; i < 2; i++) {
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
      final a = repos[0], b = repos[1];
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
      final room = await a.createRoom(
        subgroupId: subgroup,
        title: 'Atomic room',
      );
      expect((await b.watchRooms(subgroup).first).single.roomId, room.roomId);
      final race = await Future.wait([
        for (final r in repos)
          r.claimSeat(
            subgroupId: subgroup,
            roomId: room.roomId,
            seatId: 'seat-1',
          ),
      ]);
      expect(race.whereType<SeatClaimSucceeded>().length, 1);
      final loser = race[0] is SeatClaimSucceeded ? 1 : 0;
      expect(
        await repos[loser].claimSeat(
          subgroupId: subgroup,
          roomId: room.roomId,
          seatId: 'seat-2',
        ),
        isA<SeatClaimSucceeded>(),
      );
      final other = await a.createRoom(
        subgroupId: subgroup,
        title: 'Other room',
      );
      final duplicate = await a.claimSeat(
        subgroupId: subgroup,
        roomId: other.roomId,
        seatId: 'seat-1',
      );
      expect(
        (duplicate as SeatClaimFailed).failure,
        SeatClaimFailure.alreadySeated,
      );
      final invitation = FirestoreInvitationService(
        study: a,
        catalog: () async => CommunityCatalog(
          profile: UserProfile(id: a.uid, displayName: 'Learner'),
          sigs: [
            SigSummary(
              id: sig,
              name: 'Integration',
              category: 'Study',
              description: '',
              ownerId: a.uid,
              membership: MembershipState.joined,
            ),
          ],
          subgroups: [
            SubgroupSummary(
              id: subgroup,
              sigId: sig,
              name: 'Topic',
              description: '',
              membership: MembershipState.joined,
            ),
          ],
        ),
      );
      final token = await invitation.issue(subgroup, room.roomId);
      expect(InvitationTokenParser.isOpaqueToken(token), isTrue);
      expect(
        (await invitation.resolveInvitation(token)).status,
        InvitationPreviewStatus.ready,
      );
      await databases[0].doc('roomInvites/$token').update({'revoked': true});
      expect(
        (await invitation.admitInvitation(
          opaqueToken: token,
          membershipConsentGranted: true,
        )).status,
        InvitationAdmissionStatus.expiredOrRevoked,
      );
      final claims = [
        for (final r in repos) (await r.claimRef(r.uid).get()).data()!,
      ];
      await expectLater(
        a.updateLease(
          subgroup: subgroup,
          room: room.roomId,
          seat: claims[0]['seatId'],
          expectedClaimId: 'stale',
        ),
        throwsA(isA<StudyFailure>()),
      );
      await a.updateLease(
        subgroup: subgroup,
        room: room.roomId,
        seat: claims[0]['seatId'],
        expectedClaimId: claims[0]['claimId'],
      );
      final session = await a.beginSession(
        subgroup: subgroup,
        room: room.roomId,
        seat: claims[0]['seatId'],
        claimId: claims[0]['claimId'],
        goal: 'Host task',
        demo: true,
      );
      expect(
        await b.beginSession(
          subgroup: subgroup,
          room: room.roomId,
          seat: claims[1]['seatId'],
          claimId: claims[1]['claimId'],
          goal: 'Guest task',
          demo: false,
        ),
        session,
      );
      expect((await b.revalidateSession())!.sessionId, session);
      expect(
        (await a.watchCurrentUserActiveSession().first)!.goalText,
        'Host task',
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 3)),
      );
      final saved = await a.finishSession(
        GoalOutcome.unfinished,
        expectedSessionId: session,
      );
      expect(saved.isDemo, isTrue);
      expect(saved.timerStatus, TimerCompletionStatus.endedEarly);
      expect(
        (await a.finishSession(
          GoalOutcome.completed,
          expectedSessionId: session,
        )).recordId,
        saved.recordId,
      );
      expect((await a.loadCurrentUserHistoryPage()).records.length, 1);
      expect((await a.loadCurrentUserSummary()).creditedSeconds, 0);
      expect((await b.loadCurrentUserHistoryPage()).records, isEmpty);
      await expectLater(
        databases[1].doc('users/${a.uid}/completions/$session').get(),
        throwsA(isA<FirebaseException>()),
      );
      await b.finishSession(GoalOutcome.completed, expectedSessionId: session);
      for (var i = 0; i < 2; i++) {
        await repos[i].updateLease(
          subgroup: subgroup,
          room: room.roomId,
          seat: claims[i]['seatId'],
          expectedClaimId: claims[i]['claimId'],
          release: true,
        );
        expect((await repos[i].claimRef(repos[i].uid).get()).exists, isFalse);
      }
    },
  );
}
