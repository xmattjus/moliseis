## ADDED Requirements

### Requirement: Form presentation follows session identity without creating edits

When the active logical submission identity changes, the public form SHALL replace its session-owned presentation from the authoritative current draft without routing synchronization through user-edit callbacks, mutating draft fields, checkpointing, restoring, clearing, or rotating identity. This SHALL apply to content, rich description, author/contact, and terms controls. Presentation replacement SHALL preserve the exact current snapshot and the clean or dirty state established by the existing structural checkpoint comparison, including absent nullable values and temporal values. Values from the previous session SHALL NOT be reintroduced. Ordinary user edits within an unchanged session SHALL retain existing edit and dirty-state behavior.

#### Scenario: Late empty persisted adoption preserves clean recovery
- **GIVEN** the screen is mounted while draft loading is pending with a constructor identity
- **WHEN** valid recovery adopts a different persisted identity with absent nullable fields and the form presentation settles
- **THEN** the exact recovered snapshot remains clean, absent values remain absent, no automatic draft save occurs, no unsaved-changes indicator appears, and clean Back exits without confirmation

#### Scenario: Mixed recovered values remain exact
- **WHEN** recovery adopts a different identity containing both populated and absent fields
- **THEN** the form presents those values exactly without synthesizing edits, replacing absent values, or persisting the recovered draft

#### Scenario: Retirement beneath progress preserves the fresh snapshot
- **GIVEN** the real form screen remains mounted beneath progress
- **WHEN** acknowledged submission completes successful local finalization and form presentation settles
- **THEN** the new identity's canonical fresh snapshot remains empty and clean before navigation, without values or edits replayed from the submitted session

#### Scenario: Successful Home uses the clean exit policy
- **WHEN** the user activates `Torna alla home` after successful local finalization
- **THEN** Home is reached without `Salvare le modifiche?`, fresh-session checkpointing, restoration, another clear, or another identity rotation

#### Scenario: Back and new suggestion reveal only the fresh session
- **WHEN** Back or `Nuovo suggerimento` removes progress after successful finalization
- **THEN** the revealed form presents the fresh session, including empty contact fields, unchecked terms and fresh temporal controls, without an unsaved-changes indicator or additional lifecycle work

#### Scenario: Recovered contact values cannot return after retirement
- **GIVEN** a recovered session originally has populated author and contact fields
- **WHEN** that session is submitted successfully and retired
- **THEN** neither the next draft nor its presentation reintroduces those original values

#### Scenario: Real same-session edits remain observable
- **WHEN** the user changes a field while the active identity is unchanged
- **THEN** the existing edit updates the draft and structural difference from its checkpoint continues to control dirty state and exit confirmation
