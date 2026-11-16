import 'package:firebase_core/firebase_core.dart';

import '../data/firestore_study_repository.dart';

String roomCreationError(Object error) {
  if (error is StudyFailure) return error.message;
  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' => 'Room creation was denied by Firebase. Confirm you joined both the SIG and subgroup. If you have, deploy the current Firestore rules for this app version.',
      'unauthenticated' =>
        'Your sign-in expired. Sign in again before creating a room.',
      'unavailable' || 'deadline-exceeded' => 'Firebase could not be reached. Check your internet connection and retry.',
      'aborted' => 'The room changed while saving. Please retry creation.',
      _ =>
        'Room creation could not be confirmed (${error.code}). Refresh the room list before retrying.',
    };
  }
  return 'Room creation could not be confirmed. Refresh the room list before retrying.';
}
