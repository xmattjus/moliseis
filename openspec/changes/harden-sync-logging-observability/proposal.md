# Proposal

## Why

Molise Is has typed logging, but the canonical content sync is not diagnosable as one operation. Cursor and settings errors can return without a useful log, while per-entity and repository "success" events are emitted before an ObjectBox transaction can still roll back. The resulting log history is noisy and can contradict durable state.

On the audited `main` baseline (`f674d7e4e6771d7588c0f894d6f1768b14663851`), Sentry 10.0.0-rc.2 defaults to streaming spans, but the sync and content-submission workflows use `startTransaction`, which is a no-op in that lifecycle. The sync tracing test explicitly opts into `static` and misses the production configuration. [TASK-41](https://app.notion.com/p/40d1b5e75aa781d98c64f872116da35b) records the reviewed findings and the decision to use `SentryTraceLifecycle.stream`.

## What Changes

- Emit a small, typed, local-first sync lifecycle with a distinguishable phase, bootstrap/delta mode, fetched DTO counts, elapsed time, and exactly one accurate terminal outcome. Report cursor, fetch, transaction, and sync-state persistence failures without duplicate exception capture.
- Stop publishing successful entity/repository writes before the *outer* atomic transaction commits; report durable content commit separately from successful sync-state persistence. Replace per-entity info noise with concise aggregate reporting.
- Preserve original exceptions and available stack traces at error-catching boundaries, respecting the existing `Result.error(Exception)` API. Do not rewrite the general Result or sync protocol.
- Adopt `SentryTraceLifecycle.stream` explicitly; replace the two obsolete transactions with a tiny `Result`-aware `Sentry.startSpan` adapter under `lib/utils/logging/`, preserving existing return values, exceptions, logging, and consent.
- Add deterministic automated regression coverage and narrowly scoped dependency-boundary checks. Codex must **run** the affected tests, full Flutter test suite, analysis, formatting, and strict OpenSpec validation during implementation, not merely author tests.

## Capabilities

### New Capabilities

- `application-observability`: consistent local diagnostic events, owned error reporting, SDK-version-compatible streaming traces, and supported logging integration boundaries.

### Modified Capabilities

- `canonical-content-sync`: success diagnostics must agree with the already-defined atomic content commit and durable cursor advancement, including partial success when settings persistence fails.

## Impact

Flutter app only: `lib/utils/logging/`, sync orchestration/cursor/transaction/persistence error boundaries, `BaseSyncRepository` reporting, content-submission tracing, composition, and focused tests. No changes to Supabase schema/RPC, ObjectBox model, sync scheduling, fetch pagination/overlap, user-facing UX, dependency versions, Sentry consent/replay lifecycle, or Cloudinary-specific logging. The existing unrelated OpenSpec change for imported-asset persistence is out of scope.

Planning only. This proposal does not authorize implementation, syncing canonical specs, archiving, merging, or deployment.
