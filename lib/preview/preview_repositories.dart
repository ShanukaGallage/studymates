import 'dart:async';

import '../core/models/community_models.dart';
import '../features/communities/data/community_repository.dart';
import '../features/rooms/data/room_repository.dart';
import 'community_fixtures.dart';

enum PreviewScenario { sample, empty, loading, errorOnce }

class MemoryCommunityRepository implements CommunityRepository {
  MemoryCommunityRepository({this.scenario = PreviewScenario.sample})
    : _catalog = createCommunityFixtures(
        empty: scenario == PreviewScenario.empty,
      );
  final PreviewScenario scenario;
  CommunityCatalog _catalog;
  bool _failed = false;
  int _nextId = 1;

  @override
  Future<CommunityCatalog> loadCatalog() async {
    if (scenario == PreviewScenario.loading) {
      return Completer<CommunityCatalog>().future;
    }
    if (scenario == PreviewScenario.errorOnce && !_failed) {
      _failed = true;
      throw const RepositoryException(RepositoryError.unavailable);
    }
    return _catalog;
  }

  @override
  Future<CommunityCatalog> createSig({
    required String name,
    required String category,
    required String description,
  }) async {
    final values = _validate(name, category, description);
    final id = 'preview-sig-${_nextId++}';
    _catalog = CommunityCatalog(
      profile: _catalog.profile,
      sigs: [
        ..._catalog.sigs,
        SigSummary(
          id: id,
          name: values.$1,
          category: values.$2,
          description: values.$3,
          ownerId: _catalog.profile.id,
          membership: MembershipState.joined,
        ),
      ],
      subgroups: _catalog.subgroups,
    );
    return _catalog;
  }

  @override
  Future<CommunityCatalog> createSubgroup({
    required String sigId,
    required String name,
    required String description,
  }) async {
    final sig = _ownedSig(sigId);
    final values = _validate(name, 'subgroup', description);
    _catalog = CommunityCatalog(
      profile: _catalog.profile,
      sigs: _catalog.sigs,
      subgroups: [
        ..._catalog.subgroups,
        SubgroupSummary(
          id: 'preview-subgroup-${_nextId++}',
          sigId: sig.id,
          name: values.$1,
          description: values.$3,
        ),
      ],
    );
    return _catalog;
  }

  @override
  Future<CommunityCatalog> updateSubgroup({
    required String sigId,
    required String subgroupId,
    required String name,
    required String description,
  }) async {
    _ownedSubgroup(sigId, subgroupId);
    final values = _validate(name, 'subgroup', description);
    _catalog = CommunityCatalog(
      profile: _catalog.profile,
      sigs: _catalog.sigs,
      subgroups: [
        for (final group in _catalog.subgroups)
          if (group.id == subgroupId)
            SubgroupSummary(
              id: group.id,
              sigId: group.sigId,
              name: values.$1,
              description: values.$3,
              membership: group.membership,
            )
          else
            group,
      ],
    );
    return _catalog;
  }

  @override
  Future<CommunityCatalog> deleteSubgroup({
    required String sigId,
    required String subgroupId,
  }) async {
    _ownedSubgroup(sigId, subgroupId);
    _catalog = CommunityCatalog(
      profile: _catalog.profile,
      sigs: _catalog.sigs,
      subgroups: [
        for (final group in _catalog.subgroups)
          group.id == subgroupId
              ? group.withStatus(SubgroupStatus.closed)
              : group,
      ],
    );
    return _catalog;
  }

  SigSummary _ownedSig(String id) {
    final sig = _catalog.sig(id);
    if (sig == null) throw const RepositoryException(RepositoryError.notFound);
    if (sig.ownerId != _catalog.profile.id) {
      throw const RepositoryException(RepositoryError.permissionDenied);
    }
    return sig;
  }

  void _ownedSubgroup(String sigId, String subgroupId) {
    _ownedSig(sigId);
    final subgroup = _catalog.subgroup(subgroupId);
    if (subgroup == null ||
        subgroup.sigId != sigId ||
        subgroup.status != SubgroupStatus.active) {
      throw const RepositoryException(RepositoryError.notFound);
    }
  }

  (String, String, String) _validate(
    String name,
    String category,
    String description,
  ) {
    final normalizedName = name.trim();
    final normalizedCategory = category.trim();
    final normalizedDescription = description.trim();
    if (normalizedName.isEmpty ||
        normalizedName.length > 80 ||
        normalizedCategory.isEmpty ||
        normalizedCategory.length > 40 ||
        normalizedDescription.isEmpty ||
        normalizedDescription.length > 500) {
      throw const RepositoryException(RepositoryError.invalidData);
    }
    return (normalizedName, normalizedCategory, normalizedDescription);
  }

  @override
  Future<CommunityCatalog> setSigMembership(
    String id,
    MembershipState value,
  ) async {
    if (_catalog.sig(id) == null) {
      throw const RepositoryException(RepositoryError.notFound);
    }
    _catalog = CommunityCatalog(
      profile: _catalog.profile,
      sigs: [
        for (final sig in _catalog.sigs)
          sig.id == id ? sig.withMembership(value) : sig,
      ],
      subgroups: [
        for (final group in _catalog.subgroups)
          group.sigId == id && value == MembershipState.notJoined
              ? group.withMembership(MembershipState.notJoined)
              : group,
      ],
    );
    return _catalog;
  }

  @override
  Future<CommunityCatalog> setSubgroupMembership(
    String id,
    MembershipState value,
  ) async {
    final group = _catalog.subgroup(id);
    if (group == null || group.status != SubgroupStatus.active) {
      throw const RepositoryException(RepositoryError.notFound);
    }
    if (value == MembershipState.joined &&
        _catalog.sig(group.sigId)?.membership != MembershipState.joined) {
      throw const RepositoryException(RepositoryError.membershipRequired);
    }
    _catalog = CommunityCatalog(
      profile: _catalog.profile,
      sigs: _catalog.sigs,
      subgroups: [
        for (final item in _catalog.subgroups)
          item.id == id ? item.withMembership(value) : item,
      ],
    );
    return _catalog;
  }
}

class MemoryRoomRepository implements RoomRepository {
  MemoryRoomRepository({
    this.scenario = PreviewScenario.sample,
    this.isSubgroupActive,
  });
  final PreviewScenario scenario;
  final Future<bool> Function(String subgroupId)? isSubgroupActive;
  bool _failed = false;
  Future<List<RoomSummary>> _load() async {
    if (scenario == PreviewScenario.loading) {
      return Completer<List<RoomSummary>>().future;
    }
    if (scenario == PreviewScenario.errorOnce && !_failed) {
      _failed = true;
      throw const RepositoryException(RepositoryError.unavailable);
    }
    return scenario == PreviewScenario.empty ? [] : previewRooms;
  }

  @override
  Future<List<RoomSummary>> listRooms(String subgroupId) async {
    if (isSubgroupActive != null && !await isSubgroupActive!(subgroupId)) {
      return const [];
    }
    return List.unmodifiable(
      (await _load()).where((room) => room.subgroupId == subgroupId),
    );
  }

  @override
  Future<RoomSummary?> getRoom(String id) async {
    for (final room in await _load()) {
      if (room.id == id) {
        if (isSubgroupActive != null &&
            !await isSubgroupActive!(room.subgroupId)) {
          return null;
        }
        return room;
      }
    }
    return null;
  }
}
