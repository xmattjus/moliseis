# Admin Command Execution Delta

## ADDED Requirements

### Requirement: Admin editor effects consume current completion once
Editor effects SHALL consume a current admitted execution once, without bind-time replay. Ordinary Save SHALL only update Progress and keep its Editor open. A successful moderation effect that closes the Editor requires its originating visible visit, authority and activation. Stale dialog confirmations SHALL lose authority when their captured revision or execution changes.

#### Scenario: Save during open status dialog
- **WHEN** Save settles after a Publish or Reject confirmation captured earlier editor state
- **THEN** it neither closes the Editor nor allows the earlier confirmation to dispatch
- **AND** moderation requires a fresh confirmation

#### Scenario: Obsolete or covered completion
- **WHEN** an Editor operation settles after its visit is covered or its authority, activation or presentation is replaced
- **THEN** it does not pop another presentation, report stale feedback or replay an effect on return
- **AND** existing private settlement and handled runtime reporting still apply

#### Scenario: Covered dialog loses action authority
- **WHEN** a distinct page covers a moderation dialog or newer fields or a later execution supersede its evidence
- **THEN** closing it cannot authorize moderation, including after the covering page returns or the newer execution fails

#### Scenario: Repeated terminal notifications
- **WHEN** the current presentation observes the same execution again or binds to a prior terminal
- **THEN** it does not issue a second navigation or feedback effect

### Requirement: Privileged dispatch keeps its admitted principal
Each newly entered privileged phase SHALL use only the authorized account and interval that admitted it. A change in the shared SDK session SHALL NOT transfer an already-started request to a successor. Physical settlement remains subject to the original request and server authorization.

#### Scenario: Auth changes during transport preparation
- **GIVEN** an authorized phase entered its repository call and the transport has not sent it yet
- **WHEN** the shared SDK session changes during body preparation or credential resolution
- **THEN** the request either fails safely or uses only the admitted principal's credentials
- **AND** no further phase or presentation effect is admitted for the retired visit

### Requirement: Admin presentation follows current authority once
An Admin entry SHALL render safe authentication state or one Dashboard for its current authority. Login and logout commands SHALL report their own results without navigating globally. Logout SHALL be admitted by a current authorized control, with identity rechecked at deferred dispatch. Replacement SHALL invalidate prior callbacks and observations.

#### Scenario: Unauthorized Workspace
- **WHEN** an anonymous, non-Admin or unresolved session enters the Workspace
- **THEN** only Login or safe authentication state appears

#### Scenario: Login succeeds in place
- **WHEN** established Admin authority arrives during an admitted login
- **THEN** one Dashboard appears from authority, independently of when command completion arrives

#### Scenario: External sign-out or authorized logout
- **WHEN** the auth owner observes the end of an interval
- **THEN** the private presentation retires and the existing Workspace entry shows its safe state
- **AND** neither completion nor Back can reopen its former Login or private pages

#### Scenario: Logout intent outlives its account
- **WHEN** another identity replaces the authority that requested logout before SDK dispatch
- **THEN** that request performs no sign-out on the successor

#### Scenario: Auth widget owner replacement
- **WHEN** Login receives a replacement auth owner
- **THEN** it observes only the new owner and stale callbacks produce no presentation effects

### Requirement: Admin work belongs to continuous authority
The Admin auth owner SHALL identify each continuous interval of observed authority independently of account ID. Loss, replacement or invalidation SHALL end the interval synchronously before private listeners act. A subsequent grant SHALL establish a new interval. A refresh with valid continuity SHALL preserve the interval.

#### Scenario: Authority changes without an intermediate frame
- **WHEN** the auth owner observes A becoming unauthorized and then A or B authorized, or directly observes replacement by B
- **THEN** old controls and publications lose authority as soon as A ends
- **AND** the reconciled Workspace starts a fresh Dashboard even if Login was never rendered

#### Scenario: Rapid snapshots and live session diverge
- **WHEN** a queued SDK observation ends A while the live SDK already holds a later user
- **THEN** A is invalidated and the historical observation cannot grant authority to the later user
- **AND** authorization follows evidence of the current session rather than an earlier auth operation response

#### Scenario: Continuity across ordinary events
- **WHEN** valid authority remains continuous through token refresh, metadata notifications or background/resume
- **THEN** the current authorized Workspace remains active

### Requirement: Dashboard validates authority before admission and publication
Dashboard actions, reads and recovery SHALL retain the authority of their originating visit. Initial loads, deferred dispatch, follow-up work and publication SHALL require current authority. Data, lane state, recovery actions and feedback from a retired Dashboard SHALL become unavailable to any replacement.

#### Scenario: Old control before teardown
- **WHEN** a retained refresh, un-ignore, open, recover or logout control is invoked after its authority ends but before a Flutter frame
- **THEN** it cannot admit a command, navigate, start I/O or publish feedback

#### Scenario: Delayed Dashboard completion and follow-ups
- **WHEN** a read, mutation, post-Editor refresh or recovery lookup crosses revocation
- **THEN** it causes no old-account data, feedback, pending ID, further private read or navigation in the replacement Workspace
- **AND** the original operation still follows its private settlement contract

### Requirement: Dashboard entry and local Editor return retain refresh behavior

Each new authorized Dashboard SHALL initialize submissions once. Manual refresh and retry SHALL use the selected list through its existing admission. Pull refresh SHALL await its accepted execution's private settlement. Only an ordinary return from the Dashboard's own Editor SHALL request a best-effort submissions refresh followed by ignored sources if still selected. Busy refusal leaves manual refresh available.

#### Scenario: Initial loading and empty result
- **WHEN** a new dashboard begins its first request then returns an empty list
- **THEN** loading is shown before deferred action entry and then the existing empty state is shown

#### Scenario: Initial failure and retry
- **WHEN** the first request fails and the user retries
- **THEN** the existing error/retry UI appears and one new read is admitted after settlement

#### Scenario: Refresh retains existing submissions
- **WHEN** a refresh fails with previously displayed submissions
- **THEN** those rows are retained and become visible again after any admitted manual-refresh loading presentation ends; the existing main-list error visibility policy is preserved

#### Scenario: Refresh ignored sources with retained data
- **WHEN** ignored-source refresh fails with existing sources
- **THEN** retained sources and the existing ignored-source error/retry feedback become visible again after any admitted manual-refresh loading presentation ends; outside that presentation their existing visibility policy is preserved

#### Scenario: Editor returns to its Dashboard
- **WHEN** the Editor returns normally to the same live Dashboard, regardless of result
- **THEN** submissions refresh is requested and ignored sources is requested afterward only if that filter is still selected; ordinary busy refusal is acceptable

#### Scenario: Editor owner was replaced
- **WHEN** an editor return callback belongs to a removed or replaced dashboard owner
- **THEN** it starts no refresh or navigation on the replacement owner

#### Scenario: REF-01 Toolbar refresh communicates admitted progress
- **GIVEN** the selected list can admit a manual read
- **WHEN** the toolbar refresh is activated in compact or wide layout
- **THEN** only the selected list is requested and one shared centered manual-refresh loading indicator appears, with the AppBar visible and filters and previous content hidden
- **AND** loading remains correctly centered in the available content region in compact and wide layouts, with enlarged text and after scrolling, until safe settlement or presentation revocation; no route replacement is introduced

#### Scenario: REF-02 Pull refresh waits for its own safe settlement
- **GIVEN** the selected list can admit a pull refresh
- **WHEN** the native pull interaction begins
- **THEN** it displays the same loading presentation as REF-01 without a simultaneous native pull spinner, and its callback awaits that exact admitted execution's safe settlement
- **AND** the pull gesture, nested scrolling and notification-depth behavior remain functional; presentation revocation does not prematurely complete or strand the admitted callback

#### Scenario: REF-03 Accepted success is quiet
- **WHEN** an admitted manual refresh successfully settles
- **THEN** the intended list updates, progress ends and no success Snackbar is shown

#### Scenario: REF-04 Expected failure retains usable data
- **GIVEN** a manual refresh owns current presentation authority
- **WHEN** its admitted read settles with an expected application failure
- **THEN** loading ends, the filters and retained selected content become available again, and one established custom error notification appears without resetting the local filter

#### Scenario: REF-05 Handled unexpected failure preserves reporting
- **WHEN** an admitted manual read settles through its existing handled unexpected-error channel under live presentation authority
- **THEN** the same user-facing error feedback appears once while the original command retains sole runtime reporting ownership
- **AND** presentation causes no additional capture, throw or fabricated domain result

#### Scenario: REF-06 Unavailable admission is silent
- **GIVEN** the relevant lane is busy or coordinated reactivation excludes external reads
- **WHEN** another manual refresh is requested
- **THEN** it starts no repository call, does not join or restart the accepted read, and causes no new success, error or loading feedback

#### Scenario: REF-07 Retained data and retry
- **WHEN** manual refresh fails after previously loading data and a later retry is admitted
- **THEN** retained rows and local status selection are available again after loading ends, and retry requests only the affected read

#### Scenario: REF-08 Independent read lanes remain independent
- **WHEN** manual submissions and ignored-source reads overlap after selection changes
- **THEN** each lane retains its own single-flight admission and settlement without cancelling the other
- **AND** visible loading belongs only to the current selection authority; revoking an earlier presentation does not cancel either accepted execution

#### Scenario: REF-09 Selection changes are not reverted
- **WHEN** a user changes status or selected list before a manual read settles
- **THEN** the old loading presentation is revoked and normal content for the current selection returns; accepted data can commit through existing ownership, but completion never restores the old selection

#### Scenario: REF-10 Obsolete presentation cannot emit feedback
- **GIVEN** a manual refresh captures dashboard visit, account/auth generation, owner and selection revision
- **WHEN** a route departure or cover, logout, owner replacement, selection change or disposal revokes that authority before settlement
- **THEN** stale loading is removed and no obsolete error notification is published, even if the same account or filter later returns; an old completion cannot clear a newer presentation or alter the current selection
- **AND** accepted physical work and private settlement remain intact

#### Scenario: REF-11 Reactivation retains mandatory refresh ordering
- **WHEN** source reactivation commits while manual intents are refused
- **THEN** its ignored-then-submissions reads still run under their existing reservation and publish mutation readiness only after their safe settlement
- **AND** those internal reads do not generate manual-refresh feedback

#### Scenario: Only exact local Editor return refreshes the Dashboard
- **WHEN** the Dashboard regains its active presentation after its own local Editor returns
- **THEN** it requests one best-effort refresh under current authority and visit
- **AND** Progress dismissal, unrelated coverage and retirement are not Editor returns, and a late callback cannot duplicate that refresh

#### Scenario: REF-12 Existing entry and editor return remain compatible
- **WHEN** initial loading, empty, initial failure/retry or editor return occurs
- **THEN** state rendering, retry, prior data retention and best-effort refresh after Editor return remain available
- **AND** initial, retry, filter-triggered, editor-return and reactivation reads do not acquire the manual-refresh loading presentation


#### Scenario: Hidden refresh content is unavailable to interaction and accessibility
- **GIVEN** an admitted manual refresh owns the loading presentation
- **WHEN** the filter bar and previous content are hidden
- **THEN** they are not visible, cannot be interacted with or receive keyboard focus, and are excluded from accessibility traversal
- **AND** restoration preserves appropriate data, selection and relevant scroll state without requiring every widget to remain mounted or retain element identity


#### Scenario: Dismiss pending manual-refresh presentation without cancelling execution
- **GIVEN** a toolbar or pull refresh has been admitted and remains pending, possibly indefinitely
- **WHEN** the user activates its accessible `Annulla` action, which explains that dismissing the wait leaves the admitted update running
- **THEN** its loading presentation disappears immediately and retained filters and content become visible, interactive, keyboard-focusable and accessible again with appropriate selection and scroll state
- **AND** the original read remains admitted and pending without another repository request, fabricated cancellation or completion; a pull callback still awaits that exact execution's safe settlement
- **AND** the independent lane remains available through normal authorized admission while the original lane retains its single-flight restriction, and ordinary Back/navigation behavior remains available
- **AND** eventual results follow existing ViewModel publication and safe-settlement rules, but dismissed or obsolete presentation callbacks cannot recreate loading, show stale feedback, dismiss a newer presentation or change current selection
- **AND** route authority and unrelated recovery Snackbar state are unchanged

## MODIFIED Requirements

### Requirement: Admin editor Save success identifies the persisted draft

Save SHALL capture the immutable field snapshot and exact account, session, target and replay identity at admission. A successful response SHALL confirm only that execution's captured work. It SHALL keep the Editor open and preserve later edits. Confirmed Create identity SHALL be adopted by its original session under the existing durable adoption contract, without automatic follow-up Save.

#### Scenario: Newer draft while Save is pending

- **WHEN** Save persists revision A while newer revision B exists locally
- **THEN** B remains unconfirmed and visible and the Editor stays open
- **AND** no automatic later Save can persist B

#### Scenario: Snapshot and original identity

- **WHEN** accepted Save inputs or nested description data are changed before deferred entry
- **THEN** the accepted immutable snapshot and its captured owner and replay identity determine the request
- **AND** confirmed adoption makes a later explicit Save of that same session target the adopted remote record

### Requirement: Logout availability matches shared Auth admission

Logout SHALL be visibly disabled whenever the live shared Auth admission boundary cannot accept it. The callback SHALL still perform definitive admission, preserve its captured authority through SDK dispatch and leave navigation to the Workspace. Rejected intent SHALL cause no sign-out, local navigation or success feedback. Auth events SHALL not create another local navigation callback.

#### Scenario: Logout unavailable during local login
- **WHEN** an external Admin event exposes the dashboard while a local login remains pending
- **THEN** compact and wide Logout controls remain disabled until shared admission safely reopens, with no sign-out or Home navigation from attempts to activate them

#### Scenario: Stale enabled logout callback
- **WHEN** a previously enabled Logout callback runs after another Auth operation reserves admission
- **THEN** definitive admission rejects it and no sign-out, local navigation or success feedback occurs

#### Scenario: Reentrant admitted logout navigation
- **WHEN** an admitted logout notifies synchronously and its originating route is replaced or unmounted
- **THEN** an obsolete intent issues no SDK sign-out before dispatch, and it produces no stale widget access, feedback or completion-driven navigation

### Requirement: Actual Supabase session owns Admin authorization

The actual Supabase client session SHALL remain authoritative throughout authentication operations. Admin access SHALL require established authority for a current non-anonymous user with admin metadata exactly true. Auth observations SHALL account for continuity, and unresolved or invalid startup, recovery and stream errors SHALL keep private content unavailable. Auth completions SHALL reread the current session; an SDK response serves only as login correlation evidence.

#### Scenario: Startup has only cached or unresolved authority
- **WHEN** initial session data is available but Admin authority has not yet been established, or the current session is missing, expired or unverified after an auth error
- **THEN** the Workspace shows only safe auth state and issues no private Dashboard request
- **AND** a stale startup result cannot authorize a replacement session

#### Scenario: External auth event during password request
- **WHEN** an external auth event occurs while password sign-in is pending
- **THEN** the live owner processes the observation and a later completion cannot install its captured response as authority

#### Scenario: External identity replaces rejected account
- **WHEN** a newer identity is current before rejected-account sign-out starts
- **THEN** cleanup does not sign out that newer identity

#### Scenario: Wrong password
- **WHEN** password sign-in returns an expected authentication exception
- **THEN** it is logged and exposed as an expected Result failure, without unexpected-error reporting

#### Scenario: Non-Admin account
- **WHEN** sign-in settles with a demonstrably correlated current non-Admin attempt session
- **THEN** the live owner rechecks correlation before cleanup, attempts anonymous restoration only with no current user, and returns access denied without granting Dashboard access

#### Scenario: Sign-out failure with real session remaining
- **WHEN** sign-out fails and a non-anonymous session remains current
- **THEN** the failure is logged, restoration respects the existing session, and logout exposes expected restore failure

#### Scenario: Sign-out failure after session clearance
- **WHEN** sign-out logs an expected failure after clearing the session and anonymous restoration succeeds
- **THEN** logout succeeds according to the final anonymous session

#### Scenario: Anonymous restoration fails
- **WHEN** anonymous restoration has an expected authentication failure
- **THEN** it is logged, no anonymous session is fabricated, and logout returns expected failure if final session is not anonymous

## REMOVED Requirements

### Requirement: Admin navigation follows session once
**Reason**: Global auth redirects, imperative Login replacement and logout-to-Home are retired.

**Migration**: Enter the Workspace from Settings and render the current authorized presentation in place. Actual predecessor and root Back contracts are in canonical-app-routing; local Editor safeguards are in admin-submission-editor.

### Requirement: Admin editor navigation consumes current completion once
**Reason**: The historical Save-close latch conflicts with Save keeping the Editor open.

**Migration**: Observe a matching Save through local Progress and preserve one-shot, current moderation closure and feedback.

### Requirement: Dashboard entry and refresh consumers retain behavior

**Reason**: Dashboard return no longer depends on global declarative navigation or imperative push completion.

**Migration**: Keep the existing Dashboard refresh, accessibility and settlement behavior, using the exact authorized local Editor return.
