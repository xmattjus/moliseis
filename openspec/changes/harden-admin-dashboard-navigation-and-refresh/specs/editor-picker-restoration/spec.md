# Spec Delta

## ADDED Requirements

### Requirement: Dashboard recovery requires authoritative navigation eligibility
The dashboard SHALL offer contextual recovery only after a successful current-Admin-account lookup yields a valid navigation intent. Repository availability or an ordinary draft SHALL NOT imply eligibility. Successful absence SHALL hide recovery; lookup failure SHALL remain unknown without deletion, navigation or a claim of successful recovery. Existing account/session/target validation SHALL remain authoritative.

#### Scenario: DRAFT-01 No navigation intent
- **GIVEN** no current-account navigation intent exists, even if a repository and ordinary checkpoint exist
- **WHEN** the dashboard resolves recovery eligibility
- **THEN** no recovery Snackbar or permanent AppBar resume action is shown

#### Scenario: DRAFT-02 Valid candidate is offered once
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
- **GIVEN** recovery lookup fails during initial lookup or action revalidation
- **WHEN** that lookup settles under live dashboard authority
- **THEN** no recovery navigation or authoritative-absence claim occurs, durable state is preserved and established generic error feedback is shown once for that attempt
- **AND** the next dashboard visit, editor return or explicitly admitted manual refresh can recheck without polling or rebuild-driven retries

### Requirement: Recovery notification has an owned persistent lifetime
The recovery Snackbar SHALL use existing notification styling and remain until dismissal, recovery activation or context invalidation. Suppression SHALL be ephemeral and candidate-specific within a dashboard visit. A changed navigation request SHALL be eligible again. Dashboard departure, authority replacement or disposal SHALL revoke queued and visible recovery effects without deleting durable work or clearing unrelated notifications.

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
- **AND** the existing editor receives its exact session hint; normal editor initialization and exit protections remain authoritative
- **AND** successful editor presentation suppresses this candidate for the originating visit without consuming its durable nonce

#### Scenario: DRAFT-08 Equivalent candidates do not repeat
- **GIVEN** a candidate was displayed and dismissed or recovered during this visit
- **WHEN** rebuilds, equivalent successful lookups or repository notifications occur
- **THEN** no duplicate notification appears
- **AND** a later genuinely different navigation request can be offered once, even for the same session

#### Scenario: DRAFT-09 Stale work cannot regain presentation authority
- **GIVEN** a recovery lookup, pending presentation or callback captures a dashboard visit and authority generation
- **WHEN** the route leaves or is covered, auth or draft/dashboard owner changes, logout occurs or the widget is disposed
- **THEN** pending publication is revoked and visible recovery is removed without affecting another notification
- **AND** a late completion or callback cannot navigate even after the same identifiers return

#### Scenario: Candidate changes during action revalidation
- **GIVEN** a displayed candidate captures request A
- **WHEN** action revalidation successfully returns absence or a different request B
- **THEN** A does not navigate and no draft is deleted
- **AND** B can become independently eligible once if the same dashboard context still owns presentation

#### Scenario: Return to dashboard refreshes eligibility
- **WHEN** the dashboard becomes current after editor return or another covering route, or an admitted manual refresh is requested
- **THEN** one owner-qualified recovery lookup rechecks eligibility independently of remote read success
- **AND** suppression survives covering-route return within the same retained visit, while a new dashboard visit or new auth authority can offer an eligible intent again

### Requirement: Contextual recovery yields to ordinary notification feedback
A persistent recovery notification SHALL NOT indefinitely block ordinary feedback or outlive its dashboard context. Ordinary notification callers SHALL retain finite duration, queue ordering, semantic colors, responsive action layout and existing explicit replacement behavior. Recovery invalidation SHALL target only its own pending or visible presentation.

#### Scenario: DRAFT-11 Existing feedback precedes recovery
- **GIVEN** ordinary feedback is visible or queued
- **WHEN** an eligible recovery presentation is requested
- **THEN** existing feedback is preserved and recovery waits outside the native notification queue until it can be safely owned
- **AND** departure while waiting prevents its later appearance on another route

#### Scenario: DRAFT-11 New feedback displaces recovery
- **GIVEN** recovery is pending or visible
- **WHEN** ordinary feedback, including refresh failure, is requested
- **THEN** only recovery is revoked and the ordinary notification follows its established queue/replacement policy
- **AND** the same recovery candidate does not immediately reappear during that visit

#### Scenario: DRAFT-12 Existing callers retain default behavior
- **WHEN** unrelated callers show ordinary notifications with or without an action
- **THEN** their existing finite timeout, action callback, default queue ordering and opt-in global replacement remain supported

#### Scenario: Recovery remains accessible at supported widths
- **WHEN** recovery is shown at wide or narrow widths, in light or dark theme, or with enlarged text
- **THEN** its action and close control remain visible, legible and accessible with the existing semantic colors and touch/assistive-technology affordances
