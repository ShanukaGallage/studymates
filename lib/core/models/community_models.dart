enum MembershipState { notJoined, joined }

enum SubgroupStatus { active, closed }

class UserProfile {
  static const defaultAvatarId = 'default';

  UserProfile({
    required this.id,
    required this.displayName,
    this.avatarId = defaultAvatarId,
    List<String> interestIds = const [],
  }) : interestIds = List.unmodifiable(interestIds);
  final String id;
  final String displayName;
  final String avatarId;
  final List<String> interestIds;
}

class SigSummary {
  const SigSummary({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.ownerId,
    this.membership = MembershipState.notJoined,
  });
  final String id, name, category, description, ownerId;
  final MembershipState membership;
  SigSummary withMembership(MembershipState value) => SigSummary(
    id: id,
    name: name,
    category: category,
    description: description,
    ownerId: ownerId,
    membership: value,
  );
}

class SubgroupSummary {
  const SubgroupSummary({
    required this.id,
    required this.sigId,
    required this.name,
    required this.description,
    this.membership = MembershipState.notJoined,
    this.status = SubgroupStatus.active,
  });
  final String id, sigId, name, description;
  final MembershipState membership;
  final SubgroupStatus status;
  SubgroupSummary withMembership(MembershipState value) => SubgroupSummary(
    id: id,
    sigId: sigId,
    name: name,
    description: description,
    membership: value,
    status: status,
  );
  SubgroupSummary withStatus(SubgroupStatus value) => SubgroupSummary(
    id: id,
    sigId: sigId,
    name: name,
    description: description,
    membership: membership,
    status: value,
  );
}

class CommunityCatalog {
  CommunityCatalog({
    required this.profile,
    required List<SigSummary> sigs,
    required List<SubgroupSummary> subgroups,
  }) : sigs = List.unmodifiable(sigs),
       subgroups = List.unmodifiable(subgroups);
  final UserProfile profile;
  final List<SigSummary> sigs;
  final List<SubgroupSummary> subgroups;
  Iterable<SubgroupSummary> get activeSubgroups =>
      subgroups.where((subgroup) => subgroup.status == SubgroupStatus.active);
  SigSummary? sig(String id) {
    for (final value in sigs) {
      if (value.id == id) return value;
    }
    return null;
  }

  SubgroupSummary? subgroup(String id) {
    for (final value in subgroups) {
      if (value.id == id) return value;
    }
    return null;
  }
}

// Discovery summary only: not a live room snapshot or a seat reservation.
class RoomSummary {
  const RoomSummary({
    required this.id,
    required this.subgroupId,
    required this.title,
    required this.occupiedSeats,
    this.capacity = 6,
    this.isPrivate = false,
    this.occupancyKnown = true,
  }) : assert(occupiedSeats >= 0 && occupiedSeats <= capacity);
  final String id, subgroupId, title;
  final int occupiedSeats, capacity;
  final bool isPrivate;
  final bool occupancyKnown;
  bool get isFull => occupancyKnown && occupiedSeats >= capacity;
}

enum RepositoryError {
  notFound,
  membershipRequired,
  permissionDenied,
  invalidData,
  unavailable,
}

class RepositoryException implements Exception {
  const RepositoryException(this.code);
  final RepositoryError code;
}
