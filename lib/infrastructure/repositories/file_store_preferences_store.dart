import 'dart:convert';
import 'dart:io';

import '../../models/repositories/store_preferences_store.dart';
import '../../models/store_summary.dart';

/// Santiago Casasbuenas: Sprint 4 local storage with **files**.
///
/// Each account's Stores preferences are a small JSON document in the app's
/// documents directory: `stores_preferences/<uid>.json`. A file fits a few
/// fields that are read once per visit and written when the user changes
/// them; it needs no schema or migration, unlike the SQLite tables, and is
/// removed with the app's data.
///
/// Writes go to a temporary file that then replaces the old one, so a crash
/// mid-write never leaves half a document. A missing, corrupt or unknown file
/// reads as "no preference".
class FileStorePreferencesStore implements StorePreferencesStore {
  FileStorePreferencesStore({
    required Future<Directory> Function() directory,
    DateTime Function() now = DateTime.now,
  }) : _directory = directory,
       _now = now;

  static const folderName = 'stores_preferences';
  static const _version = 1;

  final Future<Directory> Function() _directory;
  final DateTime Function() _now;

  /// Where [userId]'s preferences live. Only `[A-Za-z0-9_-]` reach the name.
  Future<File> fileFor(String userId) async {
    final base = await _directory();
    final safe = userId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return File('${base.path}/$folderName/$safe.json');
  }

  @override
  Future<StoreSort?> readSort(String userId) async {
    try {
      final file = await fileFor(userId);
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString());
      if (json is! Map || json['userId'] != userId) return null;
      return StoreSort.fromName(json['sort']);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeSort(String userId, StoreSort sort) async {
    final file = await fileFor(userId);
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      jsonEncode({
        'version': _version,
        'userId': userId,
        'sort': sort.name,
        'updatedAt': _now().toUtc().toIso8601String(),
      }),
      flush: true,
    );
    await temporary.rename(file.path);
  }

  @override
  Future<void> clear(String userId) async {
    final file = await fileFor(userId);
    if (await file.exists()) await file.delete();
  }
}
