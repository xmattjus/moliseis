# Admin Editor Picker Restoration Delta

## Purpose

Restore the account-owned Admin editor independently of interrupted media while preserving captured live-request authority and leaving Public Content Submission unchanged.

## ADDED Requirements

### Requirement: Public remains an unchanged dependency
Plan 2 SHALL preserve Public production code, initialization, picker/recovery, successful eligible lost-media staging, persistence, navigation and submission behavior. Existing regression tests and expectations SHALL remain unchanged. Public canonical specs SHALL remain authoritative. Admin integration SHALL not intercept Public retrieval, add a shared recovery gateway or introduce universal discard.

#### Scenario: Existing Public recovery remains supported
- **WHEN** the existing Public recovery suites run after Admin integration
- **THEN** recovers a single lost file and acquires lost media early and stages it after draft restoration pass with unchanged assertions
- **AND** Public draft/staging/submit/progress/lifecycle regressions remain supported without changing their expectations

### Requirement: Admin retains the pinned picker integration
Admin SHALL continue using the pinned image_picker gallery selection mechanism. New-target images SHALL enter exact-owner private staging; eligible persisted pending submissions SHALL retain immediate add behavior. No second picker dependency, native fork/channel or global media framework SHALL be introduced.

#### Scenario: Valid normal Admin selection
- **GIVEN** the exact account/session/activation is authorized and durably checkpointed before launch
- **WHEN** its gallery picker returns an eligible image under the original live request
- **THEN** new-target intake stages privately or persisted pending intake follows the existing immediate path
- **AND** subsequent phases recheck captured authority

### Requirement: Normal Admin resume preserves original request authority
An ordinary resumed or background lifecycle transition SHALL NOT invalidate a pending Admin picker request. While captured account/session/activation and request nonce remain valid, any image, cancellation or error completion SHALL be processed normally even if resume happened first. Same-activation rebuilds SHALL not abandon it.

#### Scenario: Resume precedes valid image completion
- **WHEN** a valid Admin request resumes before its original Future returns an image
- **THEN** the eligible image is accepted through ordinary owner-checked intake

#### Scenario: Resume precedes cancellation completion
- **WHEN** a valid Admin request resumes before its Future returns cancellation
- **THEN** cancellation settles without an asset and a later selection can be admitted

#### Scenario: Resume precedes error completion
- **WHEN** a valid Admin request resumes before its Future returns an error
- **THEN** the existing error path settles the action without a permanent application picker reservation

### Requirement: Admin abandonment requires revocation or explicit intent
Local Admin abandonment SHALL require actual account/session/activation revocation or an explicit request-bound user action. It SHALL revoke publication before settling its local await and releasing only its own admission. Resume, elapsed time or presumed Activity loss SHALL not suffice. Local abandonment SHALL not claim native cancellation or automatically relaunch a picker.

#### Scenario: Activity recreation strands the original Future
- **GIVEN** the Dart owner survives but its native picker Future never completes
- **WHEN** the authorized user activates Admin Interrompi selezione for that nonce
- **THEN** the local await and add action settle as interrupted without awaiting native completion
- **AND** editor/checkpoint/navigation access remains usable and the existing Add control permits separate explicit selection after settlement

#### Scenario: Reconstruction genuinely replaces authority
- **WHEN** route/editor reconstruction establishes A2 after revoking A1
- **THEN** A1 loses authority and cannot publish into A2
- **AND** an ordinary rebuild retaining the same activation does not trigger abandonment

#### Scenario: Abandoned A completes after B starts
- **WHEN** A's original Future returns media or error after A was abandoned and B admitted
- **THEN** A cannot stage/upload, publish into B, release B's reservation or clear B's navigation nonce

#### Scenario: A1 cannot revive after A to B to A
- **WHEN** A1 is revoked, B activates, A2 activates and A1 completes late
- **THEN** captured activation/nonce guards reject A1 despite equal account/session/target

### Requirement: Pending Admin selection has a bounded explicit escape
The current authorized Admin editor SHALL expose Interrompi selezione while its picker await is pending. It SHALL remain callable while add runs, preserve fields/files/resume intent and settle only the captured request. This control SHALL NOT be added to Public or require a second command architecture, timer, recovery coordinator or native acknowledgement.

#### Scenario: Repeated interruption and next selection
- **WHEN** Admin selections are interrupted and explicitly abandoned repeatedly
- **THEN** each application admission can settle without its native Future and a later valid explicit request can complete normally
- **AND** no permanent editor loading state or application-owned picker lockout remains

#### Scenario: Native state still reports already active
- **WHEN** native selection rejects a later explicit request as already_active
- **THEN** the action settles with editor access and later explicit retry available
- **AND** the application neither spins nor claims native cancellation

### Requirement: Admin navigation intent is independent of media provenance
Before Admin external picking, the editor SHALL checkpoint and persist its account/session/target and request nonce for navigation only. Matching cleanup SHALL compare-and-clear only that nonce. Revocation or local abandon SHALL retain resume intent through interruption. Intent SHALL not identify native media, consume cache, gate Public or authorize discarding any Public result.

#### Scenario: Intent commits before death and before launch
- **WHEN** the process dies after Admin intent persistence but before native launch
- **THEN** the same-account editor is recoverable without inferring that a picker started or media exists

#### Scenario: Old cleanup follows a same-session next launch
- **WHEN** B replaces A's navigation nonce and A's cleanup completes late
- **THEN** B's intent remains and A cannot clean up or release B's request

### Requirement: Admin restoration requires original account and session
Admin restoration SHALL resolve the exact durable local session, adopted remote target and committed staged files independently of media availability. Login SHALL preserve the original-account resume intent; another account SHALL not view or consume that work. Missing or interrupted media SHALL not block activation, loading, checkpointing or later explicit selection.

#### Scenario: Login then original account resumes
- **WHEN** restoration reaches login and the original account reauthorizes
- **THEN** its Publication Editor resumes without waiting for media retrieval

#### Scenario: Different account authenticates
- **WHEN** B authenticates while A's Admin resume intent exists
- **THEN** B reaches only its own area and A's private work remains recoverable without a redirect loop

#### Scenario: Adopted new-editor identity restores
- **WHEN** an old new-editor hint references a session already bound to a remote ID
- **THEN** account/session lookup restores that adopted editor without creating another new draft

#### Scenario: Activity recreation and process death
- **WHEN** either interruption reconstructs an Admin editor
- **THEN** its durable checkpoint and valid committed files restore under correct account authority
- **AND** process death does not reconstruct the original native Future or run Save automatically

### Requirement: Admin restoration performs no unattributed media recovery
Admin SHALL NOT call retrieveLostData, drain shared cache or upload/associate unattributed lost media. Restoration SHALL not start Save, upload or remote mutation. Public's existing retrieval SHALL remain untouched; this Admin contract SHALL not claim native cross-feature provenance or complete cache isolation.

#### Scenario: Interrupted Admin media is unavailable
- **WHEN** Admin restores after picker interruption without a valid live result
- **THEN** the editor and committed staged files remain usable without recovering that individual image or starting remote persistence

### Requirement: Native acceptance is scoped to new Admin behavior
Android verification SHALL distinguish Activity recreation from actual process death and exercise normal/late/cancel/error callbacks and subsequent explicit selection. Fake-picker tests SHALL not prove native ordering. New demonstrated regressions SHALL be addressed specifically; acceptance SHALL NOT require eliminating the accepted pre-existing shared-cache attribution limitation or rewriting Public behavior.

#### Scenario: Device verification scope
- **WHEN** Android acceptance runs for newly introduced Admin lifecycle/restoration paths
- **THEN** it verifies captured continuation safety, same-account restoration and no permanent application admission lock
- **AND** it does not assert that the plugin's shared cache can never expose Admin-origin lost media to existing Public recovery
