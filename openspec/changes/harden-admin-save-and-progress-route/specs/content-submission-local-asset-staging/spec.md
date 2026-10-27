# Content Submission Local Asset Staging Delta

## MODIFIED Requirements

### Requirement: Android lost data is acquired early and processed after restoration
Option B SHALL intentionally remove previous Public lost-media staging: the single application entry discards all pinned-API lost-data candidates lacking native feature/session correlation. Empty/error/missing/cancelled or nonterminating retrieval SHALL not mutate committed staging, imply recovery, gate editor restoration or block future selection. Normal live selection and durable draft/staged-file restoration SHALL remain supported.

#### Scenario: Production startup ordering waits after retrieval
- **GIVEN** draft initialization and application retrieval overlap
- **WHEN** native media returns before restoration
- **THEN** it is discarded without guessed attribution and Public restoration proceeds independently

#### Scenario: Recovery deduplicates against restored assets
- **GIVEN** Public restores its only durable draft and the previous recovery path would have accepted a returned image
- **WHEN** lost-data returns that image without native feature/session identity
- **THEN** no new image is staged, even if the Dart launch record matches
- **AND** previously committed staged descriptors/files/order remain unchanged

#### Scenario: Clear makes a deferred recovery response stale
- **GIVEN** Public A existed before clear rotated to B
- **WHEN** delayed lost-data returns
- **THEN** neither A nor B acquires that media

#### Scenario: Recovery honors restored capacity and size limits
- **GIVEN** valid staged files occupy restored capacity
- **WHEN** native lost-data returns oversized or excess files
- **THEN** all unattributed files are discarded without changing existing files or capacity

#### Scenario: Recovery consumes only remaining restored capacity
- **GIVEN** four valid staged assets restore
- **WHEN** lost-data returns additional files
- **THEN** no additional asset commits and all four retain paths, digests and order
- **AND** subsequent normal selection still enforces the remaining capacity and size rules

#### Scenario: No durable recovered session prevents reassociation
- **WHEN** initialization is absent, unknown or unable to restore a durable draft
- **THEN** lost-data is not assigned to a fresh identity and failed loading cannot authorize cleanup

#### Scenario: Recovered candidate-processing failure is observable but non-blocking
- **WHEN** the application retrieval or discard path reports an expected failure
- **THEN** it remains best effort without user-facing successful recovery or mutation of valid staged state

#### Scenario: Non-Android and empty recovery remain no-ops
- **WHEN** platform is not Android or retrieval is empty
- **THEN** no media commits and no warning is shown for an empty response of unknown cause
- **AND** non-Android performs no retrieval

#### Scenario: Thrown Android recovery still initializes
- **WHEN** retrieval throws or never completes independently of Public initialization
- **THEN** normal draft/staged restoration still runs and settles on its own result without awaiting retrieval
- **AND** the editor has no permanent recovery loading state

### Requirement: Recovery eligibility cannot migrate between sessions
Native lost-data candidates SHALL not gain attribution from an initialization outcome, persisted navigation ticket or currently visible draft. Public clear, retirement, disposal or replacement SHALL invalidate old live callback authority. Only ordinary attributed live selection SHALL enter the existing candidate pipeline. Non-Android SHALL not retrieve lost data.

#### Scenario: Recovery response arrives after clear
- **WHEN** lost media arrives after A is retired and B created
- **THEN** neither session gains the media

#### Scenario: Response precedes initialization
- **WHEN** lost media arrives before initialization completes
- **THEN** it is discarded without binding to whatever draft later restores

#### Scenario: Normal resume before a live callback
- **GIVEN** a normal Public picker retains its captured owner/session/activation and has not been abandoned
- **WHEN** the app resumes before the original Future returns an image, cancellation or error
- **THEN** the image enters ordinary candidate processing, cancellation settles without an asset, or error settles through its existing path
- **AND** resume alone does not invalidate any of those outcomes or block the next selection

#### Scenario: Capacity and deduplication stay shared
- **WHEN** valid normal selections overlap other local lifecycle mutations
- **THEN** existing arbitration preserves size, digest, capacity and rotation guarantees without a second recovery queue

### Requirement: Admin local storage does not consume Public picker recovery
Admin and Public local storage SHALL neither launch retrieval nor intercept platform results. Their application integration SHALL use one shared lost-data entry and captured normal-launch authority. Constructing local repositories SHALL remain inert with respect to platform and remote work.

#### Scenario: Local storage is constructed or reconciled
- **WHEN** Admin local repositories or their local session are exercised
- **THEN** no platform launch/retrieval or Public consumer is created

#### Scenario: Public editor performs recovery
- **WHEN** Public and Admin editors reconstruct on Android
- **THEN** feature widgets and ViewModels do not independently retrieve lost data
- **AND** the application entry applies conservative discard without a durable lease

#### Scenario: Existing normal picker behavior
- **WHEN** either feature selects or cancels media normally on Android, iOS or macOS
- **THEN** valid live callbacks retain their feature-owned intake behavior and cancellation keeps later selections available
