## MODIFIED Requirements

### Requirement: Subplan 3 reuses earlier hardening without claiming release readiness
This capability SHALL reuse the explicit draft checkpoint, checkpoint baseline, durable client submission identity, local lifecycle serialization, staged-asset ownership, retry-safe upload behavior, and persistence-first clear established by Content Submission Hardening Subplans 1 and 2. It SHALL NOT duplicate those mechanisms or represent completion of this navigation/lifecycle subplan as whole-feature release readiness. Subplan 4 SHALL remain the source of client request, ownership, acknowledgement, and ViewModel-finalization behavior. Subplan 5 SHALL consume the already-present `client_submission_id` only at the Edge/database boundary to provide authenticated server idempotency and atomic persistence. No Subplan 5 backend outcome SHALL bypass or duplicate the existing successful local-finalization path, and route, progress, checkpoint, Command, Provider, Cloudinary, and staging behavior SHALL remain unchanged.

#### Scenario: Existing durable boundaries remain authoritative
- **WHEN** guarded exits, external launches, submission transitions, retries, or finalization need persistence behavior
- **THEN** they invoke or extend the existing checkpoint, serialized lifecycle, staged-session, Command, and clear primitives rather than creating parallel draft or asset infrastructure

#### Scenario: Backend hardening is isolated from navigation
- **WHEN** Subplan 5 persists and deduplicates by `client_submission_id`
- **THEN** it changes no route ownership, progress state, external-link checkpoint, form-exit, or local retirement behavior

#### Scenario: Backend remains unchanged
- **WHEN** the Subplan 4 client request envelope adds `client_submission_id` before Subplan 5 is deployed
- **THEN** Supabase schemas, migrations, RLS, RPCs, production Edge Function implementation, server-side persistence and rate-limit behavior, and Cloudinary behavior and retry semantics remain unchanged

#### Scenario: Client identity remains a compatibility field
- **WHEN** only the Subplan 4 production submission boundary tolerates the additional `client_submission_id` field
- **THEN** the client does not yet claim that the backend stores, validates, enforces, or deduplicates by that field

#### Scenario: Created and replayed responses use one finalization path
- **WHEN** final submission returns either a newly created or idempotently replayed positive acknowledgement
- **THEN** the ViewModel uses the same existing identity-bound successful local-finalization path before success navigation is enabled

#### Scenario: Completion is reported as Subplan 3 only
- **WHEN** every requirement in this navigation capability is verified independently
- **THEN** the result remains completion of the Form Exit Guard & Progress Route subplan and whole-program release readiness remains deferred to the complete hardening sequence
