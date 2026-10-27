# Proposal

## Why

Admin editor fields currently live only in a route-owned ViewModel, and its picker has no durable local owner or recovery contract. Public has durable drafts and staged files, but its route-triggered Android lost-data consumer cannot safely distinguish Public from Admin; copying its single-draft cleanup policy would also delete recoverable Admin sessions.

## What Changes

- Introduce immutable, account-owned Admin drafts, explicit local checkpoints, separate remote baselines, and recoverable per-target sessions behind the existing Provider architecture.
- Add Admin-specific ObjectBox descriptors and private staged copies with bounded size/capacity, digest deduplication, contained paths, ordered publication and deterministic reconciliation.
- Introduce one application-startup Android picker recovery coordinator, durable pre-launch ownership and a bounded durable handoff inbox. Preserve the documented plugin-consumption loss window; do not claim crash-safe exactly-once delivery.
- Narrowly integrate Public with that shared ownership/retrieval boundary while preserving Public draft, staging, submit and navigation guarantees.
- Keep new-mode asset selection unavailable until Plan 2. Preserve existing remote Save, moderation, previews, event resolution and immediate persisted pending asset actions, adding only necessary ownership and local-retirement guards.
- Record disposition of the obsolete `improve-admin-submission-editor-workflow` proposal without archiving it as implemented or syncing its unimplemented requirements.

## Capabilities

### New Capabilities

- `admin-draft-persistence`: incomplete immutable fields, account/session identity, explicit checkpoints, recoverable activation, remote/local truth separation and lifecycle compatibility.
- `admin-local-asset-staging`: private ordered Admin staging, reconciliation, isolation, capacity and safe recovered-asset consumption without remote replay.

### Modified Capabilities

- `content-submission-local-asset-staging`: replace feature-local route-triggered lost-data acquisition with shared startup retrieval and durable attribution for both features; retain all other Public storage, admission, rotation and submission contracts.

## Impact

Future implementation touches Admin domain models/repositories, additive ObjectBox entities/mappers/generated schema, local filesystem repositories, the existing Admin ViewModel/screen/routes and `config/dependencies.dart`; application startup and Public picker recovery need narrow integration. Existing `EventDateDraft`, `EventTimePolicy`, Delta freezing, `Result`, Command admission and test support remain authoritative patterns. No new dependency, state-management library, Supabase migration, RPC, Edge Function, Cloudinary contract or remote idempotency key is needed for this foundation.

Plan 2 owns Save & Progress Route, create-ID adoption, staged uploads and post-Save navigation. Plan 3 owns remote stale recovery; Plan 4 owns dirty exit. This definition is planning only: all implementation tasks remain unchecked. Validation of artifacts is not evidence of implementation or release readiness.
