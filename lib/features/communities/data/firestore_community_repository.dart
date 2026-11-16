import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/community_models.dart';
import 'community_repository.dart';
import 'firestore_membership_repository.dart';
import 'membership_repository.dart';

/// Firestore-backed catalog composition. Membership documents are never
/// enumerated: [MembershipRepository] checks only the authenticated user's
/// membership paths and owns all membership mutations.
class FirestoreCommunityRepository implements CommunityRepository {
  FirestoreCommunityRepository({
    required MembershipRepository membershipRepository,
    required this.loadCurrentProfile,
    required this.currentUserId,
    CommunityCatalogDocumentStore? catalogStore,
    FirebaseFirestore? firestore,
    this.cleanupTimeout = const Duration(seconds: 30),
  }) : _membership = membershipRepository,
       _catalog =
           catalogStore ??
           FirestoreCommunityCatalogDocumentStore(
             firestore ?? FirebaseFirestore.instance,
           );

  final MembershipRepository _membership;
  final Future<UserProfile?> Function() loadCurrentProfile;
  final String? Function() currentUserId;
  final CommunityCatalogDocumentStore _catalog;
  final Duration cleanupTimeout;

  @override
  Future<CommunityCatalog> loadCatalog() async {
    _requireCurrentUser();
    try {
      final results = await Future.wait([
        _catalog.loadSigs(),
        _catalog.loadSubgroups(),
        loadCurrentProfile(),
      ]);
      final profile = results[2] as UserProfile?;
      if (profile == null) {
        throw const RepositoryException(RepositoryError.unavailable);
      }
      final sigDocuments = results[0] as List<CommunityCatalogDocument>;
      final subgroupDocuments = results[1] as List<CommunityCatalogDocument>;
      final allSigs = sigDocuments.map(_sigFromDocument).toList();
      final activeSigs = allSigs
          .where((sig) => _documentStatus(sigDocuments, sig.id) == 'active')
          .toList();
      final activeSigIds = activeSigs.map((sig) => sig.id).toSet();
      final activeSubgroups = subgroupDocuments
          .where(
            (document) =>
                _status(document.data, optional: true) == 'active' &&
                activeSigIds.contains(_requiredString(document.data, 'sigId')),
          )
          .map(_subgroupFromDocument)
          .toList();

      final sigMemberships = await Future.wait(
        activeSigs.map((sig) => _membership.checkSigMembership(sigId: sig.id)),
      );
      final subgroupMemberships = await Future.wait(
        activeSubgroups.map(
          (group) => _membership.checkSubgroupMembership(
            sigId: group.sigId,
            subgroupId: group.id,
          ),
        ),
      );

      return CommunityCatalog(
        profile: profile,
        sigs: [
          for (var i = 0; i < activeSigs.length; i++)
            activeSigs[i].withMembership(_toMembershipState(sigMemberships[i])),
        ],
        subgroups: [
          for (var i = 0; i < activeSubgroups.length; i++)
            activeSubgroups[i].withMembership(
              _toMembershipState(subgroupMemberships[i]),
            ),
        ],
      );
    } on FirebaseException {
      throw const RepositoryException(RepositoryError.unavailable);
    } on FormatException {
      throw const RepositoryException(RepositoryError.unavailable);
    }
  }

  @override
  Future<CommunityCatalog> setSigMembership(
    String id,
    MembershipState value,
  ) async {
    final catalog = await loadCatalog();
    if (catalog.sig(id) == null) {
      throw const RepositoryException(RepositoryError.notFound);
    }
    if (value == MembershipState.joined) {
      try {
        await _membership.joinSig(sigId: id);
      } on MembershipRepositoryException catch (error) {
        if (error.code == MembershipRepositoryError.notMember) {
          throw const RepositoryException(RepositoryError.unavailable);
        }
        rethrow;
      }
      return loadCatalog();
    }
    final request = await _membership.beginSigLeave(sigId: id);
    await _awaitCleanupAndFinalize(request.requestId);
    return loadCatalog();
  }

  @override
  Future<CommunityCatalog> setSubgroupMembership(
    String id,
    MembershipState value,
  ) async {
    final catalog = await loadCatalog();
    final subgroup = catalog.subgroup(id);
    if (subgroup == null) {
      throw const RepositoryException(RepositoryError.notFound);
    }
    if (value == MembershipState.joined) {
      try {
        await _membership.joinSubgroup(
          sigId: subgroup.sigId,
          subgroupId: subgroup.id,
        );
      } on MembershipRepositoryException catch (error) {
        if (error.code == MembershipRepositoryError.notMember) {
          throw const RepositoryException(RepositoryError.membershipRequired);
        }
        rethrow;
      }
      return loadCatalog();
    }
    try {
      final request = await _membership.beginSubgroupLeave(
        sigId: subgroup.sigId,
        subgroupId: subgroup.id,
      );
      await _awaitCleanupAndFinalize(request.requestId);
    } on MembershipRepositoryException catch (error) {
      if (error.code != MembershipRepositoryError.notMember) rethrow;
    }
    return loadCatalog();
  }

  Future<void> _awaitCleanupAndFinalize(String requestId) async {
    await _membership
        .watchCleanupRequest(requestId)
        .firstWhere(
          (request) => request?.status == MembershipCleanupStatus.completed,
        )
        .timeout(cleanupTimeout);
    await _membership.finalizeMembershipRemoval(requestId);
  }

  String _requireCurrentUser() {
    final uid = currentUserId()?.trim();
    if (uid == null || uid.isEmpty) {
      throw const MembershipRepositoryException(
        MembershipRepositoryError.notAuthenticated,
      );
    }
    return uid;
  }

  MembershipState _toMembershipState(MembershipCheckResult result) =>
      switch (result) {
        MembershipCheckResult.member => MembershipState.joined,
        MembershipCheckResult.nonMember => MembershipState.notJoined,
        MembershipCheckResult.permissionDenied =>
          throw const MembershipRepositoryException(
            MembershipRepositoryError.permissionDenied,
          ),
        MembershipCheckResult.unavailable =>
          throw const MembershipRepositoryException(
            MembershipRepositoryError.unavailable,
          ),
      };

  SigSummary _sigFromDocument(CommunityCatalogDocument document) {
    final data = document.data;
    _status(data);
    return SigSummary(
      id: document.id,
      name: _requiredString(data, 'name'),
      category: _requiredString(data, 'category'),
      description: _requiredString(data, 'description'),
      ownerId: _requiredString(data, 'ownerId'),
    );
  }

  SubgroupSummary _subgroupFromDocument(CommunityCatalogDocument document) =>
      SubgroupSummary(
        id: document.id,
        sigId: _requiredString(document.data, 'sigId'),
        name: _requiredString(document.data, 'name'),
        description: _requiredString(document.data, 'description'),
      );

  String _documentStatus(List<CommunityCatalogDocument> documents, String id) =>
      _status(documents.firstWhere((document) => document.id == id).data);

  String _status(Map<String, dynamic> data, {bool optional = false}) {
    final value = data['status'] ?? (optional ? 'active' : null);
    if (value is! String || !const {'active', 'closed'}.contains(value)) {
      throw const FormatException('Invalid community status.');
    }
    return value;
  }

  String _requiredString(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Invalid community field: $key.');
    }
    return value;
  }
}

final communityCatalogDocumentStoreProvider =
    Provider<CommunityCatalogDocumentStore>(
      (ref) =>
          FirestoreCommunityCatalogDocumentStore(FirebaseFirestore.instance),
    );

abstract interface class CommunityCatalogDocumentStore {
  Future<List<CommunityCatalogDocument>> loadSigs();
  Future<List<CommunityCatalogDocument>> loadSubgroups();
}

final class CommunityCatalogDocument {
  const CommunityCatalogDocument({required this.id, required this.data});
  final String id;
  final Map<String, dynamic> data;
}

final class FirestoreCommunityCatalogDocumentStore
    implements CommunityCatalogDocumentStore {
  FirestoreCommunityCatalogDocumentStore(this._firestore);
  final FirebaseFirestore _firestore;

  @override
  Future<List<CommunityCatalogDocument>> loadSigs() async =>
      (await _firestore
              .collection(FirestoreMembershipRepository.sigsCollection)
              .get())
          .docs
          .map(
            (document) => CommunityCatalogDocument(
              id: document.id,
              data: document.data(),
            ),
          )
          .toList(growable: false);

  @override
  Future<List<CommunityCatalogDocument>> loadSubgroups() async =>
      (await _firestore
              .collection(FirestoreMembershipRepository.subgroupsCollection)
              .get())
          .docs
          .map(
            (document) => CommunityCatalogDocument(
              id: document.id,
              data: document.data(),
            ),
          )
          .toList(growable: false);
}
