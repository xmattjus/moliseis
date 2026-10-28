# admin-submission-editor Specification

## Purpose

Provide one account-owned durable Admin editing session with continuous Save, recoverable staged progress and navigation that observes admitted work.

## Requirements

### Requirement: One active editor survives page changes
The application SHALL own one active Admin editing session shared by editor and progress presentations. Normal target changes SHALL refuse uncheckpointed or unsettled work without replacing it. Same-target reconstruction SHALL reuse initialization and session state. Local checkpointing SHALL accept incomplete fields without remote Save.

#### Scenario: Replacement would abandon work
- **GIVEN** A contains uncheckpointed fields or an admitted mutation
- **WHEN** navigation requests target B
- **THEN** A remains active and unchanged, and the request settles as refused with access back to A
- **AND** no implicit checkpoint, remote request or second editor is created

#### Scenario: Checkpoint then switch
- **GIVEN** A has incomplete editable values
- **WHEN** the user explicitly checkpoints A and later switches after settlement
- **THEN** A restores losslessly when reopened and B receives independent authority

### Requirement: Account and activation authority guard every effect
Revocation SHALL immediately hide private editor state and prevent new remote phases or stale publication. Callbacks and effects SHALL retain their original account/session/target/activation authority. Already-sent HTTP MAY complete, but SHALL NOT mutate a replacement session. A physical operation reservation SHALL release only on its own settlement.

#### Scenario: Account A to B
- **WHEN** A's operation completes after revocation and activation of B
- **THEN** B receives none of A's fields, assets, errors, navigation effects or successful status
- **AND** captured durable commits remain recoverable only for A

#### Scenario: Session A1 to B to A2
- **WHEN** a setter, dialog, load, picker or command from A1 completes after A2 activates
- **THEN** equal target or session identifiers do not restore A1 publication authority

### Requirement: Remote hydration preserves local intent
Restoration and fresh detail loading SHALL keep physical durability, effective local baseline and confirmed remote state distinct. Hydration SHALL not erase typing or checkpointed unconfirmed edits. Incompatible or failed loading SHALL settle as unavailable/conflicting while preserving work and permitting return or explicit reload.

#### Scenario: Typing during restore or hydration
- **GIVEN** a remote request was admitted before local edit B
- **WHEN** that request completes
- **THEN** B is not replaced, and stale success/failure cannot authorize a newer activation

#### Scenario: Checkpointed unconfirmed edit
- **GIVEN** local checkpoint A differs from its recorded remote baseline
- **WHEN** incompatible fresh remote B arrives
- **THEN** A remains intact even if locally checkpoint-clean and remote mutation stays unavailable until compatible authority exists

### Requirement: Save confirms only captured work
Save SHALL capture immutable fields and ordered staged identities at admission, checkpoint the attempt, persist remotely, adopt Create identity, then persist remaining staged assets in order. Later fields/checkpoints or uncaptured staged items SHALL remain pending. All remote calls SHALL execute outside local persistence arbitration.

#### Scenario: Checkpoint A settles after typing B
- **WHEN** A's checkpoint or remote confirmation finishes while C contains B
- **THEN** A alone is confirmed and B remains current and remotely unconfirmed
- **AND** a newer physical checkpoint B is not overwritten with A

#### Scenario: First Save followed by Save
- **GIVEN** new local UUID A has no remote ID
- **WHEN** Create and local adoption succeed and the user later Saves again
- **THEN** the same logical session uses Update for the authoritative ID and never issues a second Create

### Requirement: Staged Save preserves monotonic confirmed progress
New submissions SHALL permit local selection, preview and exact-identity removal before Create. Save SHALL preserve separate local bytes, confirmed upload and confirmed association facts. Retry SHALL skip confirmed work and retain failed/unstarted files. Moderation SHALL remain unavailable while fields, staged work or remote outcomes remain unconfirmed.

#### Scenario: Second image upload fails
- **GIVEN** first association and second upload receipt are confirmed but later work fails
- **WHEN** retry is explicitly admitted
- **THEN** confirmed association is not uploaded or inserted again, and confirmed second upload is reused
- **AND** unstarted files retain deterministic order

#### Scenario: Association reply is lost
- **WHEN** database association may have committed but its response is unavailable
- **THEN** the upload receipt and local file remain available and retry uses association replay rather than another upload

#### Scenario: Existing pending submission receives a new image
- **WHEN** a normal live picker returns for an already-persisted pending submission
- **THEN** its existing immediate upload/association behavior remains available with existing size/status/capacity protections
- **AND** interrupted-media restoration never starts that upload automatically

### Requirement: Save progress observes admitted work
Save SHALL be admitted synchronously before progress navigation. The progress route SHALL only observe the shared session/attempt and SHALL NOT start or repeat commands from initialization, build or restoration. Running work SHALL block ordinary Back paths while auth revocation remains effective.

#### Scenario: Route rebuild or reconstruction
- **WHEN** progress rebuilds or is reconstructed without a matching live attempt
- **THEN** no Save is issued and an interrupted presentation permits return to the exact editor session

#### Scenario: Cold progress restoration for an adopted new session
- **GIVEN** restorable route metadata identifies the original local session UUID
- **WHEN** progress/editor routes reconstruct after Create adoption
- **THEN** account-checked local lookup restores the adopted session without allocating a fresh new owner or invoking Save

#### Scenario: Repeated Save tap
- **WHEN** a Save is already admitted or physically settling
- **THEN** another tap cannot admit or navigate for a second execution

### Requirement: Terminal Save states remain usable and honest
Progress SHALL distinguish completed, partial, recoverable failure, unknown remote outcome and unexpected failure. Every terminal state SHALL allow return to the same editor. Retry SHALL require matching presentation authority and a safe phase policy; ambiguous Update SHALL use explicit read-back rather than blind resend.

#### Scenario: Unknown Update
- **WHEN** Update response is lost
- **THEN** the editor retains local fields and progress offers return/read-back without claiming failure or success
- **AND** equality confirms observed fields and further writes remain conditional on the exact server token, while different/missing/moderated remote state follows the guarded recovery branches below

#### Scenario: Local adoption or receipt persistence fails
- **WHEN** remote work is confirmed but local metadata is not committed
- **THEN** progress reports partial/local repair, preserves confirmed evidence and does not repeat confirmed remote work solely to clean up

### Requirement: Successful Save preserves the open editor
Save success SHALL keep the editor open, adopt authoritative identity/status without erasing newer fields or known assets, and invalidate obsolete moderation confirmations. Other moderation operations SHALL retain their existing protections and SHALL NOT be moved into Save Progress.

#### Scenario: Save completes with a status dialog open
- **WHEN** the admitted Save settles
- **THEN** it neither closes the editor nor executes the old confirmation
- **AND** a fresh confirmation is required under current revision/authority

#### Scenario: Update response omits associations
- **WHEN** a field Update succeeds with an incomplete asset envelope
- **THEN** known confirmed associations are preserved until a complete authoritative asset refresh replaces them

### Requirement: Dashboard refresh does not depend on Save pop result
Returning from either editor entry route SHALL refresh the current authorized dashboard regardless of a boolean result. Progress return to the editor SHALL not be treated as editor exit.

#### Scenario: Save remains open then user returns
- **WHEN** an administrator Saves and later leaves the editor normally
- **THEN** the current dashboard reloads even without a true route result

#### Scenario: Untouched editor exits
- **WHEN** an editor returns without changing remote content
- **THEN** the same harmless dashboard refresh occurs subject to owner/account/mounted checks

### Requirement: Unresolved Update recovery distinguishes version and projection
Read-back SHALL compare captured A/V with the authoritative row. Compatible pending A SHALL confirm only its observed row/token. A compatible pending row still at V SHALL permit explicit original A/V retry through the existing Save Command. Other outcomes SHALL follow the scenarios below without borrowing a fresh token or inferring old HTTP settlement. All branches SHALL preserve newer C/P.

#### Scenario: Intent committed before dispatch and remote remains V
- **GIVEN** durable Update A/V and newer local checkpoint B survive process death
- **WHEN** explicit read-back observes the compatible pending row at V with fields different from A
- **THEN** the editor/progress offers explicit original A/V continuation, leaving B untouched
- **AND** initialization, route reconstruction and read-back perform no Update

#### Scenario: Original A and retry race
- **WHEN** explicit original A/V retry races the old request
- **THEN** the existing exact-token predicate fences a later incompatible write
- **AND** token rejection requires read-back again rather than blind retry, fresh-token substitution or presumed success

#### Scenario: Newer remote fields have another token
- **WHEN** read-back returns fields other than A at a different exact token
- **THEN** local work remains and the obsolete intent is locally settled as conflict
- **AND** no immediate Save using the historical token or automatic overwrite with the new token is allowed

#### Scenario: Read-back cannot establish a compatible pending row
- **WHEN** the row is missing, finalized, provenance-incompatible, or cannot be read
- **THEN** no remote mutation is admitted and local work is retained
- **AND** a read failure retains the unresolved intent rather than proving non-application
