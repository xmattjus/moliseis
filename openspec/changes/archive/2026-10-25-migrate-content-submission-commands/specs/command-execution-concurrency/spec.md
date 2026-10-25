## ADDED Requirements

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
