import '../core/models/community_models.dart';
import '../features/invites/data/invitation_service.dart';
import '../features/invites/data/invitation_token.dart';

enum InvitationFixtureState {
  valid,
  invalid,
  expired,
  revoked,
  membershipRequired,
  unavailable,
  fullRoom,
}

final class InvitationFixture {
  const InvitationFixture({
    required this.token,
    required this.state,
    required this.room,
    required this.sig,
    required this.subgroup,
  });

  final String token;
  final InvitationFixtureState state;
  final RoomSummary room;
  final SigSummary sig;
  final SubgroupSummary subgroup;
}

const _fixtureSig = SigSummary(
  id: 'sig-iot',
  name: 'IoT Study Group',
  category: 'Technology',
  description: 'Study embedded systems together.',
  ownerId: 'fixture-owner',
  membership: MembershipState.joined,
);

const _fixtureSubgroup = SubgroupSummary(
  id: 'subgroup-esp32',
  sigId: 'sig-iot',
  name: 'ESP32',
  description: 'ESP32 projects and study sessions.',
  membership: MembershipState.joined,
);

/// Named, deterministic invitation cases for scanner and admission consumers.
final class InvitationFixtures {
  InvitationFixtures._();

  static const validToken = 'ABCDEFGHJK23MNPQ';
  static const invalidToken = 'BBCDEFGHJK23MNPQ';
  static const expiredToken = 'CBCDEFGHJK23MNPQ';
  static const revokedToken = 'DBCDEFGHJK23MNPQ';
  static const membershipRequiredToken = 'EBCDEFGHJK23MNPQ';
  static const unavailableToken = 'FBCDEFGHJK23MNPQ';
  static const fullRoomToken = 'GBCDEFGHJK23MNPQ';

  static final List<InvitationFixture> all = List.unmodifiable([
    _fixture(validToken, InvitationFixtureState.valid, occupiedSeats: 2),
    _fixture(invalidToken, InvitationFixtureState.invalid, occupiedSeats: 2),
    _fixture(expiredToken, InvitationFixtureState.expired, occupiedSeats: 2),
    _fixture(revokedToken, InvitationFixtureState.revoked, occupiedSeats: 2),
    _fixture(
      membershipRequiredToken,
      InvitationFixtureState.membershipRequired,
      occupiedSeats: 2,
      joined: false,
    ),
    _fixture(
      unavailableToken,
      InvitationFixtureState.unavailable,
      occupiedSeats: 2,
    ),
    _fixture(fullRoomToken, InvitationFixtureState.fullRoom, occupiedSeats: 6),
  ]);

  static InvitationFixture _fixture(
    String token,
    InvitationFixtureState state, {
    required int occupiedSeats,
    bool joined = true,
  }) => InvitationFixture(
    token: token,
    state: state,
    room: RoomSummary(
      id: 'room-invitation-demo',
      subgroupId: _fixtureSubgroup.id,
      title: 'ESP32 Study Room',
      occupiedSeats: occupiedSeats,
    ),
    sig: _fixtureSig.withMembership(
      joined ? MembershipState.joined : MembershipState.notJoined,
    ),
    subgroup: _fixtureSubgroup.withMembership(
      joined ? MembershipState.joined : MembershipState.notJoined,
    ),
  );
}

/// In-memory service for deterministic UI integration and contract tests.
///
/// This is not a Firebase adapter. Production membership verification and
/// transaction authorization remain behind M2's shared membership contract.
final class FixtureInvitationService implements InvitationService {
  FixtureInvitationService({List<InvitationFixture>? fixtures})
    : _fixtures = {
        for (final fixture in fixtures ?? InvitationFixtures.all)
          fixture.token: fixture,
      };

  final Map<String, InvitationFixture> _fixtures;
  final Set<String> _admittedTokens = {};
  final Map<String, int> _occupiedSeats = {};

  int get successfulAdmissionCount => _admittedTokens.length;

  /// Simulates another participant taking a seat after preview.
  bool claimSeatForOtherUser(String opaqueToken) {
    final fixture = _fixtures[opaqueToken];
    if (fixture == null || !InvitationTokenParser.isOpaqueToken(opaqueToken)) {
      return false;
    }
    final occupied = _currentOccupancy(fixture);
    if (occupied >= fixture.room.capacity) return false;
    _occupiedSeats[opaqueToken] = occupied + 1;
    return true;
  }

  @override
  Future<InvitationPreviewResult> resolveInvitation(String opaqueToken) async {
    if (!InvitationTokenParser.isOpaqueToken(opaqueToken)) {
      return const InvitationPreviewResult(
        status: InvitationPreviewStatus.invalid,
      );
    }

    final fixture = _fixtures[opaqueToken];
    if (fixture == null) {
      return const InvitationPreviewResult(
        status: InvitationPreviewStatus.invalid,
      );
    }

    switch (fixture.state) {
      case InvitationFixtureState.invalid:
        return const InvitationPreviewResult(
          status: InvitationPreviewStatus.invalid,
        );
      case InvitationFixtureState.expired:
      case InvitationFixtureState.revoked:
        return const InvitationPreviewResult(
          status: InvitationPreviewStatus.expiredOrRevoked,
        );
      case InvitationFixtureState.unavailable:
        return const InvitationPreviewResult(
          status: InvitationPreviewStatus.unavailable,
        );
      case InvitationFixtureState.valid:
      case InvitationFixtureState.membershipRequired:
      case InvitationFixtureState.fullRoom:
        final preview = _preview(fixture);
        if (_currentOccupancy(fixture) >= fixture.room.capacity) {
          return InvitationPreviewResult(
            status: InvitationPreviewStatus.fullRoom,
            preview: preview,
          );
        }
        if (fixture.state == InvitationFixtureState.membershipRequired) {
          return InvitationPreviewResult(
            status: InvitationPreviewStatus.membershipRequired,
            preview: preview,
          );
        }
        return InvitationPreviewResult(
          status: InvitationPreviewStatus.ready,
          preview: preview,
        );
    }
  }

  @override
  Future<InvitationAdmissionResult> admitInvitation({
    required String opaqueToken,
    required bool membershipConsentGranted,
  }) async {
    if (!InvitationTokenParser.isOpaqueToken(opaqueToken)) {
      return const InvitationAdmissionResult(InvitationAdmissionStatus.invalid);
    }

    final fixture = _fixtures[opaqueToken];
    if (fixture == null || fixture.state == InvitationFixtureState.invalid) {
      return const InvitationAdmissionResult(InvitationAdmissionStatus.invalid);
    }
    if (fixture.state == InvitationFixtureState.expired ||
        fixture.state == InvitationFixtureState.revoked) {
      return const InvitationAdmissionResult(
        InvitationAdmissionStatus.expiredOrRevoked,
      );
    }
    if (fixture.state == InvitationFixtureState.unavailable) {
      return const InvitationAdmissionResult(
        InvitationAdmissionStatus.unavailable,
      );
    }

    // Consent never substitutes for active membership or enrolls the user.
    if (fixture.state == InvitationFixtureState.membershipRequired) {
      return const InvitationAdmissionResult(
        InvitationAdmissionStatus.membershipRequired,
      );
    }

    // Recheck current occupancy on every admission attempt; preview is not a
    // reservation and may have become stale.
    if (_currentOccupancy(fixture) >= fixture.room.capacity) {
      return const InvitationAdmissionResult(
        InvitationAdmissionStatus.fullRoom,
      );
    }

    _occupiedSeats[opaqueToken] = _currentOccupancy(fixture) + 1;
    _admittedTokens.add(opaqueToken);
    return const InvitationAdmissionResult(InvitationAdmissionStatus.admitted);
  }

  InvitationPreview _preview(InvitationFixture fixture) => InvitationPreview(
    room: RoomSummary(
      id: fixture.room.id,
      subgroupId: fixture.room.subgroupId,
      title: fixture.room.title,
      occupiedSeats: _currentOccupancy(fixture),
      capacity: fixture.room.capacity,
    ),
    sig: fixture.sig,
    subgroup: fixture.subgroup,
  );

  int _currentOccupancy(InvitationFixture fixture) =>
      _occupiedSeats[fixture.token] ?? fixture.room.occupiedSeats;
}
