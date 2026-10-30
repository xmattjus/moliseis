## ADDED Requirements

### Requirement: GeoMap Nearby publication belongs to its current semantic target

GeoMap Nearby SHALL have one active requested target: committed Explore anchor, or materialized Post identity and coordinates. The Explore anchor SHALL remain independently owned while Post is active. Search and unresolved Post SHALL have no Nearby target. Target changes SHALL immediately revoke obsolete publication and clear/hide prior target collections.

#### Scenario: Explore anchor changes while loading
- **WHEN** Nearby target A is pending and Explore commits B
- **THEN** B can be admitted immediately and no A collection or terminal failure is published as B

#### Scenario: Explore switches to Post
- **WHEN** a materialized Post with its own identity/coordinates becomes active
- **THEN** Nearby uses the materialized Post as its target, while the Explore anchor remains remembered; pending Explore results cannot appear beneath Post

#### Scenario: Post switches to another Post or Explore
- **WHEN** Post A becomes Post B, or explicit close enters Explore at live center
- **THEN** target changes even when numeric coordinates are equal but semantic identity differs, and old data/publication are invalidated

#### Scenario: Obsolete widget callback or disposed owner
- **WHEN** a deferred load/retry refers to a no-longer-current target or disposed owner
- **THEN** it cannot retarget the active lane, publish content or notify the ViewModel late

#### Scenario: Nearby commits only authoritative terminal data
- **WHEN** Nearby retrieval settles or its semantic target changes
- **THEN** Only authoritative live terminal retrieval SHALL synchronously commit one target-bound terminal snapshot and its replacement collection/error projection; awaited actions SHALL not mutate ViewModel data. Existing repository distance/filter contracts SHALL remain unchanged. Foundation Home/Search retrieval and concurrency requirements are inherited without modification or duplication.

### Requirement: GeoMap Nearby preserves partial data and first error together

A completed GeoMap Nearby retrieval SHALL retain successful Places first and successful Events second, and the original first expected repository error, with Places error taking precedence over Events error. Its operation-specific aggregate SHALL carry both collection and nullable first error. A completed aggregate with a first error SHALL NOT be presented as fully successful discovery.

#### Scenario: Both repositories succeed
- **WHEN** Places and then Events succeed
- **THEN** one atomic collection is published in Places-first/Events-second order, including empty-success distinctly from failure

#### Scenario: Places fail and Events succeed
- **WHEN** Places returns an expected error and Events returns content
- **THEN** Events content and original Places error are both retained and presented as partial failure with retry

#### Scenario: Events fail and Places succeed
- **WHEN** Places returns content and Events returns an expected error
- **THEN** Places content and original Events error are both retained and presented as partial failure with retry

#### Scenario: Both repositories fail
- **WHEN** both return expected errors
- **THEN** an empty aggregate retains the original Places error and presents error/retry rather than empty success

#### Scenario: Pending, failure and retry
- **WHEN** the current target is loading, completes partially/fully failed, or is retried
- **THEN** loading hides obsolete data, partial failure shows successful items plus error/retry, total failure shows error/retry, and retry retrieves the still-current target

#### Scenario: Neutral differs from empty success
- **WHEN** Nearby has no accepted terminal retrieval, or is running, or completes successfully with no items
- **THEN** neutral/running render loading placeholders, while only completed empty success renders the empty message

#### Scenario: Unexpected terminal failure
- **WHEN** current Nearby retrieval throws a handled runtime failure without a successful aggregate
- **THEN** its original runtime error is presented as terminal error/retry, never an indefinite loading skeleton or fabricated expected Result

#### Scenario: Target returns before deferred invalidation
- **WHEN** target A changes to B then A before neutral results publish
- **THEN** the synchronously cleared committed terminal prevents old A data or error from being reused

#### Scenario: Invalid coordinates
- **WHEN** either shared Nearby consumer is given coordinates rejected by the existing validity predicate
- **THEN** it performs no repository lookup and does not show completed-empty success

#### Scenario: Shared normal Post consumer
- **WHEN** normal Post uses the adapted shared Nearby widget inputs
- **THEN** its existing retrieval ordering, error display, Post owner isolation and Nearby URI/Search-parent navigation behavior remain unchanged

#### Scenario: Aggregate completion distinguishes expected and runtime failures
- **WHEN** Nearby aggregation returns expected errors or throws unexpectedly
- **THEN** Unexpected runtime failures SHALL retain foundation error routing rather than fabricated expected Results; partial publication after such a throw is not required.
