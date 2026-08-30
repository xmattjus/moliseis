## 1. Re-verify the Implementation Boundary

- [x] 1.1 From implementation HEAD, re-read `AdminSubmissionEditorViewModel`, `AdminSubmissionEditorScreen`, `AdminDashboardScreen._openEditor`, both admin editor routes, `AdminContentSubmissionRepository`, `ContentSubmissionRepository.uploadImageTask`, `AdminSubmission`, `AdminSubmissionAsset`, `ImageUploadTask`, the public staging flow, and the focused tests/support; verify the contracts in `design.md` still hold and stop to update OpenSpec before source edits if an observed create response is no longer authoritative or any backend/repository/dependency/generated-code change appears necessary.
- [x] 1.2 Confirm from the current Edge Function/store/SQL that create still returns the persisted row but has no idempotency/reconciliation key, update still omits loaded asset associations, and `add_submission_assets` remains pending/max-five but non-idempotent; record both ambiguous-response limitations in implementation notes and make no backend edits.
- [x] 1.3 Run `openspec validate "improve-admin-submission-editor-workflow" --strict --no-interactive` and require a valid result before implementation.
- [x] 1.4 Before editing tests, inspect `test/support/fake_repositories.dart`, `fake_image_picker.dart`, and all affected consumers; reuse or minimally extend them for queued per-image results, call ordering, and pending work, verify shared defaults remain backward-compatible, and do not add duplicate local fakes/harnesses.
- [x] 1.5 Before source edits, require a clean implementation HEAD and capture analyzer baselines from that exact checkout: run repository-wide `flutter analyze` and record its exit plus error/warning/information counts, then run targeted `dart analyze` on the three expected ViewModel/screen/dashboard files, the four focused tests in task 6.2, and the two shared support files in task 1.4. Preserve the concrete planning snapshot in `design.md` for traceability, but use this implementation-HEAD capture—not a historical magic count—as the authoritative comparison baseline.

## 2. Add Persisted Identity, Staging, and Coherent Dirty State

- [x] 2.1 In `admin_submission_editor_view_model.dart`, keep persisted identity privately adoptable from a successful create response only while the ViewModel is live, and extend the narrow response-application boundary so load/create apply authoritative returned state while update applies authoritative editable/scalar state without replacing confirmed assets. Add a monotonically increasing authoritative editable-state revision that advances only when a load/create/update response is applied; verify ViewModel tests prove same-instance adoption, trimmed create/update city and name adoption, stable revision during ordinary setters and staged-only retries, and update responses cannot clear confirmed assets.
- [x] 2.2 Replace the single dirty meaning with a field-change flag plus derived `isDirty = field changes || staged entries`, using one private route-scoped staged entry that holds a local file and optional uploaded `SubmissionAsset`; verify tests cover field-only dirtiness, staged-only dirtiness, create/update clearing only field dirtiness, and final staged removal restoring clean state only when appropriate.
- [x] 2.3 Refactor the existing image-selection command so pre-create selection stages without upload/association, removal is local-only, selection order is preserved, and combined persisted-plus-staged capacity uses `kMaximumSubmissionAssetCount`; verify tests assert zero upload/delete/backend calls, restored capacity after removal, and proactive refusal of a sixth combined image.
- [x] 2.4 Preserve immediate picker/upload/`addAsset` behavior for an image selected after persisted identity exists, including pending/final-status and command-exclusion guards; verify existing persisted-add, accepted/rejected, capacity, and delete regressions remain green.

## 3. Orchestrate Save and Failure Recovery

- [x] 3.1 Change Save's field phase to invoke create when no identity has been adopted, adopt a successful response only while the ViewModel is live, update only when persisted fields are dirty, and skip a clean field write when only staged work remains; verify tests cover successful response adoption, create-without-images, authoritative metadata adoption, and a second dirty Save after adoption using update without invoking create again.
- [x] 3.2 Persist staged entries through an internal Save helper—not `addAsset.execute()`—using sequential selection order and `uploadImageTask -> admin addAsset`; retain each upload result before association and remove/append only after confirmed association, then verify ordered-call tests for one and multiple images and clean completion.
- [x] 3.3 Preserve monotonic state at every observable failure boundary: a create error before adoption keeps the editor in create mode with its draft/staging and starts no upload; upload failure after adoption keeps identity plus failed/unstarted staging; association failure keeps identity plus uploaded metadata; middle-item failure keeps confirmed earlier assets out of retry. Add the missing ordered regression in which the first staged image is confirmed, the second upload or association fails, and every later image remains unstarted; verify moderation remains blocked while staged work exists.
- [x] 3.4 Make retry after identity adoption use the adopted identifier, skip update when fields are clean, skip upload when a staged entry already has `SubmissionAsset`, and never reprocess confirmed associations; extend the middle-item regression to assert no additional create, upload, or association for the confirmed first image, direct retry from retained upload metadata after association failure, ordered processing of remaining entries, and eventual clean state.
- [x] 3.5 Preserve operation exclusion and disposal safety across create/update/upload/association awaits: after every await, prevent result adoption and state mutation when disposed, cancel the active staged upload, and start no later staged work or association. Verify focused tests cover disposal while create is pending (including no ID adoption and no upload/association afterward), pending upload, and pending association; allow already-started remote work to finish without adding rollback.
- [x] 3.6 Audit retry tests and fakes so none asserts exactly-once remote creation after an observed create error or exactly-once asset association after an ambiguous response. Model only the supported live-session guarantees after confirmed result adoption, and verify no idempotency key, reconciliation flow, compensating delete, or backend recovery contract is introduced.

## 4. Keep Save Open and Render the In-Place Transition

- [x] 4.1 In `admin_submission_editor_screen.dart`, remove successful-Save route popping, `_statusDialogOpen`, `_saveCompletedWhileStatusDialogOpen`, and deferred Save-pop branches while retaining Save error mapping and Promote/Reject success exits; verify widget tests cover update/create Save remaining open and confirmation completion/cancellation causing no deferred Save exit.
- [x] 4.2 Render one `Foto` section in new and loaded-persisted modes with combined count, local staged previews/removal, persisted network assets/deletion, and guarded add controls; retain the existing pre-create, removal, and capacity coverage, and add a widget regression that drives Save through a partial staged-image failure and proves failed/unstarted previews, combined count, persistence-incomplete copy, and disabled moderation remain visible.
- [x] 4.3 Key the existing `ContentSubmissionFields` subtree by the ViewModel's authoritative editable-state revision so successful create/update response application resynchronizes `initialValue`-backed city/name controls without replacing the route or remounting on ordinary edits. Extend the mounted transition tests with server-trimmed create and update values, visible authoritative field assertions, stable surrounding editor mode, confirmed-asset preservation, and existing `unknown`-category Publish/Reject behavior.
- [x] 4.4 Run the retained editor widget regressions for accepted/rejected read-only behavior, immediate persisted image addition, persisted deletion confirmation, Promote/Reject success navigation, operation locking, category readiness, event readiness, coordinates, and Save error mapping; require no unrelated behavior change.

## 5. Refresh the Dashboard on Editor Return

- [x] 5.1 In `admin_submissions_view_model.dart`, add a narrow post-editor reload operation that executes an idle `load` normally or coalesces one serialized follow-up repository list call when `load` is already running; the older response alone must not satisfy or overwrite the post-return refresh. Call it from the sole `AdminDashboardScreen._openEditor` path after either create/edit route returns and the mounted check. Verify ViewModel/dashboard tests hold an older list request pending across editor return, then prove a second request starts and its result becomes authoritative. Do not modify global `Command` semantics, run concurrent list requests, or add mutation-result tracking/navigation abstractions.
- [x] 5.2 Update dashboard/navigation coverage so a Save can remain in the editor and a later back or moderation-success return reloads the list; also verify an untouched no-result exit performs the accepted harmless reload.

## 6. Objective Verification and Scope Audit

- [x] 6.1 Run all materially affected tests for shared support and the repaired editor/dashboard behavior, then run `dart format` on every touched authored Dart file and `dart format --output=none --set-exit-if-changed` on the same paths; require affected consumers to pass and no formatting drift.
- [x] 6.2 Run `flutter test test/ui/admin/submissions/view_models/admin_submission_editor_view_model_test.dart test/ui/admin/submissions/view_models/admin_submissions_view_model_test.dart test/ui/admin/submissions/widgets/admin_submission_editor_screen_test.dart test/ui/admin/submissions/widgets/admin_dashboard_screen_test.dart test/routing/admin_route_test.dart` and require all focused lifecycle, authoritative synchronization, staging, retry, disposal, moderation, serialized refresh, and navigation regressions to pass.
- [x] 6.3 Run targeted `dart analyze` on the eleven planned authored source/test/support files: the original nine from task 1.5 plus `lib/ui/admin/submissions/view_models/admin_submissions_view_model.dart` and `test/ui/admin/submissions/view_models/admin_submissions_view_model_test.dart`. The two added files and the seven originally zero-clean files must remain zero-clean; `admin_submission_editor_view_model.dart` and `test/support/fake_repositories.dart` require no new or worsened diagnostics relative to their captured pre-existing information diagnostics. Then run repository-wide `flutter test` and `flutter analyze`; require all tests to pass and no new or worsened diagnostics attributable to this change relative to the clean implementation-HEAD repository baseline. Existing diagnostics from the repository lint configuration are outside this feature's cleanup scope: do not alter `analysis_options.yaml`, weaken rules, add ignores/suppressions merely to change the count, or refactor unrelated code to obtain repository-wide zero diagnostics.
- [x] 6.4 Run `git status --short`, `git diff --check`, and review the full implementation diff; confirm unrelated pre-existing work is preserved and there are no lint-configuration or diagnostic-suppression changes, Supabase migrations, idempotency/reconciliation additions, SQL/RPC/Edge Function or Cloudinary contract changes, repository API additions, dependencies, generated output, generic staging frameworks, route replacement, forced post-create reload, distributed rollback, global `Command` behavior changes, concurrent dashboard list requests, or unrelated refactors.
- [x] 6.5 Re-read the finalized proposal/spec/design/tasks against the repaired implementation and run `openspec validate "improve-admin-submission-editor-workflow" --strict --no-interactive`; require a valid result and stop handoff if implementation discoveries changed intent or any objective gate fails.

## Implementation Notes

- The create response remains the authoritative persisted row for live-session
  adoption, but it has no idempotency or reconciliation key. If an insert commits
  and the success response is not observed, a later create retry can duplicate the
  submission; this frontend-only change does not promise exactly-once creation.
- `add_submission_assets` remains pending-only and enforces a maximum of five
  assets, but it has no idempotency key or URL-uniqueness protection. If an
  association commits and its success response is not observed, retrying it can
  duplicate the association; this change only avoids retrying confirmed work.
- Implementation HEAD `19fb5c0d021b8756794d6ffceeb987f5b4546643` had no
  implementation changes. `flutter analyze` reported a non-zero result with
  189 diagnostics: 0 errors, 6 warnings, and 183 information diagnostics.
  Targeted `dart analyze` of the nine planned source/test/support files
  reported 3 information diagnostics and no errors or warnings: one in the
  editor ViewModel and two in `fake_repositories.dart`; the other seven files
  were zero-clean.
- The post-implementation adversarial review found that backend create/update
  validation trims city/name while mounted `initialValue` fields do not
  resynchronize, and that an already-running dashboard `load` can coalesce away
  the required post-editor refresh. It also found missing middle-item retry and
  partial-failure widget regressions, so the affected tasks and final gates were
  reopened rather than treating checked boxes as proof of compliance.
- At that review checkpoint, the original focused command passed 141 tests,
  repository-wide `flutter test` passed 1,399 tests, targeted and repository-wide
  analyzer results exactly matched their recorded baselines, `git diff --check`
  passed, and strict OpenSpec validation succeeded. These results describe the
  pre-repair implementation and must be rerun after the reopened work.
- Before planning the dashboard repair, targeted `dart analyze` confirmed
  `admin_submissions_view_model.dart` and
  `admin_submissions_view_model_test.dart` are both zero-clean; preserve that
  baseline when adding serialized follow-up refresh behavior.
