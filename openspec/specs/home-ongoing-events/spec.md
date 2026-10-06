# home-ongoing-events Specification

## Purpose

Expose events active at the current instant as a distinct Home discovery set, preserving Rome civil-day meaning and separating temporal classification from visual design.

## Requirements

### Requirement: Ongoing intervals use inclusive instant membership
Ongoing retrieval SHALL classify against the UTC snapshot supplied by its caller. Each Home discovery pass SHALL capture that snapshot once in application orchestration and supply it unchanged to both ongoing and upcoming retrieval; neither query SHALL acquire a separate current instant. A non-deleted event with a non-null end SHALL be ongoing exactly when start <= snapshot <= end. It SHALL NOT use overlap with the whole current day as a substitute, round instants, or apply epsilon adjustments. Retrieval SHALL include active intervals regardless of their initial calendar year.

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
Ongoing retrieval SHALL exclude soft-deleted events and return the complete matching Event collection directly, ordered by start ascending and event identity ascending for equal starts. It SHALL NOT add an arbitrary result cap tied to an unspecified visual layout.

#### Scenario: Deleted interval contains now
- **WHEN** a soft-deleted event otherwise qualifies as ongoing
- **THEN** it is excluded

#### Scenario: More than six active events
- **WHEN** more than six non-deleted events qualify, including equal-start events
- **THEN** all are returned with stable start and identity ordering

### Requirement: Home discovery passes share one snapshot and produce disjoint sets
Each Home discovery pass SHALL capture exactly one current UTC snapshot in application orchestration and pass it to both retrieval operations. Both classifications, the current Rome day and the upcoming-window end SHALL use that same snapshot even if the first discovery query delays the second query across a temporal boundary. For the same dataset, ongoing and upcoming Event collections returned by a successful pass SHALL have an empty intersection by their retrieval contracts, without a temporal gap caused by different clock readings. Presentation SHALL NOT repair overlap using local filtering or deduplication. This requirement SHALL NOT assert atomic cache reads, reclassify retained state after failed retrieval or provide live updates while time passes.

#### Scenario: Same dataset contains active and future events
- **WHEN** a successful Home pass queries both sets over active, ended and future events
- **THEN** application orchestration supplies the same captured snapshot to both, their event-identity intersection is empty and eligible active and future events remain in their respective sets

#### Scenario: First discovery query crosses an event start
- **WHEN** a pass captures `10:59:59.900Z`, delays its first ongoing discovery query over an already-active event, and queries upcoming after the clock advances to `11:00:00.200Z` while another event starts at `11:00:00Z`
- **THEN** both queries receive `10:59:59.900Z`, the later-start event is upcoming and not ongoing for that pass, and it does not disappear from both sets due to clock drift

#### Scenario: A later pass observes the advanced clock
- **WHEN** a subsequent pass begins at `11:00:00.200Z` for that same event whose end still includes the new snapshot
- **THEN** one new snapshot governs both queries and the event is ongoing and not upcoming

#### Scenario: First discovery query crosses Rome midnight
- **WHEN** a pass captures an instant before Rome midnight and the delayed first discovery query finishes after midnight
- **THEN** both classifications and the upcoming-window end remain based on the captured Rome day, including null-end membership

#### Scenario: A coalesced pass captures a fresh shared instant
- **WHEN** a return request is queued during a pass and the clock advances before the next pass starts
- **THEN** the first pass retains its original snapshot and the subsequent pass captures one new snapshot shared by both queries

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
Temporal discovery SHALL be owned by the repository boundary and return ordered Event collections directly through the existing application command/result flow as read-only ongoing and upcoming state. Home SHALL consume these collections without date comparisons, synthetic ends, temporal deduplication or corrective sorting. A recoverable direct query or materialization failure SHALL retain the last successful collection and expose the error on the command representing that retrieval, without partial publication; successful empty retrieval SHALL clear earlier results. Successful collection publication SHALL occur in a single final state replacement after direct retrieval completes, without per-ID entity resolution.

#### Scenario: Ongoing retrieval succeeds
- **WHEN** direct ongoing retrieval returns an ordered Event collection successfully
- **THEN** that complete read-only collection is published in repository order before the load finishes

#### Scenario: Ongoing retrieval fails after a success
- **WHEN** a later direct retrieval returns a recoverable error
- **THEN** the prior successful state remains available and the same retrieval command exposes the error without publishing a partial collection

#### Scenario: Successful reload is empty
- **WHEN** a subsequent successful direct retrieval returns no ongoing events
- **THEN** the ongoing collection becomes empty and is distinguishable from retrieval error

#### Scenario: Direct retrieval remains pending
- **WHEN** a direct discovery query has not completed
- **THEN** the earlier successful collection remains available without incrementally accumulated entities

### Requirement: Home re-entry refreshes temporal discovery
Initial Home creation SHALL load both ongoing and upcoming discovery through a pass with one shared UTC snapshot. A supported navigation away from Home followed by return SHALL re-execute both classifications against the then-current cache and clock, even when the shell retains the application state. Manual sync and pull-to-refresh SHALL retain the existing sync navigation/error contract and reclassify both sets when Home returns. Overlapping return requests SHALL not be silently lost because another load is running. The system SHALL NOT introduce periodic refresh, polling, a global clock notifier or a lifecycle framework for this feature. Continuously visible Home SHALL retain snapshot state until an explicit reload or supported return.

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
- **THEN** a coalesced subsequent pass captures its own single shared snapshot, completes and the return request is not discarded

#### Scenario: Home owner is disposed while loading
- **WHEN** a Home owner is disposed with direct discovery retrieval in flight
- **THEN** late completion does not publish state or schedule further Home loads on the disposed owner

### Requirement: Home visual implementation is gated on developer design
Home SHALL provide a distinct section named “Eventi in corso” after the developer supplies its visual design. This change SHALL NOT prescribe position, layout, cards, visible count, responsive behavior, spacing, typography, colors, animations, skeletons, empty/error presentation or CTAs. Functional data and refresh implementation SHALL be reviewable before that gate; the feature SHALL NOT be considered fully complete before the approved visual surface and its functional rendering tests exist.

#### Scenario: Design has not been supplied
- **WHEN** technical data and refresh work is implementable but developer UI decisions are absent
- **THEN** visual implementation stays gated without inventing a layout or marking the entire feature complete

#### Scenario: Approved visual surface consumes ongoing
- **WHEN** the developer design is supplied and the Home section is implemented
- **THEN** “Eventi in corso” consumes the classified ongoing collection separately from “Prossimi eventi”
