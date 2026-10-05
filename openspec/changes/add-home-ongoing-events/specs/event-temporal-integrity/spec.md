## MODIFIED Requirements

### Requirement: Upcoming events remain start-date-based
Upcoming-event retrieval SHALL include only non-deleted events whose start occurs strictly after one captured current UTC instant and at or before the inclusive end of the Europe/Rome calendar day thirty civil days after the current Rome day. It SHALL remain start-date-based even when the window crosses New Year, sorted by start ascending and limited to six results. It SHALL NOT include an event whose start is equal to or before the captured instant merely because its interval remains active. The current Rome day and future-window end SHALL be derived from that same snapshot, independently of device timezone.

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

#### Scenario: Existing upcoming ordering and limit
- **WHEN** more than six non-deleted future starts are inside the window
- **THEN** retrieval returns the first six under the existing ascending start order
