import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/community_models.dart';
import '../../data/community_repository.dart';

final communityRepositoryProvider = Provider<CommunityRepository>(
  (ref) => throw StateError(
    'No community repository configured. Use the preview entry point.',
  ),
);

final communityCatalogProvider =
    AsyncNotifierProvider<CommunityController, CommunityCatalog>(
      CommunityController.new,
      retry: (count, error) => null, // Recovery is explicit through Retry.
    );

class CommunityController extends AsyncNotifier<CommunityCatalog> {
  @override
  Future<CommunityCatalog> build() =>
      ref.watch(communityRepositoryProvider).loadCatalog();

  Future<void> setSigMembership(String id, MembershipState value) async {
    final result = await ref
        .read(communityRepositoryProvider)
        .setSigMembership(id, value);
    if (ref.mounted) state = AsyncData(result);
  }

  Future<void> setSubgroupMembership(String id, MembershipState value) async {
    final result = await ref
        .read(communityRepositoryProvider)
        .setSubgroupMembership(id, value);
    if (ref.mounted) state = AsyncData(result);
  }
}
