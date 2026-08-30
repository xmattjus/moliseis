## Context

See `proposal.md` for motivation and `specs/admin-submission-editor/spec.md` for the required behavior.

This design was revalidated on 2026-08-30 against current repository HEAD `a12be30107dc767f64c73a91aa35992b6c152cc0` and the current working tree. Unrelated modifications to `analysis_options.yaml`, `pubspec.yaml`, and `.agents/skills/strict-conventional-commit/` are outside this change and must be preserved.

Verified repository facts:

- `AdminSubmissionEditorViewModel.submissionId` is a constructor-owned `final int?`; `isEditMode` is derived directly from it.
- `_save()` calls `repository.create(input)` when `submissionId == null` or `repository.update(submissionId, input)` otherwise, but maps either success only to `_isDirty = false`, discarding both returned `AdminSubmission` values.
- Moderation guards require a non-null submission identifier, `_hasLoadedDetail == true`, a clean editor, and pending status.
- `_addAsset()` rejects create mode, then uses the existing picker, `ContentSubmissionRepository.uploadImageTask`, and `AdminContentSubmissionRepository.addAsset` sequence for persisted pending submissions.
- `AdminSubmissionEditorScreen` listens to successful Save and calls `context.pop(true)`. It also carries `_saveCompletedWhileStatusDialogOpen` specifically to defer that pop while a moderation confirmation dialog is open.
- The photo section renders only when `viewModel.isEditMode && viewModel.hasLoadedDetail`.
- Existing widget tests explicitly assert that `Foto` is absent in create mode.
- The app-bar title, photo/status/contributor sections, and Save label read `isEditMode` inside the editor's existing `ListenableBuilder`, so they can react to an in-place identity transition. The city/name `TextFormField`s use `initialValue`, but the current create path echoes the submitted editable values; create adoption does not require replacing those active field values.
- Production has one editor-opening method in `AdminDashboardScreen`, with create and edit route branches. It currently reloads only when the editor route returns `true`.
- `AdminContentSubmissionRepository.create` returns a complete authoritative `AdminSubmission`. The create Edge Function response includes the new identifier, pending status, contributor metadata, timestamps, promotion fields, and an empty asset list, so no `getById` reload is needed.
- Admin create has no client idempotency key or equivalent exactly-once contract: the repository sends only `operation: create` plus input, the store performs a plain insert, and an invocation error carries no reconciliation identity. If the insert commits but the successful response is lost, the live editor cannot know the persisted identifier and a later retry may create a duplicate submission.
- The update Edge Function also serializes an empty asset list because it does not reload associations. Therefore an update response must not be adopted wholesale in a way that clears the ViewModel's confirmed assets.
- Existing asset addition is `ContentSubmissionRepository.uploadImageTask(File)` followed by `AdminContentSubmissionRepository.addAsset`. The latter uses `add_submission_assets`, which locks the submission row and authoritatively enforces pending status and a maximum of five associations.
- Cloudinary uploads use a deterministic SHA-256 public ID and duplicate lookup, but `add_submission_assets` has no URL uniqueness or idempotency key. Upload retry can avoid retransferring bytes; backend association retry is not exactly-once if a response is lost after commit.
- A privileged Cloudinary destroy helper exists for the unrelated `import-external-events` Edge Function. It is not available through the Flutter/admin repository path and is not a reusable cleanup mechanism for this change.
- The public contribution flow already demonstrates the useful minimal pattern of holding selected local images before persistence and uploading them sequentially during submit. This change should reuse that pattern conceptually without creating a generic shared abstraction unless the codebase now contains a third concrete use case.
- `AdminSubmissionEditorViewModel.dispose()` already marks the ViewModel disposed and cancels its active `ImageUploadTask`, but create/update repository futures have no cancellation contract. A remote write may therefore complete after disposal; staged Save work must prevent result adoption and all other state mutation after disposal rather than assuming the remote operation was cancelled.
- Current working-tree `flutter analyze` reports 20 pre-existing informational diagnostics, none in the planned admin editor/dashboard source or focused test files.

The verified implementation boundary is frontend-only. If implementation discovers that the specified behavior requires a database, Edge Function, Cloudinary contract, domain repository API, dependency, or generated-code change, stop and update the OpenSpec artifacts instead of expanding scope.

## Goals / Non-Goals

**Goals:**

- Make Save a persistence action rather than a navigation action.
- Let a new route-scoped editor become a persisted pending editor in place after create-result adoption.
- Allow local images to be chosen before initial persistence without uploading early.
- Persist staged images only after a successful create response yields an identity that the live editor adopts.
- Preserve safe retry semantics when a live editor adopts a create result but later image work partially fails.
- Keep existing persisted-edit image behavior, backend asset invariants, moderation guards, and publication-readiness semantics intact.
- Preserve active-upload cancellation and disposed-ViewModel safety for the new staged Save path.
- Keep the implementation small and aligned with existing Flutter patterns.

**Non-Goals:**

- Change database schema, migrations, `add_submission_assets`, promotion RPCs, or any Supabase Edge Function contract.
- Change Cloudinary signing, upload security, content-hash policy, or storage provider behavior.
- Create a distributed transaction or rollback protocol across Cloudinary and Supabase.
- Claim exactly-once submission creation across an ambiguous create response; the current create path has no idempotency or reconciliation contract.
- Claim exactly-once backend asset association across an ambiguous transport failure; the current RPC has no idempotency contract.
- Stage newly selected images for ordinary already-persisted edit sessions; those continue uploading immediately.
- Persist staged local-image state across route destruction, process death, app restart, deep-link reconstruction, or navigation away.
- Replace the editor route after create with an ID-bearing route or force a second detail fetch solely to enter persisted mode.
- Introduce a generic asset-staging service, state-machine framework, navigation result abstraction, or shared editor base class.
- Change the five-image domain limit or pending-only asset mutation rule.
- Change category readiness, event-time semantics, geolocation validation, rejection rules, or promotion behavior except that existing actions become available without reopening after Save.
- Clean up unrelated lints, tests, navigation patterns, or repository architecture.

## Decisions

### 1. Make the persisted identifier mutable inside the route-scoped ViewModel

Replace the constructor-owned immutable persistence identity with private route-scoped state that can transition once from null to the identifier returned by create. Keep the existing read-only `submissionId` surface so callers do not gain mutation access.

The lifecycle states and transition boundary are:

```text
NEW / no persisted identity adopted
  | successful create response received while live
  | result adopted into editor state
  v
ADOPTED PERSISTED SUBMISSION
  | future Save
  v
UPDATE WHEN FIELDS ARE DIRTY / STAGED PERSISTENCE ONLY

Any state -- route disposal --> DISPOSED / no later result adoption or mutation
```

A remote insert commit is not this transition. The live-session no-more-create guarantee begins only after the returned identity has been adopted. Once adopted, the editor never clears that identity or returns to the create path for the remainder of that live session.

`isEditMode` continues to mean "this editor now represents a persisted submission" and should derive from the mutable internal identifier. Do not create a parallel `wasCreated`, `persistedSubmissionId`, or second mode enum unless current code proves one is necessary.

Rationale: the existing ViewModel already owns all other route-scoped lifecycle state. Moving to a new ViewModel or replacing the route after create would add navigation complexity and risk losing in-memory state for no domain benefit.

### 2. Adopt the authoritative create result instead of issuing an immediate reload

The create repository call already returns the authoritative row. After a successful response, first confirm the ViewModel is still live, then synchronously adopt its identifier, returned category, pending status, promotion, contributor metadata, timestamps, assets, and loaded-detail state before starting any staged image work. Reuse a narrow internal application helper with normal detail hydration where that removes duplication, while making its create/load differences explicit. A remotely committed insert whose response is not observed, or whose result arrives after disposal, is not adopted state.

The current backend returns the editable create values that were submitted (with the existing null-category-to-`unknown` normalization already performed by Save). Keep the active editable projections semantically aligned without rebuilding the route. Do not issue `getById` merely to enter persisted mode.

Do not apply the update response through a helper that replaces `_assets`: the current update response carries `assets: []` because the handler does not query associations. A successful update may mark field changes persisted and apply safe scalar metadata if useful, but it must preserve the ViewModel's confirmed asset list.

Rationale: an observed create response is authoritative and contains the new identity. A second detail request after adoption increases latency and creates an avoidable failure boundary, but the response itself remains the only identity handoff under the current contract.

### 3. Model field dirtiness separately from staged persistence work

Replace the single manually toggled meaning of `_isDirty` with one field-change flag and a derived public dirty/persistence-incomplete value:

`isDirty = hasUnsavedFieldChanges || stagedImages.isNotEmpty`

Field setters mark only the field flag. Detail hydration clears it. Adoption of a successful create response, or observation of a successful update response, clears it immediately even when subsequent image work fails; staged entries then keep the editor dirty and moderation blocked. Removing the final staged image restores clean state only when no field changes remain.

Save remains callable for a new valid draft and whenever staged work remains. A retry after create-result adoption with clean fields skips an unnecessary update and resumes staged persistence against the adopted identifier. If the administrator changes fields after partial image failure, retry updates those fields first and then resumes images.

Rationale: field persistence and asset persistence have different failure boundaries. Derivation preserves an adopted create result while also preventing staged work from being presented as clean.

### 4. Treat staged images as route-scoped local selections, not persisted assets

Use one private admin-editor staged entry containing the selected local file and an optional successful `SubmissionAsset` upload result. The optional upload result is necessary only for retrying backend association without uploading the same bytes again after an association failure. Do not add this type to the domain layer or create a generic staging service.

Expose only the immutable local-preview/removal data the screen needs. Capacity is based on `persisted assets + staged entries`, capped by `kMaximumSubmissionAssetCount` in the ViewModel and reflected by the UI. The RPC remains the authority for persisted capacity and concurrency.

Selecting an image while `submissionId == null` only stages it. Selecting an image after the editor is persisted keeps today's immediate `_addAsset()` behavior. The implementation may split "pick image" from "persist picked image" internally to avoid duplicating picker code.

Removing a staged entry is local-only and never calls `deleteAsset`; persisted assets keep their existing backend deletion path. Preserve selection order in the staged collection.

Rationale: this directly matches the requested workflow and the existing public-submission precedent without broadening normal asset editing semantics.

### 5. Make Save the orchestration boundary; do not recurse through Commands

Preserve the existing field validation and input construction. Save then has two persistence phases:

1. Persist submission fields:
   - if no identifier has been adopted, invoke create for that Save; after a successful response, check that the editor is still live and then adopt the returned persisted state;
   - otherwise call update only when `hasUnsavedFieldChanges` is true;
   - if the identifier exists and fields are already persisted, skip the field write.
2. Persist every remaining staged entry sequentially in selection order:
   - if it has no retained upload result, create/await `uploadImageTask` and retain the successful `SubmissionAsset` before association;
   - call admin `addAsset` with the persisted identifier and retained upload result;
   - only after confirmed association, append the returned `AdminSubmissionAsset` and remove that staged entry.

Use an internal helper that accepts a staged entry; do not invoke `addAsset.execute()` from inside Save. The public command launches the picker and its existing persisted-mode guard rejects work while `save.running`, so command recursion would conflict with mutual exclusion and repeat selection.

Do not upload before the successful create response has been adopted by the live editor, and do not parallelize. Sequential work makes selection order, retained progress, capacity, cancellation, and failure recovery deterministic and mirrors the public flow.

Save is successful/clean only when the requested field persistence has succeeded and no staged images remain. A partial image failure returns an error from Save while preserving the adopted persisted identity and confirmed assets.

Rationale: this gives the user one Save action while respecting the backend requirement that assets belong to an existing submission.

### 6. Make partial failure monotonic and retryable

The critical live-session recovery boundary is successful create-result adoption, not a remote commit that may be unknown to the client. After a live editor adopts the result, it is permanently a persisted editor for the remainder of that route session. Never clear the adopted identifier or pretend create rolled back because a later upload/RPC failed.

If the client observes a create error before identity adoption, leave the field draft and staged collection unchanged, start no upload, and keep the editor in no-adopted-identity mode. A later Save may invoke create again. If the original insert actually committed but its response was lost, that retry may create a duplicate submission because the request has no idempotency key and the client has no reconciliation lookup. Exactly-once creation across this ambiguity requires a backend contract change and is explicitly out of scope.

For sequential staged assets:

- completed image associations remain in `_assets` and are removed from staging;
- an upload failure leaves the entry staged with no upload result;
- an association failure leaves the entry staged with its successful upload result;
- images after it remain staged because their work has not started;
- Save reports an error and the editor remains persistence-incomplete/dirty;
- moderation remains blocked by the existing clean-state guard;
- the next Save uses the adopted identifier, skips already-confirmed entries, and must not call create again in that live editor session.

If Cloudinary upload succeeds but `addAsset` fails, retain the `SubmissionAsset` in the staged entry and retry association directly; do not invoke Cloudinary upload again during the route session. Do not call the privileged destroy helper or add a cleanup endpoint. If the association request committed but its response was lost, the current non-idempotent RPC cannot prove exactly-once association and a retry may create a duplicate row; this change guarantees no repeat of confirmed associations, not exactly-once recovery from an ambiguous response. A backend idempotency requirement would be a material scope change and requires stopping to update OpenSpec.

Check `_disposed` after every create/update/upload/association await and before starting the next phase. Disposal cancels the active upload best-effort, starts no later staged entry or association, and suppresses every later local mutation or result adoption. Already-started create, update, or association operations have no cancellation contract and may finish remotely; ignore their responses locally and do not attempt rollback. In particular, if create commits but the editor is disposed before identity adoption, the route-scoped state may never retain that identifier and no staged upload may follow.

Rationale: backend create and external upload cannot be made atomic with a small UI change. Monotonic progress after identity adoption avoids repeated create calls from the same live editor state and keeps recoverable asset progress understandable without claiming exactly-once remote effects before adoption.

### 7. Keep persisted-edit asset addition immediate

Do not convert every image action into deferred Save semantics. Once an editor is persisted, the existing add button continues to pick, upload, and associate immediately, subject to current pending-only, capacity, and mutual-exclusion guards.

Images staged before create are a special bridge across the missing-identifier boundary. Once persisted successfully, they become ordinary `_assets`.

Rationale: broad staging would change established asset UX, dirty semantics, deletion semantics, error handling, and potentially Cloudinary lifecycle for no requirement-driven benefit.

### 8. Remove Save-driven route popping and obsolete dialog coordination

`_handleSaveCompleted` no longer calls `context.pop(true)` on success. Remove `_saveCompletedWhileStatusDialogOpen`, `_statusDialogOpen`, and the deferred-pop branches whose only purpose is to preserve that old behavior. Keep the listener only for existing Save error mapping unless it still has another concrete responsibility.

A successful Save may provide lightweight success feedback only if consistent with current UX and tests; no new dialog or forced navigation is required. Error mapping remains unchanged.

Reject and Promote retain their current post-success `context.pop(true)` behavior. The requested behavior specifically changes Save so that Publish/Reject can be invoked immediately afterward in the same editor; it does not redesign what happens after moderation succeeds.

If a Save completes while a confirmation dialog is already open, closing or confirming that dialog must not execute a deferred Save pop. The existing command/ViewModel guards remain the authority when the confirmation resumes, so moderation still cannot bypass dirty or running-state checks.

Rationale: isolate the behavioral change to Save and remove state that becomes dead once Save is no longer a navigation trigger.

### 9. Make the existing screen react to the in-place mode transition

Render the photo section in new mode as well as persisted loaded mode. It should communicate a combined `current / 5` capacity and visually distinguish enough state for the administrator to understand which selected images are not yet persisted.

For staged images, use local file rendering and a local remove action with no confirmation requirement unless the current UI pattern strongly benefits from one. Persisted assets keep `AppNetworkImage` and the existing backend delete confirmation/action.

Disable conflicting actions while Save/image work is running according to existing command mutual-exclusion rules. Do not allow Publish/Reject while staged images remain or Save is in a partial-error state; this should fall out of the clean/persistence-incomplete guard rather than a one-off button condition.

The existing `ListenableBuilder` already recomputes title, contributor section, status controls, photo behavior, and Save label from ViewModel state. Preserve that reactive structure and prove a mounted create screen changes from “Nuovo/Crea” presentation to persisted “Modifica/Salva” presentation after create. The current backend echoes city/name/description/location input, so no route key or broad controller rewrite is needed. If implementation reveals a returned editable value that materially differs and is stale in an `initialValue`-backed field, stop and update this design rather than introducing route replacement.

For partial image failure, existing Save error feedback may remain generic, but the staged preview and dirty/readiness copy must continue to communicate that persistence is incomplete. Do not add a new modal workflow.

Rationale: one section avoids duplicating UX and makes the transition from staged to persisted visible without introducing a separate upload wizard.

### 10. Refresh the dashboard whenever the editor route returns

At the sole dashboard `_openEditor` call site, await either create/edit route, check `mounted`, and execute the existing list load regardless of whether the route returned `true` or `null`.

Do not introduce a route-scoped `didPersistChanges` tracker, `PopScope` mutation protocol, or special handling for every possible back-navigation mechanism merely to avoid one harmless admin list read.

Keep any route-result behavior still needed by Promote/Reject compatible, but make dashboard freshness independent of Save returning `true`.

Rationale: KISS. The admin screen has low navigation frequency, while stale list state is a correctness problem.

### 11. Preserve existing authoritative boundaries

No change may weaken:

- pending-only editing/asset mutation;
- max-five persisted asset enforcement;
- category publication readiness;
- event temporal validation;
- coordinate validation;
- moderation mutual exclusion;
- backend status-transition authority;
- existing repository/API error mapping.

Client combined-count checks are proactive UX only. If concurrent remote mutation causes the RPC to reject an asset despite a local count below five, surface the existing error and preserve the remaining staged image for retry/correction rather than trying to bypass the RPC.

## Risks / Trade-offs

- [Create response is lost after the insert commits] → Keep the editor in no-adopted-identity mode because it has no trustworthy ID; retain draft/staging and accept that a later create retry may duplicate the remote submission. Exactly-once create requires a future backend-contract OpenSpec change.
- [Create result is adopted but Save reports an asset failure] → Keep the adopted identity, clear only field dirtiness before asset work, and leave staged previews visible and moderation blocked so later Save remains on the persisted path.
- [Dirty state diverges from staged work] → Derive public dirtiness from the field flag plus staged collection and test every create/update/removal/partial-failure transition.
- [Create/load adoption accidentally clears assets on update] → Reuse hydration narrowly and never replace confirmed assets from the current update response's empty asset envelope.
- [Cloudinary upload succeeds but association fails] → Retain the upload result and retry association without re-upload or rollback. Accept possible orphaned Cloudinary media and the current RPC's ambiguous-response duplicate risk; do not claim exactly-once association.
- [Disposal occurs during a multi-phase Save] → Check disposal after every await, cancel the active upload, and never adopt a result, start later work, or mutate disposed state; an already-started create/update/association may finish remotely without local retention or rollback.
- [In-place mode change leaves stale UI] → Exercise the mounted create-to-persisted transition in widget tests; current editable values are echoed, while title/status/contributor/photo/Save controls rebuild from ViewModel state.
- [Dashboard performs an extra read after a no-op visit] → Accept the small cost instead of building mutation-result plumbing.
- [Existing tests encode Save-pop and hidden-create-photo behavior] → Update those assertions deliberately while retaining Reject/Promote exit, final-status read-only, and immediate persisted-asset regressions.
- [Implementation HEAD changes a verified contract] → Re-audit the named paths and update OpenSpec instead of forcing this design onto changed code.

## Migration Plan

1. Implement the route-scoped ViewModel state/orchestration and focused tests without changing repository or backend contracts.
2. Update the editor screen and dashboard return handling, then run focused and repository-level verification from `tasks.md`.
3. Inspect the final diff for backend, dependency, generated, or unrelated drift before handoff.

This is a Flutter source-only behavior change with no data or deployment migration. Rollback restores the prior ViewModel/screen/dashboard behavior; no database or Cloudinary cleanup step is implied. OpenSpec must be updated before implementation if any backend contract change becomes necessary.
