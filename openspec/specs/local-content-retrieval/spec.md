# local-content-retrieval Specification

## Purpose

Ensure local content-list discovery returns the final domain content required by application state without unnecessary ID-first per-item resolution, while preserving established filtering, ordering, limits and Command semantics.

## Requirements

### Requirement: Active list discovery returns final domain models

When an active local discovery flow requires complete domain content for presentation, its repository boundary SHALL return the final required domain models directly. The caller SHALL NOT first retrieve entity IDs solely to resolve every returned ID into those same entities one by one.

This requirement applies to latest-place Home discovery, upcoming-event Home discovery, ongoing-event Home discovery and active search discovery. It SHALL NOT prohibit ID-returning APIs whose caller genuinely requires identity membership rather than immediate full entity materialization.

#### Scenario: Latest places load

- **WHEN** Home requests its latest-place collection
- **THEN** the place repository returns the ordered limited `Place` collection directly without a subsequent per-item `getById` loop

#### Scenario: Upcoming events load

- **WHEN** Home requests its upcoming-event collection
- **THEN** the event repository returns the matching ordered limited `Event` collection directly without a subsequent per-item `getById` loop

#### Scenario: Ongoing events load

- **WHEN** Home requests its ongoing-event collection for a supplied discovery snapshot
- **THEN** the event repository returns the complete matching ordered `Event` collection directly without a subsequent per-item `getById` loop

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

#### Scenario: Temporal discovery follows its owning capabilities

- **WHEN** Home retrieves upcoming or ongoing events directly
- **THEN** upcoming follows `event-temporal-integrity` and ongoing follows `home-ongoing-events`, including their classification, ordering and limits; `local-content-retrieval` governs direct materialization, atomic publication and Command semantics without redefining temporal classification

#### Scenario: Search result ordering

- **WHEN** both places and events match a search
- **THEN** direct retrieval preserves the established place-first then event result grouping and existing within-type first-match order

### Requirement: One logical load is represented by one UI-facing Command

For targeted active flows, the Command observed by the UI SHALL own the repository discovery Result for that logical load. An intermediate ID Command SHALL NOT hide repository discovery failure from a downstream entity Command.

When multiple UI-facing temporal discovery Commands are coordinated by one application refresh pass to share a single caller-owned snapshot, the coordinator MAY execute more than one logical load. Each retrieval Command SHALL still expose its own repository Result, while Home retry entry points SHALL request a fresh coordinated pass rather than constructing a snapshot in the View or reviving ID/entity command chains.

#### Scenario: Latest-place discovery fails

- **WHEN** the direct latest-place repository operation returns `Result.error`
- **THEN** `loadLatest` exposes the error and a retry executes latest-place discovery again

#### Scenario: Upcoming-event discovery fails

- **WHEN** the direct upcoming-event repository operation returns `Result.error`
- **THEN** `loadNext` exposes the error and a Home retry requests a fresh temporal discovery pass that executes upcoming discovery again with the coordinator-owned snapshot

#### Scenario: Ongoing-event discovery fails

- **WHEN** the direct ongoing-event repository operation returns `Result.error`
- **THEN** `loadOngoing` exposes the error and a Home retry requests a fresh temporal discovery pass without an intermediate ID or per-item entity-resolution Command

#### Scenario: Search discovery fails

- **WHEN** direct active search returns `Result.error`, including a recoverable query or materialization failure
- **THEN** the still-authoritative search/suggestion Command exposes that failure without publishing partial results or silently skipping failed materialization to report success

#### Scenario: Superseded Search discovery fails

- **WHEN** a superseded search or suggestion discovery returns Result.error
- **THEN** it does not replace the authoritative command failure/value state or publish a collection

### Requirement: Successful list publication is atomic after retrieval

Targeted ViewModels SHALL publish a successful collection only after the direct repository retrieval completes. They SHALL NOT construct visible list state by clearing it and appending individual entities across a series of awaited per-item lookups.

Atomic successful publication SHALL NOT by itself imply cancellation or latest-wins guarantees for other targeted flows. Search result and suggestion discovery SHALL additionally publish only from the latest authoritative intent under the Search latest-intent requirement.

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

### Requirement: Search latest intent preserves short-query behavior

Search results and suggestions SHALL each have an independent latest-intent ownership domain. Every newly accepted query, including a query shorter than the existing three-character threshold, SHALL revoke prior publication authority immediately. Valid queries SHALL retain repository filtering, ordering, mixed-content identity and atomic collection replacement. Short queries SHALL perform no repository discovery, finish as successful no-ops and retain the previously committed collection. Existing empty-input history and short-input suggestion presentation SHALL be preserved. Debounce SHALL NOT substitute for invalidation of obsolete work.

#### Scenario: Slow query replaced by fast query
- **WHEN** a valid new query completes before an older pending query
- **THEN** only the new query collection and terminal command state are published

#### Scenario: Short query invalidates pending valid query
- **WHEN** a short query replaces a pending valid query
- **THEN** the previously committed collection remains unchanged, no short-query repository call occurs and the older completion cannot overwrite it

#### Scenario: Query edit during suggestions debounce
- **WHEN** suggestion text changes while a previous lookup is pending and the new valid lookup is still debounced
- **THEN** the old lookup immediately loses publication authority and the existing debounce delay still reduces discovery calls

#### Scenario: Independent collections
- **WHEN** results and suggestions are requested independently
- **THEN** each latest query owns only its corresponding collection and neither cancels the other's authoritative work

#### Scenario: Disposal before query completion
- **WHEN** the Search owner disposes while retrieval is pending
- **THEN** the completion produces no ViewModel commit or notification

### Requirement: GeoMap marker discovery commits one filtered snapshot

One logical marker retrieval SHALL query selected Events then selected Places through their existing direct-model boundaries. It SHALL filter using the captured categories and preserve repository order within Events and Places, with Events before Places in combined markers. Only authoritative live terminal retrieval SHALL atomically replace both collections. Unselected sources SHALL perform no query and publish no items.

#### Scenario: Both sources are pending
- **WHEN** Events succeeds while selected Places remains pending
- **THEN** neither source collection is published until the complete current retrieval settles

#### Scenario: Only one type is selected
- **WHEN** marker selection contains only Events or only Places
- **THEN** only that source is queried and the other collection remains empty

#### Scenario: Filtered order and identity
- **WHEN** repositories return ordered content with matching and nonmatching categories and equal numeric IDs across types
- **THEN** the current category subset retains within-source order and Events-before-Places grouping without dropping a cross-type equal ID

#### Scenario: Obsolete physical retrieval finishes
- **WHEN** superseded marker work finishes before or after the latest retrieval
- **THEN** it cannot replace either current collection, terminal status or current loading state

### Requirement: GeoMap marker expected failures retain partial data and source evidence

Marker retrieval SHALL continue to selected Places after an Events application error. Terminal outcome SHALL retain successful source items and each original source error; Events error SHALL have display precedence when both fail. Any source error SHALL project failure with retry, including partial items, rather than full success or successful-empty. This marker contract SHALL NOT change Nearby ordering or error semantics.

#### Scenario: Events fail and Places succeed
- **WHEN** Events returns an application error and Places returns data
- **THEN** one terminal commit retains Places and the Events error, showing Places markers with generic failure and retry

#### Scenario: Places fail and Events succeed
- **WHEN** Events returns data and Places returns an application error
- **THEN** one terminal commit retains Events and the Places error with failure and retry

#### Scenario: Both sources fail
- **WHEN** both selected sources return application errors
- **THEN** both errors are retained, the Events error has precedence and empty items are shown as failure with retry rather than empty-success

#### Scenario: Successful sources are empty
- **WHEN** all selected sources succeed with empty data
- **THEN** the current empty collection is successful-empty distinctly from loading and failure

#### Scenario: One empty success and one failure
- **WHEN** one source succeeds empty and the other returns an application error
- **THEN** the outcome is failure with no markers and retry, never successful-empty

### Requirement: GeoMap marker runtime failures remain distinct from source application errors

Handled runtime throws SHALL terminate current marker retrieval as unexpected failure with original reporting once. They SHALL NOT become source application errors or fabricated aggregate success; partial data from the interrupted retrieval need not publish. Assertion failures SHALL preserve fail-loud behavior. Disposal SHALL prevent starting any not-yet-started selected source phase.

#### Scenario: First source throws
- **WHEN** Events throws a handled runtime failure before Places starts
- **THEN** Places is not queried, current retrieval shows terminal failure with retry and the original runtime object and stack are reported once

#### Scenario: Superseded runtime throw
- **WHEN** an older physical marker retrieval throws after a newer admission
- **THEN** its original runtime error remains reportable once without changing current markers or status

#### Scenario: Disposal after first source started
- **WHEN** the owner disposes while Events is pending and Events later settles
- **THEN** Places does not start and no collection or terminal outcome is committed to the disposed owner
