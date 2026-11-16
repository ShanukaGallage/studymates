import 'dart:convert';
import 'dart:typed_data';

/// A bounded JPEG avatar, kept in the owner's private Firestore profile.
/// Full-resolution photos and temporary device paths are never persisted.
class ProfilePhoto {
  ProfilePhoto._(this.bytes);

  factory ProfilePhoto.fromJpeg(Uint8List data) {
    if (data.length < 4 ||
        data.length > maxBytes ||
        data[0] != 0xff ||
        data[1] != 0xd8 ||
        data[data.length - 2] != 0xff ||
        data.last != 0xd9) {
      throw const FormatException('Invalid profile photo.');
    }
    return ProfilePhoto._(Uint8List.fromList(data).asUnmodifiableView());
  }

  static const maxBytes = 32 * 1024;
  static const maxDimension = 256;
  static const maxEncodedLength = 43692;
  final Uint8List bytes;

  String get encoded => base64Encode(bytes);

  /// A bad photo must not make an otherwise valid profile inaccessible.
  static ProfilePhoto? tryDecode(Object? value) {
    if (value is! String || value.length > maxEncodedLength) return null;
    try {
      return ProfilePhoto.fromJpeg(base64Decode(value));
    } on FormatException {
      return null;
    }
  }
}
