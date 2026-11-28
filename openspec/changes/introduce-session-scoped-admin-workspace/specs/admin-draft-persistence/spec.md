# Admin Draft Persistence Delta

## ADDED Requirements

### Requirement: Explicit local selections and resume identities agree
An explicit Editor selection for a remote target SHALL bind only an account-owned local session compatible with that target. An explicit session-only recovery from the authorized Dashboard SHALL resolve the exact saved owner and its adopted target, if present. Missing or mismatched recovery SHALL fail without allocating a replacement draft or attaching the wrong target.

#### Scenario: Selection for 123 carries session 456
- **WHEN** a local Editor selection for remote submission 123 names a same-account session belonging to remote submission 456
- **THEN** the Editor reports the session unavailable, activates neither the mismatch nor an implicit replacement, and leaves both owners intact

#### Scenario: New session was adopted before recovery
- **WHEN** the authorized owner selects recovery by saved local session after Create adoption
- **THEN** recovery opens that session with its adopted target and staged data without issuing a Create

#### Scenario: A queued lookup loses authority
- **WHEN** an account-qualified draft lookup resolves after its initiating Workspace visit or authority is retired
- **THEN** it installs no activation and offers no result to a later visit

## REMOVED Requirements

### Requirement: Explicit remote routes and resume identities agree
**Reason**: Editor activation no longer accepts global route hints.

**Migration**: Use the account-qualified local target and session contract above; old addresses have no migration.
