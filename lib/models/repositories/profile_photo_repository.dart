import '../profile_photo.dart';

abstract interface class ProfilePhotoRepository {
  // Santiago Casasbuenas: Select a supported local image.
  Future<ProfilePhoto?> pick();
  // Santiago Casasbuenas: Upload to a per-user path.
  Future<String> upload(String userId, ProfilePhoto photo);
  // Santiago Casasbuenas: Resolve a stored image to its Firebase download URL.
  Future<String> getDownloadUrl(String path);
  // Santiago Casasbuenas: Clean up replaced or failed uploads.
  Future<void> delete(String path);
}
