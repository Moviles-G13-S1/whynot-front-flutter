import 'dart:typed_data';

import '../models/repositories/profile_photo_cache_store.dart';

/// Cache-first image bytes, keyed by owner and immutable Storage path.
/// Serial disk operations and session versions prevent late downloads from
/// restoring a photo after sign-out or replacing a newer upload.
class ProfilePhotoCache {
  ProfilePhotoCache({
    required this.store,
    required this.download,
    required this.currentUserId,
  });

  static const maxBytes = 5 * 1024 * 1024;
  final ProfilePhotoCacheStore store;
  final Future<Uint8List?> Function(String path) download;
  final String? Function() currentUserId;
  final _versions = <String, int>{};
  final _paths = <String, String>{};
  final _memory = <String, Uint8List>{};
  final _inFlight = <String, ({int version, Future<Uint8List?> result})>{};
  Future<void> _disk = Future.value();

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _disk.then((_) => action());
    _disk = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  bool _valid(String userId, String path, int version) =>
      currentUserId() == userId &&
      _paths[userId] == path &&
      _versions[userId] == version;

  void _select(String userId, String path) {
    if (userId.isEmpty || !path.startsWith('profilePhotos/$userId/')) {
      throw StateError('Photo does not belong to the current user.');
    }
    if (_paths[userId] != path) {
      _versions[userId] = (_versions[userId] ?? 0) + 1;
      _paths[userId] = path;
      _memory.remove(userId);
    }
  }

  Future<Uint8List?> load(
    String userId,
    String path, {
    required bool allowNetwork,
  }) {
    if (currentUserId() != userId) return Future.value(null);
    _select(userId, path);
    final version = _versions[userId]!;
    final memory = _memory[userId];
    if (memory != null) return Future.value(memory);
    final pending = _inFlight[userId];
    if (pending?.version == version) return pending!.result;
    final result = _load(userId, path, version, allowNetwork);
    _inFlight[userId] = (version: version, result: result);
    return result;
  }

  Future<Uint8List?> _load(
    String userId,
    String path,
    int version,
    bool online,
  ) async {
    try {
      Uint8List? bytes;
      try {
        bytes = await _serial(() => store.read(userId, path));
      } catch (_) {
        /* Cache errors must not prevent an online photo load. */
      }
      if (!_valid(userId, path, version)) return null;
      if (bytes == null && online) {
        bytes = await download(path);
        if (!_valid(userId, path, version)) return null;
        if (bytes != null && bytes.isNotEmpty && bytes.length <= maxBytes) {
          final downloaded = bytes;
          try {
            await _serial(() async {
              if (_valid(userId, path, version)) {
                await store.write(userId, path, downloaded);
              }
            });
          } catch (_) {
            /* An unavailable disk cache does not hide the image. */
          }
        }
      }
      if (!_valid(userId, path, version) ||
          bytes == null ||
          bytes.isEmpty ||
          bytes.length > maxBytes) {
        return null;
      }
      _memory[userId] = bytes;
      return bytes;
    } catch (_) {
      return null; // The avatar may still use its existing URL fallback online.
    } finally {
      if (_inFlight[userId]?.version == version) _inFlight.remove(userId);
    }
  }

  Future<void> remember(String userId, String path, Uint8List bytes) async {
    if (currentUserId() != userId || bytes.isEmpty || bytes.length > maxBytes) {
      return;
    }
    _select(userId, path);
    final version = _versions[userId]!;
    _memory[userId] = bytes;
    try {
      await _serial(() async {
        if (_valid(userId, path, version)) {
          await store.write(userId, path, bytes);
        }
      });
    } catch (_) {
      /* The confirmed upload remains successful without disk space. */
    }
  }

  Future<void> clear(String userId) async {
    _versions[userId] = (_versions[userId] ?? 0) + 1;
    _paths.remove(userId);
    _memory.remove(userId);
    _inFlight.remove(userId);
    try {
      await _serial(() => store.clear(userId));
    } catch (_) {
      /* Local cleanup must not turn a successful sign-out into failure. */
    }
  }
}
