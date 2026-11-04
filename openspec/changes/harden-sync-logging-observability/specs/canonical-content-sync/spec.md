## ADDED Requirements

### Requirement: Sync diagnostic success follows atomic commit and cursor persistence

Operational success diagnostics for canonical synchronization SHALL follow the actual durability boundaries already defined by this capability. A repository or entity write that is merely staged inside the cross-repository ObjectBox transaction SHALL NOT be reported as successfully committed. Content commit success MAY be logged after the outer transaction returns successfully; overall sync success SHALL be logged only after both the content transaction and durable synchronization-state save succeed. Any reported counts SHALL distinguish fetched DTOs from committed changes and shall not assert unsupported per-entity persistence totals.

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
