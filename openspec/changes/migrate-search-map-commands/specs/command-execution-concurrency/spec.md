## ADDED Requirements

### Requirement: Search history preserves accepted mutation order

Search history SHALL accept distinct valid add/remove intentions while persistence is pending and attempt each accepted operation once in acceptance order. Opposite operations and operations on different entries SHALL NOT be silently dropped. Only proven redundant desired states or invalid/stale callbacks SHALL create no new obligation. Ordering SHALL be local to the originating session, without a cross-owner storage guarantee.

#### Scenario: Duplicate desired add
- **WHEN** add A is accepted and another equivalent add arrives with no intervening opposite intent
- **THEN** the second is represented by the first obligation and starts no duplicate write or implied independent success

#### Scenario: Opposite intentions
- **WHEN** add A then remove A, or remove A then add A, are accepted while the first write is pending
- **THEN** both operations receive one ordered persistence attempt; successful writes establish the final desired state, while failures use per-operation rollback and rebase of later intentions

#### Scenario: Different entries and first failure
- **WHEN** operations on A and B are accepted and the first returns an application failure
- **THEN** the second still executes once after the first settles and its projection is not erased by the first rollback

### Requirement: Accepted history persistence survives presentation disposal

Acceptance SHALL synchronously transfer the persistence obligation before navigation or UI notification. A live session SHALL attempt accepted writes even if presentation disposes before deferred action entry, including queued obligations. UI disposal SHALL revoke new acceptance and all presentation access, not cancel accepted persistence. Navigation SHALL NOT await physical completion. Closed-popup callbacks SHALL create no new intentions.

#### Scenario: Submit disposes before action entry
- **WHEN** current Search submit is accepted, closes its popup and navigates away before the write action enters
- **THEN** navigation is immediate and exactly one persistence attempt occurs without late owner notification or access to unmounted State

#### Scenario: Queued submit outlives UI
- **WHEN** a confirmed submit is accepted behind an earlier pending write and its UI disposes
- **THEN** the session completes both obligations in order without requiring the old UI or creating a duplicate write

#### Scenario: Closed popup callback
- **WHEN** an old popup callback fires after closure, owner replacement or unmount
- **THEN** no new history intent is accepted even if the original writer is still draining

#### Scenario: Synchronous notification replaces the host
- **WHEN** accepted-history optimism or the popup close callback disposes or replaces the host before its navigation follow-up
- **THEN** the accepted persistence obligation survives but stale close/navigation callbacks do not execute; the current confirmation's own close alone does not invalidate its valid navigation

### Requirement: Search history deduplication respects repository identity and knowledge

Add SHALL exclude empty text and known category labels and compare existing queries case-insensitively. Remove SHALL use exact text. A no-op SHALL require a known non-uncertain base or a pending intention already representing the desired state. Unknown bootstrap data or provisional state after runtime failure SHALL NOT alone prove redundancy. No-op classification SHALL NOT imply successful new persistence.

#### Scenario: Known exclusions and absent removal
- **WHEN** text is empty, a known category label, a proven duplicate add or a proven absent exact removal
- **THEN** no new write or list notification occurs

#### Scenario: Unknown or uncertain history
- **WHEN** local absence or provisional membership is the only reason an otherwise valid operation appears redundant
- **THEN** it remains admissible and receives its own persistence attempt

### Requirement: Search history rollback rebases later accepted intentions

Effective acceptance SHALL update desired history optimistically before persistence and notify only if its ordered projection changes. Success SHALL confirm that operation; application failure SHALL remove only its optimistic contribution and preserve the original error. Remaining accepted transformations SHALL be reapplied in order. Runtime failure SHALL preserve provisional optimism without fabricated rollback or domain failure.

#### Scenario: Isolated mutation fails
- **WHEN** a history mutation fails without later accepted intentions
- **THEN** the exact prior ordered list is restored and the original application error causes no unexpected-error report

#### Scenario: Failure with a later intention
- **WHEN** add A fails after add B or remove A has already been accepted
- **THEN** only the failed add contribution is removed, the later intention remains projected and is still persisted once, with notification only for an actual list change

#### Scenario: Remove fails before accepted add
- **WHEN** remove A fails with a later add A already accepted
- **THEN** rebasing preserves the original stored ordering and the later add still receives its repository attempt even if it is now a repository no-op

### Requirement: History read authority changes at mutation acceptance

History SHALL bootstrap automatically once per presentation owner and allow only one physical read at a time. Effective mutation acceptance SHALL synchronously invalidate older read authority and install settlement coordination before deferred action entry or notification. Reads SHALL publish only for a stable revision with no pending obligations. The writer SHALL NOT wait for reads, and disposal SHALL release presentation read waiters.

#### Scenario: Admission precedes action entry
- **WHEN** bootstrap G0 is pending, W is accepted and G0 completes before W enters its action
- **THEN** G0 cannot publish and a stable reconciliation read waits for the accepted write obligations to settle

#### Scenario: Mutations coalesce stale bootstrap
- **WHEN** two intentions are accepted during G0 and G0 succeeds before, during or after their writes
- **THEN** obsolete data never overwrites their desired projection and one stable post-drain read suffices if no newer intention arrives

#### Scenario: Dispose while read waits
- **WHEN** presentation disposes while its reader waits for a pending write
- **THEN** its waiter exits without a new read or notification, without pretending that physical persistence has completed

### Requirement: Runtime write failure requests bounded history reconciliation

A handled runtime write failure SHALL retain original error and stack, report once and request a stable reconciliation read while UI remains live. It SHALL NOT retry the write or invent rollback. The same read authority protocol SHALL wait for all accepted obligations and reject older data. A stable attempted read failure SHALL terminate without self-retry; uncertainty alone SHALL NOT create an infinite loop.

#### Scenario: Runtime before or after actual commit
- **WHEN** a write throws before changing storage or after storage changed, with no read already pending
- **THEN** one post-drain read is requested and actual persisted history determines the projection, with no duplicate write or runtime report

#### Scenario: Later mutation is pending
- **WHEN** a write throws while a later valid mutation is already accepted
- **THEN** reconciliation waits for both obligations, uses their current revision and cannot overwrite the later intention with earlier data

#### Scenario: Reconciliation read fails or UI disposes
- **WHEN** the requested stable read fails, or UI disposes before it starts
- **THEN** no automatic read loop or write retry occurs and disposed presentation receives no new notification

### Requirement: History read demands distinguish stale errors from retry loops

A read attempt SHALL consume only the reconciliation demand current at its stable start. Failure SHALL retain visible history and its actual error kind without reissuing that consumed demand. A newer demand created after an older read began SHALL remain eligible for one post-drain attempt after that read settles. Runtime read failures SHALL retain reporting independently of write failures.

#### Scenario: Old bootstrap fails after newer write demand
- **WHEN** G0 began before W acceptance or runtime failure and G0 then fails
- **THEN** G0 retains its error but cannot consume the newer post-write reconciliation demand

#### Scenario: Stable reconciliation fails
- **WHEN** the current stable reconciliation attempt fails with no newer demand
- **THEN** loading terminates, provisional history remains and further reading requires explicit retry or a new qualifying mutation demand

### Requirement: GeoMap marker filters immediately own immutable selection

Marker filter changes SHALL synchronously capture immutable category and type sets, hide old collections and terminal evidence, and revoke older publication. Bootstrap SHALL select all known categories and all types once. Equal current selections SHALL cause no admission, I/O or notification. Empty programmatic categories or types SHALL settle empty without I/O. Existing dialog empty-to-all behavior on permitted current-session route completion SHALL remain unchanged.

#### Scenario: Caller mutates its set
- **WHEN** a filter set is supplied and the caller subsequently changes that set
- **THEN** the accepted selection and retrieval retain their original immutable values

#### Scenario: Selection returns to A
- **WHEN** A changes to B and then A while older retrievals remain pending
- **THEN** only final A owns data and terminal status, including before deferred public loading appears

#### Scenario: Equal selection and empty selection
- **WHEN** current filters are repeated or an empty programmatic selection is accepted
- **THEN** repetition is a no-op while empty selection immediately hides old markers and settles successful-empty with zero new fetches

### Requirement: GeoMap marker retry and status belong to current admission

Marker presentation SHALL distinguish loading, successful-empty, successful-data and failure. New admission SHALL exclude old terminal evidence immediately. Retry SHALL target the current filters at activation, use a fresh intent after failure and reject busy or obsolete callbacks. Empty selection retry SHALL perform no I/O. Marker state SHALL NOT change semantic mode, selected Post, Nearby, Weather, Search admission or route ownership.

#### Scenario: Failure and retry
- **WHEN** current marker discovery fails and its current retry is activated
- **THEN** error is replaced by loading and the current selected sources are retrieved again without owner recreation

#### Scenario: Superseded retry or marker callback
- **WHEN** a callback belongs to an earlier marker admission, replaced owner or unmounted screen
- **THEN** it starts no retry or selection and cannot affect the current screen

#### Scenario: Status without semantic navigation
- **WHEN** marker discovery loads, settles empty, produces data or fails while Search or Post is active
- **THEN** marker status is distinguishable without altering the current semantic surface or repeating camera and sheet entry effects

### Requirement: Presentation and persistence ownership remain separate during cleanup

UI disposal SHALL revoke commits, rollback, callbacks and new UI-owned read/marker phases immediately. An already-live history writer SHALL retain only its accepted obligations and private settlement, without accessing the detached UI. Handled runtime reporting and exactly-once cleanup SHALL remain outside notifier dispatch. Other command owners SHALL retain their existing disposal contracts; this SHALL NOT grant stale retrieval publication authority.

#### Scenario: Dispose during optimistic notification
- **WHEN** presentation is disposed from its notification after a history intention was accepted
- **THEN** no further presentation access occurs but the separate live writer still attempts that accepted obligation once

#### Scenario: Marker or history reader disposal
- **WHEN** a marker owner or presentation-owned reader is disposed before a new source phase starts
- **THEN** that phase does not start and no later commit or notification occurs

#### Scenario: Late error and terminal observer disposal
- **WHEN** accepted persistence throws after UI detach or the UI disposes during terminal dispatch
- **THEN** original runtime reporting occurs once without disposed-notifier failure and private writer resources release once after drain

#### Scenario: Popup outlives its anchor
- **WHEN** Search submission closes its popup and navigation unmounts the anchor while accepted work remains pending
- **THEN** navigation does not await persistence, the popup is not popped twice and old callbacks access no unmounted context or replacement controller or owner

### Requirement: Explicit history refresh registers independent read demand

History refresh SHALL have one public demand entry point, with no externally executable reader. A live request SHALL register demand synchronously and use the revision-aware scheduler. Pre-entry requests MAY coalesce; demand registered after a physical read starts SHALL remain eligible and SHALL NOT be consumed by that earlier attempt. Disposed requests SHALL be no-ops.

#### Scenario: Bootstrap and explicit retry
- **WHEN** history owner starts or explicitly retries a terminal domain or runtime failure
- **THEN** the same demand protocol schedules one eligible stable read without spontaneous retry of the consumed failed demand

#### Scenario: Demand during active read or writer drain
- **WHEN** refresh is requested after G0 physically starts or while accepted writes remain pending
- **THEN** newer demand remains eligible, G0 cannot publish as its result and a single stable read starts only when prior read and writer obligations permit it

#### Scenario: Disposed refresh and reader encapsulation
- **WHEN** refresh is requested after disposal or consumers inspect the public history execution state
- **THEN** no new read occurs after disposal and consumers cannot bypass demand registration by executing the reader directly
