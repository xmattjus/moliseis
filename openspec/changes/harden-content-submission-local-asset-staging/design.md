## Context

See `proposal.md` for motivation and `specs/content-submission-local-asset-staging/spec.md` for required behavior. Repository reality was revalidated on 2026-09-03 at `60f0f9e` (`feat(draft): add explicit draft checkpoints`), with a clean working tree before this change was scaffolded. Subplan 1 is implemented and its active OpenSpec change is complete: `ContentSubmissionDraft` has one stable UUID-v4 `clientSubmissionId`; ObjectBox still stores one fixed-ID draft; `checkpointDraft()` captures immutable state and propagates `Result<void>`; and `_clear()` waits for `clearDraft()` before abandoning state. Subplan 1 deliberately selected no production checkpoint caller and no cross-operation arbitration. This subplan supplies the first such caller without redesigning that work.

The current `ContentSubmissionViewModel` keeps `List<Asset>` where `Asset` is `({XFile file, String digest})`. `_addAsset()` calls `pickMultipleMedia(limit: remainingCapacity)`, rejects files above 10 MiB, calculates SHA-1 from the picker `XFile`, deduplicates only against in-memory digests, and stores the original `XFile`. `_retrieveLostAssets()` is triggered immediately by `ContentSubmissionScreen.initState()`, independently of the unawaited `initialize()` started in `config/dependencies.dart`; on Android it calls `retrieveLostData()` and currently processes results immediately. `removeAssetAt` and `clear` remove only in-memory assets. `ContentSubmissionAssetList` renders `Image.file(File(asset.file.path))`, while `_submit()` sequentially calls `uploadImageTask(File(asset.file.path))`. After a completed submit, the existing `ContentSubmissionProgressScreen` invokes the same `clear` Command when the user leaves the progress route; this is already a production session-retirement caller and must be accounted for rather than described as nonexistent. No local staged-asset repository exists.

The generic `Command` guards only its own `_running` flag. `addAsset`, `removeAssetAt`, `retrieveLostAssets`, and `clear` are separate instances, so their actions can overlap. `_checkpointedDraft` is initialized to the newly created `_state`; consequently equality currently proves only matching snapshots, not that ObjectBox contains the draft. These are the two deferred lifecycle decisions that become load-bearing when file ownership is tied to a draft identity.

Existing dependencies already provide the required implementation surface: `image_picker` resolves to 1.2.3, ObjectBox is 5.3.2, and `crypto`, `path`, and `path_provider` are direct dependencies. Current image_picker guidance requires calling lost-data retrieval at startup on Android because the activity/process can be destroyed while an intent is open, and exposes recovered `files` or an exception. ObjectBox generation writes `lib/generated/objectbox.g.dart` and `lib/generated/objectbox-model.json`. Existing repository queries explicitly call `.order(...)`, close queries in `finally`, and return expected infrastructure failures through `Result`.

No backend expansion is needed. The Flutter submit loop converts each current asset path to `File`, the Cloudinary client independently derives a SHA-256 public ID, and `submit-content` sends remote `SubmissionAsset` metadata. Supabase's `submissions_assets` table and service-role `add_submission_assets`/`delete_submission_asset` RPCs operate only after remote upload; both the Edge Function parser and RPC retain an independent maximum of five. This subplan does not alter those contracts.

Planning baseline verification passed 121 focused draft, ViewModel, asset-list, screen, and restoration tests. Repository-wide `flutter analyze` is not zero-clean: it reports 189 pre-existing diagnostics, including two positional-boolean infos in `ContentSubmissionViewModel` and two in `test/support/fake_repositories.dart`. Implementation verification must use targeted zero-new/in-scope analysis and compare repository-wide output with that baseline rather than expanding scope into lint cleanup.

## Goals / Non-Goals

**Goals:**

- Transfer accepted local files into private Content Submission ownership under the same durable identity as the draft.
- Make staging, reconciliation, restoration, removal, discard, and Android recovery deterministic across asynchronous lifecycle overlap and crash windows.
- Preserve the existing ViewModel/Command/UI/upload contracts while replacing picker-owned runtime paths with staged paths.
- Keep filesystem/ObjectBox coordination simple, idempotent, and recoverable without pretending the two stores are transactional.
- Leave a concrete tested per-session cleanup operation for later successful-finalization wiring.

**Non-Goals:**

- Do not add another session identifier, make the fixed draft repository multi-row, or adopt old staged directories into a fresh identity.
- Do not build a media framework, filesystem service stack, use case layer, transaction journal, staging state machine, global scheduler, or general mutex package.
- Do not change generic `Command`, public/Admin shared media abstractions, Admin behavior, Content Submission navigation/progress UX, upload ordering, Cloudinary cleanup, or remote retry design.
- Do not add persisted upload status, thumbnails, dimensions, duration, MIME type, timestamps, source paths, remote IDs/URLs, or asset bytes.
- Do not modify Supabase, RLS, Edge Functions, migrations, RPCs, Cloudinary signing, remote `SubmissionAsset`, or backend maximum-five enforcement.
- Do not wire successful remote finalization if a later hardening subplan owns the definitive session-retirement contract, and do not claim whole-feature release readiness.

## Decisions

### 1. Keep `clientSubmissionId` as the sole local ownership key

Every staging directory, descriptor query, duplicate check, restoration, removal, cleanup, stale-operation comparison, and orphan decision uses `ContentSubmissionDraft.clientSubmissionId`. The ObjectBox draft ID remains the fixed technical key `1`; the staged descriptor gets its own auto-increment technical ID solely for persistence identity and ordering. The active product still supports one public draft.

Alternative considered: introduce `assetSessionId`, a second UUID, or a persistent session manager. Rejected because it duplicates the exact ownership represented by `clientSubmissionId`, creates synchronization failure modes, and violates the single-draft boundary.

### 2. Track durable draft existence independently from checkpoint equality

Add one private boolean (semantic name `_hasDurableCheckpoint`) beside `_checkpointedDraft`. It starts false for the newly constructed in-memory draft, becomes true after `initialize()` successfully loads a valid persisted draft or `saveDraft(snapshot)` succeeds, and returns to false when successful discard rotates to a new draft. `checkpointDraft()` may skip an equal snapshot only when this flag is true; otherwise it must save the captured snapshot even when `snapshot == _checkpointedDraft`.

This is a narrow refinement of Subplan 1's equality optimization: snapshot equality continues to define dirty form state, but no longer doubles as proof that storage contains the identity. The pre-picker phase calls the refined checkpoint inside lifecycle arbitration and returns its exact error before any picker invocation. On save success it captures the active ID for that picker operation.

Alternative considered: call `loadDraft()` before every picker or add repository `exists`/session-store APIs. Rejected because successful load/save outcomes already provide the needed evidence and another read contract or store would duplicate state.

Alternative considered: always save before every picker. Rejected because it discards Subplan 1's useful unchanged-snapshot optimization after durable existence is known.

### 3. Use one small private resilient async queue for local lifecycle arbitration

Implement one private Content Submission-local serialization helper in or immediately adjacent to `ContentSubmissionViewModel`, using a chained `Future`/`Completer` tail that releases even when an operation returns or throws an error. It serializes local asset/session mutation phases and all calls to the public `checkpointDraft()` write boundary. Do not expose it as a package-wide mutex and do not route `submit` or ordinary form setters through it.

The participating phases are:

1. public standalone draft checkpoints;
2. addAsset's durable checkpoint plus active-ID capture;
3. addAsset's returned-candidate validation/staging commit;
4. lost-data processing after initialization;
5. persistent `removeAssetAt`;
6. staged cleanup plus clear/session rotation.

Implement the checkpoint body as a private already-inside-boundary helper. Public `checkpointDraft()` enters arbitration before that helper captures `_state`; addAsset's pre-picker section enters arbitration once and calls the helper directly. This avoids nested-lock deadlock and prevents a standalone checkpoint from completing after clear and recreating the retired draft. If checkpoint starts first, clear waits for it and then clears that complete snapshot/session; if clear starts first, a later checkpoint captures only the new identity after rotation.

Tests must overlap different Command instances to prove the helper, because `Command._running` only prevents re-entry of one instance. The generic utility remains unchanged.

Alternative considered: modify `Command` to coordinate all Commands or add a global scheduler. Rejected because unrelated features have no such ordering requirement and global serialization would be both risky and overbroad.

Alternative considered: rely on `_running` flags or disable buttons. Rejected because screen startup, programmatic calls, and different Commands can still overlap.

Make `initialize()` idempotent by memoizing one shared initialization future. `config/dependencies.dart` continues to start it unawaited, while `addAsset`, public `checkpointDraft()`, `removeAssetAt`, and `clear` await that same future before entering lifecycle arbitration; calling one of those APIs in a test or atypical caller before DI starts initialization starts the memoized initialization itself. This prevents a fresh constructor draft from being checkpointed/cleared while a persisted draft is still loading and then overwritten by the late load. Recovery remains special only in ordering: it calls `retrieveLostData()` first and awaits the same future afterward. Ordinary form setters retain the existing screen-controlled loading contract and are not newly serialized.

### 4. Split addAsset around the external picker and revalidate ownership

`_addAsset()` uses two serialized sections:

1. Enter arbitration, verify capacity if useful, await the durable checkpoint, capture the current `clientSubmissionId`, and exit.
2. Await `pickMultipleMedia()` with the current remaining-capacity hint outside arbitration.
3. Re-enter arbitration, compare the captured ID to `_state.clientSubmissionId`, and only on equality compute current capacity and process candidates.

If clear rotates A to B while the picker is open, the returned A result is a successful no-op/stale cancellation: no candidate length/hash read is required, no staging temp/final file or descriptor is created, `_assets` is unchanged, and no generic snackbar/error is produced. Diagnostic logging may identify the discarded operation without logging paths or user content. If staging entered the second section first, clear queues behind it and then removes all A state before rotating.

The lock must never cover `pickMultipleMedia()`: an external user interaction has unbounded duration and would otherwise block explicit discard. The public `addAsset`, `AssetSelectionOutcome`, and all Command names remain unchanged.

Disposal is a terminal runtime-publication boundary. Post-picker commit checks disposal before candidate work, and the common candidate path rechecks it after every awaited size, digest, acquire, and resolution step before adding to `_assets`. Persistent removal likewise rechecks after its repository call before changing runtime state. A commit that completed before disposal remains durable for next initialization; this subplan does not add cancellation or rollback. Add/remove suppress post-disposal notifications.

### 5. Add one minimal staged descriptor model and repository boundary

Introduce immutable `ContentSubmissionStagedAsset` with exactly `clientSubmissionId`, `digest`, and `relativePath`. Add a separate `ContentSubmissionStagedAssetEntity` with those fields plus an auto-increment ObjectBox `id`. Keep it separate from `ContentSubmissionDraftEntity`, local runtime `Asset`, remote `SubmissionAsset`, and Admin models. A mapper is appropriate if required by current domain/data conventions; the technical entity ID need not leak into the domain model because `(clientSubmissionId, digest)` identifies the one allowed descriptor and the ID is used internally for explicit ordering.

Add `ContentSubmissionStagedAssetRepository` under the existing domain repository boundary and one implementation under `data/repositories`. Its focused contract must support:

- reconcile-and-load for an optional active durable `clientSubmissionId`;
- acquire/stage one already size-validated local source using a caller-supplied SHA-1 digest;
- resolve a descriptor's absolute path under the configured staging root;
- remove one asset by active identity and digest;
- idempotently clear one session's descriptors/files/directory.

The implementation owns ObjectBox plus filesystem coordination. The ViewModel owns `ImagePicker`, size/capacity UX, the candidate SHA-1, Commands, session orchestration, runtime `Asset` creation, and notifications. Inject the interface into the ViewModel and register the implementation in `config/dependencies.dart` using the existing Provider pattern. Concretely, its synchronous constructor accepts `Logger`, `ObjectBox`, and an optional `Future<Directory> Function()` whose production default is the top-level `getApplicationSupportDirectory`; memoize the first returned directory future. Provider therefore remains synchronous, while real tests inject a callback returning their temporary support directory and ViewModel tests inject the interface fake. Do not access global/service-locator storage from the ViewModel.

Alternative considered: repository + filesystem service + manager + use case + coordinator. Rejected because one feature-specific implementation can own this cohesive local persistence responsibility and remains replaceable in tests.

Alternative considered: put descriptors or bytes inside the fixed draft entity. Rejected because file lifecycle and collection queries differ from form snapshots, bytes do not belong in ObjectBox, and embedding would complicate crash reconciliation.

### 6. Stage under Application Support with validated relative paths and digest filenames

Use the already available `getApplicationSupportDirectory()` and `path` package to define:

`<application-support>/content_submission/staged/<clientSubmissionId>/`

Persist paths relative to the `content_submission/staged` root, conceptually `<clientSubmissionId>/<sha1-digest>`. The final basename is the lowercase 40-hex SHA-1 digest without source-path material. This is compatible with current upload code: `CloudinaryMultipartWriter` sends every file as `application/octet-stream` regardless of filename extension, and response `format`—not the local extension—produces the remote `SubmissionAsset.mimeType`. A no-extension digest name also makes interrupted final files self-describing for reconstruction. Temporary regular files use the exact basename pattern `.<digest>.<random-hex>.tmp`, with the random suffix used only for collision avoidance and never persisted as identity. Pin this decision with a `CloudinaryUploadClientImpl` test using the existing fake preparation/server harness and a real extensionless digest-named staged file; require the actual multipart client path to transmit the basename/bytes and complete successfully. If that concrete client-boundary test fails, stop and update the OpenSpec rather than improvising an extension convention.

Validate all session IDs and digest-derived names before path construction. During restore/reconcile, normalize and verify that every descriptor path is exactly the expected relative path and resolves inside the staging root; malformed or traversal-like state is never exposed or deleted through an escaped path. Enumerate only immediate children with `followLinks: false`, reject symlinked session directories and staged files, and delete a symlink entry itself rather than following its target. Descriptor cleanup operates by ObjectBox technical ID and never dereferences a malformed stored path. Picker paths are used only as read sources before ownership transfer.

Alternative considered: cache/temp/documents/public storage. Rejected because cache/temp are evictable, public storage exposes internal ownership, and Application Support matches private non-user-document state while already being supported by project dependencies.

Alternative considered: random final filenames plus stored source names. Rejected because deterministic digest names simplify idempotent retry and descriptor reconstruction while source names add unneeded metadata.

### 7. Keep SHA-1 in the ViewModel pipeline and make repository commit idempotent

The common candidate routine accepts picker or recovered `XFile`s and performs current-capacity/10 MiB validation, streams SHA-1, checks `_assets` for the active session, then asks the staged repository to acquire the source. It creates `Asset(file: XFile(stagedAbsolutePath), digest: digest)` only after the repository returns a committed descriptor and final path. The runtime record shape remains unchanged. Because the picker-owned file can change between the first digest pass and acquisition, the repository also hashes the completed temporary copy and requires it to equal the supplied digest before final rename; this integrity check does not transfer the candidate-deduplication policy out of the ViewModel.

The repository also converges retries by querying `(clientSubmissionId, digest)` and using the deterministic final path. If an equivalent descriptor/final pair already exists, it returns the existing descriptor rather than adding another. If a final file exists without a descriptor, it persists one. This second line of defense handles process/interruption windows; the ViewModel's digest list preserves current soft duplicate semantics and avoids unnecessary copies.

Do not replace SHA-1 with Cloudinary's SHA-256. SHA-1 remains local accidental duplicate detection; SHA-256 remains a remote upload/public-ID concern. Identical bytes in different session directories are independent ownership and are not deduplicated across sessions.

### 8. Commit files as temp-copy, close, final-rename, descriptor

For an accepted candidate:

1. ensure the validated active session directory exists;
2. copy/stream source bytes to a uniquely named temporary file inside that directory;
3. await and close the write;
4. read the closed temporary file's length and reject/delete it if it exceeds `kCloudinaryMaxUploadBytes` after acquisition;
5. SHA-1 the closed temporary copy and reject/delete it if its bytes no longer match the caller-supplied digest;
6. rename to the deterministic final digest basename (or discard the temp if an idempotent final already exists and its bytes verify against that digest and size limit);
7. persist exactly one descriptor pointing to the final relative path;
8. return the committed descriptor/path for runtime publication.

Never persist a temp path. A copy/rename failure removes its own temp on a best-effort basis and returns `Result.error`. A descriptor failure after final rename also returns error but intentionally leaves the valid final file: retry or next initialization reconstructs the descriptor. Earlier candidates already committed in the batch remain committed. This is sufficient crash tolerance without a journal or all-or-nothing transaction.

Alternative considered: persist descriptor first and then copy. Rejected because a crash would make an apparently valid descriptor point to a partial/missing file.

Alternative considered: coordinate ObjectBox/filesystem through a transaction state machine. Rejected because deterministic final names and reconciliation cover the finite crash windows with much less permanent complexity.

### 9. Reconcile active state and delete every non-active session as orphan state

`reconcileAndLoad(activeClientSubmissionId)` is the initialization write/read boundary:

- Query active descriptors with an explicit filter and `.order(ContentSubmissionStagedAssetEntity_.id)`; never depend on ObjectBox's implicit result order.
- Remove stale temp files in the active directory.
- For each active descriptor in ID order, accept only its expected validated regular final path whose bytes hash to the basename digest. If final is missing or mismatched, delete the stale descriptor and omit the broken/untrusted file from restoration.
- When duplicate rows exist for one active digest, retain the lowest auto-ID descriptor that passes validation and delete every later duplicate by technical ID.
- Scan valid deterministic regular final basenames in the active directory, sort descriptor-less candidates lexicographically by digest before any inserts, then hash each file and reconstruct a descriptor only when bytes match its basename and remain within the size limit. Insert exactly one descriptor per candidate in that sorted order and include it in deterministic post-query ID order; delete mismatched, oversized, or malformed in-root files rather than adopting them.
- Delete malformed descriptor rows by technical ID without resolving their stored path. Enumerate immediate root children without following links: valid non-active UUID directories are cleared as orphan sessions, malformed directories are removed as in-root orphan entries, and symlinks are unlinked rather than traversed.
- When there is no successfully loaded durable active identity, restore nothing and clean every staged descriptor/session directory as orphan state. Never adopt an old directory into the ViewModel's newly generated draft ID.

The repository may log path-free diagnostics for stale/malformed cleanup. Reconciliation treats expected inconsistency as repair, not a fatal error. True ObjectBox/filesystem failures return `Result.error`. Initialization still waits for that result before completing its barrier; on a hard reconciliation failure it exposes no partially restored assets, stores the error, marks staged state unavailable, completes the barrier, and transitions the existing two-state UI to ready rather than adding error UX. Recovery then drops its response best-effort. Before a later normal add opens the picker, its serialized pre-picker phase retries reconciliation for the now-durable active ID and returns the reconciliation error without picker invocation if state remains unavailable. Clear remains available through draft-first, best-effort old-session cleanup; removal cannot be offered because no runtime assets were restored. This is the only retry behavior—do not leave it optional or invent another initialization state.

`_submit()` also awaits the shared initialization future, then rejects before form validation, Cloudinary work, or final remote submission whenever staged state is unavailable or quarantined. This includes hard reconciliation/path-resolution errors and restored descriptor counts above the maximum. It does not reconcile, mutate, clean staged state, or roll back Cloudinary work; it preserves the staged descriptors/files for recovery, retry, or explicit discard.

Alternative considered: delete every descriptor-less final file. Rejected because that discards a valid asset from the rename-to-descriptor crash window.

Alternative considered: leave foreign sessions indefinitely. Rejected because only one draft can be active, so foreign state is unambiguously orphaned after durable identity resolution and would otherwise accumulate private user media.

### 10. Make initialization and lost-data processing share an explicit barrier

Create one memoized initialization future owned by the ViewModel. Its body loads the draft, determines whether a persisted active ID was successfully restored, runs staged reconciliation/load for that ID (or orphan cleanup with no active ID), reconstructs `_assets` from resolved final paths, and only then completes the barrier, sets `loadState` ready, and notifies. Repeated `initialize()` calls return the same future and perform no second load/reconciliation. Valid loaded draft establishes both `_hasDurableCheckpoint = true` and the recovery-eligible ID. `Success(null)` or draft-load failure keeps the fresh ID non-durable and supplies no recovery ownership. Every local session mutation/checkpoint awaits this future before arbitration, eliminating late-load overwrite races.

`_retrieveLostAssets()` retains current platform guards and calls `ImagePicker.retrieveLostData()` immediately when Android triggers it. It stores the returned response in that async invocation, then awaits the initialization future. Initialization records a recovery-eligible identity only when a valid persisted draft and trustworthy staged state were restored. Recovery captures that identity after the barrier, enters lifecycle arbitration, and compares it with the current active ID before touching candidates; clear rotation therefore makes the response stale. Only on equality does it prioritize non-null `response.files` (without retaining the current `response.file != null` gate), fall back to the single `response.file` when needed, and route the files through the common candidate routine. Capacity and duplicate checks therefore see restored assets.

The Android platform call remains before waiting for initialization, including when it throws. Every Android recovery exit starts and awaits the shared initialization future after that attempt, so a direct recovery call cannot leave draft loading, orphan reconciliation, the barrier, or `loadState` pending. A thrown or response-level plugin error remains a non-actionable recovery success after initialization completes.

If no valid persisted draft was restored, or reconciliation did not establish trustworthy active staged state, recovered files are logged/dropped best-effort and never attached to the fresh ID. Empty responses and plugin errors remain non-actionable successes and never delete valid staged assets. `ContentSubmissionScreen.initState()` may keep its existing early trigger; correctness no longer depends on screen timing.

Alternative considered: delay the `retrieveLostData()` platform call until initialization. Rejected because image_picker recommends startup recovery and the response should be acquired before later lifecycle activity can obscure it.

Alternative considered: let recovery checkpoint a fresh ID. Rejected because recovered picker bytes belong to an earlier process/session and cannot safely be reassigned when no matching durable draft was restored.

### 11. Remove persistently and clear draft-first without sacrificing recoverability

`removeAssetAt` synchronously captures the selected runtime asset's digest and the current `clientSubmissionId` before waiting for lifecycle arbitration. Inside the boundary it compares the captured ID with the active ID and confirms that the captured digest is still present; a mismatch is stale work and completes without touching the new session. It then asks the repository to remove that identity+digest and removes the matching runtime entry (not whichever item later occupies the original index) before notifying on success. The repository removes the descriptor first and treats a missing file as success. If deleting an existing file fails after descriptor removal, it returns an error and leaves runtime state unchanged; retry can derive and remove the same deterministic path even without a descriptor, while process-restart reconciliation can reconstruct the descriptor if the final file still exists. This favors recoverability over pretending the two deletions are atomic.

For full discard, keep Subplan 1's hard boundary: call `draftRepository.clearDraft()` before destructive staged cleanup. If draft clear fails, do not clean staged state or rotate. After it succeeds, call `clearSession(oldId)` while still under arbitration and before exposing a new identity. Because the draft is already absent, a cleanup failure cannot safely preserve the old session as active; finish rotation, return discard success, and leave residue foreign to the new ID so the next reconciliation retries orphan cleanup. Log the cleanup failure without exposing file paths. This ordering avoids the worse alternative where assets are deleted but a failed draft clear leaves a supposedly recoverable draft with missing attachments.

`clearSession(clientSubmissionId)` is the finalization seam: delete matching descriptors, final files, temp files, and the per-session directory idempotently. This subplan uses it through the existing `clear` Command and tests it directly. Repository inspection shows that `ContentSubmissionProgressScreen` already invokes `clear` after a completed submit when leaving the progress route, so that existing path will also clean staged state; this is preservation of the current clear-based session retirement, not a new `_submit()` success hook. Do not add another success callback or redesign definitive finalization here. A later hardening subplan may replace/refine the existing progress-route retirement contract using the same primitive.

Alternative considered: staged cleanup before draft clear. Rejected because a draft-clear error would leave the persisted draft alive after its attachments were destroyed, violating Subplan 1 recoverability.

Alternative considered: deletion tombstones. Rejected because deterministic paths, idempotent retry, descriptor reconstruction, and orphan reconciliation cover the required partial failures.

### 12. Keep submit remote behavior unchanged and prove the staged file is the source

After staging/restoration, every `_assets` entry contains `XFile(stagedAbsolutePath)`, so the existing `_submit()` loop continues to call `uploadImageTask(File(entry.file.path))` sequentially without a production API change. `_submit()` itself performs no local deletion on upload error, partial upload error, final `ContentSubmissionRepository.upload` error, or success. Retry iterates the same staged paths. Only the already-existing post-success progress-route `clear` retirement can clean the completed session; Cloudinary's existing SHA-256 preparation/reuse and no-rollback behavior remain untouched.

Tests must capture the `File` passed to `FakeContentSubmissionRepository.uploadImageTask`, not merely inspect repository state. Stage from a real temporary source, assert runtime path is under the staged root and differs from source, remove the original source, run submit, and prove the upload fake reads/captures the staged path. Repeat after a controlled Cloudinary or final-submit failure to prove retry uses the same durable file. Assert no Cloudinary delete/rollback call or new API is introduced.

Alternative considered: copy again during submit or store picker and staged paths together. Rejected because ownership transfer should happen once and all consumers must converge on one durable source.

### 13. Treat ObjectBox generation and tests as persistence contracts

Generate the new entity through the installed ObjectBox/build_runner workflow; never edit `lib/generated/objectbox.g.dart` or `lib/generated/objectbox-model.json` manually. Prefer a verified `--build-filter` that emits both files, otherwise run the repository's normal `dart run build_runner build --delete-conflicting-outputs` and reject unrelated Envied/dart_mappable drift. Preserve every existing entity/property ID and UID; add only the new entity/properties assigned by the generator. Do not add a `position` property: ascending auto-ID query order is the required insertion order.

Repository and reconciliation tests use `test/support/objectbox_test_store.dart` with a real temporary ObjectBox Store plus a separate temporary staging root. ViewModel tests extend shared fakes/gates in `test/support` rather than mocking ObjectBox query chains or duplicating filesystem harnesses. Race tests control checkpoints, picker completion, initialization, staging, removal, recovery, and clear with Completers so they prove ordering without sleeps. Include source mutation between digest and copy, copied/final hash mismatch, standalone checkpoint versus clear, deferred recovery versus clear, stale removal versus rotation, deterministic duplicate-row winner, malformed directory/symlink cleanup, and reconciliation-error retry behavior.

## Risks / Trade-offs

- [A fresh equal draft skips its first physical save] → Gate checkpoint equality optimization with `_hasDurableCheckpoint` and test the initial empty draft, loaded draft, successful save, failed save, and post-clear identity independently.
- [Asset/checkpoint/clear starts while a persisted draft is loading] → Memoize initialization and make every local session mutation/checkpoint await it before arbitration; recovery alone retrieves platform data first, then waits.
- [A standalone checkpoint resurrects a cleared identity] → Serialize public checkpoint calls with clear and capture the snapshot only after entering arbitration; use an internal already-locked checkpoint helper for addAsset.
- [The local queue deadlocks or remains poisoned after an exception] → Keep it private and minimal, release/advance its tail in a guaranteed completion path, and test a failing operation followed by a successful different Command.
- [Clear is blocked for the duration of picker UI] → Split add into pre/post serialized phases and put only `pickMultipleMedia()` between them.
- [Stale picker work leaks across identity rotation] → Capture before picker, compare inside the commit section before touching candidates, and race a gated picker against successful clear.
- [Descriptor/path corruption escapes the private root] → Construct paths only from validated UUID/digest values, persist generated relative paths, and normalize/contain-check stored paths before restore or deletion.
- [Process death occurs between final rename and descriptor write] → Keep digest-derived final files and reconstruct missing active descriptors during initialization.
- [Picker source changes after candidate digest] → Hash the completed temporary copy and require equality before final rename; hash descriptor-less finals before reconstructing descriptors.
- [Picker source grows after the first size check] → Recheck the completed temporary file length before final rename and reject oversized descriptor-less finals during reconciliation.
- [Descriptor exists after file loss] → Remove it during reconciliation and never expose a broken runtime `Asset`.
- [Duplicate descriptors or recovered duplicates inflate the limit] → Converge by session+digest in repository staging/reconciliation and deduplicate runtime assets against restored digests.
- [Reconstructed descriptors receive later IDs] → Sort missing-descriptor finals by digest before insertion, then accept their new IDs as the durable order; process death erased original uncommitted descriptor order while ordinary committed insertion order remains explicit and stable.
- [Draft load/reconciliation failure misowns Android files] → Separate early platform acquisition from processing and require a successfully restored durable identity plus completed staged reconciliation before recovery commits.
- [Unavailable/quarantined staged state is submitted as an empty list] → Make submit await initialization and reject unavailable state before any upload or final remote call; preserve durable staged state unchanged.
- [Recovery plugin throw skips initialization] → Start and await shared initialization after every Android platform-attempt exit, while retaining the platform-first ordering.
- [Disposed ViewModel publishes post-async asset changes] → Treat disposal as terminal for candidate/removal runtime mutation and notification, preserving only already committed durable state.
- [Clear rotates after lost-data restoration but before processing] → Capture the recovery-eligible restored ID after the barrier and compare it inside lifecycle arbitration.
- [Staged cleanup fails after draft deletion] → Rotate rather than revive a non-durable session; keep residue foreign and retry through orphan reconciliation.
- [Removal partially deletes descriptor/file] → Derive file location from validated identity+digest, keep runtime state on hard failure, allow idempotent retry, and let reconciliation repair a retained final file.
- [Queued index removal targets a replacement session/list item] → Capture identity+digest before waiting, revalidate both inside arbitration, and remove by digest rather than by the stale index.
- [Extensionless staged names affect upload] → Current multipart code sends `application/octet-stream` independently of extension; prove the actual `CloudinaryUploadClientImpl` path with the existing fake server/preparation harness and a digest-only real file, and stop to revise the OpenSpec if that integration test fails.
- [Generated ObjectBox output drifts] → Generate from annotated source, inspect complete diff and IDs/UIDs, and reject unrelated generator changes.
- [Repository-wide analysis is already non-zero] → Require zero new/in-scope targeted diagnostics and compare full output to the recorded 189-diagnostic baseline; do not clean unrelated lints.
- [The cleanup seam gains competing success callers] → Reuse only the existing clear-based progress-route retirement, keep `_submit()` free of cleanup, and leave any finalization redesign to a later approved subplan.

## Migration Plan

1. Revalidate that Subplan 1 remains implemented at the current checkout and keep its single-draft identity/checkpoint/clear contracts intact except for durable-existence-aware clean checkpointing.
2. Add the minimal staged model/entity/mapper/repository contract and real filesystem/ObjectBox implementation, wire Provider DI, and regenerate ObjectBox output from source.
3. Prove repository staging, deterministic naming, relative-path containment, explicit ordering, reconciliation, removal, session cleanup, and orphan cleanup against real temporary storage.
4. Add durable-existence tracking and the private lifecycle queue; split add around the external picker, reject stale session results, and route normal candidates through durable staging.
5. Coordinate initialization/restoration and early Android lost-data acquisition with the completion barrier, then persist removal and draft-first clear/session cleanup.
6. Extend remote-failure tests to prove the existing submit path reads staged files and preserves them across initial failure and retry; do not add remote cleanup.
7. Run focused and full tests, baseline-aware targeted and repository analysis, format checks, generated-diff/ID review, strict OpenSpec validation, and an independent semantic review of persistence/lifecycle behavior.

The generated ObjectBox schema is additive. No Supabase/backend deployment or data migration is required. On application upgrade, initialization reconciles existing empty staged state or safely removes orphan files/descriptors. Rollback after a device opens the additive ObjectBox schema must preserve compatible generated model history rather than restoring older model metadata blindly; stop and validate ObjectBox downgrade behavior if release tooling cannot retain that history.

This migration completes Subplan 2 only. It preserves the existing post-success clear-based retirement, but any definitive finalization redesign and whole-feature release readiness remain owned by later approved Content Submission Hardening work.
