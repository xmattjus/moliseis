# Planning validation and adversarial self-review

## Published checkpoint

This migration was published in Draft [PR #12](https://github.com/xmattjus/moliseis/pull/12) as commit [`52d4e448d010d2d13c13a4d3d665cdf5b1b0103b`](https://github.com/xmattjus/moliseis/commit/52d4e448d010d2d13c13a4d3d665cdf5b1b0103b), whose parent is `0cdb764a7586f85180a802fafcf2b485791cb5ff` (verified from Git history). All seven migrations are now published. The historical analyzer transition for this checkpoint was **37 → 0 INFO**; these are recorded checkpoint results, not analyzer runs performed during reconciliation. Planning assumptions, local-only authorization and uncommitted-work statements below describe their original phases. Subsequent publication supersedes those status statements without changing the historical evidence. Canonical synchronization, archival, legacy compatibility deletion and merge remain outside this reconciliation.

## Evidence provenance

Recorded artifact SHA-256 values and byte-for-byte preservation claims below refer to the original apply/remediation revisions in the published checkpoint, before this documentation reconciliation. They are not hashes of the revised narrative files. Diagnostic records and machine-readable evidence remain unchanged.

Historical local apply and CR1 results below are preserved in tracked `apply-verification.json`, the analyzer companions and the test manifest. Recorded source hashes and results describe those executions; they are not fresh reconciliation runs or proof that an external runtime stack was available. No latest-head GitHub Actions result is inferred from historical local tests; check PR #12 for checks attached to the exact published SHA.

## Initial planning record — historical

The record below belongs to the initial planning turn. Its author self-review is superseded where necessary by the independent-review remediation section at the end; it is not evidence of a second independent review.

### Scope and actual execution

Planning only, 2026-10-24. No production, test, backend, SQL, dependency, CI, foundation or canonical-spec edits. No apply, commit, staging, push, merge, rebase, cherry-pick, PR update, archive or sync. All implementation tasks remain unchecked. Two read-only exploration agents supplied source maps; the main author reconciled them with source, dependency implementation and specifications. No independent plan review was requested or performed in this turn.

| Check actually performed | Outcome |
|---|---|
| GitHub get_pr_info, list_pull_request_review_threads, list_pull_request_reviews | PR #12 open/Draft, exact head `0cdb764a7586f85180a802fafcf2b485791cb5ff`; base main; review findings recorded in design Context. Final API head recheck still matches. |
| Git worktree/branch preflight | Requested destination and branch absent; created from exact authorized SHA after sandbox permission for Git metadata. Primary checkout and existing worktree branches not moved. |
| Shell remote lookup | Failed DNS resolution; not treated as evidence. Connected GitHub metadata supplied the verified head. |
| Initial Flutter launcher | Failed on restricted SDK-cache write; did not produce analyzer/test results. |
| Authorized offline `flutter pub get --offline` in dedicated worktree | Exit 0; ignored package metadata prepared; no tracked lockfile/config changes. No upgrade/generation. |
| Direct installed Dart `analyze --format machine` | Exit 0, 37 INFO, zero WARNING/ERROR, stderr empty; independent replay reconfirmed count. Full durable relative-path records and hashes in analyzer-baseline.md. |
| OpenSpec CLI `--version`, list/context, capability inventory, schema instructions/status | Version 1.14.3, existing repo-local root, spec-driven schema; proposal/design/specs/tasks instructions read. All four planning artifacts reported done after creation. CLI isComplete here means planning artifact availability, not implementation completion. |
| `openspec validate migrate-admin-editor-commands --type change --strict --no-interactive` | Exit 0, change valid. Repeated after final planning corrections. |
| Requirement-name collision scan against other change/canonical spec.md files | No collision for newly added editor requirements; no competing MODIFIED replacement of migration-1 shared requirement. |
| Artifact containment, trailing-whitespace and local-absolute-path checks | All new files resolve inside this change, no trailing whitespace, no workstation paths. |
| `git diff --check`, tracked/staged diff inspection | Exit 0; tracked/staged diff empty. New artifacts are untracked and were checked separately, so empty git diff is not presented as proof of no new work. |
| Final all-worktree HEAD/status inspection | Primary/app checkout and six earlier persistent worktrees have zero tracked/untracked status entries and their recorded HEADs. Dedicated worktree has only this change's new planning files. |
| Runtime tests, Flutter analyzer frontend, local-stack integration tests | NOT RUN. Planned scenarios and future command gates are in test-plan.md; no historical pass count is substituted for current evidence. |

### Initial author self-review findings and planning corrections

These are findings against an initially naive migration or this draft plan, not claims of implemented fixes. Evidence references are checkpoint-relative; corrections are now part of the normative plan. Acceptance scenarios remain unexecuted until an authorized apply.

| ID / evidence | Failure mode | Correction integrated into design/specs/tasks | Acceptance test |
|---|---|---|---|
| SR1 — command_it 9.5.2 `run:312-412`; editor guards `:460-469,567-599` | Replacing running flags with deferred snapshots permits simultaneous mutation admission or overwrites a captured intent. Reentering on first idle risks old finally clearing new running. | D1 reserve before notify/run, complete directed matrix and immutable receipt; D7 guarded safe reopening. False admission has no snapshot/queue; busy-error semantic change explicit. | A1–A3/A5, tasks 2.1–2.3; hold first entry and dispatch, count exact calls and independent retry. |
| SR2 — editor Save `:507-519`; screen Save handler `:123-147` | Successful Save clears dirty/pops while newer fields exist; a dialog latch can also outlive its private receipt. | D2 persisted revision association retained with matching terminal snapshot after receipt retirement; D6 clean revision rechecked at dialog return. No create ID adoption. | S1/S2/W1/W2, tasks 3.1/7.2; release Save then retire receipt while dialog stays open before confirm/cancel. |
| SR3 — Load `:404-457`, operationRunning `:275-283` | Public Load can overwrite an accepted Save/asset/moderation or dirty draft. An artificial test hook could make impossible races appear required. | D1 exclusive public Load, loaded dirty refusal; D3 persisted setters refuse during Load; private resolution helper uses outer ownership. Revision guard remains defensive. Tests use actual public transitions, no injected revision bypass. | A2/S3/S4, tasks 2.2/3.2; held hydration then stale field callback and every conflicting request. |
| SR4 — KeepCurrent `:747-792` | Nested public Save/Preview would self-reject or pop, stale group callback could copy unrelated values, and dispose path currently fabricates success. | D2 one outer receipt, current-preview group membership, complete group copy, private phases and revoke-before-next-call. | K1–K4, tasks 3.3/3.4; ordered update/preview Completers, failures and reentrant disposal. |
| SR5 — candidates `:685-701`; target/preview `:163-169,703-745` | Text/target A→B→A and old public success can restore stale candidates or Apply readiness. Naive hash invalidation can revoke the very current preview being installed. | D4 desired-input/context revisions, explicit ordinary single-flight refusal, stale snapshot suppression, current preview+hash atomic installation, conflict requires fresh preview. | Q1–Q5/M5, tasks 5.1/5.2/4.3; old responses released after invalidation/current commit, no hidden requests. |
| SR6 — moderation/refresh `:601-683,794-845`; source/token RPC contracts | Cross-intent ack/hash mutation, lost pendingId from Reject mapping, raw refresh swallowed as success or double-reported by nested Commands. | D3 capture payload before invalidation, retain Reject resolution until original→follow-up chain ends; direct phases own one outer runtime failure; expected read error retains original mutation outcome. | M1–M6, tasks 4.1–4.3; exact payload/token checks and controlled per-phase failure/disposal. |
| SR7 — asset chain `:847-951`; current dispose `:968-974` | Cancelling upload while SQL association/delete is pending falsely implies remote cancellation; early disposal loses original late raw failure. | D5 phase table, confirmed-list policy, task cancel once and honest irreversible mutation; D7 retain active command through actual settlement. | U1–U3/L2, tasks 6.1/6.2; cancellation/count assertions at every held phase. |
| SR8 — screen `:46-75,286-437`; route `:276-322` | Retained screen owner replacement leaves old listeners; replayed terminal snapshots pop twice; stale dialog finally clears newer flags; post-unmount callback dereferences widget/context. | D6 exact-owner rebinding, consumed-terminal identity before effect, route-exit latch, guarded dialog-session finally and mounted/current owner checks; router entry remains one synchronous request. | W1–W4/L1, tasks 7.1–7.4; real route replacement, old terminal/delayed dialog release and full transition pumps. |
| SR9 — draft setters `:286-402`, moderation success pop in screen | Allowing new persisted fields during resolution can leave a dirty draft that success makes read-only and then discards. | D3 rejects persisted setters during non-Save mutations; Save permits later edits with D2 revision safety. Internal KeepCurrent copy alone uses outer private authority. Target change is refused during any mutation. | A2/M1/K3/W2; verify no field/revision mutation on refused callbacks and no loss of admitted Save edits. |
| SR10 — previous migration records and stale workflow proposal | Copying old artifacts could import absolute paths, unverifiable temporary evidence, completed checkboxes or Save-in-place/ID-adoption behavior. | Current proposal explicitly excludes stale capability/workflow; complete relative B0 evidence is bundled, tasks remain 0/27, only existing capability paths extended. | Artifact/source-scope audit, baseline checksums and strict validation; task 8.1/8.6. |

### Initial residual limits and readiness — historical

No known unresolved material planning contradiction remains after those corrections. This conclusion is an author self-review, not independent approval and not runtime evidence. Independent review should challenge especially the explicit busy-refusal change, asymmetric preview/mutation matrix, safe terminal barrier, terminal Save revision retention and raw-refresh-after-commit failure boundary.

Known limits remain physical nontermination/resource retention, best-effort upload cancellation, response-loss ambiguity on create/assets, server-side concurrency after client preflight, and a raw refresh failure after a remotely successful mutation. All are explicit in design and future acceptance. No backend contract contradiction was demonstrated; no backend change is proposed. The three existing PR review threads remain unresolved external findings and are not silently closed by this plan.

Actual diff: only new files under `openspec/changes/migrate-admin-editor-commands/`: metadata, proposal, design, tasks, two capability deltas, analyzer ledger with machine/JSON companions, deterministic test plan and this validation/self-review record. No tracked file or index change. Ignored Flutter preparation metadata is local verification setup, not part of the proposed diff. No implementation work began.

## Independent plan review remediation — F1–F3

### Preflight and authorized scope

User supplied an independent review identifying F1/F2 as P1 blockers and F3 as a minor observation. This turn is planning remediation only. HEAD and branch were verified before artifact writes: `0cdb764a7586f85180a802fafcf2b485791cb5ff`, `codex/plan-migrate-admin-editor-commands`. Connected GitHub get_pr_info reconfirmed PR #12 open and Draft, head `codex/migrate-legacy-commands` at that exact SHA, base main. Dedicated index/HEAD tracked diff was empty; exactly the eleven expected untracked artifacts were present and belonged to this change. No ownership drift or unexpected content was found. Existing worktree names/HEADs match the initial inventory; primary, detached app checkout and all six prior migration worktrees had zero status entries. Reused the dedicated worktree without switching, recreating, resetting or realigning anything.

Read all current artifacts, schema/config and the relevant actual `AdminSubmissionsViewModel` observer/settlement/disposal code. Followed openspec-update-change within the user's explicit edit authorization. Only five existing documentary artifacts were changed: design.md, specs/command-execution-concurrency/spec.md, test-plan.md, tasks.md and this validation.md. No production, Dart test, repository/backend/SQL, dependency, CI, foundation, canonical-spec or other-change file was changed. No runtime test/analyzer/pub command ran during remediation, no B0 regeneration/B1, no commit/staging/push/PR update/merge/rebase/cherry-pick/archive/sync.

### Finding closure matrix

| Finding and original evidence | Definitive implementable decision | Changed artifacts and acceptance | Residual limit / disposition |
|---|---|---|---|
| F1 — P1: initial D1 persistent eleven lanes versus initial D7 “after safe settlement remove private observers and dispose each command” | D1/D7 distinguish one owner-lifetime physical Command per lane from monotonic per-execution receipts. Install private results/running observers once before forwarding; retain them across live settlements. Barrier releases only identical receipt/reservation. Revoke detaches forwarding immediately; idle Commands release deferred, active Commands/private observers remain until actual safe settlement, then dispose once. Reuse migration-6 microtask→event recipe without its coordinator. | design D1/D6/D7; command-execution-concurrency existing revocation/result requirements and retry scenarios; tasks 2.1–2.4; test-plan RF1.1–RF1.4 and RF3.1. Failed Save→successful Save, two explicit searches, terminal reentry, old-finally isolation, second-run disposal and stable observer/disposal counters are specified with held gates and release order. | A physically nonterminating operation retains its Command/private observers; no fabricated timeout/cancellation. **CLOSED** in planning; runtime acceptance remains for apply. |
| F2 — P1: initial D4 called the input setter from parameterized search request before checking admission, contradicting D1 inert refusal | Exactly `void setCandidateSearch(String value)` and `bool requestFindCandidates()`. Setter alone edits desired input, increments revision and invalidates stale candidate data/feedback without I/O or accepted-slot overwrite. Request checks live/matrix/lane first; false allocates no receipt/ID and changes no input/snapshot/feedback. True captures current normalized input in a no-param private Command receipt, blank→null. | design consumer manifest/D1/D4/D6 and matrix explanation; command-execution-concurrency explicit-read/admission scenarios; tasks 2.2/5.1/7.3; test-plan A2/A5/Q1/Q2 and RF2.1–RF2.3. Separately measure setter event then refused request, release old A, explicitly admit B; ABA and stale Error/raw variants, mutation/Load overlap and blank query. Remove Screen _eventSearch; onChanged uses setter, button uses no-param request. | Search stays explicit single-flight: a rejected search is never queued; user retries after physical settlement. **CLOSED**. |
| F3 — minor: missing execution isolation for repeated/equal outcomes, consumed effects and Save revision metadata | D6 separates receipt ID, Result/snapshot value, `(owner,lane,terminal execution ID)` effect key and `(Save ID,persisted draft revision)` closure association. Every admission has fresh ID/running; stable observers target only current receipt. New Save admission clears previous closure association before notification; own terminal association survives only its receipt settlement, never a later Save. Bind-time existing terminals seed consumption. | design D1/D6/D7; existing result/Save/navigation requirements and equal-result/rebind/retry scenarios; tasks 2.3/7.1/7.2; test-plan RF1.2/RF3.1/RF3.2. A Success→B Error→C identical Success uses distinct IDs, one error feedback, current latch only; owner X→Y late completion stays isolated. | Equal Result values cannot distinguish attempts; explicit execution IDs are required. Existing late-work physical effects remain separately documented. **CLOSED**. |
| DF1 — derived from F3: an old successful Save latch invalidated by a later failed clean Save could fall through to confirmed moderation | D6 explicitly returns without pop or moderation when a dialog consumed a Save success whose association was superseded and not replaced by a matching current success. A later same-session C success can replace the latch with its own ID. No new requirement or workflow; refines existing dialog completion authority. | design D6; added scenario under existing navigation requirement; tasks 7.2; RF3.1 clean-B-error branch closes dialog before C and requires zero pop/moderation despite clean fields. | No automatic Save/moderation retry. A fresh explicit interaction is needed after invalidation. **CLOSED**. |

Initial author self-review rows SR1–SR10 remain historical source rationale, not independent F1–F3 closures. The matrix above is the current disposition. No finding is closed merely by prose: each has a concrete ownership/API/effect decision, a deterministic counterexample acceptance and applicable future task. These tests are specified, not executed.

### Recheck of previously accepted areas

- **KeepCurrent:** D2 unchanged byte-for-byte. One outer receipt still owns copy→private Save→private Preview; no nested public admission, inner Save terminal or receipt. D7 now explicitly forbids detaching persistent observers after such an execution. K1–K4 retained.
- **Save draft/create behavior:** D2 unchanged byte-for-byte: deep immutable request, newer dirty revision retained, no ID adoption/autosave. D6 only correlates its existing closure rule to execution ID across retries and receipt settlement. S1–S4 retained; RF3.1 strengthens the retry/dialog boundary.
- **Moderation:** D3 and the provenance delta unchanged byte-for-byte. Distinct Reject/Promote/Link/Apply payloads, exact acknowledgement/hash/opaque tokens, source-change refresh and original-outcome policy remain intact. M1–M6 retained.
- **Assets:** D5 unchanged byte-for-byte. Picker/upload/association/delete cancellation limits and confirmed-list authority remain; persistent lane cleanup clarifies when physical resources may be disposed, without remote rollback claims. U1–U3 retained.
- **Dialog/navigation:** Existing owner guards, exactly-once pop(true), latch surviving its receipt settlement and no unmount/replacement effects remain. Only ID correlation and derived DF1 needed contractual clarification; no new navigation path or UI experience.
- **Determinism/KISS/YAGNI:** All 35 original scenario IDs/families remain with controlled Future ordering; nine RF subcases refine acceptance, not substitute existing coverage. Stable observers and local receipts reuse migration-6 mechanics; no global scheduler, generic orchestration framework, duplicate input state or additional capability/requirement name.

### Final adversarial walkthroughs

1. Live Save Error settles receipt 1 only; same physical lane and observer pair accept receipt 2. Terminal reentry stays false until microtask→event; a queued old barrier checks settled/identity and cannot release receipt 2. Owner revoke during receipt 2 detaches forwarding, retains its private observers until the real Future settles and then releases the physical instance once.
2. A input/request pending → setter B → false request has no extra effect; setter A increments revision again. Old A Success/Error cannot publish. Old raw A still reports original error/stack once. Only a later true no-param request captures the current desired input. Input editing during mutation does not touch mutation input/receipt or issue I/O; public Load still blocks the search request alone.
3. Save A success is consumed once and remains close-authorized after its own receipt settles while a dialog stays open. B admission clears A authority; B Error cannot inherit it. C same-value Success gets a new ID/revision association and may close exactly once. DF1 branch with no intervening draft edit and B Error cannot fall through to moderation. A terminal already present at bind is seeded, never replayed; replacement owner has independent IDs/consumption.
4. Physically pending work after revoke retains its command until actual settlement, preserves original raw reporting, starts no new private phase and publishes nothing. Nontermination is an explicit retained-resource limit. All next-phase checks continue to use exact outer receipt identity.
5. Cross-artifact reread confirms D1/D4/D6/D7, existing delta requirements, 27 unchecked tasks and RF acceptance use the same request signature, ownership lifetimes and effect identities. No parameterized search overload or per-execution Command disposal instruction remains. Public input edit and execution admission are separately observable events.

### Executed remediation validation and integrity

- `git status --porcelain=v1 --untracked-files=all`, `git branch --show-current`, `git rev-parse HEAD`, staged/HEAD diff checks and all-worktree HEAD/status snapshots: authorized baseline, eleven expected artifacts only; no unrelated tracked/staged edits. Final comparison uses initial per-worktree HEAD/status and exact preserved artifact bytes, including other-change files.
- Connected GitHub `get_pr_info`: exact authorized PR head/open/Draft reconfirmed before edits and at final preflight. No remote mutation was invoked.
- `openspec list --json`, `openspec status --change migrate-admin-editor-commands --json`, `openspec instructions design --change migrate-admin-editor-commands --json`: existing local root/schema and existing artifact paths verified; no artifact creation or workflow advancement.
- `openspec validate migrate-admin-editor-commands --type change --strict --no-interactive`: exit 0, valid after remediation; repeated after final corrections. This does not claim runtime behavior or independent review approval.
- Direct artifact checks, including all untracked documents: UTF-8/newline/whitespace, no local absolute paths, resolved-path containment, Markdown heading/table/fence consistency, every requirement has scenarios and descriptions stay within strict length, unique names with no conflicts against other delta/canonical requirements. No new requirement names were introduced. An initial signature-check regex wrongly consumed the closing parenthesis of the no-argument call and reported a false positive; the corrected argument-aware check passes without an artifact signature change.
- B0 checksum/byte comparison: metadata and all three baseline files below are identical to pre-remediation; JSON still records 37 INFO/zero WARNING/ERROR. Recomputed SHA-256 verifies the ledger's stored hashes without regenerating analyzer output. Proposal and provenance delta also remain exactly unchanged.
- `git diff --check` and staged/HEAD diff checks pass; direct text checks and pre/post document comparison cover the untracked artifacts as well. Exact remediation diff and overall untracked inventory are reported separately; empty tracked diff is not a claim that planning did not change.
- Runtime tests, integration tests, analyzer, dependency preparation, implementation, publication and independent re-review: **NOT RUN** during remediation. All 27 apply tasks remain unchecked.

| Preserved artifact | SHA-256 before = after |
|---|---|
| .openspec.yaml | `e2ebaebee255ccc1e09b64ba38d9b09c360a7392fc110a48ca2525e1ea49fa46` |
| analyzer-b0.json | `71289bd326ba14116772a61db8af498ca1b66e35b2c53fb316882f6edfb4d910` |
| analyzer-b0.machine.txt | `d3d479bc73bf5acdcb365303621f8a8360c4c347d77cdac7da75f5d3329eeac6` |
| analyzer-baseline.md | `20befda46df2c0494225184307a47cea427d5a66b820bcbd233482c8e6a34e91` |

Current disposition: F1, F2, F3 and derived DF1 CLOSED in planning, no known unresolved material contradiction after author adversarial recheck. The next gate is a second independent plan review. This remediation is neither that approval nor authorization to implement. Known physical/remote limits from design remain unchanged and explicit.

## Authorized local apply — executed evidence

### Authorization, isolation and dependency reality

The user supplied independent plan approval, including F1/F2/F3/DF1 remediation, and explicitly authorized complete local apply, tests and verification. This section supersedes historical statements above about unchecked tasks or implementation not having started; it does not rewrite the planning record. No independent code review or remote CI result is claimed.

Preflight and final connected GitHub `get_pr_info` reads verified PR #12 open, Draft, unmerged, head branch `codex/migrate-legacy-commands`, exact SHA `0cdb764a7586f85180a802fafcf2b485791cb5ff`. Dedicated branch remains `codex/plan-migrate-admin-editor-commands` at that same SHA. Initial index and tracked diff were empty; the eleven approved untracked artifacts were preserved. No checkout recreation or branch movement occurred. Final inspection verified primary/main, detached app checkout and all six prior migration worktrees clean at their original HEADs (portable inventory in apply-verification.json). The dedicated index remains empty. No commit, push, PR update/thread resolution, merge, rebase, cherry-pick, archive, canonical synchronization or legacy deletion occurred.

Read all approved artifacts and applicable instructions/skills, ResultCommand/reporting/restartable and migration-6 implementation, actual locked command_it 9.5.2 source and existing repository/backend contracts. Its deferred entry, terminal dispatch, finally and late-throw behavior support the approved microtask→event barrier; runAsync is not used for admission or physical settlement. Production integration was owned by one main agent; bounded agents handled ViewModel, test/support and read-only internal audit. That audit is not the subsequent independent code review.

### Implementation and finding closure

| Lane (private reusable ordinary ResultCommand) | Public synchronous admission API |
|---|---|
| Load | `bool requestLoad()` |
| Save | `bool requestSave()` |
| Reject | `bool requestReject()` |
| Promote | `bool requestPromote(AdminPromotionTarget target)` |
| Link | `bool requestLink(int target)` |
| Preview | `bool requestPreview()` |
| FindCandidates | `bool requestFindCandidates()`; separate `void setCandidateSearch(String value)` |
| Apply | `bool requestApply()` |
| KeepCurrent | `bool requestKeepCurrent(AdminEventMergeGroup group)` |
| AddAsset | `bool requestAddAsset()` |
| DeleteAsset | `bool requestDeleteAsset(int assetId)` |

All lanes expose cached Result-aware snapshots and execution IDs, not Command handles. Shared local lane/receipt bookkeeping stays inside the editor ViewModel; no global scheduler, foundation modification or generic orchestration framework was introduced.

- **D1/F1:** eleven owner-lifetime instances, immutable per-admission requests and distinct monotonic execution IDs. Reservation precedes notification/deferred entry. The exact directed matrix is exercised for all 121 pairs in both pre-entry and physically pending phases, both release orders (484 traces), plus composed Preview+Candidates. False admission changes no receipt, snapshot, desired input or I/O and never queues/retries. Stable private observer pairs survive live settlement. Identity/revision checks at the microtask→event barrier release only the matching receipt/reservation. A live Command is not disposed per attempt.
- **D2:** deep-immutable AdminSubmissionInput captures nested Delta plus draft revision. Create/update uses immutable route identity; create ID is not adopted. Later Save edits remain dirty and cannot authorize closure. Public Load refuses dirty loaded editors and is exclusive; persisted setters reject Load/non-Save mutations. Hydration checks captured draft authority. KeepCurrent owns copy→private Save→private Preview under one receipt, with current group identity, no nested public lane or Save completion effect, and revoke checks at each phase.
- **D3:** existing repository boundaries/payloads retain distinct Reject/Promote/Link/Apply semantics, exact IDs, acknowledgement/hash and opaque token strings. Resolution performs original-ID refresh before optional follow-up. Expected read errors retain original resolution outcome/data; raw private-phase failure is reported once through the outer Command. Source/token conflict invalidates Apply authority; no automatic remote mutation retry or transactional client emulation.
- **D4/F2:** setter owns desired candidate text and monotonic invalidation without I/O. No-param explicit single-flight request first checks admission, then captures normalized query (blank→null), without query parameters/log data on the Command. ABA, stale Success/Error/raw and mutation overlap are tested. Preview generation/context and current hash installation prevent stale Apply readiness.
- **D5:** asset picker→upload task→repository association, confirmed list changes only, exact captured delete membership. Owner disposal cancels an active task once, starts no unstarted association, and never claims rollback of an already executed remote mutation.
- **D6/F3/DF1:** one current-owner public effect observer; rebinding seeds pre-existing terminal consumption. Effect identity is owner/lane/execution ID, independent of Result equality and persisted-draft revision. New Save admission revokes older closure authority before notification; its own terminal authority survives receipt settlement. Status-dialog latch is execution/session scoped, including A Success→B Error→C equal Success and clean-B-error DF1 branch. An invalidated old success authorizes neither pop nor moderation. Mounted/current-owner guards protect status/delete dialogs, fields and callbacks; one pop(true) maximum. Owner-keyed search field retains same-owner text and resets correctly on replacement; Screen _eventSearch removed. Router change is only edit bootstrap requestLoad once.
- **D7:** revoke immediately rejects new intentions and detaches forwarding. Idle resources retire deferred; active Command and private observers remain through physical settlement, preserving original raw error reporting once even past upstream teardown. Identity-safe cleanup runs outside dispatch and disposes each physical Command once. Fail-loud assertions are not normalized into Success. Nonterminating physical work intentionally retains necessary private resources; tests inspect before releasing only for cleanup.

F1, F2, F3 and DF1 are implemented and runtime-covered (CLOSED); no derived architectural contradiction remains. The previously accepted Save/create, KeepCurrent, moderation/source, asset and dialog behavior remains within D1–D7. The stale workflow change is not integrated.

### Executed gates and reproducibility

Flutter 3.47.5 / bundled Dart 3.13.4, command_it 9.5.2. All Flutter tests ran with TZ=Europe/Rome and `--no-pub --reporter expanded`. The sandboxed Flutter launcher initially could not write the SDK cache; authorized execution invoked installed Dart with its bundled flutter_tools.snapshot and obtained the SDK lock. This runs the same Flutter subcommands, not a substitute test runner. Existing ignored ObjectBox dylib from the primary checkout was copied into the dedicated ignored lib directory, SHA-256 `1af2e266e523dbcc33b3682eebf297f2f4f23ade6ab706dab794f7a6f8108751`; no native runtime, dependency/lockfile or generated source is part of the diff.

| Gate / actual command | Pass | Fail | Skip | Exit / evidence |
|---|---:|---:|---:|---|
| A: `TZ=Europe/Rome flutter test --no-pub --reporter expanded <five editor suites>` | 506 | 0 | 0 | 0; VM existing 97 + new commands 62 + matrix 243 + phases 33 + Screen 71 |
| B: same command with explicit route/dashboard/shared fields/admin repository/foundation/prior-lifecycle selection | 520 | 0 | 3 | 0; exact twelve paths in apply-verification.json; includes real admin router 35 cases |
| C: same command with complete explicit CI manifest | 3373 | 0 | 4 | 0; autonomous-test-manifest.txt: 160 sorted files, SHA-256 `c0be3cce82129b302bf6d491286a82217336a88b1071cd29eb0185528e8647d0` |
| D: token pipeline and all-day local-stack integrations | — | — | — | **NOT RUN**; Docker daemon socket absent; docker info exit 1 |
| E: `dart analyze --format machine` | — | — | — | 0; stdout/stderr empty; zero INFO/WARNING/ERROR |
| E: separately `flutter analyze --no-pub` | — | — | — | 0; “No issues found!” |
| F: `dart format --output=none --set-exit-if-changed <12 changed Dart files>` | — | — | — | 0; 12 files, zero formatting changes |

Gate C selects exactly every test/**/*_test.dart except test/integration/** as pull-request.yml does; no name filtering, new skip, weakened assertion or CI modification. Four existing skips: one Map-root navigation upstream issue and three command_it late-StateError-after-dispose characterization cases. Gate B contains those three foundation skips. Integration files are excluded by manifest, not counted as passing/skipped executions. Deno, Supabase and Docker CLIs exist, but the Docker daemon socket is absent and no preconfigured running local Supabase schema/Auth/API/PostgreSQL stack was available. No stack was created and no backend migration/deployment/secret configuration attempted. This leaves local-service end-to-end token/all-day coverage unexercised; repository token/ack contracts and autonomous all-day behavior passed. Task 8.4 explicitly permits a documented prerequisite outcome; this environmental limit does not demonstrate an editor defect or block the mandatory autonomous gate.

Preliminary focused runs caught transient mechanical Screen edit/analysis errors and two widget fixture expectations, corrected before final gates. A retained-State dialog rebind test uses a controlled StatefulBuilder because router refresh removes pageless dialogs; actual production router replacement/auth redirect is separately tested. One new test initially compared Result wrapper identity across an existing mapping; its oracle now checks the actual void-result contract. Internal audit found a missing settlement-probe counter increment; corrected, with runtime counter assertions passing. A verification script initially used Counter.total unavailable in system Python and was rerun with sum(values); it changed no runtime source. No preliminary failed run is presented as a final pass. No unresolved production failure was hidden, skipped or fixed out of scope.

### Coverage of the approved plan

Abbreviations below refer to actual executed suites: **VM** = existing admin_submission_editor_view_model_test.dart (97); **Commands** = new admin_submission_editor_commands_test.dart (62); **Matrix** = new admin_editor_admission_matrix_test.dart (243); **Phases** = new admin_editor_phase_test.dart (33), all under test/ui/admin/submissions/view_models. **Screen** = admin_submission_editor_screen_test.dart (71); **Routes** = test/routing/admin_route_test.dart (35). Existing cases were adapted, not removed. Controlled Completers, existing fakes/picker/upload task and shared event pumps drive order; known upstream 50ms teardown is advanced only using the virtual test clock.

| Original scenario families (all 35) | Executed coverage |
|---|---|
| A1/A2/A3/A4/A5/A6 | Matrix all lanes/pairs/pre-entry/pending/composed reads and both releases; Commands immutable nested input, neutral/expected/raw/assertion and reentrant retry; VM validation boundaries |
| S1/S2/S3/S4 | Commands create/update × success/expected/raw, newer dirty revision, Load/setter exclusivity and retry; VM field/date/coordinate/identity contracts |
| K1/K2/K3/K4 | VM all five copy groups and failure short-circuit; Phases private-preview expected/raw after successful Save, old-group rejection, revoke at copy/Save/saved-notify/Preview; Commands late runtime |
| M1/M2/M3/M4/M5/M6 | VM exact payload/ack/hash/token, source-change and follow-up; Phases per-original/follow-up expected/raw refresh, both token conflicts/fresh-preview retry and three refresh-chain revoke boundaries; Matrix interleaving; Routes mutation late outcomes |
| Q1/Q2/Q3/Q4/Q5 | Commands query ABA × success/expected/raw, explicit B/null and mutation overlap; Phases preview ABA and both Save completion orders; Matrix remaining allowed preview/mutation pairs; VM current changed source hash and acknowledgement |
| U1/U2/U3 | VM picker/capacity/upload/association/delete success/error contracts; Phases picker/upload/association revocation; Matrix captured delete conflicts; Commands all-lane raw/disposal; Routes asset replacement |
| W1/W2/W3/W4 | Screen existing confirmation/Save/asset feedback plus execution-ID retry, DF1, bind-time terminal seeding, retained-State owner rebind and search text; Routes actual owner replacement/auth redirect while Save/Reject/Delete pending |
| L1/L2/L3 | Phases all eleven before-entry revoke; Commands all eleven × StateError/TypeError/AssertionError beyond virtual teardown, active retention/settlement/disposal/observer counts, fail-loud live assertion and held nontermination observation; Screen/Routes late-owner isolation |
| RF1.1/RF1.2/RF1.3/RF1.4 | Commands failed→successful reusable Save, consecutive searches, terminal reentrant false/old-finally isolation and second-run owner disposal with original runtime reporting; same physical identity, per-receipt settlement, observers stable until revoke |
| RF2.1/RF2.2/RF2.3 | Commands setter/refused-request independence, ABA/error/raw invalidation, mutation+blank query; Matrix Load/input distinction; Screen field retention/rebinding |
| RF3.1/RF3.2/DF1 | Commands distinct Save receipts and equal-success outcomes; Screen A Success→B Error→C Success/dialog confirm+cancel and clean failed-B no-fallthrough, binding seeding/replacement; Routes old-owner success/expected/raw never affects replacement |

### Per-task completion evidence

| Task | Status | Concrete evidence |
|---|---|---|
| 1.1 | COMPLETE | Exact PR/SHA/branch/index preflight; all 37 B0 machine/JSON tuples and checkpoint spans reconciled; final unchanged checkout inventory |
| 1.2 | COMPLETE | Required skills/support audited; existing fake gains three controlled hooks; shared harness composes existing fakes; VM/Screen baselines retained |
| 2.1 | COMPLETE | Eleven private persistent lanes; Commands neutral/reuse/equal-outcome/immutable receipt assertions |
| 2.2 | COMPLETE | Matrix 243 tests, 484 pair traces plus composed reads; synchronous refusal checks |
| 2.3 | COMPLETE | Commands expected/raw/assertion/reentry and retry; Screen distinct terminal effects |
| 2.4 | COMPLETE | Commands per-lane private observer/disposal/settlement probes, second-run late failure; Phases pre-entry revocation |
| 3.1 | COMPLETE | VM validation/create/update; Commands six immutable/newer-draft outcome traces |
| 3.2 | COMPLETE | Commands public Load dirty/exclusive/setter tests; defensive hydration revision guard |
| 3.3 | COMPLETE | VM five KeepCurrent groups; Phases stale group and private-preview failures |
| 3.4 | COMPLETE | Phases four KeepCurrent revoke boundaries; Commands late raw reporting |
| 4.1 | COMPLETE | VM exact moderation payloads and idempotent results; unchanged repository contract suite in B |
| 4.2 | COMPLETE | Phases four expected/raw original/follow-up traces; VM original-ID/follow-up order |
| 4.3 | COMPLETE | Phases token conflict/fresh-preview and refresh revocation; Screen code-specific feedback |
| 5.1 | COMPLETE | Commands RF2 variants and null blank query; Screen only setter/no-param request and owner-keyed text |
| 5.2 | COMPLETE | Phases preview ABA/inverted Save release; Matrix all allowed overlaps; VM current hash installation |
| 6.1 | COMPLETE | VM asset contracts retained; Matrix captured ID/conflicts and Commands raw failures |
| 6.2 | COMPLETE | Phases three asset boundaries; Commands active resource retention and once-only retirement |
| 7.1 | COMPLETE | Screen bind seeding/replacement/equal-result effects; Routes actual old owner isolation |
| 7.2 | COMPLETE | Screen both dialog confirm/cancel variants, RF3 retry, clean-B-error DF1, no duplicate pop/moderation |
| 7.3 | COMPLETE | Screen existing action/code/asset tests, candidate text/rebind; captured mounted/current-owner callbacks |
| 7.4 | COMPLETE | Routes 35 pass; router diff only one edit bootstrap call |
| 8.1 | COMPLETE | Three documentation diagnostics removed; external legacy dependency search empty, legacy file unchanged |
| 8.2 | COMPLETE | A 506/0/0 and B 520/0/3, actual exit 0; explicit manifests in apply-verification.json |
| 8.3 | COMPLETE | C 3373/0/4, actual exit 0; exact portable 160-file manifest/hash |
| 8.4 | COMPLETE (prerequisite evaluation) | Both local-stack integrations NOT RUN; missing Docker daemon and readiness impact explicitly recorded as permitted by this task |
| 8.5 | COMPLETE | Machine/Flutter analyzer zero; immutable B0 tuple/hash reconciliation; formatter and final scope checks |
| 8.6 | COMPLETE | Strict OpenSpec exit 0; final direct untracked-file, protected-byte, source-hash, whitespace, scope, index and other-checkout checks pass |

### Analyzer, effective diff and remaining limits

B0 remains exactly 37 INFO, zero WARNING/ERROR, immutable byte-for-byte with its four preserved checksums recorded above. Comparing full severity/type/code/file/line/column/length/message multisets preserves multiplicity; all 33 ViewModel, one Screen and three support-documentation identities are absent from empty B1. No new diagnostics. No suppressions, analysis-option changes or global reporting changes. Legacy imports/exports and Command0/Command1 outside lib/utils/command.dart are absent; the legacy file remains unchanged and physically present for later consolidation.

Effective runtime diff: three production files (editor ViewModel, editor Screen, router); nine tests/support files (two adapted editor suites, route tests, fake repositories, command test support; four new files: reusable editor harness, command regression, admission matrix and phase tests). Original eleven OpenSpec artifacts stay untracked; apply updates proposal/design/tasks/test-plan/validation and adds portable autonomous manifest and apply-verification.json. Metadata/B0/delta specifications remain unchanged. Exact twelve Dart file hashes and test command selections are durable in apply-verification.json. No backend, SQL, dependencies/lockfile, CI, AGENTS, Command foundation, prior change or canonical specification is changed. Other checkout status and HEADs remain intact.

No known material implementation blocker remains from the executed gates. Residual limits are the documented unexercised local-service integrations, physical nontermination/resource retention, best-effort upload cancellation, remote response-loss ambiguity and raw refresh failure after remote commit. These are not simulated rollbacks or claimed successes. Three external PR review threads remain untouched. The next required gate is independent code review; local results do not publish or consolidate the seven changes.

Final verification: `openspec validate migrate-admin-editor-commands --type change --strict --no-interactive` returned exit 0 and “Change 'migrate-admin-editor-commands' is valid”. `git diff --check` returned exit 0. Direct checks also covered all untracked artifacts/Dart files for UTF-8, final newline, trailing whitespace, conflict markers, containment, portable artifact paths and requirement/scenario consistency. All twelve tested Dart hashes match final content; no added skip or analyzer suppression, no external legacy dependency, unchanged retained legacy file, unchanged metadata/B0/deltas, empty index and unchanged clean other checkouts. All 27 tasks are complete; 8.4 records unavailable integrations rather than executed tests. Local apply stops for independent code review.

## Implementation review remediation — CR1 (P1)

### Preflight, evidence and root cause

The user authorized local code remediation, regressions and verification only. Connected GitHub get_pr_info reads before edits and after testing reconfirmed PR #12 open/Draft and exact remote head `0cdb764a7586f85180a802fafcf2b485791cb5ff`. Local branch remains codex/plan-migrate-admin-editor-commands at that SHA; index empty. Initial inventory exactly matched the completed apply: eight modified tracked files, four new Dart files and thirteen untracked OpenSpec artifacts. A full pre-remediation content snapshot protected all 25 files. Primary checkout, detached app checkout and the six previous worktrees remain clean at their recorded HEADs. No drift, reset, cleanup, branch movement or publication action occurred.

CR1 evidence was valid: _owns(owner) checked mounted/current VM/liveness/route-exit, but not the editor route's authority over visible navigation or feedback. The real router's push(edit2) retains edit1 State and owner; context.pop(true) from edit1 could therefore pop edit2. The same missing distinction let an earlier Save/dialog latch regain authority after coverage. Original W4 go()/auth replacement exercises revocation, not retained background routes.

Regression development also found a coverage defect in the existing admin route fixture: MaterialApp.router lacked the production ScaffoldMessenger key, making previous no-snackbar checks ineffective for a live owner. The fixture now installs that existing key. With actual feedback wired, the new eighteen cases against the pre-fix Screen produced **4 PASS / 14 FAIL / 0 SKIP**, exit 1: Save/Reject Success popped B, expected/raw failures produced feedback, and eight covered-dialog variants replayed closure after return. This deliberate red run demonstrates the counterexample, not an unexplained final failure.

### Implemented decision and bounded scope

Owner authority remains unchanged. A separate private route-effect guard requires the editor ModalRoute to be current before navigation. Terminal IDs are marked consumed before checking visibility; covered terminals update their VM normally but produce no snackbar/navigation and are never queued for return. _closeEditor also checks route authority directly. Existing Save error feedback under its own current status dialog is preserved, independently of global raw reporting.

The approved Save/dialog exception uses the exact dialog route and session. Its builder calls ModalRoute.of(dialogContext), which the installed Flutter source documents as subscribing the builder to current-route changes. An active, noncurrent dialog means coverage and permanently revokes that session, including a pre-existing latch; an inactive normally dismissed dialog is distinct. Terminal handling rechecks the concrete route as well. Post-await Publish/Reject handling requires the current editor route, owner/session, nonrevoked dialog authority and existing Save ID/revision/F3/DF1 checks. A covered dialog's late confirmation/cancellation is inert; its finally clears only that session, and a later explicit dialog works independently. Asset-dialog entry and post-await confirmation also require current editor authority. No new router observer, queue, scheduler, dependency or visibility state in the ViewModel.

Only production AdminSubmissionEditorScreen changed. Test changes are confined to admin_route_test.dart (18 cases and the existing harness messenger key). D6 and the existing navigation requirement were clarified; no new requirement name/capability or separate plan. Tasks 7.1/7.2/7.4 reference additional CR1 evidence without reopening any of the 27 completed tasks. D1–D5/D7 and all admission, receipt, settlement, reporting and disposal code are byte-identical to the completed apply. The internal test-writing agent owned only the routing test file; main owned production and integration. This is not the subsequent independent code re-review.

### Regression closure matrix

| Acceptance | Deterministic evidence and result |
|---|---|
| CR1.1 — Save behind pushed B | Three Success/Result.error/raw cases: real edit1→push(edit2), held repository Future, retained mounted State/live owner, B push Future unresolved by A, no actual snackbar, B snapshot unchanged, correct A terminal, original raw report once. Explicit return to A does not replay. PASS. |
| CR1.2 — Moderation behind B | Same three outcomes for Reject; no B pop/feedback, original VM outcome preserved and raw reporting once. PASS. |
| CR1.3 — Current owned dialog | Publish/Reject × confirm/cancel: held Save released while concrete dialog current; no immediate editor pop, close association survives settlement, then exactly one pop(true) and zero moderation. Four cases PASS. |
| CR1.4 — Covered dialog | Publish/Reject × confirm/cancel × Save released before/after cover: concrete dialog is active but noncurrent, editor retained, no effects on B; after B pop, dialog is explicitly asserted retained and its result remains inert. A new explicit dialog opens/cancels correctly, proving session-local cleanup and no old Save replay. Eight cases PASS. |
| CR1.5 — Existing ownership/lifecycle | Original 35 route cases and all 71 Screen cases remain; go(), auth redirect, bind-time terminal seeding, equal-success execution identity, F3/DF1, exactly-once navigation and raw-after-dispose behavior pass. VM/foundation/lifecycle compatibility also passes without source changes. |

### Executed verification

Commands use installed Flutter 3.47.5/bundled Dart 3.13.4 via the same authorized SDK launcher as original apply, TZ=Europe/Rome and no dependency resolution. Exact explicit test selections and final source hashes are appended under remediations (entry CR1) in apply-verification.json; the original apply gates/hashes remain unchanged historical evidence.

| Gate | Actual command/selection | PASS | FAIL | SKIP | Exit |
|---|---|---:|---:|---:|---:|
| A | `TZ=Europe/Rome flutter test --no-pub --reporter expanded` with routing + Screen | 124 | 0 | 0 | 0 |
| B | Same command, previous twelve compatibility files plus four editor VM suites (16 files) | 973 | 0 | 3 | 0 |
| C | Same command, unchanged explicit CI manifest (160 files) | 3391 | 0 | 4 | 0 |
| D | `dart analyze --format machine` | — | — | — | 0; stdout/stderr empty, zero INFO/WARNING/ERROR |
| D | Separately `flutter analyze --no-pub` | — | — | — | 0; No issues found |
| E | `dart format --output=none --set-exit-if-changed` on two CR1 Dart files | — | — | — | 0; zero changes |
| E | `git diff --check` and direct checks of all tracked/untracked apply files | — | — | — | 0 |
| E | `openspec validate migrate-admin-editor-commands --type change --strict --no-interactive` | — | — | — | 0; valid |

The autonomous count increased by exactly eighteen from 3373 to 3391; all four skips are the same pre-existing Map/navigation and command_it characterization cases. No test removed, skipped or weakened. The manifest remains byte-identical, SHA-256 c0be3cce82129b302bf6d491286a82217336a88b1071cd29eb0185528e8647d0. Initial strict validation rejected an overly long draft requirement; the norm was condensed under the existing length limit with details retained in scenarios, then strict passed. No new requirement names or canonical edits.

### Final integrity and disposition

Incremental CR1 diff is eight files: Screen, routing tests, design.md, test-plan.md, tasks.md, validation.md, command-execution-concurrency/spec.md and apply-verification.json. No new files or manifest change. All other apply content is byte-identical to the pre-remediation snapshot, including ViewModel/router, other tests/support, metadata/B0 and its recorded checksums, provenance delta and proposal. Direct checks cover untracked text/UTF-8/final newline/whitespace/conflict markers/portable artifact paths, requirement names/scenarios, empty index and unchanged other worktrees. Final tested Dart hashes are recorded separately from historical apply hashes. All 27 task checkboxes remain completed.

**CR1 CLOSED locally.** No known remaining material blocker from the executed gates. The documented local Supabase token/all-day integrations remain NOT RUN because of the missing Docker daemon; no new infrastructure, backend or credentials were prepared and no integration pass is claimed. Runtime global reporting is independent of route visibility, and accepted physical operations continue normally. No commit/push/PR update/thread resolution/merge/archive/canonical sync or legacy deletion occurred. Stop for independent code re-review; this author remediation is not that review.


## PR #12 reconciliation verification — 2026-10-24

This section records new consolidation checks against the working tree based on published head `52d4e448d010d2d13c13a4d3d665cdf5b1b0103b`, including the two Content Submission route-test teardown callback additions. It does not replace the historical apply/CR1 results above or attribute those old counts to this run.

- Locked dependency preparation: exit 0; no dependency or lockfile change is part of the consolidation.
- `flutter test --no-pub test/routing/content_submission_route_test.dart`: exit 0, **39 passed / 0 failed / 0 skipped** (new reconciliation run).
- `dart analyze --format machine`: exit 0, empty output, **0 INFO / 0 WARNING / 0 ERROR** (new reconciliation run).
- `TZ=Europe/Rome flutter test --no-pub --reporter expanded` with the exact autonomous CI selection (160 files, excluding `test/integration/**`): exit 0, **3391 passed / 0 failed / 4 pre-existing skips**. This is a new run, coincidentally matching the historical CR1 count; it is not reused evidence. The selection matches tracked `autonomous-test-manifest.txt` (SHA-256 `c0be3cce82129b302bf6d491286a82217336a88b1071cd29eb0185528e8647d0`). All relevant lifecycle/support regressions are included.
- `flutter analyze --no-pub`: exit 0, **No issues found** (new reconciliation run).
- Local-stack integration tests: **NOT RUN**; the autonomous selection deliberately excludes `test/integration/`. No Supabase/Deno runtime stack was prepared or integration pass claimed.
- Historical GitHub Actions at exact head `52d4e448d010d2d13c13a4d3d665cdf5b1b0103b`: both Flutter analyze and Autonomous Flutter tests succeeded in [run 40124157345](https://github.com/xmattjus/moliseis/actions/runs/40124157345). These are remote results for the prior head, separate from the local reconciliation runs above.
- Latest-head GitHub Actions and final independent review: no completion is claimed by these local results.
- This section records results only; local temporary logs are not committed or promised accessible. The published commit and its CI run provide the persistent source/replay references.

### Documentary reconciliation and independent diff review

All seven existing migration directories were inspected. Each passed `openspec validate <change> --type change --strict --no-interactive` with exit 0 in the consolidation. All 13 normative specification files, JSON/TXT evidence and YAML metadata remain byte-identical to the starting head. Existing full Git SHA/evidence-hash values, analyzer machine rows and numbered task IDs/check states were compared with Git and preserved. The historical analyzer sequence remains **125 → 113 → 105 → 87 → 66 → 52 → 37 → 0 INFO**, not seven fresh analyzer runs.

English narrative, historical/current status and portable evidence references were checked throughout; remaining Italian text consists of exact product labels and other immutable names. No workstation/home/temporary absolute paths remain in these artifacts. Historical inaccessible logs are explicitly identified as unavailable raw evidence; recorded outcomes are not upgraded into newly verified passes. The seven published checkpoint/parent pairs were checked against Git, including the intermediate Search/GeoMap reconciliation `f48a08946c9ac40146104a0157556243ad433c92` after `da7c426fb799a26094f043319b47e63b98728f92`.

A separate read-only reviewer compared all five translated migration proposals/designs/tasks with their original revisions and inspected lifecycle correctness of the two-line test fix: no actionable finding. The integration agent separately reviewed the already-English Admin documentation diffs, source scope and evidence. The test fix is distinct from documentation normalization: each affected test creates/registers one harness, passes the established `disposeOwners` callback, and performs no earlier explicit disposal. `testOwnerUI` invokes it in `finally` after assertions and widget unmount, including when the test callback throws; `disposeContentSubmissionOwners` calls each registered disposer once and clears the list. No shared support/lifecycle abstraction changed.

CodeRabbit dispositions at this local verification stage: publication status (CR-A), missing teardown (CR-B) and evidence portability (CR-C) corrected; already-resolved Search/GeoMap inconsistency (CR-D) remains corrected. The two older deferred-disposal helper extraction suggestions are nonblocking production refactors outside scope. No unresolved correctness defect was confirmed from those suggestions. Thread replies/resolution and latest-head CI require subsequent publication/live verification; this pre-commit record does not claim those future actions.

Final reviewed source manifest: 26 existing Markdown files under the seven changes (proposal/design/tasks in migrations 1–5; proposal/design/tasks/validation/analyzer-baseline in Admin Session; proposal/design/tasks/validation/analyzer-baseline/test-plan in Admin Editor) plus `test/routing/content_submission_route_test.dart`. No production/backend/dependency/configuration/canonical files changed, no new files or permanent tooling. `git diff --check` passed; nine unrelated checkout HEAD/status inventories matched the initial read-only inventory. The dedicated reconciliation branch starts at `52d4e448d010d2d13c13a4d3d665cdf5b1b0103b`; its new commit cannot record its own SHA before creation. Final independent review, explicit merge authorization, canonical synchronization, archival and legacy compatibility removal remain separate gates.
