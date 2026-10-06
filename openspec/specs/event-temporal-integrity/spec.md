# Event Temporal Integrity Specification

## Purpose

Define structurally valid persisted event intervals and consistent Europe/Rome civil-time membership across event discovery, while preserving distinct day-range and upcoming-event contracts.

## Requirements

### Requirement: Content submission dates form a valid optional interval
The database SHALL allow both submission dates to be absent when `all_day=false`, or an optional end paired with a present start in either mode. When `all_day=true`, the database SHALL require a non-null start even with a null end. It SHALL reject an end without a start and an end earlier than the start on insert or update. Equal start and end instants SHALL be valid.

#### Scenario: Both dates are absent
- **WHEN** a content submission is inserted or updated with `all_day=false`, null start, and null end
- **THEN** the date constraints accept the row

#### Scenario: Start has no end
- **WHEN** a content submission is inserted or updated with a start and null end
- **THEN** the date constraints accept the row

#### Scenario: End is present without a start
- **WHEN** a content submission is inserted or updated with null start and a non-null end
- **THEN** the database rejects the row

#### Scenario: End equals or follows start
- **WHEN** a content submission is inserted or updated with a start and an end equal to or later than it
- **THEN** the date constraints accept the row, including differences at timestamp microsecond precision

#### Scenario: End precedes start
- **WHEN** a content submission is inserted or updated with an end earlier than its start, including a sub-millisecond inversion
- **THEN** the database rejects the row

#### Scenario: All-day mode requires a start even without an end
- **WHEN** a content submission is inserted or updated with `all_day=true`, null start, and null end
- **THEN** the database rejects the row

### Requirement: Published event dates form a valid interval
The database SHALL require every published event to have a start instant and SHALL reject an end earlier than that start on insert or update. A null end, an equal end, and a later end SHALL remain valid.

#### Scenario: Published event has no start
- **WHEN** an event is inserted or updated with a null start
- **THEN** the existing required-start column rule rejects the row

#### Scenario: Published event has no end
- **WHEN** an event is inserted or updated with a start and null end
- **THEN** the date constraints accept the row

#### Scenario: Published event has an equal or later end
- **WHEN** an event is inserted or updated with an end equal to or later than its start
- **THEN** the date constraints accept the row

#### Scenario: Published event has an inverted end
- **WHEN** an event is inserted or updated with an end earlier than its start, including a sub-millisecond inversion
- **THEN** the database rejects the row

### Requirement: Annual event membership uses Rome-year interval overlap
An event SHALL belong to a Europe/Rome calendar year when its temporal interval intersects any instant in that year's current inclusive civil-day range. For a non-null end, membership SHALL include exactly events whose start is at or before the year's end and whose end is at or after the year's start. For a null end, membership SHALL depend on whether its start falls within the year. Soft-deleted events SHALL be excluded.

#### Scenario: Start-only event occurs in the year
- **WHEN** a non-deleted event has a null end and its start is inside the selected Rome year
- **THEN** annual retrieval includes it

#### Scenario: Ranged event stays inside the year
- **WHEN** a non-deleted event starts and ends inside the selected Rome year
- **THEN** annual retrieval includes it

#### Scenario: Ranged event is wholly outside the year
- **WHEN** an event ends before the Rome year's first instant or starts after its last inclusive instant
- **THEN** annual retrieval excludes it

#### Scenario: Ranged event crosses the year start
- **WHEN** a non-deleted event starts in the preceding Rome year and ends in the selected Rome year
- **THEN** annual retrieval includes it

#### Scenario: Ranged event crosses the year end
- **WHEN** a non-deleted event starts in the selected Rome year and ends in the following Rome year
- **THEN** annual retrieval includes it

#### Scenario: Ranged event spans the whole year
- **WHEN** a non-deleted event starts before and ends after the selected Rome year
- **THEN** annual retrieval includes it

#### Scenario: Boundary contact is inclusive
- **WHEN** a non-deleted event ends exactly at the Rome year's first instant or starts exactly at its last inclusive instant
- **THEN** annual retrieval includes it

#### Scenario: Cross-year event belongs to both years
- **WHEN** a non-deleted event runs from 31 December 2026 into 1 January 2027 in Europe/Rome
- **THEN** annual retrieval includes it when the current Rome year is 2026 and when it is 2027

#### Scenario: Deleted event overlaps the year
- **WHEN** a soft-deleted event overlaps the current Rome year
- **THEN** annual retrieval excludes it

### Requirement: Every annual visibility consumer uses the same membership rule
Current-year event listings, category-filtered event listings, coordinate-filtered event listings, and event search by name, category, or associated city SHALL apply the same annual overlap and soft-delete rule. Other category, coordinate, and search filters SHALL retain their existing meaning.

#### Scenario: Cross-year event appears through annual listing filters
- **WHEN** a visible cross-year event matches the requested category and coordinates
- **THEN** current-year, category, and coordinate retrieval each include it for every Rome year it overlaps

#### Scenario: Search uses one annual rule on all event paths
- **WHEN** a visible cross-year event matches an event name, category label, or associated city search
- **THEN** each search path includes it for every Rome year it overlaps, without returning a soft-deleted match

### Requirement: Day and date-range retrieval retain interval overlap
Retrieval for one Europe/Rome calendar day or an inclusive range of Rome calendar days SHALL continue to return non-deleted events whose interval overlaps the requested range. A null end SHALL continue to be treated as a start-only event for these queries.

#### Scenario: Event overlaps a requested day or range
- **WHEN** a non-deleted event begins before a requested Rome day or date range and ends within or after it
- **THEN** day or date-range retrieval includes the event under the existing inclusive bounds

#### Scenario: Start-only event is outside the requested range
- **WHEN** an event has a null end and its start is outside the requested Rome day or date range
- **THEN** day or date-range retrieval excludes it

### Requirement: Upcoming events remain start-date-based
Upcoming-event retrieval SHALL include only non-deleted events whose start occurs strictly after the current UTC snapshot supplied by its caller and at or before the inclusive end of the Europe/Rome calendar day thirty civil days after the current Rome day. It SHALL remain start-date-based even when the window crosses New Year, returned directly as an ordered Event collection sorted by start ascending and limited to six results. It SHALL NOT include an event whose start is equal to or before the captured instant merely because its interval remains active. The current Rome day and future-window end SHALL be derived from that same supplied snapshot, independently of device timezone. For a Home discovery pass, application orchestration SHALL capture the current UTC instant once and supply the same value to ongoing and upcoming retrieval. Upcoming retrieval SHALL NOT read a separate current instant.

#### Scenario: January start appears in a December window
- **WHEN** the current snapshot is in December and a future January event start is inside the configured upcoming window
- **THEN** upcoming-event retrieval includes the event subject to the existing ordering and six-result limit

#### Scenario: Already-started event remains active
- **WHEN** an event started before or at the captured instant and ends in the future, including an event started earlier today
- **THEN** upcoming-event retrieval excludes it even if its start is within the current Rome day

#### Scenario: Event starts exactly now
- **WHEN** an event start equals the captured UTC instant
- **THEN** upcoming-event retrieval excludes it

#### Scenario: Event starts immediately after now
- **WHEN** a non-deleted event starts one microsecond after the captured instant and is inside the upper bound
- **THEN** it is eligible for upcoming retrieval without rounding or epsilon adjustments

#### Scenario: Event starts later today
- **WHEN** a non-deleted event starts later in the current Rome day
- **THEN** it is eligible for upcoming retrieval

#### Scenario: Inclusive future-window upper boundary
- **WHEN** starts occur at the last microsecond of the Rome day thirty civil days after today and one microsecond later
- **THEN** the first is eligible and the second is excluded

#### Scenario: Soft-deleted future event
- **WHEN** a soft-deleted event starts strictly in the future inside the window
- **THEN** upcoming retrieval excludes it

#### Scenario: Delayed discovery uses the supplied snapshot
- **WHEN** a Home pass supplies a snapshot before an event start and the upcoming query runs after that start because the first discovery query was delayed
- **THEN** the event remains eligible as upcoming for the supplied snapshot, and the query does not replace it with the later wall-clock time

#### Scenario: Existing upcoming ordering and limit
- **WHEN** more than six non-deleted future starts are inside the window
- **THEN** retrieval returns the first six under the existing ascending start order

### Requirement: Civil-day query bounds remain inclusive
Current Europe/Rome civil-day queries SHALL retain their inclusive range from the start of a calendar day through its final represented microsecond. This change SHALL NOT redefine an event end instant as the next day's exclusive start.

#### Scenario: Exact next-day midnight is outside the preceding day
- **WHEN** an event starts exactly at the first instant of the next Rome calendar day
- **THEN** a query limited to the preceding Rome day excludes that start-only event

### Requirement: Persisted temporal mode is non-null and defaults to timed
Submissions and events SHALL persist `all_day` as a non-null boolean defaulting to false. Existing rows SHALL acquire false without heuristic classification or date rewrites, including rows starting at midnight. Temporal schema enforcement SHALL retain the existing interval constraints plus the minimal all-day-start requirement above; it SHALL NOT add complex canonical-shape checks or silent corrective triggers.

#### Scenario: Historical and omitted modes remain false
- **WHEN** the additive schema is applied to historical rows or a new valid insert omits the mode
- **THEN** the persisted value is false and existing midnight dates are not reclassified

#### Scenario: Explicit null mode is rejected
- **WHEN** an insert or update supplies a null temporal mode
- **THEN** the database rejects that row
