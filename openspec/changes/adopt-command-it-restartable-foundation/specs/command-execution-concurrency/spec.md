## Purpose

Define observable command execution, failure reporting and latest-intent ownership so asynchronous work cannot publish stale application state or commit after its owner is disposed.

## ADDED Requirements

### Requirement: Execution states distinguish never-run and failure kinds

A Result-aware command SHALL distinguish never-run/neutral, running, completed application success, expected application failure and unexpected execution failure. Expected Result.error SHALL retain its Exception without converting it to a throw. Unexpected thrown Objects SHALL be terminal execution failures with stack trace, not fabricated domain failures. A neutral null initial result SHALL NOT be interpreted as completed success.

#### Scenario: New command has no result
- **WHEN** a command has never run
- **THEN** it is neutral and neither completed nor failed

#### Scenario: Void application success
- **WHEN** an action returns a non-null successful Result whose contained value is null
- **THEN** the execution is completed success distinctly from never-run

#### Scenario: Domain and unexpected failure
- **WHEN** an action returns an expected failure or throws an unexpected Object
- **THEN** the respective domain or unexpected failure is terminal and running ends for that authoritative execution

### Requirement: Unexpected errors use the existing privacy-aware reporting boundary

Every unexpected execution failure SHALL reach the existing application logging boundary exactly once with its original Object, stack trace and only approved non-sensitive command context. This SHALL include stale failures and programming errors. Reporting SHALL respect runtime telemetry opt-out and SHALL NOT automatically include command parameters or stringify parameter-bearing wrappers. Expected application failures SHALL NOT automatically enter unexpected-error reporting.

#### Scenario: Stale failure remains diagnosable
- **WHEN** superseded physical work throws
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
- **WHEN** the authoritative execution throws an unexpected error
- **THEN** current state becomes terminal unexpected failure, running ends and global reporting occurs once

### Requirement: Cooperative cancellation and lifecycle are separate from authority

Superseding or disposing a restartable owner SHALL request cooperative cancellation when work supports it and SHALL stop public forwarding immediately. Starting the new intent SHALL NOT wait for obsolete physical work. Cancellation requested before action entry SHALL remain observable when the action begins. Public owner disposal SHALL emit no later state and allow no later application commits; private cleanup SHALL occur exactly once per settled execution without premature disposal of live work.

#### Scenario: Noncooperative future
- **WHEN** an obsolete operation ignores cancellation
- **THEN** B starts without waiting for A and A cannot publish, with private resources cleaned after A settles

#### Scenario: Progress cancellation
- **WHEN** a progress-aware execution is superseded before or during its action
- **THEN** its action observes cancellation and cancellation does not grant it publication authority

#### Scenario: Dispose during fetch
- **WHEN** the owning ViewModel disposes while work remains in flight
- **THEN** no later public result or ViewModel notification occurs, while late unexpected failures remain reportable and private settled resources are cleaned once

### Requirement: Only authoritative completion can commit asynchronous data

Migrated asynchronous actions SHALL retrieve/compute and return application Results without mutating ViewModel state after awaits. A synchronous completion observer owned by the live ViewModel SHALL perform commits only for authoritative completions. ViewModels SHALL remove completion observers before disposing execution owners and before disposing their notifier. Existing unrelated lifecycle defenses SHALL remain until equivalent regressions prove their removal safe.

#### Scenario: Superseded retrieval returns data
- **WHEN** obsolete retrieval returns content after a newer request
- **THEN** no synchronous application commit occurs for obsolete content

### Requirement: Map selection has one cross-type latest-intent domain

Map event selection, place selection and default-map/clear invalidation SHALL share one authoritative restartable selection domain. Current route/query encoding, restoration, Map owner retention and default-sheet behavior SHALL be preserved. Stale selections and failures SHALL NOT restore cleared selection or trigger current not-found feedback. Current malformed repository identity SHALL terminate with existing not-found feedback without dropped-command retry.

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
- **THEN** the current selection terminates with not-found feedback and no second lookup is issued solely to compensate command concurrency
