import '../profile_draft.dart';

abstract interface class ProfileDraftStore {
  Future<ProfileDraft?> load(String userId);
  Future<void> save(String userId, ProfileDraft draft);
  Future<void> clear(String userId);
}

/// Serializes disk mutations, so a slow older write cannot overtake clear/save.
abstract class SerializedProfileDraftStore implements ProfileDraftStore {
  Future<void> _tail = Future.value();
  Future<T> serial<T>(String userId, Future<T> Function() operation) {
    if (userId.trim().isEmpty) {
      return Future.error(ArgumentError('User ID required'));
    }
    final next = _tail.then((_) => operation());
    _tail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }
}
