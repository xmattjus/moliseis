## Context

See `proposal.md` for motivation and `specs/content-submission-draft-persistence/spec.md` for required behavior. Repository reality was revalidated from a clean `main` checkout at `79e009c` (`Revert "feat: support staged assets and editor refresh"`), immediately after `abec1dc` reverted the related documentation update. Those two reverts restore the intended implementation baseline; neither the reverted code nor its design choices are inputs to this change. The separate active Admin editor OpenSpec remains unimplemented and is outside this public Content Submission workstream.

The current public draft path is:

`ContentSubmissionViewModel` setter → `_emit()` → three-second `Debounced` callback → `ContentSubmissionDraftRepository.saveDraft(state)` → mapper → `ContentSubmissionDraftEntity` → ObjectBox.

`ContentSubmissionViewModel` creates an empty `ContentSubmissionDraft`, eagerly receives `initialize()` from `config/dependencies.dart`, restores a successful non-null repository load, and otherwise falls back to the empty state. Every form setter calls `_emit()`, which schedules an unawaited save and then notifies listeners. The callback reads `state` when the timer fires rather than capturing the mutation snapshot, save failures are not surfaced, and `dispose()` only cancels a pending timer. `_clear()` currently clears form state and assets, reports state-clear success, then awaits and discards `clearDraft()`'s result; a deletion failure can therefore leave ObjectBox holding a session the ViewModel has already abandoned.

The existing immutable `ContentSubmissionDraft` already has structural equality across every persisted form field, including deep/order-sensitive Delta equality, and `copyWith` preserves untouched values. The repository contract already supplies `loadDraft()`, `saveDraft(...)`, and `clearDraft()` as `Future<Result<...>>`. `ContentSubmissionDraftEntity` has a fixed assignable entity ID of `1`; repository save/load/clear directly replace/read/remove that record. Preserve all of those boundaries.

ObjectBox 5.3.2 is configured to generate `lib/generated/objectbox.g.dart` and `lib/generated/objectbox-model.json`. The draft entity is ObjectBox entity `20`, currently ending at property ID `17`. ObjectBox merges annotated source with the existing model JSON, assigns a new property ID/UID, and retains retired UIDs; generated IDs must not be authored or renumbered manually. A new nullable string property lets an existing row deserialize with `null`, which is the narrow compatibility mechanism used only to reject unsupported pre-identity records safely.

Baseline verification on 2026-09-02 found all focused model, mapper, real-ObjectBox repository, and ViewModel tests passing (88 tests). Repository-wide `flutter analyze` is not zero-clean: it reports 189 pre-existing diagnostics. Targeted analysis of the planned authored source/tests reports four pre-existing info diagnostics: two positional-boolean notices in `ContentSubmissionViewModel` and two unrelated notices in `test/support/fake_repositories.dart`. Verification must reject new/in-scope diagnostics without broadening this change into existing lint cleanup; generator-owned Dart is verified through generation diff and tests rather than independent style cleanup.

## Goals / Non-Goals

**Goals:**

- Make a ViewModel checkpoint the sole ordinary local draft-write boundary and make its result awaitable by callers.
- Represent cleanliness by comparing immutable current and checkpoint snapshots, including one stable logical-session identity.
- Keep fresh construction, valid recovery, checkpoint success/failure, and discard success/failure internally consistent without adding a second source of state truth.
- Extend the existing single ObjectBox draft shape additively and reject pre-identity rows without migration or automatic repair.

**Non-Goals:**

- Select or add a UI, route, back-navigation, lifecycle, submit, or app-finalization event that calls `checkpointDraft()`; no such explicit caller exists in the post-revert baseline, and this workstream only establishes the deterministic operation. Any future caller must await it and handle its `Result` under its own approved UX contract.
- Persist image files or asset metadata; change image selection, Cloudinary, upload signing, upload retries, or remote submission construction; or add local/remote submission finalization APIs.
- Add `clientSubmissionId`/`client_submission_id` to `ContentSubmission`, DTOs, requests, Supabase, Edge Functions, RPCs, RLS, or migrations.
- Change Admin editors, navigation/`go_router`, progress routes, submit-result UX, or Admin deduplication.
- Add multi-draft storage, a session aggregate/manager/service/repository, an ID value object, a use case, a transaction coordinator, a lock, a write queue, or a new state-management/persistence framework.
- Restore old local draft content, fix unrelated malformed event-row mapping, or perform generalized Content Submission cleanup.

## Decisions

### 1. Add identity directly to the existing immutable draft

Add non-null `clientSubmissionId` to `ContentSubmissionDraft`. Normal construction without an explicit identity generates a new canonical UUID-v4-compatible string from 16 bytes produced by Dart SDK `Random.secure()`, setting the RFC 4122 version-4 and variant bits before lowercase hexadecimal formatting. An explicitly supplied recovered/test identity must satisfy the same UUID-v4 shape; do not silently normalize or replace an invalid supplied value. There is no insecure fallback.

Keep generation and validation as focused private/static behavior on the existing draft model rather than adding a package or another architectural type. The repository already depends directly on `crypto`, but hashing does not generate secure random bytes; `uuid` is only transitive and has no established project usage. A small standard-library implementation is sufficient, so promoting `uuid` to a direct dependency would add package surface solely for this one consumer.

Include `clientSubmissionId` in `==` and `hashCode`; this makes structurally identical forms from two logical sessions correctly unequal. `copyWith` must always carry the existing identity and need not expose identity replacement as an editing operation. Keep the identifier out of remote conversion and do not add it to `ContentSubmission`; it also need not be added to `toString()`/draft logs.

Alternative considered: a manually supplied required ID plus a separate generator or factory service. Rejected because it forces every draft construction site through an abstraction with one production consumer and increases test/DI churn without improving the contract.

Alternative considered: `SubmissionSession`, a dedicated ID value object, or a second session repository. Rejected under KISS, YAGNI, and Rule of Three: the existing draft is already the immutable persisted session snapshot and only one ViewModel/repository path needs the identity.

### 2. Derive dirty state from one checkpoint baseline

Initialize `_state` once to a fresh draft and initialize a private `_checkpointedDraft` to that exact snapshot. Expose `hasUnsavedChanges => _state != _checkpointedDraft`. Extend draft equality for the identity as above; do not add a mutable `_isDirty` flag or setter-specific dirty assignments.

All current form setters continue to replace `_state` with `copyWith` and notify listeners. `_emit()` becomes notification-only. Remove the debounce import, `_debounced` field and constructor setup, unawaited debounce call, and debounce cancellation from `dispose()`; do not modify the shared `debounceable.dart`, which is not owned by this capability. A no-op setter may still emit as it does today, but structural comparison leaves cleanliness unchanged and no persistence follows.

Alternative considered: maintain a boolean in every setter and reset it in load/save/clear branches. Rejected because it duplicates one invariant across many mutation sites and is especially prone to false-clean state after asynchronous save failure or an in-flight mutation.

Alternative considered: retain autosave with a shorter, longer, or resettable timer. Rejected because changing timing does not make persistence explicit, awaitable, or snapshot-deterministic.

### 3. Checkpoint the captured snapshot and propagate `Result`

Expose `Future<Result<void>> checkpointDraft()` directly on the ViewModel. It is intentionally not a `Command0`: no UI action/running/error UX is introduced here, `Command0.execute()` returns `Future<void>`, and this contract requires the caller to await and receive the repository result.

The operation performs exactly this sequence:

1. Capture `final snapshot = _state` before any await.
2. Return `const Result.success(null)` without a repository call when `snapshot == _checkpointedDraft`.
3. Await `_draftRepository.saveDraft(snapshot)`.
4. On `Success`, assign `_checkpointedDraft = snapshot` and notify active listeners so derived dirty state can update.
5. On `Error`, return the same error without changing the baseline or identity.

The success branch must not read `_state` to choose the new baseline. If A is saved while the user creates B, baseline A leaves B dirty. Immutable draft/Delta snapshots make the captured argument stable across the await.

No mutex or queue is added. The supported contract is sequential explicit persistence: callers await a checkpoint before starting another checkpoint or discard. Mutation while one checkpoint awaits is supported and tested; overlapping persistence operations deliberately started without awaiting are not ordered by this change. If a real production caller later requires overlapping checkpoint/discard arbitration, that caller contract must be designed separately rather than hidden here.

Alternative considered: serialize writes through a queue/mutex or add a generalized transaction coordinator. Rejected because autosave removal eliminates hidden competing writes and no current caller requires concurrent checkpoints.

### 4. Recover only a draft carrying a valid identity

Add nullable `clientSubmissionId` to `ContentSubmissionDraftEntity` and map the non-null domain value in both directions. Storage nullability is intentional for automatic additive ObjectBox schema compatibility; domain state remains non-null.

Make the entity-to-domain mapper return no current model when the stored identifier is absent or fails UUID-v4 validation, before mapping the remaining legacy fields. `ContentSubmissionDraftRepositoryImpl.loadDraft()` already accumulates a nullable model and returns `Result.success(null)` for no recoverable draft, so its interface and fixed-ID control flow can remain unchanged. Do not delete or rewrite the unsupported row. An effective edit followed by the normal explicit checkpoint replaces ObjectBox ID `1` with the current shape; an untouched fallback session remains write-free.

On `Success(validDraft)`, `initialize()` assigns both `_state` and `_checkpointedDraft` to the recovered immutable snapshot, preserving the exact identifier and exposing clean state without save. On `Success(null)` or existing repository error fallback, retain the fresh state/baseline created for this ViewModel and only transition load state to ready. The current screen hides form editing while loading; changing the broader initialize-versus-programmatic-mutation race is not required for this workstream.

Alternative considered: generate an identity for an old row and recover its content. Rejected because it silently converts unsupported historical state into a new logical session and creates migration semantics this cycle explicitly does not promise.

Alternative considered: delete, backfill, or checkpoint the old row during initialization. Rejected because opening the form must not write merely to store or repair an identity.

### 5. Preserve the fixed ObjectBox record and regenerate only from source

Keep `@Id(assignable: true)`, `_draftId = 1`, direct `getAsync(1)`/`removeAsync(1)`, and `putAsync` replacement. `clientSubmissionId` is ordinary draft data, never the ObjectBox key. Add the annotated entity field and mapper inputs, then run the narrowest verified build-runner invocation that emits both `lib/generated/objectbox.g.dart` and `lib/generated/objectbox-model.json`. If output filtering cannot produce both files with the installed builders, use the repository's normal `dart run build_runner build --delete-conflicting-outputs`, inspect the complete generated diff, and reject unrelated Envied or dart_mappable drift. Never hand-edit generated property IDs/UIDs or add lint ignores to generated Dart.

The generated model must retain entity ID `20`, all existing property IDs/UIDs, and the retired-ID history while assigning one new property ID/UID. Real temporary-Store tests, not ObjectBox mocks, prove save/load/replace/clear behavior and the legacy null-property projection.

Alternative considered: use the UUID as an ObjectBox key or redesign storage as a multi-row draft collection. Rejected because the current requirement remains exactly one local draft and the logical session identity has a different purpose from storage addressing.

### 6. Clear persistence before abandoning the in-memory session

Keep the existing `clear` `Command0`, screen loading behavior, repository boundary, and logging event types, but reverse the unsafe state/persistence ordering:

1. Log state-clear start and await `_draftRepository.clearDraft()` without modifying state, assets, transient event issue, checkpoint baseline, or identity.
2. On `Error`, log the existing state-clear failure event as appropriate and return the same error. Because the command remains running during the await, the existing screen can continue to hide the form without a navigation redesign.
3. On `Success`, clear assets and the transient event-time issue, create one fresh empty draft with a new identity, assign it to both `_state` and `_checkpointedDraft`, notify listeners, log state-clear success, and return success.

This ordering prevents a deletion failure from rotating the session while the old record remains recoverable after restart. With debounce removed, discard no longer has to cancel or race an implicit pending save. Future remote success must eventually cause the old logical identity to stop being reused, but this change neither rewires submit nor adds an unused `finalizeSession()` API.

### 7. Replace, do not preserve, autosave test intent

Use the existing `FakeContentSubmissionDraftRepository` and minimally extend it with an optional completer/gate or queued save results to hold one save in flight; follow existing completer patterns in `test/support/fake_repositories.dart`. Rework the ViewModel tests that intentionally require saves after three seconds, description autosave, terms autosave, and best-effort clear. Add focused cases for fresh identity/cleanliness/no write, all-setter no implicit save beyond three seconds, explicit checkpoint/no-op/failure/retry, mutation B while A awaits, recovery, identity continuity, and success/failure discard ordering.

Update `content_submission_screen_test.dart` only where it flushes or assumes debounce/early in-memory clear. Preserve its useful UI guarantee that a running clear hides stale form controls, while asserting the ViewModel retains the old session until the gated clear succeeds. Domain equality/copy tests must pin one valid identity when comparing form fields and independently prove identity affects equality and survives `copyWith`. Mapper and repository tests use valid fixed UUIDs, plus a directly seeded real ObjectBox entity with null/invalid identity for legacy fallback. Keep existing rich Delta, 5,000-character description, null-Delta, category, date, and incomplete-event regressions green.

## Risks / Trade-offs

- [A copied draft accidentally rotates its identity] → Require `copyWith` to pass the current identity, test every existing field mutation plus repeated checkpoints against one captured ID, and omit identity replacement from form editing APIs.
- [A checkpoint marks newer state clean] → Capture before await, assign only the captured snapshot on success, and gate repository completion in a regression where state changes from A to B.
- [A failed clear abandons or hides recoverable state] → Defer every destructive in-memory mutation until repository success; test pending, error, and success branches including assets, identity, baseline, and command result.
- [Legacy data crashes or is silently migrated] → Keep the storage property nullable, validate identity before mapping other fields, project invalid/missing identity to no recoverable draft, and assert zero save/clear calls during initialization.
- [UUID generation is insecure or malformed] → Use only `Random.secure()`, mask version/variant bits, test canonical UUID-v4 shape and identity rotation, and do not fall back to `Random()`.
- [ObjectBox generation renumbers schema or drifts unrelated generators] → Generate from the annotated entity, inspect model IDs/UIDs and complete generated diff, retain only the new property/binding, and stop rather than editing generated output manually.
- [Tests keep sleeping for autosave and obscure the new contract] → Remove obsolete debounce helpers/waits where their only purpose is timer flushing; retain one beyond-three-seconds negative assertion.
- [Verification is broadened into existing lint cleanup] → Compare against the recorded 189-repository/four-targeted diagnostic baseline and require no new or in-scope diagnostics; do not change existing positional-boolean APIs for this feature.
- [Future callers overlap persistence operations] → Document sequential awaiting as the supported contract and defer synchronization until a concrete caller demonstrates the need.
- [Scope expands into remote idempotency or session finalization] → Reject changes outside the local Flutter-domain-ObjectBox boundary and plan remote use of the ID in a later capability.

## Migration Plan

1. Add and test the domain identity semantics, nullable ObjectBox property, mapping, and unsupported-legacy projection while retaining fixed record ID `1`.
2. Regenerate ObjectBox bindings/model metadata from source and verify only one additive draft property receives a new stable ID/UID.
3. Replace ViewModel debounce state with the checkpoint baseline, explicit checkpoint, recovery baseline, and persistence-first discard behavior; update existing fakes and regressions rather than creating parallel harnesses.
4. Run focused model/mapper/repository/ViewModel/widget verification, baseline-aware analysis, broader Content Submission regressions, generated-diff checks, and strict OpenSpec validation.

ObjectBox applies the additive local schema when the store opens. No explicit data migration, backend rollout, or remote coordination is required. Existing rows deserialize with a null identity and are intentionally not recovered or rewritten. Before release, retain generated schema metadata in version control. Rollback after devices have opened the additive schema must preserve compatible ObjectBox model history rather than restoring an older generated model blindly; if rollback mechanics cannot retain that metadata, stop and validate ObjectBox downgrade behavior before release.
