import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/controllers/auth_providers.dart';
import '../data/common_hall_repository.dart';
import '../data/firestore_common_hall_repository.dart';
import '../data/hall_background_service.dart';
import '../domain/common_hall_models.dart';

final commonHallRepositoryProvider = Provider<CommonHallRepository>(
  (ref) => FirestoreCommonHallRepository(
    db: FirebaseFirestore.instance,
    currentUid: () => ref.read(authStateProvider).userId,
  ),
);
final hallBackgroundServiceProvider = Provider<HallBackgroundService>(
  (ref) => AndroidHallBackgroundService(),
);

/// Rebind by UID, never retaining another account's active session on switching.
final commonHallSessionProvider = Provider<AsyncValue<HallSession?>>((ref) {
  final user = ref.watch(authStateProvider.select((auth) => auth.userId));
  return user == null
      ? const AsyncData(null)
      : ref.watch(_sessionForUser(user));
});
final _sessionForUser = StreamProvider.autoDispose.family<HallSession?, String>(
  (ref, user) => ref
      .watch(commonHallRepositoryProvider)
      .watchCurrentSession()
      .where((value) => value == null || value.userId == user),
  retry: (_, _) => null,
);
final commonHallParticipantsProvider =
    StreamProvider.autoDispose<List<HallParticipant>>((ref) {
      final user = ref.watch(authStateProvider.select((auth) => auth.userId));
      return user == null
          ? Stream.value([])
          : ref.watch(commonHallRepositoryProvider).watchParticipants();
    }, retry: (_, _) => null);

final hallServiceStateProvider =
    NotifierProvider<HallServiceController, AsyncValue<void>>(
      HallServiceController.new,
    );

class HallServiceController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);
  void interrupted() {
    state = AsyncError(
      const HallFailure(
        'The background timer lost its connection. Reconnect and retry, or save your confirmed time.',
      ),
      StackTrace.current,
    );
  }

  Future<void> start(HallSession session) async {
    state = const AsyncLoading();
    try {
      await ref.read(hallBackgroundServiceProvider).start(session);
      if (ref.mounted) state = const AsyncData(null);
    } catch (error, stack) {
      if (ref.mounted) state = AsyncError(error, stack);
      rethrow;
    }
  }
}

String hallError(Object error) => error is HallFailure
    ? error.message
    : 'Common Hall could not confirm the operation. Check your connection and retry.';
