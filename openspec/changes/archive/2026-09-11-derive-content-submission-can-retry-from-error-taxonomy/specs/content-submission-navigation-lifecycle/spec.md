## MODIFIED Requirements

### Requirement: Progress navigation reflects operation state without owning draft policy
The dedicated progress route SHALL render the shared submission operation state and SHALL NOT independently checkpoint, restore, clear, rotate, or delete the draft/session in response to its navigation buttons. Navigation actions SHALL delegate any removal of the parent form route to the central form-exit policy.

The progress route SHALL expose `Riprova` only when the current derived semantic proves that executing the existing submission Command immediately is safe. During the client-first rollout, no ordinary failure satisfies that policy because the client must support a legacy non-idempotent final-submit server and the existing upload/preparation boundaries provide no feature-owned terminal safe-retry discriminator. Every ordinary failure SHALL therefore omit `Riprova`, keep Home and existing Back recovery available, and expose `Torna al modulo`, which removes only the progress child route and preserves the session. Confirmed remote success with incomplete local finalization SHALL retain its separate `Riprova` action and navigation block; that action SHALL remain local-finalization-only.

#### Scenario: Running progress blocks every back path
- **WHEN** submission or required successful-session finalization is running
- **THEN** progress UI is shown, AppBar back is unavailable, system and predictive back cannot remove the route, no exit action is available, and another submission cannot start

#### Scenario: Restored idle progress returns to editing
- **WHEN** the progress route is restored while the runtime submission Command is idle
- **THEN** Back or `Torna al modulo` removes only the progress route, preserves editable and durable work, and does not submit or clear automatically

#### Scenario: Remote failure back preserves the session
- **WHEN** an ordinary submission attempt fails and the user activates Back
- **THEN** only the progress route is removed and the same draft identity, form data, and staged assets remain available for editing

#### Scenario: Remote failure retry reuses the session
- **WHEN** the user returns to the form after an ordinary failure and later starts another submission through the existing validated form transition
- **THEN** the current logical session retains its existing `client_submission_id` and staged assets, while the failed progress route itself performs no immediate replay and pushes no duplicate form route

#### Scenario: Remote failure home preserves recoverability
- **WHEN** an ordinary submission attempt fails and the user activates `Torna alla home`
- **THEN** no destructive progress-screen cleanup occurs, any dirty parent-form exit is decided by the central form-route policy, and the failed draft/session remains recoverable unless that central policy explicitly checkpoints or restores its form edits

#### Scenario: Successful actions only navigate
- **WHEN** local finalization has succeeded and the user activates Back or `Nuovo suggerimento`
- **THEN** only the progress route is removed and the revealed form exposes a clean new submission session

#### Scenario: Successful home leaves no completed draft
- **WHEN** local finalization has succeeded and the user activates `Torna alla home`
- **THEN** navigation removes the Content Submission route without performing button-owned cleanup and no completed draft/session remains active for later restoration

#### Scenario: Ordinary failure has no immediate retry
- **WHEN** submission stops with any pre-acknowledgement local, preparation, upload, final-submit, malformed-response, transport, or unknown failure
- **THEN** `Riprova` is absent while Home, Back, and `Torna al modulo` are available

#### Scenario: Non-retryable recovery returns to the form safely
- **WHEN** the user activates `Torna al modulo` for an ordinary failure
- **THEN** only the progress route is removed, no submission or clear is executed, and the same draft identity, form data, and staged assets remain available for review or correction

#### Scenario: Finalization failure retains only local retry
- **WHEN** remote success is confirmed but local finalization stops with an error
- **THEN** `Riprova` remains available, Back and Home remain unavailable, and activating retry repeats no checkpoint, Cloudinary upload, or final `submit-content` request
