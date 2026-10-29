# Design

## Context

See [proposal.md](proposal.md) for motivation. This is Admin cluster Plan 3. The design below preserves the approved planning baseline; implementation, PR #19 remediation, merge and archival status are recorded in [tasks.md](tasks.md).

### Verified baseline and evidence boundaries

- Repository `xmattjus/moliseis`; fetched `origin/main` on 2026-10-28 at `69e1773f168c16d76a3d588588be7cddf97737ac`. It contains #17 merge `92863232dac891ff740feefb2adc63a3d9c829c1` and #18 merge `69e1773`. Primary checkout was clean and fast-forwarded from `9286323` to that head; it remains synchronized `main`. Planning branch: `plan/harden-admin-stale-recovery` in a dedicated worktree.
- Read repository AGENTS.md and OpenSpec config/schema instructions; there are no additional nested AGENTS.md files governing the inspected surfaces. Canonical Admin draft, staging, editor, Save-idempotency and picker specifications are the accepted baseline. Source and tests, rather than archived task checkmarks, establish the implementation facts below.
- Read archived `2026-10-27-harden-admin-draft-and-staged-assets` and `2026-10-28-harden-admin-save-and-progress-route` artifacts. Plan 1's inert foundations are now activated by Plan 2; the strict native handoff originally deferred by Plan 1 was superseded by Plan 2. Do not restore it here.
- Public reference plans: archived `2026-09-11-harden-content-submission-draft-persistence`, `...-local-asset-staging`, `...-submit-orchestration`, `...-exit-progress-route`, and `2026-09-29-harden-content-submission-server-idempotency`, with their canonical specs. Reuse captured snapshots, local ordering and observer-only progress principles; Public single-slot retirement, fallback and exit policy are not Admin recovery policies.
- Historical `improve-admin-submission-editor-workflow` remains unimplemented. Its continuous Save, adoption, staged progress and dashboard requirements were superseded by Plans 1/2; its RAM staging and ambiguity assumptions are obsolete. Rich conflict recovery is this plan; Dirty Exit belongs to Plan 4. Do not edit, apply or archive that history.

### Deployment evidence versus repository state

Plan 2 tasks record user-reported Android/authenticated smoke and a prior independent production parity check; these are historical attribution, not fresh runtime proof. This planning audit independently read production metadata for project `tnxiujpgzrdeyaoqxwcy`: the migration list contains all 15 repository migrations through `20261027220140_admin_save_replay_contracts`; Admin Edge is ACTIVE v13 with `verify_jwt=true`. All nine fetched deployed TypeScript files exactly equal this baseline, including shared imports. Read-only catalog inspection of Create/association/Apply definitions confirms their relevant replay, lock, token and restricted service-role contracts below. No production content rows, credentials or secrets were needed; no backend write or smoke mutation was performed.

Migration history alone does not establish complete live schema parity. This audit does not claim every trigger/index/RLS definition was freshly compared, that the deployed mobile client is this build, or that device/network recovery passed. Source-defined guarantees are backed by existing PostgreSQL tests, not by merely finding a migration row. Recheck affected contracts if implementation baseline drifts.

### Audited implementation and contracts

Paths and line anchors refer to the baseline, not proposed symbols.

| Boundary | Evidence and existing contract |
| --- | --- |
| Local session | `lib/domain/use_cases/admin_draft_session.dart:17-64, 181-324, 463-542, 755-850`: C/current, E/effective, P/physical and R/remote are distinct; local future tail; captured activation; exact intent settlement; latest-admitted hydration; capacity bound to accepted detail. |
| Draft storage | `lib/domain/models/admin_submission_draft.dart`; `lib/data/repositories/admin_submission_draft_repository_impl.dart` and mappers/entities: one exact-account/target resumable owner, immutable raw snapshots, persisted original field intent and navigation hint; unsupported/conflicting data is unavailable rather than absent. |
| Staging storage | `lib/domain/models/admin_submission_staged_asset.dart`; staging repository implementation: private account/session/digest bytes, durable order, separate upload and association evidence, invalid progress retained without blind replay, exact removal and retained parent. |
| Activation/auth | Editor VM `activate/revoke/_clearContext` at lines 175-315; `lib/ui/admin/auth/view_models/admin_auth_view_model.dart`; `lib/config/dependencies.dart`: one Provider-owned editor, synchronous authority revocation, fresh generations and deferred command disposal. |
| Hydration and Save recovery | Editor VM lines 950-1060, 1429-1629: Save blocked by remote unavailable/unresolved intent; rejected hydration still publishes remote metadata; read-back compares original A/V, retries only A/V at unchanged V, confirms matching A, settles different advanced version as conflict. |
| Existing UI/routing | `admin_submission_editor_screen.dart:664-770`: retry, protected-conflict message, checkpoint/read-back/reload but no explicit field choice. `admin_submission_editor_route.dart:146-220`: local activation retry and initial detail load. `lib/routing/router.dart` and Save Progress use exact session hints and observer-only admitted Save. |
| Moderation | Editor VM lines 2336-2415 and canonical `external-event-provenance-moderation`: Apply token errors invalidate preview; SOURCE_CHANGED revokes acknowledgement/preview and reloads original detail; KeepCurrent saves under outer ownership. Captured source and exact preview tokens stay authoritative for their own request. |
| Repository/wire | `lib/data/repositories/admin_content_submission_repository_impl.dart:47-115`: getById, UUID Create, exact-string Update token, typed errors. `AdminSubmissionAsset` carries ID/URL/dimensions, not MIME/duration; detail equality is not an exact full-receipt oracle. |
| Guarded Update | `supabase/functions/admin-content-submissions/admin_submission_store.ts:627-680`: one pending + exact modified_at predicate, imported provenance guard, typed zero-row classification. `20261002163130_add_external_event_provenance.sql:79-99`: real editable-field changes advance token monotonically at database precision; no-op does not. |
| Create and receipts | `20261027220140_admin_save_replay_contracts.sql`: account/UUID first-write-wins Create; exact receipt replay under parent lock before pending/capacity rejection; metadata conflict fails; new insert only pending, max five; EXECUTE only service_role. Explicit re-association after deletion remains a backend capability; recovery must not invoke it accidentally. |
| Moderation backend | `20261002181549_resolve_external_event_submissions.sql:393-444`; Edge `index.ts`: submission/source/Event locks, source hash and exact submission/Event token checks; SOURCE_CHANGED, SUBMISSION_CHANGED, EVENT_CHANGED. Existing Edge and real PostgreSQL resolution/replay tests cover these contracts. |

### Gap analysis and findings

| Category | Finding, consequence and severity | Minimum action and verification |
| --- | --- | --- |
| 1 — already sufficient | Intent settlement, original A/V read-back/retry, Create identity/replay, C/E/P/R, protected hydration, command admission/physical settlement, account revocation and A → B → A already exist. No demonstrated backend integrity gap. | Preserve these contracts and extend their tests only where new recovery actions interact. Do not rebuild Save or a session manager. |
| 1 — already sufficient | EVENT_CHANGED/SUBMISSION_CHANGED invalidate Apply preview; SOURCE_CHANGED revokes acknowledgement and refreshes original detail. | Reuse these paths; ensure a later conflict choice cannot restore old acknowledgement/preview. No new moderation RPC. |
| 2 — demonstrated incomplete path (medium) | Session `acceptHydration` refuses incompatible unconfirmed fields; VM `_loadDetail` sets conflict; screen only offers reload/park/return. A differing server projection repeatedly refuses hydration, so the user cannot intentionally adopt it or Save preserved local fields against it. `admin_save_recovery_remediation_test.dart:630-653` confirms advanced-version conflict remains Save-blocked. | Add one observed-candidate and two explicit whole-field choices with stale-choice guards. Deterministic domain/VM/widget tests must demonstrate both exits and zero implicit remote writes. |
| 2 — demonstrated presentation gap (low) | Initial NOT_FOUND is rendered as generic retryable load failure at screen lines 674-685; final/missing unresolved Update remains protected but has no specific terminal recovery explanation. This is an incomplete recovery path, not evidence of overwrite. | Distinguish final/missing/denied from transport failure, keep local checkpoint/return usable, allow deliberate recheck without automatic retry loops or clearing unknown intent. |
| 3 — plausible risk, not a proven data-loss bug | Metadata refresh and field acceptance use different authority; newly displayed tokens/assets could be confused with accepted Save authority when adding choices. Existing hydration rejection can publish detail metadata. | Separate candidate from accepted baseline; deterministic queued hydration/checkpoint/edit/replacement tests. Do not infer freshness from VM display metadata. |
| 3 — plausible risk requiring focused verification | A persisted association receipt can outlive deletion by another actor while descriptor cleanup previously failed. Existing staged continuation trusts its confirmation and cleans it without checking a newly changed complete list. No runtime loss reproduced by this planning audit. | Preserve receipt as historical evidence; block automatic reconstruction and local cleanup based solely on old confirmation when latest detail contradicts it. Test missing/changed confirmed ID and capacity-only changes. |
| 3 — plausible risk requiring focused verification | Backend 401/403 can precede local auth claims updating; new callbacks must not treat old successful detail as authority. | Denied recovery state blocks remote commands; actual auth revocation hides local state; test authorization denial plus account replacement. |
| 4 — optional/out of scope | Per-field merge, conflict history, exports, draft lists/forks, push subscription/polling, global framework, asset tombstones, native cache redesign and Dirty Exit. | Exclude. Whole-field review and existing explicit checkpoint suffice for the verified gap. |

Existing tests inspected include domain `admin_draft_session_test`, `admin_save_session_test`, `admin_field_write_settlement_test`, `admin_session_target_binding_test`; VM `admin_editor_durable_session_test`, `admin_save_recovery_remediation_test`, command/admission suites; routing `admin_save_recovery_ui_test`, progress/session-target tests; real-store `admin_save_persistence_test`, draft/staging/storage tests; auth lifecycle and external moderation error cases. Passing them does not validate proposed behavior. Current focused execution is recorded in the final planning validation, not inferred from archived totals.

## Goals / Non-Goals

Complete a deliberate editor-level field reconciliation path while keeping all existing local and remote safety boundaries. Use one bounded recovery observation and the existing local arbitration and Commands. Recovery choices perform no network mutation and are not Save success.

No automatic field merge, per-field conflict algorithm, persisted conflict ledger, new payload/schema version, new public behavior, backend protocol or owner lifetime change. Progress stays an observer; recovery review lives in the editor, using an inline comparison/action area rather than Plan 4's dialog.

## Decisions

### 1. Observe first; do not silently promote display metadata into authority

Keep a single immutable latest remote recovery candidate in the editor VM, replacing the previous candidate on each authoritative detail result. It holds complete detail and an opaque runtime observation identity, bound to account/local session/remote target, activation generation and admitted read revision. The domain session validates the corresponding current observation when applying a local choice; it does not fetch or own auth/UI. A usable observation must identify the exact requested remote target and contain a fully decoded editable projection, status, complete association list and an exact non-null field token accepted by the existing wire validator. Missing token, wrong target or unsupported provenance/context yields unavailable state, not a selectable candidate. Compatible pending means that this remote context is supported for the same target; it does not mean local fields already equal it or pass Save validation. Imported local fields still require the existing Event/start-date and provenance guards before Save.

Invalidate selectable observations at new read admission, any relevant local field revision, activation/revocation, remote mutation admission or known source/target change. A newer read failure never revives an older choice. Successful resolution consumes the selectable candidate; repeated callbacks cannot apply a second choice. A local edit while reading may still yield a displayed candidate, but the user must review choices bound to the new current field revision. Re-rendering creates no new remote authority. Local checkpoint completion is serialized and must not restore an earlier candidate/baseline.

When automatic safe hydration is already permitted and no uncheckpointed explicit acceptance is outstanding, keep it. Only protected/incompatible loads enter explicit review. While an explicit acceptance is outstanding, later reads supply candidates/status/assets but cannot silently replace its C/E/R or clear its transition restriction. Expose local versus observed values for name/category, description (plain/rich as one group), schedule (full temporal group) and location (city/coordinates as one group). Highlight differences without a three-way merge. Preserve invalid/raw local values; compare remote projections using existing normalization, never reparsing a token from display DateTime.

Alternative rejected: another generic conflict domain/repository, a second hydration scheduler or a persisted candidate history. One editor and its existing latest-read tokens suffice.

### 2. Two explicit field choices, neither is a remote write

Preconditions shared by both: exact current account/session/target/activation/observation and current field revision; fully decoded fresh detail; no physically running conflicting operation, pending local mutation, unresolved field intent or local settlement repair; current staff authority not denied. Recheck inside the existing local tail immediately before changing baselines. Failure/staleness returns a settled no-effect result; request a new observation/review, never act on a replacement activation.

| Choice | C / E / P / R and resulting authority |
| --- | --- |
| Accept remote fields | C=E=observed editable snapshot, R=observed baseline; P remains the exact old checkpoint. Rebind field controllers once without setter callbacks. No disk write or remote mutation. Existing staged work/receipts/owner remain. Establish the acceptance checkpoint obligation below when the chosen C/R is not already physically represented. Pending valid detail may authorize later normal actions; final detail remains read-only. |
| Keep local fields for a later Save | C, E and P remain exactly unchanged; R=observed pending baseline/token and accepted capacity is qualified to this observation. Local dirty status C≠E is unchanged; C may be checkpoint-clean yet remotely unconfirmed. A later separate normal Save validates/captures C under a new intent/attempt with that exact observed token. No saved claim, Update or automatic asset replay occurs on choice. |

The UI describes Accept as replacing current editor fields; P is still the saved local copy until the user explicitly checkpoints or Saves. It must not label Accept durable. Thus process death before explicit checkpoint restores old P/R and requires fresh observation/review. Keep likewise is not a durable authorization record; restart never trusts the runtime choice. Ordinary checkpoint after Keep writes captured C with R=observed; after Accept it writes observed C. No extra archive/undo slot is introduced.

For finalized detail, Accept can show remote read-only fields only after the shared intent barrier permits it; retaining local fields always permits park/return without authorizing Save. Missing detail offers no Accept. Choosing to preserve work is always available as a nonmutating return/park path even when reconciling baselines is forbidden. Local exact staged removal remains available as already contracted.

Alternative rejected: atomically checkpoint on every choice. It would conflate remote acceptance with explicit physical persistence and could silently replace the user's saved local copy. Alternative rejected: borrowing observed token while leaving unresolved request active.

#### F1 — Retain an explicit acceptance until checkpoint proof

Confirmed against source: `AdminDraftSessionState.hasUncheckpointedChanges` compares only C/E (`admin_draft_session.dart:68`), while `activate` refuses that dirtiness, pending local work and hydration (`:181-209`), and the VM delegates target replacement after its operation gate (`admin_submission_editor_view_model.dart:199-248`). Thus proposed Accept B over physical A can be locally clean yet lost on target replacement. `activateBySession` resolves into the same activation boundary; route restoration is not a separate bypass. This is a planning defect, not a claim that the unimplemented Accept operation already fails at runtime.

Extend the existing session state's transition eligibility with one runtime, activation-owned explicit-acceptance obligation, identified by a monotonically changing reconciliation revision. It is not another dirtiness definition or persisted field. C/E/P/R retain their meanings; `hasUncheckpointedChanges` remains C != E. The obligation records why this particular user decision must not be abandoned, independently of ordinary clean hydration.

| Event | Exact obligation lifecycle and effects |
| --- | --- |
| Successful explicit Accept B | After current choice authority passes inside local ordering, set C=E=B and R=observed B, leaving P unchanged. Establish a fresh obligation if P does not already contain the exact chosen snapshot and recorded R. An already physically represented choice needs no obligation. No write occurs. |
| Ordinary target/session replacement | Refuse while the obligation exists, even when C=E and no operation is running. Preserve activation, C/E/P/R, owner, assets and obligation. Explain that the accepted remote fields need an explicit local checkpoint and provide access back to that same editor/checkpoint action. Direct target routes and session hints use the same guard. |
| Same-session rebind or leaving a page | Reuse the active state and obligation. Back/return to the dashboard may leave the page while the application owner retains the session; it must not clear the decision. A later target activation still refuses. No route-exit dialog or automatic checkpoint/discard is added. |
| Checkpoint admission and success | Capture obligation revision together with exact current snapshot and R in existing local ordering. Only successful persistence (or verified equality with actual P) of that captured snapshot/R, under the same active owner and unchanged obligation revision, can clear it. The checkpoint phase of an explicitly requested Save may satisfy the identical proof without an extra write or field Update. Remote success alone cannot clear it. |
| Checkpoint failure or obsolete completion | Preserve physical A and the obligation. A checkpoint captured before the acceptance or an old callback cannot clear a later revision. If typing occurs after a matching checkpoint capture, its success can satisfy that captured obligation, but newer typing remains protected by the existing C != E guard. |
| Another reconciliation | Another successful Accept replaces the obligation with a fresh revision unless its chosen snapshot/R is already physically represented. Keep retains any existing obligation and advances its revision while changing only R, so earlier checkpoint proof cannot release the revised decision. Keep without a prior obligation creates none. Failed/stale choices have no effects. |
| Ordinary hydration, edits or metadata settlement | Ordinary hydration alone never establishes an obligation. While one exists, hydration cannot overwrite the accepted fields/baseline or release it. Typing, read failures and remote/intent metadata settlement neither clear it nor replace it with a disk-equality heuristic. |
| Actual revocation, disposal or process death | Revoke runtime access/authority immediately; no refusal can delay security redirects. Drop the activation's obligation without claiming durability or transferring it to another account. Existing durable A remains private and unchanged unless a captured authorized checkpoint actually committed. Reopen restores P and requires fresh observation; this is the existing explicit-persistence crash limitation. A permitted new activation starts without an inherited runtime obligation. |

A broad `!currentMatchesDisk` guard is rejected: canonical `admin-draft-persistence` explicitly permits switching after ordinary clean hydration B over P=A. This narrow extension refines user-directed recovery only, preserves that canonical case and does not implement Plan 4. Failed checkpoint never grants transition permission; an old completion cannot release a newer obligation even when fields happen to be equal.

### 3. Original intent proof comes before fresh Save authority

Reuse `requestSaveReadBack`, `settleFieldWriteIntent` and local repair. Do not create another intent settlement implementation.

| Original durable Update A/V and observation | Existing contract retained; new-choice policy |
| --- | --- |
| Compatible pending projection A | Existing read-back confirms observed A/token durably, preserving newer C/P. This is field confirmation, not proof old HTTP ended. Only after its local settlement succeeds can a fresh review/new Save proceed. An outstanding no-op A/V is harmless under existing conditional fencing. |
| Compatible pending, other fields, token still V | Only explicit original A/V continuation or further read-back. No rebase, discard of intent or newly captured C/V Save. Preserving/parking C is available. |
| Different token W, different projection | Existing read-back durably settles the obsolete A/V as conflict: W fences future application of A/V, without proving it never committed. Then require a new selectable observation/review; never silently continue the old Save with W. |
| Missing/finalized/provenance incompatible/no exact token/read failure | Block new remote Save. Keep unresolved intent unless existing proof rules establish settlement; terminal status alone is not a fabricated field-version fence. No timeout, restart or current rejection proves an earlier dispatch ended. |

Fresh first-dispatch typed rejection still uses its existing narrow proof. Local settlement failure keeps the intent blocking and offers local-only repair while proof survives; after restart use existing read-back again. Create remains same-UUID replay/adoption; if replay discovers changed/final detail, first complete the existing atomic adoption and then enter this same review, never another Create or another owner.

A token is an opaque equality value; compare equality/difference only, never chronological string ordering. A new Save after Keep is a new captured intent and uses ordinary validation, command reservation, pending/provenance predicates and error handling. A concurrent server edit may reject it again; do not silently refresh/resend.

#### F2 — One accepted baseline supplies new field-write tokens

Source confirms the ambiguity: durable `_save` uses session R for `skipFields` but constructs new intents with VM `_modifiedAtToken` (`admin_submission_editor_view_model.dart:1754-1789`); `_publishDetail` assigns that VM token even when hydration was refused (`:1400-1465`). Existing blocking guards prevent this observation alone from proving a current overwrite bug. Plan 3 must make the new reconciliation authority explicit rather than copying W into another token cache.

For the application-owned durable path, use the session's `AdminRemoteBaseline.modifiedAtToken` as the sole value source for **new** Update intents and for the existing no-op comparison. Qualify that R with the existing accepted remote-context revision and captured activation (account/session/submission/generation), current successful observation, pending status and availability gates. Historical restored R, pending/failed/superseded observation and display metadata are not accepted context. Safe ordinary hydration and existing confirmed-write/read-back paths can still establish accepted authority under Plan 2; a protected conflicting observation requires completed explicit reconciliation. Do not change the legacy non-session path or rework moderation preview tokens as part of this clarification. Existing successful field confirmation/read-back must bind the resulting R to the same current runtime context qualification, rather than leaving a qualification for the previous R. A complete read-back can supply its association count; an incomplete field response must leave capacity unqualified until the already-existing complete refresh, not attach an old count to the new revision. This preserves existing confirmation and no-op behavior without adding a network phase or another token value source.

Keep commits R=W and its accepted observation qualification together inside local ordering only after the original intent has been durably confirmed or fenced/settled and conflicting physical work has settled. At synchronous new Save admission, capture immutable R and its qualification with the fields/owner into the existing Save attempt; recheck that exact accepted context before committing a new intent and before dispatch under existing action authority. If it is no longer current, refuse without borrowing newer metadata, preserve local work and require current recovery. `_modifiedAtToken` may remain display/legacy metadata but cannot independently authorize or populate a new durable field intent. No new persisted token, revision column, journal or parallel mutable token authority is introduced.

Once a new intent is durably admitted, its exact expected token is immutable: new intent B/W dispatches B/W; historical A/V continuation dispatches A/V. Later detail publication cannot substitute W or X into either intent. A field change at the server from W to X returns existing SUBMISSION_CHANGED, preserves local C/P, and follows existing settlement/read-back rules without automatic resend. New no-op or asset-only Save continues to compare against the same qualified R and skip field Update; the checkpoint obligation does not force an otherwise unnecessary Update. Server conditional Update remains the final race boundary even after all client checks.

### 4. Classify hydration and terminal availability, without expanding auth policy

| Result | User path and allowed effects |
| --- | --- |
| Transient transport/read error | Stop loading, mark current mutation authority unavailable, retain C/E/P/R and receipts, show explicit Retry and checkpoint/return. Retry uses the existing load lane with a new read token. |
| Successfully read incompatible projection | Display candidate comparison and applicable field choices; preserve C/P until explicit acceptance. |
| Pending → accepted/rejected | Show actual remote final status separately from preserved local fields. No Save/add/delete/moderation command, no automatic staged continuation. Checkpoint, local staged removal, return and deliberate recheck remain. |
| Typed NOT_FOUND | Settled “record unavailable” with retained work; no remote accept or conversion to Create. Recheck is explicit, never a background loop. Unknown original intent remains unknown. |
| API 401/403 | Immediately invalidate mutation/choice authority and old source/preview acceptance. Do not retry with cached authority. Allow only same-account local work while auth still permits its visibility; existing auth lifecycle hides it immediately on actual revocation/account change. Recovery needs current valid staff auth and a newly successful detail read. No authentication redesign. |
| Unsupported/corrupt local payload or failed reconciliation | Reuse local initialize retry and preserve unknown ownership/rows/files. No fresh owner, clear or overwrite. Repeated error settles each attempt. Remote choices remain disabled until local initialization is complete. |
| Malformed/incompatible remote detail | No actionable candidate; fail closed with explicit reload/return and preserved local data. A valid but currently invalid-for-Save local draft is still preservable via Keep once remote context is compatible; later Save validation remains authoritative. |

Do not add a timer or automatic retry. These are terminal presentation outcomes for an attempt, not promises the remote row can never return. Keep the editor/progress routing model and auth redirects; no new screen stack or material dialog dependency.

### 5. Source and preview freshness remain separate from field reconciliation

Preserve existing SOURCE_CHANGED acknowledgement invalidation and original-detail refresh ordering. A failed refresh leaves source readiness unavailable; show Retry without reviving old acknowledgement. SUBMISSION_CHANGED from Save follows intent recovery; from Apply invalidates preview and requires fresh detail review when fields differ. EVENT_CHANGED requires a fresh preview, not a new field Update.

Every explicit field choice invalidates candidate search results, preview, selected apply groups, source acknowledgement/hash and open moderation confirmation revision. It does not carry them onto the new field baseline or automatically call Preview/Apply/KeepCurrent. A fresh preview must be requested and acknowledged against current source/target evidence. Follow-up IDs remain information, never replacement editor identity.

No delta to the backend moderation capability is needed: the new obligations concern integration of new editor recovery choices with the existing invalidation contract.

### 6. Preserve asset evidence without resurrecting removed work

Use complete authoritative detail after recovery for visible remote associations and qualified capacity. Field-version equality is not asset-list equality; refresh associations even if fields/token are unchanged. Do not alter descriptor path, owner, order or upload receipt on either field choice.

- Local-only items remain pending. Uploaded-only items retain their exact upload receipt; explicit subsequent staged Save uses existing server exact-receipt replay, never assumes an association from URL or dimensions.
- A confirmed association ID present in complete detail with matching exposed URL/dimensions counts once; existing local-only cleanup can finish without upload/association.
- A confirmed ID absent or contradictory in the latest complete detail is historical confirmation, not current presence. Preserve bytes/receipt and flag that item unavailable for continuation; do not clear its association ID to “retry”, clean it merely on old confirmation, or call replay to recreate it. Exact local removal remains explicit and does not delete remote media. Deliberate re-attachment through existing normal user selection is separate work, subject to current pending/capacity guards.
- The detail model omits MIME/duration. Do not infer full-receipt equality, fill missing metadata, add a backend contract or associate solely to obtain richer metadata. Exact upload-only ambiguity still resolves through the existing explicit replay path.
- Over-capacity, metadata conflict, unreadable progress or finalized/missing parent retains work and gives a specific blocker plus local removal/recheck/return. Do not truncate, delete owner, roll back Cloudinary or automatically retry.
- A pure field choice never uploads, associates, deletes, removes local files or reports staged completion. Preserve in-memory confirmed receipts after local metadata failure and use existing repair ordering; do not clear them merely to simplify recovery.

This is a focused client recovery constraint; no tombstone, changed RPC or universal asset reconciliation framework is justified.

### 7. Own new callbacks through existing lifecycle and settlement

The VM owns observation/classification/admission; the domain session alone changes C/E/P/R inside local ordering; repositories remain the only persistence boundaries; UI captures choice identity and only presents/actions it. Use existing command admission for reads and normal Save, and a narrow explicit local resolution action under current mutation admission and local tail. Do not allocate commands per candidate or hold the local tail during HTTP.

Invalidate recovery callbacks on A1 → B → A2 even with equal durable owner. Same-account credential refresh alone does not fabricate a new session or cancel valid local work. Old results release only their own existing physical reservation; B may restore locally after revocation, but cannot start a competing remote mutation until A settles. A queued choice that becomes obsolete is no-op; an already-started checkpoint may commit only to captured A, with no B publication.

## Risks / Trade-offs

- [Whole-field choice can replace wanted local values] → Display both snapshots/differing groups, explicit Accept, retain physical checkpoint until ordinary explicit persistence. Per-field merge remains deferred.
- [Remote changes immediately after observation] → Conditional Save fails closed again; no freshness lease or race-free UI claim.
- [Lost runtime choice after restart] → Deliberate, requires new observation; no new persisted state or migration.
- [Unknown original HTTP can still run] → Existing A/V proof rules and physical reservation remain; no cancellation inference.
- [Stale receipt contradicts complete remote list] → Preserve evidence/bytes and block that continuation; explicit local removal is available.
- [Generic retry error obscures final/denied state] → Classified outcome and deterministic UI tests, without changing server auth policy.

## Migration Plan

Client-only extension; no database/local schema or dependency migration, generated output or coordinated backend deployment. Implement local baseline transitions, then VM recovery/admission, then editor presentation. Preserve old safe-blocked behavior until all three are integrated. Rollback can return to that behavior without losing new-format data because none is introduced. No deployment or PR is authorized by this planning mission.

## Verification and review gates

Use existing support in `test/support/admin_draft_repositories.dart`, `admin_editor_command_harness.dart`, `admin_save_route_harness.dart`, `admin_moderation_error_cases.dart` and real `objectbox_test_store.dart`; load applicable test-support/unit/widget/mounted-safety skills before implementation tests or State edits. Extend existing tests rather than parallel fixtures.

1. Deterministic session tests: each choice's exact C/E/P/R transition; F1 switch refusal, checkpoint success/failure, ordinary hydration exception and obsolete-obligation completion; queued checkpoint/edit/read/revoke permutations; unchanged-token intent refusal and fenced settlement; no implicit persistence.
2. VM tests: F2 capture of qualified R=W only after proof + explicit Keep, superseded W and server W-to-X conflict, with no-op/asset-only field skipping; exact original A/V continuation unchanged; local repair failure; final/missing/401/403/read error; Create replay adoption conflict; source/preview invalidation; assets-only change and confirmed ID contradiction; late success/error and A → B → A.
3. Real ObjectBox/filesystem tests only for new transition/checkpoint/restart invariants: P survives uncheckpointed Accept/Keep; F1 successful checkpoint then switch/reopen restores B while failed checkpoint retains A and blocks replacement; explicit checkpoint persists new R with exact raw C; intent/receipt/file/owner retention across failure/reopen. Reuse existing store fixtures; no fake persistence assertions as durability evidence.
4. Widget/route tests: visible comparison/actions; rejected stale taps; initial and refresh failure retry; terminal park/return and F1 actionable target-switch refusal without a dialog; controller rebind without manufactured edit; progress remains observer-only; auth replacement and old effects invisible.
5. Run focused tests first, then affected Admin domain/data/VM/widget/routing/auth suites and Public preservation regressions, plus analyzer and strict OpenSpec validation. Existing backend contracts need source/grant review, not new DB infrastructure for a client-only change. If a concrete backend change becomes necessary, stop for plan revision and add real PostgreSQL tests before affected execution.

Independent planning review is required before apply. No unresolved product/architecture decision is deliberately delegated to implementation. Exact UI wording/layout is deferrable within these acceptance semantics. Hosted client/device runtime behavior remains unverified by planning; no new native acceptance gate is introduced for unchanged picker behavior.

## Planning validation — 2026-10-28

- Executed on the clean synchronized primary checkout at the identical baseline (using its already-resolved Flutter dependencies): `flutter test --no-pub test/domain/use_cases/admin_draft_session_test.dart test/domain/use_cases/admin_field_write_settlement_test.dart test/ui/admin/submissions/view_models/admin_save_recovery_remediation_test.dart test/routing/admin_save_recovery_ui_test.dart`. Result: **89 tests passed**, exit 0. Planning artifacts live only in the dedicated worktree; this baseline run changed no tracked primary file.
- `openspec validate harden-admin-stale-recovery --strict` passed; status reports all four artifact categories complete. Implementation task boxes remain unchecked.
- Planning diff is limited to the new change metadata, proposal, design, three focused deltas and tasks. No production, canonical, archived/historical, dependency or backend file is edited. Whitespace/path/allowlist checks form the final hygiene gate.
- New behavior is specified, not implemented or runtime-verified. Analyzer/full Flutter/native/real-PostgreSQL suites were not run for this documentation-only mission. Existing backend test source was inspected; prior acceptance totals are not reported as fresh passes.
- Verdict: **READY for independent planning review**, not implementation/release readiness. No blocking product decision remains; exact presentation wording/layout is deferrable. Mobile rollout/device recovery and complete hosted-schema parity remain **NOT VERIFIED** by this audit.

## Independent review remediation — 2026-10-29

F1 is confirmed from the activation and C/E contracts and corrected by the narrow explicit-acceptance checkpoint obligation above. F2 is a token-authority clarification supported by the split baseline/display-token source in the current Save path; it is not reported as an independently reproduced overwrite. The deltas and existing tasks now cover both findings. The earlier 2026-10-28 baseline test and deployment observations remain historical; this remediation runs documentation validation/hygiene only and makes no new production, Flutter, device or backend test-pass claim. Canonical ordinary hydration and Plan 2 intent/conditional-write guarantees are unchanged. No proposal or staged-asset scope change is needed.
