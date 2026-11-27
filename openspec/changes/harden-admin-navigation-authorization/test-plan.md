# Verification plan

## Dependency comparison

Reproduce the original opt-in characterizations on unchanged 18.0.2 in an
isolated checkout. Retain the original inputs and outcomes locally. Reuse
the same probes against the dependency-only commit with the latest stable
release, accounting for intentional changes in control flow. At the
checkpoint, record outcomes by finding and distinguish any revised
assertions from the original comparison. Keep permanent regression tests
named `*_test.dart` with the desired behavior.

Run affected routing suites on both baselines. Include navigation shell
branch switching, preloaded and retained branches, explicit and system
Back, deep links, canonical paths and queries, GeoMap NAV-01, Search
focus/navigation, Gallery, editor picker, public submission, sync,
restoration, and Admin login, recovery, dirty exit and Save Progress.
Use the existing NAV-01 assertions on the upgrade. Enable the test when
they pass for the intended branch-activity reason. Otherwise retain the
exact expected behavior and an accurate skip annotation. Record any
upstream regression before considering a change to application scope.

## Deterministic Admin regression matrix

Use the real `buildAppRouter` via `AdminSaveRouteHarness` or an existing
routing harness that exposes the required state. Use existing
`AdminDashboardCommandHarness`, auth and draft doubles, and controlled
repositories where widget rendering adds no evidence. Follow the test
support reuse and mounted-context guidance. Use distinct synthetic
account, submission, contributor, ignored-source and draft sentinels.
Capture actual Page, Route, provider owner, modal and operation identity.
Record repository invocation arguments, counts and order.

For the critical frame-gap case, install and settle the source route,
capture the installed Page and Route, commit the imperative cover,
drain only microtasks, and assert the cover match is committed while
the source is still physically current. Change observed auth before
pumping the next frame. Check the resulting pages, then deliver
`handlePopRoute` and inspect actual active/current routes. Probe visible,
hit-testable and semantic exposure, focus and retained callbacks at
relevant transition frames, including a callback invoked before routing
reconciles. Advance explicit frames and completion boundaries with
controlled Completers. Use settling only for stable setup or bounded
transitions and avoid sleeps or broadened timing tolerances.

| ID | Representative case | Acceptance evidence |
| --- | --- | --- |
| A1 | Sign-out, anonymous, same-account demotion and auth stream error followed by A recovery. Queue A→B→A and loss→A before a frame, including multiple SDK observations before asynchronous delivery. | Original authority is permanently retired. No old page, owner or callback becomes eligible. Fresh A gets authorized reads. Duplicate events, same-account token refresh and profile updates preserve owner, route, admitted execution and read counts. |
| H1 | Populated Dashboard with ordinary external loss and with an uninstalled imperative cover. Include sign-out and same-account role revocation. Include the already-installed-cover control. | Login is current after reconciliation. Original Dashboard Route/Page absent from Back history. Submission, city, contributor and ignored-source sentinels and actions cannot resurface. Assert installed pages, semantics and hit testing through transition frames. |
| H2 | Direct A→B with ordinary Dashboard and with a pending cover. Check Back after replacement. | A's owner is retired even while mounted. B uses fresh owner and reads. No old cached rows, snapshots, pending IDs, refresh or recovery state, controls, or stale completion. No old Page is reachable. |
| H3 | Malformed diagnostic, existing/new Editor or Save Progress under an uninstalled cover. Include dirty exit, pending exit decisions or a Save attempt in representative paths. | Obsolete Page/Route and pageless modal become unreachable. Security removal proceeds. Back cannot reactivate old routes. Ordinary same-authority dirty exit, Save restrictions and Back still work. |
| H4 | Enter Admin from Settings above a known ancestor. Cover Admin with public navigation or running/fatal Sync, revoke or replace auth, release Sync. Restore state containing mixed public and obsolete Admin history. | Public-only auth transitions preserve route and owner identity. Preserve valid public ancestry and eligible destination where possible. Public Sync return stays exact, stale Admin return resolves to safe landing. Running/fatal Sync takes precedence, and restoration never revives old authority. Preserve supported same-account resume via fresh validation. |
| D1 | Capture old callbacks for initial read, filter, retry/manual/pull, ignored read, reactivation, pending link, Editor existing/new, recovery/dialog, Back/logout and navigation continuations. Run representative UI callbacks before and after reconciliation and resumed A or B. | No reservation, dispatch, navigation or feedback from retired authority. Cover the original real tap and invoke stale closures directly. Use existing authorized controls to check each distinct admission path. |
| D2 | Initial read pending at revoke, and work reserved before its body runs. Revoke synchronously in a running/business-state listener and between reservation and async repository entry. | Pre-dispatch work has zero repository calls. A pending initial read affects neither owner presentation nor B's fresh reads. No unsafe or stuck reservation and no new notification from retired owner. |
| D3 | Complete admitted reads and mutations with success and failure after revocation. Also revoke during the first of the coordinated post-mutation reads. | No data, expected or unexpected UI error, success, ID, link, follow-up read or protected navigation. Private settlement and cleanup are exact-once, including handled unexpected throws after upstream teardown timing and fail-loud assertions. Preserve error routing and independent authorized lanes/refresh order. |
| E1 | Hold first activation, distinct account-qualified session lookup, or later staged reconciliation. Switch to B while pending. Resolve A before B begins or while B's activation is pending; then resolve in the opposite order as needed to distinguish the boundaries. | No A runtime installation, detail dispatch, follow-up private work or displacement of B. No old visit may start under B. Use account- and visit-qualified counters and state identity. Preserve A checkpoint and staged assets; A can recover the same durable owner on a fresh visit after returning. |
| E2 | Keep recovery, moderation/dirty modal, Save Progress or picker state across revocation. Reuse effective existing pending Save, guarded exit and restoration tests and add only uncovered authority boundaries. | Old callbacks and results have no private work or route effect. Exact modal dismissal preserves unrelated routes. Correct attempt identity and owned durable settlement survive. Current authorized restore/recovery and picker paths remain valid. |

F1 maps to H1–H2, F2 to D1–D3, F3 to H2 and D1–D3, and F4 to
H3–H4. A1 and E1 cover the source-established continuity and pending
activation gaps, with E2 protecting existing Editor behavior.

This matrix groups independent failure boundaries. It does not require
every auth transition crossed with every route or outcome. Existing
`admin_route_test.dart`, `admin_editor_navigation_admission_test.dart`,
`admin_session_target_route_test.dart`, `admin_dirty_exit_route_test.dart`,
`admin_save_progress_route_test.dart`, `admin_save_recovery_ui_test.dart`,
`sync_redirect_test.dart` and restoration tests are starting points.
The opt-in probes covered installed history, sentinel visibility and
fake dispatch, but do not establish queued auth continuity, pre-dispatch
reentrancy, fully qualified pending Editor activation, mixed restoration
or device behavior. Add command-level coverage for duplicated settlement
paths only where existing coverage does not assert the changed boundary.

## Independent review regressions

| ID | Characterization at the reviewed implementation | Regression acceptance |
| --- | --- | --- |
| R1 | In Home → Admin → public form, retiring Admin opened a dirty-exit dialog or left Admin in installed history during submission or finalization. An already pending public go could also leave Admin beneath the open decision. The ordinary submit flow pushes Progress above the form as a separate match. | Assert the actual Navigator removes the obsolete Admin Page and keeps the original form, owner and match, and keeps the original Progress route during finalization. No security-triggered checkpoint, discard or exit dialog. Test genuine Back while dirty or submitting, and a pending public go before or during its decision, including approval and cancellation. |
| R2 | Refresh errors could appear concurrently with unrelated app feedback or before an already-visible app message. | Exercise visible and queued Dashboard retirement with unrelated feedback before or after it. Check same-turn native dismissal, recovery revalidation after the surviving tail, and global clearing with a queued owned entry. Retain the existing Dashboard authority and DRAFT-11/DRAFT-12 regressions. |
| R3 | Loss, anonymous sign-in and renewed Admin authority can commit without an intervening Navigator build. A stale restoration can also supersede the fresh landing request. | Exercise same-account and different-account admission at the root and above Home, plus the superseding restore. Require a rendered fresh owner, a fresh read, retirement of private state and work, and valid Back history. |
| R4 | Sign-out on wholly public history should leave the router idle. | Verify Gallery configuration, route information, Page and Back history remain intact. Verify a dirty public submission keeps its state and the usual Back decision. |

For a GoRouter upgrade, run `admin_authorization_history_test.dart`
for Page replacement, public ancestry, pending commits and restoration,
`content_submission_route_test.dart` for the scoped public restore and
ordinary exit decisions, and `explicit_back_test.dart`, `admin_route_test.dart`
and `post_gallery_lifecycle_test.dart` for explicit Back and imperative
match reconciliation. Keep the original NAV-01 assertions enabled in
`geo_map_route_test.dart`.

## Disposable Supabase runtime gate

Use a disposable local stack with the repository's actual gateway, Auth,
migrations and Admin Edge Function plus synthetic Admin A, Admin B and
non-Admin/anonymous controls. Capture effective HTTP status and response
classification, user lookup/role decision when observable, and synthetic
effects before/after each case using local trusted verification. Include
a successful authorized read and a reversible or disposable synthetic
moderation operation as controls. Keep authorization headers, credentials
and tokens out of committed evidence and logs.

| Case | Expected verification |
| --- | --- |
| Valid unexpired access token after sign-out | Record the old token's effective local response and effects, and distinguish refresh/session termination from expiry. Compare with Supabase's documented contract before assigning severity. |
| Admin role removed with old token | Exercise actual gateway and user lookup with a token issued before removal. Record whether fresh server user metadata denies privileged data and writes and whether any effect occurred. Compare to the repository's strict Admin contract. |
| Client switches from A to B | Compare server decisions for the previously issued A credential and for B, and correlate which synthetic principal the shared client actually uses for a permitted B request. Identity replacement alone need not invalidate a still-authorized A credential. |
| Request already authorized when authority changes | Hold a controlled already-authorized synthetic request, complete it after the transition and record its effect. Separate its server settlement from client publication and follow-up admission. |
| New request after observed revocation | Assert no obsolete-origin request reaches the local endpoint, including delayed dispatch or follow-up from A after B. Use endpoint observations and client counters. |

For the already-authorized case, control the handoff after authorization
and before the synthetic store effect through an existing handler test
seam or disposable local instrumentation. Keep the normal endpoint
and SDK path for token comparisons. Identify a handler-only timing
observation as such if the local gateway path cannot be paused there.

Record stack versions and differences from the deployment. If local
behavior cannot establish a deployment-specific property, record it as
unverified and retain the open release gate for owner disposition. A
material backend authorization defect requires separate remediation
authorization and keeps the release blocked. Use no production accounts,
roles, submissions or deployment changes.

### Observed local runtime results

The disposable stack ran the repository migrations and real Admin function
through Supabase CLI 2.122.0, Docker 29.7.2, GoTrue 2.197.0, Kong 2.8.1,
Edge Runtime 1.77.8, and Postgres 17.11.0.006. Anonymous sign-in was enabled
in the isolated runtime configuration to establish that control. Both
stack instances were stopped and their disposable data removed.

| Case | Effective result |
| --- | --- |
| Authorized baseline and source reactivation | A and B each received HTTP 200 for list. An authorized synthetic `unIgnoreSource` returned 200 and direct SQL confirmed `ignored_at` cleared. |
| After sign-out with the previous unexpired token | Sign-out returned 204. Subsequent Auth user lookup returned 403 and the function returned 401 `UNAUTHORIZED` on the same token. |
| After server-side Admin demotion with the previous token | Auth user lookup returned 200 with current `admin=false`. The function returned 403 `ADMIN_REQUIRED`. Non-Admin and anonymous controls also returned 403; missing credentials returned 401. |
| A-to-B account switch | While A remained an Admin, A's previous credential and B's credential independently returned 200. In the separate shared-SDK run, an observing transport verified one actual list request from A and one from the fresh B owner, both 200. The captured A callback added zero endpoint requests after B was observed. |
| Already-authorized operation | A database row lock held the real request inside `set_source_ignored` after authorization. A's Admin metadata was revoked, then the lock transaction completed. The in-flight operation returned 200 and cleared `ignored_at`. A later request with the same token returned 403. |

The shared-SDK run observed callback rejection at the actual endpoint.
Controlled Flutter tests exercise zero repository entry after reservation
and suppression of late publication and follow-up work. These local checks
establish no deployment-specific behavior. The public release decision and
physical-device gates remain open.

## Owner-executed physical-device release gates

**Status: OPEN.** Use a release-candidate build and synthetic accounts and
data on physical Android and iOS. Record build SHA, GoRouter version,
platform/device and OS, result and concise observation for each gate.
Emulators, widgets and simulator coverage support diagnosis.

| Gate | Physical acceptance |
| --- | --- |
| Android Back | Exercise system/hardware Back and predictive Back commit and cancel, including while a cover is installing or authorization changes. Verify inactive shell branch retention, no obsolete Admin reveal and stable eligible Back behavior. |
| iOS Back | Exercise swipe Back commit/cancel and explicit app-bar Back during ordinary and authority-driven departures. Confirm correct public ancestry and no reveal of retired content. |
| Both platforms, transitions | Rotate and background/resume during navigation and auth change. Check protected pixels, accessibility focus and interaction during transition frames, with an active moderation or dirty dialog and in Save Progress while work is outstanding. Check that authorized exit protections still apply. Verify retired Snackbar withdrawal, unrelated feedback duration and accessible announcements. |
| Both platforms, restart and account replacement | Restart with an A checkpoint and staged assets plus saved navigation state. Use B, verify A's editor and progress cannot resume, then return as A and recover the durable checkpoint and assets through a fresh visit. |

Keep unresolved manual results in the linked navigation release record.
Pass only gates with observed evidence and retain any limitations for
the project owner. Implementation review, PR merge and archival do not
authorize public release.
