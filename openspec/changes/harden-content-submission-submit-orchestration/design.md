## Context

See `proposal.md` for motivation and the two delta specs for required behavior. The authoritative synchronized baseline is `9165a8a47fd08d4c87a33fa08b8d8b3d4cc473fc`: it contains the completed Subplan 3 implementation and synchronizes all three completed predecessor capabilities into `openspec/specs/`. The main `content-submission-draft-persistence` spec therefore contains the local-only stable-identity requirement deliberately modified by this change. Implementation may proceed from a HEAD containing `9165a8a` as an ancestor, or from an explicitly reviewed equivalent state in which those completed predecessor capabilities are already synchronized. No historical test count is treated as the implementation baseline; the executor must rerun and retain focused pre-change outputs on the actual checkout.

The current public domain contract has two operations named around upload: `ContentSubmissionRepository.upload(ContentSubmission, List<SubmissionAsset>)` performs the final Edge Function request, while `uploadImageTask(File)` performs one Cloudinary binary upload. `ContentSubmissionRepositoryImpl` depends on the complete `Supabase` wrapper, obtains `currentUser?.id`, maps through `ContentSubmissionDto`, invokes `submit-content`, ignores `response.data`, catches `FunctionException` only as a generic `Exception`, and returns `Result.success(null)` for any non-throwing response. Repository-wide references show the old DTO and `ContentSubmissionMapper.toDto(userId:)` are used only by this implementation and their focused mapper test.

The current `submit-content` parser requires the existing content and asset fields but ignores unknown top-level fields. It therefore accepts and discards `client_submission_id`; the production handler still returns `201 {"submission_id": <integer>}` after its existing rate-limit and database work. This permissive acceptance is the compatibility seam for the client rollout. Production Edge code, validated types, RPCs, tables, RLS, and rate-limit state remain untouched.

`ContentSubmissionViewModel` already owns memoized initialization, `_PersistedDraftState`, an immutable `_checkpointedDraft`, one FIFO `_serialize` boundary for local draft/staged mutations, durable ordered staged assets, stable `clientSubmissionId`, sequential Cloudinary uploads, and transient `_submissionFinalizationPending`. Its current `_submit()` awaits initialization and validates live state, but then iterates live `_assets` and rebuilds `ContentSubmission` from live `_state` after network awaits. Direct command invocation does not checkpoint the attempted snapshot. The form's Subplan 3 transition checkpoint protects the ordinary UI route, but tests and other callers can invoke the command directly, and later edits can change the final payload after the checkpoint that justified the attempt.

The current clear/finalization path is intentionally preserved. After valid remote success it sets `_submissionFinalizationPending`, calls the existing `clear` Command, and retries only clear while pending. Staged cleanup remains the predecessor's best-effort policy: `_clear()` awaits but does not propagate `clearSession`/orphan-reconciliation `Result` values after draft clear succeeds. Strengthening that separate cleanup contract is not part of this submit-orchestration change.

## Goals / Non-Goals

**Goals:**

- Give final whole-submission a precise domain and wire contract without changing binary upload semantics.
- Make one exact draft/client-identity/asset snapshot both durable and authoritative for each remote attempt.
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
- Do not redesign the progress route, form transition checkpoint, clear ownership, or staged-cleanup failure semantics.

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

Add one private ViewModel-only record alias containing `ContentSubmissionDraft draft` and an unmodifiable ordered `List<Asset> assets`. Do not place it in `domain`; it is orchestration state, not a reusable business model.

Retain the early `_submissionFinalizationPending` branch after initialization and before any preparation. Otherwise invoke one private `_prepareSubmissionAttempt()` through the existing `_serialize` queue. Inside that one local critical section:

1. Reject unavailable/quarantined staged state and an asset count above `maximumAssetCount` using existing errors.
2. Capture `final draft = _state` before any checkpoint await.
3. Evaluate the existing event-time persistence policy against `draft.eventDates`, updating `_eventTimeIssue` with the same observable semantics as current submit validation; add no rule.
4. Validate only current submit-owned required fields (`city`, `name`, `userEmail`, `userName`) from `draft`.
5. Capture `List<Asset>.unmodifiable(_assets)` while staged membership is serialized.
6. Checkpoint exactly `draft` through the supplied-snapshot primitive.
7. Return the attempt only on checkpoint success.

The queue is held only for local validation, snapshot capture, and persistence. Release it before creating `ImageUploadTask`s or awaiting any network result. Ordinary setters are intentionally not serialized, so draft B may become live while A is saving; because A was captured before the await and the checkpoint primitive advances only to A, the intended A-baseline/B-dirty invariant remains true. Asset add/remove operations queue behind preparation until its checkpoint completes, then may proceed while remote work uses its immutable membership copy. The existing Subplan 3 UI pre-submit checkpoint remains unchanged as the navigation transition boundary; this ViewModel-side checkpoint is a separate defensive attempt invariant and does not replace or relocate the UI checkpoint.

If a captured staged source is independently deleted after the queue is released, the existing upload task fails normally and the attempt short-circuits. This design does not promise filesystem pinning across remote work or hold the lifecycle queue for network duration; normal UI submission already transitions to progress and blocks editing, while direct/adversarial callers receive deterministic captured membership and existing retryable error behavior.

Alternative considered: hold `_serialize` for the entire submit. Rejected because slow Cloudinary/Edge awaits would block clear and every durable local asset operation, turning a local commit queue into a network lock.

Alternative considered: rely only on the form's Subplan 3 pre-submit checkpoint and absorbed interaction. Rejected because the ViewModel command is independently callable and must itself prove the exact attempt it sends, while a clean repeated command checkpoint remains an inexpensive no-op.

### 6. Execute remote work exclusively from the attempt

Refactor `_submit()` to unwrap the prepared attempt and never consult live `_state` or `_assets` for that remote attempt. Iterate `attempt.assets` sequentially, create each image task only when its turn begins, stop on the first `Error`, and append successful `SubmissionAsset` values in captured order. Build one `ContentSubmission` from `attempt.draft`, carrying category, required contributor fields, text and Delta, and `eventDates.startInstantUtc`/`endInstantUtc`. Leave latitude, longitude, and address null because the current draft does not own them. Call repository `submit` with `attempt.draft.clientSubmissionId`, that immutable content model, and the ordered uploaded metadata.

Any Cloudinary or final repository error returns immediately without local retirement. Preserve staged files/descriptors and the existing deterministic Cloudinary duplicate/reuse behavior. Do not follow the current source TODO suggesting rollback or parallel `Future.wait`; those options explicitly contradict this subplan.

Alternative considered: rebuild content from live state after uploads. Rejected because it divorces the request from the snapshot that was checkpointed and makes client identity/content evidence ambiguous.

### 7. Preserve the existing finalization owner and retry branch

After repository `submit` returns a valid success, set `_submissionFinalizationPending = true` immediately and delegate to the existing `_finalizeSubmittedSession()`/`clear.execute()` path. A repository error, including malformed acknowledgement, returns before setting the flag. On a local clear error, keep the flag and old identity; on a later `submit.execute()`, branch to finalization before preparation, validation, checkpointing, Cloudinary, or repository invocation. One successful clear remains the only rotation point.

Do not persist the finalization flag. The process-death ambiguity intentionally remains until the later backend idempotency subplan, and adding local durable state without server consumption would not resolve whether a prior request committed.

Alternative considered: add a durable remote-success marker now. Rejected because it changes ObjectBox schema and still cannot disambiguate a lost response without a server-side identity contract.

### 8. Prove contracts at their existing boundaries

Use `RecordingSupabaseFunctionsHttpClient` with a real test `SupabaseClient`, as the admin repository tests do, to assert exact request method/path/body, one invocation, bearer construction without `currentUser`, valid/additional success metadata, malformed IDs, structured and text Function errors, generic client error, and observable failure logging. Do not mock mapper or domain internals.

Extend the existing ViewModel suite and shared fakes rather than adding local harnesses. Gate draft save, individual image results, and final repository completion to prove checkpoint ordering, A→B snapshot races, immutable remote content, asset order, identity stability across Cloudinary/final errors, and finalization-only retry. Preserve existing staged-path and deterministic duplicate/reuse assertions. Update existing form/progress/route/restoration tests only as needed for the contract rename and strengthened captures; do not weaken Subplans 1–3 navigation/finalization expectations.

Add one Deno parser test using the existing `validSubmission()` fixture plus a canonical UUID-v4-compatible `client_submission_id`. Assert only `result.ok`; do not assert the validated value exposes the ID. Reinspect the parser immediately before implementation. If it has begun rejecting unknown top-level fields, stop and revise the OpenSpec instead of modifying production backend code under this plan.

## Risks / Trade-offs

- [Repository HEAD diverges across checkpoint, staged-state, finalization, DTO, or Edge parser boundaries] → Require `9165a8a47fd08d4c87a33fa08b8d8b3d4cc473fc` as an ancestor or an explicitly reviewed equivalent state with synchronized predecessor capabilities; stop and update artifacts when new production changes overlap these assumptions.
- [A MODIFIED delta silently drops predecessor identity guarantees] → Keep the entire existing stable-identity requirement block and all prior scenario names in the delta, then run strict OpenSpec validation before implementation and after final changes.
- [The attempt checkpoints A while ordinary setters publish B] → Capture A before await, save and baseline exactly A, execute remote work from A, and prove B remains live and dirty with a gated regression.
- [Asset removal after local preparation deletes a captured file] → Do not claim filesystem pinning; process captured paths in order and return the existing first upload error while preserving the logical identity and retry policy.
- [Malformed success causes destructive local retirement] → Validate a positive integer `submission_id` before setting finalization pending or invoking clear; test every invalid scalar/type and extra-key tolerance.
- [Function errors lose backend diagnostics or leak inconsistent shapes] → Normalize only non-empty code/message strings with an explicit fallback order, preserve status, log once, and avoid logging request payloads containing contributor PII.
- [A compatibility field is mistaken for idempotency] → Keep production parser/database untouched, assert acceptance only, and state in specs/review that acknowledgement ambiguity remains open.
- [Removing one generated DTO causes broad generator drift] → Verify the source reference search, prefer the narrow output filter, inspect every generated diff, and reject unrelated Envied/ObjectBox/dart_mappable or dependency changes.
- [Cross-cutting interface rename leaves stale tests/callers] → Update interface, implementations, fakes, and all compile boundaries together; finish with repository-wide symbol searches and the complete Flutter test suite.
- [Repository-wide analyzer already has diagnostics] → Record the actual pre-change output, require zero new diagnostics in authored/touched files, and compare repository-wide diagnostics to that baseline rather than expanding into unrelated lint cleanup.
- [Existing local staged cleanup remains best-effort] → Preserve predecessor behavior in this subplan; do not claim stronger retirement durability than the current clear contract provides.

## Migration Plan

1. Revalidate that HEAD contains authoritative synchronized baseline `9165a8a` as an ancestor or is an explicitly reviewed equivalent state; also verify working-tree preservation, predecessor specs, parser permissiveness, DTO consumers, and focused Flutter/Deno/analyzer baselines. Strictly validate this OpenSpec before source edits.
2. Change the public repository contract, shared fakes, explicit wire mapper, narrow `SupabaseClient` implementation, acknowledgement/error parsing, and direct repository tests as one compile-safe unit. Remove verified-dead DTO/mapping output through the generator boundary.
3. Refactor checkpointing to accept an exact snapshot, add serialized immutable-attempt preparation, and execute remote work only from that attempt. Add focused race, ordering, failure, retry, and finalization regressions before mechanical widget/routing updates.
4. Add the parser compatibility test without production backend changes, then run focused suites, complete Flutter tests, baseline-aware analysis, formatting, generated-diff inspection, repository-wide stale-symbol searches, strict OpenSpec validation, and an independent semantic review of persistence/remote/finalization boundaries.

There is no database or backend deployment migration. The Dart interface rename and client request field must ship together in one application build. Rollback is source-only because the current server ignores the additional field and no durable schema is changed; however, do not rollback only the attempt checkpoint or only the remote payload changes while retaining dependent tests/contracts. Report completion as Subplan 4 only, with backend idempotency and ambiguous acknowledgement still deferred.
