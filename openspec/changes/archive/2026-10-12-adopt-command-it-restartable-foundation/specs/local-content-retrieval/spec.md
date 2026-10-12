## MODIFIED Requirements

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

## ADDED Requirements

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
