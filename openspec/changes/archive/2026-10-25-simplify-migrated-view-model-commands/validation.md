# Planning validation

## Current authorized implementation

Implementation and fresh code-review evidence are recorded in `implementation-verification.md` and `implementation-verification.json`. The sections below preserve earlier planning and documentation-remediation history. Their unchecked-task/no-code-change statements apply to those earlier executions, not the subsequently authorized implementation. The approved design, delta and independent plan-review history remain unchanged.

## Current documentation remediation — 2026-10-25

READY FOR FINAL INDEPENDENT SIMPLIFICATION PLAN REVIEW

F1–F3 are resolved in the plan; the configured reviewer found no remaining material issue after independently repeating composition. No simplification implementation, Flutter test, analyzer, backend operation or fresh CI run occurred during this remediation. All nine implementation tasks remain unchecked. The original review/validation below is historical, not a claim that its checks ran again today.

### Baseline and isolation

Repository `xmattjus/moliseis`; PR [#12](https://github.com/xmattjus/moliseis/pull/12) remains open/Draft. Connected PR metadata matches local Git origin refs: head `c6e4a21b17f9d14299f7a159dd7bebe5b31d9af1`, head branch `codex/migrate-legacy-commands`, base `main` at `ee60777c7fdfc5c16daa1151050c134fbb7cde29`. Git confirms head parent `52d4e448d010d2d13c13a4d3d665cdf5b1b0103b`. The existing dedicated branch `codex/plan-simplify-migrated-view-model-commands` stays at that head; directory `moliseis-worktrees/simplify-migrated-view-model-commands` was reused after deriving its base from local Git. No new worktree/branch was created.

Preflight found no tracked or staged changes and exactly fifteen untracked artifacts under this change. Their bytes and all eleven worktree states were captured before editing. Ten existing files are revised; the artifact set is unchanged. `.openspec.yaml`, proposal.md, metrics.md, metrics.json and historical-artifact-inventory.json are byte-identical to remediation preflight. The metrics baseline is preserved.

### F1–F3 outcome and verification

| Finding | Authoritative correction | Verification actually performed | Limit |
|---|---|---|---|
| F1 | D3/F1 and H10 identify the live Recenti ListenableBuilder in `_buildViewBuilder`, distinct inert cache, current owner/controller/session guards, rendered read/failure/reload acceptance | Read current Search widget branches/VM, existing widget tests and corrected plan; focused reviewer verified actual subscription placement instead of a suggestions-only assumption | Widget acceptance is planned, not implemented or run |
| F2 | D4/F2 gives permanent local release ownership claimed before detach/dispose; E11 covers queued cleanup convergence, E5 keeps original late-error reporting | Read editor `_admit`/dispose/release, existing eleven-operation admission-disposal trace and command_it duplicate-dispose/error-order behavior; reviewer verified idempotent cleanup contract | No new diagnostic getters, receipt engine or runtime test result |
| F3 | Seven RENAMED pairs and thirteen MODIFIED final-name bodies, exact ledger below | Read installed OpenSpec 1.14.3 parser/apply order and run official merge engine in an isolated temporary copy; reviewer reran it independently | Live canonical/historical specs remain unsynchronized and unchanged |

### Rename ledger

These are verified against the effective baseline after the seven migrations, not assumed from prior prose. OpenSpec applies RENAMED before MODIFIED and requires the MODIFIED TO header. Every old header is absent afterward and every new header is present exactly once. Six other correctly named targeted requirements remain unchanged in title; all thirteen replacements are accounted for in design's effective-spec ledger and script evidence.

| Effective old requirement name | New requirement name |
|---|---|
| Search history deduplication respects repository identity and knowledge | Search history mutations use repository identity rules |
| Search history rollback rebases later accepted intentions | Search history presentation retains confirmed data |
| History read authority changes at mutation acceptance | History reads remain independent of accepted writes |
| Runtime write failure requests bounded history reconciliation | Runtime history write failures allow explicit read-only recovery |
| History read demands distinguish stale errors from retry loops | History read failures terminate without automatic retry |
| Explicit history refresh registers independent read demand | Explicit history refresh uses ordinary single-flight admission |
| Editor changes retain an owner-local refresh obligation | Editor return requests best-effort dashboard refresh |

### Validation actually executed

- `openspec validate simplify-migrated-view-model-commands --type change --strict --no-interactive`: exit 0. Against live unsynchronized canonical it reports INFO that a pending rename source is not present; this documents the required composition order. No synchronization was attempted.
- The existing `spec-composition-check.mjs` now asserts the thirteen original target names, seven distinct old/new pairs, exact final modified bodies, retention of all previous requirement/scenario identities, absence of duplicates/orphans and unchanged unrelated capabilities. It copies OpenSpec into a fresh system temporary directory and uses installed `findSpecUpdates`, `buildUpdatedSpec` and `parseDeltaSpec`; no archive/sync command is used.
- Actual composition order: simple → Category → content ViewModels → Search/Map → Content Submission → admin session → admin editor → simplification. The seven migrations contain thirteen prior delta files. The final change applies **13 modifications and 7 renames**, 0 additions/removals of requirements, with **zero warnings**. Composed strict change validation exits 0 without INFO or stderr.
- Target capability totals: **59 requirements / 287 scenarios before → 59 / 290 after**. Whole composed specification: **17 capabilities / 240 requirements / 972 scenarios before → 17 / 240 / 975 after**. Counts are computed from actual output. The only added scenarios are the two F1 popup traces and the F2 never-started cleanup-convergence trace. All prior scenarios remain; seven old requirement headers do not survive. Existing scenario names identify retained input traces; approved changed WHEN/THEN outcomes remain explicit.
- `node --check` passed. Every artifact JSON parses; the installed YAML parser reads unchanged `.openspec.yaml` as spec-driven/2026-10-24. Official OpenSpec Markdown parsing, heading/scenario/table/reference inspection, trailing-whitespace/final-newline and artifact-containment checks passed. English prose review and portable-path scans passed; original application identifiers such as `Recenti` and `Ricarica cronologia` are exact UI strings, not explanatory prose.
- Exact remediation diff was inspected against the preflight artifact-byte snapshot because these artifacts remain untracked and ordinary git diff alone would omit them. No file was added/deleted. Tracked/staged Git diff remains empty. Ten other worktrees preserve HEAD/branch/status/index bytes and tracked/nonignored-untracked content; no ignored runtime artifact was written. All fifty historical artifacts match the unchanged inventory hashes and byte lengths.

The initial strengthened validation caught a scenario inserted into a rename line and a redundant blank-line raw comparison mismatch. Both were corrected and the entire final check rerun successfully. These were documentary authoring errors, not application or Flutter test results. The final script rejects either condition rather than accepting a partially applied rename.

### Historical test transcript normalization

`focused-test-output.txt` records the **initial 2026-10-24** run: 298 passed, 0 failed, 3 pre-existing skips, exit 0. It was not rerun during F1–F3 remediation. Before normalization its bytes matched the original recorded raw SHA-256 `6cb192e731c4817a961d617e63fe6e7aa02e81f92623884a2b60d51a96870250`. The file now has an explicit normalization/provenance header and removes only the machine-specific checkout prefix from test paths; all original test names, counters, skips, errors and stacks are otherwise retained. It is **not verbatim raw output**. The original raw hash is preserved, and the actual normalized file hash is `8fdc1c63c19353383b0d2c17505f951261dbd5b21283cb11e448853da75a80fa`; validation-evidence.json distinguishes them. This byte change is intentional hygiene, not a new test execution.

The old temporary raw file is not a portable or guaranteed available artifact. The test command and published checkpoint are reproducible with the resolved dependencies/runtime prerequisites; raw-byte timing/interleaving identity is not guaranteed. Skips remain visible and are not passing verification. Historical implementation/CI evidence in the seven migration directories is untouched and supplies no new remediation result.

### Scope and disposition

Changed files are design.md, tasks.md, test-plan.md, specs/command-execution-concurrency/spec.md, simplification-audit.md, independent-review.md, validation.md, validation-evidence.json, spec-composition-check.mjs and focused-test-output.txt, all under this existing change. No production/test/backend/dependency/AGENTS/foundation/canonical/historical edit, commit, push, PR change, merge, rebase, sync or archive occurred. F1–F3 have no remaining documentary blocker. Future implementation still requires final independent plan review and separate explicit authorization; N01–N03 stay excluded.

## Historical initial planning report — 2026-10-24

The following original planning validation is retained with its original date/scope. Its test execution, initial readiness phrase and initial no-further-finding review conclusion must not be read as current F1–F3 remediation results. The transcript reference is annotated for the normalization described above.

### Outcome

READY FOR INDEPENDENT SIMPLIFICATION PLAN REVIEW

This is readiness of an audited plan only. All nine implementation tasks remain unchecked; no source/test/backend change is implemented or claimed verified. Independent reviewer IR1 is fixed in design, tasks, acceptance and normative delta and re-read closed. No further material plan finding remains. Three evidence-limited candidates are explicitly excluded, with no unresolved executable design choice.

### Checks actually performed

| Check | Actual outcome |
|---|---|
| GitHub connected get_pr_info at preflight and final | Open/Draft; unchanged exact head c6e4a21b17f9d14299f7a159dd7bebe5b31d9af1; head branch codex/migrate-legacy-commands; base main ee60777c7fdfc5c16daa1151050c134fbb7cde29. No checkpoint delta. |
| Worktree isolation | New persistent codex/plan-simplify-migrated-view-model-commands branch at checkpoint; path derived from local Git toplevel parent into moliseis-worktrees/simplify-migrated-view-model-commands. |
| AGENTS/OpenSpec/schema | Repository AGENTS read; no nested AGENTS found. OpenSpec 1.14.3, configured spec-driven, root list/context resolved; proposal/specs/design/tasks instructions read. All required artifacts exist. |
| Seven-change audit | Fifteen migrated VMs and consumers, all seven planning/delta groups and historical evidence inspected; 50 historical artifacts hashed and unchanged. Three exploratory maps and a bounded architecture decision reconciled with source/tests/backend. |
| command_it behavior | Resolved pubspec.lock version 9.5.2 and local source checked. Deferred entry, result/running/finally order, assertion runAsync limitation and late-throw notifier problem are concrete evidence. Shared utilities unchanged vs main. |
| Fresh focused tests | In isolated temporary copy: 298 passed, 0 failed, 3 existing skips, exit 0 across result_command, restartable_command, command_it_disposal_behavior and ordinary_view_model_lifecycle tests. The original full output was recorded then; focused-test-output.txt is now explicitly normalized as described in the current remediation section. Skip reason is the known direct upstream late-StateError-after-dispose defect; no passing proof is inferred from skipped cases. |
| Direct strict change validation | openspec validate simplify-migrated-view-model-commands --type change --strict --no-interactive: exit 0, valid. It emits INFO that pending migration-added headers do not yet exist in canonical; this is a real synchronization ordering constraint, not ignored evidence. |
| Effective ordered composition | spec-composition-check.mjs copies OpenSpec to a fresh temporary directory, uses the installed official specs-apply.js findSpecUpdates/buildUpdatedSpec, applies all 13 prior delta files in the seven-change order, then strict-validates this change and builds its 13 MODIFIED replacements. Exit 0, zero merge warnings, no missing header or scenario-loss warning, 59 effective requirements. No archive or sync command ran; no real canonical/history file was written. |
| Independent adversarial review | IR1 identified the editor admitted-but-never-started disposal branch. Corrected direct idle release, revocable editor admission and test retention; independent reread confirms closed. No further material plan finding. See independent-review.md. |
| Preservation | Ten prior worktrees match preflight HEAD/branch/status/index-byte hash and tracked/nonignored-untracked content hash. Ignored runtime artifacts were not written: tests ran in a temporary copy. Dedicated HEAD/index/tracked tree unchanged; all new files confined to this change; 50 historical hashes unchanged. |
| Whitespace/containment/status | git diff --check exit 0; new artifact whitespace and realpath containment checked separately; only this change is untracked. |
| Git/publication | No commit, push, merge, rebase, cherry-pick, archive, canonical sync, PR mutation or new PR. Creating the requested local branch/worktree was the sole Git metadata addition. |

Full machine evidence: validation-evidence.json. LOC/callsite baseline: metrics.json and metrics.md. Historical artifact fingerprint inventory: historical-artifact-inventory.json. Future test families and risk tradeoffs: test-plan.md.

### Reproducing effective-spec validation

Run `node openspec/changes/simplify-migrated-view-model-commands/spec-composition-check.mjs <repository-root> <installed-openspec-package>/dist/core/specs-apply.js`. Resolve the installed package from the actual openspec executable; no package is downloaded or changed. The script writes only a newly created system temporary copy. It uses the same installed merge engine as OpenSpec rather than inventing a parser. Future real synchronization must apply the seven migrations before this change; this planning run authorizes neither synchronization nor archival.

### Limits and failed setup attempts

Local gh metadata lookup and Context7/find-docs lookup failed DNS; the former was replaced by connected GitHub read-only metadata, the latter by the authoritative locally resolved package source. No library behavior was inferred from current web docs or memory. The first Flutter launch failed at its SDK cache permission boundary before test execution; the temporary copy first lacked package_graph.json. Both were setup failures, not passing runs. After copying existing resolved dependency metadata and allowing SDK-cache access, the focused test command above actually completed with exit 0. No production/test file was edited for setup.

Full analyzer/autonomous Flutter suite and live-stack Supabase/Deno integration were NOT RUN in this planning execution. Historical PR/CI results are context only. Those future implementation checks are explicitly enumerated in tasks/test-plan and must be freshly measured after code changes. Reduction estimates and completion-bridge equivalence remain design expectations, subject to the listed behavioral acceptance; no future code/test result is claimed.
