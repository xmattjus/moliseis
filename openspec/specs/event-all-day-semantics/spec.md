# event-all-day-semantics Specification

## Purpose

Represent events whose civil date is known but whose meaningful start time is unavailable, preserving that meaning through editing, persistence, import, synchronization, and display.

## Requirements

### Requirement: All-day mode describes unavailable meaningful start time
`allDay=true` SHALL mean that the event date is known and no meaningful start time is available to display. It SHALL NOT assert that an event occupies the whole day. The mode SHALL be explicit; neither a midnight timestamp nor an absent final time SHALL imply it. `allDay=false` SHALL preserve existing timed-event semantics, including a real midnight start.

#### Scenario: Real midnight remains timed
- **WHEN** a source or editor provides a meaningful midnight start with `allDay=false`
- **THEN** the event remains timed and midnight remains a displayable start time

#### Scenario: Timed start has only a final civil date
- **WHEN** an event has a meaningful initial time and only a final civil date
- **THEN** it retains `allDay=false`, the final bound is the final Rome microsecond of that date, and no real final clock time is inferred or newly displayed

### Requirement: All-day intervals use inclusive Rome civil boundaries
Every all-day civil date SHALL use Europe/Rome independently of device timezone. The persisted start SHALL be the first instant of the initial Rome day. An omitted final date SHALL produce a null end and logical membership in the entire initial civil day. A supplied final date on or after the initial date SHALL produce the final microsecond of that Rome day as its inclusive end. Normalization SHALL respect DST and SHALL NOT replace the final microsecond with the next day's start.

#### Scenario: Single-day event has no distinct final date
- **WHEN** an all-day event supplies `2026-10-12` and no final date
- **THEN** its start is `2026-10-11T22:00:00Z`, its end is null, and its civil-day membership is 12 October in Europe/Rome

#### Scenario: Multi-day event includes its final day
- **WHEN** an all-day event supplies `2026-10-12` through `2026-10-14`
- **THEN** its start is `2026-10-11T22:00:00Z` and its end is `2026-10-14T21:59:59.999999Z`

#### Scenario: Explicit same-day final date is valid
- **WHEN** an all-day event supplies the same initial and final civil date
- **THEN** its stored end represents the supplied final date with that day's inclusive final microsecond

#### Scenario: DST days retain their true civil length
- **WHEN** all-day bounds are normalized for 29 March 2026 or 25 October 2026
- **THEN** the respective Rome civil intervals have 23 or 25 hours and retain exact inclusive final-microsecond precision

### Requirement: Temporal mode survives remote and local data boundaries
Event and submission domain values SHALL expose a non-null boolean mode. Remote decoding, mapping, local cache persistence, repository access, and synchronization SHALL retain the mode without reinterpretation. Updating only the remote mode SHALL advance the existing remote modification marker and propagate through the existing replacement rules while preserving client-owned saved state. Cache schema evolution SHALL preserve existing identities, data, and saved state, with false for historical records.

#### Scenario: Promotion result reaches the local event cache
- **WHEN** an all-day published event is fetched and synchronized
- **THEN** its domain, remote, and cached representations retain true and the same normalized dates

#### Scenario: Flag-only remote update preserves a saved event
- **WHEN** a saved local event receives a newer remote record differing only in temporal mode and its modification marker
- **THEN** the cached event adopts the new mode and remains saved

#### Scenario: Prior cache opens under the new model
- **WHEN** a cache created by the previous schema is opened by the updated app
- **THEN** existing events remain readable with false mode and their prior saved state

### Requirement: Editors retain civil dates across mode transitions
Public and Admin submission editors SHALL offer “Senza orario” through the same event-editing semantics. Enabling it SHALL retain initial/final civil dates, discard the meaningful start-time selection, and materialize canonical Rome bounds when dates permit. Disabling it SHALL retain both civil dates, clear the resolved start, require a newly selected time, and never restore an earlier time or treat technical midnight as real. Selecting the new start time SHALL reconstruct a retained final-day bound using existing timed semantics. Disabled event mode SHALL have no persistible temporal data and false all-day mode.

#### Scenario: Timed editor switches to unavailable start time
- **WHEN** an editor with a timed start and a final civil date enables “Senza orario”
- **THEN** both civil dates remain, the previous time ceases to be meaningful, and the persistible bounds use Rome day boundaries

#### Scenario: All-day editor switches back to timed
- **WHEN** the editor disables “Senza orario”
- **THEN** both civil dates remain, the start is unresolved and invalid for timed submission until a new time is selected, and no old or technical time is selected automatically

#### Scenario: New time resolves the retained range
- **WHEN** a valid new start time is selected after switching back to timed
- **THEN** the editor retains the initial civil date and rebuilds the final bound from the retained final civil date

#### Scenario: Non-event editor clears temporal data
- **WHEN** event mode is disabled in a submission editor
- **THEN** its domain draft has false mode and no persistible temporal values

### Requirement: Admin editing retains the persisted mode
Admin read/create/update results SHALL expose the stored temporal mode so later editing preserves it. Admin temporal input SHALL follow `event-temporal-input-validity`; existing pending-only, readiness, authorization, and moderation guarantees remain in force. No new published-event editing path is introduced.

#### Scenario: Admin reload preserves the selected mode
- **WHEN** Admin loads a saved date-only submission or receives a successful create/update result
- **THEN** its editor retains the stored mode and dates without reinterpreting the technical start as a meaningful clock time

### Requirement: Import adapters own source interpretation
An import adapter SHALL explicitly decide whether a source provides a meaningful start time; the interpreted source values SHALL cross the shared normalization contract owned by `event-temporal-input-validity`. Existing EventiMolise imports SHALL remain timed and retain their existing end parsing. Source ingestion SHALL use provider-scoped strong identity as defined by external-event-provenance-moderation; Rome-day/title/city similarity SHALL remain advisory candidate evidence only and SHALL NOT suppress provenance persistence. The prepared/import persistence contract SHALL support date-only single-day, timed single-day, date-only multi-day, and timed-start/final-date-only events without another schema, domain, cache, or display change. No new live provider is required. Multiple provider identities MAY link through moderation to one canonical Event without changing temporal interpretation.

#### Scenario: Current EventiMolise input stays timed
- **WHEN** a currently supported EventiMolise source row is prepared and persisted
- **THEN** its mode is explicitly false, its time interpretation and end handling remain unchanged, and repeated appearances converge through strong source identity; the Rome start day remains available for advisory moderation matching

#### Scenario: Date-only adapter fixture uses the existing pipeline
- **WHEN** a test adapter supplies a single civil date or an initial/final civil-date pair without a meaningful start time
- **THEN** the adapter selects true and the existing prepared/import contract carries the resulting date-only event without a new provider framework

#### Scenario: Timed adapter fixture has a final date without time
- **WHEN** a test adapter supplies a meaningful start time and only a final civil date
- **THEN** the adapter selects false and retains the known start-time meaning under the mixed-precision contract

### Requirement: All-day display omits synthetic times
Every event display that currently shows a start time SHALL suppress that time for true mode and derive the displayed civil date in Europe/Rome. It SHALL NOT synthesize “00:00”, “24 ore”, or “Tutto il giorno”. Timed rendering and current final-date visibility SHALL remain unchanged; no final-time display is introduced.

#### Scenario: Foreign device timezone does not shift the date
- **WHEN** a device outside Europe/Rome displays an all-day event for 12 October 2026
- **THEN** it displays 12 October without a start-time label, even if the stored UTC start falls on 11 October

#### Scenario: Timed display retains a real time
- **WHEN** the same display receives a timed event, including a real midnight start
- **THEN** its existing date/time rendering remains in force

### Requirement: Existing discovery behavior is preserved without speculative expiration infrastructure
Introducing all-day mode SHALL preserve start-based sorting and the upcoming and overlap contracts owned by `event-temporal-integrity`. A focused audit SHALL identify any actual current-time expiration consumer that treats a single-day all-day event as ended at its technical midnight start; only such a demonstrated consumer SHALL receive a minimal owning-layer correction to respect logical Rome-day membership. No preventive effective-end abstraction or expression index is introduced.

#### Scenario: Sorting and upcoming retain the current contract
- **WHEN** all-day events enter existing discovery paths
- **THEN** start ordering and the established upcoming and overlap rules remain unchanged

#### Scenario: Actual expiration consumer respects logical day membership
- **WHEN** the audit finds a consumer that expires a start-only all-day event during its initial Rome day
- **THEN** a focused correction prevents that demonstrated error without redesigning upcoming or adding a general effective-end API

### Requirement: Previous decoder tolerates the additive remote field
A previously published or immediately preceding supported DTO/mapper shape SHALL tolerate an additional `all_day` field in a remote event row. Ignoring unknown fields satisfies this technical compatibility requirement; older clients need not understand all-day semantics and their display of technical midnight is accepted. No forced update, minimum-version rule, remote config, version routing, or full old-client startup/synchronization certification is required.

#### Scenario: Previous decoder receives an extra remote key
- **WHEN** a representative previous decoder processes a valid remote event row with the additional `all_day` key
- **THEN** decoding succeeds without requiring semantic recognition of the flag
