## MODIFIED Requirements

### Requirement: Subplan completion is not release readiness
Completion of local asset staging SHALL be assessed as Content Submission Hardening Subplan 2 only. The per-session cleanup seam SHALL continue to support explicit clear/discard when no active submission attempt owns the logical session. After valid remote acknowledgement, the ViewModel-owned successful-finalization path SHALL reuse the same persistence-first draft/session retirement and per-session staged cleanup primitive; finalization-only retries SHALL remain owned by that path. The progress route SHALL NOT independently clear or rotate the session, and its success actions SHALL only navigate after local finalization succeeds. No eager cleanup before valid acknowledgement, Cloudinary rollback or deletion, duplicate cleanup implementation, or speculative finalization abstraction SHALL be introduced. The system SHALL NOT be declared release-ready or release-proof until all Content Submission Hardening subplans and their cross-subplan behavior have been implemented and verified.

#### Scenario: Existing post-success clear reuses staged cleanup
- **GIVEN** per-session cleanup is implemented through the existing persistence-first retirement operation
- **AND** the backend has returned a valid successful acknowledgement for the owned logical session
- **WHEN** ViewModel-owned local finalization retires that completed session
- **THEN** it SHALL clean the completed session's staged state through the same tested per-session primitive
- **AND** no eager cleanup, Cloudinary rollback, or duplicate cleanup path SHALL run before acknowledgement

#### Scenario: Later finalization redesign remains deferred
- **GIVEN** Subplan 2 exposed the tested per-session cleanup primitive while deferring definitive successful-submission ownership
- **WHEN** the later ViewModel-owned finalization or finalization-only retry retires an acknowledged session
- **THEN** it SHALL reuse that primitive rather than creating a parallel staged cleanup or finalization abstraction

#### Scenario: Explicit discard remains available without an owner
- **WHEN** no active or acknowledged submission attempt owns the current logical session and explicit clear/discard is requested
- **THEN** the existing persistence-first retirement and per-session staged cleanup behavior remains available

#### Scenario: Progress actions do not own cleanup
- **WHEN** local successful-submission finalization is pending or has completed
- **THEN** the progress route does not clear or rotate the session and its success actions navigate only after ViewModel-owned finalization succeeds

#### Scenario: Subplan verification does not claim whole-feature readiness
- **WHEN** every requirement in this capability passes
- **THEN** the result SHALL be reported as completion of Subplan 2 only
- **AND** whole Content Submission release readiness SHALL remain deferred to the complete hardening sequence
