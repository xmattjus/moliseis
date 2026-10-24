# Planning validation and F1–F4 remediation — 2026-10-24

## Published checkpoint

This migration was published in Draft [PR #12](https://github.com/xmattjus/moliseis/pull/12) as commit [`0cdb764a7586f85180a802fafcf2b485791cb5ff`](https://github.com/xmattjus/moliseis/commit/0cdb764a7586f85180a802fafcf2b485791cb5ff), whose parent is `e80dfbaf472ef1cc15b220a48df966509a9ee8a1` (verified from Git history). All seven migrations are now published. The historical analyzer transition for this checkpoint was **52 → 37 INFO**; these are recorded checkpoint results, not analyzer runs performed during reconciliation. Planning assumptions, local-only authorization and uncommitted-work statements below describe their original phases. Subsequent publication supersedes those status statements without changing the historical evidence. Canonical synchronization, archival, legacy compatibility deletion and merge remain outside this reconciliation.

## Evidence provenance

Recorded artifact SHA-256 values and byte-for-byte preservation claims below refer to the original apply/remediation revisions in the published checkpoint, before this documentation reconciliation. They are not hashes of the revised narrative files. Diagnostic records and machine-readable evidence remain unchanged.

Historical log filenames and `<evidence-dir>` references below identify ephemeral local evidence captured during the original apply/remediation. Those files are not tracked or guaranteed accessible; the recorded outcomes and hashes are preserved as provenance, not newly replayed verification. Tracked tests and the published commit remain inspectable, but do not independently recover missing raw logs. No latest-head GitHub Actions result is inferred from historical local tests; check PR #12 for checks attached to the exact published SHA.

## Initial planning record (historical; superseded readiness)

Planning only. No production/test edits, test runs, generator, Dart formatter, commit, push, PR update, merge, sync or archive.

- Remote PR #12 verified before worktree creation and again at closure: OPEN, codex/migrate-legacy-commands, base main, head e80dfbaf472ef1cc15b220a48df966509a9ee8a1. No drift.
- New worktree: `<worktree>`. Branch codex/plan-migrate-admin-session-commands; HEAD remains e80dfbaf472ef1cc15b220a48df966509a9ee8a1.
- Seven pre-existing checkout inventories compared against analyzer-baseline.md: branch/HEAD/index/tracked/untracked all unchanged and clean. Primary main remains ee60777c7fdfc5c16daa1151050c134fbb7cde29.
- New worktree index empty; tracked diff empty. Only untracked files are the seven documentary artifacts under this change: .openspec.yaml, proposal.md, design.md, tasks.md, specs/command-execution-concurrency/spec.md, analyzer-baseline.md and this validation.md. No symlink escape in output paths.
- `flutter pub get --offline`: exit 0; lockfile tracked diff empty. Ignored dependency/runtime metadata was prepared only in the new worktree. No SDK/dependency upgrade. Initial non-escalated SDK version queries were denied a cache stamp write; direct Dart SDK version query succeeded: Dart 3.13.4 stable, 2026-09-15, macos_arm64. Analyzer used this installed SDK through `<sdk-bin>/dart`.
- `dart analyze --format machine`: exit 0, 52 INFO / 0 WARNING / 0 ERROR. Entire normalized 52-row Counter equals located published phase-5 B1.stdout: missing=0, added=0, same positions and multiplicity. 15 target entries (Auth 6 / Dashboard 9); eventual apply target is 37 retained INFO, not an executed B1.
- `openspec validate migrate-admin-session-commands --strict`: exit 0, valid. `openspec status --change migrate-admin-session-commands`: 4/4 planning artifacts complete. This is file/workflow validity, not approval or implementation verification; all 19 apply task checkboxes remain unchecked.
- `git diff --check`: exit 0. Since change files are untracked, additionally checked all seven document contents for trailing whitespace, terminal newline and scope/symlink containment. No violations.
- Implementation tests, B1, independent plan review, independent code review and CI: NOT EXECUTED in this planning phase. Their future gates are specified in design/tasks, not claimed passed.

No material planning blocker remains identified. Known limitations: physical SDK/repository calls already started can affect shared remote/session state after local owner revocation; private cleanup retains never-settling Futures; Dart immutable credentials cannot be securely zeroed. Decisions and deterministic acceptance coverage are explicit in design.md. No extra global infrastructure is proposed.

Initial readiness was READY FOR INDEPENDENT PLAN REVIEW; the independent review subsequently supplied F1–F4. The current remediation outcome follows below.

## F1–F4 remediation verification

Scope: authorized planning remediation only, using existing change migrate-admin-session-commands. No worktree recreation, branch switch, production/test/config/dependency/backend/foundation edit, experiment through code changes, analyzer run, dependency preparation, formatter, apply, commit, push, PR update, sync, archive or merge in this remediation. No independent re-review has been performed here; the user supplied the prior independent findings.

### Evidence and reconciled findings

- F1 premise confirmed: the old proposed currentUser-only recheck did not correlate the completed login with that session. Read resolved gotrue 2.27.2 source (selected by pubspec.lock/package_config): nullable response.user, its session fallback, exact Session object saved by password sign-in, direct currentSession/currentUser getters and signOut without CAS. D2 now requires explicit attempt/user/session correlation and a final no-yield/no-callback guard before cleanup; absent or replaced evidence gives expected login failure without cleanup or false success. Only actual currentUser authorizes Admin. Tests A3/A6 include distinct nonadmin A/B, missing identity/session, same-user replaced Session and pre/post-signOut reentrancy. Residual: no client guard makes SDK side effects atomic after invocation.
- F2 premise corrected: legacy pendingId assignment itself does NOT notify, but it precedes both reads; their running/commit notifications and the screen's merged listener can expose an enabled link while refresh is pending. D3/D4 now deliberately harden UX: private committed ID retained, public link/readiness withheld until both attempts normally settle, including either/both handled read failures. D5/D7/D9 cover every visibility barrier, partial failure, stale callback and revocation. This is an intentional observable timing change, disclosed in proposal rather than described as preservation.
- F3 premise confirmed as a planning gap: private cleanup had not defined ownership of the Future returned from an accepted refresh. D1/D5 now register per-admission private receipts BEFORE run/notification and retain private settlement listeners separately from detached public forwarders. Original Futures complete normally exactly once after safe settlement for success/domain/handled runtime, even after disposal; no second throw/report. Abnormal assertion settlement keeps original fail-loud path and forbids normal follow-up. S1–S8/E1–E3 cover pre-entry/physical pending/reentrant dispose, duplicate resolution, >50ms virtual-time raw failures, internal receipts and nonterminating work. Residual: truly nonterminating physical work and its Future remain pending.
- F4 premise confirmed: shared gate can reject Logout while UI did not specify disabled state; existing MenuItem.onPressed is nonnullable. D2/D4 now derive canLogout from the exact shared live/idle predicate, observe Auth in Dashboard header and use Dashboard-local compact/wide Material controls with nullable callbacks (shared wrapper unchanged). requestLogout remains definitive; only accepted still-owned callback navigates Home once, no post-go context/widget access or completion go. A5/R4 cover external Admin event during local login, visually disabled controls, stale callback rejection and reentrant routing.

The review traceability table in design.md connects each finding to code evidence, final decision, existing normative scenario titles and executable task/test IDs. The normative delta has 11 requirements / 70 scenarios; 21 apply tasks remain unchecked. Reconciliation explicitly covers gate/session distinction, held logical mutation snapshot vs private terminal, pending navigation readiness, read receipt completion vs revoked public forwarding, and raw-error reporting exactly once. No material F1–F4 ambiguity remains identified in the planning artifacts; runtime acceptance remains future work.

### Commands and integrity checks actually executed

- `gh pr view 12 --repo xmattjus/moliseis --json state,headRefName,headRefOid,baseRefName` at remediation preflight and closure: OPEN / codex/migrate-legacy-commands / e80dfbaf472ef1cc15b220a48df966509a9ee8a1 / main. Remote baseline unchanged; only read operations issued.
- Reused `<worktree>` on codex/plan-migrate-admin-session-commands. HEAD remains e80dfbaf472ef1cc15b220a48df966509a9ee8a1. Index and tracked diff empty before/after; seven documentary files remain untracked, no additional files under the change.
- `openspec list --json`, `openspec status --change migrate-admin-session-commands --json` and instructions for existing artifacts confirmed resolved root, scope and all artifacts present. Final `openspec status --change migrate-admin-session-commands`: 4/4 planning artifacts complete, with implementation task progress 0/21. CLI apply guidance was not executed.
- `openspec validate migrate-admin-session-commands --strict`: final exit 0, valid. The first remediation validation exposed one >500-character ADDED requirement warning (strict exit 1); that requirement was shortened without dropping scenarios and subsequent strict runs passed. No validation failure is presented as a pass.
- `git diff --check`: exit 0. Because all seven files are untracked, additionally checked trailing whitespace, final newline, symlink containment and exact seven-file manifest. All pass.
- Preserved original seven artifact bytes for comparison in a temporary copy. Compared before/after SHA256: analyzer-baseline.md remains **1fca7dda52be5611c6031757ac18a458e6cb53bc0a75b0e24eb7488a8af7fb03**, .openspec.yaml unchanged. No B0 regeneration. Diff against the preserved untracked artifact copy confirms only the five authorized documentation files below changed; ordinary tracked git diff is empty.
- Compared all eight checkout inventories (HEAD, branch, index, tracked status/diff and untracked list) with remediation preflight: identical. All seven other checkouts remain clean and on the same HEAD/branch; primary main unchanged.
- Programmatic documentary consistency checks: all F1–F4 traceability rows resolved in planning, every referenced normative scenario exists, no duplicate scenario titles, requirement text within strict limits, exactly 21 unchecked tasks and zero checked implementation tasks. Full design/delta/tasks reread for contradictory old identity, early-link, observer-removal or logout policies.
- NOT EXECUTED: implementation/unit/widget/runtime tests, B0/B1 analyzer, CI, independent plan re-review or code review in this remediation. Test cases above are acceptance criteria for a separately authorized apply, not observed runtime results.

### Remediation manifest

Modified existing untracked documents only:

- proposal.md — disclose intentional correlation/navigation/settlement/logout contract hardening.
- design.md — revised D1–D5, matrices, evidence, tests, risks and F1–F4 traceability.
- specs/command-execution-concurrency/spec.md — reconciled normative requirements and deterministic scenarios.
- tasks.md — 21 unchecked implementation/verification tasks, including explicit private settlement cases.
- validation.md — historical evidence preserved and current remediation checks distinguished.

Preserved byte-for-byte: .openspec.yaml and analyzer-baseline.md. All seven files remain in the existing change directory; no new capability or implementation surface beyond the original five Commands is introduced. Remaining limits are explicit: invocation-time correlation is not SDK CAS, in-flight effects may outlive owners, never-settling Futures retain private resources, immutable credentials cannot be securely zeroed, and runtime behavior still requires future acceptance tests.

READY FOR INDEPENDENT PLAN RE-REVIEW

## Apply — preflight and B0

Apply explicitly authorized after independent F1–F4 re-review. PR #12 checked OPEN/Draft, head e80dfbaf472ef1cc15b220a48df966509a9ee8a1, base main. Dedicated worktree/branch reused, HEAD unchanged, index/tracked diff empty before edits. All seven artifact hashes and eight checkout inventories saved in `<evidence-dir>/admin-session-apply`. Reconstructed the final prior remediation patch against its preserved originals: all current artifacts exactly match approved last-turn content; no drift. Resolved command_it 9.5.2, listen_it 6.0.0, gotrue 2.27.2 and Dart 3.13.4 confirmed from actual package_config/SDK.

B0 regenerated before production edits: `<flutter-sdk>/bin/cache/dart-sdk/bin/dart analyze --format machine`, cwd dedicated worktree, exit 0, stderr empty; 52 INFO / 0 WARNING / 0 ERROR. Normalized full Counter exactly equals the approved analyzer-baseline.md ledger, including source positions/messages/multiplicity: 15 target / 37 residual, missing=0, added=0. B0.stdout/stderr/json retained in temporary evidence directory; no analyzer suppression or dependency preparation.

Test-support inventory: existing ControllableAdminAuth/MockGoTrueClient and FakeAdminContentSubmissionRepository inspected with their current users; existing command_test_support and ordinary lifecycle support supply virtual pumps/reporting/disposal probes. Extended only Admin fake with independent pendingIgnoredList, phase order and entry hooks. Legacy Dashboard VM baseline after that additive extension: `flutter test --no-pub test/ui/admin/submissions/view_models/admin_submissions_view_model_test.dart --reporter expanded`, exit 0, 7 pass/0 fail/0 skip (dashboard-support-baseline.log). Auth support baseline and owner implementation remain in progress; no unverified task marked complete.

Auth support baseline: `flutter test --no-pub --reporter expanded test/ui/admin/auth/view_models/admin_auth_view_model_test.dart`, exit 0, 10 pass/0 fail/0 skip (auth-baseline.log). ControllableAdminAuth extended with exact Session installation, independently controlled SDK response handlers, operation entry hooks/counters. Both original target VM baselines passed after additive support changes; task 1.3 verified. Flutter 3.47.5 stable (framework 6a19cca564), Dart 3.13.4 confirmed. Auth owner implementation and deterministic regression gate are in progress; Dashboard production migration has not started.

### Apply Auth gate (tasks 2.1–2.4)

Implemented private no-parameter Result Commands, shared synchronous reservation, one-shot credential slot, cached Result-aware snapshots and separate detachable public forwarders/retained private settlement observers. Login verifies response user/session identity and identical current Session, then current Admin authorization; final cleanup guard follows reentrant rejection logging. Missing/replaced evidence fails conservatively. Logout uses actual final session; no new SDK phase after revocation.

Focused command: `flutter test --no-pub --reporter expanded test/ui/admin/auth/view_models/admin_auth_view_model_test.dart test/ui/admin/auth/view_models/admin_auth_lifecycle_test.dart`, exit 0, **46 pass/0 fail/0 skip**, stable auth-gate-closed.log. Targeted `dart analyze --format machine` on Auth owner/mock/two VM test files: exit 0, zero diagnostics (auth-analyze-closed.log). Coverage A1–A8/E1/E3 includes logger-triggered A→distinct nonadmin B after initial correlation (zero signOut/restore), missing user/session/null current/same-user session replacement, denied cleanup failures, disposed restore and signOut with actual client cleared (discriminating no-next-phase oracle), replacement owner independence, running/terminal dispose, private physical notifier release once, raw StateError/assertion after >50ms virtual cleanup time and loggingHandler/CommandError/snapshot/log password absence.

An internal read-only adversarial audit found two test-oracle weaknesses (post-signOut user not cleared; replacement occurred before first rather than final correlation); both were strengthened before final46 gate. Production guard behavior and test harness fixes were reconciled without changing normative contracts. Initial harness late-error tests needed same-Zone Completer construction, not altered acceptance. No new skip or global foundation change. Dashboard owner implementation now in progress; consumer migration awaits its gate.

### Apply Dashboard and consumer gates (tasks 3.1–4.4)

Dashboard owner gate: `flutter test --no-pub --reporter expanded test/ui/admin/submissions/view_models/admin_submissions_view_model_test.dart test/ui/admin/submissions/view_models/admin_dashboard_command_lifecycle_test.dart`, exit 0, **60 pass/0 fail/0 skip** (dashboard-final.log). The two independent ordinary read lanes return domain lists; each admission owns a receipt/Completer before notifications/run. Private results/running observation plus action-finally witness and revision-checked microtask→event barrier settle the original Future once, separately from public forwarding. Retain active Commands past owner revocation; deferred release outside upstream dispatch. Mutation uses the receipt object as a private orchestration token, keeps successful resolution private and performs ignored-then-submissions refresh once each. Joint normal settlement publishes logical success and pending ID together, including handled read failures. Assertion-abort is private settlement only, never normal success or next-refresh authority.

D1–D9/E1–E3/S1–S8 covered by 7 original VM cases plus 53 lifecycle/coordinator cases. Both read façades test original Future settlement, skipped pre-entry, late success/domain/raw/assertion, same-turn completion/dispose orders, disposal from owner/upstream notifications, exact resource release, retained never-terminating work, replacement-owner isolation and both internal-refresh revocation points. Internal raw read failure reports once without parent rethrow; normal handled failures still permit next refresh and mutation success. Final-success notification can admit another exclusive mutation safely, clearing old pending navigation; third mutation/external reads remain rejected. Targeted Dashboard owner/harness/tests analyzer exit 0, no diagnostics (dashboard-analyze-final.log).

Auth widget+routing gate: `flutter test --no-pub --reporter expanded test/ui/admin/auth/widgets/admin_login_screen_test.dart test/routing/admin_route_test.dart`, exit 0, **26 pass/0 fail/0 skip** (auth-consumers-final.log: 10 Login widget, 16 routing). Targeted analyzer exit 0/no diagnostics. Existing denial/redirect/Settings Back cases retained; added pending shared gate, listener rebinding, late owner notifications, pushed-login initial/update binding, actual-router external Admin during local pending login, repeated events+completion yielding one Dashboard initial read, and logout event+completion yielding one protected redirect.

Dashboard widget final gate: `flutter test --no-pub --reporter expanded test/ui/admin/submissions/widgets/admin_dashboard_screen_test.dart`, exit 0, **35 pass/0 fail/0 skip** (dashboard-widget-final.log). Includes both responsive logout shapes, stale enabled callback rejection, admitted logout with synchronous reentrant route movement, all four post-commit read-failure combinations plus compact success, no usable pending link before both settlements, exact pending-editor navigation, stale link/new mutation, editor true/false/null, old owner editor return/retry callback, unmount, manual/pull refresh and retained rows after failed refresh.

Internal consumer audit found retained Retry tearoffs could admit reads on a replaced but still-live owner; both now use guarded captured-owner/lane helpers, with two discriminating regressions. Filter selection also rechecks ownership before remote admission after its synchronous notification. Shared ResponsiveOverflowMenu, Editor and routing guards are unchanged; router diff is only one Dashboard initialization call. Tests no longer await deferred commands inside fake async without pumps; no sleep or new skip introduced.

Mounted-safety discriminating experiment: copied current lib/test/config to `<evidence-dir>/admin-session-apply/unmount-red-snapshot`, remapped only that copy's package root, removed Dashboard entry mounted guards ONLY in the copy, then ran `flutter test --no-pub --reporter expanded test/ui/admin/submissions/widgets/admin_dashboard_screen_test.dart --plain-name "R4 unmounted Dashboard rejects captured editor callback"`. Exit 1, 0 pass/1 fail, actual unmounted-State.context assertion (Flutter 3.47.5), proving the guard is exercised. Worktree guards remained present; the same case passed in the real final Dashboard widget suite. No production experiment edit or acceptance relaxation.

### Integrated focused acceptance

Expanded focused command includes the four Admin VM test files, both screen files, admin_route_test, ordinary_view_model_lifecycle_test, result_command_test, restartable_command_test, command_configuration_test, command_it_disposal_behavior_test, test/ui/settings, dependencies_test, events_route_test, sync_redirect_test, route_ownership_test and back_navigation_integration_test. Exact argv/cwd/exit retained in focused-suite-final.json with full expanded log: **573 pass/0 fail/3 pre-existing skip, exit 0**. A subsequent additional compact post-commit widget case passed in the final35 Dashboard gate; full-suite gate below includes that final test version.

First focused attempt: 572 pass/1 fail/3 skip, exit 1, solely missing native ObjectBox library in dependencies_test setup (plus consequent uninitialized teardown). Setting DYLD_LIBRARY_PATH did not satisfy the hardened Flutter loader. Inspected resolved objectbox-5.3.2 loader: desktop runtime is preferred at absolute worktree/lib/libobjectbox.dylib. Copied the existing universal binary from prior content-submission worktree to that ignored runtime path; SHA256 identical **1af2e266e523dbcc33b3682eebf297f2f4f23ade6ab706dab794f7a6f8108751**. No ObjectBox source, persistence contract, dependency, configuration or other checkout changed. Final focused gate above passed with that environment preparation.

### Full Flutter gate and limitations

Actually executed `<sdk-bin>/flutter test --no-pub --reporter expanded` in the dedicated worktree, exit **0**, **2979 passed / 0 failed / 6 skipped**, duration reported 01:38 (full-suite.log/json). Includes final source/test versions and all 167 target tests. No test file excluded and no new skip added. Baseline skip declarations were read at HEAD and remain unmodified: three command_it_disposal_behavior_test late-StateError-after-early-Command-dispose characterizations; geo_map_route_test Map-root Back upstream issue; two opt-in Supabase pipeline bodies (MOLISE_ALL_DAY_LOCAL_E2E and MOLISE_EXTERNAL_TOKEN_LOCAL_E2E unset). Those six bodies were NOT executed; no backend integration/CI/device smoke or external network behavior is claimed. All target late-error/receipt regressions themselves executed, rather than relying on the upstream skipped bodies.

Preliminary widget failures were corrected, not hidden: migration initially disposed Command owners outside the virtual test clock and awaited a deferred action without pumping; original logout test checked SDK call before deferred entry; first responsive test used Tooltip/RawTooltip finder as IconButton. Existing testOwnerUI cleanup and explicit command pumps plus correct control finder resolved these harness issues. The internal Retry ownership finding was fixed in production and given two regressions before final gates. No acceptance criterion, CI gate, foundation behavior or runtime failure policy was relaxed.

### B0/B1 exact analyzer reconciliation

Both commands were `<flutter-sdk>/bin/cache/dart-sdk/bin/dart analyze --format machine`, identical cwd/SDK/config, exit **0**, empty stderr. B0 **52 INFO/0 WARNING/0 ERROR**, B1 **37 INFO/0 WARNING/0 ERROR**. Exit 0 does not mean zero INFO. All diagnostics are INFO/LINT/DEPRECATED_MEMBER_USE_FROM_SAME_PACKAGE; baseline ledger stores their complete messages. Removed Counter equals exactly the 15 target identities below (line:column:length at approved checkpoint; overload/reference spans deliberately count separately). Every message matches B0/approved ledger; none of these target paths has a B1 diagnostic.

| Target file owner | Original line:column:length | Deprecated symbol in message |
|---|---|---|
| Auth | 23:13:37 | Command1 |
| Auth | 23:13:8 | Command1 |
| Auth | 24:14:14 | Command0 |
| Auth | 24:14:8 | Command0 |
| Auth | 39:8:8 | Command1 |
| Auth | 42:8:8 | Command0 |
| Dashboard | 17:12:14 | Command0 |
| Dashboard | 17:12:8 | Command0 |
| Dashboard | 18:19:14 | Command0 |
| Dashboard | 18:19:8 | Command0 |
| Dashboard | 19:16:35 | Command1 |
| Dashboard | 19:16:8 | Command1 |
| Dashboard | 33:8:8 | Command0 |
| Dashboard | 36:8:8 | Command1 |
| Dashboard | 51:8:8 | Command0 |

B1 retains **33** Editor VM diagnostics, **1** Editor screen diagnostic and **3** existing fake_repositories.dart diagnostics. Compared severity/type/code/file/message/column/length/multiplicity and mapped only unchanged source lines using SequenceMatcher matching blocks: fake lines **656→675** and **1169→1188**, both same source text/column/span after the additive 19-line Admin fake extension. Other positions unchanged, including the third fake diagnostic. Counter equality true; missing=0, added=0. Full raw B0/B1 stdout/stderr/json and analyzer-reconciliation.json were captured under `<evidence-dir>/admin-session-apply`; analyzer-baseline.md is byte-for-byte unchanged. No ignore/suppression, Editor cleanup or dependency/config change.

### Final scope, artifacts and Git integrity

All 21 tasks checked only after corresponding acceptance gates. Design adds an actual implementation appendix, F1–F4 executed traceability and A1–A8/R1–R4/D1–D9/E1–E3/S1–S8 PASS mapping. Normative delta remains unchanged; no retroactive acceptance adjustment. Apply changes only design.md/tasks.md/validation.md among the seven approved artifacts. .openspec.yaml, proposal.md, analyzer-baseline.md and specs/command-execution-concurrency/spec.md retain pre-apply SHA256 exactly.

Authorized local diff manifest (15 Dart files plus seven preserved/newly surfaced OpenSpec documents):

| File | Purpose |
|---|---|
| lib/ui/admin/auth/view_models/admin_auth_view_model.dart | Two private Commands, shared gate, correlation/privacy and retained lifecycle |
| lib/ui/admin/auth/widgets/admin_login_screen.dart | Façade/snapshots and exact-owner listener binding |
| lib/ui/admin/submissions/view_models/admin_submissions_view_model.dart | Three private Commands, coordinated lanes/receipts/post-commit |
| lib/ui/admin/submissions/widgets/admin_dashboard_screen.dart | Intent consumers, guarded callbacks/pending navigation, responsive disabled Logout |
| lib/routing/router.dart | Dashboard initial refresh call only |
| test/support/mock_gotrue_client.dart | Independent SDK response/current Session, counters/hooks and recording Auth logger |
| test/support/fake_repositories.dart | Additive controlled Admin read/mutation phases only |
| test/support/admin_dashboard_command_harness.dart | Reusable real-Command Dashboard lifecycle harness |
| test/ui/admin/auth/view_models/admin_auth_view_model_test.dart | Auth domain/concurrency/correlation regressions |
| test/ui/admin/auth/view_models/admin_auth_lifecycle_test.dart | Auth reporting/privacy/reentry/disposal regressions |
| test/ui/admin/auth/widgets/admin_login_screen_test.dart | Login façade, generic error, rebinding/replacement/unmount |
| test/ui/admin/submissions/view_models/admin_submissions_view_model_test.dart | Migrate existing dashboard regression consumers |
| test/ui/admin/submissions/view_models/admin_dashboard_command_lifecycle_test.dart | D/E/S deterministic coordinator and original-Future settlement |
| test/ui/admin/submissions/widgets/admin_dashboard_screen_test.dart | Refresh/editor/link/Logout/replacement/unmount UI regressions |
| test/routing/admin_route_test.dart | Guard/session/Settings/navigation single-effect regressions |
| openspec/changes/migrate-admin-session-commands/.openspec.yaml | Existing approved metadata preserved |
| openspec/changes/migrate-admin-session-commands/proposal.md | Existing approved proposal preserved |
| openspec/changes/migrate-admin-session-commands/design.md | Actual implementation/acceptance evidence appended |
| openspec/changes/migrate-admin-session-commands/tasks.md | 21 verified tasks checked |
| openspec/changes/migrate-admin-session-commands/analyzer-baseline.md | Existing approved full B0 ledger preserved |
| openspec/changes/migrate-admin-session-commands/validation.md | Apply commands/results/reconciliation/integrity evidence |
| openspec/changes/migrate-admin-session-commands/specs/command-execution-concurrency/spec.md | Approved normative delta preserved |

No tracked diff in foundation/global handler/lib/utils/command.dart, Editor, backend, production repositories/domain, Provider composition, dependency/config/generated/CI paths, or improve-admin-submission-editor-workflow. Search found no legacy execution/state API or direct run/runAsync in the target screen/test consumers; router's excluded Editor load.execute and other migrated features remain intact. Format verification on all 15 changed/new Dart files: 0 changed, exit 0. No added sleep, skip or suppression. Runtime native dylib is ignored environment preparation, not part of the source diff.

Final checks recorded alongside the temporary evidence manifest: OpenSpec strict validation exit 0; status 4/4 planning artifacts complete and instructions apply 21/21 tasks complete; git diff --check exit 0; additional untracked trailing-whitespace/final-newline/symlink/manifest checks pass. Dedicated HEAD remains **e80dfbaf472ef1cc15b220a48df966509a9ee8a1**, branch **codex/plan-migrate-admin-session-commands**, staged diff empty/index matches HEAD. Twelve tracked files modified; ten individual untracked files (seven existing OpenSpec documents plus three new Dart support/test files). All seven other checkouts exactly match initial HEAD/branch/index/tracked/untracked inventory; main remains ee60777c7fdfc5c16daa1151050c134fbb7cde29. PR #12 read-only closure check remains OPEN/Draft, codex/migrate-legacy-commands→main, exact authorized head. No commit, push, PR update, main synchronization, archive or merge.

Readiness applies to the local diff and executed tests only. The independent code review is still mandatory before any separately authorized commit/publication. Residual limitations are unchanged: SDK invocation-time correlation has no CAS, physically in-flight SDK effects can outlive owners, immutable passwords cannot be securely zeroed, truly nonterminating work retains waiters/resources, six pre-existing skipped bodies were not exercised, no CI/device/backend opt-in run is claimed.

READY FOR INDEPENDENT CODE REVIEW


## Independent code review remediation F5 — 2026-10-24

This section supersedes the earlier local code-review readiness with the actual targeted remediation. The previous21 checked tasks remain historical verified work; F5 adds3 remediation tasks for a total24. No publication is authorized. The independently reported lost refresh was confirmed against source: rejected ordinary admission returns an already-completed Future and did not retain editor demand. No F1–F4 contract was reopened.

### Baseline preservation

Before any edit, read-only gh PR check confirmed OPEN/Draft, cumulative codex/migrate-legacy-commands→main, exact e80dfbaf472ef1cc15b220a48df966509a9ee8a1. Dedicated branch/HEAD unchanged, index empty; initial12 tracked modifications and10 untracked files exactly match the prior apply's22-file manifest by SHA256, with no unexplained drift. Recorded porcelain-v2, complete binary tracked diff, index entries, individual untracked paths and copied all22 local files to `<evidence-dir>/admin-session-f5/before/`. All8 checkout inventories matched prior apply closure, including all7 other clean checkouts. No worktree recreation, branch change, restoration or untracked deletion.

Evidence directory: `<evidence-dir>/admin-session-f5` (manifest-before.json, tracked-before.patch, status-before.txt, index-before.txt, checkouts-before.json, PR-before.json). Existing ignored native runtime remains unchanged; no environment/dependency preparation was needed in F5. Actual SDK/foundation selection is unchanged from apply: Flutter3.47.5/Dart3.13.4, command_it9.5.2/listen_it6.0.0/gotrue2.27.2.

### Incremental implementation and state contract

Only two production files changed relative to the reviewed apply. `refreshAfterEditorChange()` synchronously records revision+waiter before scheduling, and the widget invokes it once on true after existing mounted/widget/Provider ownership guards. It performs no widget/context access afterward. Ordinary refresh admission still rejects busy lanes without queueing. A single coalesced microtask advances a file-local event-driven drain, using exact existing `_AdminExecution` receipts and their safe-settled flags. Wakes come from registration, safe read settlement and safe exclusive release/abort, not polling or notification availability.

A batch captures its highest pending revision before admission notifications can reenter. All earlier receipts, including unIgnore internal reads, are conservatively insufficient. Current batch main→optional ignored completes only its captured waiters; newer revisions require a later main, coalescing before that admission. Finishing each batch avoids dependence on a quiet event stream for older caller completion. Current filter is evaluated after main safe settlement; an established ignored demand survives lane occupancy. No captured selection is restored. Domain/raw terminals process the obligation without automatic retry, parent rethrow or duplicate reporting. Assertion keeps original fail-loud handling and aborts normal ignored continuation.

Dispose completes coordinator waiters normally immediately, clears coordinator ownership and permits no new work/publication. Physical read receipts remain independently retained to their real D1/D5 settlement. Queued pre-entry, old manual read, editor-owned main and editor-owned ignored disposal variants are all tested. Widget unmount after registration does not revoke a still-live VM; unmount/replacement before true return registers nothing. F2 atomic mutation success/pending navigation is unchanged, including while the additional editor read is pending. Auth/F4/router code are byte-for-byte preserved.

### Deterministic regression results

All tests use existing FakeAdminContentSubmissionRepository, AdminDashboardCommandHarness, command_test_support and disposal probe/virtual cleanup pumps. No test-support change/new helper, arbitrary sleep, new skip or suppression was introduced.

| Family | Controlled sequence and verified oracle | Actual result |
|---|---|---|
| F5.1 | Prior manual read pending→register→stale terminal→second read: distinct call, original obligation still pending, final updated list | PASS1 case |
| F5.2 | Register in mutation/ignored/main internal phase; no external read until release, internal order exact, one new main, mutation once, F2 pending ID8/readiness still published atomically | PASS3 variants |
| F5.3 | Same-turn3 events coalesce; newer event during main/ignored requires new batch; older captured main+ignored completes its own callers before new batch | PASS4 cases |
| F5.4 | Selected ignored lane occupied by old read; main settles, old ignored settles, fresh ignored admitted and awaited | PASS1 case |
| F5.5 | Toggle ignored→status and status→ignored during main; latest selection decides ignored phase without restoration | PASS2 variants |
| F5.6 | Dispose while behind manual read, before drain entry, during own main/ignored; coordinator completes while physical receipt/Command stays retained until response, no UI/new phase, replacement independent | PASS4 cases |
| F5.7 | Prior domain/raw terminal still triggers fresh read; own domain/raw terminal processes once and follows selected ignored, original runtime object/stack reported once, no mutation retry | PASS4 cases |
| F5.8 | Real open-editor/return true with stale read requires third call; false/null no invalidation; widget unmounted before return none; registered demand survives later widget unmount | PASS5 cases |
| F5.9 | Register in running notification/old terminal dispatch/safe settlement; fresh read once, no premature reopening or lost wakeup | PASS3 variants |
| Assertion | Fail-loud original assertion, coordinator acknowledgement once, no fabricated success/ignored continuation | PASS1 case |

Executed individual test names (structured reporter records each successful testDone with skipped=false):

| Test name | Result |
|---|---|
| F5.1 editor obligation waits for manual read then fetches fresh | PASS; executed, not skipped |
| F5.3 same-turn editor events coalesce before admission | PASS; executed, not skipped |
| F5.3 event during post-editor read requires a newer read | PASS; executed, not skipped |
| F5.3 captured batch finishes before newer pending changes | PASS; executed, not skipped |
| F5.2 editor change survives exclusive mutation phase | PASS; executed, not skipped |
| F5.2 editor change survives exclusive ignored phase | PASS; executed, not skipped |
| F5.2 editor change survives exclusive submissions phase | PASS; executed, not skipped |
| F5.4 ignored lane drains before a fresh selected ignored read | PASS; executed, not skipped |
| F5.5 final filter selection ignored=false controls second list | PASS; executed, not skipped |
| F5.5 final filter selection ignored=true controls second list | PASS; executed, not skipped |
| F5.3 newer event during ignored read restarts ordered refresh | PASS; executed, not skipped |
| F5.7 domain settles obligation once without retry or rethrow | PASS; executed, not skipped |
| F5.7 runtime settles obligation once without retry or rethrow | PASS; executed, not skipped |
| F5.6 dispose settles coordinator while physical receipt stays pending | PASS; executed, not skipped |
| F5.6 dispose before drain entry revokes queued coordination | PASS; executed, not skipped |
| F5.6 dispose during editor-owned read ignored=false | PASS; executed, not skipped |
| F5.6 dispose during editor-owned read ignored=true | PASS; executed, not skipped |
| F5 assertion abort settles obligation without ignored continuation | PASS; executed, not skipped |
| F5.7 prior manual domain still drains into a fresh read | PASS; executed, not skipped |
| F5.7 prior manual runtime still drains into a fresh read | PASS; executed, not skipped |
| F5.9 reentrant registration from running notification is retained | PASS; executed, not skipped |
| F5.9 reentrant registration from terminal notification is retained | PASS; executed, not skipped |
| F5.9 reentrant registration from safe notification is retained | PASS; executed, not skipped |
| AdminDashboardScreen F5.8 editor return true while stale read is active | PASS; executed, not skipped |
| AdminDashboardScreen F5.8 editor return false while stale read is active | PASS; executed, not skipped |
| AdminDashboardScreen F5.8 editor return null while stale read is active | PASS; executed, not skipped |
| AdminDashboardScreen F5.8 widget unmounted before editor return registers nothing | PASS; executed, not skipped |
| AdminDashboardScreen F5.8 registered change survives widget unmount with live owner | PASS; executed, not skipped |

### Commands actually executed

- Dashboard: `flutter test --no-pub --reporter expanded test/ui/admin/submissions/view_models/admin_submissions_view_model_test.dart test/ui/admin/submissions/view_models/admin_dashboard_command_lifecycle_test.dart test/ui/admin/submissions/widgets/admin_dashboard_screen_test.dart` → exit0, **123 passed/0 failed/0 skipped** (dashboard-gate-closed.log/json). Subsequent strengthened F2 assertions were exercised in the final full/individual F5 gates below.
- Focused aggregate: exact argv in focused.json (same eighteen paths as prior apply, including both Admin VM/screen suites, admin_route, ordinary lifecycle, four foundation suites, Settings/dependencies/events/sync/ownership/back routing) → exit0, **602 passed/0 failed/3 pre-existing skipped**. F1–F4 regression coverage retained; Auth46, Login10 and admin routing16 remain passing. No Auth/router/Logout change.
- Per-test F5: `flutter test --no-pub --reporter json --concurrency 1 --plain-name F5 test/ui/admin/submissions/view_models/admin_dashboard_command_lifecycle_test.dart test/ui/admin/submissions/widgets/admin_dashboard_screen_test.dart` → exit0, **28 passed/0 failed/0 skipped**, each event captured in F5-individual.jsonl and reconciled in F5-individual.json. This includes all final F2 readiness assertions and all F5 cases, not merely test source presence.
- Complete: `flutter test --no-pub --reporter expanded` → exit0, **3007 passed/0 failed/6 pre-existing skipped**, reported duration01:51 (full-suite.log/json). Delta is28 additional executed tests over prior2979. Skip declarations unchanged:3 upstream early-dispose late-StateError characterization bodies,1 Map-root Back upstream issue,2 local Supabase opt-in pipelines. Those6 bodies were not executed. No backend opt-in/CI/device smoke or external integration claimed.
- Discriminating red experiment: in the existing isolated `<evidence-dir>/unmount-red-snapshot` only, copied current VM/test and restored the copied PRE-F5 widget callback from the preservation snapshot. Ran exact F5.8 true/stale widget case: exit1,0 pass/1 fail, expected3 calls/actual2. The real worktree was never reverted. Corrected callback passes in all final gates. This demonstrates the original lost read.
- First owner test attempt:78 pass/1 fail due an over-strong new ignored-phase test expecting both callers to remain pending after the first caller's own main+ignored settlement. Corrected to per-caller semantics (first complete, newer pending). Captured-batch completion was then simplified and given its own no-quiet-period progress regression. No acceptance weakening, no runtime defect suppressed. Initial analyzer found3 cascade style INFO in new tests; fixed narrowly, no ignores.

### Analyzer after remediation

Actually executed `<flutter-sdk>/bin/cache/dart-sdk/bin/dart analyze --format machine` in the same worktree, exit0, stderr empty, **37 INFO/0 WARNING/0 ERROR**. Compared full raw diagnostic lines to prior apply B1 using Counter: equalitytrue, missing0/added0, including severity/type/code/path/line/column/span/message and multiplicity. No new position mapping needed in F5: the existing fake extension is untouched. Same residual33 Editor VM+1 Editor screen+3 fake diagnostics. No suppression, dependency/config change or opportunistic Editor migration. Exit0 does not imply zero INFO. analyzer-baseline.md remains byte-for-byte unchanged.

### Incremental and complete manifest

Same22 local diff files and same12 tracked-modified/10 untracked inventory. The8 incremental changes below are within the existing reviewed manifest;14 files are preserved byte-for-byte. Original F1–F4 normative delta is an exact prefix of current delta (new F5 requirement+13 scenarios appended only); original21 checked tasks remain intact, plus3 remediation tasks. .openspec.yaml, analyzer-baseline.md and proposal.md are unchanged. Proposal needs no adjustment because its declared Dashboard refresh ownership/surfaces already cover this targeted guarantee; no capability or feature scope added.

| Complete local diff path | F5 incremental purpose / preservation |
|---|---|
| lib/routing/router.dart | Preserved byte-for-byte from reviewed apply |
| lib/ui/admin/auth/view_models/admin_auth_view_model.dart | Preserved byte-for-byte from reviewed apply |
| lib/ui/admin/auth/widgets/admin_login_screen.dart | Preserved byte-for-byte from reviewed apply |
| lib/ui/admin/submissions/view_models/admin_submissions_view_model.dart | F5 API, revision batches, receipt-triggered drain and coordinator revocation |
| lib/ui/admin/submissions/widgets/admin_dashboard_screen.dart | One post-editor invalidation call, existing ownership guards retained |
| openspec/changes/migrate-admin-session-commands/.openspec.yaml | Preserved byte-for-byte from reviewed apply |
| openspec/changes/migrate-admin-session-commands/analyzer-baseline.md | Preserved byte-for-byte from reviewed apply |
| openspec/changes/migrate-admin-session-commands/design.md | F5 evidence, state machine, lifetime and acceptance trace |
| openspec/changes/migrate-admin-session-commands/proposal.md | Preserved byte-for-byte from reviewed apply |
| openspec/changes/migrate-admin-session-commands/specs/command-execution-concurrency/spec.md | Append13 F5 scenarios under one added requirement; original delta preserved |
| openspec/changes/migrate-admin-session-commands/tasks.md | Preserve21 original checked tasks; add3 remediation tasks |
| openspec/changes/migrate-admin-session-commands/validation.md | Incremental evidence, commands/results, diagnostics and integrity |
| test/routing/admin_route_test.dart | Preserved byte-for-byte from reviewed apply |
| test/support/admin_dashboard_command_harness.dart | Preserved byte-for-byte from reviewed apply |
| test/support/fake_repositories.dart | Preserved byte-for-byte from reviewed apply |
| test/support/mock_gotrue_client.dart | Preserved byte-for-byte from reviewed apply |
| test/ui/admin/auth/view_models/admin_auth_lifecycle_test.dart | Preserved byte-for-byte from reviewed apply |
| test/ui/admin/auth/view_models/admin_auth_view_model_test.dart | Preserved byte-for-byte from reviewed apply |
| test/ui/admin/auth/widgets/admin_login_screen_test.dart | Preserved byte-for-byte from reviewed apply |
| test/ui/admin/submissions/view_models/admin_dashboard_command_lifecycle_test.dart | 23 deterministic F5 owner/lifecycle cases |
| test/ui/admin/submissions/view_models/admin_submissions_view_model_test.dart | Preserved byte-for-byte from reviewed apply |
| test/ui/admin/submissions/widgets/admin_dashboard_screen_test.dart | 5 real-editor callback regressions, owner-keyed fixture unmount |

Final integrity commands, incremental patch/hash manifest, task closure and readiness follow after the final checks. The earlier code-review readiness above remains historical; this remediation requires independent CODE RE-REVIEW before any publication.


### F5 final closure

Final verification completed: `openspec validate migrate-admin-session-commands --strict` exit0; `openspec status --change migrate-admin-session-commands` exit0,4/4 artifacts complete; apply instructions report **24/24 tasks complete** (original21 plus remediation3). `git diff --check` exit0; format verification on the four incremental Dart files exit0/0 changes; all22 local files checked for whitespace, newline and symlink containment. Complete manifest unchanged in paths;8 incremental files,14 preserved byte-for-byte. Final SHA256 manifest and incremental unified patch saved as manifest-final.json/incremental.patch in the F5 evidence directory, separately from the complete tracked diff including preserved prior apply work.

HEAD/branch unchanged: e80dfbaf472ef1cc15b220a48df966509a9ee8a1 / codex/plan-migrate-admin-session-commands. Index entries exactly match preflight, staged diff empty. Final12 tracked modifications and10 untracked files are the same inventory as before F5. All7 other checkout inventories match their initial HEAD/branch/index/tracked/untracked state exactly, including main. Final PR read-only check equals preflight: OPEN/Draft, unchanged cumulative branch/head/base. Auth, Logout responsive rendering, router, Editor, foundation, repositories/domain/backend/DI/dependencies and all unrelated surfaces were preserved relative to reviewed apply. No staging, commit, push, PR update, archive, merge or checkout synchronization.

No residual material F5 finding identified. Guarantees concern post-change admission/processing, not successful repository Results or backend replication latency. Physical nontermination remains possible while live; dispose always releases local coordinator waiters without cancelling physical work. Existing six skipped bodies, CI/device/backend opt-in execution and independent code re-review are not claimed as performed. The independent code re-review remains mandatory before separate publication authorization.

READY FOR INDEPENDENT CODE RE-REVIEW
