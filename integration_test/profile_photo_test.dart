import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:studymates/core/models/profile_photo.dart';
import 'package:studymates/features/profile/data/firestore_profile_repository.dart';
import 'package:studymates/firebase_options.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('private photo persists, clears and enforces owner/size rules', (
    tester,
  ) async {
    const host = String.fromEnvironment('STUDYMATES_EMULATOR_HOST');
    if (host.isEmpty) {
      throw StateError('Local Firebase emulators are required.');
    }
    final suffix = DateTime.now().microsecondsSinceEpoch;
    final apps = <FirebaseApp>[];
    final databases = <FirebaseFirestore>[];
    final identities = <FirebaseAuth>[];
    for (var i = 0; i < 2; i++) {
      debugPrint('Profile photo: initialize client $i');
      final app = await Firebase.initializeApp(
        name: 'profile-photo-$suffix-$i',
        options: DefaultFirebaseOptions.currentPlatform,
      );
      final auth = FirebaseAuth.instanceFor(app: app);
      await auth.useAuthEmulator(host, 9099, automaticHostMapping: false);
      final db = FirebaseFirestore.instanceFor(app: app);
      db.settings = const Settings(persistenceEnabled: false);
      db.useFirestoreEmulator(host, 8080, automaticHostMapping: false);
      debugPrint('Profile photo: create isolated account $i');
      await auth
          .createUserWithEmailAndPassword(
            email: 'profile-photo-$suffix-$i@example.test',
            password: 'photo-test-password',
          )
          .timeout(const Duration(seconds: 30));
      debugPrint('Profile photo: client $i ready');
      apps.add(app);
      databases.add(db);
      identities.add(auth);
    }
    final auth = identities.first;
    final db = databases.first;
    final uid = auth.currentUser!.uid;
    final repository = FirestoreProfileRepository(
      firebaseAuth: auth,
      firestore: db,
    );
    final photo = ProfilePhoto.fromJpeg(
      img.encodeJpg(img.Image(width: 32, height: 32)),
    );
    final secondPhoto = ProfilePhoto.fromJpeg(
      img.encodeJpg(
        img.fill(
          img.Image(width: 32, height: 32),
          color: img.ColorRgb8(100, 80, 180),
        ),
      ),
    );
    debugPrint('Profile photo: verify persistence');
    await repository.createCurrentProfile(displayName: 'Photo learner');
    expect((await repository.getCurrentProfile())!.photo, isNull);
    await repository.updateCurrentProfile(
      displayName: 'Photo learner',
      photo: photo,
    );
    expect(
      (await repository.getCurrentProfile())!.photo!.encoded,
      photo.encoded,
    );
    await repository.updateCurrentProfile(
      displayName: 'Photo learner',
      photo: secondPhoto,
    );
    expect(
      (await repository.watchCurrentProfile().first)!.photo!.encoded,
      secondPhoto.encoded,
    );
    final denied = throwsA(
      isA<FirebaseException>().having(
        (error) => error.code,
        'code',
        'permission-denied',
      ),
    );
    debugPrint('Profile photo: verify owner and size rules');
    await expectLater(
      databases.last
          .doc('users/$uid')
          .get(const GetOptions(source: Source.server)),
      denied,
    );
    await expectLater(
      databases.last.doc('users/$uid').update({'photoBase64': photo.encoded}),
      denied,
    );
    await expectLater(
      db.doc('users/$uid').update({'photoBase64': 'A' * 43696}),
      denied,
    );
    await expectLater(
      db.doc('users/$uid').update({'photoBase64': 123}),
      denied,
    );
    await repository.updateCurrentProfile(
      displayName: 'Photo learner',
      photo: null,
    );
    debugPrint('Profile photo: verify removal and legacy profile');
    expect((await repository.getCurrentProfile())!.photo, isNull);
    await db.doc('users/$uid').delete();
    await db.doc('users/$uid').set({'displayName': 'Legacy learner'});
    final legacy = await repository.getCurrentProfile();
    expect(legacy!.displayName, 'Legacy learner');
    expect(legacy.photo, isNull);
    await db.doc('users/$uid').delete();
    for (var i = 0; i < apps.length; i++) {
      await identities[i].currentUser!.delete();
      await databases[i].terminate();
      await apps[i].delete();
    }
  });
}
