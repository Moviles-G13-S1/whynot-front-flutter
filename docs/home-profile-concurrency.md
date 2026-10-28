# Home and Profile concurrency — Sprint 3

## Implementation

HomeScreen owns a HomeController for its mounted lifetime. The controller starts
the profile and wishlist subscriptions independently. Each LiveSection publishes
its own loading, data and error state; a slow or failed source cannot block the
other section. Retry replaces only the selected subscription. Existing streams
continue delivering profile and wishlist changes after their initial results.
There is no extra initial `get()` alongside the subscriptions.

ProfileScreen owns a ProfileLoadController. It starts the city catalog request
at the same time as the profile subscription. Previously the city widget was
only mounted after the profile arrived, making these operations sequential.
The profile can now render while cities are still loading. A failed city lookup
has its own retry action. Resolving the avatar URL still waits for the profile's
photo path because that is a real dependency.

LiveSection owns subscription cancellation and ignores results from superseded
loads or disposed screens. Futures cannot cancel an in-flight backend request;
canceling their stream subscription prevents a late result from updating the UI.
Home/Profile initialize their load controllers once in didChangeDependencies,
so rebuilding a screen does not restart these loads. Disposing the screen cancels
its subscriptions. Re-entering the screen creates a fresh controller.

Recommendations and nearby stores retain their independent controllers. The
backend, Firestore schema, and Cloud Functions are unchanged. This implements
asynchronous I/O concurrency on Dart's event loop, not CPU parallelism or isolates.
Home already had asynchronous widgets; its improvement here is explicit ownership,
stable subscriptions, independent retry and lifecycle management. The concrete
change from sequential to concurrent I/O is the Profile city-catalog load.

## Automated evidence

Run:

```sh
flutter test test/concurrent_screen_loads_test.dart test/concurrent_screens_widget_test.dart
```

Controlled streams and Completers demonstrate that both sources start before
either responds, results appear independently, errors remain local, retries do
not restart successful sections, reactive updates continue, subscriptions are
canceled, late completions are ignored and rebuilding does not repeat loads.
Widget tests exercise Home with delayed wishlists and Profile with a delayed,
then failing, city catalog and successful retry.

## Device demonstration still required

On an iPhone, open Home and Profile with slow connectivity and interact with
navigation while data loads. Confirm profile edits and wishlist changes still
update the UI when returning from their forms. Demonstrate a failed section and
its retry. These tests do not replace real-device connectivity validation, and
this change alone does not implement the full eventual-connectivity strategy.
