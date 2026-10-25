## ADDED Requirements

### Requirement: Asset requests retain their admission target
Asset addition and removal SHALL bind their target before deferred entry. Removal SHALL bind the requested session and digest, never a later occupant of the index. A valid but subsequently absent or retired target SHALL be a harmless no-op. Originally invalid indices SHALL remain failures. Stale picker results SHALL create no staging or user warning.

#### Scenario: Removal followed by list change
- **WHEN** removal of index zero is admitted for digest A and another mutation changes the list before entry
- **THEN** only A in the captured session can be removed, never the new index-zero asset

#### Scenario: Invalid index before restoration
- **WHEN** removal is admitted for an index outside the currently exposed list and initialization later restores assets at that index
- **THEN** removal remains an invalid-index failure with zero removal I/O

#### Scenario: Addition crosses rotation before entry
- **WHEN** addition for a ready session A is admitted and clear rotates to B before action entry
- **THEN** no picker or staging phase begins for B on behalf of that request

### Requirement: Rendered removal callbacks validate before admission
A rendered removal callback SHALL synchronously validate mounted consumer, captured ViewModel owner, session, original index and digest before requesting removal. A reused index or obsolete owner/session SHALL cause no admission, repository call, snapshot change or feedback. An unchanged target SHALL remain removable after an ordinary rebuild. Persistence SHALL remain owned by the ViewModel.

#### Scenario: Stale index represents a different asset
- **WHEN** a callback rendered for A at index zero is retained, the list becomes only B and the old callback is invoked
- **THEN** B remains present, no removal request or repository call occurs and neither success nor failure is published for that obsolete callback

#### Scenario: Old callback after owner replacement
- **WHEN** a retained callback is invoked after its consumer receives another ViewModel, even with equal session identifiers
- **THEN** neither the old nor replacement owner receives a removal request and no membership or feedback changes

#### Scenario: Old callback after session rotation
- **WHEN** a retained callback is invoked after its original ViewModel rotates to a different session
- **THEN** no removal is admitted for the new session and no success or error notification is emitted

#### Scenario: Valid callback survives rebuild
- **WHEN** an ordinary rebuild leaves the captured owner, session, index and digest unchanged and the retained callback is invoked
- **THEN** one valid removal can be admitted and only that target is removed after persistence succeeds

### Requirement: Loading requests bind one initialization outcome
A request made while initialization is pending SHALL bind that initialization instance before waiting. Restoration SHALL supply its immutable recovered draft and ordered assets; authoritative absence SHALL retain the request's provisional draft. The outcome SHALL be fixed before publication. Later session state SHALL NOT replace that bound outcome, and unknown persisted ownership SHALL remain unavailable.

#### Scenario: Restored session is selected once
- **WHEN** addition or submission is requested during one initialization and that initialization restores session A
- **THEN** the request resolves only from that initialization's fixed A outcome and cannot adopt B created by a subsequent clear

#### Scenario: Absence preserves request-time fields
- **WHEN** submission is requested with provisional draft A while initialization is pending, fields are edited afterward and initialization reports absence
- **THEN** the request uses captured A rather than the later edits and still awaits coordinated staged initialization

#### Scenario: Unknown draft state
- **WHEN** initialization cannot establish persisted ownership
- **THEN** identity-dependent mutation remains unavailable without orphan cleanup or reassignment of assets to a fresh session

### Requirement: Recovery eligibility cannot migrate between sessions
Android recovery SHALL bind the eligible restored identity from its identified initialization before waiting for lost media. Clear, retirement or owner disposal SHALL invalidate subsequent recovery commits for that identity. Retrieval failures expected from the platform SHALL remain best-effort diagnostics. Non-Android requests SHALL perform no retrieval.

#### Scenario: Recovery response arrives after clear
- **WHEN** recovery is admitted for initialization A, clear creates B and lost media arrives afterward
- **THEN** neither A nor B gains staged media from that response

#### Scenario: Response precedes initialization
- **WHEN** lost media arrives before the bound initialization completes
- **THEN** processing waits for that initialization's eligible restored identity and cannot adopt an absent, unknown or replacement session

#### Scenario: Capacity and deduplication stay shared
- **WHEN** recovery and normal addition supply overlapping or excessive media
- **THEN** their local commits are serialized through the existing boundary and preserve shared size, digest and capacity rules

### Requirement: Admission does not add another lifecycle queue
The existing local arbitration SHALL remain the sole ordering boundary for checkpoint, staged commit, removal and retirement. Per-operation single-flight SHALL NOT replace cross-operation arbitration. Picker interaction and remote submission SHALL remain outside that boundary, and every exit including unexpected throw SHALL release it.

#### Scenario: Picker gap permits clear
- **WHEN** a picker remains pending after its durable checkpoint
- **THEN** clear can acquire local arbitration and retire that session without waiting for the picker

#### Scenario: Throw does not poison arbitration
- **WHEN** a serialized mutation throws unexpectedly
- **THEN** the next independent local operation can enter after release and the original error remains a runtime failure
