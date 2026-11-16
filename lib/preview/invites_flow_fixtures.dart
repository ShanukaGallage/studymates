import 'dart:async';

import '../core/models/community_models.dart';
import '../features/invites/data/invitation_service.dart';
import 'invitation_fixtures.dart';

enum InvitesFlowScenario {
  valid,
  invalid,
  expired,
  revoked,
  fullRoom,
  membershipRequired,
  unavailable,
  seatRace,
  networkError,
  admissionError,
  loading,
  longText,
}

/// Adds UI scenarios by delegating all admission decisions to M3's fixture.
class InvitesFlowFixtureService implements InvitationService {
  InvitesFlowFixtureService(this.scenario) {
    _delegate = FixtureInvitationService(
      fixtures: scenario == InvitesFlowScenario.longText
          ? [
              InvitationFixture(
                token: InvitationFixtures.validToken,
                state: InvitationFixtureState.valid,
                room: RoomSummary(
                  id: 'long-room',
                  subgroupId: 'long-subgroup',
                  title:
                      'A study room for a detailed discussion of sensors and microcontroller experiments ' *
                      3,
                  occupiedSeats: 2,
                ),
                sig: SigSummary(
                  id: 'long-sig',
                  name:
                      'A community for learners exploring connected devices together ' *
                      3,
                  category: 'Technology',
                  description: '',
                  ownerId: 'fixture-owner',
                  membership: MembershipState.joined,
                ),
                subgroup: SubgroupSummary(
                  id: 'long-subgroup',
                  sigId: 'long-sig',
                  name:
                      'ESP32 projects with practical experiments and shared learning goals ' *
                      3,
                  description: '',
                  membership: MembershipState.joined,
                ),
              ),
            ]
          : null,
    );
  }
  final InvitesFlowScenario scenario;
  late FixtureInvitationService _delegate;
  bool _failedResolve = false;
  bool _failedAdmission = false;

  String get token => switch (scenario) {
    InvitesFlowScenario.invalid => InvitationFixtures.invalidToken,
    InvitesFlowScenario.expired => InvitationFixtures.expiredToken,
    InvitesFlowScenario.revoked => InvitationFixtures.revokedToken,
    InvitesFlowScenario.fullRoom => InvitationFixtures.fullRoomToken,
    InvitesFlowScenario.membershipRequired =>
      InvitationFixtures.membershipRequiredToken,
    InvitesFlowScenario.unavailable => InvitationFixtures.unavailableToken,
    _ => InvitationFixtures.validToken,
  };

  Future<void> completeMembershipForPreview(InvitationPreview preview) async {
    // Explicit fixture-only membership action. No real identity/enrollment.
    final original = InvitationFixtures.all.firstWhere(
      (item) => item.token == token,
    );
    _delegate = FixtureInvitationService(
      fixtures: [
        InvitationFixture(
          token: token,
          state: InvitationFixtureState.valid,
          room: original.room,
          sig: original.sig.withMembership(MembershipState.joined),
          subgroup: original.subgroup.withMembership(MembershipState.joined),
        ),
      ],
    );
  }

  @override
  Future<InvitationPreviewResult> resolveInvitation(String opaqueToken) async {
    if (scenario == InvitesFlowScenario.loading) {
      return Completer<InvitationPreviewResult>().future;
    }
    if (scenario == InvitesFlowScenario.networkError && !_failedResolve) {
      _failedResolve = true;
      throw StateError('Fixture network error.');
    }
    return _delegate.resolveInvitation(opaqueToken);
  }

  @override
  Future<InvitationAdmissionResult> admitInvitation({
    required String opaqueToken,
    required bool membershipConsentGranted,
  }) async {
    if (scenario == InvitesFlowScenario.seatRace) {
      while (_delegate.claimSeatForOtherUser(opaqueToken)) {
        /* Fill after preview. */
      }
    }
    if (scenario == InvitesFlowScenario.admissionError && !_failedAdmission) {
      _failedAdmission = true;
      throw StateError('Fixture admission network error.');
    }
    return _delegate.admitInvitation(
      opaqueToken: opaqueToken,
      membershipConsentGranted: membershipConsentGranted,
    );
  }
}
