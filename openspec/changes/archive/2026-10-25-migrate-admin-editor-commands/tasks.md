# Tasks

## Published checkpoint

This migration was published in Draft [PR #12](https://github.com/xmattjus/moliseis/pull/12) as commit [`52d4e448d010d2d13c13a4d3d665cdf5b1b0103b`](https://github.com/xmattjus/moliseis/commit/52d4e448d010d2d13c13a4d3d665cdf5b1b0103b), whose parent is `0cdb764a7586f85180a802fafcf2b485791cb5ff` (verified from Git history). All seven migrations are now published. The historical analyzer transition for this checkpoint was **37 → 0 INFO**; these are recorded checkpoint results, not analyzer runs performed during reconciliation. Planning assumptions, local-only authorization and uncommitted-work statements below describe their original phases. Subsequent publication supersedes those status statements without changing the historical evidence. Canonical synchronization, archival, legacy compatibility deletion and merge remain outside this reconciliation.

Authorized local apply completed after user-supplied independent plan approval and explicit apply authorization. Decisions refer to design.md; scenario IDs refer to test-plan.md. Executed evidence and per-task traceability are in validation.md and apply-verification.json. This checklist does not authorize publication or canonical synchronization.

## 1. Authorized baseline and shared test support

- [x] 1.1 Reconfirm PR #12 open/Draft, exact authorized head and dedicated branch/worktree identity; compare full B0 identities against analyzer-b0.json. Acceptance: recorded SHA/status and all 37 tuples including span/multiplicity match; stop rather than adopt drift (Context, D1).
- [x] 1.2 Load required test skills and audit shared support; add only missing per-call getById/candidates/link gates or an editor-specific reusable harness. Acceptance: existing fake defaults remain compatible, gated call order is deterministic and existing editor baseline suites run without fake duplication (test-plan support, A1/M3/Q1).

## 2. Private command ownership and synchronous admission

- [x] 2.1 Replace eleven public legacy commands with eleven owner-lifetime reusable private ordinary ResultCommand instances, fresh monotonic receipt IDs/immutable requests and synchronous request façades (candidate request has no parameter). Acceptance: all eleven initial snapshots neutral, private commands inaccessible to consumers, A1/A6 and RF1.1/RF1.2 distinguish physical lane identity from receipt identity, equal Results do not merge attempts, and no foundation changes (D1/D6).
- [x] 2.2 Implement complete directed admission matrix, public Load exclusivity/dirty refusal and reservation-before-notify. Acceptance: A2 tests both orders and pre-entry/pending phases for every pair plus composed read reservations; false means no desired-input/snapshot change, receipt/ID allocation, I/O, queue, overwrite or terminal result; RF2.1 asserts state after setter separately (D1).
- [x] 2.3 Preserve expected validation errors distinctly from refusal and implement safe cached snapshot forwarding/reentrant reopening. Acceptance: A3–A5, RF1.3 and RF3.1 pass with owner/lane/execution-ID publication and no Result-equality correlation; an admitted retry cannot have its busy flag lowered by old finally (D1/D6/D7).
- [x] 2.4 Implement owner revocation and retained private settlement outside terminal/notifier dispatch. Acceptance: L1–L3/RF1.1–RF1.4 show live settlement releases receipts only and preserves stable observers/Command reuse; after revoke each idle/settled Command releases once, active second runs retain original late-runtime reporting, with no public state/new phase, assertion normalization or invented nontermination timeout (D7). Document actual cleanup evidence beside these decisions.

## 3. Save, hydration and KeepCurrent

- [x] 3.1 Capture and validate full immutable persisted Save input and draft revision; retain original create/update route identity. Acceptance: existing required/date/coordinate/create/update tests and S1/S2 prove admission snapshot, no ID adoption, dirty retained for newer fields and explicit retry (D2).
- [x] 3.2 Guard persisted-field setters during Load/non-Save mutations and hydrate only live authorized revision. Acceptance: S3/S4 show refused callbacks cannot create edits later erased by hydration; ordinary load errors retain prior fields and initial retry works (D1/D3).
- [x] 3.3 Implement receipt-authorized KeepCurrent copy→private Save→private Preview without public recursive commands or force flags. Acceptance: existing five group tests plus K1–K3 verify complete atomic group, current membership, error short-circuit and no internal Save pop (D2/D4).
- [x] 3.4 Guard every KeepCurrent phase and notify reentry against revocation. Acceptance: K4 and L2 prove zero next-phase I/O and no fabricated success after dispose while preserving original late runtime reporting (D2/D7).

## 4. Moderation, source evidence and refresh chain

- [x] 4.1 Preserve Reject/Promote/Link/Apply eligibility, exact request identity/target/ack/hash and original typed/idempotent results. Acceptance: existing domain cases and M1 compare exact repository arguments including opaque token strings and no client merge authority (D3).
- [x] 4.2 Keep original-ID refresh→optional follow-up order under outer authority for Success/SOURCE_CHANGED, with explicit expected/raw failure policy. Acceptance: M2–M4 prove call order, ack/preview clearing, original expected outcome, raw outer-only reporting and retained data; no automatic mutation retry (D3).
- [x] 4.3 Invalidate Apply preview on token/source conflict and revoke all remaining phases on disposal/reentrant notification. Acceptance: M5/M6 cover specific error feedback, fresh-preview requirement, zero revoked hydration/follow-up/status publication (D3/D4/D7).

## 5. Explicit candidates, target and preview

- [x] 5.1 Separate void setCandidateSearch(String value) from bool requestFindCandidates(); only the setter edits desired input/invalidation, only successful request admission captures trimmed search in a no-param Command receipt. Acceptance: A2/A5/Q1/Q2 and RF2.1–RF2.3 prove refused request is inert, ABA/failure invalidation, exact B/null query and deterministic mutation overlap, no typeahead/queue; pending warnings remain advisory (D4).
- [x] 5.2 Preserve monotonic preview generation, current source-hash update and current-target Apply authority; suppress stale data and public terminal snapshots independently from physical busy state. Acceptance: Q3–Q5 and A2 prove target ABA, reversed completions, no stale Apply readiness and no current-preview self-invalidation (D4).

## 6. Persisted assets

- [x] 6.1 Migrate AddAsset/DeleteAsset with existing guards, exact captured IDs, picker/upload/association order and confirmed-list commits. Acceptance: existing asset tests plus U1/U2 cover cancellation, capacity, expected failures and raw errors without optimistic success (D5).
- [x] 6.2 Preserve once-only active task cancellation and honest remote persistence limits. Acceptance: U3 phase matrix and L2 verify no new association after revoke, no late assets/feedback, no remote rollback claim and safe private retirement (D5/D7).

## 7. Screen and route consumers

- [x] 7.1 Replace direct command listeners/merged command observation and typed legacy resolution helper with cached VM snapshots, owner/lane/terminal-execution-ID consumption and owner rebinding, with distinct identities for receipt, snapshot value, effect and persisted draft revision. Acceptance: existing screen rendering/feedback tests plus W3/RF3.1/RF3.2 establish distinct outcomes for equal Result values, seeded existing-terminal consumption and isolated replacement-owner effects (D6).
- [x] 7.2 Preserve clean Save closure and status-dialog latches with current owner/session/revision checks and mounted-safe callbacks. Acceptance: extend existing dialog tests for W1/W2, including confirm/cancel, receipt-settlement latch retention, revocation on next Save admission and dirty invalidation; RF3.1 proves A Success→B Error→C Success without inheriting old closure authority, and DF1 clean-B-error branch cannot fall through to stale moderation; zero stale moderation and one pop(true) (D2/D6).
- [x] 7.3 Migrate all screen action/retry/search/target/asset callbacks through definitive VM admission and guard delete dialogs after awaits. Search onChanged calls setCandidateSearch; button calls requestFindCandidates() with no argument; remove Screen _eventSearch and preserve field text/owner rebinding. Acceptance: existing action/error-code/asset tests and A5/W2/RF2.1–RF2.3 preserve feedback, membership and false-admission behavior; no State.widget/context read after unmount (D1/D6).
- [x] 7.4 Replace only edit-route initial load trigger with synchronous requestLoad, retaining provider scope/keys. Acceptance: W4 real-router owner replacement/auth redirect tests pass with one initial load and no old owner navigation/snackbar, alongside existing admin route tests (D6/D7).

## 8. Analyzer closure and compatibility gates

- [x] 8.1 Remove the fake-repository documentation-only legacy import and two legacy dartdoc links; search all direct/indirect editor consumers and tracked Dart imports/exports/symbols. Acceptance: no external dependency on command.dart remains, all 37 B0 identities accounted for, command.dart still present and no suppressions/global rule changes (baseline ledger).
- [x] 8.2 Run focused editor/route/repository/shared-field suites and prior migration foundation/lifecycle compatibility gates. Acceptance: actual commands/exits/pass/fail/skip totals recorded, no unexplained failure or new helper duplication (test-plan execution gates 1–2).
- [x] 8.3 Run complete autonomous Flutter suite with CI-equivalent explicit sorted test manifest and Europe/Rome timezone. Acceptance: manifest/hash and actual counts/exits recorded, every failure resolved within authorized scope or reported; service tests excluded explicitly rather than called passed (test-plan gate 3).
- [x] 8.4 Run pertinent preconfigured local-stack token pipeline and adjacent all-day compatibility tests, or record unmet prerequisites as unexecuted with readiness impact. Acceptance: actual opt-in/env/service provenance and results recorded; no production backend or schema/dependency changes to manufacture a pass (test-plan gate 4).
- [x] 8.5 Run full machine analyzer plus Flutter analyzer, reconcile B0/B1 and check formatter/whitespace/scoped diff. Acceptance: zero remaining/new diagnostic tuples, actual exits recorded, only authorized production/test/support and current-change artifacts differ; no legacy deletion/backend/foundation/canonical edits (test-plan gate 5).
- [x] 8.6 Strictly validate OpenSpec and update implementation evidence/traceability honestly. Acceptance: `openspec validate migrate-admin-editor-commands --type change --strict --no-interactive` passes; completed tasks cite executed evidence and limitations; stop for independent code review (test-plan gate 6).

## Historical workflow follow-up

- The user supplied independent plan approval and authorized this local apply. Independent code review is the next gate; this checklist does not claim that review.
- Publication to cumulative Draft PR #12, final consolidation/legacy deletion, canonical sync, archive and merge are later separately authorized work. Never push directly to main.

## Additional implementation review evidence — CR1

The 27 completed tasks remain complete. Review remediation adds route-effect authority verification to 7.1 (consume covered terminal IDs without effects/replay), 7.2 (exact current dialog route/session, sticky revocation on cover, existing F3/DF1) and 7.4 (real push retains owner; no effects on the covering route). CR1.1–CR1.5 in test-plan.md specify additional acceptance; validation.md and the CR1 entry in apply-verification.json record actual reruns. This does not reopen the plan or authorize publication.
