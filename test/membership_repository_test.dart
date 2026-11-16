import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studymates/core/models/community_models.dart';
import 'package:studymates/features/communities/data/firestore_community_repository.dart';
import 'package:studymates/features/communities/data/firestore_membership_repository.dart';
import 'package:studymates/features/communities/data/membership_repository.dart';

void main() {
  group('FirestoreMembershipRepository checks', () {
    late _FakeMembershipStore store;
    late String? currentUid;
    late FirestoreMembershipRepository repository;

    setUp(() {
      store = _FakeMembershipStore();
      currentUid = 'user-a';
      repository = FirestoreMembershipRepository(
        currentUserId: () => currentUid,
        documentStore: store,
      );
      _seedCommunity(store);
    });

    test('uses authenticated identity and recognizes SIG membership', () async {
      store.documents['sigs/sig-a/members/user-a'] = _member('user-a');

      expect(
        await repository.checkSigMembership(sigId: 'sig-a'),
        MembershipCheckResult.member,
      );
      expect(
        store.documents.containsKey('sigs/sig-a/members/someone-else'),
        isFalse,
      );
    });

    test('SIG owner counts as member without a membership document', () async {
      store.documents['sigs/sig-a']!['ownerId'] = 'user-a';

      expect(
        await repository.checkSigMembership(sigId: 'sig-a'),
        MembershipCheckResult.member,
      );
    });

    test('missing and removal-pending membership are nonMember', () async {
      expect(
        await repository.checkSigMembership(sigId: 'sig-a'),
        MembershipCheckResult.nonMember,
      );
      store.documents['sigs/sig-a/members/user-a'] = _member(
        'user-a',
        status: 'removalPending',
      );
      expect(
        await repository.checkSigMembership(sigId: 'sig-a'),
        MembershipCheckResult.nonMember,
      );
    });

    test(
      'subgroup membership requires active parent and matching SIG',
      () async {
        store.documents['sigs/sig-a/members/user-a'] = _member('user-a');
        store.documents['subgroups/group-a/members/user-a'] = _member(
          'user-a',
          sigId: 'sig-a',
        );
        expect(
          await repository.checkSubgroupMembership(
            sigId: 'sig-a',
            subgroupId: 'group-a',
          ),
          MembershipCheckResult.member,
        );

        store.documents['subgroups/group-a/members/user-a']!['status'] =
            'removalPending';
        expect(
          await repository.checkSubgroupMembership(
            sigId: 'sig-a',
            subgroupId: 'group-a',
          ),
          MembershipCheckResult.nonMember,
        );
        expect(
          await repository.checkSubgroupMembership(
            sigId: 'other-sig',
            subgroupId: 'group-a',
          ),
          MembershipCheckResult.nonMember,
        );
      },
    );

    test('closed SIG blocks room eligibility', () async {
      store.documents['sigs/sig-a']!['status'] = 'closed';
      store.documents['sigs/sig-a/members/user-a'] = _member('user-a');
      store.documents['subgroups/group-a/members/user-a'] = _member(
        'user-a',
        sigId: 'sig-a',
      );

      expect(
        await repository.checkSubgroupMembership(
          sigId: 'sig-a',
          subgroupId: 'group-a',
        ),
        MembershipCheckResult.nonMember,
      );
    });

    test('room eligibility requires active SIG and subgroup membership and matching parent', () async {
      final transaction = _DummyFirestoreTransaction();
      store.documents['sigs/sig-a/members/user-a'] = _member('user-a');
      store.documents['subgroups/group-a/members/user-a'] = _member(
        'user-a',
        sigId: 'sig-a',
      );

      Future<MembershipCheckResult> verify() =>
          repository.verifyRoomEligibilityInTransaction(
            transaction: transaction,
            sigId: 'sig-a',
            subgroupId: 'group-a',
          );

      expect(await verify(), MembershipCheckResult.member);

      store.documents.remove('sigs/sig-a/members/user-a');
      expect(await verify(), MembershipCheckResult.nonMember);
      store.documents['sigs/sig-a/members/user-a'] = _member(
        'user-a',
        status: 'removalPending',
      );
      expect(await verify(), MembershipCheckResult.nonMember);
      store.documents['sigs/sig-a/members/user-a'] = _member('user-a');

      store.documents['subgroups/group-a']!['sigId'] = 'another-sig';
      expect(await verify(), MembershipCheckResult.nonMember);
      store.documents['subgroups/group-a']!['sigId'] = 'sig-a';
      store.documents['subgroups/group-a']!['status'] = 'closed';
      expect(await verify(), MembershipCheckResult.nonMember);
      store.documents['subgroups/group-a']!['status'] = 'active';

      store.documents.remove('subgroups/group-a/members/user-a');
      expect(await verify(), MembershipCheckResult.nonMember);
      store.documents['subgroups/group-a/members/user-a'] = _member(
        'user-a',
        sigId: 'sig-a',
        status: 'removalPending',
      );
      expect(await verify(), MembershipCheckResult.nonMember);
    });

    test(
      'SIG owner still needs active subgroup membership for room eligibility',
      () async {
        final transaction = _DummyFirestoreTransaction();
        store.documents['sigs/sig-a']!['ownerId'] = 'user-a';
        store.documents['subgroups/group-a/members/user-a'] = _member(
          'user-a',
          sigId: 'sig-a',
        );

        expect(
          await repository.verifyRoomEligibilityInTransaction(
            transaction: transaction,
            sigId: 'sig-a',
            subgroupId: 'group-a',
          ),
          MembershipCheckResult.member,
        );

        store.documents.remove('subgroups/group-a/members/user-a');
        expect(
          await repository.verifyRoomEligibilityInTransaction(
            transaction: transaction,
            sigId: 'sig-a',
            subgroupId: 'group-a',
          ),
          MembershipCheckResult.nonMember,
        );
      },
    );

    test(
      'unavailable transaction membership reads fail room eligibility closed',
      () async {
        store.transactionFailure = FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unavailable',
        );

        expect(
          await repository.verifyRoomEligibilityInTransaction(
            transaction: _DummyFirestoreTransaction(),
            sigId: 'sig-a',
            subgroupId: 'group-a',
          ),
          MembershipCheckResult.unavailable,
        );
      },
    );

    test('signed-out caller is denied without a Firestore read', () async {
      currentUid = null;

      expect(
        await repository.checkSigMembership(sigId: 'sig-a'),
        MembershipCheckResult.permissionDenied,
      );
      expect(store.readPaths, isEmpty);
    });

    test('permission and service errors map to distinct outcomes', () async {
      store.failure = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
      expect(
        await repository.checkSigMembership(sigId: 'sig-a'),
        MembershipCheckResult.permissionDenied,
      );

      store.failure = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );
      expect(
        await repository.checkSigMembership(sigId: 'sig-a'),
        MembershipCheckResult.unavailable,
      );
    });

    test('malformed documents return unavailable', () async {
      store.documents['sigs/sig-a']!.remove('status');
      expect(
        await repository.checkSigMembership(sigId: 'sig-a'),
        MembershipCheckResult.unavailable,
      );
    });

    test(
      'room eligibility reads through the exact supplied transaction',
      () async {
        store.documents['sigs/sig-a/members/user-a'] = _member('user-a');
        store.documents['subgroups/group-a/members/user-a'] = _member(
          'user-a',
          sigId: 'sig-a',
        );
        final transaction = _DummyFirestoreTransaction();

        expect(
          await repository.verifyRoomEligibilityInTransaction(
            transaction: transaction,
            sigId: 'sig-a',
            subgroupId: 'group-a',
          ),
          MembershipCheckResult.member,
        );
        expect(store.lastSuppliedTransaction, same(transaction));
        expect(store.transactionReadPaths, [
          'sigs/sig-a',
          'sigs/sig-a/members/user-a',
          'subgroups/group-a',
          'subgroups/group-a/members/user-a',
        ]);
      },
    );
  });

  group('FirestoreMembershipRepository removal', () {
    test(
      'joining a SIG increments its revision with the membership write',
      () async {
        final store = _FakeMembershipStore()
          ..documents['sigs/sig-a'] = {
            'ownerId': 'owner',
            'status': 'active',
            'membershipRevision': 0,
          };
        final repository = FirestoreMembershipRepository(
          currentUserId: () => 'user-a',
          documentStore: store,
        );

        await repository.joinSig(sigId: 'sig-a');

        expect(store.documents['sigs/sig-a']!['membershipRevision'], 1);
        expect(
          store.documents['sigs/sig-a/members/user-a']!['status'],
          'active',
        );
      },
    );

    test(
      'concurrent SIG membership changes restart owner succession lookup',
      () async {
        final store = _FakeMembershipStore()
          ..documents['sigs/sig-a'] = {
            'ownerId': 'user-a',
            'status': 'active',
            'membershipRevision': 0,
          };
        store.onEarliestActiveSigMember = () {
          store.documents['sigs/sig-a']!['membershipRevision'] = 1;
          store.documents['sigs/sig-a/members/user-b'] = _member('user-b');
        };
        final repository = FirestoreMembershipRepository(
          currentUserId: () => 'user-a',
          documentStore: store,
        );

        await repository.beginSigLeave(sigId: 'sig-a');

        expect(store.documents['sigs/sig-a']!['ownerId'], 'user-b');
        expect(store.documents['sigs/sig-a']!['status'], 'active');
        expect(store.documents['sigs/sig-a']!['membershipRevision'], 2);
      },
    );

    test('SIG owner transfer and pending removal are atomic', () async {
      final store = _FakeMembershipStore()
        ..documents['sigs/sig-a'] = {
          'ownerId': 'user-a',
          'status': 'active',
          'membershipRevision': 1,
        }
        ..documents['sigs/sig-a/members/user-b'] = _member('user-b');
      final repository = FirestoreMembershipRepository(
        currentUserId: () => 'user-a',
        documentStore: store,
      );

      final request = await repository.beginSigLeave(sigId: 'sig-a');

      expect(store.documents['sigs/sig-a']!['ownerId'], 'user-b');
      expect(
        store.documents['sigs/sig-a/members/user-a']!['status'],
        'removalPending',
      );
      expect(request.status, MembershipCleanupStatus.pending);
      expect(request.userId, 'user-a');
      expect(
        store
            .documents['membershipCleanupRequests/${request.requestId}']!['status'],
        'pending',
      );
    });

    test(
      'retrying SIG leave while pending returns the original request',
      () async {
        final store = _FakeMembershipStore()
          ..documents['sigs/sig-a'] = {
            'ownerId': 'owner',
            'status': 'active',
            'membershipRevision': 4,
          }
          ..documents['sigs/sig-a/members/user-a'] = _member('user-a');
        final repository = FirestoreMembershipRepository(
          currentUserId: () => 'user-a',
          documentStore: store,
        );

        final firstRequest = await repository.beginSigLeave(sigId: 'sig-a');
        final revisionAfterFirstRequest =
            store.documents['sigs/sig-a']!['membershipRevision'];
        final requestCountAfterFirstRequest = store.documents.keys
            .where((path) => path.startsWith('membershipCleanupRequests/'))
            .length;

        final retriedRequest = await repository.beginSigLeave(sigId: 'sig-a');

        expect(retriedRequest.requestId, firstRequest.requestId);
        expect(
          store.documents['sigs/sig-a']!['membershipRevision'],
          revisionAfterFirstRequest,
        );
        expect(
          store.documents.keys
              .where((path) => path.startsWith('membershipCleanupRequests/'))
              .length,
          requestCountAfterFirstRequest,
        );
      },
    );

    test('SIG closes when no successor exists and retains its data', () async {
      final store = _FakeMembershipStore()
        ..documents['sigs/sig-a'] = {
          'ownerId': 'user-a',
          'status': 'active',
          'membershipRevision': 0,
          'name': 'IoT',
        };
      final repository = FirestoreMembershipRepository(
        currentUserId: () => 'user-a',
        documentStore: store,
      );

      final request = await repository.beginSigLeave(sigId: 'sig-a');

      expect(store.documents['sigs/sig-a']!['status'], 'closed');
      expect(store.documents['sigs/sig-a']!['name'], 'IoT');
      expect(request.status, MembershipCleanupStatus.pending);
    });

    test('subgroup leave waits for M3 acknowledgement before finalizing', () async {
      final store = _FakeMembershipStore()
        ..documents['sigs/sig-a'] = {
          'ownerId': 'owner',
          'status': 'active',
          'membershipRevision': 1,
        }
        ..documents['sigs/sig-a/members/user-a'] = _member('user-a')
        ..documents['subgroups/group-a'] = {'sigId': 'sig-a'}
        ..documents['subgroups/group-a/members/user-a'] = _member(
          'user-a',
          sigId: 'sig-a',
        );
      final repository = FirestoreMembershipRepository(
        currentUserId: () => 'user-a',
        documentStore: store,
      );

      final request = await repository.beginSubgroupLeave(
        sigId: 'sig-a',
        subgroupId: 'group-a',
      );
      expect(
        store.documents['subgroups/group-a/members/user-a']!['status'],
        'removalPending',
      );
      await expectLater(
        repository.finalizeMembershipRemoval(request.requestId),
        throwsA(
          isA<MembershipRepositoryException>().having(
            (error) => error.code,
            'code',
            MembershipRepositoryError.cleanupNotComplete,
          ),
        ),
      );

      store.documents['membershipCleanupRequests/${request.requestId}']!['status'] =
          'completed';
      await repository.finalizeMembershipRemoval(request.requestId);
      expect(
        store.documents['subgroups/group-a/members/user-a']!['status'],
        'left',
      );
    });

    test('finalizing a subgroup request twice does not update membership again', () async {
      final store = _FakeMembershipStore()
        ..documents['sigs/sig-a'] = {
          'ownerId': 'owner',
          'status': 'active',
          'membershipRevision': 1,
        }
        ..documents['sigs/sig-a/members/user-a'] = _member('user-a')
        ..documents['subgroups/group-a'] = {'sigId': 'sig-a'}
        ..documents['subgroups/group-a/members/user-a'] = _member(
          'user-a',
          sigId: 'sig-a',
        );
      final repository = FirestoreMembershipRepository(
        currentUserId: () => 'user-a',
        documentStore: store,
      );
      final request = await repository.beginSubgroupLeave(
        sigId: 'sig-a',
        subgroupId: 'group-a',
      );
      store.documents['membershipCleanupRequests/${request.requestId}']!['status'] =
          'completed';

      await repository.finalizeMembershipRemoval(request.requestId);
      final membershipAfterFirstFinalize = Map<String, dynamic>.of(
        store.documents['subgroups/group-a/members/user-a']!,
      );
      final updatesAfterFirstFinalize = store.updateCount;

      await repository.finalizeMembershipRemoval(request.requestId);

      expect(
        store.documents['subgroups/group-a/members/user-a'],
        membershipAfterFirstFinalize,
      );
      expect(store.updateCount, updatesAfterFirstFinalize);
    });

    test('finalizing a SIG request twice does not increment its revision twice', () async {
      final store = _FakeMembershipStore()
        ..documents['sigs/sig-a'] = {
          'ownerId': 'owner',
          'status': 'active',
          'membershipRevision': 1,
        }
        ..documents['sigs/sig-a/members/user-a'] = _member('user-a');
      final repository = FirestoreMembershipRepository(
        currentUserId: () => 'user-a',
        documentStore: store,
      );
      final request = await repository.beginSigLeave(sigId: 'sig-a');
      store.documents['membershipCleanupRequests/${request.requestId}']!['status'] =
          'completed';

      await repository.finalizeMembershipRemoval(request.requestId);
      final revisionAfterFirstFinalize =
          store.documents['sigs/sig-a']!['membershipRevision'];
      final updatesAfterFirstFinalize = store.updateCount;

      await repository.finalizeMembershipRemoval(request.requestId);

      expect(
        store.documents['sigs/sig-a']!['membershipRevision'],
        revisionAfterFirstFinalize,
      );
      expect(store.updateCount, updatesAfterFirstFinalize);
    });

    test('SIG finalization before cleanup completion leaves membership pending', () async {
      final store = _FakeMembershipStore()
        ..documents['sigs/sig-a'] = {
          'ownerId': 'owner',
          'status': 'active',
          'membershipRevision': 1,
        }
        ..documents['sigs/sig-a/members/user-a'] = _member('user-a')
        ..documents['subgroups/group-a'] = {'sigId': 'sig-a'}
        ..documents['subgroups/group-a/members/user-a'] = _member(
          'user-a',
          sigId: 'sig-a',
        );
      final repository = FirestoreMembershipRepository(
        currentUserId: () => 'user-a',
        documentStore: store,
      );
      final request = await repository.beginSigLeave(sigId: 'sig-a');
      final revisionAfterLeaveBegan =
          store.documents['sigs/sig-a']!['membershipRevision'];

      await expectLater(
        repository.finalizeMembershipRemoval(request.requestId),
        throwsA(
          isA<MembershipRepositoryException>().having(
            (error) => error.code,
            'code',
            MembershipRepositoryError.cleanupNotComplete,
          ),
        ),
      );

      expect(
        store.documents['sigs/sig-a/members/user-a']!['status'],
        'removalPending',
      );
      expect(
        store.documents['subgroups/group-a/members/user-a']!['status'],
        'active',
      );
      expect(
        store.documents['sigs/sig-a']!['membershipRevision'],
        revisionAfterLeaveBegan,
      );
      expect(
        store
            .documents['membershipCleanupRequests/${request.requestId}']!['status'],
        'pending',
      );
    });

    test('SIG leave finalizes child memberships after one M3 acknowledgement', () async {
      final store = _FakeMembershipStore()
        ..documents['sigs/sig-a'] = {
          'ownerId': 'owner',
          'status': 'active',
          'membershipRevision': 1,
        }
        ..documents['sigs/sig-a/members/user-a'] = _member('user-a')
        ..documents['subgroups/group-a'] = {'sigId': 'sig-a'}
        ..documents['subgroups/group-a/members/user-a'] = _member(
          'user-a',
          sigId: 'sig-a',
        );
      final repository = FirestoreMembershipRepository(
        currentUserId: () => 'user-a',
        documentStore: store,
      );

      final request = await repository.beginSigLeave(sigId: 'sig-a');
      expect(
        store.documents['subgroups/group-a/members/user-a']!['status'],
        'active',
      );
      store.documents['membershipCleanupRequests/${request.requestId}']!['status'] =
          'completed';

      await repository.finalizeMembershipRemoval(request.requestId);

      expect(
        store.documents['subgroups/group-a/members/user-a']!['status'],
        'left',
      );
      expect(store.documents['sigs/sig-a/members/user-a']!['status'], 'left');
      expect(store.documents['sigs/sig-a']!['membershipRevision'], 3);
    });
  });

  test(
    'community SIG leave resumes the same request after a cleanup timeout',
    () async {
      final store = _FakeMembershipStore()
        ..documents['sigs/sig-a'] = {
          'ownerId': 'owner',
          'status': 'active',
          'membershipRevision': 1,
        }
        ..documents['sigs/sig-a/members/user-a'] = _member('user-a')
        ..documents['subgroups/group-a'] = {'sigId': 'sig-a'}
        ..documents['subgroups/group-a/members/user-a'] = _member(
          'user-a',
          sigId: 'sig-a',
        );
      addTearDown(store.closeWatches);
      final membershipRepository = FirestoreMembershipRepository(
        currentUserId: () => 'user-a',
        documentStore: store,
      );
      final communityRepository = FirestoreCommunityRepository(
        membershipRepository: membershipRepository,
        loadCurrentProfile: () async =>
            UserProfile(id: 'user-a', displayName: 'Test user'),
        currentUserId: () => 'user-a',
        catalogStore: _CleanupCatalogStore(),
        cleanupTimeout: const Duration(milliseconds: 20),
      );

      await expectLater(
        communityRepository.setSigMembership(
          'sig-a',
          MembershipState.notJoined,
        ),
        throwsA(isA<TimeoutException>()),
      );
      final requestPath = store.documents.keys.singleWhere(
        (path) => path.startsWith('membershipCleanupRequests/'),
      );
      expect(store.watchPaths, [requestPath]);
      expect(
        store.documents['sigs/sig-a/members/user-a']!['status'],
        'removalPending',
      );

      store.documents[requestPath]!['status'] = 'completed';
      store.emitDocument(requestPath);
      await communityRepository.setSigMembership(
        'sig-a',
        MembershipState.notJoined,
      );

      expect(store.watchPaths, [requestPath, requestPath]);
      expect(store.documents['sigs/sig-a/members/user-a']!['status'], 'left');
    },
  );
}

class _CleanupCatalogStore implements CommunityCatalogDocumentStore {
  @override
  Future<void> createSig(Map<String, dynamic> data) async {}

  @override
  Future<void> createSubgroup(Map<String, dynamic> data) async {}

  @override
  Future<void> updateSubgroup(
    String subgroupId,
    Map<String, dynamic> data,
  ) async {}

  @override
  Future<void> closeSubgroup(String subgroupId) async {}

  @override
  Future<List<CommunityCatalogDocument>> loadSigs() async => [
    const CommunityCatalogDocument(
      id: 'sig-a',
      data: {
        'name': 'IoT',
        'category': 'Technology',
        'description': 'Test SIG',
        'ownerId': 'owner',
        'status': 'active',
      },
    ),
  ];

  @override
  Future<List<CommunityCatalogDocument>> loadSubgroups() async => const [];
}

void _seedCommunity(_FakeMembershipStore store) {
  store.documents['sigs/sig-a'] = {
    'ownerId': 'owner',
    'status': 'active',
    'membershipRevision': 1,
  };
  store.documents['subgroups/group-a'] = {'sigId': 'sig-a', 'status': 'active'};
}

Map<String, dynamic> _member(
  String userId, {
  String sigId = 'sig-a',
  String status = 'active',
}) => {
  'userId': userId,
  'sigId': sigId,
  'status': status,
  'joinedAt': Timestamp.fromDate(DateTime.utc(2026)),
};

class _DummyFirestoreTransaction implements Transaction {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeMembershipStore implements MembershipDocumentStore {
  final documents = <String, Map<String, dynamic>>{};
  final readPaths = <String>[];
  final transactionReadPaths = <String>[];
  final watchPaths = <String>[];
  final _watchers = <String, List<StreamController<Map<String, dynamic>?>>>{};
  Object? failure;
  Object? transactionFailure;
  Transaction? lastSuppliedTransaction;
  void Function()? onEarliestActiveSigMember;
  var _requestId = 0;
  var updateCount = 0;

  void _checkFailure() {
    if (failure case final error?) throw error;
  }

  @override
  String newRequestId() => 'request-${++_requestId}';

  @override
  Future<Map<String, dynamic>?> get(String path) async {
    _checkFailure();
    readPaths.add(path);
    final value = documents[path];
    return value == null ? null : Map.of(value);
  }

  @override
  Stream<Map<String, dynamic>?> watch(String path) {
    watchPaths.add(path);
    late final StreamController<Map<String, dynamic>?> controller;
    controller = StreamController<Map<String, dynamic>?>(
      onListen: () {
        _watchers.putIfAbsent(path, () => []).add(controller);
        final value = documents[path];
        controller.add(value == null ? null : Map.of(value));
      },
      onCancel: () => _watchers[path]?.remove(controller),
    );
    return controller.stream;
  }

  void emitDocument(String path) {
    final value = documents[path];
    for (final watcher in List.of(_watchers[path] ?? const [])) {
      watcher.add(value == null ? null : Map.of(value));
    }
  }

  Future<void> closeWatches() async {
    final watchers = _watchers.values.expand((value) => value).toList();
    await Future.wait(watchers.map((watcher) => watcher.close()));
  }

  @override
  Future<T> runTransaction<T>(
    Future<T> Function(MembershipTransaction) body,
  ) async {
    _checkFailure();
    final transaction = _FakeMembershipTransaction(this);
    final result = await body(transaction);
    transaction.commit();
    return result;
  }

  @override
  Future<Map<String, dynamic>?> getInTransaction(
    Transaction transaction,
    String path,
  ) async {
    lastSuppliedTransaction = transaction;
    transactionReadPaths.add(path);
    if (transactionFailure case final error?) throw error;
    final value = documents[path];
    return value == null ? null : Map.of(value);
  }

  @override
  Future<MembershipDocument?> earliestActiveSigMember(
    String sigId, {
    required String excludingUid,
  }) async {
    final prefix = 'sigs/$sigId/members/';
    final candidates =
        documents.entries
            .where(
              (entry) =>
                  entry.key.startsWith(prefix) &&
                  entry.key.substring(prefix.length) != excludingUid &&
                  entry.value['status'] == 'active',
            )
            .map((entry) => MembershipDocument(entry.key, Map.of(entry.value)))
            .toList()
          ..sort((a, b) => a.userId.compareTo(b.userId));
    final candidate = candidates.isEmpty ? null : candidates.first;
    final onRead = onEarliestActiveSigMember;
    onEarliestActiveSigMember = null;
    onRead?.call();
    return candidate;
  }

  @override
  Future<List<MembershipDocument>> subgroupMembershipsForUser(
    String uid,
    String sigId,
  ) async => [
    for (final entry in documents.entries)
      if (entry.key.startsWith('subgroups/') &&
          entry.key.endsWith('/members/$uid') &&
          entry.value['sigId'] == sigId)
        MembershipDocument(entry.key, Map.of(entry.value)),
  ];

  @override
  Future<void> markLeft(
    List<MembershipDocument> documentsToUpdate,
    String requestId,
  ) async {
    for (final document in documentsToUpdate) {
      final current = documents[document.path];
      if (current?['status'] != 'left') {
        current!['status'] = 'left';
        current['removalRequestId'] = requestId;
      }
    }
  }
}

class _FakeMembershipTransaction implements MembershipTransaction {
  _FakeMembershipTransaction(this.store);
  final _FakeMembershipStore store;
  final _writes = <String, Map<String, dynamic>?>{};
  var _hasWritten = false;

  @override
  Future<Map<String, dynamic>?> get(String path) async {
    if (_hasWritten) throw StateError('Transaction read occurred after write.');
    final value = store.documents[path];
    return value == null ? null : Map.of(value);
  }

  @override
  void set(String path, Map<String, dynamic> data) {
    _hasWritten = true;
    _writes[path] = Map.of(data);
  }

  @override
  void update(String path, Map<String, dynamic> data) {
    _hasWritten = true;
    store.updateCount++;
    final value = Map<String, dynamic>.of(store.documents[path]!);
    for (final entry in data.entries) {
      if (entry.value == FieldValue.delete()) {
        value.remove(entry.key);
      } else {
        value[entry.key] = entry.value;
      }
    }
    _writes[path] = value;
  }

  void commit() {
    for (final entry in _writes.entries) {
      final value = entry.value;
      if (value == null) {
        store.documents.remove(entry.key);
      } else {
        store.documents[entry.key] = value;
      }
    }
  }
}
