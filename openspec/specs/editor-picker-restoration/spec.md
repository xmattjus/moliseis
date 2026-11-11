# editor-picker-restoration Specification

## Purpose

Restore the account-owned Admin editor independently of interrupted media while preserving captured live-request authority and leaving Public Content Submission unchanged.

## Requirements

### Requirement: Public remains an unchanged dependency
Plan 2 SHALL preserve Public production code, initialization, picker/recovery, successful eligible lost-media staging, persistence, navigation and submission behavior. Existing regression tests and expectations SHALL remain unchanged. Public canonical specs SHALL remain authoritative. Admin integration SHALL not intercept Public retrieval, add a shared recovery gateway or introduce universal discard.

#### Scenario: Existing Public recovery remains supported
- **WHEN** the existing Public recovery suites run after Admin integration
- **THEN** recovers a single lost file and acquires lost media early and stages it after draft restoration pass with unchanged assertions
- **AND** Public draft/staging/submit/progress/lifecycle regressions remain supported without changing their expectations

### Requirement: Admin retains the pinned picker integration
Admin SHALL continue using the pinned image_picker gallery selection mechanism. New-target images SHALL enter exact-owner private staging; eligible persisted pending submissions SHALL retain immediate add behavior. No second picker dependency, native fork/channel or global media framework SHALL be introduced.

#### Scenario: Valid normal Admin selection
- **GIVEN** the exact account/session/activation is authorized and durably checkpointed before launch
- **WHEN** its gallery picker returns an eligible image under the original live request
- **THEN** new-target intake stages privately or persisted pending intake follows the existing immediate path
- **AND** subsequent phases recheck captured authority

### Requirement: Normal Admin resume preserves original request authority
An ordinary resumed or background lifecycle transition SHALL NOT invalidate a pending Admin picker request. While captured account/session/activation and request nonce remain valid, any image, cancellation or error completion SHALL be processed normally even if resume happened first. Same-activation rebuilds SHALL not abandon it.

#### Scenario: Resume precedes valid image completion
- **WHEN** a valid Admin request resumes before its original Future returns an image
- **THEN** the eligible image is accepted through ordinary owner-checked intake

#### Scenario: Resume precedes cancellation completion
- **WHEN** a valid Admin request resumes before its Future returns cancellation
- **THEN** cancellation settles without an asset and a later selection can be admitted

#### Scenario: Resume precedes error completion
- **WHEN** a valid Admin request resumes before its Future returns an error
- **THEN** the existing error path settles the action without a permanent application picker reservation

### Requirement: Admin abandonment requires revocation or explicit intent
Local Admin abandonment SHALL require actual account/session/activation revocation or an explicit request-bound user action. It SHALL revoke publication before settling its local await and releasing only its own admission. Resume, elapsed time or presumed Activity loss SHALL not suffice. Local abandonment SHALL not claim native cancellation or automatically relaunch a picker.

#### Scenario: Activity recreation strands the original Future
- **GIVEN** the Dart owner survives but its native picker Future never completes
- **WHEN** the authorized user activates Admin Interrompi selezione for that nonce
- **THEN** the local await and add action settle as interrupted without awaiting native completion
- **AND** editor/checkpoint/navigation access remains usable and the existing Add control permits separate explicit selection after settlement

#### Scenario: Reconstruction genuinely replaces authority
- **WHEN** route/editor reconstruction establishes A2 after revoking A1
- **THEN** A1 loses authority and cannot publish into A2
- **AND** an ordinary rebuild retaining the same activation does not trigger abandonment

#### Scenario: Abandoned A completes after B starts
- **WHEN** A's original Future returns media or error after A was abandoned and B admitted
- **THEN** A cannot stage/upload, publish into B, release B's reservation or clear B's navigation nonce

#### Scenario: A1 cannot revive after A to B to A
- **WHEN** A1 is revoked, B activates, A2 activates and A1 completes late
- **THEN** captured activation/nonce guards reject A1 despite equal account/session/target

### Requirement: Pending Admin selection has a bounded explicit escape
The current authorized Admin editor SHALL expose Interrompi selezione while its picker await is pending. It SHALL remain callable while add runs, preserve fields/files/resume intent and settle only the captured request. This control SHALL NOT be added to Public or require a second command architecture, timer, recovery coordinator or native acknowledgement.

#### Scenario: Repeated interruption and next selection
- **WHEN** Admin selections are interrupted and explicitly abandoned repeatedly
- **THEN** each application admission can settle without its native Future and a later valid explicit request can complete normally
- **AND** no permanent editor loading state or application-owned picker lockout remains

#### Scenario: Native state still reports already active
- **WHEN** native selection rejects a later explicit request as already_active
- **THEN** the action settles with editor access and later explicit retry available
- **AND** the application neither spins nor claims native cancellation

### Requirement: Admin navigation intent is independent of media provenance
Before Admin external picking, the editor SHALL checkpoint and persist its account/session/target and request nonce for navigation only. Matching cleanup SHALL compare-and-clear only that nonce. Revocation or local abandon SHALL retain resume intent through interruption. Intent SHALL not identify native media, consume cache, gate Public or authorize discarding any Public result.

#### Scenario: Intent commits before death and before launch
- **WHEN** the process dies after Admin intent persistence but before native launch
- **THEN** the same-account editor is recoverable without inferring that a picker started or media exists

#### Scenario: Old cleanup follows a same-session next launch
- **WHEN** B replaces A's navigation nonce and A's cleanup completes late
- **THEN** B's intent remains and A cannot clean up or release B's request

### Requirement: Admin restoration requires original account and session
Admin restoration SHALL resolve the exact durable local session, adopted remote target and committed staged files independently of media availability. Login SHALL preserve the original-account resume intent; another account SHALL not view or consume that work. Missing or interrupted media SHALL not block activation, loading, checkpointing or later explicit selection.

#### Scenario: Login then original account resumes
- **WHEN** restoration reaches login and the original account reauthorizes
- **THEN** its Publication Editor resumes without waiting for media retrieval

#### Scenario: Different account authenticates
- **WHEN** B authenticates while A's Admin resume intent exists
- **THEN** B reaches only its own area and A's private work remains recoverable without a redirect loop

#### Scenario: Adopted new-editor identity restores
- **WHEN** an old new-editor hint references a session already bound to a remote ID
- **THEN** account/session lookup restores that adopted editor without creating another new draft

#### Scenario: Activity recreation and process death
- **WHEN** either interruption reconstructs an Admin editor
- **THEN** its durable checkpoint and valid committed files restore under correct account authority
- **AND** process death does not reconstruct the original native Future or run Save automatically

### Requirement: Admin restoration performs no unattributed media recovery
Admin SHALL NOT call retrieveLostData, drain shared cache or upload/associate unattributed lost media. Restoration SHALL not start Save, upload or remote mutation. Public's existing retrieval SHALL remain untouched; this Admin contract SHALL not claim native cross-feature provenance or complete cache isolation.

#### Scenario: Interrupted Admin media is unavailable
- **WHEN** Admin restores after picker interruption without a valid live result
- **THEN** the editor and committed staged files remain usable without recovering that individual image or starting remote persistence

### Requirement: Native acceptance is scoped to new Admin behavior
Android verification SHALL distinguish Activity recreation from actual process death and exercise normal/late/cancel/error callbacks and subsequent explicit selection. Fake-picker tests SHALL not prove native ordering. New demonstrated regressions SHALL be addressed specifically; acceptance SHALL NOT require eliminating the accepted pre-existing shared-cache attribution limitation or rewriting Public behavior.

#### Scenario: Device verification scope
- **WHEN** Android acceptance runs for newly introduced Admin lifecycle/restoration paths
- **THEN** it verifies captured continuation safety, same-account restoration and no permanent application admission lock
- **AND** it does not assert that the plugin's shared cache can never expose Admin-origin lost media to existing Public recovery

### Requirement: Dashboard recovery requires authoritative navigation eligibility
The dashboard SHALL offer recovery only after a successful current-Admin-account lookup validates a navigation intent under existing account/session/target rules. Repository availability or an ordinary draft SHALL NOT imply eligibility. Successful absence SHALL hide recovery; failure SHALL remain unknown and preserve durable data. Automatic failure SHALL be silent; explicit recovery failure SHALL show the established generic custom error once under live authority.

#### Scenario: DRAFT-01 No navigation intent
- **GIVEN** no current-account navigation intent exists, even if a repository and ordinary checkpoint exist
- **WHEN** the dashboard resolves recovery eligibility
- **THEN** no recovery Snackbar or permanent AppBar resume action is shown

#### Scenario: DRAFT-02 Valid candidate has one active presentation
- **GIVEN** the current Admin account owns a valid interrupted navigation intent
- **WHEN** its live dashboard visit resolves that candidate
- **THEN** one persistent custom Snackbar explains the interrupted editor and exposes the recovery action and an accessible close affordance

#### Scenario: DRAFT-06 Another account cannot recover the candidate
- **GIVEN** account A retains an interrupted session
- **WHEN** account B enters or activates an obsolete A recovery callback
- **THEN** A's candidate is neither displayed nor executed for B and A's durable work remains unchanged

#### Scenario: DRAFT-07 Original account reauthorizes
- **GIVEN** A's durable intent survived logout and a visit by B
- **WHEN** A signs in again and its dashboard lookup succeeds
- **THEN** A can explicitly restore its exact session and checkpoint, including incomplete input and committed staged assets, without automatic Save or upload

#### Scenario: DRAFT-10 Lookup failure is unknown
- **GIVEN** an automatic eligibility lookup fails on entry or another established trigger
- **WHEN** that lookup settles under live dashboard authority
- **THEN** eligibility remains unknown, no unsolicited error Snackbar, recovery navigation or authoritative-absence claim occurs, and durable state is preserved
- **AND** existing diagnostics remain without duplicate reporting; the next dashboard visit, editor/covering-route return, authorized owner/account rebinding or explicitly admitted manual refresh can recheck without polling or rebuild-driven retries

#### Scenario: DRAFT-10 Explicit recovery lookup fails
- **GIVEN** the user activates `Riprendi` for an eligible candidate
- **WHEN** authoritative revalidation returns `Result.error` under live dashboard authority
- **THEN** the established generic custom error is shown exactly once for that action, no editor navigation occurs and durable session/recovery data remains unchanged
- **AND** the in-flight latch is released without an automatic retry; a later established trigger may recheck eligibility

#### Scenario: DRAFT-10 Legitimate retry restores eligibility
- **GIVEN** an automatic or explicit lookup failed without proving absence
- **WHEN** a later established trigger successfully validates the undismissed candidate
- **THEN** recovery can be offered again under current authority without deleting or invalidating its durable data

#### Scenario: DRAFT-10 Revoked lookup cannot emit effects
- **GIVEN** an automatic lookup or explicit recovery revalidation is pending
- **WHEN** route, account/auth generation, owner replacement or disposal revokes its authority before completion
- **THEN** its late success or failure cannot show any notification or navigate, even if identifiers later match again

### Requirement: Recovery notification has an owned persistent lifetime
Recovery SHALL use existing styling and persist except during ordinary feedback, dismissal, activation or invalidation. Dismissal suppression SHALL be visit-local and candidate-specific; interruption SHALL NOT dismiss. In-flight recovery SHALL block duplicate presentation. Changed requests SHALL be independently eligible. Departure, authority replacement or disposal SHALL revoke recovery without deleting work or clearing other feedback.

#### Scenario: DRAFT-03 Ordinary timeout does not expire recovery
- **GIVEN** a recovery Snackbar is visible
- **WHEN** more than the longest ordinary notification timeout elapses
- **THEN** its message, action and close affordance remain usable

#### Scenario: DRAFT-04 Manual dismissal preserves the draft
- **WHEN** the user closes or swipes away the recovery Snackbar
- **THEN** it disappears and equivalent lookups during that visit do not present it again
- **AND** the checkpoint, navigation nonce, session, write intent and staged files remain unchanged

#### Scenario: DRAFT-05 Explicit recovery revalidates exact identity
- **GIVEN** a candidate is displayed
- **WHEN** the user activates recovery
- **THEN** the notification is retired immediately and a current account-qualified lookup must still match its session, target and navigation request before one editor navigation is allowed
- **AND** duplicate presentation is blocked while revalidation runs; the existing editor receives its exact session hint and normal initialization and exit protections remain authoritative
- **AND** action-in-progress and navigation admission block duplicates but do not prove editor activation succeeded or suppress the candidate for the remainder of the visit
- **AND** success suppression requires verified initialized editor activation for the exact recovery attempt, account/session/target and validated nonce; neither admission nor push completion suffices and no durable nonce is consumed

#### Scenario: DRAFT-05 Editor return is independent of imperative completion
- **GIVEN** an admitted recovery editor has genuinely covered its owning Dashboard
- **WHEN** pop or declarative navigation makes that same Dashboard current again
- **THEN** the exact visit reconciles and releases once under fresh current-route, account and owner authority even if its imperative push Future remains pending
- **AND** return reconciliation performs one best-effort list refresh and one authoritative recovery recheck, preserving initialized-activation and nonce-qualified success suppression
- **AND** early router notifications, admission rejection, an unrelated cover or declarative navigation to another editor do not establish completed Dashboard return
- **AND** a late push completion or revoked return lookup cannot finalize twice, release a newer attempt or publish obsolete feedback

#### Scenario: DRAFT-05 Rejected navigation releases the exact attempt
- **GIVEN** a valid interrupted session B and a retained editor A whose accepted remote fields still require a local checkpoint
- **WHEN** the user activates `Riprendi` for B and the existing route policy refuses the transition
- **THEN** the exact recovery reservation and matching editor-attempt state are released independently of the imperative push Future, while A's checkpoint obligation and both sessions' durable data, staged assets, write intents and navigation nonce remain protected
- **AND** denial records neither successful activation nor explicit dismissal, performs no automatic Save, upload, deletion or repeated navigation, and permits a later established trigger to revalidate the same candidate
- **AND** after A is explicitly checkpointed, B can be recovered from the same retained dashboard route
- **AND** the admission acknowledgement belongs only to its exact destination and attempt, resolves once for admission or rejection, and a stale result cannot release a newer attempt or publish obsolete effects after route, account or owner revocation

#### Scenario: DRAFT-05 Failed activation permits recovery after return
- **GIVEN** recovery revalidation succeeds and its editor route is admitted
- **WHEN** draft activation fails and the user returns from the existing error/retry presentation
- **THEN** the attempt is released without success suppression and the same undismissed candidate can be offered after fresh authoritative validation
- **AND** the durable draft, checkpoint, staged data and navigation intent remain intact without automatic Save, upload or cleanup

#### Scenario: DRAFT-05 Existing editor retry establishes success
- **GIVEN** an admitted recovery editor failed activation and offers its existing retry action
- **WHEN** the user retries successfully and later returns to the same authorized dashboard
- **THEN** verified initialized activation of the exact attempt prevents redundant recovery presentation even if its durable intent remains
- **AND** direct successful activation has the same behavior without another navigation or notification while the editor is active

#### Scenario: DRAFT-05 Activation authority is replaced
- **GIVEN** a recovery editor activation is pending
- **WHEN** logout, dashboard route replacement/departure, captured candidate account/session/target change, owner replacement or disposal revokes its attempt
- **THEN** stale activation and return callbacks cannot suppress a new candidate or restore notifications or navigate on the old attempt's behalf

#### Scenario: DRAFT-08 Equivalent candidates do not repeat
- **GIVEN** a candidate was explicitly dismissed or its recovery attempt verified successful editor activation during this visit
- **WHEN** rebuilds, equivalent successful lookups or repository notifications occur
- **THEN** no duplicate notification appears
- **AND** a later genuinely different navigation request can be offered independently, even for the same session

#### Scenario: DRAFT-09 Stale work cannot regain presentation authority
- **GIVEN** a recovery lookup, pending presentation or callback captures a dashboard visit and authority generation
- **WHEN** the route leaves or is covered, auth or draft/dashboard owner changes, logout occurs or the widget is disposed
- **THEN** pending publication is revoked and visible recovery is removed without affecting another notification
- **AND** a late completion or callback cannot navigate even after the same identifiers return

#### Scenario: Candidate changes during action revalidation
- **GIVEN** a displayed candidate captures request A
- **WHEN** action revalidation successfully returns absence or a different request B
- **THEN** A does not navigate, no generic error is shown and no draft is deleted; successful absence silently retires A
- **AND** B can become independently eligible if the same dashboard context still owns presentation

#### Scenario: Return to dashboard refreshes eligibility
- **WHEN** the dashboard becomes current after editor return by pop or declarative navigation, another covering route returns, or an admitted manual refresh is requested
- **THEN** one owner-qualified recovery lookup rechecks eligibility independently of remote read success
- **AND** explicit dismissal suppression survives covering-route return within the same retained visit, an undismissed eligible candidate can be offered after authoritative validation, and a new dashboard visit or new auth authority can offer an eligible intent again

### Requirement: Contextual recovery yields to ordinary notification feedback
Recovery SHALL yield to ordinary feedback and remain dashboard-owned. Ordinary duration, queue order, styling, actions and replacement SHALL remain compatible. Recovery-specific cancellation SHALL target only its request; explicit global clearing SHALL remain global. After ordinary feedback settles, recovery MAY return following authoritative validation. Interruption SHALL NOT record dismissal, alter durable drafts or consume nonces.

#### Scenario: DRAFT-11 Existing feedback precedes recovery
- **GIVEN** ordinary feedback is visible or queued
- **WHEN** an eligible recovery presentation is requested
- **THEN** existing feedback is preserved and recovery waits outside the native notification queue until it can be safely owned
- **AND** departure while waiting prevents its later appearance on another route

#### Scenario: DRAFT-11 New feedback displaces recovery
- **GIVEN** recovery is pending or visible
- **WHEN** ordinary feedback, including refresh failure, is requested
- **THEN** only recovery presentation is temporarily suspended and the ordinary notification follows its established duration and queue/replacement policy
- **AND** after ordinary feedback finishes, authoritative validation can present the same still-valid undismissed candidate again under current dashboard authority without recording dismissal or changing durable data

#### Scenario: DRAFT-11 Recovery returns after an ordinary error
- **GIVEN** a valid recovery Snackbar is visible
- **WHEN** an ordinary error displaces it and expires normally
- **THEN** recovery becomes visible again after successful authoritative validation under the same live dashboard authority

#### Scenario: DRAFT-11 Explicit dismissal survives ordinary feedback
- **GIVEN** the user explicitly closes or swipes away recovery
- **WHEN** ordinary feedback is subsequently displayed and finishes
- **THEN** the same candidate stays suppressed for that retained visit and its durable intent remains unchanged

#### Scenario: DRAFT-11 Account changes during interruption
- **GIVEN** ordinary feedback has interrupted account A's recovery
- **WHEN** the account changes before resumption or its validation completes
- **THEN** A's old request and callbacks cannot present or navigate for another account or a later A authority

#### Scenario: DRAFT-11 Multiple ordinary notifications interrupt recovery
- **GIVEN** recovery is visible or pending
- **WHEN** several non-replacing ordinary notifications arrive, including during deferred resumption validation
- **THEN** each retains its normal duration and relative queue order, no unrelated Snackbar is cleared, and recovery waits outside the native queue until the latest ordinary tail settles and authoritative validation succeeds

#### Scenario: DRAFT-11 Candidate or owner replaces pending or visible recovery
- **GIVEN** recovery for request A is pending or visible
- **WHEN** a genuinely different candidate or a replacement dashboard/auth/repository owner is bound
- **THEN** A's presentation and callbacks lose authority without suppressing a new eligible candidate, closing a queued controller or clearing unrelated messages
- **AND** the new candidate can appear only after its own successful validation and any outgoing recovery removal and ordinary feedback settlement

#### Scenario: DRAFT-11 Replacement feedback preserves pending or visible recovery
- **GIVEN** an owned recovery request is pending behind ordinary feedback or already visible
- **WHEN** `showSnackBar(replaceCurrent: true)` replaces ordinary feedback and the replacement expires
- **THEN** the recovery request survives without dismissal or durable changes and can appear after fresh candidate/owner validation under current dashboard authority
- **AND** current/queued ordinary feedback selected by replacement is removed as before; discarded tail callbacks cannot revive old presentations

#### Scenario: DRAFT-11 Replacement and ordinary feedback retain their policies
- **WHEN** replacement and non-replacing ordinary notifications arrive in sequence during recovery suspension
- **THEN** each replacement discards earlier ordinary entries, later ordinary calls queue normally with finite durations, and recovery waits for the latest surviving tail
- **AND** route/account/owner revocation or a candidate change during resumption validation prevents any obsolete recovery from returning; no queued controller is closed

#### Scenario: DRAFT-12 Explicit global clearing revokes presentation
- **GIVEN** recovery is pending or visible and ordinary feedback may be queued
- **WHEN** a caller intentionally invokes `clearAppSnackBars()` directly
- **THEN** current/queued feedback and the owned recovery request are revoked under the existing global contract; canceled callbacks cannot restore them
- **AND** durable drafts, checkpoints and navigation nonces are unchanged, no explicit user dismissal is recorded, and only a later established trigger may create a freshly validated recovery request

#### Scenario: DRAFT-12 Existing callers retain default behavior
- **WHEN** unrelated callers show ordinary notifications with or without an action
- **THEN** their existing finite timeout, semantic colors, action callback, default queue ordering and opt-in ordinary replacement remain supported
- **AND** FavouriteButton's direct global clear still immediately revokes the previous Undo; a later replacement message alone suspends recovery without invalidating its owned request

#### Scenario: Recovery remains accessible at supported widths
- **WHEN** recovery is shown at wide or narrow widths, in light or dark theme, or with enlarged text
- **THEN** its action and close control remain visible, legible and accessible with the existing semantic colors and touch/assistive-technology affordances
