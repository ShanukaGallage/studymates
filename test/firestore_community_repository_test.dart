import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studymates/app/app_mode.dart';
import 'package:studymates/core/models/community_models.dart';
import 'package:studymates/features/communities/data/community_repository.dart';
import 'package:studymates/features/communities/data/firestore_community_repository.dart';
import 'package:studymates/features/communities/data/firestore_membership_repository.dart';
import 'package:studymates/features/communities/data/membership_repository.dart';
import 'package:studymates/features/communities/presentation/controllers/community_providers.dart';

void main() {
  late _CatalogStore catalogStore;
  late _FakeMembershipRepository membership;
  late FirestoreCommunityRepository repository;

  setUp(() {
    catalogStore = _CatalogStore()
      ..sigs = [
        _doc('iot', {
          'name': 'IoT',
          'category': 'Technology',
          'description': 'Sensors and devices',
          'ownerId': 'owner',
          'status': 'active',
        }),
        _doc('closed', {
          'name': 'Closed SIG',
          'category': 'Other',
          'description': 'Archived',
          'ownerId': 'owner',
          'status': 'closed',
        }),
      ]
      ..subgroups = [
        _doc('esp32', {
          'sigId': 'iot',
          'name': 'ESP32',
          'description': 'Build with sensors',
          'status': 'active',
        }),
        _doc('archived-group', {
          'sigId': 'closed',
          'name': 'Old group',
          'description': 'Archived',
          'status': 'active',
        }),
      ];
    membership = _FakeMembershipRepository();
    repository = _repository(store: catalogStore, membership: membership);
  });

  test('self-service cleanup runs before observing completion and finalizing leave', () async {
    membership.cleanupStatus = MembershipCleanupStatus.pending;
    final repo = FirestoreCommunityRepository(
      membershipRepository: membership,
      catalogStore: catalogStore,
      currentUserId: () => 'user-a',
      loadCurrentProfile: () async =>
          UserProfile(id: 'user-a', displayName: 'Learner'),
      completeOwnCleanup: (id) async {
        expect(membership.finalizedRequestIds, isEmpty);
        expect(id, 'request-iot');
        membership.cleanupStatus = MembershipCleanupStatus.completed;
      },
    );
    await repo.setSigMembership('iot', MembershipState.notJoined);
    expect(membership.finalizedRequestIds, ['request-iot']);
  });
  test(
    'pending owner leave can resume after the SIG is already closed',
    () async {
      final repo = FirestoreCommunityRepository(
        membershipRepository: membership,
        catalogStore: catalogStore,
        currentUserId: () => 'user-a',
        loadCurrentProfile: () async =>
            UserProfile(id: 'user-a', displayName: 'Learner'),
        completeOwnCleanup: (_) async {},
      );
      await repo.setSigMembership('closed', MembershipState.notJoined);
      expect(membership.sigLeaveRequests, ['closed']);
      expect(membership.finalizedRequestIds, ['request-closed']);
    },
  );

  test(
    'loads available SIG catalog and maps current user SIG membership',
    () async {
      membership.sigResults['iot'] = MembershipCheckResult.member;
      final catalog = await repository.loadCatalog();

      expect(catalog.sigs.map((sig) => sig.id), ['iot']);
      expect(catalog.sig('iot')!.membership, MembershipState.joined);
      expect(catalog.sig('closed'), isNull);
      expect(catalog.profile.id, 'user-a');
      expect(catalogStore.sigLoads, 1);
    },
  );

  test(
    'loads subgroup membership using the authoritative repository',
    () async {
      membership.subgroupResults['iot/esp32'] = MembershipCheckResult.member;
      final catalog = await repository.loadCatalog();

      expect(catalog.subgroups.map((group) => group.id), ['esp32']);
      expect(catalog.subgroup('esp32')!.membership, MembershipState.joined);
      expect(membership.subgroupChecks, [('iot', 'esp32')]);
    },
  );

  test('missing memberships map to notJoined, not loading or error', () async {
    final catalog = await repository.loadCatalog();
    expect(catalog.sig('iot')!.membership, MembershipState.notJoined);
    expect(catalog.subgroup('esp32')!.membership, MembershipState.notJoined);
  });

  test('SIG join persists through MembershipRepository', () async {
    await repository.setSigMembership('iot', MembershipState.joined);
    expect(membership.joinedSigs, ['iot']);
  });

  test('SIG leave waits for cleanup acknowledgement and finalizes', () async {
    membership.sigResults['iot'] = MembershipCheckResult.member;
    await repository.setSigMembership('iot', MembershipState.notJoined);

    expect(membership.sigLeaveRequests, ['iot']);
    expect(membership.watchedRequestIds, ['request-iot']);
    expect(membership.finalizedRequestIds, ['request-iot']);
  });

  test('subgroup join uses membership repository parent check', () async {
    membership.joinSubgroupError = const MembershipRepositoryException(
      MembershipRepositoryError.notMember,
    );
    await expectLater(
      repository.setSubgroupMembership('esp32', MembershipState.joined),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryError.membershipRequired,
        ),
      ),
    );
    expect(membership.subgroupJoinRequests, [('iot', 'esp32')]);
  });

  test('subgroup leave persists and finalizes the cleanup request', () async {
    membership.subgroupResults['iot/esp32'] = MembershipCheckResult.member;
    await repository.setSubgroupMembership('esp32', MembershipState.notJoined);

    expect(membership.subgroupLeaveRequests, [('iot', 'esp32')]);
    expect(membership.finalizedRequestIds, ['request-esp32']);
  });

  test(
    'membership permission and availability outcomes remain errors',
    () async {
      membership.sigResults['iot'] = MembershipCheckResult.permissionDenied;
      await expectLater(
        repository.loadCatalog(),
        throwsA(isA<MembershipRepositoryException>()),
      );
      membership.sigResults['iot'] = MembershipCheckResult.unavailable;
      await expectLater(
        repository.loadCatalog(),
        throwsA(isA<MembershipRepositoryException>()),
      );
    },
  );

  test('loaded empty catalog remains successful data', () async {
    catalogStore.sigs = [];
    catalogStore.subgroups = [];
    final catalog = await repository.loadCatalog();
    expect(catalog.sigs, isEmpty);
    expect(catalog.subgroups, isEmpty);
  });

  test('controller provider exposes loading state while loading', () async {
    final completer = Completer<CommunityCatalog>();
    final container = ProviderContainer(
      overrides: [
        appModeProvider.overrideWithValue(AppMode.preview),
        communityRepositoryProvider.overrideWithValue(
          _FakeCommunityRepository(load: () => completer.future),
        ),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(communityCatalogProvider, (_, _) {});
    addTearDown(subscription.close);
    expect(container.read(communityCatalogProvider).isLoading, isTrue);
    completer.complete(_emptyCatalog());
    await container.read(communityCatalogProvider.future);
  });

  test('controller provider exposes error state on failed load', () async {
    final container = ProviderContainer(
      overrides: [
        appModeProvider.overrideWithValue(AppMode.preview),
        communityRepositoryProvider.overrideWithValue(
          _FakeCommunityRepository(
            load: () => Future.error(StateError('offline')),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(communityCatalogProvider, (_, _) {});
    addTearDown(subscription.close);
    await expectLater(
      container.read(communityCatalogProvider.future),
      throwsStateError,
    );
    expect(container.read(communityCatalogProvider).hasError, isTrue);
  });

  test('provider wiring constructs Firestore repository in normal mode', () {
    final container = ProviderContainer(
      overrides: [
        communityCatalogDocumentStoreProvider.overrideWithValue(
          _CatalogStore(),
        ),
        membershipRepositoryProvider.overrideWithValue(
          _FakeMembershipRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
    expect(
      container.read(communityRepositoryProvider),
      isA<FirestoreCommunityRepository>(),
    );
  });
}

FirestoreCommunityRepository _repository({
  _CatalogStore? store,
  _FakeMembershipRepository? membership,
  String? Function()? currentUserId,
}) => FirestoreCommunityRepository(
  membershipRepository: membership ?? _FakeMembershipRepository(),
  loadCurrentProfile: () async => UserProfile(id: 'user-a', displayName: 'A'),
  currentUserId: currentUserId ?? () => 'user-a',
  catalogStore: store ?? _CatalogStore(),
);

CommunityCatalogDocument _doc(String id, Map<String, dynamic> data) =>
    CommunityCatalogDocument(id: id, data: data);

CommunityCatalog _emptyCatalog() => CommunityCatalog(
  profile: UserProfile(id: 'user-a', displayName: 'A'),
  sigs: const [],
  subgroups: const [],
);

class _CatalogStore implements CommunityCatalogDocumentStore {
  List<CommunityCatalogDocument> sigs = [];
  List<CommunityCatalogDocument> subgroups = [];
  int sigLoads = 0;

  @override
  Future<List<CommunityCatalogDocument>> loadSigs() async {
    sigLoads++;
    return sigs;
  }

  @override
  Future<List<CommunityCatalogDocument>> loadSubgroups() async => subgroups;
}

class _FakeMembershipRepository implements MembershipRepository {
  final sigResults = <String, MembershipCheckResult>{};
  final subgroupResults = <String, MembershipCheckResult>{};
  final joinedSigs = <String>[];
  final subgroupJoinRequests = <(String, String)>[];
  final sigLeaveRequests = <String>[];
  final subgroupLeaveRequests = <(String, String)>[];
  final watchedRequestIds = <String>[];
  final finalizedRequestIds = <String>[];
  MembershipRepositoryException? joinSubgroupError;
  MembershipCleanupStatus cleanupStatus = MembershipCleanupStatus.completed;

  List<(String, String)> get subgroupChecks => _subgroupChecks;
  final _subgroupChecks = <(String, String)>[];

  @override
  Future<void> joinSig({required String sigId}) async {
    joinedSigs.add(sigId);
  }

  @override
  Future<void> joinSubgroup({
    required String sigId,
    required String subgroupId,
  }) async {
    subgroupJoinRequests.add((sigId, subgroupId));
    if (joinSubgroupError != null) throw joinSubgroupError!;
  }

  @override
  Future<MembershipCheckResult> checkSigMembership({
    required String sigId,
  }) async => sigResults[sigId] ?? MembershipCheckResult.nonMember;

  @override
  Future<MembershipCheckResult> checkSubgroupMembership({
    required String sigId,
    required String subgroupId,
  }) async {
    _subgroupChecks.add((sigId, subgroupId));
    return subgroupResults['$sigId/$subgroupId'] ??
        MembershipCheckResult.nonMember;
  }

  @override
  Future<MembershipCheckResult> verifyRoomEligibilityInTransaction({
    required Transaction transaction,
    required String sigId,
    required String subgroupId,
  }) async => MembershipCheckResult.member;

  @override
  Future<MembershipCleanupRequest> beginSigLeave({
    required String sigId,
  }) async {
    sigLeaveRequests.add(sigId);
    return _request('request-$sigId', sigId, MembershipRemovalScope.sig);
  }

  @override
  Future<MembershipCleanupRequest> beginSubgroupLeave({
    required String sigId,
    required String subgroupId,
  }) async {
    subgroupLeaveRequests.add((sigId, subgroupId));
    return _request(
      'request-$subgroupId',
      sigId,
      MembershipRemovalScope.subgroup,
      subgroupId: subgroupId,
    );
  }

  @override
  Stream<MembershipCleanupRequest?> watchCleanupRequest(String requestId) {
    watchedRequestIds.add(requestId);
    return Stream.value(
      MembershipCleanupRequest(
        requestId: requestId,
        userId: 'user-a',
        sigId: 'iot',
        scope: MembershipRemovalScope.sig,
        status: cleanupStatus,
      ),
    );
  }

  @override
  Future<void> finalizeMembershipRemoval(String requestId) async {
    finalizedRequestIds.add(requestId);
  }

  MembershipCleanupRequest _request(
    String id,
    String sigId,
    MembershipRemovalScope scope, {
    String? subgroupId,
  }) => MembershipCleanupRequest(
    requestId: id,
    userId: 'user-a',
    sigId: sigId,
    subgroupId: subgroupId,
    scope: scope,
    status: MembershipCleanupStatus.pending,
  );
}

class _FakeCommunityRepository implements CommunityRepository {
  _FakeCommunityRepository({required this.load});
  final Future<CommunityCatalog> Function() load;

  @override
  Future<CommunityCatalog> loadCatalog() => load();

  @override
  Future<CommunityCatalog> setSigMembership(String id, MembershipState value) =>
      load();

  @override
  Future<CommunityCatalog> setSubgroupMembership(
    String id,
    MembershipState value,
  ) => load();
}
