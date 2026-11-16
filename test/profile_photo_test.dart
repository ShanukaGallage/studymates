import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:material_ui/material_ui.dart';
import 'package:studymates/core/models/profile_photo.dart';
import 'package:studymates/core/theme/app_theme.dart';
import 'package:studymates/core/widgets/avatar_badge.dart';
import 'package:studymates/features/profile/data/profile_photo_picker.dart';

import 'support/profile_photo_fixture.dart';

void main() {
  test('crops a photo, strips metadata and bounds persisted JPEG bytes', () {
    final source = img.Image(width: 256, height: 300, numChannels: 4);
    source.exif.imageIfd['Make'] = 'Private camera metadata';
    final random = Random(7);
    for (final pixel in source) {
      pixel.setRgba(
        random.nextInt(256),
        random.nextInt(256),
        random.nextInt(256),
        255,
      );
    }
    final photo = prepareProfilePhoto(img.encodePng(source));
    expect(photo.bytes.length, lessThanOrEqualTo(ProfilePhoto.maxBytes));
    expect(
      photo.encoded.length,
      lessThanOrEqualTo(ProfilePhoto.maxEncodedLength),
    );
    final decoded = img.decodeJpg(photo.bytes)!;
    expect(decoded.width, 256);
    expect(decoded.height, 256);
    expect(decoded.exif.imageIfd['Make'], isNull);
    expect(() => photo.bytes[0] = 0, throwsUnsupportedError);
  });

  test('rejects unreadable and oversized source files', () {
    expect(
      () => prepareProfilePhoto(Uint8List.fromList([1, 2, 3])),
      throwsA(isA<ProfilePhotoException>()),
    );
    expect(
      () => prepareProfilePhoto(
        Uint8List(GalleryProfilePhotoPicker.maxSourceBytes + 1),
      ),
      throwsA(isA<ProfilePhotoException>()),
    );
  });

  test('missing, corrupt and oversized stored photos safely use initials', () {
    for (final value in [null, 1, '', 'bad base64', 'A' * 43693]) {
      expect(ProfilePhoto.tryDecode(value), isNull);
    }
    final photo = sampleProfilePhoto();
    expect(ProfilePhoto.tryDecode(photo.encoded)!.bytes, photo.bytes);
  });

  testWidgets('avatar displays a photo and returns to initials when removed', (
    tester,
  ) async {
    Future<void> pump(ProfilePhoto? photo) => tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Center(
          child: AvatarBadge(name: 'Study Mate', photo: photo),
        ),
      ),
    );
    await pump(sampleProfilePhoto());
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('SM'), findsNothing);
    await pump(null);
    expect(find.text('SM'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });
}
