# Eventual connectivity: Home, Profile and Authentication — Sprint 3

## Behavior

| Flow | Offline behavior | Recovery |
| --- | --- | --- |
| Login / registration / password change | A specific connection error preserves fields in the open form. Known offline status is rechecked before rejecting a submission. Passwords are not persisted. | Explicit user retry; restoring transport never automatically submits credentials or creates an account. |
| Existing session | A restored Firebase session can open Home without a new login. | New sessions still require online authentication. Admin routes keep their authorization guards. |
| Home | Keeps previously emitted profile/wishlists after read errors. Labels cached data and pending wishlist changes. Empty offline lists are described as unavailable locally. | Live Firestore updates refresh the data. Failed reads restart after an offline-to-available transport transition. |
| Profile | Shows cached data when available, identifies pending writes and explains when there is no local profile. | Metadata-only snapshots clear indicators when Firestore reports fresh/confirmed data. Profile and city retries are independent. |
| Edit profile | Offline save/upload attempts are rejected before writing. Inputs remain in the open form. If the connection drops after submitting a Firestore update, saving stays pending until acknowledgement. City failures do not discard the profile. | Explicit retry for rejected saves; an existing submitted write waits for its own acknowledgement without duplicate submission. Success is shown only after the repository Future completes. |

## Architecture

Home groups connection and cached/pending-data status into one compact strip
at the top, matching Profile with consistent horizontal margins. Its recommendation and nearby
cards do not repeat cached-status panels. Profile uses one compact status strip.
Offline recommendation buttons retain their normal save label and stay disabled;
the centered message below explains that saving is unavailable offline.

`AppDependencies.connectivity` shares the transport signal used by smart features
with Auth/Profile and the screen load coordinators. `ConnectionRecovery` retries
failed reads on offline-to-available transitions. Transport availability permits
an attempt; it does not prove backend reachability.

`LiveSection.visibleSnapshot` retains the last emitted value through errors and
retries. This memory belongs to the screen and is disposed with it. It is not a
second cache shared between accounts.

Firestore persistence is explicitly enabled in `main.dart`. Profile/wishlist
repositories include metadata changes and expose transient `fromCache` and
`hasPendingWrites` flags; these are not stored fields or backend schema changes.
Existing Firestore subscriptions update the UI when connectivity returns.

One-shot profile/city reads have 12-second timeouts so forms can offer recovery.
Writes have no artificial timeout, because timing out would not cancel an SDK
write and could encourage duplicate submission. Mounted checks and subscription
cancellation prevent late UI updates after leaving a screen.

The profile form also avoids rebuilding on cursor-only city-selector changes,
and its dropdown can fit narrow mobile layouts.

## Scope limits

Local records must previously have been read/cached on that installation.
This does not implement offline authentication or an application outbox.
Unsubmitted auth/profile inputs survive connection changes while the screen is
open; they are not persistent drafts across termination. Submitted Firestore
updates can remain pending in the SDK. Photo uploads and auth actions are not
claimed to synchronize automatically. Other members' product-draft,
recommendation and nearby-store strategies remain separate.

## Automated validation

```sh
flutter test test/home_profile_auth_connectivity_test.dart
flutter test
flutter analyze
```

Controlled transport, streams and Futures verify offline write guards, retained
credentials/edits, no automatic replay, selective read recovery, existing-session
startup, no-cache presentation, metadata indicators and acknowledgement before
save success. These tests simulate SDK contracts and do not prove physical-device
persistence or real network recovery.

The older city test expecting no prefetch without a selected city now matches
Sprint 3 concurrent catalog loading. Signed-out Profile still starts no requests.

## Chrome and physical-device demonstration

1. Run `flutter run -d chrome`, sign in online, visit Home and Profile to populate
   the cache, and keep one browser tab open.
2. In DevTools Network, enable Offline without closing the app. Navigate between
   Home/Profile and verify available data and local/cache indicators. Restore
   the network and observe fresh metadata.
3. Attempt Login, registration or password change offline. Fields should remain
   available and a connection error should explain the need for an explicit retry.
4. Edit a profile offline and attempt saving. Reconnect and explicitly save the
   retained fields. Repeat by disconnecting after submission: verify pending
   state and confirmation after recovery, without a duplicate submission.
5. Repeat on an iPhone in airplane mode. After caching data, restart the installed
   app offline and verify restored session/cache behavior. A browser dev-server
   page is not guaranteed to bootstrap offline; loading Flutter assets is
   separate from caching Firestore data.

Real Firebase acknowledgement, persistence after restart, photo failure behavior
and airplane-mode transitions still require this device validation.
