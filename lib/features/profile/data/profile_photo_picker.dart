import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../../../core/models/profile_photo.dart';

final profilePhotoPickerProvider = Provider<ProfilePhotoPicker>(
  (ref) => GalleryProfilePhotoPicker(),
);

abstract interface class ProfilePhotoPicker {
  /// Cancellation returns null and leaves the current photo untouched.
  Future<ProfilePhoto?> pickPhoto();
}

class GalleryProfilePhotoPicker implements ProfilePhotoPicker {
  GalleryProfilePhotoPicker({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;
  static const maxSourceBytes = 5 * 1024 * 1024;

  @override
  Future<ProfilePhoto?> pickPhoto() async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        // Consume interrupted selections without attaching another account's
        // old draft. A new explicit selection always belongs to this form.
        await _picker.retrieveLostData();
      }
      final selected = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
        requestFullMetadata: false,
      );
      if (selected == null) return null;
      if (await selected.length() > maxSourceBytes) {
        throw const ProfilePhotoException(
          'Choose a smaller photo (under 5 MB).',
        );
      }
      final bytes = await selected.readAsBytes();
      return await compute(prepareProfilePhoto, bytes);
    } on PlatformException {
      throw const ProfilePhotoException(
        'Could not open your photos. Please try again.',
      );
    }
  }
}

class ProfilePhotoException implements Exception {
  const ProfilePhotoException(this.message);
  final String message;
}

/// Runs off the UI isolate. Resize/crop to a small square, flatten transparency
/// and copy pixels into a fresh image to remove EXIF/GPS and other metadata.
ProfilePhoto prepareProfilePhoto(Uint8List bytes) {
  if (bytes.length > GalleryProfilePhotoPicker.maxSourceBytes) {
    throw const ProfilePhotoException('Choose a smaller photo (under 5 MB).');
  }
  final decoded = _decodeSource(bytes);
  if (decoded == null) {
    throw const ProfilePhotoException(
      'This photo could not be read. Try a JPG or PNG image.',
    );
  }
  final square = img.copyResizeCropSquare(
    img.bakeOrientation(decoded),
    size: ProfilePhoto.maxDimension,
    interpolation: img.Interpolation.average,
  );
  final clean = img.Image(
    width: ProfilePhoto.maxDimension,
    height: ProfilePhoto.maxDimension,
    numChannels: 3,
  );
  img.fill(clean, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(clean, square);
  for (final quality in [80, 65, 50, 35, 25]) {
    final jpeg = img.encodeJpg(
      clean,
      quality: quality,
      chroma: img.JpegChroma.yuv420,
    );
    if (jpeg.length <= ProfilePhoto.maxBytes) {
      return ProfilePhoto.fromJpeg(jpeg);
    }
  }
  throw const ProfilePhotoException('Choose a simpler or smaller photo.');
}

img.Image? _decodeSource(Uint8List bytes) {
  // The picker already requests 512px. Bound decoding even for hostile headers.
  final previousLimit = img.Decoder.defaultMaxPixels;
  try {
    img.Decoder.defaultMaxPixels = 4 * 1024 * 1024;
    return img.decodeImage(bytes, frame: 0);
  } finally {
    img.Decoder.defaultMaxPixels = previousLimit;
  }
}
