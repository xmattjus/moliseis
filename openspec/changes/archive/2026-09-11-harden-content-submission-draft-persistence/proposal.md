## Why

Content Submission field edits currently schedule a three-second debounced ObjectBox save, so persistence happens implicitly after state emission and callers cannot deterministically know which draft snapshot is durable. Explicit, awaited checkpoints and a stable local submission identity are the smallest hardening needed to make dirty state, restart recovery, retries, and discard behavior predictable without redesigning the existing single-draft repository.

## What Changes

- Remove debounced draft autosave from `ContentSubmissionViewModel`; form mutations update and emit in-memory state only, including after the former debounce interval.
- Expose `hasUnsavedChanges` as structural inequality between the current immutable draft snapshot and the last snapshot successfully loaded or checkpointed.
- Add one explicit, awaitable `checkpointDraft()` operation that captures the current snapshot, skips clean writes, preserves `Result<void>` failures, and advances the baseline only to the snapshot actually saved.
- Add a secure-random, UUID-v4-compatible `clientSubmissionId` to the domain draft and its existing ObjectBox entity/mapper so one logical local submission retains its identity across checkpoints, failures, retries, process restarts, and recovery.
- Harden initialization so a valid recovered draft and identity become the clean baseline without an automatic repair write; an unsupported legacy row with no valid identity falls back safely to a fresh clean session.
- Harden explicit discard so persisted removal succeeds before form state is reset and the identity rotates; a failed clear preserves the current state, identity, and dirty status and returns the repository error.
- Replace autosave-protection tests with explicit checkpoint, dirty-state, identity lifecycle, recovery, discard-ordering, legacy-row, and real ObjectBox round-trip regressions.
- Preserve the fixed ObjectBox entity ID/single-draft strategy and the existing `loadDraft()`, `saveDraft(...)`, and `clearDraft()` repository surface.

## Capabilities

### New Capabilities

- `content-submission-draft-persistence`: Deterministic local Content Submission checkpoints, derived dirty state, stable client session identity, recovery, and safe discard semantics.

### Modified Capabilities

None.

## Impact

- Affects the public Content Submission draft boundary only: `ContentSubmissionDraft`, `ContentSubmissionViewModel`, the existing ObjectBox draft entity/mapper/repository implementation, generated ObjectBox bindings/model metadata, and their existing domain, mapper, repository, ViewModel, and focused widget tests.
- Uses `Random.secure()` from the Dart SDK for a focused UUID-v4-compatible generator; no new package or persistence abstraction is expected.
- Adds one nullable ObjectBox string property so existing stores can open and legacy rows can be identified, while valid current domain drafts always carry a non-null identity. Generated files must come from the established `build_runner` workflow, not manual edits.
- Does not change physical asset persistence or selection, Cloudinary/upload signing, the remote submission repository or payload, remote finalization, Admin flows, navigation or `go_router`, Supabase schemas/migrations/RPCs/RLS/Edge Functions, multi-draft storage, or generalized session/transaction infrastructure.
