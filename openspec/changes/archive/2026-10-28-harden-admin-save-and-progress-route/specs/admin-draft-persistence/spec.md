# Admin Draft Persistence Delta

## REMOVED Requirements

### Requirement: Draft foundations remain outside active editor workflows
**Reason**: Plan 1's inert delivery is complete; Plan 2 activates the production consumer while keeping local storage free of auth, HTTP, picker and widget orchestration.
**Migration**: Use the application-owned editor with the existing local session boundary. No parallel route-owned editor or retroactive Plan 1 integration claim is permitted.

## ADDED Requirements

### Requirement: Confirmed identity adoption is atomic locally
A confirmed new-to-persisted identity transition SHALL retain account/local UUID, draft technical identity, latest checkpoint fields, staged order and private files. Lookup and every same-session descriptor target SHALL change atomically. Destination conflicts SHALL preserve both owners without merge or overwrite.

#### Scenario: Create succeeds but adoption is interrupted
- **GIVEN** the original account/new owner has a durable pending Create intent
- **WHEN** remote Create commits and the process dies before adoption commits
- **THEN** reopening retains the original UUID and files, and explicit same-key replay recovers the remote ID

#### Scenario: Death during adoption transaction
- **WHEN** the process interrupts lookup and descriptor rebinding
- **THEN** reopen sees either the complete old identity or complete adopted identity, never mixed ownership or duplicate owner records

#### Scenario: Destination already belongs to another local session
- **WHEN** adoption encounters a different account/remote-target owner
- **THEN** no row or file is deleted/reassigned and local adoption returns a settled unavailable conflict

#### Scenario: Adopted session is reopened through an old new-editor intent
- **WHEN** navigation resumes the exact original account/session UUID
- **THEN** lookup resolves its adopted remote target without allocating a new owner

### Requirement: Unresolved field-write intent survives later local checkpoints
Each Create or Update SHALL durably retain its captured valid input, kind, target, expected field-version token for Update and stable session identity before HTTP. Later checkpoints SHALL preserve the unresolved intent. Confirmed adoption or durable Update baseline settlement SHALL clear only the matching intent. Restored Update intent SHALL require read-back before any explicit original A/V continuation, without ordinary resend; initialization SHALL not replay remotely.

#### Scenario: Local B is incomplete after ambiguous Create A
- **WHEN** checkpoint B replaces editable fields after Create A lost its response
- **THEN** explicit retry can replay original valid A under the same UUID while preserving B as current/local work

#### Scenario: Process dies with server Update still pending
- **GIVEN** unresolved Update A is durable and a later checkpoint contains B
- **WHEN** the process restarts before the server operation settles
- **THEN** read-back compares captured A and normal Save cannot resend A or B while outcome remains unknown
- **AND** old baseline equality, restart or elapsed time cannot prove cancellation

### Requirement: Remote confirmation preserves newer local work
Confirmation SHALL record only the captured remote projection and SHALL not overwrite newer current fields, effective baseline or physical checkpoint fields. Required local metadata failure SHALL preserve disk truth and return partial/local repair rather than claim physical success.

#### Scenario: Update A versus checkpoint B
- **WHEN** B checkpoints before remote confirmation of A
- **THEN** B remains the physical field snapshot and is not declared remotely saved

### Requirement: Save and staging retain owners
Successful remote Save, baseline replacement, association cleanup and last-asset removal SHALL retain the exact durable owner. Already-admitted local commits SHALL remain bound to their captured owner and serialize with adoption and checkpointing. No owner-retirement obligation registry SHALL be introduced.

#### Scenario: Staged commit overlaps Update completion
- **WHEN** a local acquisition commits before or after remote Update confirmation
- **THEN** its parent remains durable and valid staged bytes restore on reopen

#### Scenario: Revocation or failed cleanup
- **WHEN** authorization changes during a local commit or file cleanup fails after descriptor deletion
- **THEN** committed work stays private to its original owner and failed cleanup cannot authorize owner deletion or media resurrection

### Requirement: Exact field-intent settlement preserves local work
A proven first-dispatch rejection or an observed field-version fence SHALL retire only the matching intent under exact account/session/activation, attempt and kind. Settlement SHALL preserve newest C/E/P, historical remote evidence, staging receipts/files and navigation, and SHALL NOT confirm remote success or grant fresh mutation authority. Empty intent SHALL be an idempotent local no-op; another intent or obsolete activation SHALL fail closed.

#### Scenario: Rejected A with newer checkpoint B
- **GIVEN** the current live Save first captured A and a typed response proves its only dispatch did not write
- **WHEN** A is durably settled after B checkpoints
- **THEN** B and all retained local assets remain unchanged, and reopen does not restore A’s intent
- **AND** an Update requires compatible fresh remote authority before another field mutation

#### Scenario: Settlement persistence fails
- **WHEN** removing the matching rejected intent fails locally
- **THEN** the durable intent remains and normal remote Save is not admitted
- **AND** an explicit request-bound local-only settlement retry is available while its proof survives

#### Scenario: A later rejection does not settle an earlier ambiguous request
- **GIVEN** an intent was restored or retried and an earlier request might still have committed
- **WHEN** the current HTTP request is rejected before dispatch or by its conditional predicate
- **THEN** that response alone SHALL NOT declare the entire intent unapplied
- **AND** Update uses observed projection/version recovery; Create retains the original server UUID

### Requirement: Explicit corrected Create retains uncertain server identity
After a verified pre-dispatch rejection of a restored/ambiguous Create, an authorized, explicitly admitted Save of corrected valid fields SHALL replace the captured Create request with a new local attempt identity under the original session UUID. It SHALL preserve newer C/P, staged work and prior-outcome uncertainty. Replay SHALL adopt the authoritative existing/created record and stop on differing or moderated fields without overwriting it.

#### Scenario: Earlier Create A may have committed while corrected B is submitted
- **WHEN** the user explicitly saves valid B after the current request for A was rejected before dispatch
- **THEN** the request still uses A’s original client submission UUID
- **AND** an earlier committed A is discovered rather than duplicated, while B remains local and later phases stop on conflict
- **AND** replacement requires exact account/session/activation authority and successful local persistence; failure SHALL NOT claim success or authorize an unsafe remote request

### Requirement: Explicit remote routes and resume identities agree
A session hint on an explicit remote-ID editor route SHALL resolve under the current account and match that ID before any activation. Rejection SHALL preserve previously active work. New-editor and Progress bindings without an explicit remote target SHALL retain adopted-session restoration.

#### Scenario: Route 123 carries session 456
- **WHEN** `/admin/submissions/123` supplies a same-account session belonging to remote submission 456
- **THEN** the route is settled unavailable and submission 456 is not activated or published through route 123
- **AND** neither existing draft is overwritten or discarded
