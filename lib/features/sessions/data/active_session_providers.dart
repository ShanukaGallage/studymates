import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/active_room_session.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/presentation/controllers/auth_providers.dart';
import 'active_session_repository.dart';
import '../../study/data/firestore_study_repository.dart';

final activeSessionRepositoryProvider = Provider<ActiveSessionRepository>(
  (ref) => ref.watch(studyRepositoryProvider),
);

/// Session state scoped to the authenticated account.
///
/// This provider deliberately returns [AsyncValue] so a UID change selects a
/// fresh account-keyed stream rather than exposing the former account's cached
/// session while the new lookup starts.
final currentUserActiveSessionProvider =
    Provider<AsyncValue<ActiveRoomSession?>>((ref) {
      final identity = ref.watch(authStateProvider);
      switch (identity.status) {
        case AuthStatus.loading:
          return const AsyncLoading<ActiveRoomSession?>();
        case AuthStatus.signedOut:
          return const AsyncData<ActiveRoomSession?>(null);
        case AuthStatus.incompleteProfile:
        case AuthStatus.ready:
          final userId = identity.userId;
          if (userId == null || userId.trim().isEmpty) {
            return const AsyncData<ActiveRoomSession?>(null);
          }
          return ref.watch(_activeSessionForUserProvider(userId));
      }
    });

final _activeSessionForUserProvider = StreamProvider.autoDispose
    .family<ActiveRoomSession?, String>((ref, userId) {
      final authenticatedUserId = ref.watch(
        authStateProvider.select((identity) => identity.userId),
      );
      if (authenticatedUserId != userId) return const Stream.empty();
      return ref
          .watch(activeSessionRepositoryProvider)
          .watchCurrentUserActiveSession()
          .where((session) => session == null || session.userId == userId);
    });