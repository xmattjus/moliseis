## MODIFIED Requirements

### Requirement: Durable submission attempt
Before any remote side effect begins, the system SHALL establish one submission attempt from an immutable draft and stable client identity bound at request admission, together with ordered staged-asset membership captured at the local arbitration position registered by that admission. The membership capture SHALL include mutations registered in the existing arbitration before admission and exclude registrations after it; it SHALL NOT create another queue or start persistence, claim ownership or wait for deferred command entry. Loading requests SHALL instead use their identified initialization outcome, since local mutation phases await initialization before entering arbitration. The exact captured draft SHALL be durably checkpointed before the first asset upload or final backend request. Remote work SHALL be authorized only after submission eligibility and durable ownership are established and that checkpoint succeeds. A snapshot already known to be durable SHALL not require a redundant save. This guarantee SHALL apply to direct submission as well as the existing UI transition, whose separate pre-submit checkpoint remains in force. Existing submission eligibility and feedback rules SHALL be preserved without adding accepted-terms, form, category, geolocation, description-length, or email-policy validation.

#### Scenario: Dirty direct submission checkpoints before the first asset
- **WHEN** a dirty valid draft with staged assets is submitted directly
- **THEN** the exact captured draft is durably saved before the first asset upload begins

#### Scenario: No-asset submission checkpoints before final request
- **WHEN** a dirty valid draft with no staged assets is submitted directly
- **THEN** the exact captured draft is durably saved before final submission is invoked

#### Scenario: Known durable snapshot avoids a redundant save
- **WHEN** the captured draft structurally equals the known durable checkpoint baseline
- **THEN** preparation succeeds without another draft save and may proceed to remote work

#### Scenario: Failed checkpoint prevents all remote work
- **WHEN** persistence of the captured submission snapshot fails
- **THEN** submission reports that error without starting an asset upload or final backend request, and the current identity and dirty-state relationship remain unchanged

#### Scenario: Unknown persisted ownership prevents submission
- **WHEN** durable draft ownership cannot be established during preparation
- **THEN** submission returns the retained persistence error without checkpointing a fresh identity or beginning remote work

#### Scenario: Edit before deferred entry
- **WHEN** submission is admitted for draft A with its ordered membership capture registered, and the same session is edited before action entry
- **THEN** preparation checkpoints captured A and remote work uses only that draft and the membership sealed at the admission-bound arbitration position, while a captured temporal failure does not overwrite the presentation issue of a later valid edit in the same session

#### Scenario: Initialization-bound submission
- **WHEN** submission is requested before initialization completes
- **THEN** the request uses only its bound initialization outcome, retains its admission-time provisional draft on authoritative absence, and performs no remote work for an unknown or subsequently replaced session

#### Scenario: Session rotates before preparation
- **WHEN** a request bound to A reaches preparation after clear has created B
- **THEN** it terminates as an application failure without checkpointing A, uploading assets, submitting B or reporting success


#### Scenario: Earlier staging commits before membership capture
- **GIVEN** P is the current ordered asset list and staging X has already registered its commit in local arbitration
- **WHEN** submission for draft D and identity A is admitted while X remains pending, and X then commits successfully
- **THEN** the captured list is P followed by X, uploads occur once in that order and one final request uses only D and A while the owner remains live

#### Scenario: Later staging is excluded despite deferred submission entry
- **WHEN** submission for draft D and identity A is admitted before the commit phase for Y is registered, and Y completes before preparation enters
- **THEN** the payload uses the membership sealed before Y, never includes Y, and sends D and A without recapturing current fields or assets

#### Scenario: Earlier acquisition fails before commit
- **WHEN** acquisition X registered before submission returns an application error without changing the available staged membership P
- **THEN** X is excluded, the add operation retains its own failure and submission can independently upload P and submit its admission-bound draft and identity

#### Scenario: Earlier staged path resolution fails
- **WHEN** earlier acquisition commits X but path resolution fails and leaves staged state unavailable
- **THEN** submission fails before checkpoint, Cloudinary upload or final request and does not invent a complete asset list

#### Scenario: Rotation between membership capture and preparation
- **WHEN** clear retires A after membership was captured but before submission preparation claims ownership
- **THEN** the old submission fails without checkpoint, upload or final request and the replacement session remains untouched

#### Scenario: Disposal while predecessor staging remains pending
- **WHEN** submission is admitted behind staging X and the owner disposes before X settles
- **THEN** only already-started I/O can settle, the private capture is drained without new preparation or remote work and no later public asset or submission state is published

#### Scenario: Earlier removal defines the captured list
- **WHEN** removal of P is registered before submission while Q remains and persistent removal succeeds
- **THEN** the captured list contains only Q, its upload order is preserved and no removed P entry is reintroduced into the payload

#### Scenario: Loading submission uses its initialization list
- **WHEN** submission is admitted during initialization and later mutations complete after the identified initialization outcome is sealed
- **THEN** membership remains that initialization list, draft selection follows the bound restored-or-absent rule and no later session state is adopted

#### Scenario: Earlier failed batch retains its committed prefix
- **WHEN** a batch registered before submission publishes X and then fails to acquire Z while the staged list remains available
- **THEN** captured membership includes the successfully published X in order but excludes Z, and the independent submission does not roll back X or fabricate add success

### Requirement: Finalization-only retry after success
After valid final acknowledgement while its owner remains live, the system SHALL record confirmed remote success and retain ownership of the acknowledged client identity before attempting persistence-first local retirement. Successful finalization SHALL verify that both the submission owner and the current logical session still match that acknowledged identity before any destructive work; an identity mismatch SHALL fail closed without draft clear, staged cleanup, replacement-session mutation, or additional identity rotation. A failed local retirement SHALL keep the completed session's identity owned and current and its finalization recoverable, and external clear or discard SHALL remain forbidden. Every later retry for that confirmed submission SHALL target only the same acknowledged session and perform only local finalization: it SHALL perform no new attempt preparation, draft checkpoint, asset upload, or final backend request. One successful finalization under a live owner SHALL retire that matching session exactly once, create exactly one different valid fresh client identity, clear pending finalization, and release ownership.

Disposal SHALL revoke permission to start local finalization or its next repository phase, including when acknowledgement arrives late. An already-started clear or cleanup SHALL settle without cancellation claims, later presentation commits or identity rotation. Pending acknowledgement and finalization state SHALL remain runtime-only; this capability SHALL NOT introduce background continuation or cross-owner persistence serialization.

#### Scenario: Local finalization failure does not resend
- **WHEN** final submission succeeds and one or more local clear attempts fail
- **THEN** exactly one final backend request has been sent, finalization remains recoverable, the acknowledged identity remains owned and current, and external clear or discard remains blocked

#### Scenario: Finalization-only retry rotates once
- **WHEN** a later finalization-only retry succeeds
- **THEN** no remote work is repeated, only the matching acknowledged persisted/staged session is retired through the existing policy, exactly one fresh identity becomes current, and submission ownership is released

#### Scenario: Final request failure does not enter finalization
- **WHEN** final submission returns an error or malformed acknowledgement
- **THEN** successful local session retirement does not start, submission ownership is released, and the same logical session remains retryable or explicitly discardable

#### Scenario: Identity mismatch fails closed
- **GIVEN** valid acknowledgement belongs to client identity A
- **WHEN** successful finalization observes that either the submission owner or current logical session no longer represents A
- **THEN** finalization reports failure before draft clear or staged cleanup, leaves the different current session untouched, performs no identity rotation, and does not mark acknowledged-session finalization complete

#### Scenario: Concurrent clear cannot cause a second rotation
- **WHEN** external clear is rejected while attempt A owns the session and A later completes remote acknowledgement and local finalization successfully
- **THEN** the acknowledged A session is retired once and exactly one fresh identity is created without an intermediate or second rotation

#### Scenario: Acknowledgement arrives after disposal
- **WHEN** a final request already started, the owner disposes and a valid acknowledgement arrives
- **THEN** it is retained only for private settlement, no new draft clear or staged cleanup starts, and no normal success is published

#### Scenario: Disposal during local clear
- **WHEN** local finalization already started draft clear and its owner disposes before settlement
- **THEN** that clear can settle but no subsequent staged-cleanup phase, identity rotation or ViewModel notification starts

#### Scenario: Runtime finalization failure on a live owner
- **WHEN** acknowledgement is confirmed and local finalization throws unexpectedly
- **THEN** the original runtime failure is reported, acknowledged identity remains owned and pending, and the next explicit retry performs local finalization only


### Requirement: Immediate retry availability is derived from authoritative submission state
The Content Submission presentation boundary SHALL expose retry availability as a read-only value derived from the current submission execution snapshot and confirmed-success finalization state. It SHALL NOT maintain an independently mutable retry flag. The value SHALL be false while the operation is idle, running, successful, or stopped with any ordinary failure. It SHALL be true only when the current operation is stopped with an application or handled runtime failure and confirmed remote success still requires local finalization.

#### Scenario: Idle, running, and success cannot retry
- **WHEN** the submission operation is idle, currently running, or completed successfully
- **THEN** immediate retry availability is false

#### Scenario: Ordinary failures cannot retry during this rollout
- **WHEN** the submission operation stops with any pre-acknowledgement local, upload, final-submit, malformed-response, transport, or unknown failure
- **THEN** immediate retry availability is false directly from the current Command and finalization state

#### Scenario: A new execution cannot retain stale retryability
- **WHEN** a finalization retry starts and the submission Command clears its previous result while entering the running state
- **THEN** immediate retry availability becomes false without synchronizing or clearing a second mutable flag

#### Scenario: Failed finalization remains immediately retryable
- **WHEN** remote success is confirmed, local finalization fails, and the submission operation is no longer running
- **THEN** immediate retry availability is true and executing the existing action invokes only identity-bound local finalization

#### Scenario: Handled runtime finalization failure permits local retry
- **WHEN** confirmed remote success remains pending and the current stopped execution has a handled runtime failure
- **THEN** retry availability is true without converting that failure into a domain Result or sending remote work again
