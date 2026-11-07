## ADDED Requirements

### Requirement: Consent acceptance follows supported SDK lifecycle boundaries

Persisted consent, first-install defaults, unreadable-preference handling, deferred opt-in, bounded public SDK shutdown observation and independent application networking SHALL remain unchanged. Acceptance SHALL distinguish saved preference, application forwarding, observable close settlement and unverified native internal state.

#### Scenario: Startup consent controls initialization

- **WHEN** a fresh process reads stored opt-out or unreadable consent
- **THEN** telemetry is not initialized and application networking remains usable
- **AND** first-install defaults and deferred opt-in retain their established semantics without a second consent store
- **AND** Debug-only Talker diagnostics and explicit developer export remain consent-independent; Profile and Release provide no Talker capabilities

#### Scenario: Runtime opt-out is observed

- **WHEN** opt-out persists while the SDK is active
- **THEN** custom forwarding stops and callers share bounded observation of the public SDK close operation
- **AND** previously acquired buffered delivery is distinguished from new work; immediate zero traffic and independently verified native shutdown are not promised
- **AND** a rejection or timeout retains saved opt-out and unconfirmed-shutdown feedback
- **AND** no private native hook, custom shutdown/recovery implementation or new native probe campaign is required

## MODIFIED Requirements

### Requirement: Committed opt-out initiates one current-session shutdown

Consent persistence SHALL precede its effective change. Committed opt-out SHALL stop custom forwarding and initiate one application-owned SDK shutdown. The application SHALL use public `Sentry.close` without native customization and stop new application forwarding. Successful shutdown observation SHALL mean settlement of that supported SDK operation, not independent proof of inaccessible native internal state. No new native acquisition probe or custom shutdown guarantee is required for this change. SDK draining of previously acquired telemetry is permitted; zero traffic immediately after the tap SHALL NOT be promised.

#### Scenario: Active SDK receives opt-out
- **WHEN** opt-out persists and remains the currently committed preference at reconciliation
- **THEN** custom forwarding stops, SDK shutdown starts, and disable success waits for shutdown settlement
- **AND** the switch's optimistic value alone does not establish observed SDK shutdown

#### Scenario: Already inactive process
- **WHEN** opt-out persists while telemetry was never initialized or has already shut down successfully
- **THEN** reporting remains inactive without redundant SDK initialization or shutdown

#### Scenario: Pre-revocation buffer
- **WHEN** shutdown drains telemetry acquired before effective revocation
- **THEN** that delivery is distinguished from new acquisition after effective revocation and does not by itself fail acceptance

### Requirement: Shutdown uncertainty does not undo persisted consent

Shutdown observation SHALL be bounded. A detected failure, timeout or unconfirmed shutdown SHALL retain saved opt-out and disabled custom forwarding, without claiming disable success or reverting persistence. Repeated callers SHALL share the original SDK close Future rather than interpret a later no-op close as proof of completion. Late settlement SHALL NOT replay UI feedback.

#### Scenario: Shutdown rejects or times out
- **WHEN** opt-out saved successfully but shutdown rejects with an `Exception` or exceeds its observation deadline
- **THEN** the operation reports saved preference with shutdown unconfirmed, the switch remains off and the user can continue using the application

#### Scenario: Shutdown rejects with an unexpected raw Error
- **WHEN** opt-out saved successfully but shutdown rejects with an unexpected raw `Error`
- **THEN** the error SHALL retain unexpected command-error reporting rather than being normalized into `shutdownUnconfirmed`
- **AND** when committed opt-out and unconfirmed shutdown remain current, eligible Settings feedback SHALL still distinguish the saved preference from the unconfirmed observed SDK shutdown through its existing fallback

#### Scenario: Repeated close while the first is pending
- **WHEN** another reconciliation observes opt-out during pending shutdown
- **THEN** no overlapping shutdown starts and the second caller cannot report success merely because a separate close call would return immediately

#### Scenario: Late settlement after timeout
- **WHEN** a timed-out shutdown later settles
- **THEN** application lifecycle state can reconcile without reviving the timed-out caller's notification or re-enabling telemetry

### Requirement: Settings feedback distinguishes preference and effective state

Enable and disable success SHALL use the existing Snackbar component with identical styling and eligibility rules. Feedback SHALL belong to the caller's admitted operation and still-current mounted owner and committed intent. Persistence failure SHALL restore presentation from committed preference; shutdown uncertainty SHALL instead retain saved opt-out and show error feedback. Unexpected failures SHALL retain existing reporting semantics.

#### Scenario: Enable succeeds
- **WHEN** the current admitted opt-in persists successfully
- **THEN** one success Snackbar says "La segnalazione degli errori sarà attivata al prossimo avvio dell'app."

#### Scenario: Disable succeeds
- **WHEN** the current admitted opt-out persists and required shutdown settles successfully through the supported SDK close observation
- **THEN** one success Snackbar says "La segnalazione di nuovi errori è stata disattivata."

#### Scenario: Persistence fails
- **WHEN** either preference write returns an expected persistence failure
- **THEN** committed consent and effective reporting remain unchanged, optimistic presentation is restored and an eligible current caller receives error feedback without a success Snackbar

#### Scenario: Preference saved but shutdown unconfirmed
- **WHEN** opt-out persists but shutdown cannot be confirmed within the bounded observation
- **THEN** an eligible current caller receives a Snackbar explaining that the preference was saved, current shutdown was not confirmed and opt-out applies at the next full app start
- **AND** the saved preference is not rolled back or represented as a persistence failure

#### Scenario: Superseded or revoked feedback owner
- **WHEN** a caller is disposed, unmounted, replaced, refused admission or superseded before feedback authorization
- **THEN** it displays no stale success or error Snackbar while application-owned consent reconciliation remains eligible

## REMOVED Requirements

### Requirement: Native acceptance is separate from presentation acceptance

**Reason**: The owner-approved final scope withdraws new Android/iOS framework/native-crash, relaunch and shutdown campaigns as acceptance gates. The official SDK remains unchanged, and inaccessible native state is an accepted SDK limitation rather than a custom application guarantee.

**Migration**: Use the supported lifecycle/application tests above, preserve historical evidence with its provenance and disclose the accepted SDK limitations in the change design. Do not claim native-envelope sanitization, native crash recovery or internal shutdown verification from facade, widget or Dart transport tests.
