# Spec Delta

## ADDED Requirements

### Requirement: Field discard restores only the effective baseline
Explicit local discard SHALL restore current editable fields C to the effective field baseline E under exact activation authority. It SHALL NOT load or overwrite physical checkpoint P, change accepted remote baseline R, delete an owner, or change staged descriptors, bytes, receipts, navigation metadata, unresolved write intent or recovery checkpoint obligations. It SHALL NOT perform persistence or remote work.

#### Scenario: Hydration makes effective fields newer than disk
- **GIVEN** physical P=A and accepted hydration establishes C=E=B without writing disk
- **WHEN** the user edits C and explicitly discards those uncheckpointed edits
- **THEN** current fields become B, E stays B, physical P stays A and R stays unchanged
- **AND** no disk write occurs and A is not incorrectly restored as the effective baseline

#### Scenario: Explicit acceptance obligation remains after discard
- **GIVEN** explicit recovery Accept established E=B and an outstanding checkpoint obligation over P=A, followed by local edits C
- **WHEN** an authorized field discard restores C to B
- **THEN** the acceptance obligation remains and still refuses unsafe target/session switching
- **AND** leaving the page does not retire the application-owned activation or claim B durable

#### Scenario: Remotely unsaved checkpoint and staged receipts are retained
- **GIVEN** E contains checkpointed remotely unconfirmed work, durable staged assets with upload receipts and an unresolved field-write intent
- **WHEN** newer local fields are discarded
- **THEN** only current fields return to E, with exact incomplete input preserved
- **AND** P including its recorded metadata, R, intent identity/input/token, staged order, receipts, files and owner remain unchanged

### Requirement: Discard cannot overwrite superseding field intent
Discard SHALL validate captured account/session/target/activation and the reviewed field/baseline revision within existing local arbitration. Stale authority, unsettled conflicting local work or a superseded revision SHALL return refusal without field effects. Expected failure SHALL preserve all local work; unexpected failures SHALL retain existing reporting behavior.

#### Scenario: Edit or checkpoint supersedes reviewed discard
- **WHEN** a field edit, checkpoint or baseline reconciliation changes the reviewed state before queued discard can act
- **THEN** discard is refused without replacing newer current/effective fields or changing physical evidence
- **AND** removal remains unauthorized until a fresh decision

#### Scenario: Account or activation changes while waiting
- **WHEN** A1 discard waits behind local work and A1 is revoked or replaced by B then A2
- **THEN** A1 changes no A2 fields, errors, route effects or persistence even when identifiers match

#### Scenario: Discard refusal leaves work available
- **WHEN** discard cannot establish current authority or safely enter local arbitration
- **THEN** it returns failure and leaves C/E/P/R, staged work, write intent and recovery obligation intact
- **AND** the current editor remains usable for retry or cancellation
