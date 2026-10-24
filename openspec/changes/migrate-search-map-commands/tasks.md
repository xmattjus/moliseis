# Tasks

This checklist records completed, verified implementation after planning, independent plan review, F1–F5 remediation and authorization. Independent code review was subsequently completed and checkpoint 4 published as `da7c426fb799a26094f043319b47e63b98728f92` (parent `1f3753b10c18061c6655cb32d078bf93aff1b05e`) in [Draft PR #12](https://github.com/xmattjus/moliseis/pull/12).

The 27 checked tasks represent implementation and acceptance verification, supported by the historical Apply evidence in `design.md`. Numbering preserves the required gate sequence; failure blocked subsequent groups. The early UI draft sequencing deviation is recorded in the design. Scenario IDs S/G/U/R and counts are defined there and in the two deltas. Prospective task verbs preserve the original execution instructions.

## 1. Preflight and characterization

- [x] 1.1 Reconfirm PR #12 open/Draft and cumulative checkpoint, dedicated worktree/branch/index and applicable instructions; use PR metadata, log and status to exclude unreconciled divergence from `1f3753b10c18061c6655cb32d078bf93aff1b05e`, preserving all other checkouts.
- [x] 1.2 Reread approved proposal/design/deltas and Result, mounted-context-safety, unit/widget-test and test-support-reuse skills before edits; verify allowed manifest, command_it 9.5.2 and canonical + delta 1–3 reconciliation order.
- [x] 1.3 Regenerate B0 with `dart analyze --format machine`; retain identities/multiplicities and verify 87 INFO, zero WARNING/ERROR and 21 targets, documenting differences without suppressions.
- [x] 1.4 Extend only existing supports with Completer queues, counters and notifications required by S1–S18/G1–G9; characterize bootstrap/order/errors and prove discriminating race tests fail for their intended reason before correction. Planning remained documentation-only.
- [x] 1.5 Record actual preflight evidence and review corrected D1–D6/F1–F5; leave no material decisions to the executor and change no foundation/repository/dependency.

## 2. Search history and SearchAnchor — F1–F4 remediation

- [x] 2.1 Replace three legacy Commands with a ResultCommand reader and private feature writer using one reusable ResultCommand and ordered FIFO. Verify S1/S3/S4/S18 and F2: synchronous sequence/epoch/drain/receipt installation before run/notify, proven deduplication, no dropped distinct intentions or cross-owner serialization.
- [x] 2.2 Implement base+pending, synchronous optimism and per-entry rebase per D1. Verify S2/S4/S17 and all eight F2 cases with exact local/persisted state, order, writes and notifications, including an accepted second operation after first-operation failure.
- [x] 2.3 R1: make requestPastSearchesRefresh() the sole public reader entry, with private execution/read-only snapshot and bootstrap through that API. Verify R1.1–R1.7, pre/post-physical-start demand and no bypass. Use one scheduler with acceptance epoch, requested/attempted generations, drain OR detach and coalescing; verify S5/S6/S8/S10/S11/S12/S16 across G0-before-W-entry, writes before/during G0, read failure, reentry and disposal without cycles or stranded UI waiters.
- [x] 2.4 Separate UI/writer lifecycles, detach callbacks before disposal and drain accepted queued or pre-entry obligations. Verify S9/U1: submit→Command admission→close→navigation/dispose→entry→settlement, one write per accepted submit, zero late UI publication/access or duplicate write.
- [x] 2.5 Adapt AppSearchAnchor intention dispatch and popup/owner/controller/session authorization before acceptance. Verify U1/U2/U6 with rechecks after dispatch and own-close (confirmation token distinct from consumed popup), queued submit, suggestions, delete, categories, stale callbacks after close/unmount/replacement, immediate navigation and no duplicate pop/reset of new input.
- [x] 2.6 Request runtime-write reconciliation through the sole D2 reader, without write retry or invented rollback. Verify S7/S13/S14/S15/S18 for throws before/after commit, no G0, accepted W2, read failure and disposal; report each actual runtime failure once with original stack.
- [x] 2.7 Verify writer/reader pump and cleanup outside dispatch/reporting, void receipts and physical drain distinct from detach. Run S9/S12/S16 and idle/running/terminal lifecycle tests, throws beyond virtual 50ms teardown, fail-loud assertions and exactly-once release without normalizing aborts or notifying disposed UI.
- [x] 2.8 Run Search VM/widget/sliver, foundation/lifecycle and all S1–S18/U1/U2/U6 gates with counters and controlled fake storage. Preserve results/suggestions and repository; record actual results/manifest before GeoMap. Failures, F1–F4 contradictions or new diagnostics block progress.

## 3. GeoMap marker retrieval

- [x] 3.1 Replace legacy setters with synchronous immutable snapshots/distinct tickets; initialize one restartable loadMarkers and bootstrap. Verify G1/G2/G3/G5: same-stack state, equality, aliases, empty zero-I/O and unchanged dialog normalization.
- [x] 3.2 Fetch selected Events→Places locally, filter captured snapshots, retain immutable per-source outcomes and atomically commit while live. Verify G1/G2/G6 across success/empty/error combinations, ordering, cross-type identity, error precedence and no partial publication before settlement.
- [x] 3.3 Implement terminal authority/tickets, immediate invalidation, current-filter retry and busy/empty no-ops. Verify G3/G4/G5/G8 across A→B→A, out-of-order completion and pre-deferred-publication windows; equal values never revive an old terminal.
- [x] 3.4 Add marker-lane disposal/reentry while preserving selectContent/loadNearContent isolation. Verify G7/G9: throw/AssertionError, original reporting once, no Places phase after disposal, stale notifications/commits or duplicate cleanup.
- [x] 3.5 Run GeoMap VM and restartable foundation tests; verify removal of all four targets and unchanged mode/Post/Nearby semantics. Record evidence and obsolete physical-I/O limits before adapting UI.

## 4. GeoMap UI, filters and navigation

- [x] 4.1 Adapt GeoMapScreen to current marker status/terminal: map overlay, successful-empty, MarkerLayer data and partial/total failure with retry. Verify U3/G6/G8, distinct messages and usable map/navigation without isolated completed flags.
- [x] 4.2 Wire synchronous setters and owner/admission guards on retry/marker callbacks; retain ObjectKey(owner), dialog ownership and draft state. Verify U4/U5/F5: Save, Back and permitted barrier/drag apply the current draft; unmounted/stale sessions publish nothing; empty→all at route completion; preserve four category/type × empty/nonempty owner-replacement regressions. Equal callback once, zero admission/I/O; no new Cancel UX.
- [x] 4.3 Verify GeoMapBottomSheet, Search admission fence, selected Post and Weather with existing ownership. Run U1/U5/R1 and semantic tests: marker notifications cause no camera/sheet replay, stale not-found or old-marker lookup.
- [x] 4.4 Run routing/navigation/back/restoration/owner-replacement gates in the design, including SearchAnchor popup and Gallery root. Compare URI, excluded-lane calls and late-settlement state against baseline invariants; record actual results.
- [x] 4.5 Verify all S1–S18/G1–G9/U1–U6/R1, F2 and F5 triggers, separating synchronous state from settlement without arbitrary wall-clock waits. Preserve foundation, queries, Weather/Nearby, backend and route ownership; regressions/material conflict block progress.

## 5. Integration and implementation-review handoff

- [x] 5.1 Format intentional Dart files only and regenerate B1. Verify removal of 21 targets: 66 INFO, zero WARNING/ERROR, no new non-target identities/multiplicities; preserve configuration and full B0/B1 comparison.
- [x] 5.2 Run full `flutter test --no-pub` after targeted gates; record actual pass/fail/skip and ObjectBox/runtime limitations, distinguishing historical evidence and CI from fresh runs.
- [x] 5.3 Update only this change's artifacts with implementation evidence/approved deviations; run `openspec validate migrate-search-map-commands --strict`; verify schema/deltas without canonical synchronization or archival.
- [x] 5.4 Verify diff/whitespace including new files, HEAD/index and every other checkout; hand off the full manifest and explicit status for independent code review. The original separate-publication authorization subsequently arrived for checkpoint 4; merge remains unauthorized.

## Published checkpoint and follow-up

Checkpoint 4 publication and the later `f48a08946c9ac40146104a0157556243ad433c92` documentation correction are complete. The historical **4/7 implemented and published** state applied then; the cumulative PR now contains **seven published migrations** and remains Draft. Merge requires explicit authorization. Canonical synchronization and archival remain separate work: apply OpenSpec 1's ordinary MODIFIED requirement before these added requirements and preserve earlier semantic/Nearby contracts.
