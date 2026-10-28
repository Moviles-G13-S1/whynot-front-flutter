# Profile photo cache — implementation and Sprint 3 evidence

## Strategy and library

The avatar loads actual bytes from its cache before resolving a Firebase download
URL. `ProfilePhotoCache` coordinates owner/path validation, duplicate requests,
replacement and session cleanup. The UI renders cached bytes with Image.memory.
An immutable Storage path changes whenever a new photo is uploaded, so it also
acts as the image version and cache key.

On iOS, `ManagedProfilePhotoCacheStore` uses `flutter_cache_manager` (the image
cache used by `cached_network_image`). A native URL fallback also renders with
`CachedNetworkImage`, using the same per-owner manager and path key. This covers
the image-cache-library strategy rather than relying only on Flutter's implicit
in-memory ImageCache.

Configuration:

- One manager per owner, with an owner-specific database/cache name.
- `maxNrOfCacheObjects: 1`: this cache stores only that user's avatar.
- `stalePeriod` and putFile `maxAge`: 30 days; the immutable path determines
  replacement. A previously available image may still be shown offline.
- Maximum image size: 5 MiB, matching upload validation.
- A confirmed upload seeds the cache with its already available bytes, replacing
  the old row/file. A rejected profile-photo update does not replace the cache.
- Sign-out/account switching clears that owner's managed files and in-memory
  bytes. Cleanup is best effort if local storage fails; it must not prevent
  Firebase sign-out. Session versions block late downloads from repopulating it.

The library may evict native cache files, and the operating system may reclaim
temporary cache storage. Offline display is guaranteed only while a valid copy
is still available; this is a cache, not a permanent photo backup.

## Chrome

The CachedNetworkImage documentation states that its web support does not
include caching. Chrome therefore uses a separate SQLite/IndexedDB photo store
through the existing sqflite web runtime. Each owner has at most one BLOB row;
lookups require both owner ID and exact Storage path. This is an adapter for
testing the offline behavior on web, not an additional analytics database.

For existing remote photos, Firebase Storage downloads the bytes with a 12-second
timeout. Browser CORS/storage restrictions can prevent a first-time download or
IndexedDB write. The existing CORS-safe HTML image remains an online fallback;
displaying that fallback alone is not proof of persistent caching. Uploading a
new photo successfully also seeds the local bytes directly, without a second
download. Local cache failure never changes a successful server upload to failure.

The avatar retries loading after an offline-to-online transition. If there is no
local image and no connection, it shows the original default avatar. Credentials
and Firebase download tokens are not persisted in the custom SQLite photo table.

## Relevant files

- `lib/controllers/profile_photo_cache.dart`: cache-first loading, coalescing,
  owner validation, session/path versions and serialized disk operations.
- `lib/infrastructure/repositories/profile_photo_cache_stores.dart`: library
  cache for iOS and SQLite adapter for Chrome.
- `lib/controllers/profile_controller.dart`: owner-checked loading and confirmed
  photo replacement.
- `lib/controllers/auth_controller.dart`: session cleanup hook.
- `lib/views/widgets/profile_controls.dart`: memory image, native library and
  web HTML fallbacks, plus reconnection listener.
- `lib/app/app_dependencies.dart`: production dependency injection.

## Validation

```sh
flutter test test/profile_photo_cache_test.dart test/profile_photo_test.dart
flutter test
flutter analyze
flutter build web
```

Tests cover one download for concurrent avatars, offline hits and misses, reload
from persistent storage, exact owner/path matching, newer uploads superseding old
downloads, logout during a download, auth cleanup, confirmed versus rejected
upload replacement and rendering cached bytes without resolving a network URL.
SQLite close/reopen tests use a real temporary database; transport/Storage tests
use controlled substitutes. They do not demonstrate real iPhone cache behavior.

Manual evidence still required:

1. Load or upload a photo online, visit Profile and Edit Profile, then disconnect.
   Navigate away/back and verify the same photo with no new image download.
2. Restart the app without signing out; verify cached bytes can be loaded offline.
3. Replace the photo online; verify the new photo is used offline afterward.
4. Sign out and sign in with another account; verify no previous avatar appears.
5. On Chrome, check Network requests and IndexedDB; on iPhone use airplane mode.

## Rubric interpretation

The rubric allocates 5 points to image-cache libraries and separately 10 to a
structure such as LRU with justified parameters. This image cache supplies
library/configuration evidence; it does not establish the entire 20-point
caching category or claim a new multi-entry LRU implementation. The existing
recommendation LRU remains separate work that must also be explained.

Sources: user-supplied `Rubrica Sprint 3.pdf`, caching column;
https://pub.dev/packages/cached_network_image and
https://pub.dev/packages/flutter_cache_manager .
