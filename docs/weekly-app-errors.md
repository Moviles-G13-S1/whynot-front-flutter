# Sprint 3 — Weekly application errors

The app records sanitized technical errors for Jerónimo's new Type 1 BQ.
`ApplicationErrorReporter` is created in `AppDependencies.firebase()` and injected
into Auth, Home and Profile controllers. Runtime handlers are installed in
`main.dart` after Firebase initialization.

Events are first written to a bounded 500-record SQLite outbox (IndexedDB on
Chrome), then sent through an authenticated Firestore transaction. Stable IDs
make retries idempotent. Pending records survive restart and keep their original
occurrence time. Pre-login events wait for a session, and owned records are
isolated from other accounts. Delivery retries on startup, sign-in, reconnection
and subsequent captured events. Telemetry errors are swallowed without changing
the original action or reporting themselves recursively.

Normal form validation, invalid credentials and expected offline-action guards
are excluded. Instrumentation covers Auth operations, Home/Profile live reads,
profile operations and global uncaught errors after initialization. It does not
cover every handled failure elsewhere in the app. No raw messages, stack traces
or form values are uploaded. Client clock accuracy and the 500-event cap limit
the completeness of the metric.

The canonical contract, exact coverage, deployment order and demonstration steps
are in the sibling backend's `docs/weekly-app-errors.md`. The backend aggregates
Monday-to-Sunday weeks in Bogotá, and the dashboard shows the result under
**Sprint 3 / Weekly app errors**, with 4/8/12-week windows. Deploy the new rules
and shared analytics callable before expecting production results.

Validation: `flutter test` passed all 148 tests; `dart analyze lib
test/application_error_reporter_test.dart` reported no issues. The 12 new tests
cover classification, private fields, offline delivery, account isolation,
retries after lost acknowledgments, runtime handlers, stream failures, durable
SQLite reopening and queue capacity. The backend emulator suite also verifies
the database → admin metric → dashboard rendering path. On October 28, 2026,
the shared backend and event rules were deployed, and the dashboard read was
verified against production. An app-generated error delivery demonstration
and iPhone verification remain pending.
