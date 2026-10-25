# Independent plan review

## Historical initial review — 2026-10-24

The following initial review is retained as historical evidence. Its no-further-finding conclusion predates the user-supplied F1–F3 follow-up review; it is not the current remediation disposition.

Read-only explorers separately traced all seven migration changes. An architect inspected command_it source for the two substantive concurrency decisions; no implementation or speculative new framework was delegated. A fresh configured reviewer then challenged proposal, design, audit, metrics, delta and tasks against source/tests/package behavior.

### Finding IR1 — P2 — editor revocation before command start

The first D4 draft said all accepted writes execute once and relied on running=false observation to release reservations. Existing editor `_admit` at lines 1458–1464 deliberately skips `.run()` if an admission observer disposes the owner. Its existing eleven-operation test at `admin_submission_editor_commands_test.dart:539+` proves no I/O. There is no running transition in that branch, so a callback-only release could strand captures/resources.

**Correction:** editor admission remains revocable before I/O, unlike already-transferred Search history persistence. D4, task 4.1 and E1/E5 now explicitly require direct capture/reservation cleanup and safe idle command release from this branch without awaiting a running observer or publishing success. Existing zero-I/O behavior test stays. No new abstraction or state engine is introduced.

### Other adversarial checks

The reviewer found no further material issue: Search independent read-only reload matches repository semantics, delayed/stale confirmed presentation is explicitly relaxed, FIFO accepted writes still survive disposal, reads never block writes, and no cross-owner guarantee is invented. Editor one-observer completion remains conditional on reservation through the actual package post-turn boundary; pure runAsync is rejected because assertion futures can remain unresolved. Same-target backend mutation, source/preview/draft authority, covered-route and finalization regressions stay.

Measured LOC/class/listener claims were independently checked: fifteen VMs 4,009→6,515; eleven introduced classes; editor 3 listener sites instantiated eleven times = 33 registrations. Reduction ranges are estimates, not verified future equivalence. N01/N02/N03 are excluded rather than hidden discovery/implementation tasks.

Root added an explicit narrow shared-ownership clarification to avoid treating a helper-class boundary as necessary for Search writes already accepted before presentation disposal; it grants no other post-dispose phases. Complete effective-spec composition is validated separately in validation.md.

IR1 correction verification and final reviewer outcome are recorded in validation.md after re-read. This review covers the plan, not a future implementation or merge authorization.

## F1–F3 documentation remediation — 2026-10-25

This is a separate follow-up to the independent review findings supplied by the user. It changes planning artifacts only. Source and parser evidence was checked afresh; earlier observations were not treated as repository authority. The configured reviewer performed one focused adversarial review of the corrected contracts without editing files or reopening excluded N01–N03 candidates.

| Finding / original concern | Documentary correction and affected artifacts | Evidence / verification | Disposition / limitation |
|---|---|---|---|
| F1 — P2: confirmed history reload had no identifiable open-popup rebuild path | D3/F1, task 3.2, H10, and two scenarios in Search history presentation retains confirmed data identify a local builder in the actual empty-input Recenti view-builder branch, mounted even without chips, with guarded owner/controller/session captures and inert fallback cache | Current AppSearchAnchor empty view branch ignores supplied suggestions and renders _lastHistory; reviewer checked that structure and the deterministic rendered-popup success/failure/reload/replacement sequence | RESOLVED in documentation. Future widget tests are not written or run; implementation authorization is still required |
| F2 — P2: removing _EditorLane lost a common idempotent release guard | D4/F2, task 4.1, E1/E5/E11, and the editor overlapping-cleanup scenario require one permanent local identity claim before observer detach/dispose; every cleanup callback checks it first | Current editor admission can synchronously revoke before .run; bulk cleanup can already be queued, and command_it 9.5.2 asserts duplicate dispose. Reviewer checked the eleven-operation existing trace and pending late-error protection | RESOLVED in documentation. No lane/receipt replacement, release counter or framework introduced; effective resource safety remains a future behavioral acceptance |
| F3 — P2: seven titles described removed optimism, knowledge or retained-demand mechanisms | Exact old→new pairs in design's effective-spec ledger and RENAMED Requirements; all thirteen replacement bodies are MODIFIED under the correct final names | Installed OpenSpec 1.14.3 parser/application order checked; reviewer independently ran spec-composition-check.mjs: 13 modifications, 7 renames, no warnings or missing scenarios; final 59 requirements/290 scenarios in the target capability | RESOLVED. Six accurate titles stay unchanged; historical delta/canonical files are not edited |

The focused reviewer reported no remaining material finding. It independently confirmed the Recenti subscription placement, inert cache/callback ownership, permanent release claim before resource operations, and the actual composed requirement/scenario results. The review establishes completeness of documentary contracts, not future implementation equivalence or merge readiness.

The initial IR1 concern is still preserved above. F2 refines its release ownership rule rather than implying the original review already covered every convergent cleanup path. Full current composition, hygiene, historical transcript normalization and preservation evidence are in validation.md and validation-evidence.json. There is no code/test result newly produced by editing these documents.
