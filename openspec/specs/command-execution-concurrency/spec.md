# command-execution-concurrency Specification

## Purpose
Define observable command execution, failure reporting and latest-intent ownership so asynchronous work cannot publish stale application state or commit after its owner is disposed.

## Requirements

### Requirement: Execution states distinguish never-run and failure kinds

A Result-aware command SHALL distinguish never-run/neutral, running, completed application success, expected application failure and unexpected execution failure. Expected Result.error SHALL retain its Exception without converting it to a throw. Unexpected runtime failures handled by the command runtime SHALL be terminal execution failures with stack trace, not fabricated domain failures. Assertion failures SHALL preserve the upstream fail-loud development/test policy and SHALL NOT be converted into normal terminal UI failures or not-found feedback. A neutral null initial result SHALL NOT be interpreted as completed success.

#### Scenario: New command has no result
- **WHEN** a command has never run
- **THEN** it is neutral and neither completed nor failed

#### Scenario: Void application success
- **WHEN** an action returns a non-null successful Result whose contained value is null
- **THEN** the execution is completed success distinctly from never-run

#### Scenario: Domain and unexpected failure
- **WHEN** an action returns an expected failure or throws an unexpected runtime failure handled by the command runtime
- **THEN** the respective domain or unexpected failure is terminal and running ends for that authoritative execution

### Requirement: Unexpected errors use the existing privacy-aware reporting boundary

Every unexpected runtime execution failure handled by the command runtime SHALL reach the existing application logging boundary exactly once with its original Object, stack trace and only approved non-sensitive command context. This SHALL include stale handled runtime failures and programming errors such as StateError and TypeError. Assertion failures SHALL retain their upstream development rethrow policy rather than this normal terminal/reporting contract. Reporting SHALL respect runtime telemetry opt-out and SHALL NOT automatically include command parameters or stringify parameter-bearing wrappers. Expected application failures SHALL NOT automatically enter unexpected-error reporting.

#### Scenario: Stale failure remains diagnosable
- **WHEN** superseded physical work throws a handled unexpected runtime failure
- **THEN** its error is reported once but cannot change the latest UI state

#### Scenario: Sensitive argument and opt-out
- **WHEN** a failed execution had a user-text parameter and remote reporting is disabled
- **THEN** application logging contains the original error and stack without command argument data and no telemetry exception is sent

### Requirement: Newest intent immediately owns restartable publication

For a restartable boundary, accepting B while A is pending SHALL immediately make B the sole authoritative logical execution. A SHALL NOT subsequently change application state, value, success, failure or running of B, even if physical A work continues. Accepting C SHALL similarly revoke B. Cancellation cooperation SHALL NOT be a correctness prerequisite. Repeated equal parameters SHALL be separate accepted intents.

#### Scenario: Slow A and fast B
- **WHEN** B completes while A remains physically pending
- **THEN** only B is published and current running is false even though A still runs

#### Scenario: Late A after B
- **WHEN** A completes successfully or with expected failure after B is admitted
- **THEN** no A state is published before or after B completion

#### Scenario: Three rapid intents
- **WHEN** A then B then C are accepted before any await finishes
- **THEN** only C can publish an authoritative terminal state

#### Scenario: Latest unexpected throw
- **WHEN** the authoritative execution throws an unexpected runtime failure handled by the command runtime
- **THEN** current state becomes terminal unexpected failure, running ends and global reporting occurs once

### Requirement: Logical cancellation and lifecycle are separate from physical work

Superseding or disposing a restartable owner SHALL stop public forwarding immediately. Starting the new intent SHALL NOT wait for obsolete physical work. Foundation execution SHALL support ordinary Result-producing actions without a progress or cooperative-cancellation specialization. Public owner disposal SHALL emit no later state and allow no later application commits; private cleanup SHALL occur exactly once per settled execution without premature disposal of live work. Assertion failures SHALL remain visible through upstream development error handling and SHALL NOT prevent settled private child cleanup.

#### Scenario: Noncooperative future
- **WHEN** an obsolete operation continues physically after logical cancellation
- **THEN** B starts without waiting for A and A cannot publish, with private resources cleaned after A settles

#### Scenario: Dispose during fetch
- **WHEN** the owning ViewModel disposes while work remains in flight
- **THEN** no later public result or ViewModel notification occurs, while late handled unexpected runtime failures remain reportable and private settled resources are cleaned once

#### Scenario: Assertion preserves development policy
- **WHEN** an execution encounters an assertion failure with upstream assertions enabled
- **THEN** the assertion reaches the upstream development error path, is not normalized to Result.error or not-found feedback and its settled private resources are still cleaned once

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

### Requirement: Map selection has one cross-type latest-intent domain

Map event selection, place selection and default-map/clear invalidation SHALL share one authoritative restartable selection domain. Current route/query encoding, restoration, Map owner retention and default-sheet behavior SHALL be preserved. Stale selections and failures SHALL NOT restore cleared selection or trigger current not-found feedback. Current malformed repository identity SHALL be rejected before ViewModel content commit, leave selectedContent null and terminate with existing not-found feedback exactly once without retry. Equal route identity and equal selection owner across unrelated widget/router refreshes SHALL NOT admit a new selection intent, reset selection or refetch content. A changed route identity or selection owner SHALL resolve anew.

#### Scenario: Event followed by place
- **WHEN** an event lookup is pending and a place is selected
- **THEN** only the place lookup may commit or finish the current selection UI

#### Scenario: Place followed by event
- **WHEN** a place lookup is pending and an event is selected
- **THEN** the old place cannot overwrite the event or produce stale feedback

#### Scenario: Same-type replacement
- **WHEN** a newer event or place selection replaces a pending selection of the same type
- **THEN** it starts without waiting for or retrying the previous command

#### Scenario: Pending selection followed by default Map
- **WHEN** navigation returns to the default Map while selection is pending
- **THEN** the selection is invalidated, existing default Map/sheet behavior is restored and later old completion is ignored

#### Scenario: Wrong current identity
- **WHEN** the current repository returns content with a different identity than requested
- **THEN** no invalid ViewModel content commit occurs, selectedContent remains null, not-found feedback occurs once and no second lookup is issued

#### Scenario: Same URI while pending
- **WHEN** an unrelated widget/router refresh rebuilds the same content identity with the same selection owner while lookup is pending
- **THEN** the pending intent remains authoritative and repository call count remains one

#### Scenario: Same URI after success
- **WHEN** an unrelated widget/router refresh rebuilds the same content identity with the same selection owner after success
- **THEN** no new intent, repository refetch, selection reset or loading flicker occurs

#### Scenario: Selection owner changes
- **WHEN** route identity remains the same but the selection ViewModel owner is replaced
- **THEN** the new owner resolves that identity and prior-owner callbacks cannot affect its selection

### Requirement: Forecast widget owns current-weather initialization across updates

The current-weather widget SHALL own its initial and updated owner/target forecast requests. Its enclosing Map screen SHALL retain only owner disposal/rebinding responsibility and SHALL NOT initialize forecasts for retained selections. Replacing the Weather owner or changing semantic content identity/coordinates SHALL request current weather for the current target exactly once; unchanged owner/identity/coordinates rebuilds SHALL NOT request again. Initial/update callbacks SHALL avoid duplicate admission. When same-owner single-flight work is pending for a previous target, the widget SHALL request the latest still-desired target after that work settles and SHALL NOT present old-target success as current weather. Weather commands and their existing disposal guards SHALL retain their current semantics.

#### Scenario: Initial owner
- **WHEN** the forecast widget mounts with a content target
- **THEN** it requests current forecast once using the current coordinates

#### Scenario: Same widget receives new forecast owner
- **WHEN** the retained widget receives a new Weather owner for unchanged content/coordinates
- **THEN** the new owner receives one current-forecast request without another Map content lookup, and the widget observes the new owner only

#### Scenario: Unchanged target rebuild
- **WHEN** owner, semantic content identity and coordinates are unchanged on rebuild
- **THEN** no additional current-forecast request occurs

#### Scenario: Changed target during same-owner pending request
- **WHEN** a retained widget changes content identity or coordinates while the same owner's old request is pending
- **THEN** the latest desired target is requested once after settlement, and old-target success is not displayed as that target's weather

#### Scenario: Changed target after completion
- **WHEN** the retained widget changes content identity or coordinates after the prior request settles
- **THEN** it requests forecast for the new target once, even if the previous command completed or failed

#### Scenario: Old owner completes late
- **WHEN** the previous owner completes after replacement
- **THEN** it cannot change the new owner's state or widget observations, and no lifecycle exception occurs

#### Scenario: Update before initial deferred request
- **WHEN** owner or target changes before the initial request callback runs
- **THEN** only the current owner/target is requested once

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

### Requirement: Category bootstrap is valid before first rendering

A Category destination SHALL expose its validated initial selection before the first screen build. Initial loading SHALL NOT depend on an asynchronous filter update or notify during widget construction. Invalid slugs SHALL retain existing error routing. Rebuilding an unchanged retained owner SHALL NOT reseed filters or reload content.

#### Scenario: Single category first frame
- **WHEN** a valid single-category URI creates its owner with retrieval still pending
- **THEN** the first frame has that nonempty selection and renders safely without accessing an empty first element

#### Scenario: All categories first frame
- **WHEN** the canonical all-categories URI creates its owner
- **THEN** all supported categories are selected before rendering and the all-content retrieval path starts once

#### Scenario: Invalid category
- **WHEN** a slug is invalid, including a retired numeric slug
- **THEN** existing route error behavior is preserved and no Category content retrieval starts

#### Scenario: Retained route and replacement owner
- **WHEN** the same route rebuilds with the same owner, or a new owner is created for that route
- **THEN** the retained owner keeps its current state without another bootstrap while a replacement independently initializes from the validated URI

#### Scenario: Canonical restoration
- **WHEN** a supported canonical Category route is reconstructed after restoration
- **THEN** its new owner seeds the URI selection before its first rendering and preserves branch ancestry without claiming restoration of unsaved in-memory filter edits

### Requirement: Category filters share one latest-intent retrieval boundary

Changing Category categories or content types SHALL synchronously establish the desired selection and revoke prior retrieval publication authority. Retrieval SHALL use an immutable snapshot of both filters. Unchanged selection SHALL be a no-op; explicit refresh SHALL admit a fresh intent. Neither filter SHALL lose a change because another retrieval is pending. Previously exposed confirmed selections SHALL retain independent snapshot values after later changes.

#### Scenario: Category A then B
- **WHEN** B is selected while A retrieval remains pending
- **THEN** B can start without waiting for A and A cannot change B content, failure or loading state

#### Scenario: Category A then B then A
- **WHEN** category selection returns to A after admitting B
- **THEN** the final A is a new authoritative intent and the original A cannot publish even though its filter values match again

#### Scenario: Types and categories change together
- **WHEN** categories and types change while retrieval is pending, including in the same synchronous turn
- **THEN** the final intent contains both latest selections and no visible collection mixes data from different filter snapshots

#### Scenario: Unchanged selection and refresh
- **WHEN** an equal selection is submitted during or after retrieval, or refresh is explicitly requested
- **THEN** equal selection starts no new retrieval while explicit refresh admits a new intent even for equal filter values

### Requirement: Category publishes complete collections atomically

Category SHALL assemble selected places and events privately and publish only a complete successful authoritative result. The first application failure SHALL terminate that retrieval without publishing its partial collection. A changed filter SHALL clear prior content immediately; same-filter refresh SHALL retain the last complete collection internally on failure. Success with zero results SHALL commit an empty collection.

#### Scenario: Places succeed while events are pending
- **WHEN** place retrieval succeeds and selected event retrieval is still pending
- **THEN** the candidate places remain private and no partial collection is published

#### Scenario: First selected query fails
- **WHEN** the first selected retrieval returns an application failure
- **THEN** its Exception remains the load failure and no subsequent selected query starts

#### Scenario: Second selected query fails
- **WHEN** places succeed but selected event retrieval returns an application failure
- **THEN** no candidate places are committed and the error is distinct from successful empty content

#### Scenario: Successful empty result and retry
- **WHEN** all selected queries succeed empty, or a retry succeeds after failure
- **THEN** empty success replaces prior data with an empty collection and a successful retry atomically replaces it with the complete new collection

#### Scenario: Filter changes during private partial retrieval
- **WHEN** filters change after one query succeeded and another remains pending
- **THEN** the old private collection cannot appear under the new filters and only the new intent can publish

### Requirement: Category presentation follows the current load outcome

Category SHALL distinguish neutral/loading, nonempty/empty success and terminal failure, with retry independent of sort completion. Shared selectors SHALL preserve drafts for equal confirmed-set values and update changed fields from independent snapshots, retiring stale modal drafts. Empty drafts SHALL show explicit labels and normalize only on current modal close. Owner replacement SHALL detach observations and discard old callbacks.

#### Scenario: Loading and sort complete independently
- **WHEN** sorting completes while Category retrieval remains pending
- **THEN** the loading surface remains until the current load has a terminal outcome

#### Scenario: Failure and retained content
- **WHEN** same-filter refresh fails while an earlier complete collection remains stored
- **THEN** the failure/retry surface is displayed rather than representing retained data as new load success

#### Scenario: Empty success
- **WHEN** the authoritative load succeeds with no matching content
- **THEN** an explicit empty state is shown rather than an indefinite skeleton or a failure

#### Scenario: Modal outlives owner
- **WHEN** a selection modal is pending with a nonempty or empty draft and its Category owner is replaced or removed, including replacement with equal confirmed selections
- **THEN** its completion cannot normalize or publish to either the old owner or the replacement and the screen observes the current owner only

#### Scenario: Equal confirmed categories preserve editing
- **WHEN** a category modal has unconfirmed checkbox edits and its same-owner parent rebuilds with new wrappers containing equal confirmed categories
- **THEN** draft edits and State are preserved, no callback occurs during editing and normal close publishes the resulting selection exactly once

#### Scenario: Equal confirmed types preserve editing
- **WHEN** a type modal has unconfirmed checkbox edits and its same-owner parent rebuilds with equal confirmed type values, including different iteration order
- **THEN** the type draft is preserved without a callback until normal close, regardless of wrapper identity

#### Scenario: Changed confirmed selection updates its field
- **WHEN** a confirmed category or type set changes by value under the same owner
- **THEN** the widget updates that field from the new independent snapshot without emitting a callback or resetting the other field’s draft, and displayed labels and selection on reopening reflect the new values

#### Scenario: Confirmed changes supersede the open draft session
- **WHEN** the widget observes its open modal’s confirmed set change by value under the same owner, including A to B and back to A delivered by separate rebuilds
- **THEN** subsequent checkbox edits affect only the captured old draft, its close performs no normalization or callback, the new confirmed selection remains intact and reopening uses it; changing only the other field does not supersede the current modal, and coalesced updates observed only as equal A to A preserve the draft instead

#### Scenario: Empty drafts remain safe through rebuild
- **WHEN** all category or type checkboxes are deselected and the parent rebuilds with equal confirmed values while the modal remains open
- **THEN** the draft remains empty, labels show Nessuna categoria or Nessun tipo without accessing an empty first element, no callback or all-options reset occurs and editing can continue

#### Scenario: Empty confirmation normalizes once
- **WHEN** a still-mounted category or type modal whose draft session is still current closes normally with an empty draft
- **THEN** all supported options of that field are restored before exactly one callback and no persistent empty-filter semantics are introduced

#### Scenario: Shared Map selector preserves its existing contract
- **WHEN** the same shared selector is used by Map and its parent rebuilds during editing, including with an empty draft
- **THEN** semantic draft retention and safe labels also apply, with the existing callback signature, publication only on normal close and empty-to-all confirmation behavior preserved

### Requirement: Category publication uses the current session ordering

Category SHALL order names ascending and modification dates descending according to the current session preference. A successful retrieval SHALL apply the current preference at commit time. A later retrieval completion SHALL NOT restore an ordering captured before a newer accepted sort action. Sorting SHALL NOT require refetching content or changing filter authority.

#### Scenario: Sort during query
- **WHEN** the accepted sort changes while a query is pending and that query subsequently succeeds
- **THEN** the complete published collection uses the newly selected ordering

#### Scenario: Loaded collection is sorted
- **WHEN** an accepted sort action changes the preference with content already committed
- **THEN** current content and menu selection update optimistically before persistence completes without a new content query

### Requirement: Category sort persistence remains single-flight and truthful

Sort writes SHALL admit at most one action per lane; duplicate pending requests SHALL NOT queue or supersede. Repeating the current sort SHALL perform no write. An accepted change SHALL preserve the optimistic session ordering on persistence failure and expose the original write Result. Unexpected throws SHALL remain runtime failures. Existing repository persistence contracts SHALL remain unchanged.

#### Scenario: Persistence fails
- **WHEN** the sort repository returns an application failure
- **THEN** the sort action exposes that failure while the session order remains selected and the repository cache retains its established failure behavior

#### Scenario: Same or concurrent sort
- **WHEN** the selected sort is repeated, or another sort request arrives before the lane settles
- **THEN** no redundant write or queued request starts and the accepted action retains ownership

#### Scenario: Sort persistence throws
- **WHEN** the pending write throws a handled unexpected runtime failure
- **THEN** it remains a runtime failure with existing global reporting and does not fabricate successful persistence or change the current load outcome

### Requirement: Category disposal revokes presentation before private cleanup

Disposal SHALL immediately revoke Category commits, notifications, observations and new repository phases. Already-started reads or sort writes SHALL retain safe private settlement and existing unexpected-error reporting. Settled resources SHALL be released exactly once outside active notifier dispatch. Owner replacement SHALL NOT transfer old work publication authority to the new owner.

#### Scenario: Dispose before action entry or between query stages
- **WHEN** Category is disposed before a queued action enters or while its first query is pending
- **THEN** no not-yet-started repository phase begins and no late content or notification is published

#### Scenario: Late outcomes after navigation
- **WHEN** already-started work returns success, application failure or handled runtime failure after navigation disposes the owner
- **THEN** no old-owner presentation mutation or notification occurs, original handled runtime errors remain reportable once and cleanup avoids secondary disposed-notifier failures

#### Scenario: Reentrant disposal
- **WHEN** an owner is disposed from its own notification or an execution terminal observer
- **THEN** public authority is revoked immediately and owner/execution notifiers are released safely after dispatch and required settlement without duplicate disposal

#### Scenario: Assertion and nonterminating future
- **WHEN** pending work fails an assertion or remains physically pending indefinitely
- **THEN** assertions retain the existing fail-loud development path with settled cleanup, while physically pending work may retain private resources without regaining publication authority

### Requirement: Calendar selection immediately owns day retrieval

Every accepted calendar selection SHALL immediately update the highlighted Rome civil day and revoke prior day presentation authority. Pending SHALL show loading without an old terminal outcome. Current success SHALL show events or empty state; domain and handled runtime failure SHALL show generic error and explicit retry of the current day. Equal values after intervening selections SHALL be new intents. Annual-cache hits SHALL avoid queries; failed fallback SHALL remain retryable.

#### Scenario: Rapid day selection returns to the first value
- **WHEN** A is selected, then B, then A while earlier queries remain pending
- **THEN** the final A is selected immediately and only its retrieval can publish data, success, failure or loading state

#### Scenario: Queries complete out of order
- **WHEN** the newest day completes before an older day
- **THEN** old success or application failure cannot replace the newest outcome and an old handled runtime failure is reported once without current presentation changes

#### Scenario: Loaded day is repeated
- **WHEN** the currently selected successfully loaded day is selected again without an annual dataset change
- **THEN** no additional query or pending state starts and the previously committed day collection and terminal success remain intact, including fallback events absent from the annual dataset and successful empty fallback retrieval

#### Scenario: Failed day is repeated
- **WHEN** fallback retrieval fails and the same day is explicitly selected again
- **THEN** a fresh attempt is admitted without treating failure as a populated cache entry

#### Scenario: New day is visible before retrieval entry
- **WHEN** A completed and B is selected before B retrieval starts
- **THEN** selection and calendar highlight already show B, the modal shows pending and A content or failure is never presented as B, including before the new public snapshot arrives

#### Scenario: Current day fails terminally
- **WHEN** the current day returns an application error or handled runtime failure
- **THEN** the skeleton ends with generic error and Riprova, old content is not presented as current, domain error keeps its Exception without global reporting and runtime failure keeps original unexpected object and stack reported once

#### Scenario: Retry uses the day selected at activation
- **WHEN** Riprova is activated after a noncacheable day failure
- **THEN** a new intent uses the day selected at that moment rather than a previously captured date, can query again and renders pending then events or empty success without annual reload, owner recreation or automatic retry

#### Scenario: Annual rebase finishes pending day presentation
- **WHEN** annual success supersedes a pending day fallback with current annual-derived events or an empty collection
- **THEN** the modal settles with current grid or empty state without awaiting the obsolete query or starting an additional query

### Requirement: Annual and day calendar results share dataset authority

Annual loading SHALL bootstrap once per owner and remain single-flight. Annual success SHALL replace the annual dataset and re-evaluate the current day, revoking fallback publication against the previous dataset. Annual failure SHALL retain previous data. Successful annual-derived empty days SHALL remain eligible for explicit fallback retry.

#### Scenario: Annual data replaces pending fallback
- **WHEN** annual success supplies the selected day while an older fallback is pending
- **THEN** the new annual dataset revision rebuilds the selected-day cache and presentation, invalidates cached fallback data from the prior revision and prevents older fallback completions from overwriting it or retaining current loading

#### Scenario: Annual success has no selected-day events
- **WHEN** annual success replaces the dataset with no events on the selected day
- **THEN** the selected-day presentation can settle empty, old fallback publication is revoked and a subsequent explicit same-day selection may query again

#### Scenario: Annual reload fails
- **WHEN** an annual reload returns an application failure
- **THEN** the prior annual collection, day cache validity and day selection remain intact and explicit annual retry remains available

### Requirement: Post detail follows its route owner and terminal outcome

A Post destination SHALL load only the detail type selected by its validated id/type URI. A retained owner SHALL not rebootstrap on an unrelated rebuild. Pending or failed detail SHALL not read uninitialized content or bind weather. A handled terminal failure SHALL end loading and display an error surface. Replacement owners SHALL not inherit old completion authority.

#### Scenario: Deferred bootstrap
- **WHEN** a valid event or place route is created and detail action entry is deferred
- **THEN** the first frame renders safely while exactly the selected detail lookup is admitted

#### Scenario: Detail failure
- **WHEN** current detail returns an application error or a handled runtime failure
- **THEN** loading ends with explicit failure presentation, weather remains unbound and no uninitialized content is read; runtime failure retains global reporting

#### Scenario: Owner replacement
- **WHEN** route A is replaced by a different id or type B and A finishes late
- **THEN** B has its own detail, weather and nearby state and A cannot affect B or start later work on its disposed owner

#### Scenario: Detail recovery
- **WHEN** a new accepted detail attempt succeeds after failure
- **THEN** current content becomes available and weather binds once to the current owner, content identity and coordinates

### Requirement: Post nearby preserves ordered partial outcomes

Nearby detail retrieval SHALL remain single-flight and query events before places. An events application error SHALL not prevent the places query. Successful sides SHALL remain available in event/place order, with the first application error as the aggregate failure. Existing invalid-coordinate, deferred scheduling and retry presentation behavior SHALL be preserved.

#### Scenario: Events fail and places succeed
- **WHEN** events return an application failure and places return content
- **THEN** the aggregate remains the original events failure and the owner retains the successful places without reporting fabricated aggregate success

#### Scenario: Places fail after events succeed
- **WHEN** events succeed and places fail
- **THEN** the owner retains the events and exposes the places failure; the Post presentation retains its established failure projection and absence of a retry button

#### Scenario: Stale scheduled nearby request
- **WHEN** coordinates are invalid or the owner/content changes before the deferred callback
- **THEN** no query starts for invalid or previous content and only the current valid load identity can be requested

#### Scenario: Disposal between nearby queries
- **WHEN** the owner is disposed while events are pending
- **THEN** late events cannot publish and no places query begins

### Requirement: Sync admission controls navigation before action entry

Automatic due sync SHALL be admitted before the first frame. Sync SHALL remain single-flight; concurrent requests SHALL neither queue nor supersede. Force SHALL bypass the schedule; non-forced work SHALL recheck whether sync is due. Navigation SHALL use immediate admission state and receive a settlement refresh after that state becomes non-running.

#### Scenario: Automatic bootstrap
- **WHEN** the application starts with sync due and action entry has not yet occurred
- **THEN** navigation already treats sync as running and enters the sync destination without briefly exposing an idle destination

#### Scenario: Forced request during active sync
- **WHEN** another forced or scheduled request arrives during admitted sync
- **THEN** only the admitted synchronization runs and the rejected request causes no queued second pass or false success feedback

#### Scenario: Non-forced operation is no longer due
- **WHEN** a non-forced admitted action enters after the schedule has become satisfied
- **THEN** it settles successfully without invoking synchronization

### Requirement: Sync failures separate availability from error kind

Sync SHALL preserve application failures as Results and handled runtime failures as unexpected outcomes with original global reporting once. A current failure SHALL be fatal for navigation exactly when no successful-sync timestamp is available. Fatal state SHALL describe the current attempt and reset on a new admission or success. Assertion policy SHALL remain fail-loud.

#### Scenario: First synchronization fails
- **WHEN** an accepted sync fails with an application or handled runtime failure and no successful-sync timestamp exists
- **THEN** the sync destination remains available for explicit retry, without converting runtime failure into a domain Result

#### Scenario: Cached synchronization fails
- **WHEN** accepted sync fails with an existing successful-sync timestamp
- **THEN** failure is nonfatal, valid cached data remains available and normal return navigation is permitted

#### Scenario: Fatal retry recovers
- **WHEN** a fatal attempt is retried and succeeds
- **THEN** fatal state clears and navigation can return to the retained valid destination

### Requirement: Sync return navigation and feedback belong to the current attempt

Sync SHALL retain the internal URI and query and return to a validated destination after nonfatal settlement; unsafe return locations SHALL fall back to Home. Current nonfatal failure feedback SHALL remain visible after normal return, at most once per observed accepted attempt. Not-yet-authorized stale feedback SHALL be suppressed. Consumers SHALL observe owner replacement, detach old observations and reconcile the current outcome without rerunning sync.

#### Scenario: Detail URI is restored
- **WHEN** manual sync interrupts a valid detail or search destination and settles successfully or nonfatally
- **THEN** the retained internal URI and supported query parameters are restored under existing branch and back-navigation rules

#### Scenario: Invalid return location
- **WHEN** an idle or nonfatally settled sync destination has an unsafe or invalid return location
- **THEN** navigation returns to Home without recursive sync redirection

#### Scenario: Current nonfatal feedback survives normal return
- **WHEN** sync terminates with a domain or handled runtime nonfatal failure while its screen is the current observer and navigation normally returns to the valid preserved URI
- **THEN** one error snackbar is visible after return, normal removal of the sync screen does not revoke already-authorized feedback and runtime reporting retains the original object and stack once

#### Scenario: Retry or owner change precedes feedback authorization
- **WHEN** feedback remains pending and a new accepted retry, owner replacement or unrelated unmount supersedes the observation before authorization
- **THEN** the old callback produces no feedback or other stale action and performs no context or owner access after unmount

#### Scenario: Different attempts share one exception object
- **WHEN** two accepted attempts observed by the current consumer fail with the same Exception instance
- **THEN** each attempt can authorize one feedback, repeated rebuilds do not duplicate it and a rejected busy request creates no new attempt or feedback

#### Scenario: Retained screen receives another owner
- **WHEN** the provider replaces A with B while retaining the sync screen state
- **THEN** the screen observes the replacement, detaches A and attaches B once, ignores late A notifications and reconciles already-terminal B without starting new work; this local lifecycle guarantee does not replace the sync owner already captured by an existing router

#### Scenario: Application router and screen use the same sync owner
- **WHEN** the supported application lifecycle builds its router and provides sync state to its screen
- **THEN** both use the same owner for bootstrap, redirect, fatal retry and completion; a new session with another owner uses a coherently recreated application and router lifecycle rather than implicitly rebinding an existing router

#### Scenario: Unchanged provider and fatal failure
- **WHEN** dependencies rebuild with the same owner or its current failure is fatal
- **THEN** unchanged identity does not reset feedback deduplication or duplicate observations, and fatal failure retains its error and retry surface without nonfatal snackbar

### Requirement: Content owners revoke presentation before private settlement cleanup

Event, Post and Sync disposal SHALL immediately revoke commits, notifications and new owner-controlled action phases. Already-started sync SHALL retain its domain protocol. Settled commands SHALL release resources once outside notifier dispatch, retaining late handled-runtime reporting. Physically pending work SHALL not regain presentation authority.

#### Scenario: Dispose before deferred entry
- **WHEN** the owner is disposed after admission but before action entry
- **THEN** no repository or sync invocation begins

#### Scenario: Late Result or runtime throw
- **WHEN** started work settles after owner disposal with success, application failure or a handled runtime failure
- **THEN** no presentation mutation occurs, runtime reporting retains the original object and stack once, and private release causes no disposed-notifier failure

#### Scenario: Disposal during notifier dispatch
- **WHEN** a terminal, value or owner listener disposes the owner reentrantly, including while logically idle
- **THEN** revocation is immediate and physical notifier cleanup occurs safely outside dispatch exactly once

#### Scenario: Started synchronization outlives owner
- **WHEN** the owner is disposed after synchronization has started
- **THEN** its domain protocol can settle without owner UI notifications, cancellation claims or ViewModel intervention in persistence phases

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

### Requirement: Content Submission admission binds one immutable request
The five ordinary Content Submission operations SHALL admit one execution per operation at a time and synchronously bind its request before deferred action entry. Duplicate busy requests SHALL start no work, replace no accepted request, and imply no independent success. Consumers SHALL observe execution snapshots without bypassing request admission. Submission membership SHALL be fixed at its admission-bound arbitration position.

#### Scenario: Deferred entry cannot reinterpret removal
- **WHEN** removal is requested for an asset and list order changes before action entry
- **THEN** the accepted request still addresses the original session and digest, and an originally invalid index remains invalid

#### Scenario: Same-stack duplicate
- **WHEN** an operation is requested twice before its deferred action starts
- **THEN** one request is admitted, one action starts, and the second request has no result or feedback of its own

#### Scenario: Reentrant admission observer
- **WHEN** an admission observer replaces or disposes the owner before action entry
- **THEN** no new persistence or remote phase starts for the revoked owner

### Requirement: Content Submission execution failures retain their kind
Expected application failures SHALL retain their original Exception as Results. Unexpected throws SHALL remain terminal runtime failures with original error and stack reported once. Assertions SHALL preserve upstream fail-loud behavior. Terminal success, domain failure, runtime failure and neutral state SHALL remain distinguishable, including after retry.

#### Scenario: Serialized callback throws
- **WHEN** local lifecycle work throws a StateError or another unexpected object
- **THEN** arbitration is released, the original failure remains runtime failure, and reporting occurs once without fabricated Result.error

#### Scenario: Recovery expected platform failure
- **WHEN** Android lost-data retrieval returns or throws its expected platform failure
- **THEN** the existing recovery diagnostic is retained and the best-effort recovery completes without blocking the UI

#### Scenario: Late assertion
- **WHEN** an in-flight operation raises an assertion after owner disposal
- **THEN** it follows the upstream development error path and private settled resources are still released once

#### Scenario: Direct repository Exception remains unexpected
- **WHEN** the asset-removal repository throws an unexpected Exception directly instead of returning an application failure
- **THEN** removal terminates with the original runtime error and stack, reports it once globally, leaves runtime assets unchanged and releases local arbitration for an independent operation

#### Scenario: Direct removal throw settles after disposal
- **WHEN** an already-started removal throws that unexpected Exception after owner disposal
- **THEN** private reporting preserves the original error and stack once, with no synthetic domain failure or late public snapshot, notification or asset mutation

#### Scenario: Primary failure survives private lease release
- **WHEN** an attempt already has a primary failure and its private ownership release also encounters a failure
- **THEN** the original primary outcome and stack are preserved, the secondary is diagnosed separately and no error is normalized into fabricated application success

#### Scenario: Initialization assertion bypasses quarantine
- **WHEN** initialization awaited by a submission action encounters an AssertionError
- **THEN** the assertion retains its original fail-loud path without domain normalization or stranded initialization waiters

### Requirement: Content Submission disposal revokes new phases
Owner disposal SHALL immediately revoke new acceptance, public forwarding, presentation commits and not-yet-started persistence or remote phases. Already-started I/O SHALL be allowed to settle without a cancellation claim. Each private command SHALL remain safe for late runtime reporting and be released exactly once after settlement outside notifier dispatch.

#### Scenario: Dispose before action entry
- **WHEN** an admitted action has not entered when its owner disposes
- **THEN** no picker, initialization, persistence, upload or final request starts for that action

#### Scenario: Dispose while upload waits
- **WHEN** an upload already started and the owner disposes before its result
- **THEN** its result settles privately, no following upload or final request starts, and no later ViewModel notification occurs

#### Scenario: Late handled runtime failure
- **WHEN** work fails after owner disposal and beyond the upstream notifier teardown delay
- **THEN** the original failure is reported once without disposed-notifier errors and private resources are eventually released once

#### Scenario: Disposal inside terminal notification
- **WHEN** a terminal observer disposes the owner synchronously
- **THEN** public forwarding stops immediately and command release waits until the active dispatch and reporting have finished

### Requirement: Admin session intents share synchronous admission

Admin login and logout SHALL share one owner-local admission boundary. While either is admitted, duplicate and conflicting local intents SHALL be rejected before deferred action entry, without queuing, changing snapshots or replacing credentials. Admission SHALL remain reserved through safe execution settlement. Authentication events SHALL not reopen admission.

#### Scenario: Duplicate password intent before action entry
- **WHEN** a second login is requested before the first deferred action starts
- **THEN** only the first credentials are used and exactly one sign-in is issued

#### Scenario: Login during logout
- **WHEN** login is requested while sign-out or anonymous restoration is pending
- **THEN** login is rejected without retaining its credentials or queuing another sign-in

#### Scenario: Logout during login
- **WHEN** logout is requested while password sign-in or rejected-account cleanup is pending
- **THEN** logout is rejected and no independent sign-out is queued

#### Scenario: Duplicate logout
- **WHEN** logout is requested twice before settlement
- **THEN** one sign-out/restoration sequence runs and the original execution state is preserved

#### Scenario: Reentrant settlement
- **WHEN** a consumer requests another operation during terminal or running-state notification
- **THEN** admission cannot reopen inside an old execution stack that could clear the next execution's busy state

### Requirement: Admin credentials do not become command state

Password credentials SHALL NOT be retained in observable command parameters, snapshots, results, diagnostic wrappers, names or notifications. Only an admitted login SHALL retain transient credentials required for its SDK call; unconsumed credentials SHALL be released on revocation. Existing privacy-aware logging SHALL not add credential data, and UI failure feedback SHALL remain generic.

#### Scenario: Running and terminal password login
- **WHEN** a password login runs and succeeds or fails
- **THEN** its command parameters are empty and observable state, command diagnostics and new log context contain no password

#### Scenario: Rejected credentials
- **WHEN** another credential submission is rejected by admission
- **THEN** it neither replaces the admitted input nor becomes observable or retained command state

#### Scenario: Revoked before action
- **WHEN** the auth owner is disposed before deferred login entry
- **THEN** its pending credential reference is cleared and no sign-in starts

### Requirement: Actual Supabase session owns Admin authorization

The actual Supabase client session SHALL remain authoritative throughout authentication operations. Admin access SHALL require a non-anonymous user with admin metadata exactly true. Live auth events SHALL update routing; completions SHALL reread current session rather than install responses. A response SHALL serve only as login-attempt correlation evidence and SHALL NOT authorize cleanup or success when uncorrelated.

#### Scenario: External auth event during password request
- **WHEN** an external auth event occurs while password sign-in is pending
- **THEN** the live owner observes the actual client session immediately and a later completion cannot install its captured response as authority

#### Scenario: External identity replaces rejected account
- **WHEN** a newer identity is current before rejected-account sign-out starts
- **THEN** cleanup does not sign out that newer identity

#### Scenario: Wrong password
- **WHEN** password sign-in returns an expected authentication exception
- **THEN** it is logged and exposed as an expected Result failure, without unexpected-error reporting

#### Scenario: Non-Admin account
- **WHEN** sign-in settles with a demonstrably correlated current non-Admin attempt session
- **THEN** the live owner rechecks correlation before cleanup, attempts anonymous restoration only with no current user, and returns access denied without granting dashboard access

#### Scenario: Sign-out failure with real session remaining
- **WHEN** sign-out fails and a non-anonymous session remains current
- **THEN** the failure is logged, restoration respects the existing session, and logout exposes expected restore failure

#### Scenario: Sign-out failure after session clearance
- **WHEN** sign-out logs an expected failure after clearing the session and anonymous restoration succeeds
- **THEN** logout succeeds according to the final anonymous session

#### Scenario: Anonymous restoration fails
- **WHEN** anonymous restoration has an expected authentication failure
- **THEN** it is logged, no anonymous session is fabricated, and logout returns expected failure if final session is not anonymous

### Requirement: Rejected login cleanup requires attempt correlation

A login SHALL succeed only with a correlated current attempt session and current Admin authorization. Its SDK response SHALL supply correlation evidence, never authorization. Rejected-account cleanup SHALL require a live owner and the same correlated current non-Admin session immediately before invocation. Missing or replaced-session evidence SHALL yield expected login failure without cleanup or session replacement.

#### Scenario: Correlated Admin login
- **WHEN** response identity and session demonstrably match the current attempt session and the current user is Admin
- **THEN** login succeeds using current-session authorization without installing the response as state

#### Scenario: Correlated rejected login
- **WHEN** response A and the actual current session demonstrate the same non-Admin login attempt
- **THEN** cleanup may start once after a final live correlation check and the login remains access denied

#### Scenario: Different current Admin identity
- **WHEN** login returns A but actual current session belongs to B Admin
- **THEN** A's login reports expected session-changed failure, sign-out and anonymous restoration are not started, and B's actual Admin session alone may authorize dashboard routing

#### Scenario: Different current nonadmin identity
- **WHEN** login returns A but actual current session belongs to distinct B non-Admin
- **THEN** A's login reports expected failure with zero cleanup calls on B and no Admin authorization

#### Scenario: Missing login correlation evidence
- **WHEN** response user/session evidence is absent, inconsistent, or no longer identifies the current attempt session, even with the same user ID
- **THEN** login reports expected unverifiable-session failure without cleanup, anonymous restoration or false success, while actual client session remains authoritative

#### Scenario: Reentrant identity change before cleanup
- **WHEN** notification or logging replaces correlated A with B before sign-out invocation
- **THEN** a final correlation check after all callbacks rejects cleanup of B, with no yield or application callback between that guard and an eligible invocation

#### Scenario: External identity after cleanup entry
- **WHEN** guarded cleanup has already entered sign-out and an external event establishes B
- **THEN** the owner does not claim cancellation or atomic session protection, preserves actual B on settlement, and starts no anonymous restoration while B exists

#### Scenario: Revoked before rejected-account cleanup
- **WHEN** the owner is revoked after password completion but before cleanup invocation
- **THEN** no sign-out, restore, state publication or follow-up phase starts from the revoked owner

### Requirement: Admin navigation follows session once

Session-driven declarative redirects and pushed-login replacement SHALL preserve protected-route denial, dashboard access and Settings Back navigation. Command success SHALL NOT add a second navigation path. Logout navigation SHALL use admitted intent and captured live UI ownership before its deferred SDK action. Owner replacement SHALL revoke old callbacks and observations.

#### Scenario: Unauthorized protected route
- **WHEN** an anonymous or authenticated non-Admin user requests the dashboard
- **THEN** the dashboard is not built and the user reaches login

#### Scenario: Declarative login succeeds
- **WHEN** an Admin session is established on declarative login
- **THEN** routing reaches dashboard once despite both event and operation completion

#### Scenario: Login pushed from Settings
- **WHEN** a pushed login establishes Admin session
- **THEN** its replacement reaches dashboard once and Back still reaches Settings

#### Scenario: External sign-out on dashboard
- **WHEN** the authoritative session loses Admin access
- **THEN** protected dashboard access redirects to login without a second command-driven navigation

#### Scenario: Logout unmounts dashboard synchronously
- **WHEN** an admitted logout navigates home and authentication changes unmount the dashboard
- **THEN** no later callback accesses that widget or navigates on its behalf

#### Scenario: Auth widget owner replacement
- **WHEN** the login widget receives a replacement auth owner
- **THEN** it listens to the new owner only and old notifications cannot trigger navigation

### Requirement: Logout availability matches shared Auth admission

Logout SHALL be visibly disabled whenever the live shared Auth admission boundary cannot accept it. The callback SHALL still perform definitive admission, navigate locally to Home at most once only on acceptance and valid originating UI ownership, and use no widget/context after navigation. Rejected intent SHALL cause no sign-out, local navigation or success feedback. Auth events SHALL not create another local navigation callback.

#### Scenario: Logout unavailable during local login
- **WHEN** an external Admin event exposes the dashboard while a local login remains pending
- **THEN** compact and wide Logout controls remain disabled until shared admission safely reopens, with no sign-out or Home navigation from attempts to activate them

#### Scenario: Stale enabled logout callback
- **WHEN** a previously enabled Logout callback runs after another Auth operation reserves admission
- **THEN** definitive admission rejects it and no sign-out, local navigation or success feedback occurs

#### Scenario: Reentrant admitted logout navigation
- **WHEN** an admitted logout notifies synchronously and its originating route is replaced or unmounted
- **THEN** the callback rechecks ownership before navigating, issues no redundant Home navigation and performs no later widget access or completion-driven navigation

### Requirement: Dashboard reads and reactivation share coordinated admission

The two dashboard read lanes SHALL be independently single-flight and able to overlap. Source reactivation SHALL be admitted only with both lanes settled, and SHALL synchronously exclude external reads and duplicate reactivation through mutation and post-commit refresh. Rejected requests SHALL start no repository calls or change execution feedback. Filters SHALL remain local.

#### Scenario: Independent reads
- **WHEN** submissions and ignored-source reads are requested in normal phase
- **THEN** both may run concurrently but a duplicate in either lane is rejected

#### Scenario: Read precedes mutation
- **WHEN** reactivation is requested while either read is reserved, including before its deferred action
- **THEN** reactivation is rejected until that read has committed and safely settled

#### Scenario: Mutation precedes read
- **WHEN** either read is requested after reactivation admission, including before mutation action entry
- **THEN** it is rejected without a repository call or a new read failure snapshot

#### Scenario: Duplicate source reactivation
- **WHEN** another reactivation is requested during mutation or post-commit refresh
- **THEN** only the admitted mutation runs and its captured source identity is preserved

#### Scenario: Filter changes during operations
- **WHEN** a local status or ignored filter changes during reads, mutation or refresh
- **THEN** filtering remains local, remote responses do not restore an old filter, and phase-restricted ignored reads cannot remove the mandatory post-commit refresh

### Requirement: Reactivation success and refresh outcomes stay distinct

Successful reactivation SHALL retain resolution and pending ID privately and refresh ignored sources then submissions once while live. No pre-commit read SHALL overwrite post-commit state. Read failure SHALL retain the prior list without failing or repeating mutation. Public mutation success and pending navigation SHALL become available together only after both refresh attempts normally settle, including handled failures. Revocation SHALL prevent readiness publication.

#### Scenario: Rejected refresh before mutation commit
- **WHEN** refresh requests were rejected while reactivation was pending and the mutation then commits
- **THEN** both required post-commit reads are still admitted once and cannot be rejected by their own orchestration

#### Scenario: Successful post-commit refresh
- **WHEN** reactivation and both follow-up reads succeed
- **THEN** both lists reflect the new data, mutation success is shown and the returned pending revision can be opened

#### Scenario: Ignored-source refresh fails
- **WHEN** mutation succeeds but the ignored-source refresh returns expected or handled unexpected failure
- **THEN** ignored data is retained, submissions refresh still runs and mutation resolution and pending ID remain successful

#### Scenario: Submissions refresh fails
- **WHEN** ignored refresh succeeds but submissions refresh fails
- **THEN** the ignored commit is retained, prior submissions remain, read failure is observable and mutation success remains intact

#### Scenario: Both refreshes fail
- **WHEN** both post-commit reads fail
- **THEN** each list retains its previous data, mutation success and the retained pending link become available together after both attempts settle, and retry performs reads rather than another mutation

#### Scenario: Mutation fails
- **WHEN** the source mutation returns expected failure
- **THEN** both lists are retained, old pending navigation from the previous attempt is cleared, mutation failure is shown and no follow-up read starts

#### Scenario: Read runtime failure after commit
- **WHEN** a post-commit read throws a handled unexpected error
- **THEN** its original error and stack are globally reported once by that read, without a second report through the mutation

#### Scenario: Pending navigation during mutation
- **WHEN** source reactivation is still pending
- **THEN** public pending navigation is unavailable and an old pending link from a previous attempt cannot be used

#### Scenario: Pending navigation waits for ignored refresh
- **WHEN** mutation succeeded with a pending ID but the ignored-source refresh is pending
- **THEN** the ID is retained privately, logical reactivation remains running and no enabled pending link is exposed

#### Scenario: Pending navigation waits for submissions refresh
- **WHEN** ignored refresh has settled but submissions refresh is still pending
- **THEN** pending navigation remains unavailable regardless of the first read's outcome

#### Scenario: Pending navigation after failed refreshes
- **WHEN** both refresh attempts settle with one or both returning expected or handled runtime failure
- **THEN** successful mutation feedback and navigation to the retained pending ID become available together, without repeating mutation or requiring successful reads

#### Scenario: Revocation before navigation readiness
- **WHEN** the dashboard owner is revoked during either post-commit refresh
- **THEN** its private committed pending ID never becomes publicly navigable and no old callback can open it on a replacement owner

#### Scenario: Stale pending-link callback
- **WHEN** a previously rendered pending-link callback runs after a new mutation starts or its owner is replaced
- **THEN** it rechecks current owner, ID and navigation readiness and does not open the obsolete pending revision

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

### Requirement: Accepted dashboard refresh Futures settle privately

Each accepted dashboard refresh SHALL own an execution-correlated Future that completes normally once at safe command settlement, even after owner revocation. Revocation SHALL stop UI forwarding and new phases, not private settlement observation. Domain and handled runtime failures SHALL not be thrown or reported again through that Future. Physically nonterminating work SHALL remain pending; assertions SHALL remain fail-loud without fabricated business success.

#### Scenario: Accepted refresh settles after revocation
- **WHEN** an accepted refresh is repository-pending, its owner is revoked, then the work succeeds
- **THEN** the original Future stays pending until safe command settlement and completes normally exactly once without later state, snapshot or notification publication

#### Scenario: Revoked before refresh action entry
- **WHEN** an accepted refresh owner is revoked before deferred action entry or reentrantly during its running notification
- **THEN** no repository call starts and the original Future completes normally once through private skipped/no-I/O settlement

#### Scenario: Domain failure settles revoked refresh
- **WHEN** an accepted refresh returns an expected failure after owner revocation
- **THEN** the original Future completes normally once without public failure publication or an additional throw

#### Scenario: Runtime failure settles revoked refresh
- **WHEN** retained accepted work throws a handled runtime failure after revocation and beyond upstream deferred teardown time
- **THEN** its original error and stack are reported once by that command and the original Future completes normally without a second error/report or disposed-notifier failure

#### Scenario: Reentrant refresh settlement
- **WHEN** dispose occurs in terminal notification or competing private terminal and fallback callbacks both attempt settlement
- **THEN** the accepted Future resolves once, private resources release once after safe settlement and no revoked follow-up phase starts

#### Scenario: Assertion settles private receipt
- **WHEN** an assertion bypasses normal terminal routing in accepted refresh work
- **THEN** original fail-loud handling remains intact while the private Future settles normally once as an abnormal execution, without fabricated domain success/failure, duplicate reporting or a second internal refresh

#### Scenario: Nonterminating refresh
- **WHEN** an accepted refresh's underlying work never terminates
- **THEN** its Future and required private resources stay pending, without invented cancellation or premature disposal

#### Scenario: Internal refresh revoked
- **WHEN** owner revocation occurs while an admitted post-commit refresh is pending
- **THEN** that refresh's receipt still settles privately when work ends, but cannot authorize another read, pending-link publication or feedback on a replacement owner

### Requirement: Admin owner revocation prevents new phases

Revoking an Admin owner SHALL stop public forwarding, state commits, callbacks and new remote phases immediately. Already-started SDK or repository I/O may settle privately. Pending ordinary execution owners SHALL remain retained until settlement for safe original-error reporting and exactly-once cleanup. Assertion failures SHALL remain fail-loud and SHALL NOT become domain results.

#### Scenario: Dispose auth during SDK work
- **WHEN** the auth owner is disposed while password sign-in or sign-out is pending
- **THEN** no later local cleanup, restore, cached-session publication or notification starts from that owner, while actual client events remain authoritative for a new owner

#### Scenario: Dispose dashboard during mutation
- **WHEN** the dashboard is disposed before its in-flight remote mutation settles
- **THEN** remote commit is not fabricated as cancelled but no list refresh, pending publication or UI notification follows

#### Scenario: Dispose after mutation commit
- **WHEN** the dashboard is disposed while its first post-commit read is pending
- **THEN** its response cannot commit publicly and the second read is not started

#### Scenario: Late raw failure after disposal threshold
- **WHEN** already-started work throws a handled runtime error after owner disposal and upstream deferred teardown time
- **THEN** the retained command reports the original error and stack once without a secondary disposed-notifier error or replacement-owner feedback

#### Scenario: Synchronous listener disposes owner
- **WHEN** a running, terminal or business-state listener revokes the owner during notification
- **THEN** no next remote phase or public notification starts and private resources release exactly once after settlement

#### Scenario: Assertion failure
- **WHEN** an execution fails an assertion with upstream assertions enabled
- **THEN** the original assertion remains fail-loud, is not normal domain feedback, and settled private cleanup still occurs

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

### Requirement: Admin editor admission binds one execution synchronously

The editor SHALL reserve each accepted request and its immutable inputs before notifications or deferred execution. Same-operation duplicates and busy conflicting requests SHALL be refused without queueing, joining, replacing an accepted request or publishing a terminal result for the refused attempt. Refusal SHALL change neither desired input nor execution snapshots. Admission success SHALL NOT mean persistence success.

#### Scenario: Duplicate before deferred entry

- **WHEN** two Save requests arrive before the first action enters
- **THEN** only the first is accepted and persists its own captured fields once
- **AND** the second changes no request slot or result snapshot

#### Scenario: Conflicting mutations

- **WHEN** Save, Reject, Promote, Link, Apply, KeepCurrent, AddAsset or DeleteAsset owns the editor mutation reservation
- **THEN** all other mutation requests are refused until safe settlement
- **AND** disabled UI controls are supplementary to the editor admission check

#### Scenario: Refusal and validation failure remain distinct

- **WHEN** a busy request is refused and a later idle request fails normal validation
- **THEN** refusal leaves execution snapshots unchanged while the admitted invalid attempt produces its expected application error
- **AND** a corrected explicit retry can execute after safe settlement

### Requirement: Admin editor hydration cannot erase accepted work

Public detail loading SHALL be exclusive with other operations and SHALL refuse to replace a loaded dirty draft. A detail response SHALL hydrate only the still-current owner and draft revision. Internal resolution refresh SHALL retain the outer operation's authority without requiring public Load admission.

#### Scenario: Public load conflicts with work

- **WHEN** Load is reserved or another editor operation is reserved
- **THEN** overlapping public Load and editor work are refused in both admission orders

#### Scenario: Draft changes during load

- **WHEN** local fields change after a detail request was admitted but before its response
- **THEN** the response cannot replace the newer draft or publish a current hydration success

### Requirement: Admin editor Save success identifies the persisted draft

Save SHALL persist its admission-time field snapshot using the route's existing create/update identity. A successful response SHALL clear dirty and authorize closure only for its terminal execution ID and matching clean draft revision. A new Save admission SHALL revoke the previous closure association. Later edits SHALL be retained. Create success SHALL NOT adopt a new identity or introduce an automatic follow-up save.

#### Scenario: Newer draft while Save is pending

- **WHEN** Save persists revision A while newer revision B exists locally
- **THEN** B remains dirty and visible and the editor does not close as though B were saved
- **AND** only an explicit later Save can persist B

#### Scenario: Snapshot and original identity

- **WHEN** accepted Save inputs or nested description data are changed before deferred entry
- **THEN** the accepted immutable snapshot and original route ID determine the request
- **AND** create remains create without adopting the returned ID

### Requirement: Admin editor explicit reads publish only current context

Candidate input editing SHALL invalidate prior result authority without starting or queueing I/O. Explicit single-flight search SHALL capture current desired input only after admission. Refusal SHALL change no input, receipt or snapshot. Input, draft, target or source changes SHALL revoke obsolete read data and feedback; physical completion SHALL NOT restore candidates, incompatible preview or Apply readiness.

#### Scenario: Search input changes and returns

- **WHEN** candidate search A is pending and input changes A to B to A
- **THEN** the old A response remains obsolete despite equal final text
- **AND** a request while that lane is busy is refused; a fresh explicit request is possible after settlement

#### Scenario: Separate input edit and refused search

- **WHEN** search A is pending, input is explicitly set to B, then another search is requested
- **THEN** the setter alone invalidates A without I/O or changing its captured input
- **AND** the refused search changes nothing further, creates no receipt and adds no feedback
- **AND** after A settles, an explicit admitted search sends exactly B

#### Scenario: Obsolete candidate failures

- **WHEN** A is invalidated by desired-input editing and later returns expected error or throws a raw runtime failure
- **THEN** no stale candidates or failure feedback appear
- **AND** the original handled raw Object and stack still report once globally

#### Scenario: Input changes during mutation

- **WHEN** desired search input changes while another mutation is admitted
- **THEN** only candidate input and stale candidate presentation change, without implicit search, mutation reinterpretation or reservation release
- **AND** an explicitly admitted blank query retains the repository's null search-name semantics

#### Scenario: Target returns to A

- **WHEN** preview for A is pending and target changes A to B to A
- **THEN** its old generation cannot publish a preview or current success or enable Apply

#### Scenario: Mutation overtakes advisory read

- **WHEN** an allowed mutation is admitted while preview or candidates are pending
- **THEN** it revokes their old publication before deferred mutation entry
- **AND** their later completion cannot undo the mutation's state or source acknowledgement

#### Scenario: Current source display changes in preview

- **WHEN** an authoritative preview returns a newer source hash
- **THEN** the preview and source display update together, prior acknowledgement is revoked and unrelated older candidate context is invalidated

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

### Requirement: Admin editor navigation consumes current completion once

Editor effects SHALL consume owner/lane/execution IDs once without bind-time replay. Navigation SHALL require the current editor route and pop(true). Covered terminals SHALL have no feedback or replay. Only a current owned status dialog MAY retain a clean Save latch; coverage SHALL revoke its session permanently. Deferred closure SHALL require current route/owner/session and Save ID/revision authority; later Save admission SHALL revoke old authority. Obsolete callbacks SHALL have no effect.

#### Scenario: Save during open status dialog

- **WHEN** a matching clean Save succeeds while Publish or Reject confirmation is open
- **THEN** completion is retained without popping underneath the dialog
- **AND** dialog completion closes the editor once with true and starts no stale moderation

#### Scenario: Newer draft invalidates Save latch

- **WHEN** fields become dirty after the success captured by an open dialog
- **THEN** the old Save latch cannot close the editor or authorize confirmation of the changed draft

#### Scenario: Owner changes during dialog

- **WHEN** the screen is unmounted or receives another owner before confirmation resolves
- **THEN** its old callback neither navigates, reports feedback, admits work nor clears a newer dialog session

#### Scenario: Repeated notifications after terminal

- **WHEN** the same terminal outcome is observed again during data notifications or admission reopening
- **THEN** it causes no second snackbar or route pop

#### Scenario: Save success then error then successful retry

- **WHEN** Save A succeeds and settles under an open status dialog, B is admitted and fails, then C is admitted and succeeds
- **THEN** B admission revokes A's closure authority and B failure inherits no success
- **AND** C has its own terminal revision association; dialog completion may close once only for C, without replaying A or B feedback

#### Scenario: Superseded Save latch cannot confirm moderation

- **WHEN** an open dialog observed Save A success, then Save B was admitted and failed without changing the clean draft
- **THEN** closing that dialog neither uses A to navigate nor falls through to stale confirmed moderation
- **AND** a later same-session matching Save success may provide only its own deferred closure authority

#### Scenario: Binding to existing terminal and replacing owner

- **WHEN** a screen binds to an owner already holding a terminal outcome or replaces that owner before its pending work completes
- **THEN** the old outcome is not replayed and late old-owner work cannot cause effects on the replacement
- **AND** genuinely new terminal execution IDs on the current owner can be consumed once

#### Scenario: Covered editor consumes without visible effects

- **WHEN** a pushed page retains a live editor underneath it and Save or moderation reaches a terminal
- **THEN** the editor consumes that execution without popping the covering page or producing a snackbar
- **AND** returning to the editor does not replay the consumed terminal, while raw failures retain global reporting

#### Scenario: Covered owned dialog loses deferred authority

- **WHEN** a distinct page covers the editor's active confirmation dialog before or after a Save latch was acquired
- **THEN** that dialog session cannot navigate or confirm moderation after the covering page returns
- **AND** a Save under an uninterrupted current owned dialog still closes the editor once after confirm or cancel when its execution and revision remain authorized

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
