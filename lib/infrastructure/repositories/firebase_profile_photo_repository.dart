import 'dart:math';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/profile_photo.dart';
import '../../models/repositories/profile_photo_repository.dart';

class FirebaseProfilePhotoRepository implements ProfilePhotoRepository {
  FirebaseProfilePhotoRepository({
    FirebaseStorage? storage,
    ImagePicker? picker,
  }) : _storage = storage ?? FirebaseStorage.instance,
       _picker = picker ?? ImagePicker();

  static const maxBytes = 5 * 1024 * 1024;
  final FirebaseStorage _storage;
  final ImagePicker _picker;

  @override
  // Santiago Casasbuenas: Pick and validate a compressed JPEG or PNG under 5 MB.
  Future<ProfilePhoto?> pick() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const FormatException('Choose an image smaller than 5 MB.');
    }
    final jpeg =
        bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff;
    final png =
        bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0d &&
        bytes[5] == 0x0a &&
        bytes[6] == 0x1a &&
        bytes[7] == 0x0a;
    if (!jpeg && !png) {
      throw const FormatException('Choose a JPEG or PNG image.');
    }
    return ProfilePhoto(
      bytes: bytes,
      contentType: jpeg ? 'image/jpeg' : 'image/png',
      extension: jpeg ? 'jpg' : 'png',
    );
  }

  @override
  // Santiago Casasbuenas: Store each image under its owner with a unique path.
  Future<String> upload(String userId, ProfilePhoto photo) async {
    final nonce = Random.secure().nextInt(1 << 32);
    final path =
        'profilePhotos/$userId/${DateTime.now().microsecondsSinceEpoch}-$nonce.${photo.extension}';
    await _storage
        .ref(path)
        .putData(photo.bytes, SettableMetadata(contentType: photo.contentType));
    return path;
  }

  @override
  // Santiago Casasbuenas: Read photo bytes through owner-protected Storage rules.
  Future<Uint8List?> read(String path) => _storage.ref(path).getData(maxBytes);

  @override
  // Santiago Casasbuenas: Remove a replaced or rolled-back image.
  Future<void> delete(String path) => _storage.ref(path).delete();
}
