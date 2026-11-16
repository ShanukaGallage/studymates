import 'package:image/image.dart' as img;
import 'package:studymates/core/models/profile_photo.dart';

ProfilePhoto sampleProfilePhoto({int red = 120}) => ProfilePhoto.fromJpeg(
  img.encodeJpg(
    img.fill(
      img.Image(width: 16, height: 16),
      color: img.ColorRgb8(red, 100, 180),
    ),
  ),
);
