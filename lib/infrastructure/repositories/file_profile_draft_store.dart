import 'dart:convert';
import 'dart:io';
import '../../models/profile_draft.dart';
import '../../models/repositories/profile_draft_store.dart';

/// Sprint 3: one small JSON file per account, independent of SQLite/cache.
class FileProfileDraftStore extends SerializedProfileDraftStore {
  FileProfileDraftStore({required this.directory});
  final Future<Directory> Function() directory;
  Future<File> _file(String userId) async {
    final root = await directory();
    // Lowercase hex also keeps distinct UIDs distinct on case-insensitive disks.
    final key = utf8
        .encode(userId)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    return File('${root.path}/profile_drafts/$key.json');
  }

  @override
  Future<ProfileDraft?> load(String userId) => serial(userId, () async {
    final file = await _file(userId);
    if (!await file.exists() || await file.length() > 16384) return null;
    return ProfileDraft.decode(await file.readAsString(), userId);
  });

  @override
  Future<void> save(String userId, ProfileDraft draft) =>
      serial(userId, () async {
        final file = await _file(userId);
        await file.parent.create(recursive: true);
        final temporary = File('${file.path}.tmp');
        await temporary.writeAsString(draft.encode(userId), flush: true);
        await temporary.rename(file.path);
      });

  @override
  Future<void> clear(String userId) => serial(userId, () async {
    final file = await _file(userId);
    if (await file.exists()) await file.delete();
    final temporary = File('${file.path}.tmp');
    if (await temporary.exists()) await temporary.delete();
  });
}
