## Why

Content Submission currently exposes structured failures at its API and upload boundaries, but the progress UI treats every ordinary submission error as immediately retryable. Before the store release, the client needs one fail-closed retry semantic derived from structured failure evidence so permanent failures do not create useless retry loops and confirmed remote success can never be submitted again.

## What Changes

- Add a narrowly scoped domain-facing Content Submission failure semantic so data/infrastructure code can identify an immediate manual retry without exposing data-layer exception types to the ViewModel or UI.
- Preserve normalized `submit-content` status, code, and message while classifying the verified public taxonomy: `VALIDATION_ERROR`/400, `UNAUTHORIZED`/401, `METHOD_NOT_ALLOWED`/405, and `RATE_LIMIT_EXCEEDED`/429 are not immediately retryable; `INTERNAL_ERROR`/500 is retryable; unknown or inconsistent API outcomes fail closed. The current boundary has no 409 outcome.
- Classify only positively identifiable transient transport and upload failures as retryable; keep malformed responses, local preflight/contract failures, unknown local or infrastructure failures, and unrecognized errors non-retryable.
- Derive a ViewModel retry getter from the current submission `Command` result and the existing `submissionFinalizationPending` state rather than storing another mutable boolean.
- Keep `Riprova` wired to the existing submit Command only for retryable submission failures and finalization recovery. For a non-retryable failure, omit immediate retry and expose the existing safe return-to-form route behavior without clearing the draft, rotating its identity, or deleting staged assets.
- Preserve finalization-only retry after acknowledged remote success, the same `client_submission_id` across legitimate remote retry, server idempotency, captured-attempt ownership, staged-asset ownership, Cloudinary reuse/deduplication, current clear ownership, and all successful/running/restoration navigation behavior.
- Add focused domain/data, ViewModel, progress-widget, and routing/restoration regressions for the taxonomy, derived state, retry action visibility, safe recovery, identity preservation, and local-only finalization retry.
- Exclude automatic retries, backoff or scheduling, `Retry-After`, authentication recovery redesign, general error UX redesign, Edge Function/SQL/RPC/idempotency changes, Cloudinary architecture changes, new packages, generic `Command`/`Result` refactors, unrelated ViewModel cleanup or deduplication, visual redesign, and store-release operations.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `content-submission-submit-orchestration`: Define the structured failure-to-immediate-retry mapping, domain dependency boundary, fail-closed unknown behavior, and retry-state/finalization/identity invariants.
- `content-submission-navigation-lifecycle`: Replace blind ordinary-error retry with retry-aware progress actions while preserving Back, restoration, running, success, finalization-only, and session-recovery behavior.

## Impact

- Domain/data boundary: a small Content Submission-specific retry/failure contract and normalization in the existing final-submit and binary-upload paths; the public repository remains `Result<void>` plus `ImageUploadTask` and retains existing structured API fields.
- UI orchestration: `ContentSubmissionViewModel` gains a derived retry getter; no data-layer import, service layer, retry manager, parallel state, or state-management change is introduced.
- Progress/navigation: only ordinary failure action selection changes; layout and unrelated copy/styles remain unchanged, and the existing route continues to own safe return-to-form behavior.
- Tests: focused repository/failure classification, upload propagation, ViewModel orchestration, progress widget, route, and restoration coverage; existing Edge tests are the authoritative taxonomy baseline and production Edge/SQL code remains unchanged.
