## ADDED Requirements

### Requirement: Imported event promotion respects existing canonical linkage

Promotion of an imported external-event submission SHALL create a new Event only while its external record remains unlinked. Existing successful promotion retries retain their current durable-link idempotency semantics. Default handling SHALL account for the promoted immutable source snapshot; an explicit guarded current-source acknowledgement SHALL instead account for the current source state under the external-event-provenance-moderation contract, without publishing unreviewed Event fields.

#### Scenario: Imported create proposal publishes a new Event

- **GIVEN** a pending imported event submission
- **AND** its external record has no canonical Event link
- **AND** all existing event publication readiness checks pass
- **AND** current-source acknowledgement is absent
- **WHEN** it is promoted as Event
- **THEN** exactly one Event SHALL be created
- **AND** existing source assets SHALL be copied according to current promotion behavior
- **AND** the external record SHALL link to the new Event in the same transaction
- **AND** the submission SHALL become accepted with its existing `promoted_event_id` semantics
- **AND** the source watermark SHALL advance to the promoted submission's immutable external snapshot
- **AND** any newer already-observed source state SHALL be enqueued before commit

#### Scenario: Already linked source cannot create a second Event

- **GIVEN** a pending imported submission whose external record already links to Event E
- **AND** the submission itself has no prior promotion linkage
- **WHEN** Event promotion is requested
- **THEN** promotion SHALL return `source_already_linked`
- **AND** no Event or media SHALL be created
- **AND** the submission SHALL remain pending
- **AND** the external record SHALL remain linked to E

#### Scenario: Existing promotion retry retains precedence

- **GIVEN** an imported submission already has a durable `promoted_event_id`
- **WHEN** Event promotion is retried
- **THEN** the existing `already_promoted` result SHALL be returned
- **AND** the new source-link guard SHALL NOT replace that idempotent result

#### Scenario: Promotion explicitly acknowledges the newer current source

- **GIVEN** imported pending X is stale, current source is Y, and publication readiness passes
- **WHEN** promotion handles X with explicit current-source acknowledgement and matching expected_source_hash for Y
- **THEN** the Event SHALL be created from the reviewed moderated submission X
- **AND** the watermark SHALL account for Y and enqueue SHALL not produce another Y pending

#### Scenario: Invalid promotion acknowledgement rolls back publication

- **WHEN** a new imported promotion requests current-source acknowledgement for a non-stale pending or a changed expected_source_hash
- **THEN** it SHALL fail with source_changed
- **AND** no Event, media, resolution, watermark or enqueue mutation SHALL occur

### Requirement: Admin publication API exposes linked-source failure

The Admin API SHALL map the `source_already_linked` promotion outcome to a stable client-visible conflict.

#### Scenario: Legacy Admin attempts promotion of update proposal

- **GIVEN** promotion returns `source_already_linked`
- **WHEN** the Admin Edge Function handles the outcome
- **THEN** it SHALL return HTTP `409`
- **AND** the response code SHALL be `PROMOTION_SOURCE_ALREADY_LINKED`
- **AND** existing Flutter error normalization SHALL treat it as an API error rather than parsing a promotion success envelope

### Requirement: Imported resolution remains Event-specific

An imported external-event submission SHALL preserve the Event discriminator and SHALL NOT create a Place through promotion. Existing temporal/category/coordinate/city/asset readiness and durable promotion-retry behavior SHALL remain authoritative; SQL SHALL NOT introduce source canonicalization or merge logic.

#### Scenario: Imported content cannot publish as a Place

- **GIVEN** an imported submission with its required non-null Event start
- **WHEN** Place promotion is attempted without prior durable promotion linkage
- **THEN** existing place_has_event_dates readiness rejects publication without target/media creation or moderation-state mutation

#### Scenario: Promotion resolution columns are guarded

- **WHEN** imported Event promotion atomically records its Event linkage and accepted status
- **THEN** the authorized RPC establishes transaction-local resolution context and obeys submission → record → Event relative lock order
- **AND** an unsupported direct status or promoted-link mutation is rejected by the imported-resolution guard
