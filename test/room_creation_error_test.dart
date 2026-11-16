import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studymates/features/study/data/firestore_study_repository.dart';
import 'package:studymates/features/study/presentation/room_creation_error.dart';

void main() {
  test(
    'room creation distinguishes eligibility, permission and network failures',
    () {
      expect(
        roomCreationError(const StudyFailure('Join the subgroup first.')),
        'Join the subgroup first.',
      );
      expect(
        roomCreationError(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          ),
        ),
        contains('deploy the current Firestore rules'),
      );
      expect(
        roomCreationError(
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        ),
        contains('internet connection'),
      );
      expect(
        roomCreationError(
          FirebaseException(plugin: 'cloud_firestore', code: 'unauthenticated'),
        ),
        contains('Sign in again'),
      );
    },
  );
}
