# Implementation verification

## Baseline and scope

Local implementation starts at `c6e4a21b17f9d14299f7a159dd7bebe5b31d9af1` on `codex/plan-simplify-migrated-view-model-commands`, in the dedicated `moliseis-worktrees/simplify-migrated-view-model-commands` worktree. PR #12 in `xmattjus/moliseis` was verified open and Draft, with head branch `codex/migrate-legacy-commands` at that SHA and base `ee60777c7fdfc5c16daa1151050c134fbb7cde29`. The initial index and tracked files were clean; the fifteen approved planning artifacts were untracked and preserved. Initial state and content fingerprints were captured for the ten other worktrees before implementation.

Dependencies were prepared with `flutter pub get --offline --enforce-lockfile` (exit 0). The ignored ObjectBox native runtime was copied from the existing primary checkout; no dependency source or lockfile was changed. Historical planning test evidence remains separate from the runs below.

## Increment A — tasks 1.1 and 1.2

Removed the redundant marker ticket and cached marker status. Status now derives from the current owner terminal, including partial-source failures. Request object identity remains authoritative. Removed only unused Dashboard execution fields and assignments; method authorization and the persistent reactivation coordinator remain. The Map test name now describes request identity rather than a deleted ticket.

Executed command (exit 0):

```sh
TZ=Europe/Rome flutter test --no-pub --reporter expanded \
  test/ui/geo_map/view_models/geo_map_markers_test.dart \
  test/ui/geo_map/widgets/geo_map_screen_test.dart \
  test/routing/geo_map_route_test.dart \
  test/ui/admin/submissions/view_models/admin_submissions_view_model_test.dart \
  test/ui/admin/submissions/view_models/admin_dashboard_command_lifecycle_test.dart \
  test/ui/admin/submissions/widgets/admin_dashboard_screen_test.dart
```

Result: 264 passed, 0 failed, 1 existing skip. Individual `dart analyze --format machine <path>` runs on the two modified ViewModels and Map test exited 0; the Map run contained one informational long-comment lint, initially missed when summarizing exit codes. Repository-wide Flutter analysis later exited 1 on that same lint. The comment was shortened, and both full analyzers were rerun; final outcomes are recorded in the integration section. Formatting and `git diff --check` passed. Scoped diff inspection confirmed no change to the marker ownership, reactivation phase or pending-ID contracts.

## Increment B — task 2.1

Removed seven editor-return coordination fields, the revision drain and settlement wakeups. The ordinary refresh now checks live ownership and a normal terminal snapshot before requesting the currently selected ignored list. No pending freshness demand replaces the drain. The persistent reactivation coordinator and exact pending-ID gate are unchanged.

Executed (exit 0):

```sh
TZ=Europe/Rome flutter test --no-pub --reporter expanded \
  test/ui/admin/submissions/view_models/admin_submissions_view_model_test.dart \
  test/ui/admin/submissions/view_models/admin_dashboard_command_lifecycle_test.dart \
  test/ui/admin/submissions/widgets/admin_dashboard_screen_test.dart
```

Result: 117 passed, 0 failed, 0 skipped. Touched-file `dart analyze --format machine` exited 0 without diagnostics for the Dashboard ViewModel and lifecycle/widget tests. Formatting and scoped whitespace checks passed. Tests retain persistent reactivation coverage and exercise sequential selected-filter refresh, busy refusal/manual recovery, accepted Future correlation, original runtime error/stack, assertion no-next-phase, disposal and reentrant admission. No Dashboard screen or support change was necessary.

## Increment C — tasks 3.1 and 3.2

Search history now uses two fixed ordinary Commands, immutable write input, one write-only FIFO Future tail and one active completion waiter. Accepted writes survive presentation disposal. Reads do not block writes or retain refresh demand. Last confirmed history remains visible after failure; read-only reload never replays a write. Removed both history helper classes, optimism/rebase/epoch machinery and the synthetic controller text refresh.

The actual empty-input Recenti branch now mounts a local owner ListenableBuilder, including empty history. Its callbacks and builder validate captured owner/controller/session identities. Cached fallback chips remain inert values; the subscribed subtree is not cached.

Executed (exit 0):

```sh
TZ=Europe/Rome flutter test --no-pub --reporter expanded test/ui/search test/data/repositories/search_repository_impl_test.dart
dart analyze --format machine lib/ui/search/view_models/search_view_model.dart lib/ui/search/widgets/components/app_search_anchor.dart test/ui/search
```

Result: 159 passed, 0 failed, 0 skipped; analyzer emitted no diagnostics. Four cases were added without deleting original cases: two open-popup initial-history variants, replaced owner with pending old read and stale callbacks, and two accepted writes progressing while a read remains pending. Existing cases were adapted narrowly for approved confirmed-history/busy-read semantics; original runtime error/stack, assertion, FIFO-after-dispose, latest-wins and repository identity behavior remain covered. The three H10 variants passed separately. A negative control removing only the local subscription made both unchanged-popup tests fail on missing newly confirmed chips (exit 1); the exact production source was restored, then the complete green suite reran. This expected negative-control failure is not a passing run.

Initial development failures included old policy expectations, an incomplete virtual popup transition and test import/lint issues; these were corrected before the final complete suite and analysis. Formatting and whitespace checks passed. Search ViewModel loses 166 physical lines; the popup gains 29 for reactive presentation and recovery. Final same-method metrics will be recorded after Editor verification.

## Increment D — tasks 4.1 and 4.2

Removed _EditorLane, _EditorExecution, the revision-rescheduled settlement barrier, paired physical observers, counters and four production diagnostic getters. Eleven fixed typed Commands receive immutable captured action closures. Explicit typed snapshots and logical effect IDs preserve the public API. An identity reservation set holds synchronous admission until post-turn completion; a permanent released-identity set claims cleanup before observer detachment and disposal. No replacement execution/receipt engine was required and the mandatory stop condition was not triggered.

The Editor screen is unchanged. Its existing logical once-only effects, route/dialog ownership and Save revision association continue through the existing snapshot/ID API. Candidate/context/preview/draft generations and repository phase guards remain local.

Executed (exit 0):

```sh
TZ=Europe/Rome flutter test --no-pub --reporter expanded \
  test/ui/admin/submissions/view_models/admin_submission_editor_commands_test.dart \
  test/ui/admin/submissions/view_models/admin_editor_admission_matrix_test.dart \
  test/ui/admin/submissions/view_models/admin_editor_phase_test.dart \
  test/ui/admin/submissions/view_models/admin_submission_editor_view_model_test.dart \
  test/ui/admin/submissions/widgets/admin_submission_editor_screen_test.dart \
  test/routing/admin_route_test.dart
```

Result: 560 passed, 0 failed, 0 skipped. Touched Editor ViewModel and tests analyze without diagnostics (exit 0); formatting and whitespace checks passed. E11 retains all eleven pre-entry admission-disposal traces and drains cleanup, the virtual notifier teardown interval and further turns, checking zero I/O, no fabricated terminal success, frozen presentation, no late notification/error and no stuck reservation. Pending late-error tests retain original object/stack reporting. E6 adds bounded reentrant completion-to-new-admission coverage; assertion reuse and topology-only oracles are replaced according to the approved relaxation.

Root diff review caught lost stack/error metadata in the public snapshot projection; the final projection preserves original stackTrace, errorReaction and isUndoValue, with live create/update failure assertions sharing the exact StackTrace object seen by the once-only global report. Development test failures concerned callback assertion timing and detailed-stack display formatting; final complete tests include their corrections.

A bounded E11 negative control removed only the permanent released-set early return and failed with the expected upstream duplicate-dispose assertion (exit 1). Exact guarded production bytes were restored and scoped analysis rerun successfully. This expected failure validates the cleanup trace, not production behavior. Editor has 11 permanent completion registrations instead of 33; its explicit typed fields retain readability despite a smaller than estimated LOC reduction.

## Cross-feature verification — task 5.1

Executed after the four feature increments (exit 0):

```sh
TZ=Europe/Rome flutter test --no-pub --reporter expanded test/ui/content_submission test/ui/admin/auth test/ui/event test/ui/category test/ui/ordinary_view_model_lifecycle_test.dart test/utils/result_command_test.dart test/utils/restartable_command_test.dart test/utils/command_configuration_test.dart test/utils/command_it_disposal_behavior_test.dart test/routing/home_event_discovery_test.dart test/routing/content_submission_route_test.dart test/routing/content_submission_restoration_test.dart test/routing/events_route_test.dart test/data/repositories/content_submission_repository_impl_test.dart test/data/repositories/content_submission_draft_repository_impl_test.dart test/data/repositories/content_submission_staged_asset_repository_impl_test.dart test/data/repositories/admin_content_submission_repository_impl_test.dart
```

Result: **968 passed, 0 failed, 3 existing skips**. This covers unchanged draft/staged/finalization, Auth correlation, Event day/Home, Category, ordinary-owner lifecycle, Command foundations, wire/repository and real route behavior. The three skips are direct upstream late-StateError-after-dispose scenarios for command_it 9.5.2; protected owner late-error regressions run rather than inheriting those skips. Feature-focused results are recorded above and were not substituted by historical evidence.

## Repository gates — task 5.2

Both final analyzer commands ran with the repository's current configuration and resolved dependencies:

| Command | Exit | Final diagnostics |
|---|---:|---|
| `dart analyze --format machine` | 0 | None |
| `flutter analyze --no-pub` | 0 | No issues found |

The initial full run found only the introduced Map comment lint described under increment A; the final runs follow its correction. No lint configuration, suppression or dependency change was made.

### Autonomous Flutter suite

Read `.github/workflows/pull-request.yml` and applied its actual sorted `find test -type f -name '*_test.dart' -not -path 'test/integration/*'` selection. The executed argv was `flutter test --no-pub --reporter expanded` followed by the **160** repository-relative paths in `autonomous-test-manifest.txt`, with `TZ=Europe/Rome`.

Result: **3390 passed, 0 failed, 4 existing skips, exit 0**. Manifest SHA-256: `c0be3cce82129b302bf6d491286a82217336a88b1071cd29eb0185528e8647d0`. This is a fresh local workflow-equivalent run, not a new GitHub CI result. The four skips are the three upstream command_it cases above and the existing Map-root Back regression for go_router's inactive-branch issue. No skip was added or modified.

Reproduce the actual invocation without shell word splitting:

```python
import os, subprocess
from pathlib import Path
manifest = Path('openspec/changes/simplify-migrated-view-model-commands/autonomous-test-manifest.txt')
subprocess.run(['flutter', 'test', '--no-pub', '--reporter', 'expanded',
                *manifest.read_text().splitlines()],
               env=dict(os.environ, TZ='Europe/Rome'), check=True)
```

`test/integration/all_day_pipeline_test.dart` and `test/integration/external_event_token_pipeline_test.dart` are **NOT RUN**. Docker, Supabase and Deno executables exist, but the Docker daemon probe exits 1; the required live local stack is unavailable. No stack startup, backend change, query/deployment or remote mutation was attempted.

### OpenSpec

Direct strict change validation exits 0. It emits the known INFO that a rename source is not yet present in unsynchronized canonical specs; the approved seven-migration composition resolves that source. This is reported explicitly, not suppressed.

`spec-composition-check.mjs` used installed OpenSpec 1.14.3 in a newly isolated temporary root, canonical → seven migration deltas → simplification. It applied **13 modifications / 7 renames**, no requirement additions/removals and **zero composition warnings**. Composed strict validation exits 0 without INFO/stderr. Target capability: **59 requirements / 287 scenarios → 59 / 290**. All capabilities: **17 / 240 requirements / 972 scenarios → 17 / 240 / 975**. All prior requirements/scenario names remain except the seven approved old-name supersessions; all final modified bodies match, no duplicate/orphan requirement/scenario exists, unrelated capabilities remain byte-identical. The approved rename ledger remains authoritative in design.md and the delta; no new normative change was introduced by implementation. No live canonical synchronization/archive occurred.

`node --check` passed for the existing composition script. Current post-implementation measurements are appended separately in metrics.md and metrics.json; all original baseline values remain intact.

## Fresh independent code review

The configured reviewer independently examined the actual uncommitted diff, approved design/delta/test plan, affected UI consumers/tests and resolved command_it 9.5.2 source. Final disposition: **no material finding survived adversarial verification**. The review traced accepted Search FIFO ownership after disposal, independent reads/recovery, actual popup subscription/cached callbacks, directed Editor admission/captures, Save association/logical effects, post-turn reentrancy, permanent idempotent release and original runtime metadata. It found no equivalent execution/receipt/revision engine recreated under new names. Reviewer whitespace inspection passed; the reviewer did not rerun Flutter tests or analyzers and does not independently attest their counts. No reviewer file edit occurred.

The root's earlier stack-metadata projection finding was fixed and tested before this fresh review. No reviewer remediation remains open. The E11 release negative control was followed by a restored guarded scenario pass (1 passed, exit 0); the full Editor suite's 560-pass result uses the same restored production bytes.

## Final scope, preservation and evidence integrity

The final tracked diff contains **five production and twelve existing test files**. No screen, shared test-support, dependency, backend, domain/repository interface, shared Command foundation, CI, AGENTS, canonical spec or historical migration file changed. Exact changed-file paths and source hashes are in `implementation-verification.json`; it distinguishes changes in this execution from approved artifacts that were already untracked at preflight.

All ten other worktrees retain captured HEAD/branch/status and exact index bytes, with no tracked/untracked changes. An additional 10,990 tracked-file comparison checks their content against captured clean HEADs. One existing CRLF text file is compared using the repository's configured Git input normalization; it is not a current modification. All fifty historical artifact byte lengths and SHA-256 values still match. The original fifteen planning artifacts remain present; the approved design, normative delta, review history and normalized historical transcript are unchanged. Original metrics fields and the original metrics.md prefix remain intact; current measurements are appended separately.

All current artifact JSON/YAML/JavaScript syntax, reference/manifest/hash checks, Markdown structure, English prose review, portable-path scan, final-newline and trailing-whitespace checks are recorded in the machine evidence. The seventeen touched Dart files pass formatter verification without changes. The original normalized historical transcript retains SHA-256 `8fdc1c63c19353383b0d2c17505f951261dbd5b21283cb11e448853da75a80fa`; it was not regenerated or presented as a current run. Full transient runtime logs are not packaged as purported portable raw transcripts; the fresh commands, outcomes, manifest and source hashes provide reproducible provenance without machine paths.

Remote PR metadata was reconfirmed open/Draft at the original head/base/branch after verification. Local HEAD and branch remain unchanged, with an empty staged diff. No commit, push, PR update, merge, rebase, new worktree, canonical synchronization or archive occurred. No implementation change was published. Live local-stack integrations remain NOT RUN for the documented missing Docker daemon; there is no remaining implementation blocker.

All nine tasks are complete and verified. **READY FOR INDEPENDENT CODE REVIEW** describes this local implementation; publication still requires separate authorization.
