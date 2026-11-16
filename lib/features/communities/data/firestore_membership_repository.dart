import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/auth_state.dart';
import '../../auth/presentation/controllers/auth_providers.dart';
import 'membership_repository.dart';

final membershipRepositoryProvider = Provider<MembershipRepository>(
  (ref) => FirestoreMembershipRepository(
    firestore: FirebaseFirestore.instance,
    currentUserId: () => _authenticatedUid(ref.read(authStateProvider)),
  ),
);

String? _authenticatedUid(AuthState auth) => switch (auth.status) {
  AuthStatus.ready || AuthStatus.incompleteProfile => auth.userId,
  AuthStatus.loading || AuthStatus.signedOut => null,
};

class FirestoreMembershipRepository implements MembershipRepository {
  FirestoreMembershipRepository({
    FirebaseFirestore? firestore,
    required this.currentUserId,
    MembershipDocumentStore? documentStore,
  }) : _documents =
           documentStore ??
           _FirestoreMembershipDocumentStore(
             firestore ?? FirebaseFirestore.instance,
           );

  static const sigsCollection = 'sigs';
  static const subgroupsCollection = 'subgroups';
  static const membersCollection = 'members';
  static const cleanupRequestsCollection = 'membershipCleanupRequests';

  final String? Function() currentUserId;
  final MembershipDocumentStore _documents;

  String _uid() {
    final uid = currentUserId()?.trim();
    if (uid == null || uid.isEmpty) {
      throw const MembershipRepositoryException(
        MembershipRepositoryError.notAuthenticated,
      );
    }
    return uid;
  }

  String _sigPath(String sigId) => '$sigsCollection/$sigId';
  String _sigMemberPath(String sigId, String uid) =>
      '${_sigPath(sigId)}/$membersCollection/$uid';
  String _subgroupPath(String subgroupId) => '$subgroupsCollection/$subgroupId';
  String _subgroupMemberPath(String subgroupId, String uid) =>
      '${_subgroupPath(subgroupId)}/$membersCollection/$uid';
  String _requestPath(String requestId) =>
      '$cleanupRequestsCollection/$requestId';

  @override
  Future<MembershipCheckResult> checkSigMembership({
    required String sigId,
  }) async {
    final uid = _uidOrPermissionDenied();
    if (uid == null || sigId.trim().isEmpty) {
      return MembershipCheckResult.permissionDenied;
    }
    try {
      final sig = await _documents.get(_sigPath(sigId));
      if (sig == null) return MembershipCheckResult.nonMember;
      final status = _sigStatus(sig);
      final ownerId = _requiredString(sig, 'ownerId');
      if (status != _activeStatus) return MembershipCheckResult.nonMember;
      final membership = await _documents.get(_sigMemberPath(sigId, uid));
      if (membership != null) {
        final active = _isActiveMembership(membership, uid, sigId: sigId);
        if (!active) return MembershipCheckResult.nonMember;
      }
      if (ownerId == uid) return MembershipCheckResult.member;
      return _isActiveMembership(membership, uid, sigId: sigId)
          ? MembershipCheckResult.member
          : MembershipCheckResult.nonMember;
    } on FirebaseException catch (error) {
      return _checkError(error);
    } on _MalformedMembershipDocument {
      return MembershipCheckResult.unavailable;
    } on Object {
      return MembershipCheckResult.unavailable;
    }
  }

  @override
  Future<MembershipCheckResult> checkSubgroupMembership({
    required String sigId,
    required String subgroupId,
  }) async {
    final uid = _uidOrPermissionDenied();
    if (uid == null || sigId.trim().isEmpty || subgroupId.trim().isEmpty) {
      return MembershipCheckResult.permissionDenied;
    }
    try {
      final values = await _readEligibility(
        read: _documents.get,
        uid: uid,
        sigId: sigId,
        subgroupId: subgroupId,
      );
      return values
          ? MembershipCheckResult.member
          : MembershipCheckResult.nonMember;
    } on FirebaseException catch (error) {
      return _checkError(error);
    } on Object {
      return MembershipCheckResult.unavailable;
    }
  }

  @override
  Future<MembershipCheckResult> verifyRoomEligibilityInTransaction({
    required Transaction transaction,
    required String sigId,
    required String subgroupId,
  }) async {
    final uid = _uidOrPermissionDenied();
    if (uid == null || sigId.trim().isEmpty || subgroupId.trim().isEmpty) {
      return MembershipCheckResult.permissionDenied;
    }
    try {
      return await _readEligibility(
            read: (path) => _documents.getInTransaction(transaction, path),
            uid: uid,
            sigId: sigId,
            subgroupId: subgroupId,
          )
          ? MembershipCheckResult.member
          : MembershipCheckResult.nonMember;
    } on FirebaseException catch (error) {
      return _checkError(error);
    } on Object {
      return MembershipCheckResult.unavailable;
    }
  }

  String? _uidOrPermissionDenied() {
    try {
      return _uid();
    } on MembershipRepositoryException {
      return null;
    }
  }

  Future<bool> _readEligibility({
    required Future<Map<String, dynamic>?> Function(String path) read,
    required String uid,
    required String sigId,
    required String subgroupId,
  }) async {
    // All four reads occur before M3 performs any writes in its transaction.
    final sig = await read(_sigPath(sigId));
    final sigMember = await read(_sigMemberPath(sigId, uid));
    final subgroup = await read(_subgroupPath(subgroupId));
    final subgroupMember = await read(_subgroupMemberPath(subgroupId, uid));
    if (sig == null || subgroup == null) return false;
    if (_sigStatus(sig) != _activeStatus) return false;
    if (_requiredString(subgroup, 'sigId') != sigId) return false;
    if (_optionalStatus(subgroup) != _activeStatus) return false;
    final isOwner = _requiredString(sig, 'ownerId') == uid;
    final hasActiveMembership = _isActiveMembership(
      sigMember,
      uid,
      sigId: sigId,
    );
    final hasSigMembership = isOwner
        ? (sigMember == null || hasActiveMembership)
        : hasActiveMembership;
    return hasSigMembership &&
        _isActiveMembership(subgroupMember, uid, sigId: sigId);
  }

  @override
  Future<void> joinSig({required String sigId}) async {
    final uid = _uid();
    if (sigId.trim().isEmpty) _throwInvalidRequest();
    try {
      await _documents.runTransaction((transaction) async {
        final sig = await transaction.get(_sigPath(sigId));
        final member = await transaction.get(_sigMemberPath(sigId, uid));
        if (sig == null || _sigStatus(sig) != _activeStatus) _throwNotMember();
        if (member?['status'] == 'removalPending' ||
            member?['status'] == 'left') {
          _throwNotMember();
        }
        if (_requiredString(sig, 'ownerId') == uid) return;
        final priorStatus = member == null ? null : _memberStatus(member);
        if (priorStatus == 'removalPending') _throwNotMember();
        if (priorStatus == _activeStatus) return;
        final revision = _revision(sig);
        final now = Timestamp.now();
        transaction.set(_sigMemberPath(sigId, uid), {
          'userId': uid,
          'status': _activeStatus,
          'joinedAt': priorStatus == 'active'
              ? (member?['joinedAt'] ?? now)
              : now,
          'updatedAt': now,
          'sigId': sigId,
        });
        transaction.update(_sigPath(sigId), {
          'membershipRevision': revision + 1,
        });
      });
    } on FirebaseException catch (error) {
      _throwRepositoryError(error);
    }
  }

  @override
  Future<void> joinSubgroup({
    required String sigId,
    required String subgroupId,
  }) async {
    final uid = _uid();
    if (sigId.trim().isEmpty || subgroupId.trim().isEmpty) {
      _throwInvalidRequest();
    }
    try {
      await _documents.runTransaction((transaction) async {
        final sig = await transaction.get(_sigPath(sigId));
        final sigMember = await transaction.get(_sigMemberPath(sigId, uid));
        final subgroup = await transaction.get(_subgroupPath(subgroupId));
        final subgroupMember = await transaction.get(
          _subgroupMemberPath(subgroupId, uid),
        );
        if (sig == null || _sigStatus(sig) != _activeStatus) _throwNotMember();
        if (subgroup == null ||
            _requiredString(subgroup, 'sigId') != sigId ||
            _optionalStatus(subgroup) != _activeStatus) {
          _throwNotMember();
        }
        final isOwner = _requiredString(sig, 'ownerId') == uid;
        if (sigMember?['status'] == 'removalPending' ||
            sigMember?['status'] == 'left') {
          _throwNotMember();
        }
        if (!isOwner && !_isActiveMembership(sigMember, uid, sigId: sigId)) {
          _throwNotMember();
        }
        if (subgroupMember != null &&
            (_requiredString(subgroupMember, 'userId') != uid ||
                _requiredString(subgroupMember, 'sigId') != sigId ||
                _memberStatus(subgroupMember) == 'removalPending')) {
          _throwNotMember();
        }
        if (subgroupMember != null &&
            _memberStatus(subgroupMember) == _activeStatus) {
          return;
        }
        final now = Timestamp.now();
        transaction.set(_subgroupMemberPath(subgroupId, uid), {
          'userId': uid,
          'sigId': sigId,
          'status': _activeStatus,
          'joinedAt': subgroupMember?['joinedAt'] ?? now,
          'updatedAt': now,
        });
      });
    } on FirebaseException catch (error) {
      _throwRepositoryError(error);
    }
  }

  @override
  Future<MembershipCleanupRequest> beginSubgroupLeave({
    required String sigId,
    required String subgroupId,
  }) async {
    final uid = _uid();
    if (sigId.trim().isEmpty || subgroupId.trim().isEmpty) {
      _throwInvalidRequest();
    }
    final requestId = _documents.newRequestId();
    try {
      return await _documents.runTransaction((transaction) async {
        final sig = await transaction.get(_sigPath(sigId));
        final parentMember = await transaction.get(_sigMemberPath(sigId, uid));
        final subgroup = await transaction.get(_subgroupPath(subgroupId));
        final membershipPath = _subgroupMemberPath(subgroupId, uid);
        final member = await transaction.get(membershipPath);
        if (member?['status'] == 'removalPending') {
          return _pendingRequest(
            transaction,
            member!,
            uid: uid,
            sigId: sigId,
            scope: MembershipRemovalScope.subgroup,
            subgroupId: subgroupId,
          );
        }
        if (sig == null ||
            _sigStatus(sig) != _activeStatus ||
            subgroup == null ||
            _requiredString(subgroup, 'sigId') != sigId) {
          _throwNotMember();
        }
        final isOwner = _requiredString(sig, 'ownerId') == uid;
        if (parentMember?['status'] == 'removalPending' ||
            parentMember?['status'] == 'left') {
          _throwNotMember();
        }
        if (!isOwner && !_isActiveMembership(parentMember, uid, sigId: sigId)) {
          _throwNotMember();
        }
        if (!_isActiveMembership(member, uid, sigId: sigId)) {
          _throwNotMember();
        }
        final now = Timestamp.now();
        final request = _requestMap(
          requestId: requestId,
          uid: uid,
          sigId: sigId,
          scope: MembershipRemovalScope.subgroup,
          subgroupId: subgroupId,
          now: now,
        );
        transaction.update(membershipPath, {
          'status': 'removalPending',
          'removalRequestId': requestId,
          'updatedAt': now,
        });
        transaction.set(_requestPath(requestId), request);
        return _requestFromMap(requestId, request);
      });
    } on FirebaseException catch (error) {
      _throwRepositoryError(error);
    }
  }

  @override
  Future<MembershipCleanupRequest> beginSigLeave({
    required String sigId,
  }) async {
    final uid = _uid();
    if (sigId.trim().isEmpty) _throwInvalidRequest();
    // Candidate lookup is outside the transaction because Firestore's mobile
    // Transaction API reads document references, not queries. membershipRevision
    // lets the transaction detect a changed eligible-member set and retry.
    for (var attempt = 0; attempt < 5; attempt++) {
      final sigPath = _sigPath(sigId);
      final memberPath = _sigMemberPath(sigId, uid);
      final sigBefore = await _documents.get(sigPath);
      if (sigBefore == null) _throwNotMember();
      final revisionBefore = _revision(sigBefore);
      final isOwner = _requiredString(sigBefore, 'ownerId') == uid;
      final successor = isOwner
          ? await _documents.earliestActiveSigMember(sigId, excludingUid: uid)
          : null;
      final requestId = _documents.newRequestId();
      try {
        return await _documents.runTransaction((transaction) async {
          final sig = await transaction.get(sigPath);
          final member = await transaction.get(memberPath);
          final successorPath = successor == null
              ? null
              : _sigMemberPath(sigId, successor.userId);
          final successorDoc = successorPath == null
              ? null
              : await transaction.get(successorPath);
          if (sig == null || _revision(sig) != revisionBefore) {
            throw const _RetryOwnerSelection();
          }
          final isCurrentOwner = _requiredString(sig, 'ownerId') == uid;
          // A retry must resume the durable request even though the member is
          // no longer active. In particular, owner departure may already have
          // transferred ownership or closed the SIG.
          if (member?['status'] == 'removalPending') {
            return _pendingRequest(
              transaction,
              member!,
              uid: uid,
              sigId: sigId,
              scope: MembershipRemovalScope.sig,
            );
          }
          if (!isCurrentOwner &&
              !_isActiveMembership(member, uid, sigId: sigId)) {
            _throwNotMember();
          }
          if (isCurrentOwner &&
              successor != null &&
              !_isActiveMembership(
                successorDoc,
                successor.userId,
                sigId: sigId,
              )) {
            throw const _RetryOwnerSelection();
          }
          final now = Timestamp.now();
          final request = _requestMap(
            requestId: requestId,
            uid: uid,
            sigId: sigId,
            scope: MembershipRemovalScope.sig,
            now: now,
          );
          if (isCurrentOwner) {
            if (successor == null) {
              transaction.update(sigPath, {
                'status': 'closed',
                'membershipRevision': revisionBefore + 1,
                'updatedAt': now,
              });
            } else {
              transaction.update(sigPath, {
                'ownerId': successor.userId,
                'membershipRevision': revisionBefore + 1,
                'updatedAt': now,
              });
            }
          } else {
            transaction.update(sigPath, {
              'membershipRevision': revisionBefore + 1,
            });
          }
          transaction.set(memberPath, {
            'userId': uid,
            'sigId': sigId,
            'status': 'removalPending',
            if (member?['joinedAt'] != null) 'joinedAt': member!['joinedAt'],
            'updatedAt': now,
            'removalRequestId': requestId,
          });
          transaction.set(_requestPath(requestId), request);
          return _requestFromMap(requestId, request);
        });
      } on _RetryOwnerSelection {
        continue;
      } on FirebaseException catch (error) {
        _throwRepositoryError(error);
      }
    }
    throw const MembershipRepositoryException(
      MembershipRepositoryError.unavailable,
    );
  }

  Map<String, dynamic> _requestMap({
    required String requestId,
    required String uid,
    required String sigId,
    required MembershipRemovalScope scope,
    required Timestamp now,
    String? subgroupId,
  }) => {
    'requestId': requestId,
    'userId': uid,
    'sigId': sigId,
    'scope': scope.name,
    ...?(subgroupId == null ? null : {'subgroupId': subgroupId}),
    'status': MembershipCleanupStatus.pending.name,
    'createdAt': now,
    'updatedAt': now,
  };

  Future<MembershipCleanupRequest> _pendingRequest(
    MembershipTransaction transaction,
    Map<String, dynamic> membership, {
    required String uid,
    required String sigId,
    required MembershipRemovalScope scope,
    String? subgroupId,
  }) async {
    final requestId = _requiredString(membership, 'removalRequestId');
    // The request is read before any writes; this is an idempotent resume path.
    final data = await transaction.get(_requestPath(requestId));
    if (data == null) {
      throw const MembershipRepositoryException(
        MembershipRepositoryError.unavailable,
      );
    }
    final request = _requestFromMap(requestId, data);
    if (request.userId != uid ||
        request.sigId != sigId ||
        request.scope != scope ||
        (scope == MembershipRemovalScope.subgroup &&
            request.subgroupId != subgroupId)) {
      throw const MembershipRepositoryException(
        MembershipRepositoryError.unavailable,
      );
    }
    return request;
  }

  @override
  Stream<MembershipCleanupRequest?> watchCleanupRequest(String requestId) {
    final uid = _uid();
    if (requestId.trim().isEmpty) _throwInvalidRequest();
    return _documents.watch(_requestPath(requestId)).map((data) {
      if (data == null) return null;
      final request = _requestFromMap(requestId, data);
      if (request.userId != uid) {
        throw const MembershipRepositoryException(
          MembershipRepositoryError.permissionDenied,
        );
      }
      return request;
    });
  }

  @override
  Future<void> finalizeMembershipRemoval(String requestId) async {
    final uid = _uid();
    if (requestId.trim().isEmpty) _throwInvalidRequest();
    final requestData = await _documents.get(_requestPath(requestId));
    if (requestData == null || _requiredString(requestData, 'userId') != uid) {
      throw const MembershipRepositoryException(
        MembershipRepositoryError.permissionDenied,
      );
    }
    final request = _requestFromMap(requestId, requestData);
    if (request.status != MembershipCleanupStatus.completed) {
      throw const MembershipRepositoryException(
        MembershipRepositoryError.cleanupNotComplete,
      );
    }
    if (request.scope == MembershipRemovalScope.subgroup) {
      final path = _subgroupMemberPath(request.subgroupId!, uid);
      await _documents.runTransaction((transaction) async {
        final storedRequest = await transaction.get(_requestPath(requestId));
        final member = await transaction.get(path);
        _ensureCompletedRequest(storedRequest, requestId, uid);
        if (member?['removalRequestId'] == requestId &&
            member?['status'] == 'removalPending') {
          transaction.update(path, {
            'status': 'left',
            'updatedAt': Timestamp.now(),
            'removalRequestId': requestId,
          });
        }
      });
      return;
    }

    // Parent membership is already pending, so no new subgroup join can race
    // this lookup. Chunking makes finalization restartable for large SIGs.
    final childMemberships = await _documents.subgroupMembershipsForUser(
      uid,
      request.sigId,
    );
    for (var offset = 0; offset < childMemberships.length; offset += 400) {
      final chunk = childMemberships.skip(offset).take(400).toList();
      await _documents.markLeft(chunk, requestId);
    }
    await _documents.runTransaction((transaction) async {
      final storedRequest = await transaction.get(_requestPath(requestId));
      final memberPath = _sigMemberPath(request.sigId, uid);
      final member = await transaction.get(memberPath);
      final sigPath = _sigPath(request.sigId);
      final sig = await transaction.get(sigPath);
      _ensureCompletedRequest(storedRequest, requestId, uid);
      if (member?['removalRequestId'] == requestId) {
        // The same completed request may be finalized again after a client
        // retry. A left membership is already finalized; do not bump the SIG
        // revision again.
        if (member?['status'] == 'left') return;
        if (member?['status'] != 'removalPending') return;
        if (sig == null) _throwNotMember();
        transaction
          ..update(sigPath, {'membershipRevision': _revision(sig) + 1})
          ..update(memberPath, {
            'status': 'left',
            'updatedAt': Timestamp.now(),
            'removalRequestId': requestId,
          });
      }
    });
  }

  void _ensureCompletedRequest(
    Map<String, dynamic>? request,
    String requestId,
    String uid,
  ) {
    if (request == null ||
        _requiredString(request, 'userId') != uid ||
        _requiredString(request, 'requestId') != requestId ||
        _requiredString(request, 'status') != 'completed') {
      throw const MembershipRepositoryException(
        MembershipRepositoryError.cleanupNotComplete,
      );
    }
  }

  bool _isActiveMembership(
    Map<String, dynamic>? data,
    String uid, {
    String? sigId,
  }) {
    if (data == null) return false;
    if (_requiredString(data, 'userId') != uid ||
        (sigId != null && _requiredString(data, 'sigId') != sigId)) {
      throw const _MalformedMembershipDocument();
    }
    return _memberStatus(data) == _activeStatus;
  }

  String _sigStatus(Map<String, dynamic> sig) {
    final status = _requiredString(sig, 'status');
    if (status != _activeStatus && status != 'closed') {
      throw const _MalformedMembershipDocument();
    }
    return status;
  }

  String _optionalStatus(Map<String, dynamic> document) {
    final status = document['status'] ?? _activeStatus;
    if (status is! String || (status != _activeStatus && status != 'closed')) {
      throw const _MalformedMembershipDocument();
    }
    return status;
  }

  String _memberStatus(Map<String, dynamic> membership) {
    final status = membership['status'];
    if (status is! String ||
        !const {'active', 'removalPending', 'left'}.contains(status)) {
      throw const _MalformedMembershipDocument();
    }
    return status;
  }

  String _requiredString(Map<String, dynamic> data, String field) {
    final value = data[field];
    if (value is! String || value.trim().isEmpty) {
      throw const _MalformedMembershipDocument();
    }
    return value;
  }

  int _revision(Map<String, dynamic> sig) {
    final revision = sig['membershipRevision'] ?? 0;
    if (revision is! int || revision < 0) {
      throw const _MalformedMembershipDocument();
    }
    return revision;
  }

  MembershipCheckResult _checkError(FirebaseException error) =>
      switch (error.code) {
        'permission-denied' ||
        'unauthenticated' => MembershipCheckResult.permissionDenied,
        'unavailable' ||
        'deadline-exceeded' ||
        'network-request-failed' ||
        'cancelled' => MembershipCheckResult.unavailable,
        _ => MembershipCheckResult.unavailable,
      };

  Never _throwRepositoryError(FirebaseException error) =>
      throw switch (error.code) {
        'permission-denied' ||
        'unauthenticated' => const MembershipRepositoryException(
          MembershipRepositoryError.permissionDenied,
        ),
        _ => const MembershipRepositoryException(
          MembershipRepositoryError.unavailable,
        ),
      };

  Never _throwNotMember() => throw const MembershipRepositoryException(
    MembershipRepositoryError.notMember,
  );

  Never _throwInvalidRequest() => throw const MembershipRepositoryException(
    MembershipRepositoryError.invalidRequest,
  );
}

class _RetryOwnerSelection implements Exception {
  const _RetryOwnerSelection();
}

class _MalformedMembershipDocument implements Exception {
  const _MalformedMembershipDocument();
}

MembershipCleanupRequest _requestFromMap(
  String requestId,
  Map<String, dynamic> data,
) {
  final storedId = data['requestId'];
  final uid = data['userId'];
  final sigId = data['sigId'];
  final scope = data['scope'];
  final status = data['status'];
  final subgroupId = data['subgroupId'];
  if (storedId != requestId ||
      uid is! String ||
      uid.isEmpty ||
      sigId is! String ||
      sigId.isEmpty ||
      scope is! String ||
      status is! String ||
      (subgroupId != null && subgroupId is! String)) {
    throw const MembershipRepositoryException(
      MembershipRepositoryError.unavailable,
    );
  }
  final parsedScope = switch (scope) {
    'sig' => MembershipRemovalScope.sig,
    'subgroup' => MembershipRemovalScope.subgroup,
    _ => throw const MembershipRepositoryException(
      MembershipRepositoryError.unavailable,
    ),
  };
  final parsedStatus = switch (status) {
    'pending' => MembershipCleanupStatus.pending,
    'processing' => MembershipCleanupStatus.processing,
    'completed' => MembershipCleanupStatus.completed,
    _ => throw const MembershipRepositoryException(
      MembershipRepositoryError.unavailable,
    ),
  };
  if (parsedScope == MembershipRemovalScope.subgroup &&
      (subgroupId is! String || subgroupId.isEmpty)) {
    throw const MembershipRepositoryException(
      MembershipRepositoryError.unavailable,
    );
  }
  return MembershipCleanupRequest(
    requestId: requestId,
    userId: uid,
    sigId: sigId,
    scope: parsedScope,
    status: parsedStatus,
    subgroupId: subgroupId as String?,
  );
}

String? _requiredUserId(MembershipDocument document) =>
    document.data['userId'] is String
    ? document.data['userId'] as String
    : null;

DateTime _joinedAt(MembershipDocument document) {
  final value = document.data['joinedAt'];
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  throw const MembershipRepositoryException(
    MembershipRepositoryError.unavailable,
  );
}

abstract interface class MembershipTransaction {
  Future<Map<String, dynamic>?> get(String path);
  void set(String path, Map<String, dynamic> data);
  void update(String path, Map<String, dynamic> data);
}

final class MembershipDocument {
  const MembershipDocument(this.path, this.data);
  final String path;
  final Map<String, dynamic> data;
  String get userId => _requiredUserId(this)!;
}

/// Fakeable persistence boundary. The public transaction check still accepts
/// and passes M3's exact Cloud Firestore [Transaction] instance.
abstract interface class MembershipDocumentStore {
  String newRequestId();
  Future<Map<String, dynamic>?> get(String path);
  Stream<Map<String, dynamic>?> watch(String path);
  Future<T> runTransaction<T>(Future<T> Function(MembershipTransaction) body);
  Future<Map<String, dynamic>?> getInTransaction(
    Transaction transaction,
    String path,
  );
  Future<MembershipDocument?> earliestActiveSigMember(
    String sigId, {
    required String excludingUid,
  });
  Future<List<MembershipDocument>> subgroupMembershipsForUser(
    String uid,
    String sigId,
  );
  Future<void> markLeft(List<MembershipDocument> documents, String requestId);
}

class _FirestoreMembershipDocumentStore implements MembershipDocumentStore {
  _FirestoreMembershipDocumentStore(this._firestore);
  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _doc(String path) =>
      _firestore.doc(path);

  @override
  String newRequestId() => _firestore
      .collection(FirestoreMembershipRepository.cleanupRequestsCollection)
      .doc()
      .id;

  @override
  Future<Map<String, dynamic>?> get(String path) async =>
      (await _doc(path).get()).data();

  @override
  Stream<Map<String, dynamic>?> watch(String path) =>
      _doc(path).snapshots().map((snapshot) => snapshot.data());

  @override
  Future<T> runTransaction<T>(Future<T> Function(MembershipTransaction) body) =>
      _firestore.runTransaction(
        (transaction) =>
            body(_FirestoreMembershipTransaction(_firestore, transaction)),
      );

  @override
  Future<Map<String, dynamic>?> getInTransaction(
    Transaction transaction,
    String path,
  ) async => (await transaction.get(_doc(path))).data();

  @override
  Future<MembershipDocument?> earliestActiveSigMember(
    String sigId, {
    required String excludingUid,
  }) async {
    final query = await _firestore
        .collection(FirestoreMembershipRepository.sigsCollection)
        .doc(sigId)
        .collection(FirestoreMembershipRepository.membersCollection)
        .where('status', isEqualTo: _activeStatus)
        .get();
    final candidates =
        query.docs
            .where((doc) => doc.id != excludingUid)
            .map((doc) => MembershipDocument(doc.reference.path, doc.data()))
            .toList()
          ..sort((a, b) {
            final byJoinedAt = _joinedAt(a).compareTo(_joinedAt(b));
            if (byJoinedAt != 0) return byJoinedAt;
            return (_requiredUserId(a) ?? '').compareTo(
              _requiredUserId(b) ?? '',
            );
          });
    return candidates.isEmpty ? null : candidates.first;
  }

  @override
  Future<List<MembershipDocument>> subgroupMembershipsForUser(
    String uid,
    String sigId,
  ) async {
    final subgroups = await _firestore
        .collection(FirestoreMembershipRepository.subgroupsCollection)
        .where('sigId', isEqualTo: sigId)
        .get();
    final memberships = await Future.wait(
      subgroups.docs.map((subgroup) async {
        final reference = subgroup.reference
            .collection(FirestoreMembershipRepository.membersCollection)
            .doc(uid);
        final snapshot = await reference.get();
        final data = snapshot.data();
        if (data == null || data['userId'] != uid || data['sigId'] != sigId) {
          return null;
        }
        return MembershipDocument(reference.path, data);
      }),
    );
    return memberships.whereType<MembershipDocument>().toList();
  }

  @override
  Future<void> markLeft(
    List<MembershipDocument> documents,
    String requestId,
  ) async {
    final batch = _firestore.batch();
    for (final document in documents) {
      if (document.data['status'] != 'left') {
        batch.update(_firestore.doc(document.path), {
          'status': 'left',
          'updatedAt': FieldValue.serverTimestamp(),
          'removalRequestId': requestId,
        });
      }
    }
    await batch.commit();
  }
}

class _FirestoreMembershipTransaction implements MembershipTransaction {
  _FirestoreMembershipTransaction(this._firestore, this._transaction);
  final FirebaseFirestore _firestore;
  final Transaction _transaction;

  @override
  Future<Map<String, dynamic>?> get(String path) async =>
      (await _transaction.get(_firestore.doc(path))).data();

  @override
  void set(String path, Map<String, dynamic> data) =>
      _transaction.set(_firestore.doc(path), data);

  @override
  void update(String path, Map<String, dynamic> data) =>
      _transaction.update(_firestore.doc(path), data);
}

const _activeStatus = 'active';
