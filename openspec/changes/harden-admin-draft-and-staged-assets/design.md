# Design

## Context

Source contract baseline: `355bc678836894c72cbec31d5929076a1fe8cc79` in `xmattjus/moliseis`. Recheck the anchored source contracts before implementation if that baseline changes.

Admin currently creates route-owned `AdminSubmissionEditorViewModel` instances for new/edit routes. Its Save captures validated input and a field revision, calls Create or Update, ignores the returned detail and permits later field changes; only a matching clean success authorizes the existing route close. Persisted pending images are picked/uploaded/associated immediately. These working paths remain unchanged in Plan 1.

Public already has immutable drafts, explicit checkpoints, stable UUIDs, private staged copies and feature-local arbitration. Its single persisted draft permits cleanup of other Public sessions; that assumption is unsuitable for recoverable Admin account/target sessions. Public's Android lost-data retrieval is triggered by its screen, not eagerly by startup, and the native plugin does not identify which feature launched the picker. Keeping those existing paths is compatibility, not a claim that their cross-feature recovery gap has been fixed.

### Source anchors

| Boundary | Authoritative sources and relevant facts |
| --- | --- |
| Public precedents | Complete artifacts in `openspec/changes/archive/2026-09-11-harden-content-submission-{draft-persistence,local-asset-staging,exit-progress-route,submit-orchestration}/` and `2026-09-29-harden-content-submission-server-idempotency/`; canonical draft, local-asset, navigation, orchestration and server-idempotency specs. Adopt their storage guarantees, not their single-slot cleanup. |
| Public implementation | `lib/domain/models/content_submission_{draft,staged_asset}.dart`, their domain repositories, `lib/data/repositories/content_submission_{draft,staged_asset}_repository_impl.dart`, corresponding entities/mappers; `lib/ui/content_submission/view_models/content_submission_view_model.dart` (`initialize`, `_lifecycleTail`, checkpoint, recovery) and `widgets/content_submission_screen.dart` (`_scheduleRecovery`). |
| Admin integration | `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` (`_captureSave`, `_save`, asset guards, admission/release), editor/location/dashboard screens; `lib/ui/admin/auth/view_models/admin_auth_view_model.dart`; `lib/routing/router.dart`, `lib/config/dependencies.dart`, `lib/main.dart`. No Plan 1 registration or edits to these existing production paths. |
| Domain conventions | `lib/domain/models/admin_submission{,_input,_asset}.dart`, `lib/domain/core/{event_time,description_delta}.dart`: validated remote input is not a draft; reuse frozen Delta, `EventDateDraft`, Europe/Rome `EventTimePolicy`. |
| Schema | `lib/data/services/objectbox.dart`, `lib/generated/objectbox-model.json` and bindings. ObjectBox 5.3.2; store `db_v2-3-0`; Public draft entity 20 UID 8436787422671765122, staged entity 21 UID 4363184663950376915. Keep existing and retired UIDs intact. |
| Backend | Admin repository/implementation; `supabase/functions/admin-content-submissions/{index,admin_submission_store,admin_submission_validation}.ts`; migrations `20260822113151_remote_schema.sql`, `20260822120000_submission_asset_invariants.sql`, `20260825170713_promote_content_submission.sql`, `20260908065810_harden_content_submission_server_idempotency.sql`, `20261002181549_resolve_external_event_submissions.sql`. Admin Create has no replay key; asset RPC locks pending parent and enforces five but has no association idempotency key. Public's replay RPC does not protect Admin. |
| Picker source | `pubspec.lock`: image_picker 1.2.3, image_picker_android 0.8.13+23, platform interface 2.11.1. Installed package `ImagePickerPlugin.java` (`onActivityStopped`, attach/detach); `ImagePickerDelegate.java` (`saveStateBeforeResult`, `retrieveLostImage`, `setPendingOptionsAndResult`, `finishWithSuccess`, `finishWithListSuccess`, `finishWithError`); `ImagePickerCache.java` (`saveResult`, `getCacheMap`, `clear`). See the versioned [official documentation](https://pub.dev/packages/image_picker/versions/1.2.3). |

## Goals / Non-Goals

Deliver tested, reusable local ownership, snapshot and filesystem contracts which Plan 2 can consume directly. Define baseline semantics now, without forcing the current editor to use them. Retain all durable owners in this phase so remote success cannot destroy a recoverable file's parent.

Do not activate durable editing, checkpoint UI, session-switch UI, auth observers, shared picker recovery, tickets/inbox, remote persistence orchestration, remote ID adoption, progress/navigation changes, stale recovery or dirty exit. No backend or native/plugin modification is part of Plan 1. Do not claim that merely storing a future ownership ticket solves Android attribution.

## Decisions

### 1. Choose inert foundation first

| Delivery option | Temporary transitions and deletion cost | Correctness, compatibility and merge cost |
| --- | --- | --- |
| A — Inert foundation (selected) | No transitional Create/Update states, gates or duplicate production owners. One local session component becomes Plan 2's dependency. | Existing UI, Commands and both pickers unchanged; additive schema plus deterministic local tests. Can merge without exposing incomplete Save or a global picker lease. |
| B — Dependent implementation PRs with gated integration scaffolding | Requires route/Provider/Command bridges or a temporary gate and tests for both old/new paths; later gate removal. | Could be safe if completely unreachable, but produces no additional verified user capability before settlement/Save exists. More activation and removal work than A. |
| C — Activate durability with legacy Save guards | Create fences, durable/non-durable branching, parked sessions, field locks and local-finalization retries. | Changes working behavior and still lacks server idempotency. High interaction/test burden; much is replaced by Plan 2. Rejected. |

Plan 1 adds no Provider registration, startup instance, feature flag or production route call to the foundation. Its local domain/data tests construct the component explicitly; Plan 2 has an exact consumer, so this is a bounded prerequisite rather than speculative infrastructure. ObjectBox's existing store may open the additive schema, but opening the store performs no Admin session initialization, picker retrieval or cleanup.

Application-level ownership of `AdminSubmissionEditorViewModel` remains mandatory in Plan 2, using existing Provider/ChangeNotifier and one active in-memory editor. It is deferred, not abandoned. Existing Command admission/physical-settlement/disposal and candidate/preview/revision guards stay untouched in Plan 1 and must be extended rather than duplicated at integration.

### 2. Immutable owner and field model

Proposed `AdminSubmissionDraft` contains a secure UUID-v4 local session ID, authenticated editing-account ID, optional existing remote submission ID and immutable editable snapshot. Remote contributor identity is distinct: an Admin may edit someone else's submission. Account IDs, not mutable email/display names, own local work.

The field snapshot includes nullable category/city/name/description, recursively frozen Delta, full `EventDateDraft` and exact latitude/longitude text, including incomplete, invalid and whitespace/comma forms. Equality includes identity and every editable value; structural comparisons never depend on dialogs, errors, commands, preview/candidate state or source acknowledgements. Checkpoint encoding does not normalize raw fields into `AdminSubmissionInput`.

Durable lookup has one resumable session per `(account, new | remoteSubmissionId)` in this phase, plus a distinct auto technical ID. Inactive target/account rows remain. Unsupported payloads or conflicting duplicate rows are unavailable, not absent. There is no parked-history schema or legacy Create attempt state. A future new-to-persisted target adoption and its uniqueness transition belong to Plan 2's server-confirmed Save contract.

### 3. Keep five kinds of state distinct

Use one small local `AdminDraftSession` component, proposed under `lib/domain/use_cases/`, depending only on domain models/repository contracts and `Result`. It owns one active local context and serialization, not HTTP, platform retrieval, Provider, Widgets or Commands. It is not a multi-editor manager. A narrow immutable session-state value supplies these facts:

| State | Meaning |
| --- | --- |
| C — current | Current immutable editable snapshot. |
| E — effective comparison baseline | Last checkpointed or authoritatively hydrated state against which new user mutations are compared. `hasUncheckpointedChanges = C != E`. |
| P — last physical checkpoint | Exact last successfully read/written checkpoint; null when authoritatively absent, unavailable when read failed. Hydration never assigns P. |
| R — confirmed remote baseline | Last authoritative remote editable projection/status/version supplied by the integration caller; optional for new mode. Local persistence cannot confirm a remote write. |
| Durability metadata | Unknown/absent/known exact owner, and whether P's editable content equals C. Owner existence is not proof that C is on disk. |

Persist one checkpoint snapshot and its then-known remote baseline, not every in-memory state or duplicate C/E/P history. Restoration initializes C = E = P; it restores the saved R as historical comparison data, not fresh status/authorization. Raw coordinate strings participate exactly in local equality; comparison with R uses existing validated numeric projection, so equivalent `41,0` and numeric `41.0` do not invent a remote edit. Invalid coordinate text remains remotely dirty.

Authoritative hydration is an explicit input, not a network fetch performed by this component. When no user edits are pending and the stored checkpoint has no unconfirmed remote field intent, accepting remote B sets C = E = B and R = B, leaves P = A, and performs no disk write. Local dirtiness is false; target switching is allowed even though B is not physically checkpointed. A subsequent edit C makes local dirtiness true. Explicit checkpoint writes that captured C and on success sets P = E = C. An explicit checkpoint of unchanged hydrated B also writes B if known P is A; the equal-checkpoint optimization applies only when the physical snapshot matches. A fresh untouched absent session's ordinary checkpoint is a no-op; a future caller requiring durable ownership must request the initial real write.

Restart before another checkpoint restores P = A and its recorded remote baseline, never claims B was stored, and waits for Plan 2's fresh remote load before treating it as current remote authority. A locally checkpointed remote edit is protected even if C = E: if P differs from its saved R and newly fetched remote context is incompatible, hydration returns a preserved/blocked outcome instead of overwriting that intent. Uncheckpointed typing is also protected. Compatible refreshed remote metadata must not erase the current field snapshot. No general version history or autosave is introduced.

A checkpoint captures A inside local arbitration; synchronous user mutation to B may occur while persistence awaits. Successful completion sets P/E to A, keeps C = B and remains dirty. Failed persistence changes neither P nor E. Hydration/baseline-changing effects are serialized with checkpoint completion, so a late checkpoint cannot reset a later accepted hydration. Stale activation tokens cannot publish into a replacement session.

### 4. Retain owner lifetime independently of field snapshots

**Owner lifetime is not checkpoint lifetime.** Replacing a checkpoint writes content under the same owner row. Accepting remote hydration only changes in-memory comparison/remote state until an explicit checkpoint; it does not write or delete the owner row. Neither operation deletes descriptors or files. The Plan 1 component/repositories expose no draft-owner deletion/retirement or remote-success finalization API. Removing a staged asset does not remove its draft owner, even when the asset was the last one. This retention-only first phase is simpler than implementing a temporary retirement algorithm or an incomplete inbox reference counter.

Fundamental invariant for the integration: a durable owner remains while any valid staged file, pending inbox delivery/acknowledgement, reserved incoming local commit or other committed recovery obligation requires it. Plan 1 has no inbox/HTTP producer and never retires owners. It tests retention during field checkpoint/baseline replacement and staging/removal. It must not add placeholder inbox tables, arbitrary obligation registries or caller-provided `safeToDelete` booleans.

Plan 2 must decide retention versus retirement at a short exact-session local arbitration boundary, accounting for pending recovery reservations before delivery, not just newer field checkpoint numbers. Remote HTTP stays outside that boundary. Confirmed Update is not authorization to retire. Acknowledgement failure keeps the obligation; in-flight staging orders either before finalization or reserves its still-live owner before finalization can conclude. The detailed Update/inbox interleavings are Plan 2 acceptance cases below; no legacy Update retirement path is implemented here. Future explicit discard must invalidate incoming work and settle its obligations before removing the owner; a field-only clear cannot be used as discard.

### 5. Two additive entities and narrowly scoped local arbitration

Add proposed `AdminSubmissionDraftEntity` with auto technical ID, validated unique account/target lookup key, local session/account/optional remote IDs and versioned checkpoint/remote-baseline payload; add `AdminSubmissionStagedAssetEntity` with auto-ID ordering, owner/session, SHA-1 and canonical relative path. Generate new IDs/UIDs from inputs using the existing workflow during implementation; never hand-assign or reuse existing/retired UIDs. Keep Public's fixed row, existing entities and store directory. A pre-change populated real-store fixture must survive the upgrade with Public/settings/content/sync-cursor data intact. No recovery entity is justified until its platform contract is known.

Domain repository contracts load/write exact owners, acquire/resolve/remove/reconcile their staged files, and report expected storage errors as `Result`. Draft loading preserves absent/valid/unknown distinction. A failed or unsupported read prohibits identity-dependent writes and null-owner cleanup. No blanket catch converts programming errors into successful initialization.

The single local session component uses a Public-style future tail for local initialization/checkpoint, staged commit/removal, local activation and hydration publication, always released in `finally`. Concurrent initialization for one activation shares one future; readiness requires complete local reconciliation. Setters change immutable C without saving. Calls capture account/session/target/generation; revocation suppresses later runtime publication, while an already-started commit may finish durably for its original retained owner. A normal different-target activation refuses uncheckpointed memory or unsettled local work; explicit auth/account revocation discards private runtime authority without exposing it to the next account. Reopening A after B has a new generation, so A1 cannot publish into A2. These are local-component contracts exercised by tests, not active auth observers or new UI in Plan 1.

### 6. Admin storage follows Public guarantees with separate ownership

Private root: application support `admin_submission/staged/<account-uuid>/<session-uuid>/<sha1>`, with canonical relative descriptor paths. Public remains under `content_submission/staged`. All compound local operations use the component's arbitration; filesystem repositories validate exact durable owner before accepting bytes. No asset can create an implicit unrelated owner.

Acquire: validate owner/size/capacity → SHA-1 → session deduplication → unique temp copy → close/flush and revalidate size/digest → same-directory rename → descriptor persistence → runtime publication. Existing limits are five combined known-associated/staged assets and 10 MiB per file. SHA-1 is accidental deduplication, not an authenticity primitive; remote URLs do not provide byte deduplication. Associated count is supplied by a verified future integration context, with no network fetch in storage. Refuse acquisition when that count is unknown. Restoring a valid count above five preserves every committed local file and reports over-capacity; local removal stays available. Order is explicit ascending descriptor ID, not incidental store iteration.

Reconcile verified exact owners only: retain lowest valid duplicate descriptor, remove malformed technical rows and missing/corrupt/oversized descriptor-backed entries, clean contained temp/descriptor-less files best-effort. Never reconstruct orphan files. Unknown ownership blocks reconciliation; a hard reconciliation failure publishes no partial runtime list. Valid inactive sessions are not orphans. No global Admin sweep or Public-style `reconcile(null)` cleanup-all method.

Reject absolute/traversing/noncanonical/wrong-owner paths and symlinks at root/account/session/file levels. Enumerate without following links; only unlink contained link entries, never their external targets. Revalidate bytes at acquisition/reconciliation and resolve structurally afterward, matching Public. A hostile process racing filesystem syscalls and hardware power-loss durability are outside these guarantees. Normal removal deletes the exact descriptor before contained file cleanup; missing file is success. Descriptor failure preserves runtime state, later file-cleanup failure leaves non-restorable residue with a path-free diagnostic. No remote deletion or rollback occurs.

### 7. Android recovery: defer activation, do not ship a global unresolved lease

The pinned plugin does not expose a reliable settlement/correlation contract. `onActivityStopped` saves options; Activity detach releases/recreates the delegate. `retrieveLostImage` reads SharedPreferences-backed result data, returns empty when none is present and clears nonempty/invalid cached data before returning. `setPendingOptionsAndResult` clears old cache when a new pick is admitted. Results have no application operation/feature/account token. `finishWithSuccess(null)` with no surviving callback writes no cancellation marker. Multiple-media empty results may follow a different cache path; no universal durable terminal signal exists across the supported calls. Do not infer Android framework guarantees beyond these observed plugin behaviors.

| Case | Source-backed observation | Consequence for integrated recovery |
| --- | --- | --- |
| Ticket committed, crash before launch | No native operation necessarily started; retrieval can be empty. | App ticket and native launch are not atomic. Moving the write after launch instead loses attribution if recreation happens first. |
| Activity destroyed while picker open | Plugin saves options on stop and replaces delegate on detach/reattach; Dart engine lifetime depends on host lifecycle. | Do not equate Activity recreation with process death or assume the original callback survives. |
| Process killed while picker open | Dart owner disappears. Selected result may later be cached by the recreated host when it returns without a callback. | Retrieval can recover selection, but no feature/session token is returned. Neither OS result delivery nor process survival is guaranteed. |
| Cancellation callback lost | Single-image cancellation without callback does not persist a result/terminal marker. | Empty cannot distinguish cancellation, not launched or still pending. |
| Delayed result after empty recovery | Empty reads only present cache; it does not cancel or await an external intent. A later callback may cache data. | Overwriting an app ticket may misattribute old data. A new launch can clear older native cache. |
| Retrieval exception | Caller cannot prove whether native consumption occurred before failure. | Neither guessed settlement nor blind owner reassignment is safe. |
| Native consumption before inbox commit | Cache is cleared before Dart can durably copy bytes. | Strict crash-safe exactly-once recovery is impossible under this contract; uncommitted bytes may be lost. |
| Repeated empty restarts | No persisted native cancellation/operation token is added by another restart. | Age/restart counts/timeouts are not settlement evidence. Global indefinite refusal is not an acceptable substitute. |

| Alternative | Decision |
| --- | --- |
| A — Verified settlement through current supported API | Unavailable for all required cases: no token, cancellation marker or acknowledgement. A single live callback proves only its live request; it does not fix interrupted retrieval. |
| B — Move/narrow ownership commit | Before launch has the observed gap; after launch risks death before ownership exists; Dart and the platform do not share an atomic commit. Not sufficient. |
| C — Defer shared transition to Plan 2 | Selected. Leave both production launch sites and Public retrieval untouched. Plan 1 supplies exact-owner storage and verified-copy intake only. No ticket/lease can disable either picker. |
| D — Supersede unresolved tickets, timeout, or add native shim now | Supersession cannot identify a delayed old payload; timeout is not evidence. A maintained native/plugin change might solve the missing contract but adds Android lifecycle/API/version obligations. Do not authorize it before evidence and an independently reviewed design. |

Plan 1 therefore contains **no coordinator instance or implementation, durable picker ticket, inbox entity, plugin wrapper, startup reorder, consumer replacement or new platform call**. Its only low-level recovery infrastructure is the same owner-verified private file intake any future handoff will call. No migration for an uncertain inbox format is added. Public keeps its existing best-effort screen/VM consumer; Admin keeps its live picker path. Their existing cross-feature weakness is outstanding, not silently certified safe. Neither feature is routed through the new foundation, so committed Public work is not migrated, dropped or reclassified.

Plan 2's shared activation is blocked until a reviewed contract demonstrates both safe attribution and usable subsequent picking after pre-launch interruption, lost cancellation, delayed results, retrieval error and repeated restarts. If that requires a native/plugin or upstream change, define and review it as a dependency before enabling integration. A decline to change the plugin must leave shared activation deferred, not reintroduce permanent global lockout. No arbitrary timeout or unsafe empty-as-settled fallback qualifies.

### 8. Mandatory Plan 2 integration handoff

Plan 2 receives exact owner/target identity, immutable C/E/P/R state, owner-known/current-physically-matching metadata, ordered descriptors/private paths and the local initialization/checkpoint/acquire/remove/reconcile boundary. It adds the application Provider owner and route bindings, auth/session revocation, remote loading and a single integrated Create/Update/ID-adoption/staged-Save/Progress transition. Until that is complete, the route-owned production editor is the sole editor and has no durable-foundation dependency.

Plan 2 must evaluate server-authoritative Admin Create and asset-association idempotency/reconciliation before enabling retries or new-mode staging. Admin Edge derives account identity; pending-only/five-image RPC and RLS remain authoritative, but there is no Admin replay key today. Prefer a coherent server contract over indefinite client fences; any required backend work needs its own reviewed scope/dependency. Do not assume Public's idempotency applies or promise exactly-once from local UUIDs. Confirmed associations are independent of field hydration; incomplete/empty update envelopes cannot erase known associated assets.

Once a verified platform contract exists, Plan 2 must replace **both** launch sites and Public's consumer atomically with one startup retrieval owner, durable feature/session/account attribution and private handoff. Acquisition must not depend on opening the original route or restored auth; a bounded inbox preserves verified bytes while the exact account/session is unavailable. No recovered Admin media auto-uploads; explicit Save owns remote persistence. Ineligible/unknown owners never receive another session's bytes. Committed inbox data is retained, not silently discarded. The unavoidable native-consumption window remains explicit.

Feature commit precedes inbox acknowledgement; interrupted acknowledgement permits same-owner deduplicated replay. Explicit removal must wait for acquisition outside feature arbitration, terminally settle matching inbox references before deleting the feature descriptor, and reject delivery captured before removal when it rechecks inside arbitration. Owner retirement must include pending-delivery/ack/in-flight obligations. These are requirements to define and verify in Plan 2, not dormant coordinator code or a future operational report in Plan 1.

#### Plan 2 acceptance matrix — not Plan 1 implementation tasks

| Deterministic setup | Required integrated outcome |
| --- | --- |
| Update A pending; recovered file commits before completion | Remote success updates its own baseline; owner and staged file remain restorable. |
| Inbox item reserved/pending before staging; Update finishes first | Finalization preserves owner for delivery; later staging cannot target a retired/missing owner. |
| Update finishes before a new recovery reservation | Reservation binds an existing retained owner or safely rejects a retired owner; it never recreates/reassigns one by convenience. |
| Feature commit succeeds; inbox ack fails | Keep owner, staged file and unacknowledged obligation across restart. |
| Remote success; process dies before local cleanup | Reconstruct owner obligations before any retirement; do not replay remote effects merely to repair local cleanup. |
| Checkpoint B commits during Update A | B remains the physical checkpoint; remote baseline confirmation of A does not declare B remotely saved. |
| No staged/inbox/in-flight work, unchanged expected session/checkpoint | Retirement may proceed only after a serialized exact-owner recheck; safe retirement is not inferred from remote success. |
| Ticket-before-launch crash, lost cancellation, delayed old result or repeated restart | Verified future contract permits continued picking without unrelated attribution or indefinite global lockout. |
| Public result while Admin active, and reverse | Exactly matching feature/session gets eligible local bytes; visibility is not attribution. |
| Auth pending, logout or different account | Commit private handoff bytes without delivery to unrelated account; reauthorize exact owner and revoke stale publication/new phases. |
| Native consume before inbox commit | Inject interruption and document uncommitted-byte loss; never claim exactly-once recovery. |
| Ack failure then remove, including pending copy/captured delivery | No replay resurrection; removal failure does not lose the still-recoverable item. |

Plan 3 defines explicit stale/conflicting remote baseline and ambiguous-outcome recovery UI, consuming preserved local work. Plan 4 defines dirty-exit choices. Neither plan restores deleted transitional Create machinery; Plan 2 must provide a complete usable Save/error contract before activation.

## Public-to-Admin reuse matrix

| Precedent | Adopt / Adapt / Exclude |
| --- | --- |
| Stable UUID, frozen Delta, EventDateDraft, captured checkpoints | Adopt in local foundations; add editing account and raw coordinates. |
| Local versus remote truth | Adapt with distinct C/E/P/R so server hydration is not user dirtiness. |
| Fixed row 1 / cleanup of every inactive Public session | Exclude; Admin retains account/target sessions and owners. |
| Private verified copy, relative path, deterministic reconciliation | Adopt under separate Admin root; use real-store/filesystem tests. |
| Feature-local future tail plus Command admission | Adopt local ordering in inert component; extend Commands only in Plan 2. |
| App-owned ViewModel and route binding | Mandatory Plan 2 integration; not an active Plan 1 promise. |
| Public lost-data consumer | Unchanged in Plan 1; shared replacement is blocked on the missing platform contract. |
| Public replay RPC, progress route and dirty exit | Do not copy Admin guarantees by inference; Plan 2/4 and explicit backend design own them. |

## Obsolete Admin requirements disposition

Preserve `improve-admin-submission-editor-workflow` and its unimplemented tasks/specs. Its notice points here; do not archive it as delivered or synchronize its unimplemented requirements. Remaining executable supersession/withdrawal belongs to reviewed later-plan definition.

| Old requirement / commitment | Disposition |
| --- | --- |
| Successful Save stays open, including dialog cases | Plan 2; current Save effects unchanged until replacement. |
| Same editor adopts initial create result; subsequent Save updates | Plan 2 integrated remote identity and idempotency design. |
| Pre-create image selection/removal/capacity | Plan 1 internal storage only; Plan 2 UI activation and complete Save. |
| First Save creates before uploads; ordered persistence | Plan 2, entirely. |
| Partial upload/association retry progress and ambiguity | Plan 2/server-contract evaluation; no transitional local fence. |
| Immediate persisted pending asset behavior / final-status guards | Preserve current behavior in Plan 1 and during Plan 2 integration. Recovery is not automatic remote replay. |
| Route-scoped/in-memory-only staging | Reject as eventual durability design; separate account-owned storage now, application owner mandatory in Plan 2. |
| Disposal-safe results, no later remote phases / no rollback | Preserve existing guards now; extend to activated session/account generations in Plan 2. |
| Dashboard refresh independent of Save close | Plan 2 with navigation; no Plan 1 dashboard edits. |
| Dirty exit | Plan 4 boundary; not delivered by the old normative delta. |
| Remote stale recovery | Plan 3 boundary; existing event/source guards preserved. |
| RAM-only upload retry metadata / avoiding refresh-only trackers | Plan 2 evaluates durable remote progression; retain KISS rationale against unnecessary tracking. |
| No backend exactly-once assumption | Retain limitation; Plan 2 must evaluate Create and association contracts explicitly. |

## Migration Plan

Plan 1 implementation may merge its two additive entities, local foundations and tests without changing production flows or introducing feature flags. Generate only intentional schema changes, verify a populated pre-change store and preserve existing Public IDs/data. Rollback must use a schema-compatible build; do not delete the database or promise untested downgrade behavior.

Plan 2 depends on these foundations and a reviewed settlement/attribution contract plus an explicit server idempotency/reconciliation decision. Backend/native dependencies, if required, are reviewed separately. Activate editor and shared picker transitions coherently only when complete; preserve the existing paths until then and remove the superseded integration in the same change. No parallel production editor architecture is retained indefinitely.

## Risks / Trade-offs

- [Current cross-feature Android attribution remains imperfect] → Plan 1 preserves the existing production path without claiming a fix. Safe integrated activation remains blocked; no new global lockout is shipped.
- [Uncheckpointed edits or uncommitted native media can be lost] → Explicit checkpoint and verified descriptor commits define durability. No autosave or crash-safe exactly-once claim.
- [Rename succeeds before descriptor put] → That uncommitted file can be lost and cleaned; never reconstruct it. Previously committed siblings remain recoverable.
- [Unknown draft/descriptor or hard store failure] → Quarantine ownership, return failure and publish no partial restoration; never equate failure with absence.
- [First phase retains empty owners] → Accepted small disk cost; no unused retirement/finalization machinery. Plan 2 defines safe owner retirement together with its producers.
- [Schema/integration drift] → Recheck source contracts before implementation; generator UIDs, existing remote guards and real-store fixtures are authoritative.
- [Device behavior exceeds automated tests] → Separate Android Activity-only and process-death verification; iOS device/macOS smoke checks remain part of future integrated activation, not proof supplied by storage tests.
