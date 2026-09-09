## Context

See `proposal.md` for motivation and the two capability deltas for normative behavior. This design was audited against repository HEAD `792b095254d742093783a4d9671235b3ee3a4c94` with a clean working tree before the change was scaffolded.

The form validates fields and event time, checkpoints the draft, starts `ContentSubmissionViewModel.submit`, and then pushes the child progress route. A form-validation or first checkpoint failure therefore stays on the form and does not normally enter `submit.result`. Once the Command starts, it clears its prior result, captures unexpected thrown `Object`s as `Result.error(Exception)`, and notifies listeners at running and terminal transitions. The progress screen observes that Command plus `submissionFinalizationPending`; today every ordinary error renders `Riprova`, while finalization failure is already a distinct local-only retry state.

The failure surface that can affect this flow is:

| Source | Current concrete form | Reaches `submit.result` / progress |
| --- | --- | --- |
| Form validation or the form-owned pre-submit checkpoint | Validation remains in the form; checkpoint is `Result.error` from the draft repository | No in the production transition; the progress route is not pushed |
| Command-side preparation/eligibility | Plain `Exception` for unavailable staged state, too many assets, invalid event time, missing required fields, or competing ownership; draft checkpoint errors are propagated unchanged | Yes when the Command is invoked, including direct callers and state failures after handoff |
| Staged-asset acquisition/reconciliation before submission | Repository `Result.error`, often an infrastructure exception; picker/lost-media work uses separate Commands and best-effort recovery | Not ordinarily; unavailable staged state can later produce the preparation error above |
| Captured staged file and Cloudinary preparation/upload | `FileSystemException`, `FormatException`, `TimeoutException`, `SocketException`/other transport error, Cloudinary validation/cancellation exceptions, a preparation `FunctionException` currently reduced to a generic `Exception`, or a private direct-upload HTTP-status failure; first `Error<SubmissionAsset>` is returned unchanged | Yes; final `submit-content` is not called after the first upload error |
| `submit-content` HTTP failure | `ContentSubmissionApiException(statusCode, code, message)` for `FunctionException` | Yes |
| `submit-content` transport failure | Non-Function exception such as `http.ClientException`, currently returned unchanged | Yes |
| Malformed positive acknowledgement | `FormatException` | Yes |
| Valid remote acknowledgement followed by local retirement failure | Draft clear `Result.error` (or identity-guard `Exception`) while `submissionFinalizationPending == true`; staged cleanup remains under the existing retirement policy | Yes, with confirmed remote success recorded |
| Unexpected throw from upload/final submit/orchestration | Existing exception, or an `Exception` wrapper when the Command catches a non-Exception `Object` | Yes; pre-acknowledgement ownership is released by the existing `finally` path |

The deployed `submit-content` handler and tests expose exactly `VALIDATION_ERROR`/400, `UNAUTHORIZED`/401, `METHOD_NOT_ALLOWED`/405, `RATE_LIMIT_EXCEEDED`/429, and `INTERNAL_ERROR`/500. Created and replayed acknowledgements are successful 201/200 responses. No 409 is emitted or normalized. The current 429 response has no `Retry-After` contract.

The separate, already-existing `prepare-cloudinary-upload` boundary can also fail before a binary upload. Its current structured outcomes are `VALIDATION_ERROR`/400, `UNAUTHORIZED`/401, `METHOD_NOT_ALLOWED`/405, `REQUEST_TOO_LARGE`/413, `CLOUDINARY_CONFIGURATION_ERROR`/500, and `CLOUDINARY_PREPARATION_ERROR`/502. Only the exact preparation 502 is evidence of a temporary preparation-side failure; configuration 500 is not an immediate user-retry condition. This mini-change does not alter that Edge Function. The direct Cloudinary client already performs its own bounded internal retry for upload HTTP 5xx and streaming/body timeouts; this design only classifies the terminal error that remains after that behavior.

## Goals / Non-Goals

**Goals:**

- Derive immediate manual retry from structured failure evidence across the existing repository/upload boundaries.
- Give UI/ViewModel one domain-facing semantic without exposing `ContentSubmissionApiException` or another data type.
- Keep retry availability synchronized with the existing Command result and finalization state by construction.
- Preserve every existing identity, idempotency, staging, captured-attempt, clear, and finalization invariant.
- Make every currently relevant failure source's retry outcome explicit, including fail-closed local and unknown cases.

**Non-Goals:**

- Automatic retries, exponential backoff, retry scheduling, or `Retry-After` support.
- Authentication refresh or recovery redesign, general error UX redesign, or new user-facing error taxonomy copy.
- Edge Function, SQL, RPC, migration, RLS, server-idempotency, quota, or acknowledgement changes.
- Cloudinary architecture, upload ordering, existing internal retry, deletion/rollback, reuse/deduplication, or staged-asset ownership changes.
- New packages, a service layer, retry manager, exception hierarchy, or speculative generic failure framework.
- Global `Command` or `Result` refactoring, unrelated Content Submission ViewModel cleanup, unrelated deduplication, or Admin behavior redesign.
- Visual hierarchy, colors, typography, spacing, icons, general layout, unrelated wording, or graphical changes.
- App Store or Play Store release operations.

## Decisions

### 1. Add one Content Submission-specific domain retry semantic, not a data exception dependency

Introduce a tiny immutable domain contract, conceptually `ContentSubmissionRetrySemantic { bool get canRetry; }`, under the existing Content Submission domain surface. Structured data/infrastructure exceptions implement that contract; an unclassified exception implements nothing and is therefore non-retryable. The contract contains no HTTP, Supabase, Cloudinary, UI, scheduling, or localized-message concept.

`ContentSubmissionApiException` remains the normalized data-layer API exception and keeps its existing `statusCode`, optional `code`, and `message`. It implements the domain semantic with an exact structured mapping: only `statusCode == 500 && code == 'INTERNAL_ERROR'` returns true. The four verified permanent/immediate-ineligible pairs return false, and every missing, unknown, or mismatched pair returns false. Classification never falls back to status alone or message text, so a proxy/custom 500 without the verified code remains fail-closed.

The existing repository boundary normalizes a terminal `TimeoutException` into a small Content Submission transport failure that implements the same semantic, retains the original exception as its cause for diagnostics, and reports `canRetry == true`. The current repository does not expose a discriminator proving that a generic `http.ClientException` or `SocketException` is transient; the Cloudinary client specifically documents that its connect-phase socket error can also reflect a misconfigured URL. Those broad types and arbitrary `Exception`s therefore remain unclassified and fail closed. No hidden request retry is added.

`SupabaseCloudinaryUploadPreparationClient` currently discards `FunctionException.status` and structured details. Preserve those fields in a focused data-layer preparation exception implementing the domain semantic: only exact `CLOUDINARY_PREPARATION_ERROR`/502 is retryable; validation/authentication/method/body-size/configuration failures and missing, unknown, or mismatched outcomes are false. This is error normalization at the existing client boundary, not a new upload service or change to the preparation API.

For binary upload, keep `ImageUploadTask`, progress, and cancellation unchanged. Decorate only its terminal `Result` at the existing `ContentSubmissionRepositoryImpl.uploadImageTask` boundary: preserve already-classified failures, wrap terminal `TimeoutException`, and leave generic client/socket, validation, cancellation, format, filesystem, and unknown errors unclassified. The Cloudinary client's existing private HTTP-status error may implement the domain semantic directly so terminal 5xx is true and non-5xx is false without parsing its string; this does not change its request/retry algorithm or expose the private type. The shared repository is also used by the Admin asset editor, so the wrapper must preserve the task's progress/cancel behavior and original cause, and focused Admin smoke coverage must confirm its generic error behavior is unchanged.

Alternatives rejected:

- Importing `ContentSubmissionApiException` into the ViewModel or progress widget would invert the `domain`/`data` dependency.
- Moving HTTP status/code/message wholesale into a new domain exception would expose infrastructure details beyond what presentation needs.
- A broad application-wide retry interface would exceed this one feature's demonstrated use cases.
- Parsing `message`, `reasonPhrase`, `toString()`, or localized copy is unstable and violates the structured-taxonomy requirement.
- Treating every upload, checkpoint, or unknown error as retryable would recreate the blind retry bug under a new name.

### 2. Fail closed for every current failure without positive transient evidence

The implementation matrix is:

| Failure classification | Immediate `Riprova` |
| --- | --- |
| `VALIDATION_ERROR` / 400 | No |
| `UNAUTHORIZED` / 401 | No |
| `METHOD_NOT_ALLOWED` / 405 | No |
| `RATE_LIMIT_EXCEEDED` / 429 | No |
| `INTERNAL_ERROR` / 500 | Yes |
| Terminal `TimeoutException` positively identified by the submission/upload boundary | Yes |
| Undifferentiated `http.ClientException`, `SocketException`, or other transport/client exception | No |
| Exact `CLOUDINARY_PREPARATION_ERROR` / 502 from `prepare-cloudinary-upload` | Yes |
| Other verified preparation pairs, including `CLOUDINARY_CONFIGURATION_ERROR` / 500 | No |
| Terminal direct-Cloudinary timeout or HTTP 5xx after its existing internal handling | Yes |
| Direct Cloudinary 4xx, file/asset validation, cancellation, malformed response, filesystem, preparation-contract, or unknown failure | No |
| Command-side local eligibility/preparation or staged-state failure | No |
| Draft checkpoint/persistence failure without a structured transient semantic | No |
| Malformed positive `submit-content` acknowledgement | No |
| Missing/unknown/mismatched API code/status, hypothetical 409, arbitrary exception, or unexpected Command wrapper | No |
| Confirmed remote success plus local finalization failure | Yes, finalization-only |

The form-owned checkpoint failure remains handled on the form and is not reinterpreted as a progress retry state. A direct Command-side checkpoint error can reach `submit.result`, but the current local repositories expose no trustworthy transient taxonomy; it therefore fails closed. This is intentional and keeps the plan evidence-based rather than guessing from disk-error text.

### 3. Derive `canRetrySubmission` from Command result plus finalization ownership

Add a read-only ViewModel getter, conceptually `canRetrySubmission`, with this invariant:

1. if `submit.running`, return false;
2. if `submit.result` is not `Error<void>`, return false (covering idle and success);
3. if `submissionFinalizationPending`, return true;
4. otherwise return the error's domain retry semantic when present, and false when absent.

No field, setter, reset call, listener, or second state machine is added. `Command._execute` already clears the previous result before notifying the running transition, so a retry cannot retain stale `true`. The Command's terminal notification also rebuilds the progress UI after finalization succeeds or fails. `submissionFinalizationPending` remains the authoritative proof that remote success occurred; the local finalization exception itself is not made generically retryable.

Alternatives rejected:

- A mutable `bool canRetry` can drift when Command execution clears or replaces its result.
- Putting the getter on generic `Command` or `Result` would broaden shared infrastructure for one feature and still lack finalization context.
- Deriving from `submit.error` alone reproduces the current bug.

### 4. Make only the ordinary failure action conditional

`ContentSubmissionProgressScreen` continues listening to the existing submit Command. Preserve the current running, idle/restored, success, Back, Home, and finalization-error branches. For an ordinary error:

- when `canRetrySubmission` is true, keep the existing Home plus primary `Riprova` actions, with `Riprova` executing `submit.execute()` exactly once under the Command's existing running guard;
- when false, keep Home, replace the primary retry affordance with `Torna al modulo`, and pop only the progress child route.

The non-retryable action neither clears nor restores anything. The existing parent form and route-exit policy remain responsible for later edits, save/discard decisions, and Home navigation. AppBar/system/predictive Back stays enabled for ordinary failures and likewise pops only the progress route. No copy or layout change beyond selecting the already-established `Torna al modulo` action is required.

### 5. Retry changes no submission side-effect boundary

A retryable pre-acknowledgement error continues through the existing `_submit()` preparation path. The unchanged draft/session retains its `clientSubmissionId`; durable staged paths remain present; Cloudinary content-addressed preparation/reuse remains active; and server replay semantics deduplicate an ambiguous committed request.

When `submissionFinalizationPending` is true, `_submit()` continues to branch to `_finalizeSubmittedSession()` before attempt preparation. The design must not reorder that guard. Tests must assert that repeated failed local finalization and its later successful retry perform no checkpoint, upload, or final submit; keep the same identity until success; clear only the acknowledged matching session; and rotate exactly once after success.

## Risks / Trade-offs

- [A future server code is introduced without client mapping] → Unknown structured outcomes intentionally fail closed; adding a new retryable outcome requires an explicit taxonomy/test update.
- [HTTP status and code disagree because of a proxy or unexpected backend] → Require the verified pair for `INTERNAL_ERROR`; do not assume status-only transience.
- [429 users cannot retry immediately even after the window expires] → This action is intentionally immediate-only; delayed retry and `Retry-After` remain separate future work.
- [A real local or network transient is not recognized] → Fail closed and return to the preserved form/session; do not expand classification until the boundary exposes reliable structure.
- [Task decoration changes Admin upload error objects] → Retain the cause and task lifecycle, keep Admin generic UX unchanged, and run its focused add-asset failure tests.
- [Finalization error is accidentally treated as an ordinary remote error] → Give `submissionFinalizationPending` precedence after running/error checks and retain direct tests for zero repeated uploads/submits.
- [Previous hardening artifacts drift during this isolated change] → Limit all planning edits to this new change directory and verify the final diff contains no predecessor or main-spec modifications.

## Migration Plan

1. Add the domain retry semantic and focused semantic tests/fakes without changing UI behavior.
2. Make the existing API exception, transport normalization, and terminal upload failures publish the semantic; preserve structured fields, causes, and current request counts.
3. Add the derived ViewModel getter and orchestration invariants, including fail-closed and finalization-only cases.
4. Gate only the progress-screen ordinary failure action and add focused widget/routing/restoration coverage.
5. Run formatting, targeted analysis, focused Flutter/Admin tests, and unchanged Edge taxonomy tests; perform no database, Edge deployment, package, or store operation.

Rollback removes the progress gating, derived getter, and new semantic/normalization together. There is no persisted state, schema, wire, server, or migration compatibility step.
