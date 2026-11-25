# Sprint 3 Flutter isolate — profile avatar processing

Santiago Casasbuenas implemented this strategy in **Profile → Edit Profile →
Change photo**.

## Execution flow

1. The main isolate awaits the gallery picker with the existing 1024 × 1024
   bounds and quality 80 request. The repository checks the selected bytes
   against the 5 MiB limit and JPEG/PNG signatures.
2. On iOS and other native Flutter targets, the repository calls `compute()`
   with the top-level `createProfilePhotoThumbnail` function, a `Uint8List`, and
   a JPEG/PNG flag. The pure Dart worker decodes the first frame within a
   4,194,304-pixel budget. For a source with a side over 384 pixels, it
   center-crops and resizes a square that matches the circular avatar's framing
   without upscaling. It returns encoded JPEG (quality 85) or PNG (alpha
   retained). A valid image with both sides at most 384 pixels can be displayed
   directly from the picker bytes.
3. The main isolate resumes with the display bytes for the edit preview. Firebase
   Storage receives the original picker bytes and MIME type under the existing
   owner-specific path. Once the profile update succeeds, the cache stores the
   display bytes under that path. An older cached entry or a later download from
   Firebase can still contain the full image.

The picker continues to prepare the upload at its existing resolution and
quality. The worker produces a separate rendition for the 72- and 100-logical-pixel
avatars. A 1024 × 768 image becomes a 384 × 384 avatar with 81% fewer pixels to
decode on subsequent displays. Codec work traverses and allocates pixel
buffers, which can compete with gesture handling and frame building if performed
synchronously on the UI isolate.

Each Dart isolate has its own event loop and isolated state. Native `compute()`
can schedule the worker concurrently with the UI isolate. It does not require an
application-managed OS thread. The input buffer can be copied at the isolate
boundary, and the short-lived worker returns the encoded bytes when it exits.
The main isolate keeps the original bytes available for upload. Picker, Firebase,
cache-manager and SQLite operations stay with their existing main-isolate
callers. Those operations await plugin or network I/O, and widgets and navigation
belong to the UI isolate. [Flutter isolates guide](https://docs.flutter.dev/perf/isolates)

On Flutter Web, `compute()` runs on the current event loop. The repository skips
thumbnail processing there and uses the picker bytes for both display and upload.
Cancellation leaves the saved photo as it was. A failed native decode returns a
format error before upload and allows another selection. A failed save clears the
temporary preview and keeps the previous cached photo.
[Flutter `compute()` API](https://api.flutter.dev/flutter/foundation/compute.html)

## Viva evidence

The Sprint 3 Flutter concurrency column lists **isolates (10 points)**. Follow
`FirebaseProfilePhotoRepository.pick` → `compute` →
`createProfilePhotoThumbnail` → `ProfilePhoto.avatarBytes`, then show
`ProfileController.savePhoto` persisting the display bytes after confirmation
and `FirebaseProfilePhotoRepository.upload` sending the original bytes.

```sh
flutter test test/profile_photo_thumbnail_test.dart test/profile_photo_test.dart test/profile_photo_cache_test.dart
flutter test --platform chrome test/profile_photo_thumbnail_test.dart
```

The native test runs the real codec callback through `compute()` and checks that
the worker's Dart isolate control port differs from the caller's. Repository
tests exercise the regular pick and upload calls with fake platform services.
They check format, size, centering, PNG transparency, invalid and oversized
inputs, retry, and the uploaded bytes and path. Cache tests verify a successful
save uses the thumbnail and a rejected profile update keeps the old entry.

On the iPhone 17 Pro simulator (iOS 26.5), a debug harness with a stub gallery
picker passed a 1024 × 768 JPEG through the repository. The fixture was 79,773
bytes and its 384 × 384 avatar was 27,569 bytes. The VM timeline showed the
codec event on a separate thread and five UI frame starts while it ran. This
run exercised the native repository and preview with local bytes.

For a repeatable device check, run `flutter run --profile -d <iphone-id>` with a
test account and a JPEG or PNG whose dimensions exceed 384 pixels. Start a
recording in DevTools **Performance**, choose that image from **Change photo**,
and scroll the form after the picker closes. Repeat with the same image and
export the trace. Look for the **Prepare profile avatar** event associated with
the `profile-photo-thumbnail` isolate and inspect nearby UI frame work. Verify
that the preview and saved avatar appear. The gallery picker and Firebase upload
also affect elapsed time, so use the worker event to identify codec work.
[Flutter DevTools Performance view](https://docs.flutter.dev/tools/devtools/performance)
