## MODIFIED Requirements

### Requirement: Progress navigation reflects operation state without owning draft policy
The dedicated progress route SHALL render the shared submission operation state and SHALL NOT independently checkpoint, restore, clear, rotate, or delete the draft/session in response to its navigation buttons. Navigation actions SHALL delegate any removal of the parent form route to the central form-exit policy. An ordinary failure SHALL expose `Riprova` only when the current derived immediate-manual-retry semantic is true. A non-retryable ordinary failure SHALL omit `Riprova` and SHALL expose a return-to-form action that removes only the progress route so the user can review or correct the preserved session. Existing Back and Home recovery behavior SHALL remain available for ordinary failures. The confirmed-remote-success finalization state SHALL remain governed by its separate finalization-only recovery contract.

#### Scenario: Running progress blocks every back path
- **WHEN** submission or required successful-session finalization is running
- **THEN** progress UI is shown, AppBar back is unavailable, system and predictive back cannot remove the route, no exit action is available, and another submission cannot start

#### Scenario: Restored idle progress returns to editing
- **WHEN** the progress route is restored while the runtime submission Command is idle
- **THEN** Back or `Torna al modulo` removes only the progress route, preserves editable and durable work, and does not submit or clear automatically

#### Scenario: Remote failure back preserves the session
- **WHEN** an ordinary submission attempt fails and the user activates Back
- **THEN** only the progress route is removed and the same draft identity, form data, and staged assets remain available for editing regardless of retry classification

#### Scenario: Remote failure retry reuses the session
- **WHEN** an ordinary submission failure is classified as immediately retryable and the user activates `Riprova`
- **THEN** the existing submission Command executes again for the same draft/session without creating or pushing another progress route, and retry-safe uploaded/staged assets retain their existing reuse behavior

#### Scenario: Non-retryable failure has no immediate retry
- **WHEN** an ordinary submission failure is permanent or unclassified
- **THEN** `Riprova` is absent and a `Torna al modulo` action is available

#### Scenario: Non-retryable recovery returns to the form safely
- **WHEN** the user activates `Torna al modulo` for a non-retryable ordinary failure
- **THEN** only the progress route is removed, no submission or clear is executed, and the same draft identity, form data, and staged assets remain available for review or correction

#### Scenario: Remote failure home preserves recoverability
- **WHEN** an ordinary submission attempt fails and the user activates `Torna alla home`
- **THEN** no destructive progress-screen cleanup occurs, any dirty parent-form exit is decided by the central form-route policy, and the failed draft/session remains recoverable unless that central policy explicitly checkpoints or restores its form edits

#### Scenario: Successful actions only navigate
- **WHEN** local finalization has succeeded and the user activates Back or `Nuovo suggerimento`
- **THEN** only the progress route is removed and the revealed form exposes a clean new submission session

#### Scenario: Successful home leaves no completed draft
- **WHEN** local finalization has succeeded and the user activates `Torna alla home`
- **THEN** navigation removes the Content Submission route without performing button-owned cleanup and no completed draft/session remains active for later restoration
