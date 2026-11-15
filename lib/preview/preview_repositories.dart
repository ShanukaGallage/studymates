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
    if (group == null) {
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
  MemoryRoomRepository({this.scenario = PreviewScenario.sample});
  final PreviewScenario scenario;
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
  Future<List<RoomSummary>> listRooms(String subgroupId) async =>
      List.unmodifiable(
        (await _load()).where((room) => room.subgroupId == subgroupId),
      );
  @override
  Future<RoomSummary?> getRoom(String id) async {
    for (final room in await _load()) {
      if (room.id == id) return room;
    }
    return null;
  }
}
