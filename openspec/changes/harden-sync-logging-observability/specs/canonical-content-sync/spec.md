## ADDED Requirements

### Requirement: Sync diagnostic success follows atomic commit and cursor persistence

Sync diagnostics SHALL reflect durability: staged ObjectBox writes SHALL NOT be called committed; optional content-commit success MAY follow the completed outer transaction. Exactly one overall sync success SHALL follow durable sync-state persistence. Fetched DTO counts SHALL be distinguished from committed changes, and unsupported per-entity write totals SHALL NOT be asserted.

#### Scenario: Fetched counts are not write counts

- **WHEN** sync diagnostics show fetched DTO counts
- **THEN** those counts describe retrieval, not persisted per-entity insert/update/delete totals, unless independently measured committed-write counts exist

#### Scenario: Later repository fails after earlier writes

- **WHEN** an early repository stages inserts, updates, or deletions and a later repository fails inside the same write transaction
- **THEN** all writes roll back according to the existing sync contract
- **AND** no entity, repository, content-commit, or sync-completion diagnostic falsely claims that those rolled-back writes were durably committed

#### Scenario: Settings save fails after successful content commit

- **WHEN** the content transaction succeeds but saving the cursor/completion pair fails
- **THEN** reporting may identify the committed content separately but SHALL identify the overall sync as failed
- **AND** no sync-success diagnostic is emitted and the previous cursor remains authoritative

#### Scenario: Successful sync saves cursor last

- **WHEN** the four repositories commit atomically and the cursor/completion pair is saved successfully
- **THEN** any content-commit success describes an already completed transaction
- **AND** exactly one overall sync-success diagnostic SHALL be emitted after the durable state update
