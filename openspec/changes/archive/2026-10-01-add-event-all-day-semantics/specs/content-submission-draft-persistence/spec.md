## ADDED Requirements

### Requirement: Supported draft recovery preserves temporal mode and civil dates
An otherwise-supported draft SHALL checkpoint and restore its temporal mode, initial civil date, and optional final civil date together with its existing content and client identity. Missing mode in a previously valid draft SHALL recover as false; missing/invalid identity and unsupported pre-schema shapes SHALL retain their existing fallback rules. A final civil date SHALL survive restore even when switching back to timed leaves the start unresolved and no final instant can yet be persisted. Dates derivable from persisted instants SHALL use Europe/Rome. Recovery SHALL remain non-writing and establish the restored structural snapshot as clean.

#### Scenario: Previously valid timed draft has no mode field
- **WHEN** a supported persisted draft with a valid client identity omits the new mode
- **THEN** recovery uses false, preserves its supported temporal values and identity, and performs no migration or automatic write

#### Scenario: All-day single-day and multi-day drafts restore
- **WHEN** either all-day shape is checkpointed and the session restarts
- **THEN** recovery preserves true, the exact civil dates and canonical bounds, and the same client identity as a clean baseline

#### Scenario: Unresolved timed transition retains a final civil date
- **WHEN** an all-day multi-day draft switches back to timed and is checkpointed before choosing a new start time
- **THEN** restore retains both civil dates, false mode, and unresolved start without inventing a time or losing the final date

#### Scenario: Unsupported legacy identity is still unsupported
- **WHEN** a persisted row lacks a valid client identity even if its new mode is absent
- **THEN** the existing fresh-clean-session fallback remains in force without recovering or rewriting that unsupported row

### Requirement: Temporal edits participate in structural checkpoint and captured submission
Mode and final-civil-date changes SHALL participate in immutable draft equality, dirty-state derivation, explicit checkpointing, and captured submission content. Editing SHALL NOT introduce implicit persistence or rotate the logical client identity. Submitting a restored all-day draft SHALL not require a start clock selection; a restored unresolved timed draft SHALL require a new time and reconstruct its retained final bound before submission.

#### Scenario: Toggle is dirty until explicit checkpoint
- **WHEN** a supported mode toggle changes the temporal snapshot
- **THEN** the session is dirty without a local write and the existing explicit checkpoint success/failure rules apply to the captured mode and dates

#### Scenario: Restored all-day draft submits without a time
- **WHEN** a restored otherwise-valid all-day draft crosses the established durable submission boundary
- **THEN** its captured request preserves true and its civil dates without synthesizing a user-selected start time

#### Scenario: Restored timed transition requires a new time
- **WHEN** the restored draft is false with unresolved start and a retained final civil date
- **THEN** timed submission remains invalid until a new start time is selected, after which the final bound is reconstructed and captured
