# Command execution concurrency delta

## ADDED Requirements

### Requirement: Admin session intents share synchronous admission

Admin login and logout SHALL share one owner-local admission boundary. While either is admitted, duplicate and conflicting local intents SHALL be rejected before deferred action entry, without queuing, changing snapshots or replacing credentials. Admission SHALL remain reserved through safe execution settlement. Authentication events SHALL not reopen admission.

#### Scenario: Duplicate password intent before action entry
- **WHEN** a second login is requested before the first deferred action starts
- **THEN** only the first credentials are used and exactly one sign-in is issued

#### Scenario: Login during logout
- **WHEN** login is requested while sign-out or anonymous restoration is pending
- **THEN** login is rejected without retaining its credentials or queuing another sign-in

#### Scenario: Logout during login
- **WHEN** logout is requested while password sign-in or rejected-account cleanup is pending
- **THEN** logout is rejected and no independent sign-out is queued

#### Scenario: Duplicate logout
- **WHEN** logout is requested twice before settlement
- **THEN** one sign-out/restoration sequence runs and the original execution state is preserved

#### Scenario: Reentrant settlement
- **WHEN** a consumer requests another operation during terminal or running-state notification
- **THEN** admission cannot reopen inside an old execution stack that could clear the next execution's busy state

### Requirement: Admin credentials do not become command state

Password credentials SHALL NOT be retained in observable command parameters, snapshots, results, diagnostic wrappers, names or notifications. Only an admitted login SHALL retain transient credentials required for its SDK call; unconsumed credentials SHALL be released on revocation. Existing privacy-aware logging SHALL not add credential data, and UI failure feedback SHALL remain generic.

#### Scenario: Running and terminal password login
- **WHEN** a password login runs and succeeds or fails
- **THEN** its command parameters are empty and observable state, command diagnostics and new log context contain no password

#### Scenario: Rejected credentials
- **WHEN** another credential submission is rejected by admission
- **THEN** it neither replaces the admitted input nor becomes observable or retained command state

#### Scenario: Revoked before action
- **WHEN** the auth owner is disposed before deferred login entry
- **THEN** its pending credential reference is cleared and no sign-in starts

### Requirement: Actual Supabase session owns Admin authorization

The actual Supabase client session SHALL remain authoritative throughout authentication operations. Admin access SHALL require a non-anonymous user with admin metadata exactly true. Live auth events SHALL update routing; completions SHALL reread current session rather than install responses. A response SHALL serve only as login-attempt correlation evidence and SHALL NOT authorize cleanup or success when uncorrelated.

#### Scenario: External auth event during password request
- **WHEN** an external auth event occurs while password sign-in is pending
- **THEN** the live owner observes the actual client session immediately and a later completion cannot install its captured response as authority

#### Scenario: External identity replaces rejected account
- **WHEN** a newer identity is current before rejected-account sign-out starts
- **THEN** cleanup does not sign out that newer identity

#### Scenario: Wrong password
- **WHEN** password sign-in returns an expected authentication exception
- **THEN** it is logged and exposed as an expected Result failure, without unexpected-error reporting

#### Scenario: Non-Admin account
- **WHEN** sign-in settles with a demonstrably correlated current non-Admin attempt session
- **THEN** the live owner rechecks correlation before cleanup, attempts anonymous restoration only with no current user, and returns access denied without granting dashboard access

#### Scenario: Sign-out failure with real session remaining
- **WHEN** sign-out fails and a non-anonymous session remains current
- **THEN** the failure is logged, restoration respects the existing session, and logout exposes expected restore failure

#### Scenario: Sign-out failure after session clearance
- **WHEN** sign-out logs an expected failure after clearing the session and anonymous restoration succeeds
- **THEN** logout succeeds according to the final anonymous session

#### Scenario: Anonymous restoration fails
- **WHEN** anonymous restoration has an expected authentication failure
- **THEN** it is logged, no anonymous session is fabricated, and logout returns expected failure if final session is not anonymous

### Requirement: Rejected login cleanup requires attempt correlation

A login SHALL succeed only with a correlated current attempt session and current Admin authorization. Its SDK response SHALL supply correlation evidence, never authorization. Rejected-account cleanup SHALL require a live owner and the same correlated current non-Admin session immediately before invocation. Missing or replaced-session evidence SHALL yield expected login failure without cleanup or session replacement.

#### Scenario: Correlated Admin login
- **WHEN** response identity and session demonstrably match the current attempt session and the current user is Admin
- **THEN** login succeeds using current-session authorization without installing the response as state

#### Scenario: Correlated rejected login
- **WHEN** response A and the actual current session demonstrate the same non-Admin login attempt
- **THEN** cleanup may start once after a final live correlation check and the login remains access denied

#### Scenario: Different current Admin identity
- **WHEN** login returns A but actual current session belongs to B Admin
- **THEN** A's login reports expected session-changed failure, sign-out and anonymous restoration are not started, and B's actual Admin session alone may authorize dashboard routing

#### Scenario: Different current nonadmin identity
- **WHEN** login returns A but actual current session belongs to distinct B non-Admin
- **THEN** A's login reports expected failure with zero cleanup calls on B and no Admin authorization

#### Scenario: Missing login correlation evidence
- **WHEN** response user/session evidence is absent, inconsistent, or no longer identifies the current attempt session, even with the same user ID
- **THEN** login reports expected unverifiable-session failure without cleanup, anonymous restoration or false success, while actual client session remains authoritative

#### Scenario: Reentrant identity change before cleanup
- **WHEN** notification or logging replaces correlated A with B before sign-out invocation
- **THEN** a final correlation check after all callbacks rejects cleanup of B, with no yield or application callback between that guard and an eligible invocation

#### Scenario: External identity after cleanup entry
- **WHEN** guarded cleanup has already entered sign-out and an external event establishes B
- **THEN** the owner does not claim cancellation or atomic session protection, preserves actual B on settlement, and starts no anonymous restoration while B exists

#### Scenario: Revoked before rejected-account cleanup
- **WHEN** the owner is revoked after password completion but before cleanup invocation
- **THEN** no sign-out, restore, state publication or follow-up phase starts from the revoked owner

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

### Requirement: Logout availability matches shared Auth admission

Logout SHALL be visibly disabled whenever the live shared Auth admission boundary cannot accept it. The callback SHALL still perform definitive admission, navigate locally to Home at most once only on acceptance and valid originating UI ownership, and use no widget/context after navigation. Rejected intent SHALL cause no sign-out, local navigation or success feedback. Auth events SHALL not create another local navigation callback.

#### Scenario: Logout unavailable during local login
- **WHEN** an external Admin event exposes the dashboard while a local login remains pending
- **THEN** compact and wide Logout controls remain disabled until shared admission safely reopens, with no sign-out or Home navigation from attempts to activate them

#### Scenario: Stale enabled logout callback
- **WHEN** a previously enabled Logout callback runs after another Auth operation reserves admission
- **THEN** definitive admission rejects it and no sign-out, local navigation or success feedback occurs

#### Scenario: Reentrant admitted logout navigation
- **WHEN** an admitted logout notifies synchronously and its originating route is replaced or unmounted
- **THEN** the callback rechecks ownership before navigating, issues no redundant Home navigation and performs no later widget access or completion-driven navigation

### Requirement: Dashboard reads and reactivation share coordinated admission

The two dashboard read lanes SHALL be independently single-flight and able to overlap. Source reactivation SHALL be admitted only with both lanes settled, and SHALL synchronously exclude external reads and duplicate reactivation through mutation and post-commit refresh. Rejected requests SHALL start no repository calls or change execution feedback. Filters SHALL remain local.

#### Scenario: Independent reads
- **WHEN** submissions and ignored-source reads are requested in normal phase
- **THEN** both may run concurrently but a duplicate in either lane is rejected

#### Scenario: Read precedes mutation
- **WHEN** reactivation is requested while either read is reserved, including before its deferred action
- **THEN** reactivation is rejected until that read has committed and safely settled

#### Scenario: Mutation precedes read
- **WHEN** either read is requested after reactivation admission, including before mutation action entry
- **THEN** it is rejected without a repository call or a new read failure snapshot

#### Scenario: Duplicate source reactivation
- **WHEN** another reactivation is requested during mutation or post-commit refresh
- **THEN** only the admitted mutation runs and its captured source identity is preserved

#### Scenario: Filter changes during operations
- **WHEN** a local status or ignored filter changes during reads, mutation or refresh
- **THEN** filtering remains local, remote responses do not restore an old filter, and phase-restricted ignored reads cannot remove the mandatory post-commit refresh

### Requirement: Reactivation success and refresh outcomes stay distinct

Successful reactivation SHALL retain resolution and pending ID privately and refresh ignored sources then submissions once while live. No pre-commit read SHALL overwrite post-commit state. Read failure SHALL retain the prior list without failing or repeating mutation. Public mutation success and pending navigation SHALL become available together only after both refresh attempts normally settle, including handled failures. Revocation SHALL prevent readiness publication.

#### Scenario: Rejected refresh before mutation commit
- **WHEN** refresh requests were rejected while reactivation was pending and the mutation then commits
- **THEN** both required post-commit reads are still admitted once and cannot be rejected by their own orchestration

#### Scenario: Successful post-commit refresh
- **WHEN** reactivation and both follow-up reads succeed
- **THEN** both lists reflect the new data, mutation success is shown and the returned pending revision can be opened

#### Scenario: Ignored-source refresh fails
- **WHEN** mutation succeeds but the ignored-source refresh returns expected or handled unexpected failure
- **THEN** ignored data is retained, submissions refresh still runs and mutation resolution and pending ID remain successful

#### Scenario: Submissions refresh fails
- **WHEN** ignored refresh succeeds but submissions refresh fails
- **THEN** the ignored commit is retained, prior submissions remain, read failure is observable and mutation success remains intact

#### Scenario: Both refreshes fail
- **WHEN** both post-commit reads fail
- **THEN** each list retains its previous data, mutation success and the retained pending link become available together after both attempts settle, and retry performs reads rather than another mutation

#### Scenario: Mutation fails
- **WHEN** the source mutation returns expected failure
- **THEN** both lists are retained, old pending navigation from the previous attempt is cleared, mutation failure is shown and no follow-up read starts

#### Scenario: Read runtime failure after commit
- **WHEN** a post-commit read throws a handled unexpected error
- **THEN** its original error and stack are globally reported once by that read, without a second report through the mutation

#### Scenario: Pending navigation during mutation
- **WHEN** source reactivation is still pending
- **THEN** public pending navigation is unavailable and an old pending link from a previous attempt cannot be used

#### Scenario: Pending navigation waits for ignored refresh
- **WHEN** mutation succeeded with a pending ID but the ignored-source refresh is pending
- **THEN** the ID is retained privately, logical reactivation remains running and no enabled pending link is exposed

#### Scenario: Pending navigation waits for submissions refresh
- **WHEN** ignored refresh has settled but submissions refresh is still pending
- **THEN** pending navigation remains unavailable regardless of the first read's outcome

#### Scenario: Pending navigation after failed refreshes
- **WHEN** both refresh attempts settle with one or both returning expected or handled runtime failure
- **THEN** successful mutation feedback and navigation to the retained pending ID become available together, without repeating mutation or requiring successful reads

#### Scenario: Revocation before navigation readiness
- **WHEN** the dashboard owner is revoked during either post-commit refresh
- **THEN** its private committed pending ID never becomes publicly navigable and no old callback can open it on a replacement owner

#### Scenario: Stale pending-link callback
- **WHEN** a previously rendered pending-link callback runs after a new mutation starts or its owner is replaced
- **THEN** it rechecks current owner, ID and navigation readiness and does not open the obsolete pending revision

### Requirement: Dashboard entry and refresh consumers retain behavior

Route entry SHALL initialize submissions once. Manual refresh, pull-to-refresh and retries SHALL use the selected list through owner admission; accepted pull refresh SHALL await terminal commit. An editor returning changed SHALL refresh submissions and then ignored sources only if still selected and owned. List loading, empty, error, retry and prior-data retention rendering SHALL be preserved.

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
- **THEN** submissions refresh and ignored sources refresh afterward only if that filter is still selected

#### Scenario: Editor owner was replaced
- **WHEN** an editor return callback belongs to a removed or replaced dashboard owner
- **THEN** it starts no refresh or navigation on the replacement owner

### Requirement: Accepted dashboard refresh Futures settle privately

Each accepted dashboard refresh SHALL own an execution-correlated Future that completes normally once at safe command settlement, even after owner revocation. Revocation SHALL stop UI forwarding and new phases, not private settlement observation. Domain and handled runtime failures SHALL not be thrown or reported again through that Future. Physically nonterminating work SHALL remain pending; assertions SHALL remain fail-loud without fabricated business success.

#### Scenario: Accepted refresh settles after revocation
- **WHEN** an accepted refresh is repository-pending, its owner is revoked, then the work succeeds
- **THEN** the original Future stays pending until safe command settlement and completes normally exactly once without later state, snapshot or notification publication

#### Scenario: Revoked before refresh action entry
- **WHEN** an accepted refresh owner is revoked before deferred action entry or reentrantly during its running notification
- **THEN** no repository call starts and the original Future completes normally once through private skipped/no-I/O settlement

#### Scenario: Domain failure settles revoked refresh
- **WHEN** an accepted refresh returns an expected failure after owner revocation
- **THEN** the original Future completes normally once without public failure publication or an additional throw

#### Scenario: Runtime failure settles revoked refresh
- **WHEN** retained accepted work throws a handled runtime failure after revocation and beyond upstream deferred teardown time
- **THEN** its original error and stack are reported once by that command and the original Future completes normally without a second error/report or disposed-notifier failure

#### Scenario: Reentrant refresh settlement
- **WHEN** dispose occurs in terminal notification or competing private terminal and fallback callbacks both attempt settlement
- **THEN** the accepted Future resolves once, private resources release once after safe settlement and no revoked follow-up phase starts

#### Scenario: Assertion settles private receipt
- **WHEN** an assertion bypasses normal terminal routing in accepted refresh work
- **THEN** original fail-loud handling remains intact while the private Future settles normally once as an abnormal execution, without fabricated domain success/failure, duplicate reporting or a second internal refresh

#### Scenario: Nonterminating refresh
- **WHEN** an accepted refresh's underlying work never terminates
- **THEN** its Future and required private resources stay pending, without invented cancellation or premature disposal

#### Scenario: Internal refresh revoked
- **WHEN** owner revocation occurs while an admitted post-commit refresh is pending
- **THEN** that refresh's receipt still settles privately when work ends, but cannot authorize another read, pending-link publication or feedback on a replacement owner

### Requirement: Admin owner revocation prevents new phases

Revoking an Admin owner SHALL stop public forwarding, state commits, callbacks and new remote phases immediately. Already-started SDK or repository I/O may settle privately. Pending ordinary execution owners SHALL remain retained until settlement for safe original-error reporting and exactly-once cleanup. Assertion failures SHALL remain fail-loud and SHALL NOT become domain results.

#### Scenario: Dispose auth during SDK work
- **WHEN** the auth owner is disposed while password sign-in or sign-out is pending
- **THEN** no later local cleanup, restore, cached-session publication or notification starts from that owner, while actual client events remain authoritative for a new owner

#### Scenario: Dispose dashboard during mutation
- **WHEN** the dashboard is disposed before its in-flight remote mutation settles
- **THEN** remote commit is not fabricated as cancelled but no list refresh, pending publication or UI notification follows

#### Scenario: Dispose after mutation commit
- **WHEN** the dashboard is disposed while its first post-commit read is pending
- **THEN** its response cannot commit publicly and the second read is not started

#### Scenario: Late raw failure after disposal threshold
- **WHEN** already-started work throws a handled runtime error after owner disposal and upstream deferred teardown time
- **THEN** the retained command reports the original error and stack once without a secondary disposed-notifier error or replacement-owner feedback

#### Scenario: Synchronous listener disposes owner
- **WHEN** a running, terminal or business-state listener revokes the owner during notification
- **THEN** no next remote phase or public notification starts and private resources release exactly once after settlement

#### Scenario: Assertion failure
- **WHEN** an execution fails an assertion with upstream assertions enabled
- **THEN** the original assertion remains fail-loud, is not normal domain feedback, and settled private cleanup still occurs


### Requirement: Editor changes retain an owner-local refresh obligation

A live dashboard SHALL register editor changes synchronously through refreshAfterEditorChange. Each revision SHALL require a submissions read admitted afterward, surviving busy lanes and reactivation. Pending revisions MAY coalesce before admission; newer revisions SHALL require a later read. Selected ignored sources SHALL refresh after submissions settlement. Coordination SHALL complete normally on processing or revocation, separately from physical receipt settlement.

#### Scenario: Older submissions read cannot satisfy editor change
- **WHEN** editor change is registered while a submissions read admitted before it remains pending
- **THEN** that receipt settles safely and a distinct new submissions read is admitted; the editor obligation cannot complete from the older response

#### Scenario: Editor demand survives exclusive reactivation
- **WHEN** editor change is registered during mutation or either required post-commit refresh
- **THEN** no external read bypasses exclusivity, both internal refreshes and atomic pending navigation retain their contract, and a fresh editor submissions read follows safe exclusive release without repeating mutation

#### Scenario: Pending editor changes coalesce before admission
- **WHEN** multiple changes are registered before a post-editor submissions read is admitted
- **THEN** one read admitted afterward covers their captured revisions and completes their obligations after safe processing

#### Scenario: Newer editor change requires another batch
- **WHEN** another change is registered during an editor batch's submissions or ignored read
- **THEN** that batch completes only its captured revisions and the newer obligation requires another submissions read admitted after the new change, without stranding older processed callers

#### Scenario: Ignored editor refresh waits for its lane
- **WHEN** ignored sources are selected after post-editor submissions settlement but their lane is already reserved
- **THEN** the obligation survives and admits a fresh ignored read after safe lane and exclusive-phase release rather than counting the older read or dropping demand

#### Scenario: Editor refresh uses current filter
- **WHEN** selection changes while post-editor submissions are pending
- **THEN** submissions remain mandatory and current selection at their safe settlement determines the ignored phase, without restoring an older filter

#### Scenario: Prior failed read releases editor demand
- **WHEN** a preceding read ends with domain or handled runtime failure while an editor revision is waiting
- **THEN** safe settlement wakes the fresh editor read and the original failure is not thrown or reported again by coordination

#### Scenario: Editor read failure processes without retry
- **WHEN** a post-editor read ends with expected or handled runtime failure
- **THEN** its obligation processes at safe settlement, selected ignored refresh still follows a normal submissions terminal, and no mutation retry, duplicate reporting or second Future error is introduced

#### Scenario: Editor assertion abort is not normal continuation
- **WHEN** a post-editor submissions assertion bypasses normal terminal routing
- **THEN** original fail-loud handling remains intact and private coordination settles its batch without fabricated success or ordinary ignored continuation

#### Scenario: Editor coordination revokes independently of physical work
- **WHEN** the owner is disposed while editor demand is queued or its read remains physically pending
- **THEN** its coordination Futures complete normally once without new work or publication, while admitted physical receipts remain retained until their own safe settlement and a replacement owner stays independent

#### Scenario: Editor callback owns registration only
- **WHEN** the editor returns true to the same mounted and authoritative Dashboard owner
- **THEN** the widget invokes refreshAfterEditorChange once and the live owner retains that registered demand even if the widget later unmounts; false, null and obsolete callbacks register nothing

#### Scenario: Reentrant editor registration preserves wakeups
- **WHEN** another editor revision is registered during admission notification, terminal dispatch or safe settlement
- **THEN** it is retained for a sufficiently recent admitted read and no duplicate drain, unsafe lane reopening or lost wakeup occurs

#### Scenario: Nonterminating editor work and revocation
- **WHEN** required physical work never terminates
- **THEN** live coordination may remain pending, but owner revocation still completes its local obligation waiters without inventing physical cancellation
