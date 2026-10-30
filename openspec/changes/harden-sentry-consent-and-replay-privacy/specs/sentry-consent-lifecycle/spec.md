# Spec Delta

## Purpose

Make telemetry follow durable consent without disrupting normal application networking or misrepresenting deferred activation and shutdown outcomes.

## ADDED Requirements

### Requirement: Startup resolves consent before telemetry initialization

The application SHALL resolve existing local consent before initializing telemetry. Missing settings SHALL retain the first-install default. An unreadable preference SHALL leave telemetry inactive independently of ordinary settings fallback. No duplicate persistent consent store SHALL be introduced.

#### Scenario: Stored opt-out
- **WHEN** a fresh process reads stored consent as disabled
- **THEN** telemetry is never initialized and normal application startup proceeds without reporting integrations

#### Scenario: Stored opt-in or first installation
- **WHEN** local settings load successfully with consent enabled, including the existing default for a missing row
- **THEN** telemetry initializes once before normal application work and the reporting-enabled root is mounted

#### Scenario: Settings cannot be read
- **WHEN** local settings return a read failure
- **THEN** ordinary settings defaults remain available but telemetry and custom forwarding remain inactive for that process
- **AND** a later successful opt-in only schedules activation for the next process start

#### Scenario: Local store cannot initialize
- **WHEN** local database initialization fails before consent can be resolved
- **THEN** the existing setup-error fallback remains usable and no telemetry initializes to report that failure

### Requirement: Unrelated settings writes preserve committed consent

An update to another setting SHALL NOT restore an older consent value through a stale full-settings snapshot. Expected persistence failure SHALL retain the previously committed consent, without imposing a global preference write queue or changing independent command admission.

#### Scenario: Theme write overlaps confirmed opt-out
- **WHEN** a theme update overlaps a successful opt-out
- **THEN** the updated theme and disabled consent both remain in persistent storage and committed repository state

#### Scenario: Unrelated update fails
- **WHEN** an unrelated settings update fails after opt-out was committed
- **THEN** disabled consent remains committed and durable

### Requirement: Telemetry shutdown preserves application networking

Telemetry SHALL own transport resources independently of application networking, including underlying fallback socket resources. Shutting down telemetry SHALL NOT close application-owned clients, cancel their requests or prevent subsequent Supabase, authentication, weather, image or other application HTTP operations.

#### Scenario: Runtime shutdown with application traffic
- **WHEN** telemetry closes while an application HTTP request is pending
- **THEN** that request is not cancelled by telemetry resource disposal and later application requests remain operational

#### Scenario: Fallback transport ownership
- **WHEN** telemetry and application networking use fallback HTTP transports
- **THEN** closing telemetry leaves the application's underlying socket client usable, even when the transports were created through the same factory

#### Scenario: Startup without telemetry
- **WHEN** startup resolves disabled or unreadable consent
- **THEN** application clients remain open and normal Supabase initialization and anonymous-session behavior remain available

### Requirement: Committed opt-out initiates one current-session shutdown

Consent persistence SHALL precede its effective change. Committed opt-out SHALL stop custom forwarding and initiate one application-owned SDK shutdown. New telemetry acquisition SHALL stop after effective shutdown on verified supported platforms. SDK draining of previously acquired telemetry is permitted; zero traffic immediately after the tap SHALL NOT be promised.

#### Scenario: Active SDK receives opt-out
- **WHEN** opt-out persists and remains the currently committed preference at reconciliation
- **THEN** custom forwarding stops, SDK shutdown starts, and disable success waits for shutdown settlement
- **AND** the switch's optimistic value alone does not establish effective shutdown

#### Scenario: Already inactive process
- **WHEN** opt-out persists while telemetry was never initialized or has already shut down successfully
- **THEN** reporting remains inactive without redundant SDK initialization or shutdown

#### Scenario: Pre-revocation buffer
- **WHEN** shutdown drains telemetry acquired before effective revocation
- **THEN** that delivery is distinguished from new acquisition after effective revocation and does not by itself fail acceptance

### Requirement: Opt-in is deferred until a fresh process

Runtime opt-in SHALL persist the preference without initializing or reinitializing telemetry. A process that has not initialized telemetry or has begun shutdown SHALL keep custom forwarding disabled. Navigation, resume and hot reload SHALL NOT be treated as a fresh process start. An active process SHALL NOT be forced to shut down merely by an opt-in request.

#### Scenario: Enable from an opted-out process
- **WHEN** enabled consent persists while telemetry is inactive
- **THEN** no telemetry starts in that session and the next fresh process initializes it after reading the saved preference

#### Scenario: Enable races shutdown
- **WHEN** enabled consent commits after valid shutdown has already begun
- **THEN** that shutdown continues, reporting stays inactive for the remainder of the process and the latest saved preference governs the next start

### Requirement: Shutdown uncertainty does not undo persisted consent

Shutdown observation SHALL be bounded. A detected failure, timeout or unconfirmed shutdown SHALL retain saved opt-out and disabled custom forwarding, without claiming disable success or reverting persistence. Repeated callers SHALL share the original physical shutdown rather than interpret a later no-op close as proof of completion. Late settlement SHALL NOT replay UI feedback.

#### Scenario: Shutdown rejects or times out
- **WHEN** opt-out saved successfully but shutdown throws or exceeds its observation deadline
- **THEN** the operation reports saved preference with shutdown unconfirmed, the switch remains off and the user can continue using the application

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
- **WHEN** the current admitted opt-out persists and required shutdown settles successfully under the validated platform behavior
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

### Requirement: Native acceptance is separate from presentation acceptance

Android and iOS acceptance SHALL verify actual shutdown and Replay behavior using synthetic identities and an isolated telemetry destination. Widget/flag assertions and a Dart facade enabled flag SHALL NOT establish native success. Buffered pre-revocation delivery SHALL be distinguished from new post-shutdown capture, including queued data observed after a later launch.

#### Scenario: Automatic capture after effective shutdown
- **WHEN** controlled framework, unhandled-Dart and native-error probes occur after successful shutdown on each native platform
- **THEN** no new report from those probes is acquired or delivered under the agreed shutdown contract and unrelated application networking remains functional

#### Scenario: Native shutdown cannot meet acceptance
- **WHEN** controlled native verification shows continued new capture or an unobservable failure invalidates the required claim
- **THEN** immediate-disable release acceptance remains unmet, evidence identifies the failing path and a bounded design correction is reviewed before release
- **AND** a restart message alone is not accepted as the privacy fix
