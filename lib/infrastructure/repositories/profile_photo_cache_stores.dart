import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import '../../models/repositories/profile_photo_cache_store.dart';

/// iOS image cache: one manager per owner, one avatar, 30-day retention.
/// The immutable Storage path is the cache key, not an expiring download URL.
class ManagedProfilePhotoCacheStore implements ProfilePhotoCacheStore {
  final _managers = <String, CacheManager>{};

  CacheManager managerFor(String userId) => _managers.putIfAbsent(
    userId,
    () => CacheManager(
      Config(
        'whynot_avatar_${Uri.encodeComponent(userId)}',
        stalePeriod: const Duration(days: 30),
        maxNrOfCacheObjects: 1,
      ),
    ),
  );

  @override
  Future<Uint8List?> read(String userId, String path) async {
    final file = await managerFor(userId).getFileFromCache(path);
    if (file == null || !await file.file.exists()) return null;
    return file.file.readAsBytes();
  }

  @override
  Future<void> write(String userId, String path, Uint8List bytes) async {
    final manager = managerFor(userId);
    await manager.emptyCache();
    await manager.putFile(
      path,
      bytes,
      key: path,
      fileExtension: path.endsWith('.png') ? 'png' : 'jpg',
      maxAge: const Duration(days: 30),
    );
  }

  @override
  Future<void> clear(String userId) => managerFor(userId).emptyCache();
}

/// Chrome fallback: CachedNetworkImage does not persist images on web.
/// Reuses the project's SQLite/IndexedDB runtime, in a separate database.
class SqliteProfilePhotoCacheStore implements ProfilePhotoCacheStore {
  SqliteProfilePhotoCacheStore({DatabaseFactory? factory, this.databasePath})
    : _injectedFactory = factory;

  final DatabaseFactory? _injectedFactory;
  final String? databasePath;
  Future<Database>? _opening;
  late final DatabaseFactory _factory =
      _injectedFactory ?? (kIsWeb ? databaseFactoryFfiWeb : databaseFactory);

  Future<Database> _database() => _opening ??= _open();
  Future<Database> _open() async {
    final path =
        databasePath ??
        (kIsWeb
            ? 'whynot_profile_photos.db'
            : '${await _factory.getDatabasesPath()}/whynot_profile_photos.db');
    return _factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) => db.execute(
          'CREATE TABLE profile_photos ('
          'user_id TEXT PRIMARY KEY, path TEXT NOT NULL, bytes BLOB NOT NULL)',
        ),
      ),
    );
  }

  @override
  Future<Uint8List?> read(String userId, String path) async {
    final rows = await (await _database()).query(
      'profile_photos',
      where: 'user_id = ? AND path = ?',
      whereArgs: [userId, path],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Uint8List.fromList((rows.single['bytes'] as List).cast<int>());
  }

  @override
  Future<void> write(String userId, String path, Uint8List bytes) async {
    await (await _database()).insert('profile_photos', {
      'user_id': userId,
      'path': path,
      'bytes': bytes,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> clear(String userId) async {
    await (await _database()).delete(
      'profile_photos',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  Future<void> close() async {
    final opening = _opening;
    if (opening != null) await (await opening).close();
    _opening = null;
  }
}
