import 'dart:typed_data';

abstract interface class ProfilePhotoCacheStore {
  Future<Uint8List?> read(String userId, String path);
  Future<void> write(String userId, String path, Uint8List bytes);
  Future<void> clear(String userId);
}
