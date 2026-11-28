import 'dart:js_interop';
import '../../models/profile_draft.dart';
import '../../models/repositories/profile_draft_store.dart';

@JS('localStorage')
external _BrowserStorage get _storage;
extension type _BrowserStorage(JSObject _) implements JSObject {
  external String? getItem(String key);
  external void setItem(String key, String value);
  external void removeItem(String key);
}

/// Browser-review adapter; mobile uses JSON files, not browser storage.
class BrowserProfileDraftStore extends SerializedProfileDraftStore {
  String _key(String id) => 'whynot.profileDraft.v1.$id';
  @override
  Future<ProfileDraft?> load(String userId) => serial(userId, () async {
    final value = _storage.getItem(_key(userId));
    return value == null ? null : ProfileDraft.decode(value, userId);
  });
  @override
  Future<void> save(String userId, ProfileDraft draft) => serial(
    userId,
    () async => _storage.setItem(_key(userId), draft.encode(userId)),
  );
  @override
  Future<void> clear(String userId) =>
      serial(userId, () async => _storage.removeItem(_key(userId)));
}

ProfileDraftStore createProfileDraftStore() => BrowserProfileDraftStore();
