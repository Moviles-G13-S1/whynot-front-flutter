# Monthly Spending Summary and Category Spending Detail

Entry: **Purchases → Monthly Spending → a category**. The button is available
even when Purchases is empty or its product request fails. Routes are
`/monthly-spending` and `/category-spending-detail`. The category route receives
the selected month/category and shares the summary's controller and data.

## Calculation contract

- Read only the signed-in owner's existing `products` stream. No backend,
  Firestore rule, admin BQ, or remote schema change is required.
- Include current products with `purchased == true` and a finite, nonnegative
  `price`. Amounts represent recorded product prices, not verified money paid.
- Convert each amount to integer cents before adding; round at product level.
- Group by `purchasedAt` calendar month in Colombia (UTC−05:00) and category ID.
  Missing purchase dates are counted in a separate note, never guessed from
  creation time. Deleting a product removes its amount at the next sync.
- The selector includes the current and previous eleven months plus all older
  months with dated purchases. Zero-spend months remain selectable. Categories
  sort by amount descending with ID as tie-break; products by purchase time
  descending with product ID as tie-break.
- Both screens use the same currency convention as Purchases (`$`). There is
  no currency field or currency conversion in the existing product contract.

## Sprint 4 strategies

**Local storage — SQLite.** `SqliteSpendingStore` uses schema version 6 in the
existing database, adding `spending_sync` and `spending_purchases`. Existing
draft/history/store/search tables are preserved. A transaction replaces only
one user's purchases and sync time, including a confirmed empty collection.
The distinction between no snapshot and a known empty snapshot is retained.
Only server-confirmed records without pending writes replace this copy.
The production auth cleanup deletes the user's copy on sign-out. User keys
and current-session checks prevent another account from seeing these totals.

**Caching — LRU in memory.** `MonthlySpendingCache` stores up to six monthly
calculations for the screen's current account/snapshot. Access updates recency;
the least recently accessed month is evicted. Concurrent misses for one month
share a worker. A new snapshot or controller disposal invalidates entries;
workers from an earlier generation cannot repopulate them. This is independent
of SQLite persistence and differs from LFU and disk image caching.

**Concurrency — compute/isolate.** Monthly grouping, sorting and summation run
through Flutter `compute`, with debug label `monthly_spending_worker`. Only
plain purchase records cross the worker boundary. Native Android/iOS use a
background isolate; Flutter web executes this callback on the main event loop.
Database transactions stay outside the worker. Worker results are guarded
against obsolete month selections and disposal.

**Eventual connectivity.** Restore SQLite before listening to Firestore.
Show the offline notice on Purchases and both spending screens. Saved totals
and category detail remain navigable offline, including after restart with a
restored Firebase session. Without a local snapshot, show unavailable rather
than inventing zero spending. Transport availability does not prove server
reachability: cache-only/pending Firestore events do not certify totals or
overwrite the durable copy. On reconnection, retry the stream automatically;
manual Refresh/Retry is available online. Stream failures preserve the last
snapshot. Initial server waiting is bounded to twelve seconds. Storage failures
do not hide online results and are shown as an offline-copy warning.

## Validation and manual review

```powershell
flutter analyze
flutter test
flutter build web
flutter run -d chrome
```

1. Sign in and open Purchases. Tap **Monthly Spending**.
2. Select a month with purchases; verify category totals add to the headline.
3. Open a category and compare its total and products with the summary.
4. Disconnect; confirm the notice appears on both screens and navigation works.
5. Restart offline after a successful sync; confirm the stored data returns.
6. Try offline on an account/device with no snapshot; confirm no false `$0.00`.
7. Reconnect; confirm the notice clears after server confirmation. Change or
   delete a purchased product and return/refresh to verify replacement.
8. Switch accounts and confirm no previous user's spending is displayed.

Tests cover grouping/date boundaries/cents, native worker, LRU eviction and
stale workers, offline recovery, account isolation, SQLite restart/atomicity/
migration, navigation and category drill-down. The existing history migration
test now expects schema version 6. Kotlin should use this same amount/date and
deletion contract to keep the mirror apps consistent.
