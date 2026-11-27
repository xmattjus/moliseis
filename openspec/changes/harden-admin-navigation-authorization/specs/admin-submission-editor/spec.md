# Admin editor authority delta

## MODIFIED Requirements

### Requirement: Auth revocation preempts exit decisions
Logout, account replacement and loss of Admin authority SHALL immediately revoke private exit effects and allow required security navigation without waiting for a dirty-exit decision, local checkpoint or physical remote completion. Obsolete dialogs SHALL be retired by exact modal identity without popping underlying pages.

#### Scenario: Logout with open dialog or checkpoint
- **WHEN** authorization is revoked while a private exit decision or checkpoint is pending
- **THEN** required security navigation proceeds immediately and the dialog can authorize no further work or route effect
- **AND** an already-started local write can settle only for its original private owner and cannot expose data to the replacement account

The same authority boundary SHALL apply from admission of a pending activation or account-qualified lookup through restoration, Save Progress and later continuations. An obsolete route SHALL NOT start or publish another activation under a replacement account.

#### Scenario: Account replacement during pending activation
- **WHEN** A's editor activation, draft lookup or staged-asset reconciliation is pending and A loses authority or B replaces A
- **THEN** A's late result cannot install, reactivate, or displace any current editor context, start detail or privileged operations, or unblock an obsolete route
- **AND** B cannot display, recover, modify or adopt A's private draft

#### Scenario: A returns after authority interruption
- **WHEN** A regains Admin access and opens the editor on a fresh authorized visit
- **THEN** account-qualified recovery can reopen A's durable checkpoint and staged assets
- **AND** old activation tokens, dialogs, pending Save Progress attempts and callbacks cannot authorize work in the fresh visit

#### Scenario: Continuous authority and authorized restoration
- **WHEN** the current continuously authorized Admin navigates or resumes supported editor or picker state
- **THEN** existing account, target, activation and attempt checks, dirty-exit rules, and durable recovery remain in effect
