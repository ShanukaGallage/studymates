import '../../../core/models/community_models.dart';

abstract interface class CommunityRepository {
  Future<CommunityCatalog> loadCatalog();
  Future<CommunityCatalog> createSig({
    required String name,
    required String category,
    required String description,
  });
  Future<CommunityCatalog> createSubgroup({
    required String sigId,
    required String name,
    required String description,
  });
  Future<CommunityCatalog> updateSubgroup({
    required String sigId,
    required String subgroupId,
    required String name,
    required String description,
  });
  Future<CommunityCatalog> deleteSubgroup({
    required String sigId,
    required String subgroupId,
  });
  // Return the updated current-user snapshot, so all consumers stay consistent.
  Future<CommunityCatalog> setSigMembership(String id, MembershipState value);
  Future<CommunityCatalog> setSubgroupMembership(
    String id,
    MembershipState value,
  );
}
