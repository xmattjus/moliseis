## ADDED Requirements

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
