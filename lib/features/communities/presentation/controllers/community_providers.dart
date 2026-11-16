import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app_mode.dart';
import '../../../../core/models/community_models.dart';
import '../../../auth/domain/auth_state.dart';
import '../../../auth/presentation/controllers/auth_providers.dart';
import '../../../profile/presentation/controllers/profile_providers.dart';
import '../../data/community_repository.dart';
import '../../data/firestore_community_repository.dart';
import '../../data/firestore_membership_repository.dart';
import '../../data/spark_membership_cleanup.dart';
import '../../../study/data/firestore_study_repository.dart';

final communityRepositoryProvider = Provider<CommunityRepository>(
  (ref) => FirestoreCommunityRepository(
    membershipRepository: ref.watch(membershipRepositoryProvider),
    completeOwnCleanup: (id) =>
        SparkMembershipCleanup(ref.read(studyRepositoryProvider)).complete(id),
    catalogStore: ref.watch(communityCatalogDocumentStoreProvider),
    currentUserId: () => _currentAuthenticatedUid(ref.read(authStateProvider)),
    loadCurrentProfile: () => ref.read(currentProfileProvider.future),
  ),
);

final communityCatalogProvider =
    AsyncNotifierProvider<CommunityController, CommunityCatalog>(
      CommunityController.new,
      retry: (count, error) => null, // Recovery is explicit through Retry.
      dependencies: [appModeProvider],
    );

class CommunityController extends AsyncNotifier<CommunityCatalog> {
  @override
  Future<CommunityCatalog> build() {
    // Rebuild on account changes so another user's cached membership snapshot
    // is never retained after authentication switches.
    if (ref.watch(appModeProvider) != AppMode.preview) {
      ref.watch(authStateProvider.select((identity) => identity.userId));
    }
    return ref.watch(communityRepositoryProvider).loadCatalog();
  }

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

String? _currentAuthenticatedUid(AuthState auth) => switch (auth.status) {
  AuthStatus.ready || AuthStatus.incompleteProfile => auth.userId,
  AuthStatus.loading || AuthStatus.signedOut => null,
};
