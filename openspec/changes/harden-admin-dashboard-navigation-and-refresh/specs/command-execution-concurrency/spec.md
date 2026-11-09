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

Route entry SHALL initialize submissions once. Manual refresh, pull-to-refresh and retries SHALL use the selected list through owner admission; accepted pull refresh SHALL await terminal commit. An editor returning changed SHALL request submissions and then selected ignored sources through ordinary admission; busy requests may be ignored and manual refresh provides recovery. List loading, empty, error, retry and prior-data retention rendering SHALL be preserved.

#### Scenario: Initial loading and empty result
- **WHEN** a new dashboard begins its first request then returns an empty list
- **THEN** loading is shown before deferred action entry and then the existing empty state is shown

#### Scenario: Initial failure and retry
- **WHEN** the first request fails and the user retries
- **THEN** the existing error/retry UI appears and one new read is admitted after settlement

#### Scenario: Refresh retains existing submissions
- **WHEN** a refresh fails with previously displayed submissions
- **THEN** those rows remain and the existing main-list error visibility policy is preserved

#### Scenario: Refresh ignored sources with retained data
- **WHEN** ignored-source refresh fails with existing sources
- **THEN** retained sources and the existing ignored-source error/retry feedback remain visible

#### Scenario: Editor returns changed
- **WHEN** the editor returns true to the same live dashboard owner
- **THEN** submissions refresh is requested and ignored sources is requested afterward only if that filter is still selected; ordinary busy refusal is acceptable

#### Scenario: Editor owner was replaced
- **WHEN** an editor return callback belongs to a removed or replaced dashboard owner
- **THEN** it starts no refresh or navigation on the replacement owner

#### Scenario: REF-01 Toolbar refresh communicates admitted progress
- **GIVEN** the selected list can admit a manual read
- **WHEN** the toolbar refresh is activated in compact or wide layout
- **THEN** that list alone is requested and established application loading feedback remains observable until safe settlement
- **AND** existing content state and identity are retained rather than replaced by a new route

#### Scenario: REF-02 Pull refresh waits for its own safe settlement
- **GIVEN** the selected list can admit a pull refresh
- **WHEN** the native pull interaction begins
- **THEN** its progress awaits that admitted execution's safe settlement without a redundant toolbar loading presentation
- **AND** the nested scrolling and notification-depth behavior remains compatible

#### Scenario: REF-03 Accepted success is quiet
- **WHEN** an admitted manual refresh successfully settles
- **THEN** the intended list updates, progress ends and no success Snackbar is shown

#### Scenario: REF-04 Expected failure retains usable data
- **GIVEN** a manual refresh owns current presentation authority
- **WHEN** its admitted read settles with an expected application failure
- **THEN** one established custom error notification appears, progress ends and the previous list and local filter remain available

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
- **THEN** retained rows remain usable and retry requests only the affected read without resetting local status selection

#### Scenario: REF-08 Independent read lanes remain independent
- **WHEN** manual submissions and ignored-source reads overlap after selection changes
- **THEN** each lane retains its own single-flight admission and settlement without cancelling the other

#### Scenario: REF-09 Selection changes are not reverted
- **WHEN** a user changes status or selected list before a manual read settles
- **THEN** its data can commit through existing ownership but completion never restores the old selection

#### Scenario: REF-10 Obsolete presentation cannot emit feedback
- **GIVEN** a manual refresh captures dashboard visit, account/auth generation, owner and selection revision
- **WHEN** a route departure or cover, logout, owner replacement, selection change or disposal revokes that authority before settlement
- **THEN** no stale progress overlay or error notification is published, even if the same account or filter later returns
- **AND** accepted physical work and private settlement remain intact

#### Scenario: REF-11 Reactivation retains mandatory refresh ordering
- **WHEN** source reactivation commits while manual intents are refused
- **THEN** its ignored-then-submissions reads still run under their existing reservation and publish mutation readiness only after their safe settlement
- **AND** those internal reads do not generate manual-refresh feedback

#### Scenario: REF-12 Existing entry and editor return remain compatible
- **WHEN** initial loading, empty, initial failure/retry or editor return occurs
- **THEN** existing state rendering and best-effort refresh policies remain, including refresh after editor return regardless of its boolean result


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
