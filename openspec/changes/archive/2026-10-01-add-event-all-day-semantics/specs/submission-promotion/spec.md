## ADDED Requirements

### Requirement: Event promotion copies temporal mode atomically
Promotion to an event SHALL read the source temporal mode and dates from the same locked submission snapshot and copy them without reinterpretation into the published event within the existing atomic promotion operation. Existing category, start, chronology, asset, authorization, and promotion-replay rules SHALL remain authoritative. Promotion SHALL NOT infer all-day mode from midnight or discard true mode because the end is null.

#### Scenario: Single-day all-day submission is promoted
- **WHEN** a publishable pending submission has true mode, canonical start, and null end and event promotion succeeds
- **THEN** the published event has true and the identical start/null-end values, and its linkage and media commit atomically

#### Scenario: Multi-day all-day submission is promoted
- **WHEN** a publishable true-mode submission has a canonical final-day end
- **THEN** the published event retains the identical flag and inclusive temporal range

#### Scenario: Timed midnight is promoted unchanged
- **WHEN** a publishable timed submission starts at real midnight
- **THEN** the published event retains false and the original dates

#### Scenario: Existing failure or replay does not create another event
- **WHEN** promotion fails a readiness check or a linked submission is promoted again
- **THEN** existing atomic failure or already-promoted behavior applies without a new event, media set, or temporal reinterpretation
