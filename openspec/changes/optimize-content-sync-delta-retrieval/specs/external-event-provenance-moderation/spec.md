## MODIFIED Requirements

### Requirement: Soft-deleted linked Events suppress source proposals

When a record links to an Event with non-null `deleted_at`, ingest MAY update current source state and metadata but enqueue SHALL create no pending and SHALL NOT advance proposed.

Generic canonical persistence/sync semantics SHALL recognize `deleted_at` non-null → null as a semantic lifecycle mutation, strictly advance canonical `modified_at` and represent the returned active row locally. Generic marker triggers and low-level DB/mapper/sync regression tests SHALL cover this restore-capable persistence/sync behavior without establishing a supported Event restore operation.

The canonical sync optimization SHALL NOT introduce an Event restore RPC, Admin restore command, UI restore, moderation restore workflow, restore-performing trigger, new runtime producer that restores Events, or operation-level restore workflow test. It SHALL NOT modify the provenance enqueue workflow to perform or automatically react to restore. Any future supported operation restoring a soft-deleted Event SHALL reevaluate enqueue for every linked source record whose current differs from its watermark.

#### Scenario: Source changes while canonical target is soft deleted

- **GIVEN** an external record links to a soft-deleted Event
- **WHEN** ingest observes a new source revision
- **THEN** current state MAY advance
- **AND** no new pending SHALL be created and proposed SHALL remain unchanged

#### Scenario: Generic restore-capable semantics remain below the operation boundary

- **WHEN** low-level DB/mapper/sync fixtures exercise a canonical Event returning from deleted to active
- **THEN** the semantic marker strictly advances and local sync can represent the active state
- **AND** no supported Event restore operation, runtime restore producer or provenance enqueue workflow change is introduced

#### Scenario: Future supported restore retains linked-source responsibility

- **WHEN** a future change introduces a supported operation restoring a soft-deleted Event
- **THEN** that operation's contract SHALL require reevaluation/enqueue for every linked source record whose current differs from its proposed watermark
- **AND** the canonical sync optimization SHALL NOT implement that future operation
