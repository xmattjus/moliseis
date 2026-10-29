# Admin draft persistence delta

## ADDED Requirements

### Requirement: Explicit reconciliation preserves baseline distinctions
Existing protected hydration SHALL be extended with explicit current-observation reconciliation. Accepting remote SHALL set current/effective/remote to observed fields while leaving physical checkpoint unchanged. Preserving local SHALL leave current/effective/physical unchanged and set remote baseline to the observation. Neither transition SHALL persist, retire an owner or confirm a remote Save.

#### Scenario: Accept remote while a different local checkpoint exists
- **GIVEN** current C, effective E and physical checkpoint P preserve local work
- **WHEN** an authorized explicit choice accepts remote B
- **THEN** current and effective become B, remote baseline becomes B, physical P and its recorded metadata remain unchanged, and local field dirtiness is false
- **AND** staged identities, receipts, bytes, navigation metadata and owner remain unchanged

#### Scenario: Keep checkpoint-clean but remotely unconfirmed local fields
- **GIVEN** C equals E and physical local L but differs from observed pending remote B
- **WHEN** an authorized explicit choice preserves local fields
- **THEN** C, E and P remain L while remote baseline becomes B
- **AND** local field dirtiness remains false but remote field confirmation remains outstanding

#### Scenario: Keep uncheckpointed incomplete local fields
- **GIVEN** C contains invalid raw coordinate text, unresolved event dates or incomplete fields and C differs from E
- **WHEN** the user explicitly preserves C against compatible pending observation B
- **THEN** C and its dirtiness remain exact and the later Save still requires ordinary validation
- **AND** no normalization, implicit checkpoint or synthetic remote field confirmation occurs

### Requirement: Reconciliation requires exact serialized local authority
The local reconciliation boundary SHALL validate captured account/session/target/activation, latest observation and local field revision within existing local ordering. Pending field intent or settlement and conflicting work SHALL block reconciliation. Failed or obsolete choices SHALL change none of current/effective/physical/remote baselines, readiness, capacity, assets or persistence.

#### Scenario: An unresolved field intent exists
- **WHEN** a field choice attempts to use another token while an original intent remains durable
- **THEN** it is refused and the original intent plus all local snapshots and receipts remain unchanged

#### Scenario: Local edit arrives before queued choice publication
- **WHEN** a captured choice waits behind checkpoint work and C changes before that choice reaches its local publication boundary
- **THEN** the choice is obsolete and cannot replace the newer fields or reset the successful physical checkpoint

#### Scenario: Revocation during an already-started durable write
- **WHEN** a checkpoint starts for A and authorization changes before it completes
- **THEN** it can commit only to A's captured owner and cannot authorize or publish a recovery choice into B or A2
- **AND** its physical settlement does not release another operation's reservation

### Requirement: Reconciliation durability follows ordinary checkpoint semantics
Runtime reconciliation SHALL not rewrite P. Explicit Accept whose chosen fields/R are not physically represented SHALL establish an activation-owned checkpoint obligation that refuses ordinary target replacement. Only matching successful checkpoint proof SHALL release it. Ordinary hydration SHALL establish no obligation. Explicit checkpoints SHALL retain existing capture/ownership guarantees; restart SHALL restore P and require fresh authority.

#### Scenario: Restart before persisting accepted remote fields
- **GIVEN** P stores local A with its original remote baseline and the user accepts remote B without checkpointing
- **WHEN** the real store reopens
- **THEN** A and its recorded baseline restore, not B, and no runtime acceptance or token authority is invented

#### Scenario: Explicit checkpoint after local preservation
- **GIVEN** current L is retained against observed remote B
- **WHEN** an explicit checkpoint succeeds and the real store reopens
- **THEN** exact L restores with recorded remote B and the same owner/receipts/files
- **AND** B remains historical evidence requiring a fresh read before remote authority

#### Scenario: Checkpoint fails after remote acceptance
- **WHEN** explicit persistence of accepted B fails
- **THEN** physical P and its metadata remain unchanged, B is not described as durable and explicit retry remains available
- **AND** checkpoint failure never triggers remote Save or cleanup

#### Scenario: Typing during explicit post-choice checkpoint
- **WHEN** chosen current A is checkpointed while typing creates B
- **THEN** successful physical/effective checkpoint is captured A with its captured remote baseline, current B remains uncheckpointed and no newer field intent or receipt is erased

#### Scenario: F1 Accepted remote state blocks ordinary target replacement
- **GIVEN** physical P=A and an authorized explicit Accept establishes C=E=B, R=B without persisting B
- **WHEN** another target or session activation is requested after other operations settle
- **THEN** replacement is refused and the exact active owner, C/E/P/R and acceptance obligation remain intact despite C=E
- **AND** same-session rebinding retains the obligation without a write or changed dirty-state definition

#### Scenario: F1 Successful explicit checkpoint makes accepted B resumable
- **GIVEN** an outstanding acceptance obligation for C=E=B, R=B over P=A
- **WHEN** an explicit checkpoint captures its revision and B/R, succeeds under the same activation, and no other admission barrier remains
- **THEN** P/E become captured B with recorded R=B and the matching obligation clears
- **AND** ordinary switch is permitted and real-store reopen restores B, not A
- **AND** the checkpoint phase of explicitly requested Save may satisfy the same proof without another write or unnecessary field Update

#### Scenario: F1 Failed checkpoint retains old durable data and refusal
- **GIVEN** accepted B has an outstanding checkpoint obligation over durable A
- **WHEN** its explicit checkpoint fails
- **THEN** P remains A with its recorded metadata, C=E=B and R=B remain available, and the obligation still refuses target replacement
- **AND** retry never reports B physically saved or starts automatic remote work

#### Scenario: F1 Ordinary clean hydration has no acceptance obligation
- **GIVEN** clean checkpoint A has no unconfirmed remote edits and no explicit-acceptance obligation
- **WHEN** ordinary authorized hydration establishes C=E=B and R=B while P=A
- **THEN** no new switch restriction exists solely because C differs from disk and ordinary replacement remains permitted after existing barriers settle

#### Scenario: F1 Later reconciliation protects its own obligation revision
- **GIVEN** a checkpoint captured acceptance revision one before a later authorized reconciliation
- **WHEN** another Accept establishes revision two or Keep changes R while retaining and advancing the outstanding obligation
- **THEN** completion or callback from revision one cannot clear revision two, even if field values happen to match
- **AND** stale or failed reconciliation changes no obligation; Keep with no prior obligation creates none
- **AND** a new current Accept already represented by actual P needs no obligation

#### Scenario: F1 Reads and typing cannot erase an outstanding acceptance
- **WHEN** hydration, a read error, typing or remote-intent metadata settlement occurs while explicit acceptance awaits checkpoint
- **THEN** none clears the obligation, and hydration cannot silently replace its accepted C/E/R
- **AND** a matching checkpoint that captures later current fields can satisfy its obligation, while typing after capture remains protected by existing C versus E dirtiness

#### Scenario: F1 Revocation remains stronger than transition refusal
- **GIVEN** A owns accepted but uncheckpointed B over physical A-data
- **WHEN** account authority is revoked or the application owner is disposed
- **THEN** runtime state, obligation and callbacks lose access immediately without delaying security redirects or checkpointing
- **AND** original durable data remains private to A; an already-started checkpoint may finish only for its captured owner without releasing a replacement activation's obligation
- **AND** process restart restores physical truth without reconstructing the runtime obligation or claiming B survived
