# Sprint 3: Profile draft files and Home Stream concurrency

## Local storage: unsaved Edit Profile drafts

Native Flutter stores the editable fields in one JSON file per Firebase UID,
under the app documents directory `profile_drafts/`. `path_provider` and
`dart:io` provide persistent app-private files, separate from the photo cache
and from all SQLite tables. No database migration or backend change is needed.

After the existing profile loads (from available cache or server), Edit Profile
restores an unsent draft and labels it **Unsaved draft restored**. The user can
review it, continue editing, save explicitly or choose **Discard draft**, which
restores the profile values loaded at entry. No edit is automatically submitted
to Firebase, including when connectivity returns.

Text edits and dropdown changes schedule serialized local writes. A completed
write displays **Draft saved on this device**; this is distinct from remote
save confirmation. The file survives a screen/store recreation. If no profile
or restored session is available, the draft is retained but does not bypass
authentication or construct a full profile on its own.

Only name, age input, gender, category ID, city ID and city display/search text
are stored, along with schema version and owner UID. Email, passwords, tokens
and photos are excluded. Intermediate/incomplete input can be restored but
must still pass existing validation before a remote save. Malformed, oversized,
unknown-version or wrong-owner data is ignored. Storage errors leave the form
usable and explain that the user should keep it open to retain edits.

Native filenames encode the UID using lowercase hex, preventing path traversal
and case-insensitive filename collisions. Writes go to a temporary file and
rename it into place; one queue orders writes/reads/deletions so an older save
cannot overtake a clear operation. Remote rejection/offline failure keeps the
draft. Acknowledged save, explicit discard, and production sign-out cleanup
clear it. Cleanup failure is handled without breaking sign-out/remote success.

Flutter Web uses a separate, account-scoped browser localStorage adapter for
review. It is not an iOS file implementation and is documented separately from
the native strategy. Both adapters use the same serialized JSON contract.

## Concurrency: Home's independent Streams

This strategy was already implemented before this change (Flutter PR #31).
`HomeController` starts profile and wishlist stream subscriptions independently.
Either can emit while the other is still waiting. Later profile/wishlist events
continue updating their own section. Failure/retry of one does not restart the
successful other source. `LiveSection` owns cancellation and guards against
disposed or superseded subscriptions.

This is asynchronous Stream concurrency on Dart's event loop, distinct from a
one-shot Future strategy. It is not an isolate or parallel CPU work. Merely
wrapping a Future in a Stream would not establish this distinction: the Home
path uses ongoing independent subscriptions with multiple emissions.

Profile also has its existing concurrent profile/city loading, which includes
a Future for the city catalog. The specific distinct Sprint 3 strategy claimed
here is Home's independent live Streams. See `home-profile-concurrency.md` for
the wider lifecycle and test contract. No duplicate controller was introduced.

## Review and verification

```powershell
flutter test test/profile_draft_test.dart test/profile_draft_screen_test.dart
flutter test test/concurrent_screen_loads_test.dart test/concurrent_screens_widget_test.dart
flutter analyze
flutter test
flutter build web
```

1. Sign in, open Profile → Edit Profile and edit the name/age without Save.
2. Wait for the local-draft confirmation, leave and reopen the form; check the
   restore notice and retained values. On web, reloading the app with the same
   session/origin exercises browser persistence; native files need an installed
   device restart for physical-device demonstration.
3. Discard the draft; check that the loaded profile values return.
4. Edit while offline. A remote-save attempt must preserve the draft and report
   the connection requirement; reconnecting must not submit it automatically.
5. Save online and wait for acknowledgement; reopening must not restore the
   former draft. Sign out and switch users; no former user's draft is displayed.

Automated tests use actual temporary native files for persistence, account
isolation and write ordering, and injected stores for the complete form flow.
Existing controlled-stream tests demonstrate concurrent subscriptions and
independent emissions. These do not claim a physical iPhone recording.
