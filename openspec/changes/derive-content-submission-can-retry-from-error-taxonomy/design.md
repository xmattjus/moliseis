## Context

See `proposal.md` for motivation and the two capability deltas for normative behavior. This correction was audited at repository HEAD `3e74ce81b7ebdc2eb1b77e2321cb170b596b7315` with a clean working tree.

Repository source and production rollout state are deliberately different. The checkout contains the hardened `submit-content` implementation and idempotency migration, but the planned deployment sequence is client first:

1. release the updated Flutter client to Android and iOS;
2. let that client coexist with the currently deployed legacy `submit-content` function;
3. deploy the hardened idempotent function only after sufficient client adoption;
4. validate the complete new-client/new-server system afterward.

The legacy handler is the implementation immediately before hardening commit `fe8a7e2` (repository commit `738d01504afa5e39fbcc653a53eb92d032d883f8`). It accepts and ignores the additional `client_submission_id`, reads and updates quota separately, inserts `content_submissions` directly, then associates assets in another RPC. It neither persists the client identity nor uses it for replay. Quota can therefore be updated before submission insertion, and the content row can commit before asset association reports a failure. Its structured failures include `VALIDATION_ERROR`/400, `UNAUTHORIZED`/401, `METHOD_NOT_ALLOWED`/405, `RATE_LIMIT_EXCEEDED`/429, plus `RATE_LIMIT_READ_FAILED`, `RATE_LIMIT_UPDATE_FAILED`, `SUBMISSION_INSERT_FAILED`, `ASSET_INSERT_FAILED`, and catch-all `INTERNAL_ERROR`, all with HTTP 500 where applicable.

The current hardened handler authenticates and validates before one service-role-only `submit_content` RPC. Migration `20260908065810_harden_content_submission_server_idempotency.sql` makes quota, content, and asset persistence atomic and deduplicates `(user_id, client_submission_id)`. Its public failure taxonomy is exactly `VALIDATION_ERROR`/400, `UNAUTHORIZED`/401, `METHOD_NOT_ALLOWED`/405, `RATE_LIMIT_EXCEEDED`/429, and `INTERNAL_ERROR`/500; created and replayed acknowledgements are HTTP 201/200. It emits no 409. Crucially, `INTERNAL_ERROR`/500 exists in both generations and neither the request nor failure response provides a version/capability discriminator. A final 500 therefore does not prove which persistence contract handled the request or whether the legacy path already committed.

`pubspec.lock` pins `functions_client` 2.6.4. Its `FunctionsClient.invoke()` returns a `FunctionResponse` for 2xx, throws `FunctionException(status, details, reasonPhrase)` for non-2xx, and lets exceptions from request transmission or response consumption propagate. It has no automatic retry or commit-status signal. `ContentSubmissionRepositoryImpl` converts only `FunctionException` into `ContentSubmissionApiException(statusCode, code, message)`, returns other exceptions unchanged, rejects malformed positive acknowledgements with `FormatException`, and performs one invocation. A final timeout, `ClientException`, `SocketException`, or equivalent can occur before receipt, during processing, or after remote commit but before acknowledgement; probable transience does not make replay proven safe against the legacy server.

The form-owned validation/checkpoint normally fails before the progress route is pushed. Once the Command starts, local eligibility/checkpoint/staged-state failures, Cloudinary preparation/direct-upload errors, final-submit errors, malformed acknowledgements, finalization errors, and unexpected exceptions can reach `submit.result`. The first upload error prevents `submit-content`; final-submit failure releases attempt ownership while preserving the session; confirmed submit success sets `submissionFinalizationPending` before local retirement.

`prepare-cloudinary-upload` exposes `VALIDATION_ERROR`/400, `UNAUTHORIZED`/401, `METHOD_NOT_ALLOWED`/405, `REQUEST_TOO_LARGE`/413, `CLOUDINARY_CONFIGURATION_ERROR`/500, and `CLOUDINARY_PREPARATION_ERROR`/502. The same preparation 502 is returned for an unexpected lookup failure, a thrown field builder, and deterministic rejection of invalid or configuration-mismatched prepared fields. It is therefore an ambiguous bucket, not positive transient evidence. Its Flutter client currently reduces `FunctionException` to a generic `Exception`; since every preparation failure maps to false for this immediate action, preserving additional fields or adding a preparation wrapper would have no behavior in this release.

The shared direct Cloudinary client internally retries only direct-upload HTTP 5xx and streaming/body `TimeoutException`, up to its existing bound. Connect-phase socket/other exceptions are terminal. After internal exhaustion, the public `ImageUploadTask` exposes only `Result<SubmissionAsset>`, progress, and cancellation; the direct HTTP status exception remains private to shared infrastructure. Content-addressed public IDs and preparation reuse protect existing asset behavior, but distinguishing every terminal direct-upload cause at the Content Submission boundary would require a feature-specific task wrapper or leakage of a feature domain contract into shared Cloudinary code used by Admin.

## Goals / Non-Goals

**Goals:**

- Define `canRetry` as proven safe immediate execution of the current manual action, separately from technical transience or eventual recoverability.
- Keep the released client's immediate-retry policy safe across both legacy non-idempotent and hardened idempotent final-submit servers.
- Remove blind ordinary-error retry while preserving the current session and its safe route recovery.
- Keep finalization failure immediately retryable through the existing local-only path.
- Use the smallest implementation surface: one derived ViewModel semantic and one progress-action decision.

**Non-Goals:**

- Backend, Edge Function, SQL, RPC, migration, RLS, server-idempotency, or deployment-version-negotiation changes.
- Feature flags, response capability headers, minimum-server checks, or automatic transition of policy after deployment.
- Automatic retry, exponential backoff, scheduling, timers, cooldown UX, or `Retry-After` support.
- Authentication refresh/recovery redesign or general error UX redesign.
- Cloudinary architecture, preparation taxonomy, direct-upload retry algorithm, deletion/rollback, content addressing, reuse/deduplication, progress, or cancellation changes.
- New packages, a service layer, retry manager, domain exception hierarchy, global `Command`/`Result` refactoring, or Admin behavior changes.
- Unrelated ViewModel cleanup, deduplication, wording, visual hierarchy, colors, typography, spacing, icons, layout, or graphical changes.
- Android/iOS store publication or hardened backend deployment operations.

## Decisions

### 1. `canRetry` means safe immediate manual action, not transient cause

Use the explicit presentation name `canRetrySubmissionImmediately`. Its normative meaning is: the user may safely execute the current `Riprova` action now without violating submission identity, duplicate-commit, staging, upload, or finalization invariants. A failure can be transient yet return false when replay safety is uncertain, recovery requires delay or another action, or the observable boundary lacks enough provenance.

A structured error is immediately retryable only when the observable contract proves both that repeating the operation is appropriate and that it is safe under every server generation supported by the released client. Classification never parses `message`, `reasonPhrase`, `toString()`, raw response bodies, or localized UI text.

### 2. Fail closed for every ordinary failure in the client-first release

The normative matrix is:

| Failure at the progress flow | Immediate `Riprova` | Reason |
| --- | --- | --- |
| Confirmed remote success plus failed local finalization | Yes, finalization-only | Remote success is known and `_submit()` enters local finalization before any preparation/upload/submit work |
| `VALIDATION_ERROR` / 400 | No | Repeating the unchanged request is inappropriate |
| `UNAUTHORIZED` / 401 | No | Requires authentication recovery, not blind replay |
| `METHOD_NOT_ALLOWED` / 405 | No | Client/server contract failure |
| `RATE_LIMIT_EXCEEDED` / 429 | No | May recover later, but the current action is immediate and has no cooldown or `Retry-After` contract |
| Hardened `INTERNAL_ERROR` / 500 while legacy remains supported | No | Same observable pair can come from the legacy path; safe replay is not proven |
| Legacy `RATE_LIMIT_READ_FAILED`, `RATE_LIMIT_UPDATE_FAILED`, `SUBMISSION_INSERT_FAILED`, `ASSET_INSERT_FAILED`, or `INTERNAL_ERROR` / 500 | No | Legacy effects are separate and can be partially committed; there is no replay key |
| Final-submit timeout, `ClientException`, `SocketException`, or equivalent transport failure | No | Remote commit is ambiguous under the legacy server even when the cause may be transient |
| Missing, unknown, or mismatched final-submit status/code | No | Observable contract does not prove appropriateness and replay safety |
| Malformed positive acknowledgement | No | A successful status with an invalid envelope does not prove a safe new request |
| Any `prepare-cloudinary-upload` failure, including `CLOUDINARY_PREPARATION_ERROR` / 502 | No | Current taxonomy does not distinguish transient from deterministic preparation failure |
| Any terminal direct Cloudinary upload failure after existing internal handling | No | Public task contract lacks a simple feature-owned safe-retry discriminator; this plan avoids wrapping shared infrastructure |
| Local eligibility, staged-state, checkpoint, filesystem, format, cancellation, or unknown failure | No | No explicit safe-immediate-retry contract exists |

The absence of ordinary immediate retry is intentional. Returning to the form is safe because it performs no remote operation and preserves the current session; it is not a claim that a later user-initiated submission against the legacy server can reconstruct an ambiguous prior commit.

### 3. Derive the result without a new failure hierarchy or wrapper

Do not add the previously proposed `ContentSubmissionRetrySemantic`, final-submit timeout wrapper, Cloudinary preparation exception, `_UploadHttpException` integration, or `ImageUploadTask` decorator. Every ordinary failure is false under the current rollout/public-contract evidence, so those types would distinguish cases without changing the release behavior.

Add one read-only ViewModel getter with the following invariant:

1. if `submit.running`, return false;
2. if `submit.result` is not `Error<void>`, return false, covering idle and success;
3. return `submissionFinalizationPending`.

This derives the decision from the authoritative Command terminal state and confirmed-success ownership state. It adds no field, setter, reset, listener, or second state machine. The ViewModel and widget import no data, Supabase, HTTP, or Cloudinary exception type. The existing `ContentSubmissionApiException` remains unchanged and keeps the structured fields already required by the main specification.

### 4. Gate the current action without changing navigation ownership

`ContentSubmissionProgressScreen` reads `canRetrySubmissionImmediately`. A stopped error with true retains the existing primary `Riprova` action, which executes the existing submit Command. Under this release matrix that is exactly the finalization-pending branch. A stopped ordinary error is false: Home remains available, `Riprova` is absent, and the primary action is `Torna al modulo`, which pops only the progress child route.

The action neither clears nor restores anything. AppBar/system/predictive Back for ordinary failures continues to pop only progress. Running and finalization-pending navigation blocking, restored idle behavior, successful actions, parent form-exit policy, and route restoration remain unchanged. No layout/style change is required.

### 5. Preserve local finalization and session ownership exactly

When `submissionFinalizationPending` is true, `_submit()` already calls `_finalizeSubmittedSession()` before preparation. This ordering remains authoritative. Every finalization retry uses the acknowledged/current identity, performs no checkpoint, asset upload, or `submit-content` invocation, preserves the draft and staged assets after another local failure, and rotates `client_submission_id` only once after successful matching-session retirement.

For every ordinary failure, classification and return-to-form perform no clear, staged cleanup, identity rotation, or remote call. The existing pre-acknowledgement ownership release and later explicit edit/discard policy remain unchanged.

### 6. Future relaxation requires a separately verified serving-contract change

After the hardened idempotent `submit-content` implementation is guaranteed to serve every supported client, the project may separately re-evaluate `INTERNAL_ERROR`/500 and ambiguous final-submit timeouts/transport failures. Reusing the same `client_submission_id` may then make replay provably safe. This OpenSpec does not schedule that change and adds no flag, server capability check, version negotiation, or automatic policy transition.

## Risks / Trade-offs

- [A genuinely transient ordinary failure has no immediate retry] → Preserve the full form/session and offer safe return; prefer a conservative false negative over a possible duplicate legacy submission.
- [Users can later choose to submit again from the form] → Returning performs no remote side effect and preserves identity, but this plan does not misrepresent later legacy replay as proven deduplication.
- [The hardened server is deployed during client rollout] → Keep the same fail-closed client policy until hardened serving is guaranteed; mixed-server observability cannot support per-request relaxation.
- [Cloudinary terminal timeout may be safely repeatable] → Existing internal retries remain; terminal progress retry stays false because provenance-safe exposure would add disproportionate shared/task coupling.
- [Future taxonomy expands] → Unknown and mismatched outcomes remain fail-closed until an explicit, cross-version-safe mapping is separately specified and tested.
- [Finalization error is confused with an ordinary error] → Give finalization state precedence through the derived getter and retain zero-remote-work regression tests.
- [Previous hardening artifacts drift] → Restrict every documentation edit to this change directory and inspect the final diff for predecessor/main-spec changes.

## Migration Plan

1. Implement and verify the client-only derived getter and progress-action change without modifying data, Cloudinary, backend, or persisted contracts.
2. Release the compatible Flutter client through the separately owned Android/iOS process while the legacy function remains deployed; this release operation is not a task in this OpenSpec.
3. Allow the fail-closed client to coexist with the legacy function during adoption.
4. Deploy the already-planned hardened idempotent backend only through its separate release process after sufficient compatible-client adoption.
5. Validate the combined new-client/new-server system without automatically relaxing this client's retry policy.

Rollback of this client change restores the prior ordinary-error action selection and removes the derived getter. There is no data, schema, wire, server, or migration rollback in this mini-change.
