## Why

Subplan 4 makes the client submit one durable immutable attempt with a stable `client_submission_id`, but the deployed `submit-content` boundary still discards that identity. A response lost after the database commit is therefore indistinguishable from a failed write, and retrying can create a duplicate submission, duplicate assets, and another quota charge.

## What Changes

- Make `client_submission_id` an authoritative, canonical UUID-v4-compatible idempotency key scoped to the authenticated user for the public Content Submission path.
- Persist the key on `content_submissions` while preserving nullable legacy/admin rows, and enforce uniqueness for each `(user_id, client_submission_id)` pair.
- Replace the Edge Function's independent quota, submission, and asset writes with one service-role-only `security invoker` PostgreSQL RPC that serializes quota decisions per user and commits quota, content, and assets atomically.
- Return `created` for the first committed key and `replayed` with the same positive `submission_id` for every later or concurrent replay; replays do not consume quota, insert rows/assets, or mutate the first committed payload.
- Require and validate the client identity at the Edge parser before privileged work. Keep authenticated ownership derived from the bearer token and never accept a body `user_id`.
- Preserve the existing Flutter `ContentSubmissionRepository.submit(...) -> Result<void>`, Command, Provider, ViewModel ownership/finalization, Cloudinary sequencing/reuse, progress-route, and UI contracts. Both a created acknowledgement and an idempotent replay remain ordinary positive acknowledgements to the client.
- Add database concurrency/rollback tests, Edge parser/handler/store tests, a focused Flutter acknowledgement compatibility regression, and generated Supabase type updates.

## Capabilities

### New Capabilities

- `content-submission-server-idempotency`: Authenticated per-session deduplication, atomic database submission, replay acknowledgement, and concurrency-safe quota accounting for public Content Submission.

### Modified Capabilities

- `content-submission-draft-persistence`: Promote the existing stable local identity from a tolerated request field to the backend idempotency key without changing its local lifecycle.
- `content-submission-navigation-lifecycle`: Supersede only the historical backend-unchanged compatibility wording while preserving all route, checkpoint, ownership, and finalization behavior.
- `content-submission-submit-orchestration`: Make retry after an ambiguous acknowledgement resolve through a replay of the first committed submission and replace the explicit server-idempotency deferral.

## Impact

- Supabase migration: nullable `content_submissions.client_submission_id`, user-scoped uniqueness/check constraints, and one transactional `submit_content` RPC restricted to `service_role`.
- Edge Function: `submission_validation.ts`, `index.ts`, a small submission-store boundary following the existing Edge test pattern, generated `database.types.ts`, and focused Deno tests.
- Database tests: one new local Postgres integration suite and runner covering sequential/concurrent replay, quota concurrency, rollback, ownership scope, and first-commit-wins behavior.
- Flutter production code and public domain interfaces are expected to remain unchanged; only the existing repository acknowledgement test may need a replay-envelope case.
- No new package, ObjectBox change, Cloudinary deletion/rollback, Admin workflow redesign, RLS relaxation, route/UI redesign, background job, or broad repository refactor.
