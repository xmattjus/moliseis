# Tasks

Planning-only definition: every box below is future implementation work and remains unchecked. Independent adversarial review and explicit apply authorization are prerequisites; OpenSpec artifact completion is not implementation evidence.

## 1. Reconfirm baseline and contracts

- [ ] 1.1 Compare application HEAD with audited `355bc678836894c72cbec31d5929076a1fe8cc79`, capture clean/staged/untracked scope, read applicable AGENTS/OpenSpec artifacts and confirm dependency versions against design; resolve material drift before affected edits, preserving unrelated work.
- [ ] 1.2 Reconfirm Admin create ownership, asset pending/max-five RPC and lack of Admin create/association idempotency from the named Edge/store/migrations; acceptance is a source-referenced contract note with zero backend/dependency changes.
- [ ] 1.3 Read the immutable-draft, mounted-context, Result, static-analysis and applicable test-support/unit/widget/ObjectBox skills; inspect shared support before writing any test. Reuse `test/support/fake_image_picker.dart`, `fake_repositories.dart`, `content_submission_command_harness.dart`, `objectbox_test_store.dart`; acceptance is no duplicate local fake Box/Store or redundant harness.
- [ ] 1.4 Run `openspec validate harden-admin-draft-and-staged-assets --strict --no-interactive`; reconcile review findings and design/spec/task contradictions before application, without importing Plans 2–4.

## 2. Domain models and immutable snapshots

- [ ] 2.1 Add Admin draft snapshot and exact owner/target identity using existing Delta freezing, `EventDateDraft` and `EventTimePolicy`; domain tests prove UUID stability, deep immutability/equality/hash, nullable/empty fields, exact coordinate strings, category changes and all-day/unresolved-start/end-civil-date round-trips.
- [ ] 2.2 Define separate checkpoint/remote-baseline metadata and draft/staging repository contracts, including unknown versus absent and exact-session retirement; tests prove local equality ignores lifecycle metadata and local checkpoint cannot clear remote dirtiness or authorize moderation.
- [ ] 2.3 Reuse/extend `test/domain/models/content_submission_draft_test.dart`, `content_submission_staged_asset_test.dart`, `admin_submission_models_test.dart`, `test/domain/core/event_time_test.dart` as precedents; add focused Admin model tests and require no UI codec/Quill controller dependency in persistence fixtures.

## 3. Additive ObjectBox schema and mapping

- [ ] 3.1 Add Admin draft/staged entities and the small ticket/inbox entry entity with explicit owner/query keys and versioned validated payloads; mapper tests cover incomplete temporal fields/raw coordinates, wrong owner, malformed IDs/digests/paths, unknown payload versions, checkpoint sequence, Create fence and resumable-versus-parked lookup keys.
- [ ] 3.2 Generate only intentional outputs with `dart run build_runner build --delete-conflicting-outputs`; inspect `lib/generated/objectbox-model.json` and generated bindings for new UIDs without renumbering/reusing existing or retired UIDs, preserving Public entities 20/21 and the existing store path. Require a scoped generated diff before repository integration.
- [ ] 3.3 Add a pre-change populated-store upgrade fixture using the established fixture convention and real temporary stores; verify Public draft/assets/settings/content/sync cursor data survive adding the three entities and new Admin/inbox rows round-trip after reopening. Do not fabricate or hand-edit generator identities.

## 4. Draft repository and checkpoints

- [ ] 4.1 Implement exact account/target lookup, captured write, baseline-only update and exact-session retirement with expected storage errors translated at the owning repository; real-store tests prove multi-target/account isolation, technical duplicate/unsupported payload quarantine and failure distinct from absence.
- [ ] 4.2 Implement local snapshot/checkpoint behavior and a feature-local future tail released in `finally`; deterministic Completer tests prove ordinary untouched/equal-durable no-op, required first owner write, A pending/B current, failed baseline, checkpoint/retirement ordering and no resurrection.
- [ ] 4.3 Extend from `test/data/mappers/content_submission_draft_mapper_test.dart`, `test/data/repositories/content_submission_draft_repository_impl_test.dart` without changing their Public guarantees; new Admin tests cover closed-store/hard read failure without treating it as absence or deleting staged ownership.

## 5. Admin staged filesystem repository

- [ ] 5.1 Implement distinct `admin_submission/staged` ownership, canonical relative paths, temp-copy/close/flush/size+SHA-1/rename/descriptor publication and explicit descriptor ordering; real-store/filesystem tests prove independence from original picker paths and partial-batch preservation.
- [ ] 5.2 Add exact-session dedup, 10 MiB maximum and combined persisted/staged five-image capacity checked under local arbitration; tests prove duplicate does not reorder, restored count consumes capacity, over-limit candidate is soft-rejected and capacity returns after local removal. Test remote associated-count growth while inactive: preserve all staged files and block over-capacity actions while allowing exact-owner local removal.
- [ ] 5.3 Implement reconciliation/removal/retirement containment, lowest-valid duplicate retention, missing/corrupt/oversized descriptor rejection, orphan/temp cleanup without reconstruction and path-free diagnostics; real filesystem tests cover root/account/session/file symlinks, traversal, wrong-owner paths, descriptor-write and cleanup failure windows.
- [ ] 5.4 Adapt the real-store cases from `test/data/repositories/content_submission_staged_asset_repository_impl_test.dart` and mapper/model tests for Admin multi-session policy; acceptance includes inactive A surviving B reconciliation, account isolation, hard ObjectBox failure, rename-without-descriptor loss and successful committed siblings after later errors.

## 6. Shared Android picker ownership and durable inbox

- [ ] 6.1 Implement one startup-initialized shared coordinator, injectable existing picker seam, durable ticket attribution and global physical picker lease; coordinator tests prove one retrieval attempt for concurrent callers/route remounts, launch waits for startup and checkpoint/ticket commit, no launch on failure and no retrieval on non-Android. Include exception-before-native-consumption and surviving-ticket/empty startup with delayed old result: replacement launches must remain blocked, including lost cancellation; no timeout or speculative abandon/reset may authorize reassignment.
- [ ] 6.2 Implement bounded private inbox copies with versioned committed descriptors, deterministic recovered digest order and temp/verify/rename/commit ordering; real-store tests recreate services after each injected retrieval/copy/rename/commit interruption and distinguish committed bytes from the documented native-consumption loss window.
- [ ] 6.3 Implement exact-feature/session/account delivery, startup-acquisition-only waiting outside feature arbitration followed by durable terminal inbox rejection before explicit removal and compare-and-ack after feature commit without holding coordinator lock across feature queues; Completer tests cover ack failure, stage failure, commit-before-ack crash, dedup replay, invalid ticket, cancellation, explicit revocation, ack failure → explicit remove → restart with no resurrection, rejection-write failure preventing removal, pending startup inbox copy → removal wait → copy commit → rejection with no resurrection, captured delivery overtaken by removal with pending-state recheck, and no deadlock/reentrant retargeting.
- [ ] 6.4 Test startup before auth restoration, unrelated login, logout/privilege loss, original-account explicit reactivation, no-ticket upgrade residue and both cross-feature directions; require no automatic Admin remote calls, no foreign UI disclosure, no ticket overwrite while a physical picker is pending and no cleanup on unknown ownership.
- [ ] 6.5 Wire early acquisition after bindings/ObjectBox availability and before auth-dependent route startup; extend `test/config/dependencies_test.dart` and focused startup tests to prove acquisition occurs with no original editor route and ObjectBox setup failure preserves existing safe setup-error behavior. Repository/source search must show exactly one production `retrieveLostData` consumer and both feature launch sites routed through ownership.

## 7. Narrow Public integration and regressions

- [ ] 7.1 Replace Public's direct platform recovery with coordinator requests/tickets while retaining initialization ticket, `_lifecycleTail`, captured removal/session guards, diagnostic mapping and common candidate pipeline; extend `test/ui/content_submission/view_models/content_submission_view_model_test.dart` for matching inbox consumption and revoked/unknown/absent owners.
- [ ] 7.2 Extend `test/routing/content_submission_route_test.dart`, `content_submission_restoration_test.dart`, `test/ui/content_submission/widgets/content_submission_screen_test.dart` and asset-list tests for early startup retrieval before route, route rebind without extra retrieval, explicit discard/session rotation, restored capacity/dedup and historical terminal suppression.
- [ ] 7.3 Run Public draft/staged model, mapper and repository tests, Public VM/screen/route/progress tests after shared changes; acceptance is preservation of explicit checkpoints, private copies, process restore, sequential submit/retry/idempotency/finalization and existing exit/progress contracts.

## 8. Admin application-level ownership and restoration

- [ ] 8.1 Register one existing-style application Provider owner and explicit target activation; replace both route-local editor providers with generation-bound consumers. Extend `test/routing/admin_route_test.dart`, `test/config/dependencies_test.dart` and editor widget tests to prove same-target reuse, A → B → A restoration, loading/activation failure and new generation even when VM identity stays equal.
- [ ] 8.2 Add local checkpoint control and inline refused-switch feedback/return action; VM/widget tests prove dirty switch refusal, explicit checkpoint then allowed switch, no automatic write on detachment, untouched activation no write and no dirty-exit dialog.
- [ ] 8.3 Implement separate remote baseline hydration and blocked-restoration behavior; Completer tests prove matching pending baseline restores incomplete edits, remote clean checkpoint can hydrate fresh detail, changed/missing/final/failed remote context preserves fields but blocks writes, and late detail cannot overwrite B.
- [ ] 8.4 Bind account/privilege changes from existing `AdminAuthViewModel`, revoke active generation immediately, cancel active upload best-effort and clear private runtime state; extend `test/ui/admin/auth/view_models/admin_auth_lifecycle_test.dart`, `admin_auth_view_model_test.dart`, Admin routing tests for changed-account isolation, delayed auth restoration and late A completion after reauthorization.
- [ ] 8.5 Extend existing Command admission/settlement and consumer effect binding rather than replacing them; `test/ui/admin/submissions/view_models/admin_submission_editor_commands_test.dart` must prove listener reentrancy, captured target, A1 → B → A2 stale results, covered routes/dialogs, cleanup-only completion and late raw-throw/disposal behavior without premature Command disposal.

## 9. Legacy editor compatibility and local replay guard

- [ ] 9.1 Keep existing Create/Update and post-success navigation; add Create-only field lock plus runtime completed-session guard, durable pre-attempt fence only for already-durable new sessions, and exact local retirement on success. Update the existing concurrent-Create expectation deliberately; tests prove fence failure makes no remote call and fenced restart never re-Creates, while non-durable retries make no exactly-once claim. Prove a pending earlier checkpoint settles before durability capture and later checkpoints cannot create an unfenced row during Create; prove explicit separate-new activation preserves parked uncertain history and fails safely if parking fails.
- [ ] 9.2 Integrate confirmed Update baseline/local-checkpoint sequence settlement and local-only finalization retry; tests prove Update A/current B stays dirty, newer explicit checkpoint B survives, old superseded checkpoint retires only after confirmation, cleanup failure never replays Create/Update and an empty update asset envelope does not erase confirmed images.
- [ ] 9.3 Preserve normal live persisted pending picker/upload/association and deletion, adding owner checks after every await; tests prove failed pre-picker checkpoint opens nothing, normal cancellation, maximum capacity, pending/final status, revocation between upload/association and no rollback/automatic replay.
- [ ] 9.4 Integrate recovered Admin local-asset notice/removal and block legacy Save with staged work while keeping new-mode selection disabled; widget/VM tests assert zero automatic recovery upload/association and no create-ID adoption, progress route, staged Save or post-Save navigation redesign.
- [ ] 9.5 Run existing Admin VM/commands/editor/location/dashboard, repository/mapper/models, routing and auth tests; retain Reject/Promote/Link/Apply behavior, source acknowledgements, preview tokens, event/coordinate validation, operation exclusion, current dashboard return refresh and final-status read-only cases. Document only the narrowly justified Create-lock/replay and recovered-local-work assertion changes.

## 10. Integrated recovery and platform verification

- [ ] 10.1 Run deterministic cross-feature tests with shared `FakeImagePicker` plus Completers: Public response while Admin active, Admin response while Public active, account changes, pending auth, picker cancellation, session rotation, owner revocation during copy/commit and no foreign notifications. Require test names/assertions covering each spec scenario, with no sleep-based race tests.
- [ ] 10.2 Run real-store/filesystem restart and migration tests for both features plus coordinator: unknown/absent, invalid descriptors, partial writes, symlinks, hard store failures, cleanup errors, inbox interrupted handoff, and feature-commit-before-ack dedup. Require committed siblings and unrelated recoverable sessions to survive every modeled failure.
- [ ] 10.3 Perform Android device/emulator activity recreation and separate process-death picker smokes for each feature, Home startup, delayed/offline auth, wrong account, cancellation and recovery notice/no remote replay. Record device/API/build and actual observed results; explicitly preserve unclosed native-consumption window rather than claiming the smoke proves exactly-once.
- [ ] 10.4 Perform iOS physical-device and macOS sandbox picker/cancel/reopen smokes and confirm no lost-data retrieval; record actual platform evidence or exact release-blocking unexecuted checks, never convert planned smoke checks into passes.

## 11. Generation and static/integration validation

- [ ] 11.1 Re-run generation only if later generator inputs changed; inspect final generated diff and rerun populated-store upgrade test. Require zero unrelated schema UID/store-directory changes and no generated output beyond intentional inputs.
- [ ] 11.2 Run `dart format` and its check mode on affected authored Dart/test files, focused `flutter analyze`, then repository `flutter analyze`; require no new/worsened attributable diagnostics, documenting preexisting issues without unrelated cleanup.
- [ ] 11.3 Run complete relevant suites under `test/domain/models/`, `test/data/mappers/`, affected repositories, Public/Admin UI/routing/auth/config plus new coordinator tests, then repository `flutter test`; require passing relevant cases and explicitly report actual skips/failures. No test result is implied by this checklist.
- [ ] 11.4 Re-read final artifacts against implementation and run `openspec validate harden-admin-draft-and-staged-assets --strict --no-interactive`; require internal consistency, no Plan 2/3/4 implementation and no silently weakened Public contract.

## 12. Diff review, hygiene and publication

- [ ] 12.1 Obtain independent adversarial implementation review of ownership/auth/copy/commit/ack/retirement races and test evidence; verify each material finding or correct it with focused regression coverage before declaring application complete.
- [ ] 12.2 Review `git diff --check`, `git diff --cached --check`, full diff/status and explicit allowlist including new untracked files; require no raw logs, analyzer dumps, temporary manifests, secrets, machine paths, unrelated work, Supabase/CI/dependency edits or implementation of later plans.
- [ ] 12.3 Prepare/update one cohesive PR for this OpenSpec change under the repository workflow, attach it to the task and preserve independent-review status; never push directly to main or merge without explicit authorization. Definition PR evidence stays distinct from later implementation evidence.

## Workflow follow-up

- Plans 2, 3 and 4 require their own reviewed definitions and authorization. Enabling pre-create/recovered staged Save depends on Plan 2, not completion of these local tests.
- Resolve remaining supersession/withdrawal of `improve-admin-submission-editor-workflow` through explicit reviewed planning follow-up. Do not archive its unimplemented requirements as delivered or sync them into canonical specs.
- Archive/sync this change only after actual implementation, verification and the appropriate authorized workflow; a definition-only PR must not mark any task complete.
