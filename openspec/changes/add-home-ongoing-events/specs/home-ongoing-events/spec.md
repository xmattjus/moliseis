## Purpose

Expose events active at the current instant as a distinct Home discovery set, preserving Rome civil-day meaning and separating temporal classification from visual design.

## ADDED Requirements

### Requirement: Ongoing intervals use inclusive instant membership
Ongoing retrieval SHALL classify against one UTC snapshot captured once per operation. A non-deleted event with a non-null end SHALL be ongoing exactly when start <= snapshot <= end. It SHALL NOT use overlap with the whole current day as a substitute, round instants, or apply epsilon adjustments. Retrieval SHALL include active intervals regardless of their initial calendar year.

#### Scenario: Multi-day event spans now
- **WHEN** a non-deleted event began yesterday and ends tomorrow
- **THEN** it is ongoing

#### Scenario: Timed event is active today
- **WHEN** a non-deleted timed event started earlier today and its end follows the snapshot
- **THEN** it is ongoing

#### Scenario: Future event intersects today
- **WHEN** an event begins later today than the snapshot
- **THEN** it is not ongoing

#### Scenario: Event ended earlier today
- **WHEN** an event ended before the snapshot in the current day
- **THEN** it is not ongoing

#### Scenario: Start boundary is inclusive
- **WHEN** a non-deleted event starts exactly at the snapshot and has no earlier end
- **THEN** it is ongoing

#### Scenario: End boundary is inclusive
- **WHEN** a non-deleted event ends exactly at the snapshot with start at or before it
- **THEN** it is ongoing, including when start equals end equals the snapshot

#### Scenario: Interval began in an earlier year
- **WHEN** a non-deleted event began in a previous year and its interval still includes the snapshot
- **THEN** ongoing retrieval includes it without an annual start filter

### Requirement: Null-end ongoing events remain single-day
For an event with a null end, ongoing retrieval SHALL require a start in the current Europe/Rome civil day and start <= the captured instant. It SHALL NOT interpret a null end as indefinite duration or materialize a synthetic persisted end.

#### Scenario: Start-only event already started today
- **WHEN** a non-deleted null-end event began earlier in the current Rome day or exactly at the snapshot
- **THEN** it is ongoing

#### Scenario: Start-only event is future today
- **WHEN** a null-end event starts later in the current Rome day than the snapshot
- **THEN** it is not ongoing

#### Scenario: Start-only event began yesterday
- **WHEN** a null-end event started in the previous Rome day
- **THEN** it is not ongoing

### Requirement: Ongoing classification preserves all-day temporal meaning
Ongoing retrieval SHALL use the same persisted start and end bounds for timed and all-day events. It SHALL NOT classify through a second temporal rule based on the all-day flag. All-day SHALL retain the meaning defined in event-all-day-semantics, including explicit same-day final dates.

#### Scenario: All-day single-day event is today
- **WHEN** a non-deleted all-day event starts at the current Rome day's first instant and has a null end
- **THEN** it is ongoing throughout that Rome day

#### Scenario: All-day multi-day event spans now
- **WHEN** a non-deleted all-day event's canonical inclusive interval contains the snapshot
- **THEN** it is ongoing under the same interval rule

#### Scenario: All-day final date explicitly equals initial date
- **WHEN** a non-deleted all-day event has both canonical bounds of the current Rome day
- **THEN** it is ongoing under the non-null-end interval rule

### Requirement: Ongoing retrieval excludes deleted events and provides a stable ordered set
Ongoing retrieval SHALL exclude soft-deleted events and return all matching IDs ordered by start ascending and event identity ascending for equal starts. It SHALL NOT add an arbitrary result cap tied to an unspecified visual layout.

#### Scenario: Deleted interval contains now
- **WHEN** a soft-deleted event otherwise qualifies as ongoing
- **THEN** it is excluded

#### Scenario: More than six active events
- **WHEN** more than six non-deleted events qualify, including equal-start events
- **THEN** all are returned with stable start and identity ordering

### Requirement: Ongoing and upcoming are disjoint at the same snapshot
For the same dataset and current UTC snapshot, ongoing and upcoming ID sets SHALL have an empty intersection by their retrieval contracts. Presentation SHALL NOT repair overlap using local filtering or deduplication. Separate operations SHALL each capture their own instant; this requirement SHALL NOT assert atomicity across independent clock readings or live reclassification while time passes.

#### Scenario: Same dataset contains active and future events
- **WHEN** both sets are queried at the same fixed snapshot over active, ended and future events
- **THEN** their ID intersection is empty and eligible active and future events remain in their respective sets

### Requirement: Rome civil boundaries are independent of device timezone
The current civil day and inclusive UTC bounds SHALL use Europe/Rome independently of device timezone and SHALL respect actual DST day lengths. Null-end membership SHALL end at the last represented microsecond of its Rome day, without conversion to half-open persisted ends.

#### Scenario: Rome day differs from UTC day
- **WHEN** the snapshot is after Rome midnight but still in the preceding UTC date
- **THEN** null-end membership uses the new Rome day

#### Scenario: Exact Rome midnight advances the day
- **WHEN** the snapshot moves from the final microsecond of a Rome day to the next Rome midnight
- **THEN** a null-end event from the preceding day stops qualifying and a non-deleted start exactly at the new midnight qualifies

#### Scenario: DST changes the day length
- **WHEN** the current Rome day is 29 March 2026 or 25 October 2026
- **THEN** classification respects the actual 23-hour or 25-hour civil bounds and their inclusive end

### Requirement: Home receives classified read-only state
Temporal discovery SHALL be owned by the repository boundary and exposed through the existing application command/result flow as read-only ongoing and upcoming collections. Home SHALL consume these collections without date comparisons, synthetic ends, temporal deduplication or corrective sorting. A failed ID retrieval SHALL retain the last successful collection and expose the error without launching entity resolution; a successful empty retrieval SHALL clear earlier results. Individual failed entity lookups SHALL be omitted without changing the order of successful lookups, preserving existing discovery error behavior.

#### Scenario: Ongoing ID retrieval succeeds
- **WHEN** ongoing IDs load successfully
- **THEN** entities are resolved in retrieval order and the resulting read-only collection is published before the load finishes

#### Scenario: Ongoing ID retrieval fails after a success
- **WHEN** a later ID retrieval returns a recoverable error
- **THEN** the prior successful state remains available, the error is exposed and entity loading is not launched for that failed request

#### Scenario: Successful reload is empty
- **WHEN** a subsequent successful ID retrieval returns no ongoing IDs
- **THEN** the ongoing entity collection becomes empty and is distinguishable from retrieval error

#### Scenario: Entity lookup partially fails
- **WHEN** some retrieved IDs cannot be resolved
- **THEN** successfully resolved entities are published in repository order with failed lookups omitted

### Requirement: Home re-entry refreshes temporal discovery
Initial Home creation SHALL load both ongoing and upcoming discovery. A supported navigation away from Home followed by return SHALL re-execute both classifications against the then-current cache and clock, even when the shell retains the application state. Manual sync and pull-to-refresh SHALL retain the existing sync navigation/error contract and reclassify both sets when Home returns. Overlapping return requests SHALL not be silently lost because another load is running. The system SHALL NOT introduce periodic refresh, polling, a global clock notifier or a lifecycle framework for this feature. Continuously visible Home SHALL retain snapshot state until an explicit reload or supported return.

#### Scenario: Initial Home load
- **WHEN** the Home route is first created
- **THEN** both discovery sets load without duplicated bootstrap requests

#### Scenario: Retained Home returns from another tab or detail
- **WHEN** Home is covered or inactive, time advances, and navigation returns to Home
- **THEN** both discovery sets reload even if their owner was retained

#### Scenario: Imperative route returns to Home
- **WHEN** a settings route is pushed from Home and popped
- **THEN** Home return refreshes both classifications without relying on browser URL changes

#### Scenario: Home rebuilds without leaving
- **WHEN** a theme or other rebuild occurs while the same Home route remains visible
- **THEN** that rebuild alone does not initiate a discovery reload

#### Scenario: Home returns after forced sync
- **WHEN** manual menu refresh or pull-to-refresh finishes sync and navigation returns to Home
- **THEN** both classifications reload against the updated cache, or retained valid cache after a non-fatal sync error

#### Scenario: Return happens while a prior load is pending
- **WHEN** another Home return requests discovery during an earlier load
- **THEN** a coalesced subsequent pass completes and the return request is not discarded

#### Scenario: Home owner is disposed while loading
- **WHEN** a Home owner is disposed with IDs or entity resolution in flight
- **THEN** late completion does not publish state or schedule further Home loads on the disposed owner

### Requirement: Home visual implementation is gated on developer design
Home SHALL provide a distinct section named “Eventi in corso” after the developer supplies its visual design. This change SHALL NOT prescribe position, layout, cards, visible count, responsive behavior, spacing, typography, colors, animations, skeletons, empty/error presentation or CTAs. Functional data and refresh implementation SHALL be reviewable before that gate; the feature SHALL NOT be considered fully complete before the approved visual surface and its functional rendering tests exist.

#### Scenario: Design has not been supplied
- **WHEN** technical data and refresh work is implementable but developer UI decisions are absent
- **THEN** visual implementation stays gated without inventing a layout or marking the entire feature complete

#### Scenario: Approved visual surface consumes ongoing
- **WHEN** the developer design is supplied and the Home section is implemented
- **THEN** “Eventi in corso” consumes the classified ongoing collection separately from “Prossimi eventi”
