# Spec Delta

## MODIFIED Requirements

### Requirement: Admin navigation follows session once

Session-driven declarative redirects and pushed-login replacement SHALL preserve protected-route denial, dashboard access and Settings Back navigation. Command success SHALL NOT add a second navigation path. Logout navigation SHALL use admitted intent and captured live UI ownership before its deferred SDK action. Owner replacement SHALL revoke old callbacks and observations.

#### Scenario: Unauthorized protected route
- **WHEN** an anonymous or authenticated non-Admin user requests the dashboard
- **THEN** the dashboard is not built and the user reaches login

#### Scenario: Declarative login succeeds
- **WHEN** an Admin session is established on declarative login
- **THEN** routing reaches dashboard once despite both event and operation completion

#### Scenario: Login pushed from Settings
- **WHEN** a pushed login establishes Admin session
- **THEN** its replacement reaches dashboard once and Back still reaches Settings

#### Scenario: External sign-out on dashboard
- **WHEN** the authoritative session loses Admin access
- **THEN** protected dashboard access redirects to login without a second command-driven navigation

#### Scenario: Logout unmounts dashboard synchronously
- **WHEN** an admitted logout navigates home and authentication changes unmount the dashboard
- **THEN** no later callback accesses that widget or navigates on its behalf

#### Scenario: Auth widget owner replacement
- **WHEN** the login widget receives a replacement auth owner
- **THEN** it listens to the new owner only and old notifications cannot trigger navigation

#### Scenario: NAV-01 Dashboard Back preserves the actual Settings entry
- **GIVEN** an authenticated Admin opens the dashboard by pushing from Settings above an existing navigation ancestor
- **WHEN** the explicit accessible dashboard Back control is activated
- **THEN** the existing dashboard route is popped and the preserved underlying Settings Navigator route and meaningful user state required by its lifecycle are revealed
- **AND** another Back reaches the original ancestor without reconstructing Settings or changing authentication

#### Scenario: NAV-02 Pushed Login is replaced above Settings
- **GIVEN** an unauthenticated user enters from an existing Settings route
- **WHEN** authentication succeeds and dashboard Back is activated
- **THEN** the preserved underlying Settings Navigator route, meaningful retained state and ancestry are revealed, a second Back reaches the original ancestor without recreating Settings, Login does not reopen, and authentication-event plus command completion causes no duplicate navigation

#### Scenario: NAV-03 Direct dashboard entry has a fallback
- **GIVEN** authorized direct dashboard entry has no poppable previous route
- **WHEN** the dashboard Back control is activated
- **THEN** Home is reached once without logout, an exception or a routing loop
- **AND** system Back retains the platform/router root-exit behavior; when a previous route exists it pops the same route as the explicit control

#### Scenario: NAV-04 Editor removal retains its own safeguards
- **GIVEN** the dashboard has opened a new or existing editor
- **WHEN** AppBar Back, system Back or another existing removal path is requested
- **THEN** the established editor dirty-field, running-operation, checkpoint, session and exact-transition protections remain authoritative

#### Scenario: NAV-05 Authentication and owner transitions remain single-owned
- **GIVEN** dashboard or pushed Login has deferred callbacks
- **WHEN** logout, external authentication change, auth-owner replacement or route replacement occurs
- **THEN** protected-route denial and existing admission remain effective and obsolete callbacks cause no extra navigation or logout


### Requirement: Dashboard entry and refresh consumers retain behavior

Route entry SHALL initialize submissions once. Manual refresh, pull-to-refresh and retries SHALL use the selected list through owner admission; accepted pull refresh SHALL await its admitted execution's safe settlement, independently of presentation revocation. An editor returning changed SHALL request submissions and then selected ignored sources through ordinary admission; busy requests may be ignored and manual refresh provides recovery. List loading, empty, error, retry and prior-data retention rendering SHALL be preserved.

Admitted toolbar and pull refreshes SHALL share one centered `EmptyView.loading` presentation displaying `Aggiornamento in corso...` within the available Dashboard content region. The Dashboard AppBar SHALL remain visible; the entire filter bar and previous list, empty or error content SHALL be temporarily hidden. Only one progress indicator SHALL be displayed. Normal filters and selected content SHALL return after safe settlement or presentation revocation, preserving retained data, selection and relevant scroll position where practical. Outside admitted manual refresh, existing rendering policies SHALL remain unchanged.

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

#### Scenario: Editor returns changed
- **WHEN** the editor returns true to the same live dashboard owner
- **THEN** submissions refresh is requested and ignored sources is requested afterward only if that filter is still selected; ordinary busy refusal is acceptable

#### Scenario: Editor owner was replaced
- **WHEN** an editor return callback belongs to a removed or replaced dashboard owner
- **THEN** it starts no refresh or navigation on the replacement owner

#### Scenario: REF-01 Toolbar refresh communicates admitted progress
- **GIVEN** the selected list can admit a manual read
- **WHEN** the toolbar refresh is activated in compact or wide layout
- **THEN** only the selected list is requested and the shared centered manual-refresh presentation appears, with the AppBar visible and filters and previous content hidden
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

#### Scenario: Declarative editor return preserves the existing refresh contract
- **WHEN** an editor opened by the Dashboard returns to that same authorized Dashboard through declarative navigation without completing its imperative push Future
- **THEN** one best-effort editor-return refresh is requested regardless of boolean result, subject to the existing owner/account/visit checks
- **AND** a covering route or return to another editor is not treated as Dashboard return, and later push completion cannot duplicate the refresh

#### Scenario: REF-12 Existing entry and editor return remain compatible
- **WHEN** initial loading, empty, initial failure/retry or editor return occurs
- **THEN** existing state rendering and best-effort refresh policies remain, including refresh after editor return regardless of its boolean result
- **AND** initial, retry, filter-triggered, editor-return and reactivation reads do not acquire the manual-refresh loading presentation


#### Scenario: Hidden refresh content is unavailable to interaction and accessibility
- **GIVEN** an admitted manual refresh owns the loading presentation
- **WHEN** the filter bar and previous content are hidden
- **THEN** they are not visible, cannot be interacted with or receive keyboard focus, and are excluded from accessibility traversal
- **AND** restoration preserves appropriate data, selection and relevant scroll state without requiring every widget to remain mounted or retain element identity


## ADDED Requirements

### Requirement: Manual refresh outcomes belong to admitted executions
Manual refresh SHALL distinguish unavailable admission from an accepted execution and its safely settled success, expected failure, handled unexpected failure, revocation or abnormal termination. Existing settlement-only consumers SHALL remain compatible. Completion alone SHALL NOT imply success. Presentation authority SHALL be separate from physical execution lifetime.

#### Scenario: A later execution cannot replace an earlier outcome
- **GIVEN** a manual read is admitted and another intent arrives at its terminal boundary
- **WHEN** the earlier receipt settles
- **THEN** its outcome describes only its captured execution, never a newer public loading or terminal snapshot

#### Scenario: Revoked accepted work settles privately
- **WHEN** an accepted read owner is revoked before action entry or during pending I/O
- **THEN** original safe-settlement acknowledgements complete exactly once when safe, no revoked presentation is authorized and no follow-up read starts on a replacement owner

#### Scenario: Assertion and nontermination remain honest
- **WHEN** accepted manual work fails loudly by assertion or never terminates
- **THEN** assertion reporting remains fail-loud with only abnormal settlement classification and no fabricated domain success/failure
- **AND** physically nonterminating work retains pending acknowledgement and resources without invented cancellation
