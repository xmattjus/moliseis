## MODIFIED Requirements

### Requirement: Subplan 3 reuses earlier hardening without claiming release readiness
This capability SHALL reuse the explicit draft checkpoint, checkpoint baseline, durable client submission identity, local lifecycle serialization, staged-asset ownership, retry-safe upload behavior, and persistence-first clear established by Content Submission Hardening Subplans 1 and 2. It SHALL NOT duplicate those mechanisms or represent completion of this navigation/lifecycle subplan as whole-feature release readiness. The later Subplan 4 client SHALL intentionally add the currently tolerated `client_submission_id` compatibility field to the public submission request envelope, while Supabase schemas, migrations, RLS, RPCs, production Edge Function implementation, server-side persistence and rate-limit behavior, and Cloudinary behavior and retry semantics remain unchanged. Sending that field SHALL NOT imply that the backend persists or enforces it, deduplicates submissions, or provides server-side idempotency.

#### Scenario: Existing durable boundaries remain authoritative
- **WHEN** guarded exits, external launches, submission transitions, retries, or finalization need persistence behavior
- **THEN** they invoke or extend the existing checkpoint, serialized lifecycle, staged-session, Command, and clear primitives rather than creating parallel draft or asset infrastructure

#### Scenario: Backend hardening is isolated from navigation
- **WHEN** Subplan 5 persists and deduplicates by `client_submission_id`
- **THEN** it changes no route ownership, progress state, external-link checkpoint, form-exit, or local retirement behavior

#### Scenario: Backend remains unchanged
- **WHEN** the Subplan 4 client request envelope adds `client_submission_id`
- **THEN** Supabase schemas, migrations, RLS, RPCs, production Edge Function implementation, server-side persistence and rate-limit behavior, and Cloudinary behavior and retry semantics remain unchanged

#### Scenario: Client identity remains a compatibility field
- **WHEN** the production submission boundary tolerates the additional `client_submission_id` field
- **THEN** the client does not claim that the backend stores, validates, enforces, or deduplicates by that field or that final submission is server-side idempotent

#### Scenario: Created and replayed responses use one finalization path
- **WHEN** final submission returns either a newly created or idempotently replayed positive acknowledgement
- **THEN** the ViewModel uses the same existing identity-bound successful local-finalization path before success navigation is enabled

#### Scenario: Completion is reported as Subplan 3 only
- **WHEN** every requirement in this capability is verified
- **THEN** the result is reported as completion of the Form Exit Guard & Progress Route subplan and whole-program release readiness remains deferred to the complete hardening sequence
