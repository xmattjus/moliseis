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
Media whose native feature/session attribution is uncertain SHALL never be attached by guessing. With the pinned uncorrelated lost-data API, all lost-data candidates SHALL be discarded even if a persisted navigation intent or only one draft exists. A live callback SHALL require its captured valid account/session/activation and uninterrupted request authority before intake.

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
- **WHEN** retrieval returns empty, throws, or finishes after editor restoration
- **THEN** editor access and later explicit picker requests remain usable without a recovery warning for unknown empty cause

#### Scenario: Delayed result and repeated restarts
- **WHEN** an old result appears after an empty retrieval or a later process retrieves again
- **THEN** it is not assigned to a current feature and no persistent pending ticket prevents new requests

#### Scenario: Normal picker cancellation
- **WHEN** a valid live request returns cancellation
- **THEN** no asset is reported recovered, its own launch/navigation intent settles, and another normal selection can be admitted

#### Scenario: Activity detach leaves native callback unresolved
- **GIVEN** the Dart engine survives but native picker Future never completes
- **WHEN** interruption/reconstruction or return to resumed abandons that local request
- **THEN** the feature action and launch lease settle locally, the old callback loses authority, and later explicit selection remains available
- **AND** a late old callback is discarded rather than assigned to a replacement request

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

#### Scenario: Existing pending Admin target resumes
- **WHEN** the editor and its staged files restore after process death
- **THEN** they remain available without remote persistence until an explicit authorized action

### Requirement: Native lifecycle acceptance distinguishes interruption kinds
Android acceptance SHALL separately verify Activity recreation and actual process death, including cancellation, delayed result and subsequent selection. Deterministic fake-picker tests SHALL not be presented as evidence of native lifecycle correctness. An observed native old-result-to-new-callback misattribution SHALL block affected live intake pending a narrowly reviewed fix.

#### Scenario: Activity recreation versus process death
- **WHEN** device verification exercises each interruption separately
- **THEN** editor restoration and future picker availability are required in both, while loss of individual uncommitted media is accepted
- **AND** no test requires exactly-once media recovery or attribution from a Dart ticket
