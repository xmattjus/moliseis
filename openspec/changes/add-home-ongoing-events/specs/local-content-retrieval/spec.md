## MODIFIED Requirements

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
- **THEN** the currently executed search/suggestion Command exposes that failure without publishing partial results or silently skipping failed materialization to report success
