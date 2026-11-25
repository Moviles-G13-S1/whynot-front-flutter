import 'dart:typed_data';

class ProfilePhoto {
  // Santiago Casasbuenas: Keep validated image bytes with their upload metadata.
  const ProfilePhoto({
    required this.bytes,
    required this.contentType,
    required this.extension,
    this.thumbnailBytes,
  });

  final Uint8List bytes;
  final String contentType;
  final String extension;
  final Uint8List? thumbnailBytes;

  Uint8List get avatarBytes => thumbnailBytes ?? bytes;
}
