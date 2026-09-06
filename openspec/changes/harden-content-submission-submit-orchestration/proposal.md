## Why

The public Content Submission command currently reads live form and asset state across multiple remote awaits, can begin remote work without proving that the exact attempted draft is durable, and sends a persistence-shaped request whose final repository operation is ambiguously named `upload`. This leaves retries and concurrent edits unable to prove which immutable draft and stable client identity were actually submitted, while malformed success envelopes and structured Edge Function failures are not checked at the client boundary.

## What Changes

- **BREAKING** Rename the public repository's final whole-submission operation from `upload` to `submit` and require named `clientSubmissionId`, `ContentSubmission`, and ordered uploaded-asset arguments; retain `uploadImageTask` for Cloudinary binaries.
- Replace the final public request's persistence-shaped DTO conversion with one explicit allowlisted wire mapper that includes `client_submission_id`, excludes local/database lifecycle fields, preserves the existing nested asset representation, and serializes event instants in UTC.
- Make the repository depend on `SupabaseClient`, normalize `FunctionException` into a focused public-content API exception, and accept success only when the response object contains a positive integer `submission_id`.
- Establish one immutable submission attempt from the draft, stable identity, and ordered staged assets, durably checkpoint that exact attempt before remote side effects, and keep all later remote work bound to the captured state.
- Execute every remote step from the captured attempt so edits or asset mutations during an async gap cannot change its payload, while preserving first-error short-circuiting, staged-file retry behavior, and no Cloudinary rollback.
- Preserve the existing confirmed-remote-success/local-finalization ownership and ensure retries after local clear failure never resend the remote submission or rotate the session identity more than once.
- Add focused ViewModel, repository HTTP-contract, shared-fake, widget/routing, and Edge parser compatibility regressions. The Edge parser will only be tested to continue accepting the forward-compatible `client_submission_id`; backend persistence and idempotency remain deferred.
- Perform a repository-wide reference check for `ContentSubmissionDto` and its legacy mapper; remove them and their directly affected generated output only if this change leaves them genuinely unused, otherwise retain them without unrelated DTO refactoring.

## Capabilities

### New Capabilities

- `content-submission-submit-orchestration`: Defines durable immutable-attempt preparation, ordered remote execution, the explicit public submit wire/API contract, error and acknowledgement handling, and retry-safe local finalization boundaries.

### Modified Capabilities

- `content-submission-draft-persistence`: Extends the stable logical client identity from local draft ownership into the public final-submission request while preserving its value across retryable failures and rotating it only after successful local session retirement.

## Impact

- Public Dart API: `ContentSubmissionRepository` and every implementation, caller, fake, and fixture that implements or invokes its final operation.
- Data boundary: `ContentSubmissionRepositoryImpl`, dependency injection, public submission wire mapping, public API exception handling, and potentially obsolete DTO/generated mapper files.
- UI orchestration: `ContentSubmissionViewModel` checkpoint internals and submit-attempt execution; existing progress/finalization presentation and routing policy remain behaviorally unchanged.
- Tests: public repository HTTP tests, ViewModel race/retry coverage, shared fake captures, mechanically affected widget/routing tests, and one `submit-content` parser compatibility case.
- Supabase: the Flutter request adds `client_submission_id`, which the current permissive parser accepts and ignores. No production Edge Function, RPC, database schema, migration, RLS, rate-limit, or idempotency implementation changes are included.
- Dependencies and packages: none.
