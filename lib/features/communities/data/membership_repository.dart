import 'package:cloud_firestore/cloud_firestore.dart';

enum MembershipCheckResult { member, nonMember, permissionDenied, unavailable }

enum MembershipCleanupStatus { pending, processing, completed }

enum MembershipRemovalScope { sig, subgroup }

/// Durable handoff from M2 to M3. M3 acknowledges by updating the request
/// status using its trusted cleanup handler; ordinary clients cannot do so.
final class MembershipCleanupRequest {
  const MembershipCleanupRequest({
    required this.requestId,
    required this.userId,
    required this.sigId,
    required this.scope,
    required this.status,
    this.subgroupId,
  });

  final String requestId;
  final String userId;
  final String sigId;
  final MembershipRemovalScope scope;
  final MembershipCleanupStatus status;
  final String? subgroupId;
}

abstract interface class MembershipRepository {
  Future<void> joinSig({required String sigId});

  Future<void> joinSubgroup({
    required String sigId,
    required String subgroupId,
  });

  Future<MembershipCheckResult> checkSigMembership({required String sigId});

  Future<MembershipCheckResult> checkSubgroupMembership({
    required String sigId,
    required String subgroupId,
  });

  /// Uses [transaction] directly and performs reads only. The caller must
  /// complete all transaction reads before issuing any writes.
  Future<MembershipCheckResult> verifyRoomEligibilityInTransaction({
    required Transaction transaction,
    required String sigId,
    required String subgroupId,
  });

  /// Marks membership removal pending and durably requests M3 cleanup.
  /// Returns an existing request if this user's removal is already pending.
  Future<MembershipCleanupRequest> beginSigLeave({required String sigId});

  Future<MembershipCleanupRequest> beginSubgroupLeave({
    required String sigId,
    required String subgroupId,
  });

  Stream<MembershipCleanupRequest?> watchCleanupRequest(String requestId);

  /// M2 marks membership inactive only after M3 has acknowledged cleanup.
  Future<void> finalizeMembershipRemoval(String requestId);
}

enum MembershipRepositoryError {
  notAuthenticated,
  notMember,
  invalidRequest,
  cleanupNotComplete,
  permissionDenied,
  unavailable,
}

class MembershipRepositoryException implements Exception {
  const MembershipRepositoryException(this.code);

  final MembershipRepositoryError code;

  @override
  String toString() => 'MembershipRepositoryException($code)';
}
