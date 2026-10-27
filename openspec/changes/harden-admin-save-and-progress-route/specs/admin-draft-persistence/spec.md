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
Each Create or Update SHALL durably retain its captured valid input, kind, target, expected field-version token for Update and stable session identity before HTTP. Later checkpoints SHALL preserve the unresolved intent. Confirmed adoption or durable Update baseline settlement SHALL clear only the matching intent. Restored Update intent SHALL require read-back without ordinary resend; initialization SHALL not replay remotely.

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
