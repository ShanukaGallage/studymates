import 'package:flutter_test/flutter_test.dart';
import 'package:studymates/core/models/community_models.dart';
import 'package:studymates/features/invites/data/invitation_service.dart';
import 'package:studymates/preview/invitation_fixtures.dart';

void main() {
  group('FixtureInvitationService preview', () {
    test(
      'valid fixture returns room, SIG, and subgroup without reserving',
      () async {
        final service = FixtureInvitationService();

        final result = await service.resolveInvitation(
          InvitationFixtures.validToken,
        );

        expect(result.status, InvitationPreviewStatus.ready);
        expect(result.preview?.room.occupiedSeats, 2);
        expect(result.preview?.sig.id, 'sig-iot');
        expect(result.preview?.subgroup.id, 'subgroup-esp32');
        expect(service.successfulAdmissionCount, 0);
        final secondPreview = await service.resolveInvitation(
          InvitationFixtures.validToken,
        );
        expect(secondPreview.preview?.room.occupiedSeats, 2);
      },
    );

    test(
      'returns invalid, expired/revoked and unavailable fixture outcomes',
      () async {
        final service = FixtureInvitationService();

        expect(
          (await service.resolveInvitation(InvitationFixtures.invalidToken))
              .status,
          InvitationPreviewStatus.invalid,
        );
        expect(
          (await service.resolveInvitation(InvitationFixtures.expiredToken))
              .status,
          InvitationPreviewStatus.expiredOrRevoked,
        );
        expect(
          (await service.resolveInvitation(InvitationFixtures.revokedToken))
              .status,
          InvitationPreviewStatus.expiredOrRevoked,
        );
        expect(
          (await service.resolveInvitation(InvitationFixtures.unavailableToken))
              .status,
          InvitationPreviewStatus.unavailable,
        );
        expect(
          (await service.resolveInvitation('malformed')).status,
          InvitationPreviewStatus.invalid,
        );
      },
    );

    test(
      'membership-required and full-room fixtures include preview details',
      () async {
        final service = FixtureInvitationService();
        final membership = await service.resolveInvitation(
          InvitationFixtures.membershipRequiredToken,
        );
        final full = await service.resolveInvitation(
          InvitationFixtures.fullRoomToken,
        );

        expect(membership.status, InvitationPreviewStatus.membershipRequired);
        expect(membership.preview?.sig.membership.name, 'notJoined');
        expect(membership.preview?.subgroup.membership.name, 'notJoined');
        expect(full.status, InvitationPreviewStatus.fullRoom);
        expect(full.preview?.room.isFull, isTrue);
      },
    );
  });

  group('FixtureInvitationService admission', () {
    test('preview then another claim makes Join return fullRoom without success', () async {
      final service = FixtureInvitationService();
      final preview = await service.resolveInvitation(
        InvitationFixtures.validToken,
      );
      expect(preview.status, InvitationPreviewStatus.ready);
      expect(preview.preview?.room.occupiedSeats, 2);
      expect(service.successfulAdmissionCount, 0);

      // Put this fixture at five occupied seats, then simulate the race winner.
      final raceService = FixtureInvitationService(
        fixtures: [
          InvitationFixture(
            token: InvitationFixtures.validToken,
            state: InvitationFixtureState.valid,
            room: const RoomSummary(
              id: 'room-race',
              subgroupId: 'subgroup-esp32',
              title: 'Race room',
              occupiedSeats: 5,
            ),
            sig: preview.preview!.sig,
            subgroup: preview.preview!.subgroup,
          ),
        ],
      );
      final racePreview = await raceService.resolveInvitation(
        InvitationFixtures.validToken,
      );
      expect(racePreview.status, InvitationPreviewStatus.ready);
      expect(racePreview.preview?.room.occupiedSeats, 5);
      expect(
        raceService.claimSeatForOtherUser(InvitationFixtures.validToken),
        isTrue,
      );

      final admission = await raceService.admitInvitation(
        opaqueToken: InvitationFixtures.validToken,
        membershipConsentGranted: false,
      );
      expect(admission.status, InvitationAdmissionStatus.fullRoom);
      expect(raceService.successfulAdmissionCount, 0);
    });

    test('explicit admission succeeds only through admission method', () async {
      final service = FixtureInvitationService();
      expect(service.successfulAdmissionCount, 0);

      final result = await service.admitInvitation(
        opaqueToken: InvitationFixtures.validToken,
        membershipConsentGranted: false,
      );

      expect(result.status, InvitationAdmissionStatus.admitted);
      expect(service.successfulAdmissionCount, 1);
    });

    test(
      'membership consent alone never enrolls or admits a non-member',
      () async {
        final service = FixtureInvitationService();

        final result = await service.admitInvitation(
          opaqueToken: InvitationFixtures.membershipRequiredToken,
          membershipConsentGranted: true,
        );

        expect(result.status, InvitationAdmissionStatus.membershipRequired);
        expect(service.successfulAdmissionCount, 0);
      },
    );

    test(
      'revalidates invalid, expired, revoked, unavailable and full outcomes',
      () async {
        final service = FixtureInvitationService();

        Future<InvitationAdmissionStatus> join(String token) async =>
            (await service.admitInvitation(
              opaqueToken: token,
              membershipConsentGranted: false,
            )).status;

        expect(
          await join(InvitationFixtures.invalidToken),
          InvitationAdmissionStatus.invalid,
        );
        expect(
          await join(InvitationFixtures.expiredToken),
          InvitationAdmissionStatus.expiredOrRevoked,
        );
        expect(
          await join(InvitationFixtures.revokedToken),
          InvitationAdmissionStatus.expiredOrRevoked,
        );
        expect(
          await join(InvitationFixtures.unavailableToken),
          InvitationAdmissionStatus.unavailable,
        );
        expect(
          await join(InvitationFixtures.fullRoomToken),
          InvitationAdmissionStatus.fullRoom,
        );
        expect(await join('not-a-token'), InvitationAdmissionStatus.invalid);
        expect(service.successfulAdmissionCount, 0);
      },
    );
  });
}
