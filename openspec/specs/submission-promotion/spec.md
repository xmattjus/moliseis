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
