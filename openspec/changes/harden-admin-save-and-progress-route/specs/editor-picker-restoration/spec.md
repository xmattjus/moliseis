# Editor Picker Restoration Delta

## Purpose

Restore the originating Public or account-owned Admin editor independently of best-effort Android media retrieval while preventing cross-feature or cross-session media attribution.

## ADDED Requirements

### Requirement: Lost-data retrieval has one application entry
Android lost-data retrieval SHALL have one process-wide entry point independent of feature routes and authentication. Each process SHALL attempt retrieval at most once. Non-Android SHALL perform no retrieval. Feature storage SHALL neither consume the native cache nor own competing retrieval calls.

#### Scenario: Public and Admin both reconstruct
- **WHEN** both features initialize or rebuild after restart
- **THEN** only the application entry attempts retrieval, without starting feature Save or uploads

### Requirement: Unattributed native media is discarded
Media whose native feature/session attribution is uncertain SHALL never be attached by guessing. Option B SHALL intentionally withdraw previous Public lost-media recovery: discard all pinned-API lost-data candidates even with a matching Dart intent or one draft. Live intake SHALL require its captured valid account/session/activation and request nonce.

#### Scenario: Cross-feature candidate
- **GIVEN** an interrupted Admin picker and a visible Public editor, or the reverse
- **WHEN** lost-data returns files
- **THEN** neither feature acquires them and visibility or latest navigation intent does not establish ownership

#### Scenario: Same target reopened
- **WHEN** an old callback arrives after A1 to B to A2
- **THEN** it cannot acquire into A2 by matching target or UUID alone

### Requirement: Recovery failure cannot block navigation or future picking
Empty, missing, cancelled, delayed or exceptional lost-data responses SHALL not imply successful recovery, change valid drafts, crash the app, hold a loading route or create an indefinite picker lease. Normal launch cancellation/error and local interruption abandonment SHALL release runtime admission without claiming native cancellation. Empty retrieval SHALL not be treated as evidence of native cancellation.

#### Scenario: Empty retrieval or exception
- **WHEN** retrieval returns empty, throws, never completes, or finishes after editor restoration
- **THEN** editor access and later explicit picker requests remain usable without a recovery warning for unknown empty cause

#### Scenario: Delayed result and repeated restarts
- **WHEN** an old result appears after an empty retrieval or a later process retrieves again
- **THEN** it is not assigned to a current feature and no persistent pending ticket prevents new requests

#### Scenario: Normal picker cancellation
- **WHEN** a valid live request returns cancellation
- **THEN** no asset is reported recovered, its own launch/navigation intent settles, and another normal selection can be admitted

### Requirement: Normal resume preserves original request authority
An ordinary resumed or background lifecycle transition SHALL NOT invalidate a pending picker request. While captured owner/session/activation and nonce remain valid, any image, cancellation or error completion of its original Future SHALL be processed normally even if resume happened first. Rebuilds/rebinds retaining the same activation SHALL not abandon it.

#### Scenario: Resume precedes valid image completion
- **GIVEN** the original request retains valid authority and was not abandoned
- **WHEN** the normal picker opens, the app resumes, then its Future returns an image
- **THEN** ordinary owner-checked candidate processing accepts the eligible image

#### Scenario: Resume precedes cancellation completion
- **WHEN** a valid original picker request resumes before its Future returns cancellation
- **THEN** cancellation settles normally with no asset and the next selection can be admitted

#### Scenario: Resume precedes error completion
- **WHEN** a valid original picker request resumes before its Future returns an error
- **THEN** the existing error path settles the request and the next selection can be admitted

### Requirement: Local abandonment requires revocation or explicit user intent
Local abandonment SHALL require actual owner/account/session/activation revocation or an explicit request-bound user action. It SHALL revoke publication before settling the wrapper and releasing only its own application admission, without waiting for native completion or claiming native cancellation. Elapsed time, resume, empty retrieval or presumed Activity loss SHALL not suffice.

#### Scenario: Activity detach leaves native callback unresolved
- **GIVEN** Activity recreation retains the Dart engine and valid editor but the original native Future never completes
- **WHEN** the user activates Interrompi selezione for that pending nonce
- **THEN** the wrapper and feature action settle locally, editor/checkpoint access remains usable and application admission becomes available for a separate explicit next pick
- **AND** no native cancellation, successful recovery or automatic relaunch is claimed

#### Scenario: Actual reconstruction replaces activation
- **WHEN** route/editor reconstruction actually revokes A1 and establishes a different activation
- **THEN** A1 is locally abandoned and cannot publish into the replacement
- **AND** a same-activation rebuild or mere resume does not trigger this path

#### Scenario: Abandoned A completes after B starts
- **GIVEN** A lost authority before B was admitted
- **WHEN** A's original Future later returns media or error
- **THEN** A cannot stage/upload, publish into B, release B's lease or clear B's navigation nonce

#### Scenario: A1 cannot regain authority after returning to A
- **WHEN** A1 is abandoned, B activates, A2 then activates and A1 completes late
- **THEN** original activation/nonce guards reject A1 despite equal account/session/target

#### Scenario: Native operation remains active after local abandonment
- **WHEN** a subsequent explicit picker request is rejected as already_active
- **THEN** it settles as a native failure with editor access and later explicit retry available
- **AND** the application does not spin, hold a permanent lease or claim it cancelled the old native operation

### Requirement: Pending selection has a minimal explicit escape
The authorized current editor SHALL expose Interrompi selezione while its picker wrapper is pending. The request-bound action SHALL remain callable while the add action runs, preserve fields/files/resume intent, and settle locally as interrupted. It SHALL not depend on retrieval, a timer or a new state machine, and SHALL not auto-launch another picker.

#### Scenario: Repeated interruption and subsequent selection
- **WHEN** pending picks are repeatedly interrupted and explicitly abandoned
- **THEN** each local admission releases without waiting for its native Future, and a subsequent valid explicit callback can be accepted under its own authority
- **AND** no global application lock or permanent recovery spinner prevents editor/local-checkpoint access

### Requirement: Navigation intent is independent of media recovery
Before picker launch the editor SHALL checkpoint and persist feature/session, per-launch nonce and Admin account/target. Restoration SHALL not await media retrieval. Normal completion SHALL compare-and-clear only its nonce while the editor is usable. Local abandon SHALL retain resume intent through auth/lifecycle interruption. Failed persistence SHALL prevent launch without indefinite loading.

#### Scenario: Process dies before picker launch
- **GIVEN** navigation intent committed but native launch did not occur
- **WHEN** the app restarts
- **THEN** the original editor is recoverable without claiming image recovery or waiting for a native result

#### Scenario: Public returns to Content Submission
- **WHEN** Public editor navigation is restored after external-picker interruption
- **THEN** Content Submission restores its durable session even when retrieval is empty or fails

#### Scenario: Same-session next launch survives old cleanup
- **GIVEN** request A is locally abandoned and B launches for the same feature/session
- **WHEN** A's cleanup or native callback arrives late
- **THEN** compare-and-clear cannot remove B's nonce and the stale callback performs no mutation or cleanup

### Requirement: Admin restoration requires the original account
Admin resume SHALL identify the original durable local session, resolve an adopted remote target, and expose private editor state only after authorization of its original account. Login SHALL preserve a recoverable same-account resume intent. A different account SHALL reach its own area without consuming or exposing the original draft.

#### Scenario: Login interruption then original account returns
- **WHEN** Admin restoration reaches login and the original account later reauthorizes
- **THEN** the original Publication Editor can resume without depending on media retrieval

#### Scenario: Auth revocation abandons an unresolved picker
- **WHEN** the original account loses authority while its native picker remains pending
- **THEN** local request/launch admission settles and late callbacks lose authority
- **AND** the exact-account navigation intent remains recoverable until authorized editor activation or explicit dismissal

#### Scenario: Different staff account logs in
- **WHEN** account B signs in while account A's resume intent exists
- **THEN** B sees only its own area, A's private work remains retained, and login does not loop or wait indefinitely

#### Scenario: Create identity was adopted before restart
- **WHEN** a saved new-editor resume intent references a session now bound to a remote ID
- **THEN** restoration resolves that exact account/session to its adopted editor instead of creating another new draft

### Requirement: Interrupted media never uploads automatically
Restoring an editor or processing a lost-data response SHALL not start upload, association, Save or Submit. Already-committed private staged files SHALL restore through their existing owner-checked storage contracts.

#### Scenario: Native result arrives after local abandonment
- **WHEN** abandoned native work later supplies lost-data or completes its original callback
- **THEN** it causes no wrong-owner staging, navigation cleanup or automatic upload

#### Scenario: Process dies with picker open
- **WHEN** process death destroys the original Dart Future while a picker is open
- **THEN** Public or authorized Admin editor restoration proceeds from durable state without recreating that Future or awaiting retrieval
- **AND** committed staged files remain intact and no Save, Submit or upload starts

#### Scenario: Existing pending Admin target resumes
- **WHEN** the editor and its staged files restore after process death
- **THEN** they remain available without remote persistence until an explicit authorized action

### Requirement: Native lifecycle acceptance distinguishes interruption kinds
Android acceptance SHALL separately verify Activity recreation and actual process death, including cancellation, delayed result and subsequent selection. Deterministic fake-picker tests SHALL not be presented as evidence of native lifecycle correctness. An observed native old-result-to-new-callback misattribution SHALL block affected live intake pending a narrowly reviewed fix.

#### Scenario: Activity recreation versus process death
- **WHEN** device verification exercises each interruption separately
- **THEN** editor restoration and future picker availability are required in both, while loss of individual uncommitted media is accepted
- **AND** no test requires exactly-once media recovery or attribution from a Dart ticket
