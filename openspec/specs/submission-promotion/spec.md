# submission-promotion Specification

## Purpose

Define publication readiness for moderated content while preserving incomplete category classification throughout suggestion and pending editorial workflows.

## Requirements

### Requirement: Publication requires a concrete category

A content submission SHALL have a category other than `unknown` before it can be promoted into a published place or event. The database promotion operation SHALL enforce this restriction authoritatively, and a failed category-readiness check SHALL NOT create or mutate publication state.

#### Scenario: Unknown category blocks place publication

- **GIVEN** a persisted pending content submission
- **AND** its category is `unknown`
- **AND** it otherwise satisfies place publication readiness
- **WHEN** promotion to `place` is requested
- **THEN** promotion SHALL fail with the domain outcome `category_required`
- **AND** `target_type` SHALL be null
- **AND** `entity_id` SHALL be null
- **AND** no place SHALL be created
- **AND** no media SHALL be created by the attempted promotion
- **AND** the source submission SHALL remain `pending`
- **AND** its category and moderation metadata SHALL remain unchanged
- **AND** its promotion linkage SHALL remain null

#### Scenario: Unknown category blocks event publication

- **GIVEN** a persisted pending content submission
- **AND** its category is `unknown`
- **AND** it otherwise satisfies event publication readiness, including valid event dates
- **WHEN** promotion to `event` is requested
- **THEN** promotion SHALL fail with the domain outcome `category_required`
- **AND** `target_type` SHALL be null
- **AND** `entity_id` SHALL be null
- **AND** no event SHALL be created
- **AND** no media SHALL be created by the attempted promotion
- **AND** the source submission SHALL remain `pending`
- **AND** its category and moderation metadata SHALL remain unchanged
- **AND** its promotion linkage SHALL remain null

#### Scenario: Concrete category remains publishable

- **GIVEN** a pending submission with a concrete category such as `nature`
- **AND** all other target-specific publication readiness requirements are satisfied
- **WHEN** promotion is requested
- **THEN** the category requirement SHALL NOT prevent promotion
- **AND** the selected category SHALL be copied according to the existing promotion behavior

#### Scenario: Linked submission remains idempotent after its category becomes unknown

- **GIVEN** a submission already has durable promotion linkage to a published target
- **AND** its source category is `unknown`
- **WHEN** promotion is retried with either target selection
- **THEN** the promotion operation SHALL return the existing `already_promoted` result with the original target and entity identifier
- **AND** it SHALL NOT return `category_required`
- **AND** it SHALL NOT create another target or media row

### Requirement: Unknown category remains valid before publication

The system SHALL continue to permit `unknown` while content is a public suggestion or pending editorial submission. The publication-category rule SHALL NOT become a global category constraint or a shared moderation rule.

#### Scenario: Public suggestion omits a concrete category

- **GIVEN** an otherwise-valid public suggestion request
- **WHEN** the user does not select a category and the request omits the category field
- **THEN** the request SHALL remain valid
- **AND** the resulting pending submission SHALL persist with the existing `unknown` database default

#### Scenario: Administrator creates or saves unknown while pending

- **GIVEN** a new or existing pending submission
- **WHEN** an administrator creates or saves it with category `unknown`
- **THEN** the operation SHALL NOT reject it solely because its category is `unknown`

#### Scenario: Unknown category does not prevent rejection

- **GIVEN** a clean persisted pending submission with category `unknown`
- **WHEN** an administrator rejects it
- **THEN** the rejection SHALL remain available
- **AND** the category publication rule SHALL NOT block that rejection

### Requirement: Publication API exposes category readiness failure

The admin publication API SHALL map the database `category_required` promotion outcome to a stable client-visible validation error.

#### Scenario: Category readiness failure reaches API client

- **GIVEN** the promotion RPC returns `category_required`
- **WHEN** the admin Edge Function processes the result
- **THEN** it SHALL return HTTP `422`
- **AND** the response code SHALL be `PROMOTION_CATEGORY_REQUIRED`
- **AND** the outcome SHALL NOT be treated as an internal database failure

### Requirement: Admin UI communicates category publication readiness

The admin editor SHALL prevent an administrator from initiating publication while the persisted submission category is `unknown`, while preserving other moderation actions allowed by the current state.

#### Scenario: Clean unknown-category submission

- **GIVEN** a clean persisted pending submission
- **AND** its category is `unknown`
- **WHEN** the admin editor renders its moderation controls
- **THEN** the publication action SHALL be disabled
- **AND** the rejection action SHALL remain enabled when no other existing guard disables it
- **AND** the UI SHALL explain that a category must be selected and saved before publication

#### Scenario: Administrator selects a concrete category

- **GIVEN** a pending submission whose persisted category is `unknown`
- **WHEN** the administrator selects a concrete category
- **THEN** the editor SHALL become dirty according to existing behavior
- **AND** publication SHALL remain unavailable until the edit has been saved
- **AND** no special auto-save behavior SHALL be introduced

#### Scenario: Backend category failure remains understandable

- **GIVEN** a publication request reaches the backend and returns `PROMOTION_CATEGORY_REQUIRED`
- **WHEN** the Flutter UI handles that API error
- **THEN** it SHALL display actionable Italian copy instructing the administrator to select and save a category before publication.

### Requirement: Event promotion copies temporal mode atomically
Promotion to an event SHALL read the source temporal mode and dates from the same locked submission snapshot and copy them without reinterpretation into the published event within the existing atomic promotion operation. Existing category, start, chronology, asset, authorization, and promotion-replay rules SHALL remain authoritative. Promotion SHALL NOT infer all-day mode from midnight or discard true mode because the end is null.

#### Scenario: Single-day all-day submission is promoted
- **WHEN** a publishable pending submission has true mode, canonical start, and null end and event promotion succeeds
- **THEN** the published event has true and the identical start/null-end values, and its linkage and media commit atomically

#### Scenario: Multi-day all-day submission is promoted
- **WHEN** a publishable true-mode submission has a canonical final-day end
- **THEN** the published event retains the identical flag and inclusive temporal range

#### Scenario: Timed midnight is promoted unchanged
- **WHEN** a publishable timed submission starts at real midnight
- **THEN** the published event retains false and the original dates

#### Scenario: Existing failure or replay does not create another event
- **WHEN** promotion fails a readiness check or a linked submission is promoted again
- **THEN** existing atomic failure or already-promoted behavior applies without a new event, media set, or temporal reinterpretation

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
