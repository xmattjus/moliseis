# Admin authorization delta

## ADDED Requirements

### Requirement: Admin authority follows continuous observed authorization

The authentication owner SHALL distinguish each continuous interval of observed Admin authority for one account. Loss, replacement or auth stream failure SHALL irreversibly retire the interval. Recovery SHALL establish fresh authority from the current authorized session. Profile changes and ordinary refresh of a continuously authorized account SHALL preserve its authority.

#### Scenario: Authority ends and the same account returns
- **WHEN** signed-out, anonymous, same-account non-Admin or stream failure is observed, followed by authorized A
- **THEN** A receives fresh authority and callbacks, routes and work admitted before loss remain obsolete

#### Scenario: Queued replacements
- **WHEN** the auth owner receives consecutive authority changes before the Navigator reconciles, including A to B to A
- **THEN** each observed interruption retires the prior authority and the final live session alone authorizes a fresh Admin entry

#### Scenario: Continuous Admin token refresh
- **WHEN** the same authorized account refreshes its token, updates profile metadata or emits a duplicate notification without observed interruption
- **THEN** its current pages, owner and otherwise valid operations retain their authority

### Requirement: Obsolete Admin history becomes unreachable

After observed Admin authority loss or replacement, obsolete Admin history SHALL be removed from reachable Navigator history. Pending navigation, saved route information and old exit decisions SHALL NOT reinstall it. Authority-driven removal SHALL preempt obsolete exit restrictions. Ordinary authorized navigation SHALL retain existing exit protections.

#### Scenario: Imperative cover commits before its frame
- **GIVEN** a settled Admin Dashboard, existing editor, new editor, Save Progress or malformed diagnostic and a committed imperative cover while the prior route remains physically current
- **WHEN** authority ends, the Navigator reconciles and system Back is delivered
- **THEN** the prior Admin pages cannot become current or expose protected content or actions, and associated dialogs cannot authorize work
- **AND** obsolete protected pages are absent from installed Back history

#### Scenario: Admin area loses its authority
- **WHEN** the user is in Admin and observed access ends
- **THEN** external loss leads once to Login when sync permits, and the existing admitted explicit logout can retain its Home departure
- **AND** Back can reveal preserved legitimate public ancestry but cannot reopen the obsolete Admin area

#### Scenario: A different Admin takes over
- **WHEN** Admin B replaces A while Admin is current
- **THEN** B reaches a fresh Dashboard and Back cannot reveal A's Dashboard, editor, diagnostics or progress

#### Scenario: Public destination or sync covers Admin
- **WHEN** an authority transition happens while an unrelated public route or Sync is current and obsolete Admin matches remain underneath or in return state
- **THEN** public ancestry and the current eligible public destination are preserved where possible
- **AND** running or fatal sync retains precedence, validated public return targets retain existing behavior, and stale Admin return targets resolve to the authorized landing without restoring their history or arguments

#### Scenario: The public Content Submission route survives retirement
- **GIVEN** the public form covers obsolete Admin history, with or without its active Progress page
- **WHEN** Admin reconciliation retains those pages
- **THEN** the original form and applicable Progress pages retain their route, draft, operation and transition ownership without a new exit decision, checkpoint or discard
- **AND** a pending or later navigation that genuinely removes the form remains subject to its existing exit protections

#### Scenario: Navigation is restored or a decision is pending
- **WHEN** saved route state or an obsolete async navigation or exit decision would otherwise reinstall or preserve an Admin visit from ended authority
- **THEN** the old visit and its associated pageless routes cannot resume
- **AND** an authorized fresh entry remains subject to current account, route and draft checks

### Requirement: Dashboard presentation belongs to its admitting authority

Dashboard data, action state and feedback SHALL be available only to their continuously authorized owner. Revocation SHALL permanently retire that owner and stop protected presentation independently of Navigator reconciliation. A replacement Admin Dashboard SHALL begin fresh reads under its own authority.

#### Scenario: Old Dashboard remains mounted
- **WHEN** Dashboard authority is lost or replaced while the old page or dialog is still mounted
- **THEN** the old rows, contributor names, ignored-source information, command snapshots, pending revision IDs, recovery and mutation or refresh feedback cannot be rendered, accessed through semantics, or acted on in the next render or transition frame
- **AND** obsolete callbacks are inert at observed revocation

#### Scenario: Dashboard feedback shares ordinary application ordering
- **GIVEN** Dashboard and unrelated ordinary feedback share the application Snackbar queue
- **WHEN** Dashboard authority ends with previously admitted feedback visible or queued
- **THEN** its feedback is withdrawn without clearing, reordering or shortening unrelated messages
- **AND** recovery retains its existing suspension, revalidation, dismissal and explicit global clearing policies

#### Scenario: Another Admin opens Dashboard
- **WHEN** B gains access in place of A
- **THEN** B initially receives fresh presentation and its own reads, and neither cached A data nor A's pending responses populate B's owner

### Requirement: Dashboard actions require their original live authority

Dashboard actions SHALL require their admission-time authority at callback invocation, command reservation, repository entry and each subsequent workflow phase. Revocation SHALL prevent new admissions, protected navigation and follow-up work even during synchronous notification or before a reserved async action begins. Authorized single-flight behavior SHALL be preserved.

#### Scenario: Old controls are invoked
- **WHEN** A's filter, retry, refresh, reactivation, editor opening, pending revision, recovery, or dialog callback executes after A's authority ends
- **THEN** it starts no command, repository call or protected navigation and emits no stale feedback, including when B or a fresh A is currently authorized

#### Scenario: Revocation between reservation and dispatch
- **WHEN** initial or user-triggered work is reserved and a listener or auth event revokes its authority before the asynchronous repository entry
- **THEN** the repository operation does not start and the reservation settles safely

#### Scenario: In-flight work settles after revocation
- **WHEN** a read or mutation admitted before revocation completes with success or failure after revocation
- **THEN** its owner settles privately with existing error routing and cannot publish outcomes, data, links, navigation, or feedback
- **AND** revocation during coordinated post-mutation refresh also prevents any later refresh stage
