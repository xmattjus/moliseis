## ADDED Requirements

### Requirement: Home refresh settles independent retrieval lanes

A Home refresh pass SHALL await any active temporal retrieval before capturing its one shared UTC snapshot. It SHALL settle ongoing and upcoming independently in order, including after application or handled runtime failure on the first side. Per-side retained state and error kind SHALL remain observable. A pass SHALL not infer success from waiter completion.

#### Scenario: First side fails
- **WHEN** ongoing retrieval returns an application error or a handled runtime failure
- **THEN** upcoming retrieval still runs with the same captured snapshot while the first error remains observable and unexpected reporting occurs once

#### Scenario: External temporal load is active
- **WHEN** coordinated refresh is requested while a temporal retrieval is already running
- **THEN** the pass waits for its settlement before capturing the pass snapshot and neither silently skips a side nor mistakes the external result for a new successful pass

#### Scenario: Second lane is occupied after snapshot capture
- **WHEN** an independent upcoming request is admitted before the pass can start its upcoming retrieval
- **THEN** the pass waits for that request and then performs its own upcoming retrieval with its original snapshot without recapturing the clock

### Requirement: Home refresh requests coalesce without retaining disposed waiters

Concurrent Home refresh requests SHALL share the in-flight completion and request one subsequent coalesced pass. A new pass SHALL capture its clock only when it starts. Disposal SHALL clear pending work and detach temporary lane observations; no later owner-controlled retrieval SHALL start. A started retrieval may settle privately without publication.

#### Scenario: Several requests arrive during one pass
- **WHEN** multiple refresh requests arrive before the current pass ends
- **THEN** they share its completion and cause one subsequent pass for that pending batch, whose fresh instant is shared by both classifications

#### Scenario: Dispose while waiting for external work
- **WHEN** the owner is disposed while the coordinator waits for an active retrieval
- **THEN** its temporary observation is removed, the public refresh wait is released and no new pass begins

#### Scenario: Dispose during the first side
- **WHEN** disposal occurs while the pass awaits ongoing retrieval
- **THEN** public refresh waiters are released without waiting for physical completion, no upcoming retrieval begins and the late first-side result cannot publish
