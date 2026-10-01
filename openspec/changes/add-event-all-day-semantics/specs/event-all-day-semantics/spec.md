## Purpose

Represent events whose civil date is known but whose meaningful start time is unavailable, preserving that meaning through editing, persistence, import, synchronization, and display.

## ADDED Requirements

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
- **THEN** normalization accepts it and represents the supplied final date with that day's inclusive final microsecond

#### Scenario: DST days retain their true civil length
- **WHEN** all-day bounds are normalized for 29 March 2026 or 25 October 2026
- **THEN** the respective Rome civil intervals have 23 or 25 hours and retain exact inclusive final-microsecond precision

### Requirement: Persisted mode is explicit and defaults to timed
Submissions and events SHALL persist a non-null boolean `all_day` defaulting to false. Existing remote and local records SHALL acquire false without retroactive classification. A submission with `all_day=true` SHALL require a non-null start at the database boundary on both insert and update. Existing start/end chronological constraints and the published-event required-start rule SHALL remain authoritative. Supported writers SHALL normalize before persistence without silent temporal correction triggers.

#### Scenario: Historical midnight does not become all-day
- **WHEN** the additive schema is applied to an existing row whose start is midnight
- **THEN** its mode is false and its dates are not reclassified or rewritten

#### Scenario: Missing all-day start is rejected structurally
- **WHEN** a submission is inserted or updated with `all_day=true` and null start
- **THEN** the database rejects it even when its end is null

#### Scenario: Existing interval rules remain enforced
- **WHEN** either mode is persisted with an inverted interval or a submission has an end without a start
- **THEN** the existing database temporal invariants reject the row

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
- **THEN** its persistible mode is false and all temporal request values are null

### Requirement: Admin submission operations preserve the temporal mode
The existing Admin full-input create/update contract SHALL explicitly include `all_day`, `start_date`, `end_date`, `start_calendar_date`, and `end_calendar_date`. Timed and all-day inputs SHALL obey the shared public temporal grammar and normalization; non-event input SHALL contain false and null temporal fields. Admin read/create/update results SHALL carry the stored flag so later edits do not lose it. Existing pending-only, readiness, authorization, and moderation guarantees SHALL remain intact; no new published-event editing path is required.

#### Scenario: Admin creates a date-only event submission
- **WHEN** Admin creates an otherwise valid input with true, civil dates, and null request timestamps
- **THEN** it stores the canonical timestamps and true mode and returns that mode for hydration

#### Scenario: Admin updates between modes
- **WHEN** Admin saves a pending submission after a supported mode transition
- **THEN** the existing full-input update persists normalized dates and mode together without retaining values from the other input format

### Requirement: Import adapters own source interpretation
An import adapter SHALL explicitly decide whether a source provides a meaningful start time; shared temporal normalization SHALL produce the persistible start, optional end, and mode. Existing EventiMolise imports SHALL remain timed and retain their existing end parsing and Rome-day deduplication behavior. The prepared/import persistence contract SHALL support date-only single-day, timed single-day, date-only multi-day, and timed-start/final-date-only events without another schema, domain, cache, or display change. New live providers and cross-provider deduplication are outside this change.

#### Scenario: Current EventiMolise input stays timed
- **WHEN** a currently supported EventiMolise source row is prepared and persisted
- **THEN** its mode is explicitly false, its time interpretation and end handling remain unchanged, and its deduplication key still uses the Rome start day

#### Scenario: Date-only adapter fixture uses the existing pipeline
- **WHEN** a test adapter supplies a single civil date or an initial/final civil-date pair without a meaningful start time
- **THEN** shared normalization produces true and canonical bounds, and the existing importer write preserves them

#### Scenario: Timed adapter fixture has a final date without time
- **WHEN** a test adapter supplies a meaningful start time and only a final civil date
- **THEN** it produces false, retains the start instant, and uses the inclusive final Rome day bound

### Requirement: All-day display omits synthetic times
Every event display that currently shows a start time SHALL suppress that time for true mode and derive the displayed civil date in Europe/Rome. It SHALL NOT synthesize “00:00”, “24 ore”, or “Tutto il giorno”. Timed rendering and current final-date visibility SHALL remain unchanged; no final-time display is introduced.

#### Scenario: Foreign device timezone does not shift the date
- **WHEN** a device outside Europe/Rome displays an all-day event for 12 October 2026
- **THEN** it displays 12 October without a start-time label, even if the stored UTC start falls on 11 October

#### Scenario: Timed display retains a real time
- **WHEN** the same display receives a timed event, including a real midnight start
- **THEN** its existing date/time rendering remains in force

### Requirement: Existing discovery and technical legacy behavior remain compatible
Sorting SHALL continue to use the stored start. Existing day/date-range and annual-overlap retrieval SHALL include date-only events under their current Rome bounds and soft-delete rules. Upcoming-event semantics SHALL remain start-window-based. A real consumer of current-time expiration SHALL NOT treat an all-day single-day event as ended immediately after its technical midnight start; any necessary correction SHALL be confined to that consumer. Released clients SHALL remain able to decode new rows, synchronize, and start; their display of technical midnight is accepted. No minimum-version, forced-update, remote-config, or client-version distribution mechanism is introduced.

#### Scenario: Existing day and year discovery returns all-day events
- **WHEN** an all-day single-day or cross-year multi-day event intersects the existing requested Rome day, date range, or annual filter
- **THEN** the existing discovery paths include it under their current filtering rules

#### Scenario: Current-time expiration consumer respects logical day membership
- **WHEN** an actual expiration consumer evaluates a start-only all-day event during its initial Rome civil day
- **THEN** it does not mark it ended solely because its normalized midnight start is earlier than now

#### Scenario: Sorting and upcoming retain the current contract
- **WHEN** all-day and timed events share a Rome date or an event starts before the upcoming window
- **THEN** sorting still follows start instants and upcoming membership still depends on the start-window rule

#### Scenario: Released client receives the additive field
- **WHEN** the currently published decoder receives a row with the added `all_day` key
- **THEN** decoding, synchronization, and startup remain functional without requiring semantic recognition of the flag
