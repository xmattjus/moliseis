# Admin Local Asset Staging Delta

## MODIFIED Requirements

### Requirement: Admin and Public storage roots remain isolated
Admin staged assets SHALL be private copies under their exact account/session ownership, separate from Public and picker-owned storage. Local descriptors SHALL contain canonical relative paths, owner and digest without original picker paths. Separately versioned persistence receipts SHALL not change that local path/identity contract. Neither feature's cleanup SHALL traverse the other's files.

#### Scenario: Original source disappears
- **WHEN** intake committed and the original file is removed
- **THEN** its private staged copy remains resolvable for that exact owner

#### Scenario: Identical content in two sessions
- **WHEN** two valid sessions acquire identical bytes
- **THEN** each owns independent files/descriptors and neither references the other's storage

#### Scenario: Feature cleanup
- **WHEN** either feature reconciles or removes contained local files
- **THEN** the other feature's sessions and descriptors remain unchanged

## ADDED Requirements

### Requirement: Confirmed asset progress is durable and exact-owner
Confirmed upload receipts and association IDs SHALL persist separately from local descriptor identity, bound to the exact account/session/digest/remote target. Legacy descriptors SHALL restore as local-only. Malformed progress SHALL not erase valid private bytes or authorize remote retry.

#### Scenario: Restart after upload confirmation
- **GIVEN** a confirmed receipt was durably recorded before association
- **WHEN** the real local store reopens
- **THEN** Save reuses the receipt and private source rather than uploading that file again

#### Scenario: Ambiguous association response
- **WHEN** remote association may have committed without confirmation
- **THEN** the descriptor and upload receipt remain available for exact-receipt server replay

#### Scenario: Receipt persistence failed before process death
- **WHEN** upload success was received but its receipt did not commit locally
- **THEN** restart does not invent confirmation and can use existing deterministic upload lookup/retry without claiming cross-service atomicity

### Requirement: Confirmed cleanup is item-specific and capacity remains accurate
Save SHALL remove only captured confirmed descriptors after recording association evidence. Failed removal SHALL preserve reusable confirmation. Capacity SHALL count a remotely associated receipt once after authoritative reconciliation, preserve uncaptured staged items and continue enforcing five images and 10 MiB.

#### Scenario: Remote association confirmed but descriptor removal fails
- **WHEN** local cleanup cannot commit
- **THEN** retry repairs that exact item without another upload and does not delete siblings or the owner

#### Scenario: New staging overlaps remote completion
- **WHEN** an uncaptured staged item commits while Save A completes
- **THEN** it remains local pending work for a later Save and is not swept by A's cleanup

#### Scenario: Concurrent capacity requests
- **GIVEN** associated and unconfirmed staged images consume four slots
- **WHEN** two candidates request local acquisition concurrently
- **THEN** local arbitration accepts at most one new distinct item while server insertion independently enforces five

#### Scenario: Size limit
- **WHEN** a selected file exceeds 10 MiB
- **THEN** it is not accepted into staging or uploaded and existing valid siblings remain
