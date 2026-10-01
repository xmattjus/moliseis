## MODIFIED Requirements

### Requirement: First committed submission wins
For one authenticated user and client identity, the first transaction that commits SHALL establish the immutable remote submission, its asset set, and its positive backend identifier. Every later otherwise-valid authenticated request with that same ownership key SHALL return the original identifier without inserting, updating, or deleting submission or asset data, even when later request content, temporal mode, or dates differ. The original `all_day` value and dates SHALL remain unchanged. A replay SHALL NOT turn a pending, accepted, or rejected submission back into another state.

#### Scenario: Sequential equivalent retry replays the acknowledgement
- **WHEN** the same authenticated user repeats an already committed request with the same client identity
- **THEN** the boundary returns the original positive submission identifier and creates no additional submission or asset rows

#### Scenario: Changed retry cannot overwrite the committed payload
- **WHEN** a later otherwise-valid request reuses a committed client identity with changed content or assets
- **THEN** the original submission and asset rows remain unchanged and the original identifier is returned

#### Scenario: Moderated submission still replays
- **WHEN** a committed submission has since been accepted or rejected and its original client identity is retried by the same user
- **THEN** the existing identifier is returned without changing moderation or publication state

#### Scenario: Changed temporal mode replays the first commit
- **WHEN** an otherwise-valid replay changes true to false or false to true with a valid corresponding temporal payload
- **THEN** the first committed mode and dates remain unchanged, the original identifier is returned, and no new quota or assets are consumed


### Requirement: Submission persistence is one atomic operation
Quota accounting, submission creation, and attachment association for a new idempotency key SHALL commit as one database transaction. Any database error or rejected persistence invariant SHALL leave all three areas unchanged. The normalized `all_day` value SHALL be part of the same first submission commit as its dates. Omission of the new optional RPC mode argument SHALL mean false. The operation SHALL reuse the existing authoritative maximum-five asset invariant, preserve the established public-field mapping including storing `unknown` when the validated category is null, and SHALL not expose a partial submission as a successful acknowledgement.

#### Scenario: Asset persistence failure rolls back the submission
- **WHEN** attachment persistence fails after submission creation has begun
- **THEN** no submission row, asset row, or quota increment from that attempt is committed

#### Scenario: Submission persistence failure does not consume quota
- **WHEN** a new logical submission cannot be committed
- **THEN** the user's quota state remains as it was before the attempt

#### Scenario: Successful no-asset submission commits atomically
- **WHEN** a valid new request contains no assets
- **THEN** its submission and one quota consumption commit together and a positive identifier is returned

#### Scenario: Null category preserves the existing database default
- **WHEN** a valid new public request carries a null category
- **THEN** the committed submission stores `unknown` exactly as the existing public submission path does

#### Scenario: Omitted RPC flag preserves the old caller
- **WHEN** the prior service-role RPC argument set is invoked through the actual PostgREST boundary without the new mode argument
- **THEN** it resolves successfully and commits false under the existing atomic quota/submission/asset guarantees

#### Scenario: All-day commit is atomic
- **WHEN** a new request carries true and normalized valid dates
- **THEN** mode, dates, submission, assets, and quota commit together or all roll back on failure
