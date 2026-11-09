# Spec Delta

## ADDED Requirements

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
