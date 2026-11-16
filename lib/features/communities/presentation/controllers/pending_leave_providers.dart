import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/controllers/auth_providers.dart';
import '../../../study/data/firestore_study_repository.dart';
import '../../data/pending_leave_recovery.dart';
import 'community_providers.dart';

final pendingLeaveRecoveryProvider = Provider<PendingLeaveRecovery>(
  (ref) => PendingLeaveRecovery(ref.watch(studyRepositoryProvider)),
);

final pendingLeaveCountProvider = StreamProvider.autoDispose<int>((ref) {
  final user = ref.watch(authStateProvider.select((auth) => auth.userId));
  // Refresh after membership actions, including successful finalization (which
  // need not modify the already-completed cleanup request).
  ref.watch(communityCatalogProvider);
  if (user == null) return Stream.value(0);
  return ref.watch(pendingLeaveRecoveryProvider).watchActionableCount();
}, dependencies: [communityCatalogProvider]);
