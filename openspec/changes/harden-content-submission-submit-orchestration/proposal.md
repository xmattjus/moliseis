## Why

The original Subplan 4 implementation now captures and submits one durable immutable attempt, but adversarial review found that an independently callable clear can still rotate its session while remote work is pending and make successful finalization target a replacement session. The synchronized predecessor specs also retain stale statements about an unchanged client envelope and progress-owned cleanup that contradict the implemented `client_submission_id` seam and ViewModel-owned finalization.

## What Changes

- **BREAKING** Rename the public repository's final whole-submission operation from `upload` to `submit` and require named `clientSubmissionId`, `ContentSubmission`, and ordered uploaded-asset arguments; retain `uploadImageTask` for Cloudinary binaries.
- Replace the final public request's persistence-shaped DTO conversion with one explicit allowlisted wire mapper that includes `client_submission_id`, excludes local/database lifecycle fields, preserves the existing nested asset representation, and serializes event instants in UTC.
- Make the repository depend on `SupabaseClient`, normalize `FunctionException` into a focused public-content API exception, and accept success only when the response object contains a positive integer `submission_id`.
- Establish one immutable submission attempt from the draft, stable identity, and ordered staged assets, durably checkpoint that exact attempt before remote side effects, and keep all later remote work bound to the captured state.
- Execute every remote step from the captured attempt so edits or asset mutations during an async gap cannot change its payload, while preserving first-error short-circuiting, staged-file retry behavior, and no Cloudinary rollback.
- Preserve the existing confirmed-remote-success/local-finalization ownership and ensure retries after local clear failure never resend the remote submission or rotate the session identity more than once.
- Give each remotely active submission exclusive ownership of its captured logical session, reject external clear/discard before destructive work while that ownership exists, release ownership after an unconfirmed failure, and retain it through acknowledged-session finalization.
- Bind successful finalization to the acknowledged client identity and reuse the existing persistence-first retirement/cleanup primitive without letting finalization clear whichever session happens to be current.
- Define direct-caller mutation semantics: later same-identity draft B remains live and dirty when attempt A fails, but is intentionally retired with that logical session when A succeeds; no draft fork or staged-asset transfer is introduced.
- Add focused ViewModel, repository HTTP-contract, shared-fake, widget/routing, and Edge parser compatibility regressions. The Edge parser will only be tested to continue accepting the forward-compatible `client_submission_id`; backend persistence and idempotency remain deferred.
- Perform a repository-wide reference check for `ContentSubmissionDto` and its legacy mapper; remove them and their directly affected generated output only if this change leaves them genuinely unused, otherwise retain them without unrelated DTO refactoring.
- Reconcile the synchronized navigation-lifecycle and local-asset-staging requirements with the newer client-envelope and ViewModel-finalization behavior. These are cross-subplan specification corrections, not new backend or routing scope.

## Capabilities

### New Capabilities

- `content-submission-submit-orchestration`: Defines durable immutable-attempt preparation, ordered remote execution, the explicit public submit wire/API contract, error and acknowledgement handling, and retry-safe local finalization boundaries.

### Modified Capabilities

- `content-submission-draft-persistence`: Extends the stable logical client identity from local draft ownership into the public final-submission request while preserving its value across retryable failures and rotating it only after successful local session retirement.
- `content-submission-navigation-lifecycle`: Reconciles the Subplan 3 backend-unchanged boundary with Subplan 4's intentionally extended client request envelope while preserving unchanged production backend and Cloudinary behavior.
- `content-submission-local-asset-staging`: Reconciles the older progress-owned cleanup wording with the already-established ViewModel-owned finalization path while preserving the same persistence-first per-session staged cleanup primitive.

## Impact

- Public Dart API: `ContentSubmissionRepository` and every implementation, caller, fake, and fixture that implements or invokes its final operation.
- Data boundary: `ContentSubmissionRepositoryImpl`, dependency injection, public submission wire mapping, public API exception handling, and potentially obsolete DTO/generated mapper files.
- UI orchestration: `ContentSubmissionViewModel` checkpoint internals, submit-attempt ownership, clear arbitration, and identity-bound finalization, plus the narrow `ContentSubmissionScreen` listener migration that resets form controls after successful session-identity rotation. Existing progress presentation and routing policy remain behaviorally unchanged.
- Tests: public repository HTTP tests, ViewModel race/retry/ownership coverage, shared fake captures, mechanically affected widget/routing tests, and one `submit-content` parser compatibility case.
- Supabase: the Flutter request adds `client_submission_id`, which the current permissive parser accepts and ignores. No production Edge Function, RPC, database schema, migration, RLS, rate-limit, or idempotency implementation changes are included.
- Dependencies and packages: none.
