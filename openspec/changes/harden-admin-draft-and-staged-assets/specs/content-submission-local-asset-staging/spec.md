## ADDED Requirements

### Requirement: Admin local storage does not consume Public picker recovery
Installing or exercising Admin draft/file storage SHALL not create a platform retrieval consumer or intercept either feature's picker results. The existing Public recovery path SHALL retain its current initialization, session, capacity, deduplication and error behavior until a separately reviewed integrated transition replaces it.

#### Scenario: Local storage is constructed or reconciled
- **WHEN** Admin local repositories or their local session component are constructed, initialized or exercised
- **THEN** no platform picker launch/retrieval occurs and no Public recovery consumer is replaced

#### Scenario: Public editor performs recovery
- **WHEN** the existing Public route requests Android recovery while Admin foundations are installed
- **THEN** its existing feature recovery contract remains in force without an additional consumer, durable global lease or new launch restriction

#### Scenario: Existing normal picker behavior
- **WHEN** either existing feature selects or cancels media on Android, iOS or macOS
- **THEN** merely installing Admin local storage adds no picker gate, route change or result attribution rule

### Requirement: Public local cleanup excludes Admin owned storage
Public checkpoint, reconciliation, discard and finalization SHALL remain scoped to Public draft/staged ownership. Admin local files and account/session rows SHALL not become Public orphan state because they are inactive or another feature is visible.

#### Scenario: Public discard with inactive Admin work
- **WHEN** Public discards or finalizes its draft while Admin has valid stored sessions/files
- **THEN** Public's existing cleanup completes within its own ownership and Admin work remains intact

#### Scenario: Admin failure does not alter Public ownership
- **WHEN** Admin local draft loading or reconciliation fails
- **THEN** Public's durable draft/assets remain unchanged and are not adopted or cleaned by Admin
