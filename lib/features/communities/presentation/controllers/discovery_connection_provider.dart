import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/controllers/auth_providers.dart';
import '../../../study/data/firestore_study_repository.dart';

/// Cache metadata is a freshness signal, not proof of internet connectivity.
/// Observe one public document; never fabricate an online/connected state.
final discoveryConnectionProvider = StreamProvider.autoDispose<bool>((ref) {
  final user = ref.watch(authStateProvider.select((auth) => auth.userId));
  if (user == null) return Stream.empty();
  return ref
      .watch(studyRepositoryProvider)
      .db
      .collection('sigs')
      .limit(1)
      .snapshots(includeMetadataChanges: true)
      .map((snapshot) => !snapshot.metadata.isFromCache);
});
