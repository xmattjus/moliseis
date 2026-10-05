## Purpose

Ensure local content-list discovery returns the final domain content required by application state without unnecessary ID-first per-item resolution, while preserving established filtering, ordering, limits and Command semantics.

## ADDED Requirements

### Requirement: Active list discovery returns final domain models

When an active local discovery flow requires complete domain content for presentation, its repository boundary SHALL return the final required domain models directly. The caller SHALL NOT first retrieve entity IDs solely to resolve every returned ID into those same entities one by one.

This requirement applies to latest-place Home discovery, upcoming-event Home discovery and active search discovery. It SHALL NOT prohibit ID-returning APIs whose caller genuinely requires identity membership rather than immediate full entity materialization.

#### Scenario: Latest places load

- **WHEN** Home requests its latest-place collection
- **THEN** the place repository returns the ordered limited `Place` collection directly without a subsequent per-item `getById` loop

#### Scenario: Upcoming events load

- **WHEN** Home requests its upcoming-event collection
- **THEN** the event repository returns the matching ordered limited `Event` collection directly without a subsequent per-item `getById` loop

#### Scenario: Search loads mixed content

- **WHEN** a valid active search query executes
- **THEN** the search repository returns its final place/event domain results without requiring the SearchViewModel to resolve separate place and event ID lists

#### Scenario: IDs are the actual requested data

- **WHEN** a feature requires an identity set such as favourite membership and does not immediately resolve every ID into content
- **THEN** an ID-returning repository API may remain

### Requirement: Direct retrieval preserves effective discovery behavior

Replacing ID-first retrieval SHALL preserve the effective active membership, filtering, deduplication, ordering and result-limit behavior that existed after the old per-ID resolution completed.

Filtering that was previously supplied implicitly by downstream entity resolution SHALL move into the owning direct repository query rather than disappear.

#### Scenario: Deleted place matches search

- **WHEN** a soft-deleted place matches search by name, category or associated city
- **THEN** direct search excludes it just as the previous downstream place lookup did

#### Scenario: Place matches multiple search paths

- **WHEN** the same visible place matches more than one existing search path
- **THEN** it appears once at the position of its first match under the existing aggregation order

#### Scenario: Event annual visibility applies to search

- **WHEN** an event matches search text but does not satisfy the canonical annual visibility rule
- **THEN** direct search excludes it under the same temporal rule as before

#### Scenario: Search contains place and event with equal numeric identity

- **WHEN** a matching place and event have the same numeric identifier
- **THEN** both remain in mixed search results because cross-type numeric equality is not duplication

### Requirement: Repository query semantics remain feature-owned

Direct model retrieval SHALL preserve each feature's existing repository-owned query semantics. This optimization SHALL NOT introduce new temporal classification, search ranking, pagination, nearby-distance semantics or presentation filtering.

#### Scenario: Latest place ordering and cap

- **WHEN** more than six visible places exist
- **THEN** latest-place retrieval returns the same six most recently created places under the established descending creation order

#### Scenario: Upcoming event contract

- **WHEN** upcoming events are retrieved before the separate ongoing-events change is implemented
- **THEN** direct model retrieval uses the current canonical upcoming temporal contract, ordering and limit without adopting future snapshot semantics early

#### Scenario: Search result ordering

- **WHEN** both places and events match a search
- **THEN** direct retrieval preserves the established place-first then event result grouping and existing within-type first-match order

### Requirement: One logical load is represented by one UI-facing Command

For targeted active flows, the Command observed by the UI SHALL own the repository discovery Result for that logical load. An intermediate ID Command SHALL NOT hide repository discovery failure from a downstream entity Command.

#### Scenario: Latest-place discovery fails

- **WHEN** the direct latest-place repository operation returns `Result.error`
- **THEN** `loadLatest` exposes the error and a retry executes latest-place discovery again

#### Scenario: Upcoming-event discovery fails

- **WHEN** the direct upcoming-event repository operation returns `Result.error`
- **THEN** `loadNext` exposes the error and a retry executes upcoming-event discovery again

#### Scenario: Search discovery fails

- **WHEN** direct active search returns `Result.error`, including a recoverable query or materialization failure
- **THEN** the currently executed search/suggestion Command exposes that failure without publishing partial results or silently skipping failed materialization to report success

### Requirement: Successful list publication is atomic after retrieval

Targeted ViewModels SHALL publish a successful collection only after the direct repository retrieval completes. They SHALL NOT construct visible list state by clearing it and appending individual entities across a series of awaited per-item lookups.

Atomic successful publication SHALL NOT by itself imply cancellation or latest-wins guarantees.

#### Scenario: Direct list succeeds

- **WHEN** a targeted repository returns a successful non-empty collection
- **THEN** the ViewModel replaces its corresponding visible collection in one synchronous commit after the await

#### Scenario: Direct list succeeds empty

- **WHEN** a targeted repository successfully returns no matching content
- **THEN** the ViewModel can publish an empty collection distinctly from repository failure

#### Scenario: Retrieval is still pending

- **WHEN** the direct repository Future has not completed
- **THEN** the ViewModel does not expose a partially accumulated result from per-item lookup

### Requirement: Obsolete ID-only plumbing is removed when it has no active consumer

Intermediate ID state, Commands and repository APIs SHALL be removed when their only purpose was immediate full-entity resolution and execution-head audit confirms no remaining active consumer.

Dormant unimplemented feature paths SHALL be deleted rather than mechanically migrated solely to preserve unused architecture.

#### Scenario: Latest-place IDs have no consumer

- **WHEN** latest-place IDs are no longer used by UI, loading placeholders or another active feature
- **THEN** latest ID state/API/Command plumbing is removed

#### Scenario: Explore near path remains unused

- **WHEN** execution-head search confirms the Explore-specific near Command/state has no non-commented runtime consumer
- **THEN** that dead flow and its ID-only coordinate API are removed rather than redirected to a semantically different nearby query

#### Scenario: Related search remains unimplemented

- **WHEN** related-search UI and triggers remain comment/TODO-only with no runtime consumer
- **THEN** its ID-resolution Commands, state and repository machinery are removed rather than migrated

### Requirement: Exact shimmer cardinality does not justify a separate discovery query

The current generic loading skeleton SHALL NOT require a preliminary ID retrieval solely to determine how many final items will later render. Reintroducing a separate count/ID query for placeholder cardinality requires a new explicit product requirement.

#### Scenario: Latest or upcoming content is loading

- **WHEN** the final content query is in progress
- **THEN** the existing generic loading surface can render without first querying the final result count
