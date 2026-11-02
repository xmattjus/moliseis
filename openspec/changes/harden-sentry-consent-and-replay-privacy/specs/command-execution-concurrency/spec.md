# Spec Delta

## MODIFIED Requirements

### Requirement: Only authoritative completion can commit asynchronous data

For restartable or latest-intent operations, migrated asynchronous actions SHALL retrieve/compute and return application Results without mutating ViewModel state after awaits. A synchronous completion observer owned by the live ViewModel SHALL perform commits only for authoritative completions. Superseded, invalidated or disposed executions SHALL NOT commit data or presentation state, including when their physical work continues. These guarantees SHALL continue to apply to the existing Search and Map selection lanes.

For ordinary single-flight operations, the feature SHALL be allowed to retain its intended optimistic updates, progressive publication and presentation rollback within its asynchronous continuations. Every local commit SHALL require a live ViewModel and an execution that still holds the authority required for that state. This allowance SHALL NOT permit obsolete restartable work to commit, introduce latest-intent semantics into ordinary operations, or force terminal-only staging on features with observable intermediate publication.

Disposal SHALL revoke presentation commit authority for both kinds of operation. After disposal, no continuation SHALL perform new presentation commits, presentation rollback, ViewModel notifications or repository phases that have not already started. Already started external persistence SHALL NOT be represented as cancelled or remotely rolled back solely because its owner was disposed. ViewModels SHALL remove completion and public forwarding observers before disposing execution owners and before disposing their notifier. Existing unrelated lifecycle defenses SHALL remain until equivalent regressions prove their removal safe. Private execution cleanup and unexpected-error reporting SHALL retain the capability’s existing settlement and reporting guarantees.

Reconciling shared application consent after already-started persistence SHALL use the repository’s currently committed value, even when the initiating presentation owner has been disposed. The captured request and the owner’s optimistic state SHALL NOT be authoritative for that reconciliation. Reconciliation SHALL restore no presentation publication authority and relax none of the restartable Search or Map guarantees. It SHALL start no new repository phase. The narrow telemetry exception SHALL allow an application-owned coordinator, independent of the disposed presentation, to complete SDK shutdown required by currently committed consent; it SHALL NOT permit runtime reinitialization or serialize preference persistence.

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
- **THEN** shared runtime consent is reconciled from the repository’s confirmed value without local presentation commits, notifications or new repository I/O; application-owned telemetry shutdown remains eligible

#### Scenario: Consent commits and completion delivery have different orders
- **WHEN** old and replacement Settings owners share the repository and consent flag, and commit order differs from delivery of their Results
- **THEN** each reconciliation uses the current committed repository value rather than either request’s captured value, without promising serialization or request-order persistence

#### Scenario: Replacement intent precedes stale consent delivery
- **WHEN** an old opt-out Result arrives after replacement-owner opt-in has committed and shutdown has not begun
- **THEN** that stale request cannot initiate shutdown using its captured false value
- **AND** once shutdown was validly initiated under committed opt-out, later opt-in never reverses it in the same process

### Requirement: Ordinary operation feedback reflects the current execution

Consumers SHALL distinguish neutral, loading, application success (including void), application failure and handled runtime failure from the current execution. Retained values, ignored/joined requests, waiter completion or disposal SHALL NOT imply success. Settings success feedback SHALL require persistence success of the caller’s own accepted request and current committed intent; disable success SHALL additionally require the application-owned shutdown outcome. A saved preference with shutdown unconfirmed SHALL produce distinct error feedback without persistence rollback. Enable and disable success SHALL use the same Snackbar mechanism and ownership eligibility. Handled runtime failures SHALL end loading and preserve global reporting; assertion policy SHALL remain unchanged.

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

#### Scenario: Saved opt-out has incomplete shutdown
- **WHEN** the current caller's opt-out persisted but SDK shutdown fails or observation times out
- **THEN** the preference remains disabled and current eligible presentation shows saved-preference/shutdown error feedback rather than disable success or optimistic rollback

#### Scenario: Current success uses symmetric feedback
- **WHEN** the admitted current Settings operation completes with enable-deferred or disable-completed outcome
- **THEN** the same Snackbar component and mounted/current-owner/current-intent checks apply, with accurate next-start or current-session wording
