# Spec Delta

## RENAMED Requirements

- FROM: `### Requirement: Search history deduplication respects repository identity and knowledge`
- TO: `### Requirement: Search history mutations use repository identity rules`

- FROM: `### Requirement: Search history rollback rebases later accepted intentions`
- TO: `### Requirement: Search history presentation retains confirmed data`

- FROM: `### Requirement: History read authority changes at mutation acceptance`
- TO: `### Requirement: History reads remain independent of accepted writes`

- FROM: `### Requirement: Runtime write failure requests bounded history reconciliation`
- TO: `### Requirement: Runtime history write failures allow explicit read-only recovery`

- FROM: `### Requirement: History read demands distinguish stale errors from retry loops`
- TO: `### Requirement: History read failures terminate without automatic retry`

- FROM: `### Requirement: Explicit history refresh registers independent read demand`
- TO: `### Requirement: Explicit history refresh uses ordinary single-flight admission`

- FROM: `### Requirement: Editor changes retain an owner-local refresh obligation`
- TO: `### Requirement: Editor return requests best-effort dashboard refresh`

## MODIFIED Requirements

### Requirement: Only authoritative completion can commit asynchronous data

For restartable or latest-intent operations, migrated asynchronous actions SHALL retrieve/compute and return application Results without mutating ViewModel state after awaits. A synchronous completion observer owned by the live ViewModel SHALL perform commits only for authoritative completions. Superseded, invalidated or disposed executions SHALL NOT commit data or presentation state, including when their physical work continues. These guarantees SHALL continue to apply to the existing Search and Map selection lanes.

For ordinary single-flight operations, the feature SHALL be allowed to retain its intended optimistic updates, progressive publication and presentation rollback within its asynchronous continuations. Every local commit SHALL require a live ViewModel and an execution that still holds the authority required for that state. This allowance SHALL NOT permit obsolete restartable work to commit, introduce latest-intent semantics into ordinary operations, or force terminal-only staging on features with observable intermediate publication.

Disposal SHALL revoke presentation commit authority for both kinds of operation. After disposal, no continuation SHALL perform new presentation commits, presentation rollback, ViewModel notifications or repository phases that have not already started. Already started external persistence SHALL NOT be represented as cancelled or remotely rolled back solely because its owner was disposed. ViewModels SHALL remove completion and public forwarding observers before disposing execution owners and before disposing their notifier. Existing unrelated lifecycle defenses SHALL remain until equivalent regressions prove their removal safe. Private execution cleanup and unexpected-error reporting SHALL retain the capability’s existing settlement and reporting guarantees.

Reconciling shared application consent after already-started persistence SHALL use the repository’s currently committed value, even when the initiating presentation owner has been disposed. The captured request and the owner’s optimistic state SHALL NOT be authoritative for that reconciliation. It SHALL perform no new I/O, restore no presentation publication authority and relax none of the restartable Search or Map guarantees.

Already-accepted Search history writes whose persistence ownership was transferred before presentation disposal SHALL remain eligible under Accepted history persistence survives presentation disposal. This narrow exception SHALL allow neither new acceptance nor presentation access after disposal and SHALL NOT authorize new phases for any other feature. Separate persistence ownership SHALL NOT depend on a particular helper-class topology.

#### Scenario: Superseded retrieval returns data
- **WHEN** obsolete retrieval returns content after a newer request
- **THEN** no synchronous application commit occurs for obsolete content

#### Scenario: Ordinary optimism and rollback
- **WHEN** an ordinary preference or favourite write updates presentation optimistically and later returns an application failure while its owner and execution remain authoritative
- **THEN** the feature retains its intended optimistic notification and exact presentation rollback without requiring a terminal completion observer

#### Scenario: Progressive favourite publication
- **WHEN** favourite place retrieval completes while event retrieval remains pending
- **THEN** the live authoritative ordinary load can publish its place collection and membership IDs before event retrieval settles, and a later event failure does not undo that successful side

#### Scenario: Disposal before asynchronous completion
- **WHEN** an ordinary or restartable owner is disposed before pending work returns success or application failure
- **THEN** the late continuation performs no local commit, presentation rollback or notification and starts no subsequent repository phase

#### Scenario: Disposal from an optimistic notification
- **WHEN** a synchronous observer disposes an ordinary owner during an optimistic notification before persistence starts
- **THEN** the continuation starts no persistence phase and emits no further presentation update

#### Scenario: Obsolete restartable success cannot use ordinary permissions
- **WHEN** superseded Search or Map selection retrieval completes after a newer intent was accepted
- **THEN** only the live authoritative completion observer can commit and the obsolete result cannot use the ordinary-operation allowance to publish state

#### Scenario: Persisted consent outlives the presentation owner
- **WHEN** a consent write already started by a disposed Settings owner settles
- **THEN** shared runtime consent is reconciled from the repository’s confirmed value without local presentation commits, notifications or new I/O

#### Scenario: Consent commits and completion delivery have different orders
- **WHEN** old and replacement Settings owners share the repository and consent flag, and commit order differs from delivery of their Results
- **THEN** each reconciliation uses the current committed repository value rather than either request’s captured value, without promising serialization or request-order persistence

### Requirement: Search history preserves accepted mutation order

Search history SHALL attempt each accepted valid add/remove once in session acceptance order. Opposite and different-entry intentions SHALL NOT be dropped. Invalid/stale callbacks SHALL create no obligation. Repository-idempotent redundant calls are permitted; no cross-owner ordering or automatic write retry is promised.

#### Scenario: Duplicate desired add
- **WHEN** equivalent adds are accepted without an intervening remove
- **THEN** storage contains at most one matching query under the repository identity rule; redundant ordered calls may occur without implying independent new data

#### Scenario: Opposite intentions
- **WHEN** add then remove, or remove then add, is accepted while persistence is pending
- **THEN** both receive one ordered attempt; the final stored state follows actual successful writes, without an optimistic projection contract

#### Scenario: Different entries and first failure
- **WHEN** operations on A and B are accepted and A returns an expected or normally handled runtime failure
- **THEN** B is still attempted once afterward; A retains its real failure and is not replayed

### Requirement: Accepted history persistence survives presentation disposal

Acceptance SHALL transfer a persistence obligation synchronously before navigation or notification. Accepted writes SHALL remain ordered after presentation disposal, including queued writes. Disposal SHALL reject new acceptance and revoke presentation access, not claim cancellation of accepted persistence. Navigation SHALL NOT await writes.

#### Scenario: Submit disposes before action entry
- **WHEN** a current submit closes its popup and disposes before write entry
- **THEN** navigation proceeds and the accepted write is attempted once without late owner notification or unmounted access

#### Scenario: Queued submit outlives UI
- **WHEN** a confirmed submit is queued behind an accepted pending write and UI disposes
- **THEN** both writes are attempted in order without requiring the old UI or duplicating a write

#### Scenario: Closed popup callback
- **WHEN** an obsolete popup callback fires after closure, replacement or unmount
- **THEN** no new history intention is accepted

#### Scenario: Synchronous notification replaces the host
- **WHEN** a popup close or current notification replaces the host before navigation follow-up
- **THEN** accepted persistence survives but stale follow-up does not execute; the current confirmation own close does not invalidate valid navigation

### Requirement: Search history mutations use repository identity rules

Add SHALL exclude empty text and known category labels. Stored adds SHALL use the repository case-insensitive identity; removals SHALL use exact text and remain idempotent. Presentation absence SHALL NOT discard a valid accepted operation. VM knowledge/projection proofs SHALL NOT be required.

#### Scenario: Known exclusions and absent removal
- **WHEN** text is empty or a known category label, or an exact removal targets an absent query
- **THEN** invalid adds perform no write; an absent removal may reach the idempotent repository and creates no false data change

#### Scenario: Unknown or uncertain history
- **WHEN** bootstrap is pending or an earlier write outcome is uncertain
- **THEN** otherwise valid operations remain admissible and ordered; the current visible list does not prove they are redundant

### Requirement: Search history presentation retains confirmed data

History SHALL display the last confirmed read until a later read succeeds. Mutation acceptance SHALL NOT require optimistic list changes, rollback or projection rebase. Failures SHALL retain the confirmed list and original error; subsequent accepted writes SHALL remain ordered and independent of prior presentation failure.

#### Scenario: Isolated mutation fails
- **WHEN** a history mutation fails with no later intention
- **THEN** the last confirmed list remains visible, original failure is available, and expected error does not enter unexpected reporting

#### Scenario: Failure with a later intention
- **WHEN** A fails after B was accepted
- **THEN** B remains scheduled once; no rollback erases B persistence and the next successful read shows actual storage

#### Scenario: Remove fails before accepted add
- **WHEN** remove A fails and later add A is already accepted
- **THEN** the add is still attempted once in order, even when the repository treats it as a no-op; display changes only from a successful read

#### Scenario: Open popup updates from a confirmed read
- **WHEN** an empty-input Search popup stays open with unchanged text and a controlled history read succeeds
- **THEN** its rendered chips update to the confirmed list without typing, closing or reopening; a failed later read retains those chips with visible error and read-only reload, and successful reload updates chips and clears failure without a history write

#### Scenario: Popup history observation changes owner or ends
- **WHEN** owner/controller/session changes or the anchor unmounts while old history work or cached callbacks remain
- **THEN** old work cannot update the replacement popup, replay a write or access unmounted state; safe fallback widget values do not create a live subscription to the old owner

### Requirement: History reads remain independent of accepted writes

History SHALL bootstrap and use one physical read at a time. Reads SHALL be independent of ordered writes; a read SHALL NOT delay accepted persistence. A successful read can publish confirmed but temporarily stale history. Mutation completion can request a best-effort reload; a busy request need not create future demand. Explicit read reload SHALL provide recovery.

#### Scenario: Admission precedes action entry
- **WHEN** bootstrap is pending, W is accepted and bootstrap completes before W enters
- **THEN** confirmed bootstrap data may appear; W still executes once and later reload can reconcile without optimistic overwrite or data loss

#### Scenario: Mutations coalesce stale bootstrap
- **WHEN** accepted mutations overlap an older read
- **THEN** writes remain ordered independently; automatic post-drain freshness and a particular read count are not promised, and explicit reload recovers stale chips

#### Scenario: Dispose while read waits
- **WHEN** presentation disposes with a read or accepted write pending
- **THEN** no new UI-owned read or publication occurs; accepted persistence remains independent and is not represented as cancelled

### Requirement: Runtime history write failures allow explicit read-only recovery

A normally handled runtime write failure SHALL preserve its original Object/stack and report once. A live history surface SHALL expose failure and read-only reload to reconcile storage. It SHALL NOT replay the write, invent rollback or claim success. Successful reload SHALL clear visible failure; no automatic stable-revision reconciliation is required.

#### Scenario: Runtime before or after actual commit
- **WHEN** a write throws before storage changes or after it committed
- **THEN** the original failure reports once, no write retry occurs, and explicit read reload shows actual storage

#### Scenario: Later mutation is pending
- **WHEN** a write throws while another valid mutation is accepted
- **THEN** the later write still executes once in order; reads do not delay it and visible history may remain stale until reload

#### Scenario: Reconciliation read fails or UI disposes
- **WHEN** the user reloads and that read fails or presentation disposes before read entry
- **THEN** no automatic retry loop or write replay occurs; confirmed data is retained and disposed UI receives no notification

### Requirement: History read failures terminate without automatic retry

Each admitted history read SHALL reach its real terminal outcome while live. Failure SHALL retain confirmed history and SHALL NOT retry itself. Refresh requested while a read is busy may be ignored without a future obligation. Loading SHALL end for terminating handled failures and explicit retry SHALL remain available.

#### Scenario: Old bootstrap fails after newer write demand
- **WHEN** bootstrap fails after a write was accepted or a best-effort reload requested
- **THEN** its actual failure is retained without blocking the write; a later explicit reload can recover and no mandatory later read is inferred

#### Scenario: Stable reconciliation fails
- **WHEN** a current reload fails with no other request
- **THEN** loading ends, confirmed history remains and another read requires explicit retry or a later best-effort write-completion request

### Requirement: Explicit history refresh uses ordinary single-flight admission

History SHALL expose one read-only refresh entry point with ordinary single-flight admission. Bootstrap and user reload SHALL use it; busy requests may be ignored. It SHALL NOT write, replay mutations or register revision-tracked future demand. Requests after presentation disposal SHALL be no-ops.

#### Scenario: Bootstrap and explicit retry
- **WHEN** an owner starts or the user activates reload after a terminal failure
- **THEN** one eligible read is requested; no failed demand self-retries and successful reading replaces confirmed history

#### Scenario: Demand during active read or writer drain
- **WHEN** reload is requested while reading or accepted writes remain pending
- **THEN** an idle read can start independently of writes; a busy request may be ignored and the UI still offers reload after completion

#### Scenario: Disposed refresh and reader encapsulation
- **WHEN** refresh is invoked after disposal or consumers inspect history status
- **THEN** no new read starts after disposal and status inspection cannot replay a mutation

### Requirement: Editor return requests best-effort dashboard refresh

A changed editor returning to the same current dashboard SHALL request submissions refresh and then ignored sources if still selected and owned. Each read SHALL obey ordinary admission; a busy request may be ignored and creates no per-revision obligation or waiter. Stale rows SHALL be recoverable by existing manual refresh/retry. Editor persistence SHALL NOT be repeated.

#### Scenario: Older submissions read cannot satisfy editor change
- **WHEN** a submissions read already runs when a changed editor returns
- **THEN** that read may finish as the visible result and the new request may be ignored; manual refresh recovers newer persisted rows

#### Scenario: Editor demand survives exclusive reactivation
- **WHEN** a changed editor returns while reactivation reserves dashboard reads
- **THEN** editor refresh may be refused without retained demand; existing reactivation and manual refresh remain available

#### Scenario: Pending editor changes coalesce before admission
- **WHEN** multiple changed returns occur while a read is busy
- **THEN** requests can be ignored without revision batches or independent completion waiters

#### Scenario: Newer editor change requires another batch
- **WHEN** another changed return arrives during a prior editor refresh
- **THEN** no additional batch is mandatory; later explicit refresh reads current storage

#### Scenario: Ignored editor refresh waits for its lane
- **WHEN** ignored sources is selected but its read lane is busy after submissions refresh
- **THEN** the ignored refresh request can be refused without a deferred obligation

#### Scenario: Editor refresh uses current filter
- **WHEN** submissions request completes with owner live
- **THEN** ignored sources is requested only if its filter is selected at that time

#### Scenario: Prior failed read releases editor demand
- **WHEN** a read fails while another editor return requests refresh
- **THEN** each request obeys admission and manual retry remains possible; no retained revision must be drained

#### Scenario: Editor read failure processes without retry
- **WHEN** the editor-triggered read fails
- **THEN** its actual failure is presented according to existing list policy without automatic retry or mutation replay

#### Scenario: Editor assertion abort is not normal continuation
- **WHEN** a refresh encounters an assertion
- **THEN** the original assertion remains fail-loud and cannot authorize a normal follow-up or fabricated success

#### Scenario: Editor coordination revokes independently of physical work
- **WHEN** the dashboard is disposed during editor-triggered reading
- **THEN** no subsequent UI read or notification starts; already-started work settles under the existing lifecycle contract

#### Scenario: Editor callback owns registration only
- **WHEN** a changed return belongs to the current dashboard
- **THEN** it requests the bounded sequential refresh without owning a revision obligation; stale callbacks request nothing

#### Scenario: Reentrant editor registration preserves wakeups
- **WHEN** an observer makes another editor refresh request while busy
- **THEN** ordinary refusal is acceptable; it cannot replace a mutation or imply refresh success

#### Scenario: Nonterminating editor work and revocation
- **WHEN** an editor-triggered read does not terminate and owner is revoked
- **THEN** no fabricated completion or subsequent phase occurs; no revision scheduler retains additional callers

### Requirement: Dashboard entry and refresh consumers retain behavior

Route entry SHALL initialize submissions once. Manual refresh, pull-to-refresh and retries SHALL use the selected list through owner admission; accepted pull refresh SHALL await terminal commit. An editor returning changed SHALL request submissions and then selected ignored sources through ordinary admission; busy requests may be ignored and manual refresh provides recovery. List loading, empty, error, retry and prior-data retention rendering SHALL be preserved.

#### Scenario: Initial loading and empty result
- **WHEN** a new dashboard begins its first request then returns an empty list
- **THEN** loading is shown before deferred action entry and then the existing empty state is shown

#### Scenario: Initial failure and retry
- **WHEN** the first request fails and the user retries
- **THEN** the existing error/retry UI appears and one new read is admitted after settlement

#### Scenario: Refresh retains existing submissions
- **WHEN** a refresh fails with previously displayed submissions
- **THEN** those rows remain and the existing main-list error visibility policy is preserved

#### Scenario: Refresh ignored sources with retained data
- **WHEN** ignored-source refresh fails with existing sources
- **THEN** retained sources and the existing ignored-source error/retry feedback remain visible

#### Scenario: Editor returns changed
- **WHEN** the editor returns true to the same live dashboard owner
- **THEN** submissions refresh is requested and ignored sources is requested afterward only if that filter is still selected; ordinary busy refusal is acceptable

#### Scenario: Editor owner was replaced
- **WHEN** an editor return callback belongs to a removed or replaced dashboard owner
- **THEN** it starts no refresh or navigation on the replacement owner

### Requirement: Admin editor results preserve failure kind and original reporting

Each accepted attempt SHALL have a distinct logical attempt identity even for equal Result values. New admission SHALL publish its own running state and revoke previous terminal authority. Outcomes SHALL distinguish neutral, success, expected Result error and runtime failure. Original handled runtime Object and stack SHALL report once, including after revocation. Assertions SHALL remain fail-loud.

#### Scenario: Real void success

- **WHEN** an operation returns successful void Result
- **THEN** it is completed success distinct from never-run neutral state

#### Scenario: Late raw failure

- **WHEN** retained editor work throws a handled raw error after owner disposal
- **THEN** its original error and stack are reported once without a fabricated Result.error, duplicate report or disposed-notifier secondary failure

#### Scenario: Nested phase failure

- **WHEN** a private phase of KeepCurrent or moderation throws
- **THEN** only the owning outer operation reports that original runtime failure
- **AND** no internal Save completion navigates the editor

#### Scenario: Equal outcomes belong to different executions

- **WHEN** two consecutive accepted executions produce equal Results regardless of physical command topology
- **THEN** they retain distinct logical attempt identities and separately observable running and terminal outcomes
- **AND** old callbacks cannot publish a duplicate into the second attempt or reset its busy state

### Requirement: Admin editor revocation preserves private physical settlement

Editor revocation SHALL stop admission, public forwarding and new phases immediately. Started work SHALL retain safe original runtime reporting and exactly one effective resource release after settlement, outside active dispatch. Converging owner, skipped-admission, late-completion and reentrant cleanup SHALL NOT repeat release or listener teardown. Application revocation SHALL remain distinct from physical completion and resource release. While owner authority remains live, accepted requests SHALL execute once and normal retries SHALL remain usable. Revocation before action entry SHALL skip I/O without public success. Physical command identity, observer counts and receipt topology SHALL NOT be application contracts.

#### Scenario: Failed execution then successful retry reuses its lane
- **WHEN** a request returns expected error and an explicit retry is accepted after completion
- **THEN** the retry executes once with its own visible running/outcome; no physical identity or observer-count assertion is required

#### Scenario: Revoke during second execution
- **WHEN** owner revocation occurs during a second accepted request
- **THEN** no late UI outcome appears; original handled runtime error/stack reports once without disposed-notifier error and settled resources release safely

#### Scenario: Dispose before deferred action
- **WHEN** owner revocation precedes admitted action entry
- **THEN** no picker or repository phase starts; resources release without public success

#### Scenario: Reentrant terminal admission
- **WHEN** a terminal observer requests another operation
- **THEN** the request follows current reservation admission; after a terminal outcome is publicly released it may be admitted, executes once and cannot have its busy state cleared by the previous operation

#### Scenario: Revocation between private phases
- **WHEN** owner revokes after one private phase or from a state notification
- **THEN** no subsequent repository phase, presentation commit or navigation starts

#### Scenario: Nonterminating work and assertion
- **WHEN** physical work stays pending or an assertion bypasses normal terminal routing
- **THEN** pending work is not declared cancelled; assertion remains fail-loud, causes no fabricated normal outcome, eligible resources release safely and further owner work may stop instead of automatic assertion recovery

#### Scenario: Overlapping cleanup of a never-started command
- **WHEN** an admission observer revokes the editor before action entry and owner cleanup, skipped-admission cleanup and queued callbacks converge
- **THEN** no picker/repository phase, fabricated success or late ViewModel notification occurs; each private command has one effective release and all later release attempts are no-ops without secondary disposal/listener errors or loss of an original runtime error
