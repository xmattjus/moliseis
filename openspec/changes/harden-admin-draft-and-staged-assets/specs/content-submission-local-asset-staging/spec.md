## MODIFIED Requirements

### Requirement: Android lost data is acquired early and processed after restoration
On Android, one shared startup recovery owner SHALL acquire lost data before editor-route dependency and retain attributed committed inbox items until matching restoration. Feature recovery requests SHALL await that shared attempt and their initialization before serialized candidate processing. Empty/error responses SHALL remain best-effort diagnostics. No recovered file SHALL be assigned to an absent, unknown, retired or different session; valid existing staged work SHALL remain unchanged by rejected recovery.

#### Scenario: Production startup ordering waits after retrieval
- **GIVEN** the shared startup acquisition and a matching ViewModel initialization start without being awaited
- **AND** the screen requests recovery through the shared owner
- **WHEN** the lost-data API returns media before persisted draft and staged-state restoration complete
- **THEN** verified response bytes SHALL be retained in the ticket-owned inbox without feature staging
- **AND** processing SHALL begin only after initialization/reconciliation completes
- **AND** recovered media SHALL be owned by the restored draft identity

#### Scenario: Recovery deduplicates against restored assets
- **GIVEN** initialization restores a staged asset
- **AND** Android recovery returns identical content
- **WHEN** deferred recovery processing runs
- **THEN** it SHALL calculate the same digest through the common pipeline
- **AND** it SHALL create no duplicate file, descriptor, or runtime asset

#### Scenario: Clear makes a deferred recovery response stale
- **GIVEN** initialization restored draft A and Android recovery retained a response for A
- **WHEN** clear rotates the active session to draft B before recovered-file processing enters lifecycle arbitration
- **THEN** recovery SHALL compare its durable ticket and captured eligible identity with B, invalidate delivery and discard the response for feature processing
- **AND** no recovered file SHALL be attached to either session and only that retired ticket's inbox residue is eligible for cleanup

#### Scenario: Recovery honors restored capacity and size limits
- **GIVEN** restored staged assets already consume some or all available capacity
- **WHEN** Android returns recovered media including oversized or excess candidates
- **THEN** the existing maximum-five and file-size rules SHALL be calculated against restored runtime state
- **AND** valid staged assets SHALL remain unchanged by rejected recovery candidates

#### Scenario: Recovery consumes only remaining restored capacity
- **GIVEN** four valid staged assets were restored in explicit order
- **AND** Android returns multiple candidates including a duplicate or oversized file
- **WHEN** recovery processes the candidates
- **THEN** at most one new valid non-duplicate under-limit candidate SHALL commit
- **AND** the four restored assets SHALL retain their paths, digests, and order
- **AND** every remaining recovered candidate SHALL leave existing staged state unchanged

#### Scenario: No durable recovered session prevents reassociation
- **GIVEN** initialization returns no valid persisted draft or cannot restore one safely
- **WHEN** an early lost-data response contains files from an interrupted picker interaction
- **THEN** those files SHALL NOT be staged for the unrelated fresh in-memory identity; an ownership read failure SHALL quarantine already-committed inbox bytes for retry
- **AND** a draft-load failure SHALL preserve existing staged ownership rather than treating it as orphan state

#### Scenario: Recovered candidate-processing failure is observable but non-blocking
- **GIVEN** initialization restored a valid draft and staged assets
- **AND** Android lost-data retrieval returns a candidate successfully
- **WHEN** serialized candidate processing returns `Result.error`
- **THEN** recovery SHALL record the failure through its recovery diagnostic path without throwing to the caller and retain unacknowledged committed inbox work for the same valid owner
- **AND** already-valid staged descriptors, files, and runtime assets SHALL remain unchanged

#### Scenario: Non-Android and empty recovery remain no-ops
- **GIVEN** the current platform is not Android or the Android response is empty
- **WHEN** recovery is triggered
- **THEN** it SHALL complete without changing staged or runtime assets

#### Scenario: Thrown Android recovery still initializes
- **GIVEN** no caller previously started initialization
- **AND** the Android lost-data platform call throws
- **WHEN** recovery completes non-actionably
- **THEN** the requesting feature SHALL start and await its shared draft initialization, with staged reconciliation only when ownership permits it
- **AND** the shared initialization future SHALL complete with `loadState == ready`
- **AND** no recovered or valid existing staged asset SHALL be mutated

### Requirement: Recovery eligibility cannot migrate between sessions
Android recovery SHALL bind a durable pre-picker ownership ticket before retrieval and verify the matching initialization outcome before feature processing. Media processing SHALL await exact restored identity, never absent, unknown or replacement state. Clear, retirement, owner disposal or explicit revocation SHALL invalidate later feature commits. Platform retrieval errors remain best-effort; non-Android requests SHALL perform no retrieval. Startup acquisition SHALL not depend on an editor route.

#### Scenario: Recovery response arrives after clear
- **WHEN** recovery is admitted for initialization A, clear creates B and lost media arrives afterward
- **THEN** neither A nor B gains staged media from that response

#### Scenario: Response precedes initialization
- **WHEN** lost media arrives before the bound initialization completes
- **THEN** processing waits for that initialization's eligible restored identity and cannot adopt an absent, unknown or replacement session

#### Scenario: Capacity and deduplication stay shared
- **WHEN** recovery and normal addition supply overlapping or excessive media
- **THEN** their local commits are serialized through the existing boundary and preserve shared size, digest and capacity rules

## ADDED Requirements

### Requirement: Public and Admin share one startup lost-data acquisition
The system SHALL make exactly one Android platform retrieval attempt per process startup recovery lifecycle through one authoritative shared consumer. Concurrent feature requests SHALL share its outcome, including empty/error outcomes. Acquisition SHALL begin without opening either editor and without waiting for authentication. Non-Android startup SHALL perform no platform retrieval.

#### Scenario: Concurrent recovery consumers
- **WHEN** startup, Public and Admin concurrently request lost-data recovery
- **THEN** one Android platform attempt occurs and all callers observe that same attempt
- **AND** route remounts or app resumes do not trigger extra platform attempts

#### Scenario: Startup has no editor route
- **WHEN** the application starts on Home with recoverable picker data
- **THEN** retrieval and eligible private inbox acquisition begin without opening the original editor

#### Scenario: Retrieval is empty or throws
- **WHEN** startup retrieval returns empty data or an expected platform exception
- **THEN** no second retrieval attempt occurs in that startup lifecycle
- **AND** existing drafts/assets/inbox commits remain intact and feature initialization can complete normally

#### Scenario: Retrieval throws before native consumption
- **WHEN** startup retrieval throws while old native media may still exist
- **THEN** new picker launches are refused for that startup without overwriting the old ticket
- **AND** existing committed inbox work may still be delivered to its verified owner

#### Scenario: Empty retrieval with a surviving ticket
- **WHEN** startup returns empty while a durable old picker ticket is still outstanding
- **THEN** its lease remains unresolved and no replacement ticket or picker launch is admitted
- **AND** a delayed old response cannot be attributed to another session

#### Scenario: Lost cancellation has no provable terminal result
- **WHEN** the original cancellation callback was lost and subsequent startups return empty
- **THEN** the old ticket remains unresolved rather than being treated as cancellation
- **AND** further picker launches remain blocked until attributable settlement; this availability limitation is reported explicitly

#### Scenario: Non-Android startup
- **WHEN** the application starts on iOS, macOS or another non-Android platform
- **THEN** retrieval is not called and normal picker/cancel behavior remains available
- **AND** old launch tickets from another process are invalidated without delivering media or introducing Android unresolved-cache blocking

### Requirement: Every picker launch records durable feature and session ownership
Public and Admin picker launches SHALL await startup acquisition and durably record one operation ticket after establishing feature draft ownership. The ticket SHALL bind feature, session and Admin account when applicable. Only one platform interaction SHALL own the shared lease at a time. Failure to establish ownership SHALL prevent launch.

#### Scenario: Public picker opens with a durable owner
- **WHEN** Public finishes its required checkpoint and ticket commit
- **THEN** the picker launches for that exact Public identity and no Admin route can claim its result

#### Scenario: Admin picker opens with a durable owner
- **WHEN** an authorized persisted Admin editor finishes its checkpoint and ticket commit
- **THEN** the picker launches for that exact account/session/remote target

#### Scenario: Checkpoint or ticket write fails
- **WHEN** either required durable boundary fails
- **THEN** no picker launches and previous fields/assets remain unchanged

#### Scenario: Lease cannot be overwritten
- **WHEN** another feature requests a picker while the first picker is physically pending
- **THEN** the second launch is refused without replacing the original ticket

#### Scenario: Cancellation releases only its operation
- **WHEN** a normal picker returns cancellation to its still-current ticket
- **THEN** that ticket is settled and its lease released without asset mutation or generic failure

#### Scenario: Revocation while picker remains open
- **WHEN** clear, session retirement or explicit Admin auth revocation invalidates a pending owner
- **THEN** its later result cannot create feature staged assets or remote work
- **AND** another launch cannot reuse that physical interaction's ticket before settlement

#### Scenario: Crash between ticket commit and launch
- **WHEN** successful startup acquisition has no unresolved former interaction and the process stops after a new ticket commit but before launch
- **THEN** a later startup cannot attribute any older undrained result to that new ticket
- **AND** an empty response with that surviving ticket remains unresolved rather than proving launch never happened

### Requirement: Recovery bytes have a durable bounded handoff
Valid attributed retrieval results SHALL be copied promptly into a private ticket-owned inbox before delivery waits on authentication or editor initialization. Only committed validated inbox descriptors SHALL authorize later handoff. Each ticket SHALL bound candidates to five files and the existing per-file maximum. Uncommitted files SHALL NOT be reconstructed; previously committed items SHALL survive later acquisition failure.

#### Scenario: Auth restoration is delayed
- **WHEN** Admin data is retrieved before authentication is available
- **THEN** eligible validated bytes commit to the original ticket's private inbox without upload or feature reassignment
- **AND** they remain available after service recreation

#### Scenario: Partial acquisition fails
- **WHEN** one inbox file commits and copying the next file fails
- **THEN** the first committed item survives and the second is not exposed as committed

#### Scenario: Inbox contains missing corrupted or linked bytes
- **WHEN** inbox validation finds a broken, oversized, digest-mismatched or symlinked entry
- **THEN** it is not delivered and no outside file is followed
- **AND** valid committed siblings remain eligible

#### Scenario: Native recovery order is unavailable
- **WHEN** Android returns paths without trustworthy original selection order
- **THEN** recovery assigns deterministic content-based order and does not claim original selection order
- **AND** normal live selection and existing staged descriptor ordering remain unchanged

### Requirement: Handoff is verified against exact feature session and account
Inbox delivery SHALL require the exact durable feature/session and Admin account/privilege when applicable. Unknown ownership SHALL quarantine committed data; authoritative retirement SHALL invalidate it. Another active account or feature SHALL never receive the media. Matching reactivation SHALL be explicit for Admin and SHALL not itself replay remote image actions.

#### Scenario: Public result arrives while Admin is active
- **WHEN** a Public ticket's result is acquired while an Admin editor is visible
- **THEN** only its matching restored Public draft can consume it through Public staging
- **AND** no Admin attachment or remote action occurs

#### Scenario: Admin result arrives while Public is active
- **WHEN** an Admin ticket's result is acquired while Public is visible
- **THEN** Public receives no media and only explicit matching authorized Admin activation can consume committed inbox data

#### Scenario: Different account becomes active
- **WHEN** account B logs in while account A owns committed recovery bytes
- **THEN** B cannot see or consume A's bytes and A's committed data is retained privately

#### Scenario: Live logout invalidates pending result
- **WHEN** A explicitly logs out or loses privilege before its pending picker response commits
- **THEN** later response bytes are rejected for feature attachment
- **AND** already committed inbox work requires explicit matching reauthorization rather than automatic replay

#### Scenario: Ownership read fails
- **WHEN** a draft or ownership record cannot be read reliably
- **THEN** no fresh identity receives the data and no broad orphan cleanup is authorized

#### Scenario: Unsupported legacy plugin result has no ticket
- **WHEN** retrieval returns bytes without a trustworthy durable ticket from the owning feature
- **THEN** they are not attached to any draft and only a path-free non-actionable diagnostic is emitted

### Requirement: Inbox acknowledgement follows idempotent feature commit
The system SHALL acknowledge an inbox item only after matching feature staging commits or a deliberate validated rejection is recorded. Interrupted acknowledgement SHALL permit replay only to the same owner, with content deduplication preventing duplicate staged assets. Recovery SHALL never automatically invoke Admin upload or association.

#### Scenario: Crash after feature commit before acknowledgement
- **WHEN** feature staging commits and the process stops before inbox acknowledgement
- **THEN** replay targets only that owner, produces no duplicate staged asset and can acknowledge the existing commit

#### Scenario: Acknowledgement fails
- **WHEN** inbox acknowledgement fails after successful staging
- **THEN** the staged item remains valid and unacknowledged committed inbox work remains safely retryable

#### Scenario: Removal waits for pending startup acquisition
- **WHEN** an asset is restored while startup is still copying identical recovered bytes and removal is requested
- **THEN** removal waits for acquisition completion outside feature arbitration before rejecting matching inbox references and deleting its descriptor
- **AND** later delivery cannot resurrect that removed asset

#### Scenario: Explicit removal after acknowledgement failure
- **WHEN** a recovered asset was staged, inbox acknowledgement failed, and the user removes that asset
- **THEN** removal first terminally rejects its existing same-owner inbox references before deleting the feature descriptor
- **AND** restart or retry cannot resurrect the removed asset

#### Scenario: Removal overtakes a captured delivery
- **WHEN** delivery captured an inbox item but removal terminally rejects it before delivery enters feature arbitration
- **THEN** delivery rechecks its pending state inside arbitration and commits no new staged asset

#### Scenario: Removal cannot record terminal inbox rejection
- **WHEN** an asset removal cannot persist rejection of its pending inbox references
- **THEN** it reports failure without deleting the feature descriptor or publishing removal

#### Scenario: Stage fails before commit
- **WHEN** feature staging fails before descriptor commit
- **THEN** the inbox item is not acknowledged as delivered and earlier valid feature work remains intact

#### Scenario: Admin pending picker was interrupted
- **WHEN** recovery hands media to the matching existing pending Admin session
- **THEN** it becomes local staged recovery work without automatic upload/association
- **AND** normal live persisted picker behavior remains immediate

### Requirement: Native consumption does not imply crash-safe exactly-once delivery
One retrieval attempt SHALL NOT be represented as guaranteed or exactly-once recovery. The system SHALL preserve committed inbox items, but acknowledge that native cache consumption before durable inbox commit can lose uncommitted media. Neither arbitrary native paths nor descriptor-less private files SHALL be used to fabricate successful handoff after interruption.

#### Scenario: Process dies after native consumption before durable copy
- **WHEN** Android has consumed its cached response and the process stops before an inbox item commits
- **THEN** that item's loss is an accepted documented limitation
- **AND** no implementation or test result claims guaranteed recovery of those bytes

#### Scenario: Process dies after inbox commit
- **WHEN** a validated inbox descriptor/file pair committed before process death
- **THEN** the next startup may deliver it to the same verified owner without relying on native cache replay

#### Scenario: Ordinary final rename has no descriptor
- **WHEN** feature staging or inbox final rename completes without a descriptor commit
- **THEN** that file remains uncommitted and is cleaned best-effort rather than reconstructed
