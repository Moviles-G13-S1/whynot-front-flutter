# Eventual connectivity: Santiago's Flutter views

## Connection signal and recovery

`ConnectivityStatus` is shared by the recommendation and nearby-store controllers in production. `ConnectivityResult.none` is a confirmed lack of a network transport. A cellular or Wi-Fi transport means only that a request can be attempted; it does **not** prove that Firebase or the backend is reachable. Backend-only failures therefore keep a Retry action and are not described as confirmed offline. When a confirmed offline state changes to an available transport, mounted views automatically request fresh data. A successful response replaces the stale display; a failure leaves the previous safe result visible with a retry affordance. There is no queued recommendation save or background data sync. The existing Home exposure telemetry writes through Firestore and may be queued by Firestore while offline.

## Smart Recommendations

The Home pick, catalog, and catalog detail use a session-only fallback. Fresh Home/catalog results keep their existing five-minute TTL; null/empty results keep their 30-second TTL. The last **nonempty** successful result may remain visible after expiration while offline or after a refresh failure, clearly marked outdated. An empty result does not become an indefinite offline substitute. Fallback never counts as a fresh cache hit. A successful empty refresh clears the former nonempty fallback. Authentication transitions, observed user switches, and successful local changes that affect recommendations clear it. Other-device changes cannot be observed immediately; stale display may reflect older eligibility until the backend responds.

Fetching a new pick/catalog and rechecking product eligibility require internet. Catalog Refresh is disabled when confirmed offline. Catalog details open from the row preview or the five-product display LRU even offline. The Save control is disabled offline. On return, the detail requests a fresh eligibility check and saveable recommendation event before enabling Save; a failed check keeps the preview and a retry control. The Home detail similarly refreshes its recommendation after an offline interval before allowing Save. No save is queued. A previous Home card that becomes visible remains a display exposure under the Home BQ rule; ordinary rebuilds do not count again.

Recommendation display fields and nearby results are held in process memory only and disappear on app termination. Images use `Image.network` with a fallback; they may fail offline and are not guaranteed after restart. This work does not add a disk image cache.

## Nearby Stores

Each attempt first obtains the **current** device location, preserving the existing permission-denied, permanently-denied, disabled-services, unavailable/timeout, settings-return, and retry behavior. The backend nearest-store lookup requires internet. A previous nonempty store can be shown after network/backend failure only for the same authenticated user and a current location fix within 100 meters of the fix used for that result. Its store and distance are marked potentially outdated. A changed user clears the previous result; a changed location or missing location fix does not reuse it. A successful backend null response clears the prior store and shows the true empty state. On connection return the view repeats both the current-location fix and backend lookup. No location or store write is queued or persisted.

## Verification still required

A signed-in physical-device airplane-mode loss/recovery demonstration remains to be performed. Verify the Home pick, catalog, catalog detail Save, nearby same-location fallback, changed-location guard, and image fallback on the device.
