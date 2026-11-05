# Proposal

## Why

On the audited Flutter `main` baseline `40c36e607adc34885e2df5e858178bc61bfe7660`, temporary Cloudinary upload retries emit error-level `CloudinaryRequestFailed` events even when a later attempt succeeds; deliberate cancellation can produce both a cancellation event and an error with a captured exception. A terminal HTTP exception includes the unbounded Cloudinary response body in `toString()`, which the existing `AppLogger` can forward to consent-enabled Sentry. This is a verified reporting path, not evidence of an actual production data leak.

The public `submit-content` and Admin `associateStagedAsset` boundaries independently persist associations after upload. Their existing failure logs do not offer a sufficiently clear, low-noise distinction between confirmed upload, confirmed database association, and association not confirmed. A failed client request does not establish that the server rejected or never committed the operation, nor does it prove an orphan exists. [TASK-7](https://app.notion.com/p/40d1b5e75aa78041b901c95f43dabd90) records the review and intended scope; [TASK-41](https://app.notion.com/p/40d1b5e75aa781d98c64f872116da35b) already completed the general sync/tracing infrastructure.

## What Changes

- Classify interim retry attempts as low-severity diagnostics, not terminal upload errors. Preserve one truthful terminal client outcome, clear voluntary cancellation, and distinct new-upload versus content-addressed reuse signals.
- Make the public and Admin post-upload association outcomes locally recognizable at their existing response boundaries. A valid server acknowledgement is required to claim persistence; response loss and ambiguous failures remain explicitly unconfirmed.
- Bound and sanitize diagnostics, especially Cloudinary HTTP error bodies and exception forwarding, without suppressing useful local error classifications or adding application-initiated duplicate Sentry captures.
- Reuse `Logger` / `AppLogger` / typed `LogEvent`, existing Sentry consent and streaming tracing, and the current test harness. Add deterministic regression tests covering duplicate reporting, boundary outcomes, and privacy.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `application-observability`: Add Cloudinary upload and subsequent public/Admin association diagnostic contracts that produce truthful, non-duplicative, privacy-safe signals. Narrow the earlier blanket "content-submission reporting unchanged" clause solely for these diagnostics; preserve exception-capture ownership, consent and existing submission behavior.

Existing `content-submission-submit-orchestration`, `admin-submission-save-idempotency`, and `admin-local-asset-staging` contracts remain authoritative and functionally unchanged; their upload/association distinctions are inputs to the observability requirements.

## Impact

Flutter logging events and affected Cloudinary upload, public submission, and Admin association reporting call sites, plus targeted Flutter tests. No change to Supabase functions, SQL/RPC/RLS, asset retention, Cloudinary inventory or deletion, content-addressed public IDs, retry/backoff/cancellation behavior, progress streaming, persisted receipts, UI flows, SDK lifecycle, sampling, or dependencies. The separate importer change `harden-imported-asset-persistence-and-cleanup` is not part of this work.

## Non-goals

No orphan count or automatic cleanup (tracked by [TASK-9](https://app.notion.com/p/40d1b5e75aa78096a2baf2ae2765abbd)); no cross-service atomicity; no new correlation-ID infrastructure, logging framework, tracing redesign, or generalized audit of unrelated request failures.

Planning only: this PR does not implement, deploy, sync canonical specs, archive the change, or authorize a merge.
