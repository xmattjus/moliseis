## Purpose

Ensure canonical event instants remain lossless and event synchronization, browsing, editing, and promotion expose one coherent temporal state under the current authoritative backend date contract.

## ADDED Requirements

### Requirement: Synchronization removes an obsolete event end
When a synchronized event no longer has an end instant, the system SHALL clear any previously persisted local end instant while preserving nullable values that were not part of an update.

#### Scenario: Remote range becomes start-only
- **WHEN** an existing local event has an end instant and a synchronization payload for that event has no end instant
- **THEN** the merged and persisted event has no end instant and is no longer presented or queried as a ranged event

### Requirement: Persisted event dates use only the canonical contract
The Flutter event path SHALL consume persisted `start_date` and `end_date` values according to the current authoritative backend contract. A nullable end SHALL remain supported for a canonical start-only event, but the system SHALL NOT add compatibility parsing, coercion, normalization, repair, or migration behavior for persisted date values that violate that contract.

#### Scenario: Canonical start-only event is loaded
- **WHEN** a persisted event has a valid start instant and a null end under the current backend contract
- **THEN** the event is loaded as start-only without synthesizing or retaining an end

#### Scenario: Persisted dates violate the contract
- **WHEN** persisted event dates are malformed, end-only, inverted, or otherwise outside the current backend contract
- **THEN** they are treated as contract violations rather than supported historical input, and no compatibility fallback or repair behavior is required

### Requirement: Selected-day events follow the current yearly data
The selected-day event result SHALL be recomputed or invalidated whenever a successful current-year load replaces the underlying event set, and an older asynchronous date result SHALL NOT leave the selected day stale after newer yearly data is available.

#### Scenario: Date request completes before initial yearly load
- **WHEN** the selected-day request first returns no events and the current-year load then returns an event on that same selected day
- **THEN** the selected-day result exposes the event without requiring the user to select another date

#### Scenario: Yearly reload changes the selected day
- **WHEN** a successful current-year reload adds, replaces, or removes events for the already selected day
- **THEN** the selected-day result reflects the reloaded set, and a same-day request cannot return solely because a stale date-cache marker matches

### Requirement: Admin event promotion performs ordered local temporal prevalidation
The admin editor SHALL apply the existing moderation eligibility guard to the currently loaded submission before performing target-specific validation. When that guard succeeds and the requested promotion target is `event`, the editor SHALL validate the loaded temporal values against the requirements of the requested event promotion target, regardless of whether the loaded submission is currently represented as an event. It SHALL publish the corresponding temporal issue and reject locally when those values are not persistence-ready. Database promotion validation SHALL remain authoritative for requests that reach the backend.

#### Scenario: Submission without event dates is requested for event promotion
- **WHEN** a normally loaded, clean, pending admin submission has no event dates and promotion is requested with `event` as the target
- **THEN** the moderation guard passes first, target-specific event validation reports the missing-start issue, the command returns a local error, and the promotion repository is not invoked

#### Scenario: Valid submission is promoted as an event
- **WHEN** a clean, loaded, pending admin submission has persistence-ready event temporal data and promotion is requested with `event` as the target
- **THEN** the moderation guard passes before target-specific event validation, the editor invokes the promotion repository, and the backend continues to enforce transactional readiness checks
