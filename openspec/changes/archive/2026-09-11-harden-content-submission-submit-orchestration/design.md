## Context

See `proposal.md` for motivation and the four delta specs for required behavior. The focused remediation baseline is implementation commit `d61dadd2091c6924587dbc8d9d0dd64a91dd6fc5`; its parent `9165a8a47fd08d4c87a33fa08b8d8b3d4cc473fc` contains the completed Subplan 3 implementation and synchronizes all three completed predecessor capabilities into `openspec/specs/`. The main draft-persistence, local-asset-staging, and navigation-lifecycle specs therefore provide the exact requirements modified by this change. Remediation may proceed only from a HEAD containing `d61dadd` as an ancestor, or from an explicitly reviewed equivalent that preserves its complete immutable-attempt implementation and synchronized predecessor specs. No historical test count is treated as the remediation baseline; the executor must rerun focused pre-change checks on the actual checkout.

At parent baseline `9165a8a`, the public domain contract used ambiguous final operation `upload`, a persistence-shaped DTO, the complete `Supabase` wrapper, and unchecked acknowledgement handling. Commit `d61dadd` implemented Decisions 1–4 and the immutable capture/checkpoint/remote-execution core of Decisions 5–6 below: the public contract is now `submit`, binary upload remains `uploadImageTask`, the request uses an allowlisted wire map containing `client_submission_id`, the repository uses `SupabaseClient`, acknowledgement and Function errors are validated, and the obsolete DTO path was removed after its consumer search proved it dead. The focused ownership and finalization remediation in Decisions 5–7 is now implemented by the current checkout and covered by the completed Tasks 11–14.

The current `submit-content` parser requires the existing content and asset fields but ignores unknown top-level fields. It therefore accepts and discards `client_submission_id`; the production handler still returns `201 {"submission_id": <integer>}` after its existing rate-limit and database work. This permissive acceptance is the compatibility seam for the client rollout. Production Edge code, validated types, RPCs, tables, RLS, and rate-limit state remain untouched.

At `d61dadd`, `ContentSubmissionViewModel` captures immutable draft A and ordered staged membership inside the existing FIFO `_serialize` boundary, checkpoints exactly A, releases the boundary, and executes sequential remote work only from that attempt. The form's separate Subplan 3 transition checkpoint remains intact. This architecture and its A→B payload-fidelity behavior are correct and remain unchanged by remediation.

The remediated implementation closes the ownership gap between local preparation and finalization. `submit` and `clear` remain independent Commands, so a private active client identity is claimed before preparation releases `_serialize`; external clear rejects while that owner exists; structured cleanup releases it after every unconfirmed remote outcome; and acknowledged finalization uses a private identity-bound retirement path rather than `clear.execute()`. Staged cleanup remains the predecessor's best-effort policy: retirement awaits but does not propagate `clearSession`/orphan-reconciliation `Result` values after draft clear succeeds. Strengthening that separate cleanup contract is not part of this change.

## Goals / Non-Goals

**Goals:**

- Give final whole-submission a precise domain and wire contract without changing binary upload semantics.
- Make one exact draft/client-identity/asset snapshot both durable and authoritative for each remote attempt.
- Make that attempt the exclusive owner of its logical session from successful preparation through unconfirmed failure or acknowledged local retirement.
- Keep local lifecycle work serialized while avoiding a lock across Cloudinary or Edge network awaits.
- Fail closed on malformed successful acknowledgement, preserve structured public API failures, and never add hidden retries.
- Preserve predecessor invariants for staged-source retry, asset order, progress routing, and finalization-only recovery.
- Keep implementation local to the existing domain repository, data mapper/repository, composition root, ViewModel, and established test support.

**Non-Goals:**

- Do not implement server-side idempotency, persist `client_submission_id`, add an acknowledgement marker, or resolve process death after backend commit but before client observation.
- Do not change production Edge Function parsing/handler code, database types, migrations, RPCs, RLS, rate limiting, or direct-table access policy.
- Do not add latitude, longitude, or address to `ContentSubmissionDraft`; the public form does not own those fields, though the wire mapper remains complete for nullable `ContentSubmission` values.
- Do not add accepted-terms, form-validator, category, geolocation, description-length, or new email validation to the ViewModel.
- Do not add Cloudinary rollback/deletion, parallel uploads, cancellation coordination, repository retries, a public submission-attempt model, a use case, a scheduler, another queue, a state machine, or a new package.
- Do not refactor Admin error handling or extract a shared Function exception normalizer for only two consumers.
- Do not redesign the progress route, form transition checkpoint, ordinary explicit-discard semantics when no submission owner exists, or staged-cleanup failure semantics.

## Decisions

### 1. Rename only the final domain operation and make its inputs explicit

Change the interface to:

```dart
Future<Result<void>> submit({
  required String clientSubmissionId,
  required ContentSubmission contentSubmission,
  required List<SubmissionAsset> submissionAssets,
});
```

Retain `uploadImageTask(File)` and `dispose()` unchanged. Named arguments prevent identity/content/asset ordering mistakes at the only final caller and make the distinction from Cloudinary explicit. Keep `Result<void>` because no current domain caller consumes the backend row ID; parsing the ID is an acknowledgement check, not a reason to widen the domain. Repository-wide search at the planning baseline found no external production implementation or caller requiring an `upload` alias, so remove the old method rather than carrying ambiguity forward. Revalidate that search immediately before editing because this is a source-breaking interface change.

Update `FakeContentSubmissionRepository` and `ControllableSubmissionRepository` to capture the exact named arguments, copy submitted lists into non-growable/unmodifiable historical evidence, and use submission-oriented result/counter/completion names. Keep image-upload names for actual `ImageUploadTask` behavior. Mechanically update widget/routing tests that only compile against those fakes without changing their navigation assertions.

Alternative considered: retain `upload` as a forwarding alias. Rejected because all known implementations and callers are repository-internal and the alias would preserve the ambiguity this change removes.

Alternative considered: return `Result<int>` or a new submission result. Rejected because the row ID is not currently used and would introduce cross-layer API and UI work unrelated to acknowledgement validation.

### 2. Replace the persistence DTO with one allowlisted top-level wire mapper

Add `lib/data/mappers/content_submission_wire_mapper.dart` with one top-level function following `adminSubmissionInputToWireMap`, rather than a new mapper class. It accepts the client identity, `ContentSubmission`, and uploaded assets and returns a literal `Map<String, dynamic>` containing all and only the fourteen specified top-level keys. Map category to its existing wire name (or null), serialize non-null dates with `toUtc().toIso8601String()`, pass the already-frozen `descriptionDelta` structure through unchanged, and map nested assets through the existing `SubmissionAssetMapper`/DTO because its five fields exactly match the current Edge contract.

The mapper is an allowlist: do not spread a domain/DTO map and remove fields afterward. In particular, do not serialize `userId`, timestamps, accepted terms, ObjectBox IDs, or lifecycle metadata. This makes the public request contract obvious and prevents persistence-model growth from leaking into the API later.

At the authoritative baseline, `ContentSubmissionDto`, `content_submission_mapper.dart`, their generated mapper, and `content_submission_mapper_test.dart` have no consumer beyond the final repository path being replaced. Repeat that reference search on the implementation checkout. If no verified production consumer remains, remove those change-caused dead files, replace the barrel export with the wire mapper export, and move relevant Delta/date/key assertions into the new wire/repository coverage. If any verified production consumer remains, keep the DTO and mapper and leave their unrelated architecture unchanged. For removal, use the installed `dart_mappable`/build-runner workflow to remove stale generated output; prefer a verified filter scoped to `lib/data/dtos/generated/content_submission_dto.mapper.dart`, and fall back to the normal `dart run build_runner build --delete-conflicting-outputs` only if the installed builder cannot process the deletion narrowly. Inspect the complete generated diff and retain no Envied, ObjectBox, unrelated DTO, dependency, or lockfile drift. Never hand-edit generated Dart.

Alternative considered: add `clientSubmissionId` to `ContentSubmissionDto`. Rejected because that DTO also contains persistence-shaped `userId`, `createdAt`, and `modifiedAt`; continuing to reuse it would keep the API allowlist implicit and fragile.

Alternative considered: duplicate a public-only nested asset DTO. Rejected because the existing nested mapper already exactly emits `url`, dimensions, nullable MIME type, and nullable duration.

### 3. Make the public repository a narrow SupabaseClient boundary

Change `ContentSubmissionRepositoryImpl` to receive `SupabaseClient`, and inject `supabase.client` in `lib/config/dependencies.dart`, matching `AdminContentSubmissionRepositoryImpl`. Remove the authenticated-user lookup and `UserIdFetchFailed` preflight branch because the Edge Function authenticates the bearer token and the request no longer carries a client-supplied database user ID. Keep exactly one `functions.invoke('submit-content', body: contentSubmissionToWireMap(...))` call.

On a non-throwing response, parse `response.data` as an object and accept any additional keys, but require `submission_id is int && submission_id > 0`. Return `Result.error(FormatException(...))` for every other shape; do not accept doubles or numeric strings. After a valid envelope, continue to return `Result.success(null)`.

Add `lib/data/repositories/content_submission_api_exception.dart` as a focused exception with `statusCode`, optional trimmed backend `code`, and normalized `message`. Catch `FunctionException` before generic `Exception`. If `details` is a map, independently extract a non-empty `code` and use a non-empty `message`; do not reinterpret that map as string details. Otherwise, if `details` is a non-empty string, use that string as the message. If neither branch provides a message, use a non-empty `reasonPhrase`, then the stable `Content Submission request failed.` fallback. Always preserve `FunctionException.status`, log once with the existing `ContentSubmissionUploadFailed` event, and return the normalized exception. Keep generic exception catch/log/result behavior and Sentry transaction finalization. Renaming transaction operation/log event types is optional only if it is a direct localized consistency edit; do not refactor telemetry or change reporting ownership.

Do not share the admin normalizer. The public and admin exceptions have different names/fallbacks and this is only the second concrete implementation; local duplication remains simpler under the Rule of Three.

Alternative considered: pass the complete `Supabase` wrapper and keep reading auth state. Rejected because final serialization needs no local user ID and the repository can depend on the narrower client it actually invokes.

Alternative considered: trust all successful HTTP responses as before. Rejected because local finalization is destructive and must begin only after the existing positive backend acknowledgement contract has been validated.

### 4. Let checkpointing persist a supplied immutable draft

Refactor the existing private checkpoint primitive into a supplied-snapshot form, for example `_checkpointDraftSnapshotInsideBoundary(ContentSubmissionDraft snapshot)`. It preserves all current ownership and result behavior:

1. `unknown` persisted state returns the retained load error and never saves.
2. A `restored` snapshot structurally equal to `_checkpointedDraft` returns success without a write.
3. Otherwise save exactly the supplied `snapshot`.
4. Only successful persistence advances `_checkpointedDraft` and durable-state knowledge to that same snapshot.
5. Failure leaves the prior baseline and identity unchanged.

Keep `_checkpointDraftInsideBoundary()` as the ordinary-current-state wrapper: it captures current `_state` and delegates to the supplied-snapshot primitive. Public `checkpointDraft()` and every existing caller therefore retain their contract. If state changes A → B while save(A) is pending, successful A persistence establishes baseline A; it must not reread B when choosing the baseline. Do not add another repository method or persistence path.

Alternative considered: temporarily replace live state with the attempt draft before invoking the existing primitive. Rejected because it would mutate presentation state and manufacture race behavior instead of expressing the actual persistence input.

### 5. Prepare one attempt under local arbitration, then release it

Keep the private ViewModel-only record alias containing `ContentSubmissionDraft draft` and an unmodifiable ordered `List<Asset> assets`. Do not place it in `domain`; it is orchestration state, not a reusable business model. Add only one nullable private ownership field, preferably `String? _activeSubmissionClientSubmissionId`. This field identifies the logical session exclusively owned by an attempt whose local preparation succeeded; it is not a generalized lifecycle state machine and is not persisted.

Retain the early `_submissionFinalizationPending` branch after initialization and before any preparation. Otherwise invoke the existing private `_prepareSubmissionAttempt()` through `_serialize`. Inside that one local critical section:

1. Reject unavailable/quarantined staged state and an asset count above `maximumAssetCount` using existing errors.
2. Capture `final draft = _state` before any checkpoint await.
3. Evaluate the existing event-time persistence policy against `draft.eventDates`, updating `_eventTimeIssue` with the same observable semantics as current submit validation; add no rule.
4. Validate only current submit-owned required fields (`city`, `name`, `userEmail`, `userName`) from `draft`.
5. Capture `List<Asset>.unmodifiable(_assets)` while staged membership is serialized.
6. Checkpoint exactly `draft` through the supplied-snapshot primitive.
7. After checkpoint success, reject an unexpected pre-existing submission owner rather than overwriting it.
8. Construct the successful immutable-attempt result before claiming ownership.
9. Claim ownership by assigning `draft.clientSubmissionId` to `_activeSubmissionClientSubmissionId` as the final mutation in the serialized turn, then immediately return the already-constructed attempt without another await or fallible operation.

The checkpoint and ownership claim occur in one uninterrupted local arbitration turn, so there is no state in which remote work is authorized but a queued clear can retire A before ownership exists. The queue is then released before creating `ImageUploadTask`s or awaiting any network result. Ordinary setters remain unserialized, so draft B may become live while A is saving; because A was captured before the await and the checkpoint primitive advances only to A, the intended A-baseline/B-dirty invariant remains true. Asset add/remove operations may still queue behind preparation and remote work still uses its immutable membership copy. The existing Subplan 3 UI pre-submit checkpoint remains unchanged as the navigation transition boundary; this ViewModel-side checkpoint and ownership claim are separate defensive attempt invariants and do not replace or relocate the UI checkpoint.

If a captured staged source is independently deleted after the queue is released, the existing upload task fails normally and the attempt short-circuits. This design does not promise filesystem pinning across remote work or hold the lifecycle queue for network duration; normal UI submission already transitions to progress and blocks editing, while direct/adversarial callers receive deterministic captured membership and existing retryable error behavior.

Alternative considered: hold `_serialize` for the entire submit. Rejected because slow Cloudinary/Edge awaits would block every durable local operation and turn a local commit queue into a network lock. The narrow ownership field rejects destructive clear without holding the queue across remote work.

Alternative considered: rely on `submit.running`. Rejected because `submit` and `clear` are independent Commands, their running guards provide only same-command re-entry protection, and successful finalization itself occurs while `submit` is running.

Alternative considered: change `Command` globally to coordinate unrelated actions. Rejected because this ownership rule is specific to one Content Submission session and a global Command behavior change would broaden scope across the application.

Alternative considered: rely only on the form's Subplan 3 pre-submit checkpoint and absorbed interaction. Rejected because the ViewModel command is independently callable and must itself prove the exact attempt it sends, while a clean repeated command checkpoint remains an inexpensive no-op.

### 6. Execute remote work exclusively from the attempt

Keep `_submit()` exclusively bound to the prepared attempt: never consult live `_state` or `_assets` for that remote attempt. Iterate `attempt.assets` sequentially, create each image task only when its turn begins, stop on the first `Error`, and append successful `SubmissionAsset` values in captured order. Build one `ContentSubmission` from `attempt.draft`, carrying category, required contributor fields, text and Delta, and `eventDates.startInstantUtc`/`endInstantUtc`. Leave latitude, longitude, and address null because the current draft does not own them. Call repository `submit` with `attempt.draft.clientSubmissionId`, that immutable content model, and the ordered uploaded metadata.

Wrap all post-preparation, pre-acknowledgement work in structured ownership cleanup. A local boolean such as `acknowledged` is sufficient; it does not become a second lifecycle model. Every explicit Cloudinary or final-repository `Result.error`, malformed acknowledgement surfaced by the repository, transport failure, and unexpected throw before valid acknowledgement must pass through one `finally`/equivalent path that briefly reacquires `_serialize` and releases `_activeSubmissionClientSubmissionId` only when it still matches `attempt.draft.clientSubmissionId`. The release path must not clear draft or staged state and must not replace a different owner. Await that narrow release before `_submit()` completes with the original error so the next explicit clear or retry cannot observe a stale claim. Preserve staged files/descriptors and the existing deterministic Cloudinary duplicate/reuse behavior. Do not add rollback or parallel `Future.wait`; those options explicitly contradict this subplan.

After repository success has already validated the acknowledgement, set `_submissionFinalizationPending = true` and mark the local flow as acknowledged synchronously before awaiting any finalization work. From that point the `finally` path must not release ownership: a finalization error or throw leaves the acknowledged identity owned and finalization pending for local-only retry.

Ordinary production UI blocks edits while submission is on the progress route, but direct callers can still mutate fields. Such draft B mutations retain A's identity and therefore remain part of the same logical session. If A fails before acknowledgement, ownership release leaves B current and dirty relative to checkpoint A. If A is acknowledged and local retirement succeeds, B is intentionally retired with that completed same-identity session; do not clone B, transfer its staged assets, or synthesize another session before the one normal fresh identity is created.

Alternative considered: rebuild content from live state after uploads. Rejected because it divorces the request from the snapshot that was checkpointed and makes client identity/content evidence ambiguous.

Alternative considered: fork or copy late draft B into a fresh identity after A succeeds. Rejected because the guarded UI does not support concurrent editing, automatic transfer would require a second session-generation and staged-ownership protocol, and the mutation still belongs to A's logical identity.

### 7. Make clear and successful finalization ownership-aware

Extract the body that performs persistence-first draft deletion, existing best-effort staged cleanup, in-memory reset, and fresh-identity creation into one private retirement primitive that is invoked only while `_serialize` is held. Do not duplicate that sequence. Keep public `clear` as the explicit-discard Command, but inside its serialized turn check `_activeSubmissionClientSubmissionId` before calling `clearDraft()`. When an owner exists, return a focused local error before draft deletion, staged cleanup, state reset, or identity rotation. If clear entered the queue before preparation, normal FIFO order lets it retire the prior session first; if it waits behind preparation, the atomic claim makes it fail rather than overtake the prepared attempt.

Do not use `clear.execute()` as successful-submission finalization after this remediation. The first `_finalizeSubmittedSession(...)` call after acknowledgement must receive `attempt.draft.clientSubmissionId` as its expected identity; a later finalization-only retry may recover that same expected value from the retained `_activeSubmissionClientSubmissionId`. Finalization must enter `_serialize` directly and, in the same serialized turn before calling the shared retirement primitive, verify all of the following:

1. `_submissionFinalizationPending` is true.
2. The expected acknowledged identity is non-null and still equals `_activeSubmissionClientSubmissionId`.
3. `_state.clientSubmissionId` equals that expected acknowledged identity.

Any mismatch returns an error before `clearDraft()` or staged cleanup, leaves a different current session untouched, performs no rotation, and preserves the owner and pending-finalization state rather than silently declaring success. This is a defensive invariant: the new clear guard should make identity replacement during a healthy in-flight attempt unreachable, but finalization must still fail closed rather than destructively target arbitrary current state.

When the identity checks pass, invoke the one shared retirement primitive. A draft-clear failure leaves the old state, pending flag, and owner unchanged. On successful retirement, reset `_submissionFinalizationPending` and `_activeSubmissionClientSubmissionId` only after the acknowledged session has been cleared and one fresh identity has been installed; perform those transitions within the same serialized turn so a later explicit clear sees one coherent post-finalization state. Existing best-effort staged-cleanup result handling remains unchanged.

Because acknowledged finalization no longer delegates to the public `clear` Command, `ContentSubmissionScreen` no longer observes `clear.completed` to reset form controls. It instead observes successful ViewModel session-identity rotation and resets its form controls only when the client identity changes. This narrow listener migration preserves the visible cleared-form outcome after successful submission without delegating finalization ownership back to generic clear. It does not redesign routing, progress presentation, or unrelated UI behavior.

The early `_submissionFinalizationPending` branch in `_submit()` remains before attempt preparation. A retry therefore invokes only identity-bound local finalization and creates no image task or repository call. External clear remains rejected while finalization is pending because the acknowledged owner remains active.

Do not persist the finalization flag or active owner. Process-death ambiguity intentionally remains until the later backend-idempotency subplan; local durable state without server consumption would not resolve whether a prior request committed.

Alternative considered: allow finalization to call generic public clear and retire whichever session is current. Rejected because successful acknowledgement authorizes retirement only of the submitted identity and must never destroy a replacement session.

Alternative considered: add a generalized submission state machine. Rejected because one nullable owner identity plus the existing finalization-pending flag completely represents the required distinction.

Alternative considered: bypass identity checks because public clear is guarded. Rejected because finalization is destructive and must remain safe under unexpected internal state divergence as well as the ordinary path.

Alternative considered: add a durable remote-success marker now. Rejected because it changes ObjectBox schema and still cannot disambiguate a lost response without a server-side identity contract.

### 8. Prove contracts at their existing boundaries

Use `RecordingSupabaseFunctionsHttpClient` with a real test `SupabaseClient`, as the admin repository tests do, to assert exact request method/path/body, one invocation, bearer construction without `currentUser`, valid/additional success metadata, malformed IDs, structured and text Function errors, generic client error, and observable failure logging. Do not mock mapper or domain internals.

Extend the existing ViewModel suite and shared fakes rather than adding local harnesses. Preserve the completed checkpoint-ordering, A→B payload, immutable remote content, asset order, identity stability, finalization-only retry, staged-path, and deterministic duplicate/reuse coverage. Add gates for preparation, individual image results, final repository completion, and retirement to prove that external clear cannot cross an active owner; both explicit error results and thrown pre-acknowledgement exceptions release ownership; acknowledged local-finalization failure retains ownership; finalization cleanup targets only the submitted identity; and one successful completion rotates exactly once. Add paired A→B tests showing B survives and remains dirty on A failure but is intentionally retired without cloning on A success. Update widget/routing tests only if the private finalization refactor mechanically affects existing harnesses; do not change their navigation expectations.

The completed suite includes an additive fake capability that throws an arbitrary object from final `submit(...)`, proving the actual repository boundary releases unacknowledged ownership before the existing `Command` converts that object into its terminal error result. The session remains retryable and a subsequent explicit clear remains allowed.

Add one Deno parser test using the existing `validSubmission()` fixture plus a canonical UUID-v4-compatible `client_submission_id`. Assert only `result.ok`; do not assert the validated value exposes the ID. Reinspect the parser immediately before implementation. If it has begun rejecting unknown top-level fields, stop and revise the OpenSpec instead of modifying production backend code under this plan.

## Risks / Trade-offs

- [Repository HEAD diverges from the implemented Subplan 4 state] → Require `d61dadd2091c6924587dbc8d9d0dd64a91dd6fc5` as an ancestor or an explicitly reviewed equivalent preserving its complete immutable-attempt implementation and synchronized predecessor capabilities; stop and update artifacts when later production changes overlap ownership, checkpointing, staging, submit, or finalization.
- [A MODIFIED delta silently drops predecessor identity guarantees] → Keep the entire existing stable-identity requirement block and all prior scenario names in the delta, then run strict OpenSpec validation before implementation and after final changes.
- [Cross-capability specs simultaneously require an unchanged client envelope and `client_submission_id`] → Modify the complete navigation-lifecycle requirement so production backend behavior remains unchanged while the client-only compatibility field is explicit.
- [Cross-capability specs assign successful cleanup to both progress and the ViewModel] → Modify the complete local-asset-staging requirement so the existing cleanup primitive survives but the newer ViewModel owner is authoritative.
- [The attempt checkpoints A while ordinary setters publish B] → Capture A before await, save and baseline exactly A, execute remote work from A, and prove B remains live and dirty with a gated regression.
- [Clear waits behind preparation and rotates A before remote completion] → Claim A inside the same serialized preparation turn, reject public clear while any owner exists, and test both Cloudinary-pending and final-request-pending races.
- [An unexpected pre-acknowledgement throw strands ownership] → Use structured `finally`/equivalent cleanup that briefly reacquires local arbitration and test a thrown image-task or repository boundary.
- [Finalization targets a replacement identity] → Validate pending owner and current identity together inside the finalization arbitration turn before any destructive call; fail closed and preserve acknowledged ownership on mismatch.
- [Late same-identity draft B has ambiguous successful disposition] → State and test that B survives A failure but is retired without cloning when A succeeds, because both belong to the same logical identity and ordinary production UI blocks such edits.
- [Asset removal after local preparation deletes a captured file] → Do not claim filesystem pinning; process captured paths in order and return the existing first upload error while preserving the logical identity and retry policy.
- [Malformed success causes destructive local retirement] → Validate a positive integer `submission_id` before setting finalization pending or invoking clear; test every invalid scalar/type and extra-key tolerance.
- [Function errors lose backend diagnostics or leak inconsistent shapes] → Normalize only non-empty code/message strings with an explicit fallback order, preserve status, log once, and avoid logging request payloads containing contributor PII.
- [A compatibility field is mistaken for idempotency] → Keep production parser/database untouched, assert acceptance only, and state in specs/review that acknowledgement ambiguity remains open.
- [Removing one generated DTO causes broad generator drift] → Verify the source reference search, prefer the narrow output filter, inspect every generated diff, and reject unrelated Envied/ObjectBox/dart_mappable or dependency changes.
- [Cross-cutting interface rename leaves stale tests/callers] → Update interface, implementations, fakes, and all compile boundaries together; finish with repository-wide symbol searches and the complete Flutter test suite.
- [Repository-wide analyzer already has diagnostics] → Record the actual pre-change output, require zero new diagnostics in authored/touched files, and compare repository-wide diagnostics to that baseline rather than expanding into unrelated lint cleanup.
- [Existing local staged cleanup remains best-effort] → Preserve predecessor behavior in this subplan; do not claim stronger retirement durability than the current clear contract provides.

## Migration Plan

1. Treated `d61dadd` as the completed original Subplan 4 implementation under remediation and `9165a8a` as its synchronized parent, preserving unrelated work.
2. Added the private owner identity, claimed it atomically at the end of successful preparation, rejected public clear while it exists, and extracted one shared persistence-first retirement primitive without changing cleanup semantics.
3. Wrapped pre-acknowledgement remote execution in structured ownership release, retained ownership after valid acknowledgement, and switched successful finalization from generic `clear.execute()` to the identity-bound private path.
4. Added clear-race, exception-release—including the final repository thrown-object boundary—identity-bound finalization, no-double-rotation, finalization-retry, A→B success/failure, and visible form-reset regressions while preserving every existing Subplan 4 test.
5. Ran focused and complete Flutter verification, baseline-aware analysis, strict OpenSpec validation, cross-capability semantic review, and final scope inspection. No Deno production change or new database/backend verification was required because remediation is local ViewModel orchestration.

There is no database or backend deployment migration. The Dart interface rename and client request field must ship together in one application build. Rollback is source-only because the current server ignores the additional field and no durable schema is changed; however, do not rollback only the attempt checkpoint or only the remote payload changes while retaining dependent tests/contracts. Report completion as Subplan 4 only, with backend idempotency and ambiguous acknowledgement still deferred.
