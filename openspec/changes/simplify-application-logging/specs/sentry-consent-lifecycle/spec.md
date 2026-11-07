## ADDED Requirements

### Requirement: Telemetry channel acceptance follows effective consent

Consent acceptance SHALL identify acquisition and shutdown evidence separately for app reports, automatic Dart/native errors, Supabase breadcrumbs/spans and Replay. Existing persistence, deferred opt-in, bounded shutdown and networking guarantees SHALL remain intact. Local history and user-directed export SHALL remain independent of automatic telemetry consent.

#### Scenario: Disabled or unreadable consent at startup

- **GIVEN** a fresh process with stored opt-out or unreadable consent
- **WHEN** representative app, automatic error, database breadcrumb/span and Replay triggers occur
- **THEN** no automatic telemetry channel initializes or acquires new data, while local diagnostics and application networking remain available
- **AND** a voluntary export requires a separate user action and does not activate telemetry

#### Scenario: Active consent is revoked

- **GIVEN** working pre-revocation controls for each affected channel
- **WHEN** opt-out persists and effective shutdown completes
- **THEN** no new telemetry is acquired by those channels, including native errors and Replay
- **AND** draining of previously acquired telemetry is identified separately, including crash/cache recovery on later launch
- **AND** application networking and local history remain usable without an immediate-zero-traffic promise

#### Scenario: Activation is deferred or shutdown unconfirmed

- **WHEN** runtime opt-in persists, or opt-out saves but shutdown rejects or times out
- **THEN** existing deferred activation and saved-opt-out/unconfirmed-shutdown semantics remain accurate across channels
- **AND** a logger flag or facade completion does not substitute for native or Replay evidence

#### Scenario: Platform evidence is incomplete

- **WHEN** an affected channel or platform lacks a reliable runtime control or acceptance result
- **THEN** readiness evidence names the exact missing guarantee, environmental constraint and consequence, and obtains explicit owner disposition before a readiness claim
- **AND** historical passes, host platform overrides and widget flags do not become native acceptance; mandatory canonical guarantees remain required
