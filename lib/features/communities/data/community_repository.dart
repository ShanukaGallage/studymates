import '../../../core/models/community_models.dart';

abstract interface class CommunityRepository {
  Future<CommunityCatalog> loadCatalog();
  // Return the updated current-user snapshot, so all consumers stay consistent.
  Future<CommunityCatalog> setSigMembership(String id, MembershipState value);
  Future<CommunityCatalog> setSubgroupMembership(
    String id,
    MembershipState value,
  );
}
