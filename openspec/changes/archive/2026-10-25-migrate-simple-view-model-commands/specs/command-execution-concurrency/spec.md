## MODIFIED Requirements

### Requirement: Only authoritative completion can commit asynchronous data

For restartable or latest-intent operations, migrated asynchronous actions SHALL retrieve/compute and return application Results without mutating ViewModel state after awaits. A synchronous completion observer owned by the live ViewModel SHALL perform commits only for authoritative completions. Superseded, invalidated or disposed executions SHALL NOT commit data or presentation state, including when their physical work continues. These guarantees SHALL continue to apply to the existing Search and Map selection lanes.

For ordinary single-flight operations, the feature SHALL be allowed to retain its intended optimistic updates, progressive publication and presentation rollback within its asynchronous continuations. Every local commit SHALL require a live ViewModel and an execution that still holds the authority required for that state. This allowance SHALL NOT permit obsolete restartable work to commit, introduce latest-intent semantics into ordinary operations, or force terminal-only staging on features with observable intermediate publication.

Disposal SHALL revoke presentation commit authority for both kinds of operation. After disposal, no continuation SHALL perform new presentation commits, presentation rollback, ViewModel notifications or repository phases that have not already started. Already started external persistence SHALL NOT be represented as cancelled or remotely rolled back solely because its owner was disposed. ViewModels SHALL remove completion and public forwarding observers before disposing execution owners and before disposing their notifier. Existing unrelated lifecycle defenses SHALL remain until equivalent regressions prove their removal safe. Private execution cleanup and unexpected-error reporting SHALL retain the capability’s existing settlement and reporting guarantees.

Reconciling shared application consent after already-started persistence SHALL use the repository’s currently committed value, even when the initiating presentation owner has been disposed. The captured request and the owner’s optimistic state SHALL NOT be authoritative for that reconciliation. It SHALL perform no new I/O, restore no presentation publication authority and relax none of the restartable Search or Map guarantees.

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

## ADDED Requirements

### Requirement: Ordinary preference and discovery operations preserve single-flight admission

The six ordinary commands (crash reporting, theme brightness/type, latest places, suggestions and favourites) SHALL admit one execution at a time; duplicates SHALL NOT queue, restart or supersede. Theme fields SHALL retain independent lanes. Each preference action SHALL update and notify optimistically before persistence and preserve its success or application-error rollback behavior. Admission MAY precede action entry; same-stack optimism SHALL NOT be required.

#### Scenario: Duplicate ordinary operation
- **WHEN** an operation is invoked while that same operation remains active
- **THEN** no additional persistence or retrieval action starts and the active execution retains ownership

#### Scenario: Preference action enters after admission
- **WHEN** an admitted preference action begins after dispatch has returned
- **THEN** its local optimistic update and observer notification precede persistence, and application failure restores the established prior presentation state

#### Scenario: Independent theme fields
- **WHEN** theme type and brightness operations are admitted while both writes remain pending
- **THEN** neither operation supersedes the other and each retains the rollback state for its own field

### Requirement: Ordinary operation feedback reflects the current execution

Consumers SHALL distinguish neutral, loading, application success (including void), application failure and handled runtime failure from the current execution. Retained values, ignored/joined requests, waiter completion or disposal SHALL NOT imply success. Settings feedback SHALL require persistence success of the caller’s own accepted request. Handled runtime failures SHALL end loading and preserve global reporting; assertion policy SHALL remain unchanged.

#### Scenario: Retry after failure
- **WHEN** the user retries a failed ordinary discovery operation
- **THEN** the current failure is replaced by loading and then the actual new terminal outcome, without false success from a retained value

#### Scenario: Runtime failure on discovery
- **WHEN** the current retrieval throws a handled unexpected runtime failure
- **THEN** loading ends, failure and retry presentation is available, and the original failure is globally reported without fabricating an application error

#### Scenario: Preference write fails
- **WHEN** enabling crash reporting returns an application failure
- **THEN** its established optimistic rollback occurs and no successful-persistence snackbar is shown

#### Scenario: Ignored duplicate preference request
- **WHEN** a second crash-reporting request is ignored while an earlier write is active
- **THEN** the second caller produces no success feedback based on joining or observing the earlier request

#### Scenario: Owner disposal completes a waiter
- **WHEN** an owner is disposed before an awaited operation physically completes
- **THEN** completion of that wait alone produces no success feedback, local commit or later ViewModel notification

### Requirement: Favourite loading and mutation remain mutually exclusive

Favourite SHALL reject writes synchronously from load admission and reject concurrent writes. Load admission during a write SHALL retain its unavailable failure after that write settles. Autoload SHALL preserve progressive places/events, first-failure policy, deduplicated IDs and membership without full content. Direct writes SHALL preserve their Result and exact optimistic rollback while the owner remains live.

#### Scenario: Mutation before the first load notification
- **WHEN** a favourite mutation is requested immediately after loading is admitted
- **THEN** it is rejected and performs no optimistic update or repository write

#### Scenario: Write settles before a rejected load action enters
- **WHEN** a load is requested during a pending favourite write and that write settles before the load action begins
- **THEN** the load reports the established unavailable application failure and starts no place or event retrieval

#### Scenario: Second write while mutation is pending
- **WHEN** a second favourite mutation is requested before the first write settles
- **THEN** it is rejected without replacing the first operation’s predecessor state

#### Scenario: Partial favourite load
- **WHEN** one favourite side loads successfully while the other returns application failure
- **THEN** the successful side and its deduplicated membership IDs remain available and the load reports the established first failure

#### Scenario: Missing favourite content
- **WHEN** a favourite ID is available but resolving its complete content fails
- **THEN** that ID still participates in favourite membership without a fabricated content object

#### Scenario: Optimistic removal fails
- **WHEN** an accepted favourite removal fails while its owner remains live
- **THEN** the exact prior membership and content ordering are restored and the direct caller receives the failure Result

### Requirement: Ordinary owners stop commits and notifications on disposal

Disposal of the five migrated owners SHALL revoke presentation commits, rollback and notifications and prevent new repository phases. In-flight commands SHALL retain original unexpected-error reporting and release private resources exactly once after safe settlement, outside any active notifier dispatch, including while logically idle. Direct favourite writes SHALL retain their Result or throw contract without command-global reporting.

#### Scenario: Disposal requested during terminal notification
- **WHEN** an observer of a terminal operation state disposes its owner during notifier dispatch, including after the operation has become logically idle
- **THEN** owner forwarding is revoked immediately, private release does not invalidate the ongoing dispatch, no further ViewModel notification is initiated, and private resources are eventually released exactly once without notifier-after-dispose failure

#### Scenario: Dispose during initial retrieval
- **WHEN** an owner disposes while initial retrieval is pending and retrieval later returns success or application failure
- **THEN** the owner commits no later collection or preference state, starts no subsequent retrieval stage and emits no ViewModel notification

#### Scenario: Late handled runtime throw
- **WHEN** a pending command action throws a handled unexpected runtime failure after owner disposal
- **THEN** its original failure reaches global reporting exactly once without a disposed-notifier error and settled private resources are eventually cleaned

#### Scenario: Dispose during direct favourite write
- **WHEN** a favourite write settles after owner disposal
- **THEN** its direct caller retains the established Result or unexpected-throw contract without late rollback, collection commit or notification on the disposed owner
